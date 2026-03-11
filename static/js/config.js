/* ═══════════════════════════════════════════════════════════════
   Config — API Base URL
   ═══════════════════════════════════════════════════════════════ */

const CONFIG = {
    // When running locally, use relative URL (Flask serves everything)
    // When deployed, this stays the same
    API_BASE: window.location.origin,
};
