/* ═══════════════════════════════════════════════════════════════
   KITS VoteSecure — Main Application
   SPA Router, Auth State, Page Logic
   ═══════════════════════════════════════════════════════════════ */

// ── State ───────────────────────────────────────────────────────
let currentUser = null;
let currentRole = null;  // 'voter' | 'admin' | 'super_admin'
let selectedCandidateId = null;
let selectedElectionId = null;
let resultChart = null;
let allElections = [];

// ── Init ────────────────────────────────────────────────────────
document.addEventListener("DOMContentLoaded", () => {
    initApp();
});

async function initApp() {
    // Check stored session
    const token = localStorage.getItem("token");
    const storedUser = localStorage.getItem("user");
    if (token && storedUser) {
        try {
            currentUser = JSON.parse(storedUser);
            currentRole = currentUser.role || "voter";
            updateNavForUser();
        } catch { handleLogout(); }
    }

    // Setup nav toggle
    document.getElementById("navToggle").addEventListener("click", () => {
        document.getElementById("navMenu").classList.toggle("open");
    });

    // Close nav on link click (mobile)
    document.querySelectorAll(".nav-link").forEach(link => {
        link.addEventListener("click", () => {
            document.getElementById("navMenu").classList.remove("open");
        });
    });

    // User dropdown
    const userBtn = document.getElementById("userMenuBtn");
    if (userBtn) {
        userBtn.addEventListener("click", (e) => {
            e.stopPropagation();
            document.getElementById("userDropdown").classList.toggle("show");
        });
        document.addEventListener("click", () => {
            document.getElementById("userDropdown").classList.remove("show");
        });
    }

    // Route
    handleRoute();
    window.addEventListener("hashchange", handleRoute);

    // Hide loader
    setTimeout(() => {
        document.getElementById("loader").classList.add("hidden");
    }, 800);

    // Load stats for home page
    loadHomeStats();
}

// ── Router ──────────────────────────────────────────────────────
function handleRoute() {
    const hash = window.location.hash.replace("#", "") || "/";
    const routes = {
        "/": "home",
        "/login": "login",
        "/register": "register",
        "/admin-login": "admin-login",
        "/dashboard": "dashboard",
        "/elections": "elections",
        "/vote": "vote",
        "/results": "results",
        "/admin": "admin",
    };

    // Check for vote page with election ID
    let page = routes[hash];
    if (!page && hash.startsWith("/vote/")) {
        page = "vote";
        selectedElectionId = hash.split("/vote/")[1];
    }
    if (!page && hash.startsWith("/results/")) {
        page = "results";
    }

    if (!page) page = "home";

    // Auth guards
    const protectedPages = ["dashboard", "elections", "vote"];
    const adminPages = ["admin"];

    if (protectedPages.includes(page) && !currentUser) {
        navigateTo("/login");
        return;
    }
    if (adminPages.includes(page) && !["admin", "super_admin"].includes(currentRole)) {
        navigateTo("/admin-login");
        return;
    }

    showPage(page);
    updateActiveNav(hash);
    loadPageData(page);
}

function showPage(pageId) {
    document.querySelectorAll(".page").forEach(p => p.classList.remove("active"));
    const target = document.getElementById(`page-${pageId}`);
    if (target) target.classList.add("active");
    window.scrollTo(0, 0);
}

function navigateTo(path) {
    window.location.hash = `#${path}`;
}

function updateActiveNav(hash) {
    document.querySelectorAll(".nav-link").forEach(link => {
        link.classList.remove("active");
        if (link.getAttribute("data-page") === hash.replace("/", "")) {
            link.classList.add("active");
        }
    });
}

function updateNavForUser() {
    const loginBtn = document.getElementById("navLoginBtn");
    const userMenu = document.getElementById("navUserMenu");
    const navElections = document.getElementById("navElections");
    const navDashboard = document.getElementById("navDashboard");
    const navResults = document.getElementById("navResults");
    const navAdmin = document.getElementById("navAdmin");

    if (currentUser) {
        loginBtn.style.display = "none";
        userMenu.style.display = "block";
        document.getElementById("userName").textContent = currentUser.full_name || currentUser.username || "User";
        
        // Dynamic User Avatar
        const avatarUrl = currentUser.photo_url || "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=100&q=80";
        document.getElementById("userAvatar").innerHTML = `<img src="${esc(avatarUrl)}" alt="Profile" style="width:100%; height:100%; object-fit:cover; border-radius:50%; border: 2px solid var(--accent-primary);">`;

        if (currentRole === "voter") {
            navElections.style.display = "block";
            navDashboard.style.display = "block";
            navResults.style.display = "block";
            navAdmin.style.display = "none";
        } else {
            navElections.style.display = "block";
            navDashboard.style.display = "none";
            navResults.style.display = "block";
            navAdmin.style.display = "block";
        }
    } else {
        loginBtn.style.display = "block";
        userMenu.style.display = "none";
        navElections.style.display = "none";
        navDashboard.style.display = "none";
        navResults.style.display = "none";
        navAdmin.style.display = "none";
    }
}

