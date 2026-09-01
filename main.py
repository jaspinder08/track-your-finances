import sys
from pathlib import Path

# Add tyf_backend and root directory to sys.path
backend_path = Path(__file__).resolve().parent / "tyf_backend"
if str(backend_path) not in sys.path:
    sys.path.insert(0, str(backend_path))

from tyf_backend.main import app  # noqa: E402, F401

if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)

