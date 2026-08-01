(function () {
  var banner = document.getElementById('offline-banner');
  var loaded = false;

  function el(id) { return document.getElementById(id); }

  function showBar() {
    var bar = el('page-loader');
    if (bar) bar.classList.add('active');
  }

  function showFull() {
    var bar = el('page-loader');
    var logo = el('loader-logo');
    var backdrop = el('loader-backdrop');
    if (bar) bar.classList.add('active');
    if (logo) logo.classList.add('active');
    if (backdrop) backdrop.classList.add('active');
  }

  function hide() {
    loaded = true;
    var bar = el('page-loader');
    var logo = el('loader-logo');
    var backdrop = el('loader-backdrop');
    if (bar) bar.classList.remove('active');
    if (logo) logo.classList.remove('active');
    if (backdrop) backdrop.classList.remove('active');
  }

  document.addEventListener('DOMContentLoaded', hide);
  document.addEventListener('turbolinks:load', hide);

  // Show thin loading bar during Turbolinks navigation
  document.addEventListener('turbolinks:before-visit', showBar);

  // Safety: hide after 2s even if something fails (was 3s — too slow, blocks clicks)
  setTimeout(function() { if (!loaded) hide(); }, 2000);

  // Show on initial page load
  if (document.readyState === 'loading') {
    showBar();
  } else {
    hide();
  }

  // Show on form submits
  document.addEventListener('submit', function (e) {
    if (e.defaultPrevented) return;
    if (e.target.getAttribute('data-no-loader') === 'true') return;
    showBar();
  });

  function verifyOnline() {
    if (!banner) return;
    fetch(window.location.origin + '/', { method: 'HEAD', cache: 'no-cache' })
      .then(function () { banner.style.display = 'none'; })
      .catch(function () { banner.style.display = 'flex'; });
  }
  verifyOnline();
  window.addEventListener('offline', function () { if (banner) banner.style.display = 'flex'; });
  window.addEventListener('online', function () { if (banner) banner.style.display = 'none'; });
})();