// ── Auth Handlers ───────────────────────────────────────────────
async function handleLogin(e) {
    e.preventDefault();
    const btn = document.getElementById("loginBtn");
    const errEl = document.getElementById("loginError");
    setLoading(btn, true);
    errEl.textContent = "";

    try {
        const data = await API.post("/api/auth/login", {
            username: document.getElementById("loginUsername").value,
            password: document.getElementById("loginPassword").value,
        });

        localStorage.setItem("token", data.token);
        localStorage.setItem("user", JSON.stringify({ ...data.user, role: "voter" }));
        currentUser = { ...data.user, role: "voter" };
        currentRole = "voter";
        updateNavForUser();
        showToast("Login successful! Welcome back.", "success");
        navigateTo("/dashboard");
    } catch (err) {
        errEl.textContent = err.message;
    } finally {
        setLoading(btn, false);
    }
}

async function handleRegister(e) {
    e.preventDefault();
    const btn = document.getElementById("registerBtn");
    const errEl = document.getElementById("registerError");
    const successEl = document.getElementById("registerSuccess");
    setLoading(btn, true);
    errEl.textContent = "";
    successEl.textContent = "";

    try {
        const data = await API.post("/api/auth/register", {
            full_name: document.getElementById("regName").value,
            voter_id: document.getElementById("regVoterId").value,
            email: document.getElementById("regEmail").value,
            phone: document.getElementById("regPhone").value,
            date_of_birth: document.getElementById("regDob").value,
            gender: document.getElementById("regGender").value,
            address: document.getElementById("regAddress").value,
            district: document.getElementById("regDistrict").value,
            state: document.getElementById("regState").value,
            username: document.getElementById("regUsername").value,
            password: document.getElementById("regPassword").value,
            photo_url: document.getElementById("regPhoto").value || "",
        });

        successEl.textContent = data.message;
        showToast("Registration successful! You can now login.", "success");
        document.getElementById("registerForm").reset();
        setTimeout(() => navigateTo("/login"), 2000);
    } catch (err) {
        errEl.textContent = err.message;
    } finally {
        setLoading(btn, false);
    }
}

async function handleAdminLogin(e) {
    e.preventDefault();
    const btn = document.getElementById("adminLoginBtn");
    const errEl = document.getElementById("adminLoginError");
    setLoading(btn, true);
    errEl.textContent = "";

    try {
        const data = await API.post("/api/auth/admin/login", {
            username: document.getElementById("adminUsername").value,
            password: document.getElementById("adminPassword").value,
        });

        localStorage.setItem("token", data.token);
        localStorage.setItem("user", JSON.stringify({ ...data.user }));
        currentUser = { ...data.user };
        currentRole = data.user.role;
        updateNavForUser();
        showToast("Admin login successful!", "success");
        navigateTo("/admin");
    } catch (err) {
        errEl.textContent = err.message;
    } finally {
        setLoading(btn, false);
    }
}

function handleLogout() {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    currentUser = null;
    currentRole = null;
    updateNavForUser();
    navigateTo("/");
    showToast("Logged out successfully.", "info");
}

// ── Page Data Loaders ───────────────────────────────────────────
async function loadPageData(page) {
    try {
        switch (page) {
            case "dashboard": await loadDashboard(); break;
            case "elections": await loadElections(); break;
            case "vote": await loadVotePage(); break;
            case "results": await loadResults(); break;
            case "admin": await loadAdmin(); break;
        }
    } catch (err) {
        console.error(`Error loading ${page}:`, err);
    }
}

async function loadHomeStats() {
    try {
        const data = await API.get("/api/health");
        // Stats will show when backend is connected
    } catch { /* Backend not connected yet */ }
}

