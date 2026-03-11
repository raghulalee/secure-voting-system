"""
Results Routes.

Handles vote counting and result generation.
"""

from flask import Blueprint, request, jsonify
from datetime import datetime, timezone

from services.supabase_client import db
from services.encryption import encryption
from middleware.auth_guard import require_auth

results_bp = Blueprint("results", __name__)


@results_bp.route("/api/results/<election_id>", methods=["GET"])
def get_results(election_id):
    """Get election results (public for completed elections)."""
    try:
        election = db.get_election(election_id)
        if not election.data:
            return jsonify({"error": "Election not found"}), 404

        election_data = election.data[0]

        # Only show results for completed elections (or admin)
        auth_header = request.headers.get("Authorization")
        is_admin = False
        if auth_header and auth_header.startswith("Bearer "):
            try:
                from middleware.auth_guard import decode_token
                token = auth_header.split(" ")[1]
                payload = decode_token(token)
                is_admin = payload.get("role") in ("admin", "super_admin")
            except Exception:
                pass

        # Check if time expired for auto-calculation
        status = election_data["status"]
        if status == "active":
            try:
                # Handle ISO format potentially ending in 'Z' or with timezone
                end_str = election_data["end_date"].replace('Z', '+00:00')
                end_dt = datetime.fromisoformat(end_str)
                if datetime.now(timezone.utc) > end_dt:
                    # Auto-calculate!
                    _do_calculate_results(election_id)
                    election_data["status"] = "completed"
                    status = "completed"
            except Exception as e:
                print(f"Error checking auto-calculate: {e}")

        if status != "completed" and not is_admin:
            return jsonify({"error": "Results not yet available"}), 403

        # Get results
        results = db.get_results(election_id)
        vote_count = db.get_vote_count(election_id)

        return jsonify({
            "election": election_data,
            "results": results.data or [],
            "total_votes": vote_count.count if vote_count.count else 0,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


def _do_calculate_results(election_id):
    """Core logic to calculate results for an election."""
    # Get all encrypted votes
    votes = db.get_votes_for_election(election_id)
    if not votes.data:
        # Mark as completed even if 0 votes
        db.update_election(election_id, {"status": "completed"})
        return 0, []

    # Decrypt and count
    vote_counts = {}
    for vote in votes.data:
        try:
            decrypted = encryption.decrypt_vote(vote["encrypted_vote"])
            candidate_id = decrypted["candidate_id"]
            vote_counts[candidate_id] = vote_counts.get(candidate_id, 0) + 1
        except Exception:
            continue

    total_votes = sum(vote_counts.values())
    max_votes = max(vote_counts.values()) if vote_counts else 0

    results = []
    for candidate_id, count in vote_counts.items():
        percentage = round((count / total_votes * 100), 2) if total_votes > 0 else 0
        result_data = {
            "election_id": election_id,
            "candidate_id": candidate_id,
            "vote_count": count,
            "percentage": percentage,
            "is_winner": count == max_votes and count > 0,
        }
        db.upsert_result(result_data)
        results.append(result_data)

    db.update_election(election_id, {"status": "completed"})
    return total_votes, results

@results_bp.route("/api/results/<election_id>/calculate", methods=["POST"])
@require_auth(role="admin")
def calculate_results(election_id):
    """Calculate and store election results (admin only)."""
    try:
        election = db.get_election(election_id)
        if not election.data:
            return jsonify({"error": "Election not found"}), 404

        total_votes, results = _do_calculate_results(election_id)

        return jsonify({
            "message": "Results calculated successfully",
            "total_votes": total_votes,
            "results": results,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@results_bp.route("/api/results/<election_id>/live", methods=["GET"])
@require_auth(role="admin")
def live_vote_count(election_id):
    """Get live vote count for monitoring (admin only)."""
    try:
        vote_count = db.get_vote_count(election_id)
        election = db.get_election(election_id)
        candidates = db.get_candidates(election_id)

        return jsonify({
            "election": election.data[0] if election.data else None,
            "total_votes": vote_count.count if vote_count.count else 0,
            "total_candidates": len(candidates.data) if candidates.data else 0,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500
