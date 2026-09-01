import logging
import sys
import warnings
from contextlib import asynccontextmanager
from pathlib import Path

# Ensure tyf_backend folder is in sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from urllib3.exceptions import NotOpenSSLWarning

from config.settings import settings
from db.init_db import init_db
from endpoints.v1.router import api_router


# Suppress MacOS default LibreSSL urllib3 warning
warnings.filterwarnings("ignore", category=NotOpenSSLWarning)

# Configure logging format
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("tyf-backend")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup actions
    init_db()
    yield
    # Shutdown actions (if any)


app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    lifespan=lifespan,
)

# Set all CORS enabled origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)


