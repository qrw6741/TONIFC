/* ============================================================
   UI / APP — router, transitions, shared chrome (top bar, hints)
   ============================================================ */
const SCREENS = {};
const HUB_TABS = [['home', 'Home'], ['objectives', 'Objectives'], ['play', 'Play'], ['club', 'Club'], ['sbc', 'SBC'], ['transfers', 'Transfers'], ['store', 'Store']];

const UI = {
  cur: null, curName: '', params: null, stack: [], timers: [],
  go(name, params = {}, { push = true, replace = false } = {}) {
    const S = SCREENS[name]; if (!S) { console.error('No screen', name); return; }
    this.timers.forEach(clearInterval); this.timers = [];
    if (this.cur) {
      if (push && !replace && this.curName) this.stack.push({ name: this.curName, params: this.params });
      const old = this.cur; old.classList.add('out'); setTimeout(() => old.remove(), 260);
    }
    if (!push) { /* going back: stack already popped */ }
    this.curName = name; this.params = params;
    BG.set(S.bg || 'hub');
    const el = S.render(params);
    el.classList.add('screen');
    $('#screen').appendChild(el);
    this.cur = el;
    Input.mode = 'menu';
    Input.onTab = S.hub ? (d) => { const i = HUB_TABS.findIndex(t => t[0] === name); if (i < 0) return; const n = HUB_TABS[(i + d + HUB_TABS.length) % HUB_TABS.length][0]; Audio2.sfx('tab'); this.go(n, {}, { replace: true, push: false }); } : null;
    Input.setBase(el, () => S.back ? S.back() : this.back());
    requestAnimationFrame(() => Input.focusFirst(el));
    if (S.after) S.after(el, params);
    if (!Audio2.musicOn && Audio2.ctx && !S.noMusic) Audio2.musicStart();
  },
  back() {
    const prev = this.stack.pop();
    if (prev) this.go(prev.name, prev.params, { push: false });
  },
  reset(name, params) { this.stack = []; this.go(name, params, { push: false }); },
  rerender() { const n = this.curName, p = this.params; const st = this.stack.slice(); this.go(n, p, { push: false }); this.stack = st; },
  every(ms, fn) { const t = setInterval(fn, ms); this.timers.push(t); return t; },
  refreshCurrency() {
    $$('[data-coins]').forEach(e => e.textContent = fmtFull(Save.data.coins));
    $$('[data-points]').forEach(e => e.textContent = fmtFull(Save.data.points));
    $$('[data-level]').forEach(e => e.textContent = 'LVL ' + Save.data.profile.level);
  },
  refreshBadges() { const n = Objectives.claimable(); $$('[data-objdot]').forEach(e => e.classList.toggle('hidden', !n)); },
  onMarketChange: null
};

function currencyHTML() {
  return `<div class="cur"><span><i class="coin"></i><b data-coins>${fmtFull(Save.data.coins)}</b></span><span><i class="pts"></i><b data-points>${fmtFull(Save.data.points)}</b></span><span class="lvl" data-level>LVL ${Save.data.profile.level}</span></div>`;
}
function hintsHTML(extra = '') {
  return `<div class="hints"><span><span class="k">A</span>Select <span class="dim" style="font-weight:500">(Enter)</span></span><span><span class="k">B</span>Back <span class="dim" style="font-weight:500">(Esc)</span></span>${extra}</div>`;
}
/* builds the hub chrome; returns {el, body} */
function hubShell(tab, { title } = {}) {
  const el = h(`<div class="hub">
    <div class="topbar">
      <div class="row" style="gap:14px"><div class="hub-crest">${badgeSVG(Save.data.profile.badge, 50)}</div><div class="hub-title">Ultimate XI</div></div>
      <div class="hub-tabs"><span class="lbrb">Q</span>${HUB_TABS.map(([k, l]) => `<button class="tab ${k === tab ? 'on' : ''}" data-nav data-tab="${k}">${l}${k === 'objectives' ? '<span class="dot hidden" data-objdot></span>' : ''}</button>`).join('')}<span class="lbrb">E</span></div>
      ${currencyHTML()}
    </div>
    <div class="hub-body"></div>
    ${hintsHTML(`<span class="r"><span class="k">Q</span><span class="k">E</span>Switch tab · <span class="k">LB</span><span class="k">RB</span></span>`)}
  </div>`);
  $$('.tab', el).forEach(b => b.onclick = () => { if (b.dataset.tab !== tab) { Audio2.sfx('tab'); UI.go(b.dataset.tab, {}, { replace: true, push: false }); } });
  setTimeout(() => UI.refreshBadges(), 0);
  return { el, body: $('.hub-body', el) };
}
/* sub-screen chrome inside hub (title + back) */
function subShell(title, subtitle = '') {
  const el = h(`<div class="hub">
    <div class="topbar"><div class="row" style="gap:14px"><div class="hub-crest">${badgeSVG(Save.data.profile.badge, 44)}</div>
      <div><div class="dim" style="font-size:12px;font-weight:800;letter-spacing:.1em;text-transform:uppercase">${subtitle || 'Ultimate XI'}</div><div style="font-weight:900;font-size:24px">${title}</div></div></div>
      ${currencyHTML()}</div>
    <div class="hub-body"></div>${hintsHTML()}</div>`);
  return { el, body: $('.hub-body', el) };
}
