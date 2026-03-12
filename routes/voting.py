"""
Voting Routes.

Handles the core voting operations: cast vote, verify vote.
"""

from flask import Blueprint, request, jsonify
from datetime import datetime, timezone

from services.supabase_client import db
from services.encryption import encryption
from middleware.auth_guard import require_auth

voting_bp = Blueprint("voting", __name__)


@voting_bp.route("/api/vote/elections", methods=["GET"])
@require_auth()
def list_elections():
    """List elections available to the voter."""
    try:
        status = request.args.get("status", None)
        result = db.get_elections(status=status)
        elections = result.data or []

        # Enrich with candidate count and vote count
        enriched = []
        now = datetime.now(timezone.utc)
        for election in elections:
            # Check if time expired visually
            if election["status"] == "active":
                try:
                    end_str = election["end_date"].replace('Z', '+00:00')
                    end_dt = datetime.fromisoformat(end_str)
                    if now > end_dt:
                        election["status"] = "completed"
                except Exception:
                    pass

            candidates = db.get_candidates(election["id"])
            vote_count = db.get_vote_count(election["id"])
            election["candidate_count"] = len(candidates.data) if candidates.data else 0
            election["total_votes"] = vote_count.count if vote_count.count else 0
            enriched.append(election)

        return jsonify({"elections": enriched}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@voting_bp.route("/api/vote/election/<election_id>", methods=["GET"])
@require_auth()
def get_election_detail(election_id):
    """Get election details with candidates."""
    try:
        election = db.get_election(election_id)
        if not election.data:
            return jsonify({"error": "Election not found"}), 404

        candidates = db.get_candidates(election_id)

        # Check if current voter has voted
        has_voted = False
        user = request.user
        if user.get("role") == "voter":
            voter = db.get_voter_by_uuid(user["sub"])
            if voter.data:
                voter_hash = encryption.hash_voter_id(
                    voter.data[0]["voter_id"], election_id
                )
                voted = db.check_has_voted(election_id, voter_hash)
                has_voted = bool(voted.data)

        return jsonify({
            "election": election.data[0],
            "candidates": candidates.data or [],
            "has_voted": has_voted,
        }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


@voting_bp.route("/api/vote/cast", methods=["POST"])
@require_auth(role="voter")
def cast_vote():
    """Cast an encrypted vote."""
    try:
        data = request.json
        election_id = data.get("election_id")
        candidate_id = data.get("candidate_id")

        if not election_id or not candidate_id:
            return jsonify({"error": "Election ID and Candidate ID required"}), 400

        # Verify election exists and is active
        election = db.get_election(election_id)
        if not election.data:
            return jsonify({"error": "Election not found"}), 404

        if election.data[0]["status"] != "active":
            return jsonify({"error": "Election is not currently active"}), 400

        # Verify candidate belongs to this election
        candidates = db.get_candidates(election_id)
        valid_candidates = [c["id"] for c in (candidates.data or [])]
        if candidate_id not in valid_candidates:
            return jsonify({"error": "Invalid candidate for this election"}), 400

        # Get voter info
        user = request.user
        voter = db.get_voter_by_uuid(user["sub"])
        if not voter.data:
            return jsonify({"error": "Voter profile not found"}), 404

        voter_data = voter.data[0]

        # Check eligibility
        if not voter_data.get("is_eligible", True):
            return jsonify({"error": "You are not eligible to vote"}), 403

        # Check if already voted (using hashed voter identity)
        voter_hash = encryption.hash_voter_id(voter_data["voter_id"], election_id)
        already_voted = db.check_has_voted(election_id, voter_hash)
        if already_voted.data:
            return jsonify({"error": "You have already voted in this election"}), 409

        # Encrypt the vote
        encrypted_vote = encryption.encrypt_vote(candidate_id, election_id)
        vote_hash = encryption.hash_vote(encrypted_vote)
        voter_token = encryption.generate_voter_token()

        # Store encrypted vote (Ballot Box DB)
        vote_data = {
            "election_id": election_id,
            "encrypted_vote": encrypted_vote,
            "vote_hash": vote_hash,
            "voter_token": voter_token,
        }
        res_cast = db.cast_vote(vote_data)
        if not res_cast.data:
            # Check for error message
            err_msg = res_cast.error.get("message") if hasattr(res_cast, "error") and res_cast.error else "Failed to record vote in ballot box"
            return jsonify({"error": err_msg}), 500

        # Track that this voter has voted (anonymous hash only)
        res_track = db.track_vote({
            "election_id": election_id,
            "voter_hash": voter_hash,
        })
        if not res_track.data:
            return jsonify({"error": "Failed to update voter participation tracking"}), 500

        # Update voter record for global participation stats
        res_voter = db.update_voter(user["sub"], {"has_voted": True})
        if not res_voter.data:
            # We don't necessarily fail the whole vote if just the stat update failed, 
            # but it is good to know.
            print(f"Warning: Failed to update global participation flag for voter {user['sub']}")

        return jsonify({
            "message": "Vote cast successfully!",
            "receipt": voter_token[:12] + "...",
            "vote_hash": vote_hash[:16] + "...",
        }), 201

    except Exception as e:
        return jsonify({"error": str(e)}), 500
