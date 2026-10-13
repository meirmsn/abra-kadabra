// Devshop UI baseline theme toggle (runtime/guidelines/ui.md). A project copies this file and owns it.
// Load it in <head>, before any stylesheet-dependent content, as a plain (not deferred) script or
// inlined, so the stored choice is on <html> before the first paint and there is no flash.
// Any [data-theme-toggle] control cycles system -> light -> dark -> system and shows the choice.
// The choice is kept in this browser only; if storage is blocked, the page just follows the system.
(function () {
  var KEY = 'theme';
  var ORDER = ['system', 'light', 'dark'];
  var LABEL = {
    system: 'Theme: system',
    light: 'Theme: light',
    dark: 'Theme: dark',
  };
  var root = document.documentElement;

  function stored() {
    try {
      var v = window.localStorage.getItem(KEY);
      return ORDER.indexOf(v) > 0 ? v : 'system';
    } catch (e) {
      return 'system';
    }
  }

  function save(choice) {
    try {
      if (choice === 'system') window.localStorage.removeItem(KEY);
      else window.localStorage.setItem(KEY, choice);
    } catch (e) {
      // Blocked storage: the choice lasts until the page reloads.
    }
  }

  function apply(choice) {
    if (choice === 'system') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', choice);
    var buttons = document.querySelectorAll('[data-theme-toggle]');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].textContent = LABEL[choice];
      buttons[i].setAttribute('aria-label', LABEL[choice] + ' (change theme)');
    }
  }

  var current = stored();
  apply(current);
  document.addEventListener('DOMContentLoaded', function () {
    apply(current);
  });
  document.addEventListener('click', function (e) {
    var target =
      e.target instanceof Element
        ? e.target.closest('[data-theme-toggle]')
        : null;
    if (!target) return;
    current = ORDER[(ORDER.indexOf(current) + 1) % ORDER.length];
    save(current);
    apply(current);
  });
})();
