# VideoDub

An automatic video dubbing application — upload a video in any language, get it back dubbed in your target language. No manual work needed.

> ⚠️ **Work in Progress** — The frontend and infrastructure are complete. Real AI processing components are currently under development.

---

## 📱 Try the App

**[Download APK (Android)](https://drive.google.com/file/d/1M8n0U9De575-Rmi-BXThbhEjgKr5trsg/view?usp=drive_link)**

Install on any Android device (Android 5.0+). You will need to enable "Install from unknown sources" in your device settings.

> Note: To use the app you need to run the API and AI server locally on your machine. See setup instructions below.

---

## 🏗️ Architecture

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  Flutter App    │ ──HTTP─▶│   FastAPI       │ ──HTTP─▶│   AI Server     │
│  (Android)      │◀──HTTP──│   Backend       │◀──HTTP──│   (Pipeline)    │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

- **Frontend** — Flutter mobile app (Android)
- **API** — FastAPI backend handling uploads, queue, status, downloads
- **AI Server** — Pipeline processor with orchestrator threads per job

All three communicate over HTTP only — they can run on separate machines.

---

## ✅ What's Done

- Flutter mobile app — upload, library, player, settings
- FastAPI backend — upload, validation, queue, status, download, cancel
- AI server management system — job scheduler, orchestrator threads, pipeline architecture
- Fake simulation mode — full end-to-end testing without real AI components
- Notifications when video is ready
- Background polling
- Original/dubbed audio toggle in player
- Download to gallery, share

## 🔧 What's In Progress

- Real AI pipeline components:
  - Audio/video separation
  - Audio filtering
  - Speech analysis
  - Speech to text (STT)
  - Text to speech (TTS)
  - Audio/video merge

---

## 🚀 Local Setup

### Requirements
- Python 3.10+
- Flutter 3.x
- Android device or emulator

### 1. API Server

```bash
cd videodub-api
pip install fastapi uvicorn python-multipart
python main.py
```

Default runs on `http://0.0.0.0:8000`

### 2. AI Server

```bash
cd videodub-ai
pip install requests
python server.py
```

### 3. Configure IP

Find your PC's local IP:
```bash
ipconfig   # Windows
ifconfig   # Mac/Linux
```

Update in `videodub-api/config.py`:
```python
BASE_URL = "http://YOUR_PC_IP:8000"
```

Update in `videodub-ai/config.py`:
```python
API_BASE_URL = "http://YOUR_PC_IP:8000"
```

Update in `videodub-frontend/lib/api_service.dart`:
```dart
static const String _baseUrl = 'http://YOUR_PC_IP:8000';
```

### 4. Mode Switch

In `videodub-api/config.py`:
```python
FAKE_MODE = False  # True = fake simulation, False = real AI server
```

---

## 📁 Project Structure

```
videodub/
├── videodub-frontend/    # Flutter mobile app
├── videodub-api/         # FastAPI backend
│   ├── main.py           # Routes and endpoints
│   ├── queue_manager.py  # Job queue and state
│   └── config.py         # Configuration
└── videodub-ai/          # AI processing server
    ├── server.py         # Job scheduler
    ├── orchestrator.py   # Per-job thread manager
    ├── pipeline.py       # Pipeline stages
    ├── api_client.py     # API communication
    └── config.py         # Configuration
```

---

## 🔑 Internal API Security

The AI server communicates with the API using an internal key. Change this before deploying:

`videodub-api/config.py` and `videodub-ai/config.py`:
```python
INTERNAL_API_KEY = "your-strong-secret-key"
```

---

*Built with Flutter, FastAPI, and Python*