/* ============================================================
   CORE / INPUT — keyboard + gamepad, spatial menu navigation
   ============================================================ */
const Input = {
  keys: {}, pressed: {}, layers: [], mode: 'menu', // 'menu' | 'game'
  pad: null, padPrev: {}, padRepeat: {}, usingPad: false,
  onTab: null, // (dir) => void  (Q/E, LB/RB)

  init() {
    window.addEventListener('keydown', e => {
      Audio2.resume();
      const k = e.key.toLowerCase();
      if (!this.keys[k]) this.pressed[k] = true;
      this.keys[k] = true;
      this.usingPad = false;
      if (this.mode === 'menu') this.menuKey(k, e);
      else if ([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', 'tab'].includes(k)) e.preventDefault();
    });
    window.addEventListener('keyup', e => { this.keys[e.key.toLowerCase()] = false; });
    window.addEventListener('blur', () => { this.keys = {}; });
    window.addEventListener('mousedown', () => Audio2.resume(), { capture: true });
    document.addEventListener('mouseover', e => {
      const t = e.target.closest('[data-nav]');
      if (t && this.mode === 'menu' && !t.disabled && document.activeElement !== t && this.inTopLayer(t)) { t.focus({ preventScroll: true }); }
    });
    document.addEventListener('focusin', e => { if (e.target.matches?.('[data-nav]')) Audio2.sfx('move'); });
    const loop = () => { this.pollPad(); requestAnimationFrame(loop); };
    requestAnimationFrame(loop);
  },
  consume(k) { const p = this.pressed[k]; this.pressed[k] = false; return !!p; },
  clearPressed() { this.pressed = {}; },

  /* ---------- layers (screens / modals) ---------- */
  pushLayer(root, onBack) { const L = { root, onBack }; this.layers.push(L); return L; },
  popLayer(L) { const i = this.layers.indexOf(L); if (i >= 0) this.layers.splice(i, 1); const top = this.top(); if (top) this.focusFirst(top.root, true); },
  setBase(root, onBack) { this.layers = this.layers.filter(l => !l.base); const L = { root, onBack, base: true }; this.layers.unshift(L); return L; },
  top() { return this.layers[this.layers.length - 1]; },
  inTopLayer(el) { const t = this.top(); return !t || t.root.contains(el); },
  focusables(root) { return $$('[data-nav]', root).filter(el => !el.disabled && el.offsetParent !== null && !el.closest('.hidden')); },
  focusFirst(root, keepIfInside) {
    if (!root) return;
    if (keepIfInside && root.contains(document.activeElement) && document.activeElement.matches('[data-nav]')) return;
    const pref = $('[data-autofocus]', root);
    const f = pref && pref.offsetParent !== null ? pref : this.focusables(root)[0];
    if (f) f.focus({ preventScroll: false });
  },

  menuKey(k, e) {
    const tag = (document.activeElement?.tagName || '').toLowerCase();
    const typing = (tag === 'input' && !['range', 'checkbox', 'button'].includes(document.activeElement.type)) || tag === 'textarea';
    if (typing && k !== 'escape' && k !== 'enter') return;
    const dirs = { arrowup: 'up', arrowdown: 'down', arrowleft: 'left', arrowright: 'right' };
    if (dirs[k]) {
      if (tag === 'input' && document.activeElement.type === 'range' && (k === 'arrowleft' || k === 'arrowright')) return;
      if (tag === 'select') return;
      e.preventDefault(); this.navigate(dirs[k]);
    } else if (k === 'enter' || k === ' ') {
      if (tag === 'select' || (tag === 'input' && document.activeElement.type !== 'checkbox')) return;
      const a = document.activeElement;
      if (a && a.matches('[data-nav]')) { e.preventDefault(); a.click(); }
    } else if (k === 'escape' || k === 'backspace') {
      if (k === 'backspace' && typing) return;
      e.preventDefault(); this.back();
    } else if ((k === 'q' || k === 'e') && this.onTab && this.layers.length <= 1) {
      this.onTab(k === 'q' ? -1 : 1);
    }
  },
  back() { const t = this.top(); if (t && t.onBack) { Audio2.sfx('back'); t.onBack(); } },
  navigate(dir) {
    const t = this.top(); const root = t ? t.root : document.body;
    const list = this.focusables(root);
    if (!list.length) return;
    const cur = document.activeElement;
    if (!cur || !list.includes(cur)) { list[0].focus(); return; }
    const r = cur.getBoundingClientRect(), cx = r.left + r.width / 2, cy = r.top + r.height / 2;
    let best = null, bestScore = Infinity;
    for (const el of list) {
      if (el === cur) continue;
      const b = el.getBoundingClientRect(), x = b.left + b.width / 2, y = b.top + b.height / 2;
      const dx = x - cx, dy = y - cy;
      let main, cross;
      if (dir === 'up') { if (b.bottom > r.top + 4 && dy >= -2) continue; main = -dy; cross = Math.abs(dx); }
      if (dir === 'down') { if (b.top < r.bottom - 4 && dy <= 2) continue; main = dy; cross = Math.abs(dx); }
      if (dir === 'left') { if (b.right > r.left + 4 && dx >= -2) continue; main = -dx; cross = Math.abs(dy); }
      if (dir === 'right') { if (b.left < r.right - 4 && dx <= 2) continue; main = dx; cross = Math.abs(dy); }
      if (main <= 0) continue;
      const score = main + cross * 2.2;
      if (score < bestScore) { bestScore = score; best = el; }
    }
    if (best) { best.focus({ preventScroll: true }); best.scrollIntoView({ block: 'nearest', inline: 'nearest', behavior: 'smooth' }); }
  },

  /* ---------- gamepad ---------- */
  pollPad() {
    const pads = navigator.getGamepads ? navigator.getGamepads() : [];
    let p = null; for (const g of pads) if (g && g.connected) { p = g; break; }
    this.pad = p;
    if (!p) return;
    const b = i => !!(p.buttons[i] && p.buttons[i].pressed);
    const ax = p.axes[0] || 0, ay = p.axes[1] || 0;
    const state = {
      a: b(0), b: b(1), x: b(2), y: b(3), lb: b(4), rb: b(5), lt: b(6), rt: b(7), back: b(8), start: b(9),
      up: b(12) || ay < -0.6, down: b(13) || ay > 0.6, left: b(14) || ax < -0.6, right: b(15) || ax > 0.6
    };
    const now = performance.now();
    const edge = k => state[k] && !this.padPrev[k];
    const rep = k => {
      if (!state[k]) { this.padRepeat[k] = 0; return false; }
      if (!this.padPrev[k]) { this.padRepeat[k] = now + 380; return true; }
      if (now > this.padRepeat[k]) { this.padRepeat[k] = now + 110; return true; }
      return false;
    };
    if (Object.values(state).some(v => v)) { this.usingPad = true; Audio2.resume(); }
    if (this.mode === 'menu') {
      for (const d of ['up', 'down', 'left', 'right']) if (rep(d)) {
        const a = document.activeElement;
        if (a && a.type === 'range' && (d === 'left' || d === 'right')) { a.value = +a.value + (d === 'left' ? -1 : 1) * (+a.step || 1); a.dispatchEvent(new Event('input', { bubbles: true })); }
        else this.navigate(d);
      }
      if (edge('a')) { const a = document.activeElement; if (a && a.matches('[data-nav]')) a.click(); else this.focusFirst(this.top()?.root); }
      if (edge('b')) this.back();
      if ((edge('lb') || edge('rb')) && this.onTab && this.layers.length <= 1) this.onTab(edge('lb') ? -1 : 1);
    }
    this.padState = state;
    this.padPrev = state;
  },
  padEdge(k) { return this.padState && this.padState[k] && !this._gamePrev?.[k]; }
};
