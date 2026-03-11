/* ═══════════════════════════════════════════════════════════════
   API Client — Handles all HTTP requests with JWT auth
   ═══════════════════════════════════════════════════════════════ */

const API = {
    /**
     * Make an authenticated API request.
     */
    async request(method, path, body = null) {
        const headers = { "Content-Type": "application/json" };
        const token = localStorage.getItem("token");
        if (token) {
            headers["Authorization"] = `Bearer ${token}`;
        }

        const options = { method, headers };
        if (body && method !== "GET") {
            options.body = JSON.stringify(body);
        }

        try {
            const response = await fetch(`${CONFIG.API_BASE}${path}`, options);
            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || `HTTP ${response.status}`);
            }
            return data;
        } catch (err) {
            if (err.message === "Token has expired") {
                handleLogout();
                showToast("Session expired. Please login again.", "error");
            }
            throw err;
        }
    },

    get(path) { return this.request("GET", path); },
    post(path, body) { return this.request("POST", path, body); },
    put(path, body) { return this.request("PUT", path, body); },
    delete(path) { return this.request("DELETE", path); },
};
