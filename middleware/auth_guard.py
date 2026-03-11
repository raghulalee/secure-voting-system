"""
JWT Authentication Middleware.

Provides decorators for protecting routes with JWT tokens.
"""

import functools
from datetime import datetime, timedelta, timezone

import jwt
import bcrypt
from flask import request, jsonify
from config import Config


def create_token(user_id: str, role: str = "voter", extra: dict = None) -> str:
    """Create a JWT token."""
    payload = {
        "sub": user_id,
        "role": role,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(hours=Config.JWT_EXPIRY_HOURS),
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, Config.JWT_SECRET, algorithm="HS256")


def decode_token(token: str) -> dict:
    """Decode and verify a JWT token."""
    return jwt.decode(token, Config.JWT_SECRET, algorithms=["HS256"])


def hash_password(password: str) -> str:
    """Hash a password with bcrypt."""
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def verify_password(password: str, hashed: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(password.encode(), hashed.encode())


def require_auth(role=None):
    """Decorator to require JWT authentication on a route.

    Args:
        role: Optional required role ('voter', 'admin', 'super_admin')
    """

    def decorator(f):
        @functools.wraps(f)
        def wrapper(*args, **kwargs):
            auth_header = request.headers.get("Authorization")
            if not auth_header or not auth_header.startswith("Bearer "):
                return jsonify({"error": "Missing or invalid authorization header"}), 401

            token = auth_header.split(" ")[1]
            try:
                payload = decode_token(token)
            except jwt.ExpiredSignatureError:
                return jsonify({"error": "Token has expired"}), 401
            except jwt.InvalidTokenError:
                return jsonify({"error": "Invalid token"}), 401

            if role and payload.get("role") != role:
                if role == "admin" and payload.get("role") == "super_admin":
                    pass  # super_admin can access admin routes
                else:
                    return jsonify({"error": "Insufficient permissions"}), 403

            request.user = payload
            return f(*args, **kwargs)

        return wrapper

    return decorator
