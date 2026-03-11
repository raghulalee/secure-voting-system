import os
from dotenv import load_dotenv

load_dotenv()


class Config:
    """Application configuration from environment variables."""

    # Supabase
    SUPABASE_URL = os.getenv("SUPABASE_URL")
    SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
    SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")

    # JWT
    JWT_SECRET = os.getenv("JWT_SECRET", "dev-secret-change-in-production")
    JWT_EXPIRY_HOURS = int(os.getenv("JWT_EXPIRY_HOURS", "24"))

    # Encryption
    ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY")

    # Flask
    FLASK_ENV = os.getenv("FLASK_ENV", "production")
    PORT = int(os.getenv("PORT", "5000"))
    CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")

    @classmethod
    def validate(cls):
        """Validate required configuration."""
        required = ["SUPABASE_URL", "SUPABASE_SERVICE_KEY"]
        missing = [k for k in required if not getattr(cls, k)]
        if missing:
            raise ValueError(f"Missing required config: {', '.join(missing)}")