// ── Dashboard ───────────────────────────────────────────────────
async function loadDashboard() {
    if (!currentUser) return;

    document.getElementById("dashName").textContent = currentUser.full_name || "Voter";
    document.getElementById("dashVoterId").textContent = currentUser.voter_id || "N/A";

    try {
        const data = await API.get("/api/vote/elections");
        const elections = data.elections || [];

        // Active Elections
        const active = elections.filter(e => e.status === "active");
        const activeEl = document.getElementById("dashActiveElections");
        if (active.length === 0) {
            activeEl.innerHTML = '<div class="empty-state">No active elections at this time</div>';
        } else {
            activeEl.innerHTML = active.map(e => `
                <div class="election-card" style="margin-bottom:12px">
                    <div class="election-card-header">
                        <h4>${esc(e.title)}</h4>
                        <span class="election-status status-active">Active</span>
                    </div>
                    <p>${esc(e.description || "")}</p>
                    <div class="election-meta">
                        <span>📅 Ends: ${formatDate(e.end_date)}</span>
                        <span>👥 ${e.candidate_count} candidates</span>
                    </div>
                    <button class="btn btn-primary btn-sm" onclick="navigateTo('/vote/${e.id}')">Vote Now →</button>
                </div>
            `).join("");
        }

        // Completed elections
        const completed = elections.filter(e => e.status === "completed");
        const completedEl = document.getElementById("dashCompletedElections");
        if (completed.length === 0) {
            completedEl.innerHTML = '<div class="empty-state">No completed elections yet</div>';
        } else {
            completedEl.innerHTML = completed.map(e => `
                <div class="election-card" style="margin-bottom:12px">
                    <h4>${esc(e.title)}</h4>
                    <div class="election-meta"><span>📊 ${e.total_votes} votes</span></div>
                    <button class="btn btn-glass btn-sm" onclick="viewResult('${e.id}')">View Results</button>
                </div>
            `).join("");
        }

        // Vote history (check each active/completed election)
        const historyEl = document.getElementById("dashVoteHistory");
        let historyHtml = "";
        for (const e of elections) {
            try {
                const vs = await API.get(`/api/voter/voting-status/${e.id}`);
                if (vs.has_voted) {
                    historyHtml += `<div class="election-card" style="margin-bottom:8px">
                        <h4>✅ ${esc(e.title)}</h4>
                        <span class="election-status status-completed">Voted</span>
                    </div>`;
                }
            } catch { /* skip */ }
        }
        historyEl.innerHTML = historyHtml || '<div class="empty-state">No votes cast yet</div>';

    } catch (err) {
        showToast("Error loading dashboard: " + err.message, "error");
    }
}

// ── Elections ───────────────────────────────────────────────────
async function loadElections() {
    try {
        const data = await API.get("/api/vote/elections");
        allElections = data.elections || [];
        renderElections(allElections);
    } catch (err) {
        document.getElementById("electionsList").innerHTML = `<div class="empty-state">Error: ${esc(err.message)}</div>`;
    }
}

function renderElections(elections) {
    const container = document.getElementById("electionsList");
    if (elections.length === 0) {
        container.innerHTML = '<div class="empty-state">No elections found</div>';
        return;
    }
    container.innerHTML = elections.map(e => {
        const endTime = new Date(e.end_date);
        const now = new Date();
        const timeLeft = endTime - now;
        let countdownHtml = '';
        if (e.status === 'active' && timeLeft > 0) {
            const days = Math.floor(timeLeft / 86400000);
            const hours = Math.floor((timeLeft % 86400000) / 3600000);
            const mins = Math.floor((timeLeft % 3600000) / 60000);
            countdownHtml = `<span class="countdown">⏱️ ${days}d ${hours}h ${mins}m remaining</span>`;
        }
        return `
        <div class="election-card">
            <div class="election-card-header">
                <h4>${esc(e.title)}</h4>
                <span class="election-status status-${e.status}">${e.status}</span>
            </div>
            <p>${esc(e.description || "No description")}</p>
            <div class="election-meta">
                <span>📅 ${formatDate(e.start_date)} — ${formatDate(e.end_date)}</span>
                <span>🏷️ ${e.election_type}</span>
                <span>👥 ${e.candidate_count} candidates</span>
                <span>🗳️ ${e.total_votes} votes</span>
                ${countdownHtml}
            </div>
            <div class="election-card-actions">
                ${e.status === "active" ? `<button class="btn btn-primary btn-sm" onclick="navigateTo('/vote/${e.id}')">Vote Now</button>` : ""}
                ${e.status === "completed" ? `<button class="btn btn-glass btn-sm" onclick="viewResult('${e.id}')">View Results</button>` : ""}
            </div>
        </div>
    `;
    }).join("");
}

