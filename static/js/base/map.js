// ==============================================================================
// File: map.js
// Description: Footer map initialization with Leaflet and OpenStreetMap
// Re-initializes on turbolinks:load to survive body swaps.
// ==============================================================================

(function(){
  function init() {
    var container = document.getElementById('footer-map');
    if (!container || container.dataset.mapInit) return;
    container.dataset.mapInit = '1';

    var homeLat = parseFloat(container.getAttribute('data-home-lat'));
    var homeLng = parseFloat(container.getAttribute('data-home-lng'));
    var hasHome = container.hasAttribute('data-home-lat') && !isNaN(homeLat) && homeLat !== 0;

    var lat = hasHome ? homeLat : 27.7350;
    var lng = hasHome ? homeLng : 85.3180;
    var label = hasHome ? 'Your Home Location' : 'FITNESS HUB — Basundhara, Kathmandu';

    var map = L.map('footer-map', {
      center: [lat, lng],
      zoom: 14,
      zoomControl: true,
      dragging: true,
      scrollWheelZoom: false,
      attributionControl: false,
    });
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
    }).addTo(map);
    L.marker([lat, lng]).addTo(map).bindPopup(label);

    if (typeof enhanceMap === 'function') {
      enhanceMap(map, { fullscreen: true, panArrows: false, myLocation: false });
    }
  }

  // Initial load: wait for DOM + Leaflet to be ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  document.addEventListener('turbolinks:load', init);
})();