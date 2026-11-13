/* ============================================================
   CORE / SAVE — persistent save system (localStorage, versioned)
   ============================================================ */
const SAVE_KEY = 'pf27_save_v1';
const SAVE_VERSION = 1;

function defaultSettings() {
  return { music: 0.5, sfx: 0.8, crowd: 0.7, difficulty: 'professional', halfLen: 3, camera: 'broadcast', autoSim: false, showLinks: true, reduceMotion: false };
}

function newSave(name) {
  return {
    v: SAVE_VERSION, created: Date.now(),
    profile: {
      name: name || 'Manager', clubName: 'Phoenix FC', level: 1, xp: 0,
      badge: { shape: 'shield', c1: '#e8b631', c2: '#14161c', icon: 'star' },
      kit: { home: { c1: '#e8b631', c2: '#14161c', pattern: 'plain' }, away: { c1: '#f2f2f2', c2: '#2a6fdb', pattern: 'sash' } },
      stadium: { name: 'Phoenix Park', theme: 'gold', tifo: 'flames', seats: '#3a3f4d' },
      history: [{ t: Date.now(), text: 'Club founded' }]
    },
    coins: 5000, points: 500,
    tx: [{ t: Date.now(), kind: 'reward', amount: 5000, cur: 'coins', desc: 'Welcome bonus' }, { t: Date.now(), kind: 'reward', amount: 500, cur: 'points', desc: 'Welcome Prime Points' }],
    club: { items: [] },
    squads: [], activeSquad: 0,
    unopened: [],                       // pack ids owned (from rewards)
    market: { listings: [], mine: [], bids: [], history: [], lastGen: 0, demand: {} },
    objectives: { progress: {}, claimed: {}, dailyKey: '', weeklyKey: '' },
    sbc: { done: {} },
    modes: {
      sb: { weekKey: '', points: 0, played: 0, history: [] },
      rivals: { div: 10, pts: 0, played: 0, wins: 0, best: 10, weekWins: 0, weekKey: '' },
      champs: { tickets: 0, active: null, history: [] },
      draft: { active: null, history: [], tokens: 0 }
    },
    matches: [],
    stats: { played: 0, wins: 0, draws: 0, losses: 0, gf: 0, ga: 0, packs: 0, sbcs: 0, sold: 0, bought: 0, assists: 0 },
    settings: defaultSettings(),
    onboarded: false
  };
}

const Save = {
  data: null,
  _t: null,
  load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw) {
        const d = JSON.parse(raw);
        if (d && d.v === SAVE_VERSION) { this.data = this.migrate(d); return true; }
      }
    } catch (e) { console.warn('Save load failed', e); }
    this.data = null;
    return false;
  },
  migrate(d) {
    const base = newSave(d.profile?.name);
    // shallow fill of any missing keys so older saves keep working as systems are added
    for (const k in base) if (d[k] === undefined) d[k] = base[k];
    for (const k in base.settings) if (d.settings[k] === undefined) d.settings[k] = base.settings[k];
    for (const k in base.modes) if (!d.modes[k]) d.modes[k] = base.modes[k];
    for (const k in base.stats) if (d.stats[k] === undefined) d.stats[k] = base.stats[k];
    return d;
  },
  create(name) { this.data = newSave(name); this.now(); },
  // debounced autosave
  dirty() { clearTimeout(this._t); this._t = setTimeout(() => this.now(), 250); },
  now() {
    try { localStorage.setItem(SAVE_KEY, JSON.stringify(this.data)); }
    catch (e) { console.warn('Save failed', e); toast('Save failed — storage unavailable', 'bad'); }
  },
  wipe() { try { localStorage.removeItem(SAVE_KEY); } catch (e) { } this.data = null; },
  exportJSON() { return JSON.stringify(this.data); },
  importJSON(txt) {
    const d = JSON.parse(txt);
    if (!d || d.v !== SAVE_VERSION) throw new Error('Not a Prime Football 27 save');
    this.data = this.migrate(d); this.now();
  }
};
window.addEventListener('beforeunload', () => { if (Save.data) Save.now(); });
