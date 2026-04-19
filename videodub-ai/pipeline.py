import time
import os
import shutil
import config

def log(stage: str, video_id: str, msg: str):
    print(f"[{time.strftime('%H:%M:%S')}] [STAGE:{stage.upper()}] {msg}")

class StageResult:
    def __init__(self, success: bool, output_path: str = "", error: str = ""):
        self.success = success
        self.output_path = output_path
        self.error = error

class PipelineStage:
    name = "base"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError

# ── Fake stages ───────────────────────────────────────────────────

class FakeAudioSeparationStage(PipelineStage):
    name = "audio_separation"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        log(self.name, job['video_id'], f"Separating audio from video...")
        log(self.name, job['video_id'], f"Input: {input_path}")
        time.sleep(config.FAKE_STAGE_DURATION)
        log(self.name, job['video_id'], f"Audio separated successfully (fake)")
        return StageResult(success=True, output_path=input_path)

class FakeFilteringStage(PipelineStage):
    name = "filtering"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        log(self.name, job['video_id'], f"Applying noise reduction and audio cleanup...")
        time.sleep(config.FAKE_STAGE_DURATION)
        log(self.name, job['video_id'], f"Filtering complete (fake)")
        return StageResult(success=True, output_path=input_path)

class FakeAnalysisStage(PipelineStage):
    name = "analysis"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        log(self.name, job['video_id'], f"Analyzing speech — detecting speakers and language...")
        time.sleep(config.FAKE_STAGE_DURATION)
        log(self.name, job['video_id'], f"Analysis complete (fake) — 1 speaker detected")
        return StageResult(success=True, output_path=input_path)

class FakeSTTStage(PipelineStage):
    name = "stt"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        log(self.name, job['video_id'], f"Transcribing speech to text...")
        time.sleep(config.FAKE_STAGE_DURATION)
        log(self.name, job['video_id'], f"Transcription complete (fake)")
        return StageResult(success=True, output_path=input_path)

class FakeTTSStage(PipelineStage):
    name = "tts"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        log(self.name, job['video_id'], f"Generating dubbed audio in target language...")
        time.sleep(config.FAKE_STAGE_DURATION)
        log(self.name, job['video_id'], f"Dubbed audio generated (fake)")
        return StageResult(success=True, output_path=input_path)

class FakeMergeStage(PipelineStage):
    name = "merge"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        log(self.name, job['video_id'], f"Merging dubbed audio with original video...")
        time.sleep(config.FAKE_STAGE_DURATION)

        # Resolve absolute path for input — it may be relative to API project
        abs_input = input_path if os.path.isabs(input_path) else os.path.abspath(input_path)
        log(self.name, job['video_id'], f"Resolved input path: {abs_input}")

        os.makedirs(config.OUTPUT_DIR, exist_ok=True)
        output_path = os.path.join(config.OUTPUT_DIR, f"{job['video_id']}_dubbed.mp4")

        try:
            if not os.path.exists(abs_input):
                # Try API storage directory
                filename = os.path.basename(input_path)
                abs_input = os.path.join(config.API_STORAGE_DIR, filename)
                log(self.name, job['video_id'], f"Trying API storage path: {abs_input}")

            shutil.copy2(abs_input, output_path)
            log(self.name, job['video_id'], f"Merge complete (fake)")
            log(self.name, job['video_id'], f"Output saved to: {output_path}")
            return StageResult(success=True, output_path=output_path)
        except Exception as e:
            log(self.name, job['video_id'], f"Merge FAILED: {e}")
            return StageResult(success=False, error=str(e))

# ── Real stages (placeholders) ────────────────────────────────────

class AudioSeparationStage(PipelineStage):
    name = "audio_separation"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError("Real audio separation not implemented yet")

class FilteringStage(PipelineStage):
    name = "filtering"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError("Real filtering not implemented yet")

class AnalysisStage(PipelineStage):
    name = "analysis"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError("Real analysis not implemented yet")

class STTStage(PipelineStage):
    name = "stt"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError("Real STT not implemented yet")

class TTSStage(PipelineStage):
    name = "tts"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError("Real TTS not implemented yet")

class MergeStage(PipelineStage):
    name = "merge"
    def run(self, input_path: str, job: dict, work_dir: str) -> StageResult:
        raise NotImplementedError("Real merge not implemented yet")

# ── Factory ───────────────────────────────────────────────────────

def get_pipeline() -> list:
    if config.FAKE_MODE:
        return [
            FakeAudioSeparationStage(),
            FakeFilteringStage(),
            FakeAnalysisStage(),
            FakeSTTStage(),
            FakeTTSStage(),
            FakeMergeStage(),
        ]
    else:
        return [
            AudioSeparationStage(),
            FilteringStage(),
            AnalysisStage(),
            STTStage(),
            TTSStage(),
            MergeStage(),
        ]