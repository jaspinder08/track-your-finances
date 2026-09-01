from config.settings import settings
from db.session import engine, SessionLocal, get_db


def test_settings_load():
    assert settings.PROJECT_NAME in ["TYF - Track Your Finances", "tyfbackend"]
    assert settings.API_V1_STR == "/v1"
    assert settings.DB_CONNECTION is not None



def test_get_db_generator():
    db_gen = get_db()
    assert db_gen is not None
