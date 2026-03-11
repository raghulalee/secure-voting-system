"""
Vote Encryption Service.

Uses Fernet symmetric encryption + SHA-256 hashing
to protect vote data and voter identity.
"""

import hashlib
import secrets
from cryptography.fernet import Fernet
from config import Config


class EncryptionService:
    """Handles vote encryption, decryption, and hashing."""

    def __init__(self):
        key = Config.ENCRYPTION_KEY
        if key:
            self.fernet = Fernet(key.encode() if isinstance(key, str) else key)
        else:
            # Generate a key for development (NOT for production)
            generated = Fernet.generate_key()
            self.fernet = Fernet(generated)
            print(f"⚠️  No ENCRYPTION_KEY set. Generated temporary key: {generated.decode()}")

    def encrypt_vote(self, candidate_id: str, election_id: str) -> str:
        """Encrypt vote data."""
        payload = f"{election_id}:{candidate_id}:{secrets.token_hex(16)}"
        return self.fernet.encrypt(payload.encode()).decode()

    def decrypt_vote(self, encrypted_vote: str) -> dict:
        """Decrypt vote data and return components."""
        decrypted = self.fernet.decrypt(encrypted_vote.encode()).decode()
        parts = decrypted.split(":")
        return {"election_id": parts[0], "candidate_id": parts[1]}

    @staticmethod
    def hash_vote(encrypted_vote: str) -> str:
        """Generate unique hash for vote integrity verification."""
        return hashlib.sha256(encrypted_vote.encode()).hexdigest()

    @staticmethod
    def hash_voter_id(voter_id: str, election_id: str) -> str:
        """Hash voter identity for anonymous vote tracking.
        Combines voter_id with election_id to prevent cross-election tracking."""
        combined = f"{voter_id}:{election_id}:{Config.JWT_SECRET}"
        return hashlib.sha256(combined.encode()).hexdigest()

    @staticmethod
    def generate_voter_token() -> str:
        """Generate anonymous voter token for vote receipt."""
        return secrets.token_urlsafe(32)


encryption = EncryptionService()
