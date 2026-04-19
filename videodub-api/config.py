# ── Mode ─────────────────────────────────────────────────────────
FAKE_MODE = False  # Set to False when real AI server is ready

# ── Fake mode settings ────────────────────────────────────────────
FAKE_DUBBED_VIDEO_PATH = r"C:\Users\sawar\Downloads\Videos\id1_one_person_dubbed_via_heygen.mp4"

FAKE_JOB_DURATION = 120
FAKE_PROGRESS_INTERVAL = 30
FAKE_PROGRESS_STEPS = [20, 40, 60, 80, 100]

# ── Queue settings ────────────────────────────────────────────────
MAX_QUEUE_SIZE = 10          # Total jobs in InQueue at once
MAX_CONCURRENT_JOBS = 5      # Max jobs AI server processes at same time (half of buffer)

# ── File validation ───────────────────────────────────────────────
ALLOWED_EXTENSIONS = {".mp4", ".mov", ".avi", ".mkv"}
ALLOWED_MIME_TYPES = {
    "video/mp4",
    "video/quicktime",
    "video/x-msvideo",
    "video/x-matroska",
    "video/avi",
    "application/octet-stream",
}
MAX_FILE_SIZE_MB = 500
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024

# ── Storage ───────────────────────────────────────────────────────
UPLOAD_DIR = "storage"
DUBBED_DIR = "dubbed"

# ── Internal API security ─────────────────────────────────────────
# AI server must send this key in header: X-Internal-Key
# Change this to a strong secret in production
INTERNAL_API_KEY = "videodub-internal-secret-2024"

# ── Pipeline stages ───────────────────────────────────────────────
PIPELINE_STAGES = [
    "audio_separation",   # 15%
    "filtering",          # 30%
    "analysis",           # 45%
    "stt",                # 60%
    "tts",                # 75%
    "merge",              # 90%
    "done",               # 100%
]

STAGE_PROGRESS = {
    "audio_separation": 15,
    "filtering": 30,
    "analysis": 45,
    "stt": 60,
    "tts": 75,
    "merge": 90,
    "done": 100,
}

# ── Server ───────────────────────────────────────────────────────
BASE_URL = "http://192.168.18.3:8000"
HOST = "0.0.0.0"
PORT = 8000