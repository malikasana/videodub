import time
import queue
import threading
import sys

_log_queue = queue.Queue()
_stop = threading.Event()

def _writer():
    while not _stop.is_set() or not _log_queue.empty():
        try:
            msg = _log_queue.get(timeout=1)
            sys.stdout.write(msg + "\n")
            sys.stdout.flush()
        except queue.Empty:
            continue

_writer_thread = threading.Thread(target=_writer, daemon=True, name="logger")
_writer_thread.start()

def log(tag: str, msg: str):
    _log_queue.put(f"[{time.strftime('%H:%M:%S')}] [{tag}] {msg}")