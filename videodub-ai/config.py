import os

# ── Mode ─────────────────────────────────────────────────────────
FAKE_MODE = True  # Set to False when real components are ready

# ── API connection ────────────────────────────────────────────────
API_BASE_URL = "http://192.168.18.3:8000"
INTERNAL_API_KEY = "videodub-internal-secret-2024"

# ── Thread pool ───────────────────────────────────────────────────
MAX_CONCURRENT_JOBS = 5
JOB_POLL_INTERVAL = 5
CANCEL_CHECK_INTERVAL = 10

# ── Fake simulation settings ──────────────────────────────────────
FAKE_STAGE_DURATION = 5      # Seconds each fake stage takes

# ── Pipeline stages in order ──────────────────────────────────────
PIPELINE_STAGES = [
    ("audio_separation", 15),
    ("filtering",        30),
    ("analysis",         45),
    ("stt",              60),
    ("tts",              75),
    ("merge",            90),
    ("done",             100),
]

# ── Storage ───────────────────────────────────────────────────────
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORK_DIR = os.path.join(BASE_DIR, "workdir")
OUTPUT_DIR = os.path.join(BASE_DIR, "output")

# ── API storage path (where uploaded videos are saved by the API) ──
API_STORAGE_DIR = os.path.join(BASE_DIR, "..", "videodub-api", "storage")