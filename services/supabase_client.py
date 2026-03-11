"""
Supabase Multi-Database Client Service.

Provides isolated access to three logical databases:
  - Voter Registry (voter_profiles)
  - Auth Store (voter_credentials, auth_logs, admin_users)
  - Ballot Box (elections, candidates, votes, vote_tracking, election_results)
"""

from supabase import create_client, Client, ClientOptions
from config import Config


class SupabaseClient:
    """Singleton Supabase client with multi-database access patterns."""

    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance.client = create_client(
                Config.SUPABASE_URL, 
                Config.SUPABASE_SERVICE_KEY,
                options=ClientOptions(
                    postgrest_client_timeout=30,
                    storage_client_timeout=30
                )
            )
        return cls._instance

    # ── Voter Registry Database ──────────────────────────────────────

    def get_voter_by_id(self, voter_id: str):
        return (
            self.client.table("voters")
            .select("*")
            .eq("voter_id", voter_id)
            .execute()
        )

    def get_voter_by_email(self, email: str):
        return (
            self.client.table("voters")
            .select("*")
            .eq("email", email)
            .execute()
        )

    def get_voter_by_uuid(self, uuid: str):
        return (
            self.client.table("voters")
            .select("*")
            .eq("id", uuid)
            .execute()
        )

    def create_voter(self, data: dict):
        return self.client.table("voters").insert(data).execute()

    def update_voter(self, uuid: str, data: dict):
        return (
            self.client.table("voters")
            .update(data)
            .eq("id", uuid)
            .execute()
        )

    def get_all_voters(self, limit=100, offset=0):
        return (
            self.client.table("voters")
            .select("*")
            .range(offset, offset + limit - 1)
            .order("created_at", desc=True)
            .execute()
        )

    def count_voters(self):
        return (
            self.client.table("voters")
            .select("id", count="exact")
            .execute()
        )

    # ── Authentication Database ──────────────────────────────────────

    def get_credentials_by_username(self, username: str):
        return (
            self.client.table("credentials")
            .select("*")
            .eq("username", username)
            .execute()
        )

    def get_credentials_by_profile(self, profile_id: str):
        return (
            self.client.table("credentials")
            .select("*")
            .eq("voter_profile_id", profile_id)
            .execute()
        )

    def create_credentials(self, data: dict):
        return self.client.table("credentials").insert(data).execute()

    def update_credentials(self, cred_id: str, data: dict):
        return (
            self.client.table("credentials")
            .update(data)
            .eq("id", cred_id)
            .execute()
        )

    def log_auth_event(self, data: dict):
        return self.client.table("auth_logs").insert(data).execute()

    def get_auth_logs(self, limit=50):
        return (
            self.client.table("auth_logs")
            .select("*")
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )

    # ── Admin Authentication ─────────────────────────────────────────

    def get_admin_by_username(self, username: str):
        return (
            self.client.table("admin_users")
            .select("*")
            .eq("username", username)
            .execute()
        )

    def update_admin(self, admin_id: str, data: dict):
        return (
            self.client.table("admin_users")
            .update(data)
            .eq("id", admin_id)
            .execute()
        )

    def update_admin_login(self, admin_id: str):
        return (
            self.client.table("admin_users")
            .update({"last_login": "now()"})
            .eq("id", admin_id)
            .execute()
        )

    # ── Ballot Box Database ──────────────────────────────────────────

    def create_election(self, data: dict):
        return self.client.table("elections").insert(data).execute()

    def get_elections(self, status=None):
        query = self.client.table("elections").select("*")
        if status:
            query = query.eq("status", status)
        return query.order("created_at", desc=True).execute()

    def get_election(self, election_id: str):
        return (
            self.client.table("elections")
            .select("*")
            .eq("id", election_id)
            .execute()
        )

    def update_election(self, election_id: str, data: dict):
        return (
            self.client.table("elections")
            .update(data)
            .eq("id", election_id)
            .execute()
        )

    def delete_election(self, election_id: str):
        return (
            self.client.table("elections")
            .delete()
            .eq("id", election_id)
            .execute()
        )

    # Candidates
    def add_candidate(self, data: dict):
        return self.client.table("candidates").insert(data).execute()

    def get_candidates(self, election_id: str):
        return (
            self.client.table("candidates")
            .select("*")
            .eq("election_id", election_id)
            .order("position")
            .execute()
        )

    def delete_candidate(self, candidate_id: str):
        return (
            self.client.table("candidates")
            .delete()
            .eq("id", candidate_id)
            .execute()
        )

    # Votes
    def cast_vote(self, data: dict):
        return self.client.table("votes").insert(data).execute()

    def track_vote(self, data: dict):
        return self.client.table("vote_tracking").insert(data).execute()

    def check_has_voted(self, election_id: str, voter_hash: str):
        return (
            self.client.table("vote_tracking")
            .select("*")
            .eq("election_id", election_id)
            .eq("voter_hash", voter_hash)
            .execute()
        )

    def get_votes_for_election(self, election_id: str):
        return (
            self.client.table("votes")
            .select("*")
            .eq("election_id", election_id)
            .execute()
        )

    def get_vote_count(self, election_id: str):
        return (
            self.client.table("vote_tracking")
            .select("id", count="exact")
            .eq("election_id", election_id)
            .execute()
        )

    # Results
    def upsert_result(self, data: dict):
        return self.client.table("election_results").upsert(data).execute()

    def get_results(self, election_id: str):
        return (
            self.client.table("election_results")
            .select("*, candidates(*)")
            .eq("election_id", election_id)
            .order("vote_count", desc=True)
            .execute()
        )


# Singleton accessor
db = SupabaseClient()
