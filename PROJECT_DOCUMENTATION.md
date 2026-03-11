# 🗳️ Secure Online Voting System - Project Documentation

## 🌟 Overview
The **Secure Online Voting System** is a production-grade, full-stack web application designed for integrity, transparency, and high-performance user experience. It leverages a **Multi-Database Architecture** (logical separation of Voter, Auth, and Ballot data) to ensure top-tier security and privacy.

---

## 🏗️ System Architecture

### 1. Multi-Database Design
The system uses **Supabase (PostgreSQL)** but logically isolates data into three distinct areas:
- **Voter Registry:** Stores personal profiles, residence addresses, and verified identity metadata.
- **Auth Store:** Manages login credentials, hashed passwords, and security logs.
- **Ballot Box:** Handles elections, candidates, encrypted votes, and participation tracking.

### 2. Tech Stack
-   **Backend:** Python 3.11 + Flask (RESTful API)
-   **Database:** Supabase (PostgreSQL)
-   **Frontend:** Single Page Application (SPA) - Vanilla HTML5, CSS3, ES6 JavaScript
-   **Security:** Cryptography (Fernet), Bcrypt (Hashing), PyJWT (Authentication)
-   **deployment:** Render (Production-ready)

---

## 🔒 Security Features

### 🛡️ End-to-End Encryption
Each vote is encrypted using **Fernet symmetric encryption** before it hits the database. Only the system (during result calculation) can decrypt these votes.

### 🎭 Voter Anonymity
To prevent tracking, we use **SHA-256 Hashing**. A voter's identity is combined with a secret salt and the specific election ID to create a unique `voter_hash`. This confirms a person has voted without revealing *how* they voted.

### 🔑 Robust Authentication
-   **Bcrypt Hashing:** Passwords are never stored in plain text.
-   **JWT Tokens:** Secure session management with role-based access control (Admin vs Voter).
-   **Case-Insensitive Login:** Handles mobile auto-capitalization issues (admin vs Admin).

---

## 🚀 Key Features

### 👤 Premium Profiles
-   **Real Image Uploads:** Direct file upload support for profile pictures.
-   **Base64 Storage:** Images are converted and stored as Base64 strings for maximum portability.
-   **Address Management:** Voters can update their official residence for election accuracy.

### 🗳️ Voting Flow
-   **Candidate Metadata:** Rich profiles including age, locality, party symbol, and manifesto.
-   **Automatic Expiry:** Elections transition from "Active" to "Completed" automatically based on the end date.
-   **Vote Receipts:** Users receive an anonymous 12-character receipt and a cryptographic hash of their vote.

### 📊 Admin Dashboard
-   **Advanced Stats:** Real-time tracking of **Total Registered**, **Participated**, and **Not Voted** metrics.
-   **Election Management:** Create, Edit, or Delete upcoming elections.
-   **Candidate Control:** Add candidates with symbols and headshots.

---

## 🛠️ Installation & Setup

### 1. Database Setup
1.  Create a project in **Supabase**.
2.  Open the **SQL Editor**.
3.  Run the [complete_setup_final.sql](complete_setup_final.sql) script. This creates all tables and the default Admin account.

**Default Credentials:**
-   **Admin:** `admin` / `114462`
-   **Voter:** `voter` / `voter`

### 2. Local Environment
1.  Clone the repository.
2.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
3.  Configure your `.env` file with your Supabase URL, Service Key, and JWT Secret.
4.  Run the app:
    ```bash
    python app.py
    ```

---

## ☁️ Deployment (Render)

### 1. Build & Start Commands
-   **Build Command:** `pip install -r requirements.txt`
-   **Start Command:** `gunicorn -b 0.0.0.0:$PORT app:app`

### 2. Environment Variables
Ensure you add these in the Render Dashboard:
-   `SUPABASE_URL`
-   `SUPABASE_SERVICE_KEY`
-   `JWT_SECRET`
-   `ENCRYPTION_KEY`

---

## 📁 File Structure
-   `app.py`: Main entry point and Flask app initialization.
-   `/routes`: API endpoints (Admin, Auth, Voting, Results).
-   `/services`: Core logic (Supabase Client, Encryption Service).
-   `/middleware`: Auth Guards and JWT logic.
-   `/static`: Frontend UI (HTML, CSS, JS).

---

## ⚖️ License & Credits
Developed for **Safe & Secure Online Voting**. Optimized for modern browsers and mobile responsiveness.

**Author:** Raghu & Team
**Theme:** Antigravity (Google Deepmind Inspired)