function filterElections(status, btn) {
    document.querySelectorAll(".filter-btn").forEach(b => b.classList.remove("active"));
    btn.classList.add("active");
    if (status === "all") {
        renderElections(allElections);
    } else {
        renderElections(allElections.filter(e => e.status === status));
    }
}

// ── Vote Page ───────────────────────────────────────────────────
async function loadVotePage() {
    if (!selectedElectionId) {
        // Get from URL hash
        const hash = window.location.hash;
        const match = hash.match(/\/vote\/(.+)/);
        if (match) selectedElectionId = match[1];
        else {
            navigateTo("/elections");
            return;
        }
    }

    try {
        const data = await API.get(`/api/vote/election/${selectedElectionId}`);
        const election = data.election;
        const candidates = data.candidates;

        document.getElementById("voteElectionTitle").innerHTML = `Cast Your Vote: <span class="gradient-text">${esc(election.title)}</span>`;
        document.getElementById("voteElectionDesc").textContent = election.description || "";

        // Reset UI
        document.getElementById("voteAlreadyVoted").style.display = "none";
        document.getElementById("voteCandidates").style.display = "grid";
        document.getElementById("voteSuccess").style.display = "none";
        document.getElementById("voteConfirmModal").style.display = "none";
        selectedCandidateId = null;

        if (data.has_voted) {
            document.getElementById("voteAlreadyVoted").style.display = "block";
            document.getElementById("voteCandidates").style.display = "none";
            return;
        }

        if (election.status !== "active") {
            document.getElementById("voteCandidates").innerHTML = `
                <div class="empty-state">This election is not currently active (Status: ${election.status})</div>`;
            return;
        }

        document.getElementById("voteCandidates").innerHTML = candidates.map(c => `
            <div class="candidate-card" id="candidate-${c.id}" onclick="selectCandidate('${c.id}', '${esc(c.name)}', '${esc(c.party || "Independent")}', '${esc(c.symbol || "⚪")}')">
                ${c.photo_url ? `<img src="${esc(c.photo_url)}" alt="${esc(c.party)}" class="candidate-photo">` : `<div class="candidate-symbol">${c.symbol || "⚪"}</div>`}
                <h4>${esc(c.name)}</h4>
                <p class="candidate-party">${esc(c.party || "Independent")}</p>
                
                <div class="candidate-details">
                    ${c.age ? `<span class="detail-chip">Age: ${c.age}</span>` : ""}
                    ${c.locality ? `<span class="detail-chip">📍 ${esc(c.locality)}</span>` : ""}
                    ${c.district ? `<span class="detail-chip">${esc(c.district)}</span>` : ""}
                    ${c.timings ? `<span class="detail-chip">🕒 ${esc(c.timings)}</span>` : ""}
                </div>

                ${c.manifesto ? `<p class="candidate-manifesto">${esc(c.manifesto)}</p>` : ""}
                <button class="btn btn-glass btn-sm" style="margin-top:12px">Select ✓</button>
            </div>
        `).join("");

    } catch (err) {
        showToast("Error loading election: " + err.message, "error");
    }
}

function selectCandidate(id, name, party, symbol) {
    selectedCandidateId = id;
    // Highlight selected
    document.querySelectorAll(".candidate-card").forEach(c => c.classList.remove("selected"));
    document.getElementById(`candidate-${id}`).classList.add("selected");

    // Show confirmation modal
    const card = document.getElementById(`candidate-${id}`);
    const img = card.querySelector('.candidate-photo');
    const imgHtml = img ? `<img src="${img.src}" style="width:60px;height:60px;border-radius:12px;object-fit:cover;margin-bottom:8px">` : `<span style="font-size:40px">${symbol}</span>`;
    document.getElementById("voteConfirmCandidate").innerHTML = `${imgHtml}<br>${name}<br><small style="color:var(--text-secondary)">${party}</small>`;
    document.getElementById("voteConfirmModal").style.display = "flex";
}

function closeVoteModal() {
    document.getElementById("voteConfirmModal").style.display = "none";
    selectedCandidateId = null;
    document.querySelectorAll(".candidate-card").forEach(c => c.classList.remove("selected"));
}

