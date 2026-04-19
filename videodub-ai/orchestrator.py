import os
import time
import threading
import config
import api_client
from pipeline import get_pipeline

def log(video_id: str, msg: str):
    print(f"[{time.strftime('%H:%M:%S')}] [ORCH:{video_id[-8:]}] {msg}")

class JobOrchestrator(threading.Thread):
    def __init__(self, job: dict):
        super().__init__(daemon=True)
        self.job = job
        self.video_id = job["video_id"]

    def run(self):
        log(self.video_id, "=" * 40)
        log(self.video_id, f"Job started")
        log(self.video_id, f"File     : {self.job.get('original_name', 'unknown')}")
        log(self.video_id, f"Upload   : {self.job.get('upload_path', 'unknown')}")
        log(self.video_id, "=" * 40)

        work_dir = os.path.join(config.WORK_DIR, self.video_id)
        os.makedirs(work_dir, exist_ok=True)

        input_path = self.job.get("upload_path", "")
        pipeline = get_pipeline()
        stage_progress = dict(config.PIPELINE_STAGES)

        try:
            for i, stage in enumerate(pipeline):
                log(self.video_id, f"Stage {i+1}/{len(pipeline)}: {stage.name.upper()} — checking cancellation...")

                if self._is_cancelled():
                    log(self.video_id, f"CANCELLED before stage {stage.name}. Stopping.")
                    self._cleanup(work_dir)
                    return

                log(self.video_id, f"Stage {i+1}/{len(pipeline)}: {stage.name.upper()} — running...")
                stage_start = time.time()

                result = stage.run(
                    input_path=input_path,
                    job=self.job,
                    work_dir=work_dir,
                )

                elapsed = round(time.time() - stage_start, 2)

                if not result.success:
                    log(self.video_id, f"Stage {stage.name} FAILED after {elapsed}s: {result.error}")
                    api_client.report_failed(self.video_id, f"Stage {stage.name} failed: {result.error}")
                    self._cleanup(work_dir)
                    return

                input_path = result.output_path
                progress = stage_progress.get(stage.name, 0)

                log(self.video_id, f"Stage {stage.name} DONE in {elapsed}s — progress: {progress}%")
                log(self.video_id, f"Output path: {result.output_path}")

                reported = api_client.report_progress(self.video_id, stage.name, progress)
                log(self.video_id, f"Progress reported to API: {'OK' if reported else 'FAILED'}")

            log(self.video_id, "-" * 40)
            log(self.video_id, f"All stages complete!")
            log(self.video_id, f"Final output: {input_path}")

            # Upload dubbed file directly to API — AI server no longer holds it after this
            reported = api_client.report_complete(self.video_id, input_path)
            log(self.video_id, f"Dubbed file uploaded to API: {'OK' if reported else 'FAILED'}")

            # Delete local output file — API has its own copy now
            try:
                if os.path.exists(input_path):
                    os.remove(input_path)
                    log(self.video_id, f"Local output file deleted")
            except Exception as e:
                log(self.video_id, f"Could not delete local output file: {e}")

            log(self.video_id, "Job DONE ✓")
            log(self.video_id, "=" * 40)

            self._cleanup(work_dir)

        except Exception as e:
            log(self.video_id, f"UNEXPECTED ERROR: {e}")
            api_client.report_failed(self.video_id, str(e))
            self._cleanup(work_dir)

    def _is_cancelled(self) -> bool:
        cancelled = api_client.get_cancelled_jobs()
        is_cancelled = self.video_id in cancelled
        if is_cancelled:
            log(self.video_id, f"Found in cancelled jobs list")
        return is_cancelled

    def _cleanup(self, work_dir: str):
        import shutil
        try:
            if os.path.exists(work_dir):
                shutil.rmtree(work_dir)
                log(self.video_id, f"Working directory cleaned up")
        except Exception as e:
            log(self.video_id, f"Cleanup error: {e}")