from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Atma'en API"
    database_url: str = "sqlite:///./atmaen.db"

    secret_key: str = "dev-only-secret-do-not-use-in-production-0001"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 720

    cors_origins: str = "http://localhost:5173"

    upload_dir: str = "uploads"
    image_model_path: str = "models_store/chemical_classifier.keras"

    admin_email: str = "admin@atmaen.sa"
    admin_password: str = "Admin@12345"

    # Saudi Red Crescent. kept in config so we can change per country later
    emergency_number: str = "997"
    medical_line_number: str = "937"  # MOH medical consultation line

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