async function confirmVote() {
    if (!selectedCandidateId || !selectedElectionId) return;

    const btn = document.getElementById("confirmVoteBtn");
    setLoading(btn, true);

    try {
        const data = await API.post("/api/vote/cast", {
            election_id: selectedElectionId,
            candidate_id: selectedCandidateId,
        });

        // Show success
        document.getElementById("voteConfirmModal").style.display = "none";
        document.getElementById("voteCandidates").style.display = "none";
        document.getElementById("voteSuccess").style.display = "block";
        document.getElementById("voteReceipt").textContent = data.receipt;
        document.getElementById("voteHashDisplay").textContent = data.vote_hash;
        showToast("🗳️ Vote cast successfully!", "success");

    } catch (err) {
        showToast("Error casting vote: " + err.message, "error");
        closeVoteModal();
    } finally {
        setLoading(btn, false);
    }
}

// ── Results ─────────────────────────────────────────────────────
async function loadResults() {
    try {
        const data = await API.get("/api/vote/elections");
        const completed = (data.elections || []).filter(e => e.status === "completed");

        const container = document.getElementById("resultsList");
        document.getElementById("resultDetail").style.display = "none";
        container.style.display = "grid";

        if (completed.length === 0) {
            container.innerHTML = '<div class="empty-state">No completed elections with results yet</div>';
            return;
        }

        container.innerHTML = completed.map(e => `
            <div class="election-card" onclick="viewResult('${e.id}')" style="cursor:pointer">
                <div class="election-card-header">
                    <h4>${esc(e.title)}</h4>
                    <span class="election-status status-completed">Completed</span>
                </div>
                <div class="election-meta">
                    <span>🗳️ ${e.total_votes} total votes</span>
                    <span>👥 ${e.candidate_count} candidates</span>
                </div>
                <button class="btn btn-primary btn-sm">View Results →</button>
            </div>
        `).join("");

    } catch (err) {
        showToast("Error loading results: " + err.message, "error");
    }
}

async function viewResult(electionId) {
    try {
        const data = await API.get(`/api/results/${electionId}`);
        const results = data.results || [];
        const election = data.election;

        document.getElementById("resultsList").style.display = "none";
        document.getElementById("resultDetail").style.display = "block";
        document.getElementById("resultElectionTitle").textContent = election.title;
        document.getElementById("resultTotalVotes").textContent = data.total_votes;

        // Table
        const tbody = document.getElementById("resultTableBody");
        tbody.innerHTML = results.map((r, i) => `
            <tr${r.is_winner ? ' style="color: var(--accent-emerald); font-weight: 600"' : ''}>
                <td>${i + 1}${r.is_winner ? " 🏆" : ""}</td>
                <td>${esc(r.candidates?.name || "Unknown")}</td>
                <td>${esc(r.candidates?.party || "—")}</td>
                <td>${r.vote_count}</td>
                <td>${r.percentage}%</td>
            </tr>
        `).join("");

        // Chart
        if (resultChart) resultChart.destroy();
        const ctx = document.getElementById("resultChart").getContext("2d");
        const colors = [
            "#6366f1", "#8b5cf6", "#10b981", "#f59e0b", "#f43f5e",
            "#06b6d4", "#ec4899", "#14b8a6", "#f97316", "#84cc16"
        ];
        resultChart = new Chart(ctx, {
            type: "doughnut",
            data: {
                labels: results.map(r => r.candidates?.name || "Unknown"),
                datasets: [{
                    data: results.map(r => r.vote_count),
                    backgroundColor: colors.slice(0, results.length),
                    borderWidth: 0,
                    hoverOffset: 8,
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: "bottom",
                        labels: { color: "#94a3b8", padding: 16, font: { size: 13 } }
                    }
                }
            }
        });

    } catch (err) {
        showToast("Error loading results: " + err.message, "error");
    }
}

function showResultsList() {
    document.getElementById("resultsList").style.display = "grid";
    document.getElementById("resultDetail").style.display = "none";
}

// ── Admin Panel ─────────────────────────────────────────────────
async function loadAdmin() {
    try {
        // Load dashboard stats
        const stats = await API.get("/api/admin/dashboard");
        const s = stats.stats;
        document.getElementById("adminTotalVoters").textContent = s.total_voters;
        document.getElementById("adminTotalElections").textContent = s.total_elections;
        document.getElementById("adminActiveElections").textContent = s.active_elections;
        document.getElementById("adminTotalVotes").textContent = s.total_votes_cast;

        // Also update home page stats
        document.getElementById("statVoters").textContent = s.total_voters;
        document.getElementById("statElections").textContent = s.total_elections;
        document.getElementById("statVotes").textContent = s.total_votes_cast;

        await loadAdminElections();
    } catch (err) {
        showToast("Error loading admin: " + err.message, "error");
    }
}

