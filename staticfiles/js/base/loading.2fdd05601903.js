(function () {
  var bar = document.getElementById('page-loader');
  var logo = document.getElementById('loader-logo');
  var backdrop = document.getElementById('loader-backdrop');
  var banner = document.getElementById('offline-banner');
  if (!bar) return;

  var loaded = false;

  function hide() {
    loaded = true;
    bar.classList.remove('active');
    if (logo) logo.classList.remove('active');
    if (backdrop) backdrop.classList.remove('active');
  }

  // Hide once everything loads
  window.addEventListener('load', hide);
  document.addEventListener('turbolinks:load', hide);

  // Safety: hide after 2s even if something fails
  setTimeout(function() { if (!loaded) hide(); }, 2000);

  // Show only on initial page load, never on Turbolinks clicks
  if (document.readyState === 'loading') {
    bar.classList.add('active');
    if (logo) logo.classList.add('active');
    if (backdrop) backdrop.classList.add('active');
  } else {
    hide();
  }

  // Show on form submits (not intercepted by Turbolinks)
  document.addEventListener('submit', function (e) {
    if (e.defaultPrevented) return;
    if (e.target.getAttribute('data-no-loader') === 'true') return;
    bar.classList.add('active');
    if (logo) logo.classList.add('active');
    if (backdrop) backdrop.classList.add('active');
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