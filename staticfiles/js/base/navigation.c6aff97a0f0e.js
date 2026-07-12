// ==============================================================================
// File: navigation.js
// Description: Category navigation scroll with drag support (re-inits on turbolinks:load)
// NOTE: Dropdown toggles are handled by main.min.js via delegated document listener — do NOT add here.
// ==============================================================================
// Re-queries DOM on each turbolinks:load so arrows don't break after navigation.

(function () {
  var track, inner, prev, next;
  var STEP = 300;
  var dragState = {};

  function init() {
    track = document.getElementById('elite-nav-track');
    inner = document.getElementById('elite-nav-inner');
    prev  = document.getElementById('nav-prev');
    next  = document.getElementById('nav-next');
    if (!track || track.dataset.navInit) return;
    track.dataset.navInit = '1';

    function sync() {
      var atStart = track.scrollLeft < 4;
      var atEnd   = track.scrollLeft > track.scrollWidth - track.clientWidth - 4;
      prev.disabled = atStart;
      next.disabled = atEnd;
      inner.classList.toggle('show-left-fade',  !atStart);
      inner.classList.toggle('show-right-fade', !atEnd);
    }

    window.eliteSlide = function (dir) {
      if (!track) return;
      track.scrollBy({ left: dir * STEP, behavior: 'smooth' });
    };

    track.addEventListener('scroll', sync, { passive: true });
    window.addEventListener('resize', sync);

    var active = track.querySelector('.elite-cat-item.active-cat');
    if (active) {
      setTimeout(function () {
        active.scrollIntoView({ behavior: 'smooth', block: 'nearest', inline: 'center' });
      }, 250);
    }

    // drag-to-scroll
    dragState.dragging = false;
    track.addEventListener('mousedown', function (e) {
      dragState.dragging = true;
      track.style.cursor = 'grabbing';
      dragState.startX = e.pageX - track.offsetLeft;
      dragState.scrollStart = track.scrollLeft;
    });
    ['mouseleave','mouseup'].forEach(function (ev) {
      track.addEventListener(ev, function () {
        dragState.dragging = false;
        track.style.cursor = '';
      });
    });
    track.addEventListener('mousemove', function (e) {
      if (!dragState.dragging) return;
      e.preventDefault();
      track.scrollLeft = dragState.scrollStart - (e.pageX - track.offsetLeft - dragState.startX) * 1.3;
    });

    track.setAttribute('tabindex', '0');
    track.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowRight') eliteSlide(1);
      if (e.key === 'ArrowLeft')  eliteSlide(-1);
    });
    sync();
  }

  init();
  document.addEventListener('turbolinks:load', init);
})();