async function loadAdminElections() {
    try {
        const data = await API.get("/api/admin/elections");
        const elections = data.elections || [];
        const container = document.getElementById("adminElectionsList");

        if (elections.length === 0) {
            container.innerHTML = '<div class="empty-state">No elections created yet. Create your first election!</div>';
            return;
        }

        container.innerHTML = elections.map(e => {
            const endTime = new Date(e.end_date);
            const now = new Date();
            const isExpired = endTime <= now;
            const timeLeft = endTime - now;
            let timerHtml = '';
            if (e.status === 'active' && !isExpired) {
                const d = Math.floor(timeLeft / 86400000);
                const h = Math.floor((timeLeft % 86400000) / 3600000);
                const m = Math.floor((timeLeft % 3600000) / 60000);
                timerHtml = ` · ⏱️ ${d}d ${h}h ${m}m left`;
            } else if (e.status === 'active' && isExpired) {
                timerHtml = ' · <span style="color:var(--accent-rose)">⚠️ Time expired — Calculate results now!</span>';
            }
            return `
            <div class="admin-election-item">
                <div class="admin-election-info">
                    <h4>${esc(e.title)} <span class="election-status status-${e.status}">${e.status}</span></h4>
                    <p>${e.candidate_count} candidates · ${e.total_votes} votes · ${formatDate(e.start_date)} — ${formatDate(e.end_date)}${timerHtml}</p>
                </div>
                <div class="admin-election-actions">
                    <button class="btn btn-glass btn-sm" onclick="manageCandidates('${e.id}', '${esc(e.title)}')">Candidates</button>
                    ${e.status === "upcoming" ? `<button class="btn btn-success btn-sm" onclick="updateElectionStatus('${e.id}', 'active')">▶ Start Voting</button>` : ""}
                    ${e.status === "active" ? `<button class="btn btn-sm" style="background:var(--accent-amber);color:white" onclick="updateElectionStatus('${e.id}', 'paused')">⏸ Pause</button>` : ""}
                    ${e.status === "paused" ? `<button class="btn btn-success btn-sm" onclick="updateElectionStatus('${e.id}', 'active')">▶ Resume</button>` : ""}
                    ${["active", "paused"].includes(e.status) ? `<button class="btn btn-primary btn-sm" onclick="calculateResults('${e.id}')">📊 Declare Results</button>` : ""}
                    ${e.status === "completed" ? `<button class="btn btn-glass btn-sm" onclick="viewResult('${e.id}')">📊 View Results</button>` : ""}
                    ${["upcoming", "cancelled"].includes(e.status) ? `<button class="btn btn-danger btn-sm" onclick="deleteElection('${e.id}')">🗑 Delete</button>` : ""}
                </div>
            </div>
        `;
        }).join("");
    } catch (err) {
        showToast("Error loading elections: " + err.message, "error");
    }
}

function switchAdminTab(tab, btn) {
    document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
    btn.classList.add("active");
    document.querySelectorAll(".admin-tab-content").forEach(t => t.classList.remove("active"));
    document.getElementById(`adminTab-${tab}`).classList.add("active");

    if (tab === "voters") loadAdminVoters();
    if (tab === "logs") loadAdminLogs();
}

function showCreateElection() {
    document.getElementById("createElectionForm").style.display = "block";
}

function hideCreateElection() {
    document.getElementById("createElectionForm").style.display = "none";
}

async function handleCreateElection(e) {
    e.preventDefault();
    const errEl = document.getElementById("createElectionError");
    errEl.textContent = "";

    try {
        await API.post("/api/admin/elections", {
            title: document.getElementById("elTitle").value,
            election_type: document.getElementById("elType").value,
            description: document.getElementById("elDesc").value,
            start_date: new Date(document.getElementById("elStart").value).toISOString(),
            end_date: new Date(document.getElementById("elEnd").value).toISOString(),
        });

        showToast("Election created successfully!", "success");
        hideCreateElection();
        e.target.reset();
        await loadAdminElections();
    } catch (err) {
        errEl.textContent = err.message;
    }
}

async function updateElectionStatus(id, status) {
    try {
        await API.put(`/api/admin/elections/${id}`, { status });
        showToast(`Election ${status}!`, "success");
        await loadAdminElections();
    } catch (err) {
        showToast("Error: " + err.message, "error");
    }
}

