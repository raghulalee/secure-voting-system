"""
Authentication Routes.

Handles voter login, registration, and admin login.
"""

from datetime import datetime, timezone
from flask import Blueprint, request, jsonify
from services.supabase_client import db
from services.encryption import encryption
from middleware.auth_guard import (
    create_token, hash_password, verify_password, require_auth
)

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/api/auth/register", methods=["POST"])
def register():
    """Register a new voter."""
    try:
        data = request.json
        required = ["full_name", "voter_id", "email", "date_of_birth", "username", "password"]
        missing = [f for f in required if not data.get(f)]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

        # Check if voter_id already exists
        existing = db.get_voter_by_id(data["voter_id"])
        if existing.data:
            return jsonify({"error": "Voter ID already registered"}), 409

        # Check if username exists
        existing_user = db.get_credentials_by_username(data["username"])
        if existing_user.data:
            return jsonify({"error": "Username already taken"}), 409

        # Check if email exists
        existing_email = db.get_voter_by_email(data["email"])
        if existing_email.data:
            return jsonify({"error": "Email already registered"}), 409

        # Step 1: Create voter profile (Voter Registry DB)
        voter_data = {
            "full_name": data["full_name"],
            "voter_id": data["voter_id"],
            "email": data["email"],
            "phone": data.get("phone", ""),
            "date_of_birth": data["date_of_birth"],
            "gender": data.get("gender", "Other"),
            "address": data.get("address", ""),
            "district": data.get("district", ""),
            "state": data.get("state", "Telangana"),
            "photo_url": data.get("photo_url", ""),
        }
        voter_result = db.create_voter(voter_data)

        if not voter_result.data:
            return jsonify({"error": "Failed to create voter profile"}), 500

        voter_profile = voter_result.data[0]

        # Step 2: Create credentials (Auth Store DB)
        cred_data = {
            "voter_profile_id": voter_profile["id"],
            "username": data["username"],
            "password_hash": hash_password(data["password"]),
        }
        cred_result = db.create_credentials(cred_data)

        if not cred_result.data:
            return jsonify({"error": "Failed to create credentials"}), 500

        # Step 3: Log the registration event
        db.log_auth_event({
            "credential_id": cred_result.data[0]["id"],
            "action": "register",
            "ip_address": request.remote_addr,
            "user_agent": request.headers.get("User-Agent", ""),
            "status": "success",
        })

        return jsonify({
            "message": "Registration successful! You can now login.",
            "voter_id": data["voter_id"],
        }), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@auth_bp.route("/api/auth/login", methods=["POST"])
def login():
    """Voter login."""
    try:
        data = request.json
        username = data.get("username")
        password = data.get("password")

        if not username or not password:
            return jsonify({"error": "Username and password required"}), 400

        # Get credentials from Auth Store DB
        cred_result = db.get_credentials_by_username(username)
        if not cred_result.data:
            return jsonify({"error": "Invalid credentials"}), 401

        cred = cred_result.data[0]

        # Check if account is locked
        if cred.get("locked_until"):
            locked = datetime.fromisoformat(cred["locked_until"].replace("Z", "+00:00"))
            if locked > datetime.now(timezone.utc):
                return jsonify({"error": "Account temporarily locked. Try again later."}), 423

        # Check if account is active
        if not cred.get("is_active", True):
            return jsonify({"error": "Account is deactivated"}), 403

        # Verify password
        if not verify_password(password, cred["password_hash"]):
            # Increment failed attempts
            failed = cred.get("failed_attempts", 0) + 1
            update_data = {"failed_attempts": failed}
            if failed >= 5:
                lock_time = datetime.now(timezone.utc).isoformat()
                update_data["locked_until"] = lock_time

            db.update_credentials(cred["id"], update_data)
            db.log_auth_event({
                "credential_id": cred["id"],
                "action": "login",
                "ip_address": request.remote_addr,
                "user_agent": request.headers.get("User-Agent", ""),
                "status": "failed",
            })
            return jsonify({"error": "Invalid credentials"}), 401

        # Reset failed attempts on successful login
        db.update_credentials(cred["id"], {
            "failed_attempts": 0,
            "locked_until": None,
            "last_login": datetime.now(timezone.utc).isoformat(),
        })

        # Get voter profile
        voter = db.get_voter_by_uuid(cred["voter_profile_id"])
        voter_data = voter.data[0] if voter.data else {}

        # Create JWT token
        token = create_token(
            user_id=cred["voter_profile_id"],
            role="voter",
            extra={
                "username": username,
                "voter_id": voter_data.get("voter_id", ""),
                "name": voter_data.get("full_name", ""),
            }
        )

        # Log successful login
        db.log_auth_event({
            "credential_id": cred["id"],
            "action": "login",
            "ip_address": request.remote_addr,
            "user_agent": request.headers.get("User-Agent", ""),
            "status": "success",
        })

        return jsonify({
            "message": "Login successful",
            "token": token,
            "user": {
                "id": cred["voter_profile_id"],
                "username": username,
                "full_name": voter_data.get("full_name", ""),
                "voter_id": voter_data.get("voter_id", ""),
                "email": voter_data.get("email", ""),
                "is_verified": voter_data.get("is_verified", False),
            }
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@auth_bp.route("/api/auth/admin/login", methods=["POST"])
def admin_login():
    """Admin login."""
    try:
        data = request.json
        username = data.get("username")
        password = data.get("password")

        if not username or not password:
            return jsonify({"error": "Username and password required"}), 400

        result = db.get_admin_by_username(username)
        if not result.data:
            return jsonify({"error": "Invalid admin credentials"}), 401

        admin = result.data[0]

        if not verify_password(password, admin["password_hash"]):
            return jsonify({"error": "Invalid admin credentials"}), 401

        token = create_token(
            user_id=admin["id"],
            role=admin["role"],
            extra={"name": admin["full_name"]}
        )

        return jsonify({
            "message": "Admin login successful",
            "token": token,
            "user": {
                "id": admin["id"],
                "username": admin["username"],
                "full_name": admin["full_name"],
                "role": admin["role"],
            }
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@auth_bp.route("/api/auth/me", methods=["GET"])
@require_auth()
def get_me():
    """Get current user profile."""
    try:
        user = request.user
        role = user.get("role", "voter")

        if role == "voter":
            voter = db.get_voter_by_uuid(user["sub"])
            if not voter.data:
                return jsonify({"error": "Profile not found"}), 404
            profile = voter.data[0]
            profile.pop("id", None)
            return jsonify({"user": profile, "role": role}), 200
        else:
            return jsonify({
                "user": {
                    "id": user["sub"],
                    "name": user.get("name", ""),
                    "role": role,
                },
                "role": role,
            }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
