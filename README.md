# 🗳️ Secure Online Voting System

**Multi-Database Architecture | KITS — Batch C10**

A production-grade secure online voting platform built with Python Flask and Supabase, featuring encrypted votes, JWT authentication, and a professional dark-theme SPA frontend.

---

## 🏗️ Architecture

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Voter       │    │  Auth        │    │  Ballot Box  │
│  Registry DB │    │  Store DB    │    │  DB          │
├──────────────┤    ├──────────────┤    ├──────────────┤
│voter_profiles│    │voter_creds   │    │elections     │
│              │    │auth_logs     │    │candidates    │
│              │    │admin_users   │    │votes (enc.)  │
│              │    │              │    │vote_tracking │
└──────────────┘    └──────────────┘    └──────────────┘
        ↕                  ↕                    ↕
    ┌─────────────────────────────────────────────┐
    │          Flask Backend (Python)              │
    │   JWT Auth · Fernet Encryption · CORS       │
    └─────────────────────────────────────────────┘
                         ↕
    ┌─────────────────────────────────────────────┐
    │         Frontend SPA (HTML/CSS/JS)          │
    │   Dark Theme · Responsive · Chart.js        │
    └─────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### 1. Setup Supabase Database

1. Create a project at [supabase.com](https://supabase.com)
2. Go to **SQL Editor** → **New Query**
3. Copy the entire contents of `supabase_schema.sql` and **Run**
4. Copy your credentials from **Settings → API**:
   - Project URL
   - `service_role` key (secret)
   - `anon` key

### 2. Configure Environment

```bash
cd secure-voting-system
copy .env.example .env
```

Edit `.env` with your Supabase credentials:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key
JWT_SECRET=your-random-secret-min-32-chars
```

Generate an encryption key:
```bash
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```
Paste the output as `ENCRYPTION_KEY` in `.env`.

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Run Locally

```bash
python app.py
```

Open **http://localhost:5000** in your browser.

### 5. Default Admin Login

- **Username:** `admin`
- **Password:** `admin123`

> ⚠️ Change this immediately in production!

---

## 📁 Project Structure

```
secure-voting-system/
├── app.py                  # Main Flask application
├── config.py               # Environment configuration
├── requirements.txt        # Python dependencies
├── Procfile                # Gunicorn for production
├── render.yaml             # Render deployment config
├── supabase_schema.sql     # Database schema (run in Supabase)
├── .env.example            # Environment template
│
├── services/
│   ├── supabase_client.py  # Multi-DB Supabase service
│   └── encryption.py       # Vote encryption (Fernet + SHA-256)
│
├── routes/
│   ├── auth.py             # Login, register, admin login
│   ├── voter.py            # Voter profile operations
│   ├── voting.py           # Cast vote, list elections
│   ├── admin.py            # Election & candidate CRUD
│   └── results.py          # Vote counting & results
│
├── middleware/
│   └── auth_guard.py       # JWT auth & role-based access
│
└── static/
    ├── index.html           # SPA with all views
    ├── css/styles.css       # Dark theme with glassmorphism
    └── js/
        ├── config.js        # API configuration
        ├── api.js           # HTTP client with JWT
        └── app.js           # Router, auth, all page logic
```

---

## 🌐 Deploy to Render

1. Push code to GitHub
2. Go to [render.com](https://render.com) → **New Web Service**
3. Connect your repo
4. Set **Build Command:** `pip install -r requirements.txt`
5. Set **Start Command:** `gunicorn app:app --bind 0.0.0.0:$PORT --workers 4`
6. Add environment variables from `.env`
7. Deploy!

---

## 🔒 Security Features

| Feature | Implementation |
|---------|---------------|
| Vote Encryption | Fernet symmetric encryption |
| Voter Anonymity | SHA-256 hashed voter tokens |
| Authentication | JWT with bcrypt passwords |
| Account Lockout | After 5 failed login attempts |
| Multi-DB Separation | Voter/Auth/Ballot data isolated |
| Tamper Prevention | Unique vote hash per ballot |
| HTTPS | Enforced via Render/Supabase |

---

## 📋 API Endpoints

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register` | — | Register voter |
| POST | `/api/auth/login` | — | Voter login |
| POST | `/api/auth/admin/login` | — | Admin login |
| GET | `/api/auth/me` | JWT | Get profile |
| GET | `/api/voter/profile` | Voter | Get voter profile |
| GET | `/api/vote/elections` | JWT | List elections |
| POST | `/api/vote/cast` | Voter | Cast encrypted vote |
| POST | `/api/admin/elections` | Admin | Create election |
| POST | `/api/admin/candidates` | Admin | Add candidate |
| GET | `/api/admin/dashboard` | Admin | Dashboard stats |
| POST | `/api/results/{id}/calculate` | Admin | Count votes |
| GET | `/api/results/{id}` | — | View results |

---

*Built for KITS CSE Department — Batch C10*
