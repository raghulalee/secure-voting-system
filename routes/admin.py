"""
Admin Routes.

Handles election management, candidate management, and monitoring.
"""

from flask import Blueprint, request, jsonify
from services.supabase_client import db
from middleware.auth_guard import require_auth

admin_bp = Blueprint("admin", __name__)


# ── Election Management ─────────────────────────────────────────────

@admin_bp.route("/api/admin/elections", methods=["POST"])
@require_auth(role="admin")
def create_election():
    """Create a new election."""
    try:
        data = request.json
        required = ["title", "election_type", "start_date", "end_date"]
        missing = [f for f in required if not data.get(f)]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

        election_data = {
            "title": data["title"],
            "description": data.get("description", ""),
            "election_type": data["election_type"],
            "start_date": data["start_date"],
            "end_date": data["end_date"],
            "status": data.get("status", "upcoming"),
            "created_by": request.user["sub"],
        }

        result = db.create_election(election_data)
        return jsonify({
            "message": "Election created successfully",
            "election": result.data[0],
        }), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/elections", methods=["GET"])
@require_auth(role="admin")
def list_elections():
    """List all elections."""
    try:
        status = request.args.get("status", None)
        result = db.get_elections(status=status)
        elections = result.data or []

        for election in elections:
            vote_count = db.get_vote_count(election["id"])
            candidates = db.get_candidates(election["id"])
            election["total_votes"] = vote_count.count if vote_count.count else 0
            election["candidate_count"] = len(candidates.data) if candidates.data else 0

        return jsonify({"elections": elections}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/elections/<election_id>", methods=["PUT"])
@require_auth(role="admin")
def update_election(election_id):
    """Update election details or status."""
    try:
        data = request.json
        allowed = ["title", "description", "election_type", "start_date", "end_date", "status"]
        update_data = {k: v for k, v in data.items() if k in allowed}

        if not update_data:
            return jsonify({"error": "No valid fields to update"}), 400

        result = db.update_election(election_id, update_data)
        return jsonify({
            "message": "Election updated",
            "election": result.data[0] if result.data else None,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/elections/<election_id>", methods=["DELETE"])
@require_auth(role="admin")
def delete_election(election_id):
    """Delete an election (only if upcoming)."""
    try:
        election = db.get_election(election_id)
        if not election.data:
            return jsonify({"error": "Election not found"}), 404

        if election.data[0]["status"] not in ("upcoming", "cancelled"):
            return jsonify({"error": "Cannot delete active/completed elections"}), 400

        db.delete_election(election_id)
        return jsonify({"message": "Election deleted"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── Candidate Management ────────────────────────────────────────────

@admin_bp.route("/api/admin/candidates", methods=["POST"])
@require_auth(role="admin")
def add_candidate():
    """Add a candidate to an election."""
    try:
        data = request.json
        required = ["election_id", "name"]
        missing = [f for f in required if not data.get(f)]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

        candidate_data = {
            "election_id": data["election_id"],
            "name": data["name"],
            "party": data.get("party", ""),
            "symbol": data.get("symbol", ""),
            "photo_url": data.get("photo_url", ""),
            "manifesto": data.get("manifesto", ""),
            "position": data.get("position", 0),
            "age": data.get("age"),
            "locality": data.get("locality", ""),
            "timings": data.get("timings", ""),
            "district": data.get("district", ""),
            "state": data.get("state", ""),
        }

        result = db.add_candidate(candidate_data)
        if not result.data:
            return jsonify({"error": "Failed to add candidate"}), 500

        return jsonify({
            "message": "Candidate added successfully",
            "candidate": result.data[0],
        }), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/candidates/<election_id>", methods=["GET"])
@require_auth(role="admin")
def list_candidates(election_id):
    """List candidates for an election."""
    try:
        result = db.get_candidates(election_id)
        return jsonify({"candidates": result.data or []}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/candidates/<candidate_id>", methods=["DELETE"])
@require_auth(role="admin")
def remove_candidate(candidate_id):
    """Remove a candidate."""
    try:
        db.delete_candidate(candidate_id)
        return jsonify({"message": "Candidate removed"}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── Monitoring ───────────────────────────────────────────────────────

@admin_bp.route("/api/admin/voters", methods=["GET"])
@require_auth(role="admin")
def list_voters():
    """List registered voters."""
    try:
        limit = int(request.args.get("limit", 100))
        offset = int(request.args.get("offset", 0))
        result = db.get_all_voters(limit=limit, offset=offset)
        total = db.count_voters()

        return jsonify({
            "voters": result.data or [],
            "total": total.count if total.count else 0,
            "limit": limit,
            "offset": offset,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/logs", methods=["GET"])
@require_auth(role="admin")
def get_logs():
    """Get authentication logs."""
    try:
        limit = int(request.args.get("limit", 50))
        result = db.get_auth_logs(limit=limit)
        return jsonify({"logs": result.data or []}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/dashboard", methods=["GET"])
@require_auth(role="admin")
def dashboard_stats():
    """Get dashboard statistics."""
    try:
        total_voters = db.count_voters()
        all_elections = db.get_elections()
        active_elections = db.get_elections(status="active")

        elections_data = all_elections.data or []
        total_votes = 0
        for election in elections_data:
            vc = db.get_vote_count(election["id"])
            total_votes += vc.count if vc.count else 0

        voted_count = db.count_voted_voters()
        non_voted_count = db.count_non_voted_voters()

        return jsonify({
            "stats": {
                "total_voters": total_voters.count if total_voters.count else 0,
                "voted_voters": voted_count.count if voted_count.count else 0,
                "non_voted_voters": non_voted_count.count if non_voted_count.count else 0,
                "total_elections": len(elections_data),
                "active_elections": len(active_elections.data) if active_elections.data else 0,
                "total_votes_cast": total_votes,
            }
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@admin_bp.route("/api/admin/profile", methods=["PUT"])
@require_auth(role="admin")
def update_admin_profile():
    """Update admin profile details."""
    try:
        admin_id = request.user["sub"]
        data = request.json
        allowed = ["photo_url", "full_name", "email"]
        update_data = {k: v for k, v in data.items() if k in allowed}

        if not update_data:
            return jsonify({"error": "No valid fields to update"}), 400

        result = db.update_admin(admin_id, update_data)
        return jsonify({
            "message": "Admin profile updated successfully",
            "user": result.data[0] if result.data else None
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
