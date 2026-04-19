import os
import asyncio
import time
from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Header
from fastapi.responses import FileResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional
import uvicorn

import config
import queue_manager as qm
from queue_manager import JobStatus

app = FastAPI(title="VideoDub API", version="1.0.0")

# ── Startup ───────────────────────────────────────────────────────

@app.on_event("startup")
async def startup():
    os.makedirs(config.UPLOAD_DIR, exist_ok=True)
    os.makedirs(config.DUBBED_DIR, exist_ok=True)
    mode = "FAKE" if config.FAKE_MODE else "REAL"
    print(f"VideoDub API started in {mode} mode on port {config.PORT}")

# ── Internal auth helper ──────────────────────────────────────────

def _verify_internal_key(x_internal_key: Optional[str]):
    if x_internal_key != config.INTERNAL_API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized — invalid internal key")

# ── Public Routes ─────────────────────────────────────────────────

@app.get("/")
def root():
    return {
        "service": "VideoDub API",
        "version": "1.0.0",
        "mode": "fake" if config.FAKE_MODE else "real",
        "queue_size": qm.get_queue_size(),
        "max_queue": config.MAX_QUEUE_SIZE,
    }


@app.post("/upload")
async def upload_video(
    user_id: str = Form(...),
    video: UploadFile = File(...),
):
    if not user_id or len(user_id.strip()) < 3:
        raise HTTPException(status_code=400, detail="Invalid user ID")

    if qm.is_queue_full():
        return JSONResponse(
            status_code=503,
            content={
                "error": "queue_full",
                "message": "Server is busy. Please try again later.",
                "queue_size": qm.get_queue_size(),
                "max_queue": config.MAX_QUEUE_SIZE,
            }
        )

    if not video.filename:
        raise HTTPException(status_code=400, detail="No file provided")

    ext = os.path.splitext(video.filename)[1].lower()
    if ext not in config.ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported format. Allowed: {', '.join(config.ALLOWED_EXTENSIONS)}"
        )

    content_type = video.content_type or ""
    if content_type not in config.ALLOWED_MIME_TYPES:
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload a valid video file.")

    content = await video.read()

    if len(content) == 0:
        raise HTTPException(status_code=400, detail="File is empty")

    if len(content) > config.MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size is {config.MAX_FILE_SIZE_MB}MB"
        )

    if not _is_valid_video_bytes(content, ext):
        raise HTTPException(status_code=400, detail="File does not appear to be a valid video file")

    original_name = video.filename
    temp_filename = f"{user_id}_{int(time.time())}{ext}"
    upload_path = os.path.join(config.UPLOAD_DIR, temp_filename)

    with open(upload_path, "wb") as f:
        f.write(content)

    job = qm.create_job(
        user_id=user_id,
        original_name=original_name,
        upload_path=upload_path,
    )

    if config.FAKE_MODE:
        asyncio.create_task(qm.run_fake_job(job.video_id))
    else:
        asyncio.create_task(qm.run_real_job(job.video_id))

    return {
        "success": True,
        "video_id": job.video_id,
        "original_name": original_name,
        "message": "Video uploaded successfully. Processing started.",
        "estimated_minutes": 10 if config.FAKE_MODE else None,
    }


@app.get("/status/{video_id}")
def get_status(video_id: str, user_id: str):
    job = qm.get_job(video_id)

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.user_id != user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    response = {
        "video_id": video_id,
        "original_name": job.original_name,
        "status": job.status,
        "progress": job.progress,
        "current_stage": job.current_stage,
    }

    if job.status == JobStatus.DONE:
        response["download_url"] = f"{config.BASE_URL}/download/{video_id}?user_id={user_id}"

    if job.status == JobStatus.FAILED:
        response["error"] = job.error_message or "Processing failed"

    return response


@app.get("/download/{video_id}")
def download_video(video_id: str, user_id: str):
    job = qm.get_job(video_id)

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.user_id != user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    if job.status != JobStatus.DONE:
        raise HTTPException(status_code=400, detail="Video is not ready yet")

    if not job.dubbed_path or not os.path.exists(job.dubbed_path):
        raise HTTPException(status_code=404, detail="Dubbed video file not found")

    import threading
    def _cleanup():
        time.sleep(600)  # 10 minutes — gives app time to download
        qm.mark_downloaded(video_id)
    threading.Thread(target=_cleanup, daemon=True).start()

    return FileResponse(
        path=job.dubbed_path,
        filename=f"{os.path.splitext(job.original_name)[0]}_dubbed.mp4",
        media_type="video/mp4",
    )


@app.delete("/job/{video_id}")
def cancel_job(video_id: str, user_id: str):
    job = qm.get_job(video_id)

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.user_id != user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    cancelled = qm.cancel_job(video_id)

    if not cancelled:
        raise HTTPException(
            status_code=400,
            detail="Job cannot be cancelled — it may already be done or cancelled"
        )

    return {"success": True, "message": "Job cancelled and files cleaned up"}


