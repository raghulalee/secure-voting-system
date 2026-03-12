"""
Voter Routes.

Handles voter profile operations.
"""

from flask import Blueprint, request, jsonify
from services.supabase_client import db
from middleware.auth_guard import require_auth

voter_bp = Blueprint("voter", __name__)


@voter_bp.route("/api/voter/profile", methods=["GET"])
@require_auth(role="voter")
def get_profile():
    """Get voter profile details."""
    try:
        user = request.user
        result = db.get_voter_by_uuid(user["sub"])
        if not result.data:
            return jsonify({"error": "Profile not found"}), 404

        return jsonify({"profile": result.data[0]}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500





@voter_bp.route("/api/voter/voting-status/<election_id>", methods=["GET"])
@require_auth(role="voter")
def voting_status(election_id):
    """Check if voter has already voted in an election."""
    try:
        user = request.user
        voter = db.get_voter_by_uuid(user["sub"])
        if not voter.data:
            return jsonify({"error": "Voter not found"}), 404

        from services.encryption import encryption
        voter_hash = encryption.hash_voter_id(voter.data[0]["voter_id"], election_id)
        result = db.check_has_voted(election_id, voter_hash)

        return jsonify({
            "has_voted": bool(result.data),
            "election_id": election_id,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
