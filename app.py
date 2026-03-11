"""
Secure Online Voting System - Main Application.

Multi-Database Architecture Flask Backend
Serves both API endpoints and the frontend SPA.
"""

import os
from flask import Flask, send_from_directory, jsonify
from flask_cors import CORS
from config import Config

# Import route blueprints
from routes.auth import auth_bp
from routes.voter import voter_bp
from routes.voting import voting_bp
from routes.admin import admin_bp
from routes.results import results_bp

app = Flask(__name__, static_folder="static", static_url_path="")
CORS(app, origins=Config.CORS_ORIGINS.split(",") if Config.CORS_ORIGINS != "*" else "*")


# ── Register Blueprints ─────────────────────────────────────────────

app.register_blueprint(auth_bp)
app.register_blueprint(voter_bp)
app.register_blueprint(voting_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(results_bp)


# ── Frontend Routes ─────────────────────────────────────────────────

@app.route("/")
def serve_index():
    """Serve the SPA index page."""
    return send_from_directory(app.static_folder, "index.html")


@app.route("/<path:path>")
def serve_static(path):
    """Serve static files, fallback to index.html for SPA routing."""
    file_path = os.path.join(app.static_folder, path)
    if os.path.isfile(file_path):
        return send_from_directory(app.static_folder, path)
    return send_from_directory(app.static_folder, "index.html")


# ── Health Check ─────────────────────────────────────────────────────

@app.route("/api/health")
def health():
    return jsonify({
        "status": "healthy",
        "service": "Secure Voting System",
        "version": "1.0.0",
    }), 200


# ── Error Handlers ───────────────────────────────────────────────────

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def server_error(e):
    return jsonify({"error": "Internal server error"}), 500


# ── Main ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("=" * 60)
    print("  🗳️  Secure Online Voting System")
    print("  Multi-Database Architecture")
    print(f"  Running on http://localhost:{Config.PORT}")
    print("=" * 60)
    app.run(
        host="0.0.0.0",
        port=Config.PORT,
        debug=Config.FLASK_ENV == "development",
    )
