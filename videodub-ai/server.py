import time
import threading
import traceback
import config
import api_client
from orchestrator import JobOrchestrator
from logger import log

# No lock needed — GIL protects dict operations in CPython
_active_jobs: dict[str, JobOrchestrator] = {}

def _get_active_count() -> int:
    return sum(1 for o in _active_jobs.values() if o.is_alive())

def _start_job(job: dict):
    orchestrator = JobOrchestrator(job)
    _active_jobs[job["video_id"]] = orchestrator
    orchestrator.start()
    log("SERVER", f"Orchestrator started for {job['video_id']}")

def _poll_once():
    active_count = _get_active_count()
    if active_count < config.MAX_CONCURRENT_JOBS:
        job = api_client.get_next_job()
        if job:
            log("SERVER", f"New job: {job['video_id']} | Active: {active_count+1}/{config.MAX_CONCURRENT_JOBS}")
            _start_job(job)
        else:
            log("SERVER", f"No jobs. Active: {active_count}/{config.MAX_CONCURRENT_JOBS}")
    else:
        log("SERVER", f"At capacity ({active_count}/{config.MAX_CONCURRENT_JOBS})")

def _cleanup_loop():
    log("SERVER", "Cleanup loop started")
    while True:
        time.sleep(15)
        try:
            finished = [vid for vid, o in list(_active_jobs.items()) if not o.is_alive()]
            for vid in finished:
                del _active_jobs[vid]
                log("SERVER", f"Cleaned up: {vid} | Active: {_get_active_count()}")
        except Exception as e:
            log("SERVER", f"Cleanup error: {e}")

def _job_loop():
    log("SERVER", "Job loop started")
    iteration = 0
    while True:
        iteration += 1
        try:
            _poll_once()
        except Exception as e:
            log("SERVER", f"Poll error #{iteration}: {e}\n{traceback.format_exc()}")
        log("SERVER", f"Heartbeat #{iteration} — Active: {_get_active_count()}/{config.MAX_CONCURRENT_JOBS}")
        time.sleep(config.JOB_POLL_INTERVAL)

if __name__ == "__main__":
    import os
    os.makedirs(config.WORK_DIR, exist_ok=True)
    os.makedirs(config.OUTPUT_DIR, exist_ok=True)

    log("SERVER", "=" * 50)
    log("SERVER", "VideoDub AI Server starting...")
    log("SERVER", f"Mode       : {'FAKE' if config.FAKE_MODE else 'REAL'}")
    log("SERVER", f"Max jobs   : {config.MAX_CONCURRENT_JOBS}")
    log("SERVER", f"API URL    : {config.API_BASE_URL}")
    log("SERVER", f"Poll every : {config.JOB_POLL_INTERVAL}s")
    log("SERVER", "=" * 50)

    threading.Thread(target=_cleanup_loop, daemon=True, name="cleanup").start()
    log("SERVER", "Cleanup thread started")

    log("SERVER", "Starting job loop...")
    try:
        _job_loop()
    except KeyboardInterrupt:
        log("SERVER", "Stopped.")
    except Exception as e:
        log("SERVER", f"FATAL: {e}\n{traceback.format_exc()}")