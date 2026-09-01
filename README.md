# Track Your Finances (TYF)

**Track Your Finances (TYF)** is a full-stack personal finance and expense tracking ecosystem consisting of a high-performance **FastAPI backend** and a cross-platform **Flutter mobile app**.

---

## 🏗 Project Architecture

```text
TYF/
├── tyf_backend/       # FastAPI REST API & Database Layer
├── tyf_mobile/        # Flutter Cross-Platform Mobile Application
├── .venv/             # Shared Python virtual environment
└── README.md          # Workspace root guide (this file)
```

| Component | Stack | Description |
| :--- | :--- | :--- |
| **`tyf_backend`** | Python 3.9+, FastAPI, SQLAlchemy, PostgreSQL, Pytest | RESTful API server handling business logic, authentication, and database persistence. |
| **`tyf_mobile`** | Flutter 3.x, Dart 3.8+ | Native iOS and Android mobile app providing a clean and intuitive user interface. |

---

## 🚀 Quick Start

### 1. Prerequisites
- **Python**: `3.9+`
- **PostgreSQL**: `14+` running locally or via Docker
- **Flutter SDK**: `3.x` with Dart `3.8+`
- **Xcode** (for iOS simulator) / **Android Studio** (for Android emulator)

---

### 2. Running the Backend (`tyf_backend`)

You can use any of these ultra-short commands from the project root `TYF/`:

```bash
# Option 1: Direct launcher script (automatically activates venv)
./dev

# Option 2: Make shortcut
make dev

# Option 3: Python directly
python main.py
```

Or using standard `uvicorn`:
```bash
uvicorn main:app --reload --port 8000
```

- **API URL**: `http://127.0.0.1:8000`
- **Interactive Swagger Docs**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **ReDoc**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)

👉 See [tyf_backend/README.md](file:///Users/jassi/Desktop/Personal/TYF/tyf_backend/README.md) for full backend documentation.


---

### 3. Running the Mobile App (`tyf_mobile`)

```bash
# Navigate to mobile directory
cd tyf_mobile

# Get dependencies
flutter pub get

# Run on connected device or simulator
flutter run
```

👉 See [tyf_mobile/README.md](file:///Users/jassi/Desktop/Personal/TYF/tyf_mobile/README.md) for full mobile documentation.

---

## 🧪 Testing

### Backend Tests
```bash
cd tyf_backend
pytest
```

### Mobile Tests
```bash
cd tyf_mobile
flutter test
```

---

## 📄 License
Private & Proprietary. All rights reserved.
