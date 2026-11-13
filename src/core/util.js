/* ============================================================
   CORE / UTIL — seeded RNG, math & DOM helpers
   ============================================================ */
'use strict';

function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
function hashStr(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}
const R = {
  rnd: Math.random,
  range(a, b) { return a + Math.random() * (b - a); },
  int(a, b) { return Math.floor(a + Math.random() * (b - a + 1)); },
  pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; },
  chance(p) { return Math.random() < p; },
  weighted(entries) { // [{w, v}]
    const tot = entries.reduce((s, e) => s + e.w, 0);
    let r = Math.random() * tot;
    for (const e of entries) { if ((r -= e.w) <= 0) return e.v; }
    return entries[entries.length - 1].v;
  },
  shuffle(arr) { const a = arr.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }
};
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const dist = (ax, ay, bx, by) => Math.hypot(ax - bx, ay - by);
const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 8);

function fmtCoins(n) {
  n = Math.round(n);
  if (n >= 1e6) return (n / 1e6).toFixed(n >= 1e7 ? 0 : 1).replace(/\.0$/, '') + 'M';
  if (n >= 1e4) return (n / 1e3).toFixed(n >= 1e5 ? 0 : 1).replace(/\.0$/, '') + 'K';
  return n.toLocaleString('en-US');
}
function fmtFull(n) { return Math.round(n).toLocaleString('en-US'); }
function fmtTime(ms) {
  if (ms <= 0) return 'Expired';
  const s = Math.floor(ms / 1000), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
  if (h > 0) return `${h}h ${m}m`;
  if (m > 0) return `${m}m ${sec}s`;
  return `${sec}s`;
}
function esc(s) { return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }

/* DOM helpers */
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));
function h(html) { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstElementChild; }

/* Toasts */
function toast(msg, kind = 'info') {
  let host = $('#toasts');
  if (!host) { host = h('<div id="toasts"></div>'); document.body.appendChild(host); }
  const el = h(`<div class="toast ${kind}">${msg}</div>`);
  host.appendChild(el);
  setTimeout(() => el.classList.add('out'), 2600);
  setTimeout(() => el.remove(), 3100);
}

/* Modal dialog (returns a promise). buttons: [{label, value, primary}] */
function modal({ title, body, buttons = [{ label: 'OK', value: true, primary: true }], wide = false, onOpen }) {
  return new Promise(resolve => {
    const el = h(`<div class="modal-back"><div class="modal ${wide ? 'wide' : ''}">
      ${title ? `<h2>${title}</h2>` : ''}<div class="modal-body"></div>
      <div class="modal-btns"></div></div></div>`);
    const bodyEl = $('.modal-body', el);
    if (typeof body === 'string') bodyEl.innerHTML = body; else if (body) bodyEl.appendChild(body);
    const btns = $('.modal-btns', el);
    const close = v => { el.classList.add('out'); setTimeout(() => el.remove(), 180); Input.popLayer(layer); resolve(v); };
    buttons.forEach((b, i) => {
      const btn = h(`<button class="btn ${b.primary ? 'primary' : ''} ${b.danger ? 'danger' : ''}" data-nav>${b.label}</button>`);
      btn.onclick = () => { Audio2.sfx('select'); close(b.value); };
      btns.appendChild(btn);
    });
    document.body.appendChild(el);
    const layer = Input.pushLayer(el, () => close(buttons.find(b => b.cancel)?.value ?? null));
    if (onOpen) onOpen(el, close);
    Input.focusFirst(el);
  });
}
