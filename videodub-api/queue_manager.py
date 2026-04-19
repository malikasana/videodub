import uuid
import time
import os
import asyncio
from enum import Enum
from dataclasses import dataclass, field
from typing import Optional
import config


class JobStatus(str, Enum):
    QUEUED      = "queued"
    PROCESSING  = "processing"
    DONE        = "done"
    CANCELLED   = "cancelled"
    FAILED      = "failed"


@dataclass
class Job:
    video_id:        str
    user_id:         str
    original_name:   str
    upload_path:     str
    source_language: str = ""
    target_language: str = ""
    status:          JobStatus = JobStatus.QUEUED
    progress:        int = 0
    current_stage:   str = "queued"
    dubbed_path:     Optional[str] = None
    error_message:   Optional[str] = None
    created_at:      float = field(default_factory=time.time)
    started_at:      Optional[float] = None
    done_at:         Optional[float] = None

# ── In-memory stores ──────────────────────────────────────────────
_jobs: dict[str, Job] = {}

# ── Helpers ───────────────────────────────────────────────────────

def generate_video_id() -> str:
    ts = int(time.time() * 1000)
    rand = uuid.uuid4().hex[:4].upper()
    return f"VID-{ts}-{rand}"

def get_job(video_id: str) -> Optional[Job]:
    return _jobs.get(video_id)

def get_all_jobs() -> dict[str, Job]:
    return _jobs

def get_queue_size() -> int:
    return sum(
        1 for j in _jobs.values()
        if j.status in (JobStatus.QUEUED, JobStatus.PROCESSING)
    )

def get_processing_count() -> int:
    return sum(1 for j in _jobs.values() if j.status == JobStatus.PROCESSING)

def get_queued_jobs() -> list[Job]:
    """Get jobs waiting to be processed, ordered by creation time."""
    return sorted(
        [j for j in _jobs.values() if j.status == JobStatus.QUEUED],
        key=lambda j: j.created_at
    )

def is_queue_full() -> bool:
    return get_queue_size() >= config.MAX_QUEUE_SIZE

def can_start_new_job() -> bool:
    return get_processing_count() < config.MAX_CONCURRENT_JOBS

def create_job(user_id: str, original_name: str, upload_path: str) -> Job:
    job = Job(
        video_id=generate_video_id(),
        user_id=user_id,
        original_name=original_name,
        upload_path=upload_path,
    )
    _jobs[job.video_id] = job
    return job

def cancel_job(video_id: str) -> bool:
    job = _jobs.get(video_id)
    if not job:
        return False
    if job.status in (JobStatus.DONE, JobStatus.CANCELLED):
        return False
    job.status = JobStatus.CANCELLED
    _cleanup_files(job)
    return True

def update_job_progress(video_id: str, stage: str, progress: int) -> bool:
    """Called by AI server to update job progress."""
    job = _jobs.get(video_id)
    if not job:
        return False
    if job.status == JobStatus.CANCELLED:
        return False
    job.current_stage = stage
    job.progress = progress
    if job.status != JobStatus.PROCESSING:
        job.status = JobStatus.PROCESSING
        if not job.started_at:
            job.started_at = time.time()
    return True

def complete_job(video_id: str, dubbed_path: str) -> bool:
    """Called by AI server when job is done."""
    job = _jobs.get(video_id)
    if not job:
        return False
    if job.status == JobStatus.CANCELLED:
        return False
    job.dubbed_path = dubbed_path
    job.status = JobStatus.DONE
    job.progress = 100
    job.current_stage = "done"
    job.done_at = time.time()
    return True

def fail_job(video_id: str, error_message: str = "") -> bool:
    """Called by AI server when job fails."""
    job = _jobs.get(video_id)
    if not job:
        return False
    job.status = JobStatus.FAILED
    job.error_message = error_message
    _cleanup_files(job)
    return True

def mark_downloaded(video_id: str):
    job = _jobs.get(video_id)
    if job:
        _cleanup_files(job)
        job.upload_path = ""
        job.dubbed_path = ""

def _cleanup_files(job: Job):
    for path in [job.upload_path, job.dubbed_path]:
        if path and os.path.exists(path):
            try:
                os.remove(path)
            except Exception:
                pass

# ── Fake mode processor ───────────────────────────────────────────

async def run_fake_job(video_id: str):
    job = _jobs.get(video_id)
    if not job:
        return

    job.status = JobStatus.PROCESSING
    job.started_at = time.time()

    steps = config.FAKE_PROGRESS_STEPS.copy()
    interval = config.FAKE_PROGRESS_INTERVAL

    for step in steps:
        await asyncio.sleep(interval)

        job = _jobs.get(video_id)
        if not job or job.status == JobStatus.CANCELLED:
            return

        job.progress = step

        if step == 100:
            import shutil
            dubbed_filename = f"{video_id}_dubbed.mp4"
            dubbed_path = os.path.join(config.DUBBED_DIR, dubbed_filename)
            try:
                shutil.copy2(config.FAKE_DUBBED_VIDEO_PATH, dubbed_path)
                job.dubbed_path = dubbed_path
                job.status = JobStatus.DONE
                job.done_at = time.time()
            except Exception as e:
                job.status = JobStatus.FAILED
                print(f"Failed to copy dubbed video: {e}")

# ── Real mode processor ───────────────────────────────────────────

async def run_real_job(video_id: str):
    """
    In real mode the AI server pulls jobs from /internal/next-job
    and pushes progress to /internal/progress.
    This function just marks the job as queued and waits.
    The AI server is responsible for picking it up.
    """
    job = _jobs.get(video_id)
    if not job:
        return
    # Job stays QUEUED until AI server picks it up via /internal/next-job
    # Progress updates come via /internal/progress
    # Completion comes via /internal/complete