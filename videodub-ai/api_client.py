import time
import json
import urllib.request
import urllib.error
import config
from logger import log as _log

def log(msg: str):
    _log('API_CLIENT', msg)

def _headers():
    return {
        "X-Internal-Key": config.INTERNAL_API_KEY,
        "Content-Type": "application/json",
    }

def _get(path: str, timeout: int = 8):
    url = f"{config.API_BASE_URL}{path}"
    req = urllib.request.Request(url, headers=_headers(), method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        log(f"HTTP {e.code} on GET {path}: {body}")
        return None
    except Exception as e:
        log(f"ERROR on GET {path}: {e}")
        return None

def _post(path: str, data: dict, timeout: int = 8):
    url = f"{config.API_BASE_URL}{path}"
    body = json.dumps(data).encode()
    req = urllib.request.Request(url, data=body, headers=_headers(), method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        log(f"HTTP {e.code} on POST {path}: {body}")
        return None
    except Exception as e:
        log(f"ERROR on POST {path}: {e}")
        return None

def get_next_job():
    data = _get("/internal/next-job")
    if data is None:
        return None
    job = data.get("job")
    if not job:
        log(f"No job available — reason: {data.get('reason', 'unknown')}")
    return job

def report_progress(video_id: str, stage: str, progress: int) -> bool:
    result = _post("/internal/progress", {
        "video_id": video_id,
        "stage": stage,
        "progress": progress,
    })
    if result:
        log(f"Progress reported — {video_id[-8:]} | {stage} | {progress}%")
        return True
    return False

def report_complete(video_id: str, dubbed_path: str) -> bool:
    """Upload the dubbed file directly to the API."""
    url = f"{config.API_BASE_URL}/internal/upload-dubbed"
    try:
        with open(dubbed_path, "rb") as f:
            file_data = f.read()

        boundary = "----VideoDubBoundary"
        body = (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="video_id"\r\n\r\n'
            f"{video_id}\r\n"
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="dubbed_file"; filename="{video_id}_dubbed.mp4"\r\n'
            f"Content-Type: video/mp4\r\n\r\n"
        ).encode() + file_data + f"\r\n--{boundary}--\r\n".encode()

        headers = {
            "X-Internal-Key": config.INTERNAL_API_KEY,
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Content-Length": str(len(body)),
        }

        req = urllib.request.Request(url, data=body, headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=120) as resp:
            json.loads(resp.read().decode())
            log(f"Dubbed file uploaded to API — {video_id[-8:]}")
            return True
    except Exception as e:
        log(f"ERROR uploading dubbed file for {video_id[-8:]}: {e}")
        return False

def report_failed(video_id: str, error_message: str = "") -> bool:
    result = _post("/internal/fail", {
        "video_id": video_id,
        "error_message": error_message,
    })
    if result:
        log(f"Failure reported — {video_id[-8:]} | {error_message}")
        return True
    return False

def get_cancelled_jobs() -> list:
    data = _get("/internal/cancelled-jobs")
    if data is None:
        return []
    cancelled = data.get("cancelled_jobs", [])
    if cancelled:
        log(f"Cancelled jobs: {cancelled}")
    return cancelled