async function deleteElection(id) {
    if (!confirm("Are you sure you want to delete this election?")) return;
    try {
        await API.delete(`/api/admin/elections/${id}`);
        showToast("Election deleted.", "info");
        await loadAdminElections();
    } catch (err) {
        showToast("Error: " + err.message, "error");
    }
}

async function calculateResults(id) {
    if (!confirm("Calculate and publish final results? This will end the election.")) return;
    try {
        await API.post(`/api/results/${id}/calculate`);
        showToast("Results calculated and published!", "success");
        await loadAdminElections();
    } catch (err) {
        showToast("Error: " + err.message, "error");
    }
}

// ── Candidates Management ───────────────────────────────────────
let currentManageElectionId = null;

async function manageCandidates(electionId, title) {
    currentManageElectionId = electionId;
    document.getElementById("candElectionTitle").textContent = title;
    document.getElementById("candidatesModal").style.display = "flex";
    await refreshCandidates();
}

function closeCandidatesModal() {
    document.getElementById("candidatesModal").style.display = "none";
    currentManageElectionId = null;
}

async function refreshCandidates() {
    try {
        const data = await API.get(`/api/admin/candidates/${currentManageElectionId}`);
        const candidates = data.candidates || [];
        const container = document.getElementById("candidatesList");

        if (candidates.length === 0) {
            container.innerHTML = '<div class="empty-state">No candidates added yet</div>';
        } else {
            container.innerHTML = candidates.map(c => `
                <div class="candidate-manage-item">
                    <span>${c.symbol || "⚪"} <strong>${esc(c.name)}</strong> — ${esc(c.party || "Independent")}</span>
                    <button class="btn btn-danger btn-sm" onclick="removeCandidate('${c.id}')">Remove</button>
                </div>
            `).join("");
        }
    } catch (err) {
        showToast("Error loading candidates: " + err.message, "error");
    }
}

async function handleAddCandidate(e) {
    e.preventDefault();
    const errEl = document.getElementById("addCandidateError");
    errEl.textContent = "";

    try {
        await API.post("/api/admin/candidates", {
            election_id: currentManageElectionId,
            name: document.getElementById("candName").value,
            party: document.getElementById("candParty").value,
            symbol: document.getElementById("candSymbol").value,
            position: parseInt(document.getElementById("candPosition").value) || 0,
            photo_url: document.getElementById("candPhoto").value || "",
            age: parseInt(document.getElementById("candAge").value) || null,
            locality: document.getElementById("candLocality").value || "",
            state: document.getElementById("candState").value || "",
            district: document.getElementById("candDistrict").value || "",
            timings: document.getElementById("candTimings").value || "",
            manifesto: document.getElementById("candManifesto").value || "",
        });

        showToast("Candidate added!", "success");
        document.getElementById("candName").value = "";
        await refreshCandidates();
        await loadAdminElections();
    } catch (err) {
        errEl.textContent = err.message;
    }
}

async function removeCandidate(id) {
    if (!confirm("Remove this candidate?")) return;
    try {
        await API.delete(`/api/admin/candidates/${id}`);
        showToast("Candidate removed.", "info");
        await refreshCandidates();
        await loadAdminElections();
    } catch (err) {
        showToast("Error: " + err.message, "error");
    }
}

// ── Admin Voters & Logs ─────────────────────────────────────────
async function loadAdminVoters() {
    try {
        const data = await API.get("/api/admin/voters");
        const voters = data.voters || [];
        const container = document.getElementById("adminVotersList");

        if (voters.length === 0) {
            container.innerHTML = '<div class="empty-state">No registered voters yet</div>';
            return;
        }

        container.innerHTML = `
            <table class="data-table">
                <thead><tr>
                    <th>Name</th><th>Voter ID</th><th>Email</th><th>District</th><th>Verified</th><th>Registered</th>
                </tr></thead>
                <tbody>
                    ${voters.map(v => `<tr>
                        <td>${esc(v.full_name)}</td>
                        <td><code>${esc(v.voter_id)}</code></td>
                        <td>${esc(v.email)}</td>
                        <td>${esc(v.district || "—")}</td>
                        <td>${v.is_verified ? "✅" : "❌"}</td>
                        <td>${formatDate(v.created_at)}</td>
                    </tr>`).join("")}
                </tbody>
            </table>
            <p style="margin-top:12px;font-size:13px;color:var(--text-muted)">Total: ${data.total} voters</p>
        `;
    } catch (err) {
        showToast("Error loading voters: " + err.message, "error");
    }
}

