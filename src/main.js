/* ============================================================
   MAIN — boot sequence
   ============================================================ */
(function boot() {
  buildDatabase();
  Input.init();
  BG.init();
  const hasSave = Save.load();
  if (hasSave) { Audio2.applyVolumes(); document.body.classList.toggle('reduce-motion', !!Save.data.settings.reduceMotion); }
  // market simulation runs in the background while the game is open
  setInterval(() => { try { Market.tick(); } catch (e) { console.error(e); } }, 1000);
  if (hasSave) Market.tick();
  UI.reset('title');
  setTimeout(() => { const l = document.getElementById('loading'); if (l) { l.classList.add('out'); setTimeout(() => l.remove(), 700); } }, 350);
  window.PF27 = { Save, DB, Club, Squads, Market, Match, UI }; // debug handle
})();