@app.get("/queue")
def queue_info():
    return {
        "queue_size": qm.get_queue_size(),
        "max_queue": config.MAX_QUEUE_SIZE,
        "available_slots": config.MAX_QUEUE_SIZE - qm.get_queue_size(),
        "is_full": qm.is_queue_full(),
        "processing": qm.get_processing_count(),
        "max_concurrent": config.MAX_CONCURRENT_JOBS,
    }


# ── Internal Routes (AI server only) ─────────────────────────────

class ProgressUpdate(BaseModel):
    video_id: str
    stage: str
    progress: int

class JobFailed(BaseModel):
    video_id: str
    error_message: Optional[str] = ""


@app.get("/internal/next-job")
def get_next_job(x_internal_key: Optional[str] = Header(None)):
    """AI server calls this to get the next job to process."""
    _verify_internal_key(x_internal_key)

    if not qm.can_start_new_job():
        return {"job": None, "reason": "max_concurrent_reached"}

    queued = qm.get_queued_jobs()
    if not queued:
        return {"job": None, "reason": "no_jobs_in_queue"}

    job = queued[0]
    job.status = JobStatus.PROCESSING
    job.started_at = time.time()

    return {
        "job": {
            "video_id": job.video_id,
            "user_id": job.user_id,
            "original_name": job.original_name,
            "upload_path": job.upload_path,
            "source_language": job.source_language,
            "target_language": job.target_language,
        }
    }


@app.post("/internal/progress")
def update_progress(
    update: ProgressUpdate,
    x_internal_key: Optional[str] = Header(None)
):
    """AI server calls this to report progress at each pipeline stage."""
    _verify_internal_key(x_internal_key)

    if update.stage not in config.PIPELINE_STAGES and update.stage != "processing":
        raise HTTPException(status_code=400, detail=f"Unknown stage: {update.stage}")

    success = qm.update_job_progress(
        video_id=update.video_id,
        stage=update.stage,
        progress=update.progress,
    )

    if not success:
        raise HTTPException(status_code=404, detail="Job not found or cancelled")

    return {"success": True, "video_id": update.video_id, "stage": update.stage, "progress": update.progress}


@app.post("/internal/upload-dubbed")
async def upload_dubbed(
    video_id: str = Form(...),
    dubbed_file: UploadFile = File(...),
    x_internal_key: Optional[str] = Header(None)
):
    """AI server uploads the dubbed video file directly to API."""
    _verify_internal_key(x_internal_key)

    job = qm.get_job(video_id)
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    if job.status == JobStatus.CANCELLED:
        raise HTTPException(status_code=400, detail="Job was cancelled")

    local_filename = f"{video_id}_dubbed.mp4"
    local_path = os.path.join(config.DUBBED_DIR, local_filename)

    content = await dubbed_file.read()
    with open(local_path, "wb") as f:
        f.write(content)

    success = qm.complete_job(
        video_id=video_id,
        dubbed_path=local_path,
    )

    if not success:
        raise HTTPException(status_code=404, detail="Job not found or cancelled")

    return {"success": True, "video_id": video_id, "message": "Dubbed video uploaded and job marked complete"}


@app.post("/internal/fail")
def fail_job(
    data: JobFailed,
    x_internal_key: Optional[str] = Header(None)
):
    """AI server calls this when processing fails."""
    _verify_internal_key(x_internal_key)

    success = qm.fail_job(
        video_id=data.video_id,
        error_message=data.error_message or "",
    )

    if not success:
        raise HTTPException(status_code=404, detail="Job not found")

    return {"success": True, "video_id": data.video_id, "message": "Job marked as failed"}


@app.get("/internal/cancelled-jobs")
def get_cancelled_jobs(x_internal_key: Optional[str] = Header(None)):
    """AI server polls this to know which jobs to stop processing.
    Once returned, cancelled jobs are removed from memory."""
    _verify_internal_key(x_internal_key)

    all_jobs = qm.get_all_jobs()
    cancelled = [
        v.video_id for v in all_jobs.values()
        if v.status == JobStatus.CANCELLED
    ]

    # Remove cancelled jobs from memory — no longer needed
    for video_id in cancelled:
        all_jobs.pop(video_id, None)

    return {"cancelled_jobs": cancelled}


# ── File validation ───────────────────────────────────────────────

def _is_valid_video_bytes(content: bytes, ext: str) -> bool:
    if len(content) < 12:
        return False
    if ext in (".mp4", ".mov"):
        return content[4:8] == b'ftyp' or content[4:8] == b'moov' or content[0:4] == b'\x00\x00\x00\x18'
    if ext == ".avi":
        return content[0:4] == b'RIFF' and content[8:11] == b'AVI'
    if ext == ".mkv":
        return content[0:4] == b'\x1a\x45\xdf\xa3'
    return True


# ── Run ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=config.HOST,
        port=config.PORT,
        reload=True,
    )