async function loadAdminLogs() {
    try {
        const data = await API.get("/api/admin/logs");
        const logs = data.logs || [];
        const container = document.getElementById("adminLogsList");

        if (logs.length === 0) {
            container.innerHTML = '<div class="empty-state">No authentication logs yet</div>';
            return;
        }

        container.innerHTML = `
            <table class="data-table">
                <thead><tr>
                    <th>Action</th><th>Status</th><th>IP Address</th><th>Time</th>
                </tr></thead>
                <tbody>
                    ${logs.map(l => `<tr>
                        <td>${esc(l.action)}</td>
                        <td><span class="election-status status-${l.status === 'success' ? 'active' : 'cancelled'}">${l.status}</span></td>
                        <td><code>${esc(l.ip_address || "—")}</code></td>
                        <td>${formatDate(l.created_at)}</td>
                    </tr>`).join("")}
                </tbody>
            </table>
        `;
    } catch (err) {
        showToast("Error loading logs: " + err.message, "error");
    }
}

// ── Utilities ───────────────────────────────────────────────────
function esc(str) {
    if (!str) return "";
    const div = document.createElement("div");
    div.textContent = str;
    return div.innerHTML;
}

function formatDate(dateStr) {
    if (!dateStr) return "—";
    try {
        return new Date(dateStr).toLocaleDateString("en-IN", {
            day: "2-digit", month: "short", year: "numeric",
            hour: "2-digit", minute: "2-digit"
        });
    } catch { return dateStr; }
}

function setLoading(btn, loading) {
    const text = btn.querySelector(".btn-text");
    const loader = btn.querySelector(".btn-loader");
    if (loading) {
        if (text) text.style.display = "none";
        if (loader) loader.style.display = "inline-block";
        btn.disabled = true;
    } else {
        if (text) text.style.display = "inline";
        if (loader) loader.style.display = "none";
        btn.disabled = false;
    }
}

function togglePassword(inputId) {
    const input = document.getElementById(inputId);
    input.type = input.type === "password" ? "text" : "password";
}

function showToast(message, type = "info") {
    const toast = document.getElementById("toast");
    toast.textContent = message;
    toast.className = `toast ${type} show`;
    setTimeout(() => { toast.classList.remove("show"); }, 4000);
}

// ── Profile Logic ───────────────────────────────────────────────
function showProfile() {
    if (!currentUser) return;
    
    document.getElementById("profileInfoName").textContent = currentUser.full_name || currentUser.username;
    document.getElementById("profileInfoEmail").textContent = currentUser.email || "—";
    document.getElementById("profileInfoVoterId").textContent = currentUser.voter_id || "—";
    document.getElementById("profileInfoDistrict").textContent = currentUser.district || "—";
    document.getElementById("profileInfoState").textContent = currentUser.state || "—";
    
    const photoUrl = currentUser.photo_url || "https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=200&q=80";
    document.getElementById("profileInfoPhoto").src = photoUrl;
    document.getElementById("editProfilePhoto").value = currentUser.photo_url || "";
    
    // Check role for address editing
    const addrGroup = document.getElementById("editAddressGroup");
    if (currentRole === "voter") {
        addrGroup.style.display = "block";
        document.getElementById("editProfileAddress").value = currentUser.address || "";
    } else {
        addrGroup.style.display = "none";
    }
    
    document.getElementById("profileInfoRole").textContent = currentRole.charAt(0).toUpperCase() + currentRole.slice(1);
    
    document.getElementById("profileModal").style.display = "flex";
    document.getElementById("userDropdown").classList.remove("show");
}

async function handleUpdateProfile() {
    const btn = document.getElementById("saveProfileBtn");
    const photo = document.getElementById("editProfilePhoto").value;
    const address = document.getElementById("editProfileAddress").value;
    
    setLoading(btn, true);
    
    try {
        const endpoint = currentRole === "voter" ? "/api/voter/profile" : "/api/admin/profile";
        const data = await API.put(endpoint, {
            photo_url: photo,
            address: currentRole === "voter" ? address : undefined
        });
        
        showToast(data.message, "success");
        
        // Refresh local user data
        const profileData = await API.get("/api/auth/me");
        currentUser = profileData.user;
        
        // Update UI
        updateNavForUser();
        showProfile(); // Re-populate
        
    } catch (err) {
        showToast("Error updating profile: " + err.message, "error");
    } finally {
        setLoading(btn, false);
    }
}

function closeProfileModal() {
    document.getElementById("profileModal").style.display = "none";
}
