(function () {
  var bar = document.getElementById('page-loader');
  var logo = document.getElementById('loader-logo');
  var banner = document.getElementById('offline-banner');
  if (!bar) return;

  var timer = null;
  var loaded = false;

  function show() {
    bar.classList.add('active');
    if (logo) logo.classList.add('active');
  }
  function hide() {
    loaded = true;
    bar.classList.remove('active');
    if (logo) logo.classList.remove('active');
    if (timer) { clearTimeout(timer); timer = null; }
  }
  function showDelayed(delay) {
    if (timer) clearTimeout(timer);
    timer = setTimeout(function() {
      if (!loaded) show();
    }, delay || 500);
  }

  if (document.readyState === 'loading') {
    showDelayed(500);
  }
  document.addEventListener('DOMContentLoaded', function () {
    setTimeout(hide, 200);
  });
  window.addEventListener('load', function () {
    hide();
  });

  setTimeout(function() {
    if (!loaded) hide();
  }, 2000);

  document.addEventListener('click', function (e) {
    var link = e.target.closest('a[href]');
    if (!link) return;
    var h = link.getAttribute('href');
    if (!h || h.startsWith('#') || h.startsWith('javascript') || h.startsWith('tel:') || h.startsWith('mailto:')) return;
    if (link.hasAttribute('download') || link.target === '_blank') return;
    if (!(h.startsWith('/') || h.startsWith(window.location.origin))) return;
    loaded = false;
    showDelayed(500);
  });

  document.addEventListener('submit', function (e) {
    if (e.defaultPrevented) return;
    if (e.target.getAttribute('data-no-loader') === 'true') return;
    loaded = false;
    showDelayed(500);
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
