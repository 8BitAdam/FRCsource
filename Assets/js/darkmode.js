// Shared dark mode handler for the site
// Usage: include <script src="/Assets/js/darkmode.js"></script> near the end of the page
(function () {
  const rootEl = document.body;

  function applyPreference() {
    const saved = localStorage.getItem('darkmode');
    if (saved === 'true') {
      rootEl.classList.add('darkmode');
    } else if (saved === 'false') {
      rootEl.classList.remove('darkmode');
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      rootEl.classList.add('darkmode');
    }
  }

  function toggleDarkMode() {
    if (rootEl.classList.contains('darkmode')) {
      rootEl.classList.remove('darkmode');
      localStorage.setItem('darkmode', 'false');
    } else {
      rootEl.classList.add('darkmode');
      localStorage.setItem('darkmode', 'true');
    }
  }

  // Expose functions to global scope for existing onclick attributes
  window.applyPreference = applyPreference;
  window.toggleDarkMode = toggleDarkMode;

  window.addEventListener('load', applyPreference);
})();
