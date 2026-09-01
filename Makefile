.PHONY: dev run test mobile clean help

help:
	@echo "Track Your Finances (TYF) - Available Commands:"
	@echo "  make dev      - Start the backend server (reload enabled on port 8000)"
	@echo "  make test     - Run backend unit/integration tests"
	@echo "  make mobile   - Run Flutter mobile application"
	@echo "  make clean    - Remove cache directories & temp files"

dev:
	@uvicorn main:app --reload --port 8000

run: dev

test:
	@pytest tyf_backend/tests

mobile:
	@cd tyf_mobile && flutter run

clean:
	@rm -rf .pytest_cache tyf_backend/.pytest_cache
	@find . -type d -name "__pycache__" -exec rm -rf {} +
