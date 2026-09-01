# tyf_backend (Track Your Finances API)

A structured, scalable, and modular **FastAPI** server tailored for clean architecture, robust testing, and automated database initialization.

---

## 📁 Folder Structure

```text
tyf_backend/
├── config/                   # Application configuration & Pydantic Settings
│   ├── __init__.py
│   └── settings.py
├── db/                       # Database logic (engine, sessionmaker, Base, init)
│   ├── __init__.py
│   ├── base.py
│   ├── init_db.py            # Startup DB connectivity & table verification
│   └── session.py
├── endpoints/                # API endpoints grouped by feature
│   ├── __init__.py
│   └── v1/
│       ├── __init__.py
│       ├── router.py         # Main V1 router combining all features
│       ├── auth/             # Authentication & user management
│       │   ├── __init__.py
│       │   └── user.py
│       └── health/           # Health check endpoints
│           ├── __init__.py
│           └── router.py
├── models/                   # SQLAlchemy ORM models
│   └── __init__.py
├── schemas/                  # Pydantic validation schemas
│   ├── __init__.py
│   └── health.py
├── utils/                    # Shared helper utilities & dependencies
│   ├── __init__.py
│   └── db.py
├── tests/                    # Automated testing suite (pytest + httpx)
│   ├── __init__.py
│   ├── conftest.py           # Test fixtures and test client setup
│   ├── test_auth.py          # Auth endpoint test suite
│   ├── test_config.py        # Config and DB connection tests
│   └── test_health.py        # Health endpoint test suite
├── .env                      # Environment variables
├── main.py                   # FastAPI entrypoint & lifespan management
└── requirements.txt          # Python dependencies
```

---

## ⚙️ Environment Variables

Create or update `.env` in the `tyf_backend/` directory:

```env
PROJECT_NAME="tyfbackend"
API_V1_STR="/v1"
DB_CONNECTION="postgresql://postgres:password@localhost:5432/tyf"
```

---

## 🚀 Local Setup & Execution

### 1. Activate Virtual Environment
Using the shared virtual environment in the project root:
```bash
# From tyf_backend/
source ../.venv/bin/activate
```

*(If creating a fresh virtual environment from scratch: `python3 -m venv .venv && source .venv/bin/activate`)*

### 2. Install Dependencies
```bash
pip install -r requirements.txt
```

### 3. Run Development Server
```bash
uvicorn main:app --reload --port 8000
```

---

## 📖 API Documentation

Once the server is running, visit:
- **Swagger UI**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **ReDoc**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)
- **OpenAPI JSON**: [http://127.0.0.1:8000/v1/openapi.json](http://127.0.0.1:8000/v1/openapi.json)

---

## 🧪 Running Tests

Run all unit and integration tests using `pytest`:
```bash
pytest
```
To run tests with detailed verbosity:
```bash
pytest -v
```
