/* ============================================================
   CORE / AUDIO — fully synthesized music + SFX (WebAudio, no assets)
   ============================================================ */
const Audio2 = {
  ctx: null, master: null, musicGain: null, sfxGain: null, crowdGain: null,
  musicOn: false, _timer: null, _step: 0, _nextT: 0, noiseBuf: null, crowdSrc: null, crowdFilter: null,
  init() {
    if (this.ctx) return;
    try {
      const AC = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AC();
    } catch (e) { return; }
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = 0.9; this.master.connect(c.destination);
    const comp = c.createDynamicsCompressor(); comp.connect(this.master);
    this.musicGain = c.createGain(); this.musicGain.connect(comp);
    this.sfxGain = c.createGain(); this.sfxGain.connect(comp);
    this.crowdGain = c.createGain(); this.crowdGain.gain.value = 0; this.crowdGain.connect(comp);
    const len = c.sampleRate * 2, buf = c.createBuffer(1, len, c.sampleRate), d = buf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this.noiseBuf = buf;
    this.applyVolumes();
  },
  resume() { this.init(); if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); },
  applyVolumes() {
    if (!this.ctx) return;
    const s = Save.data?.settings || defaultSettings();
    this.musicGain.gain.value = s.music * 0.32;
    this.sfxGain.gain.value = s.sfx * 0.7;
    this._crowdBase = s.crowd;
  },
  tone(freq, dur, { type = 'sine', vol = 0.3, attack = 0.005, when = 0, slide = 0, dest } = {}) {
    if (!this.ctx) return;
    const c = this.ctx, t = c.currentTime + when;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type; o.frequency.setValueAtTime(freq, t);
    if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(20, freq * slide), t + dur);
    g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g); g.connect(dest || this.sfxGain); o.start(t); o.stop(t + dur + 0.05);
  },
  noise(dur, { vol = 0.3, freq = 1200, q = 1, type = 'bandpass', when = 0, attack = 0.005, dest, slide = 0 } = {}) {
    if (!this.ctx) return;
    const c = this.ctx, t = c.currentTime + when;
    const s = c.createBufferSource(); s.buffer = this.noiseBuf; s.loop = true;
    const f = c.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(freq, t); f.Q.value = q;
    if (slide) f.frequency.exponentialRampToValueAtTime(freq * slide, t + dur);
    const g = c.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + attack);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    s.connect(f); f.connect(g); g.connect(dest || this.sfxGain); s.start(t); s.stop(t + dur + 0.05);
  },
  sfx(name) {
    if (!this.ctx) return;
    switch (name) {
      case 'move': this.tone(1800, 0.04, { type: 'triangle', vol: 0.07 }); break;
      case 'select': this.tone(880, 0.08, { type: 'triangle', vol: 0.18 }); this.tone(1320, 0.12, { type: 'triangle', vol: 0.14, when: 0.05 }); break;
      case 'back': this.tone(660, 0.1, { type: 'triangle', vol: 0.15, slide: 0.6 }); break;
      case 'error': this.tone(200, 0.18, { type: 'square', vol: 0.08 }); this.tone(150, 0.2, { type: 'square', vol: 0.08, when: 0.09 }); break;
      case 'coin': this.tone(1568, 0.08, { type: 'square', vol: 0.06 }); this.tone(2093, 0.18, { type: 'square', vol: 0.06, when: 0.07 }); break;
      case 'whoosh': this.noise(0.6, { vol: 0.35, freq: 400, slide: 8, q: 0.8 }); break;
      case 'tab': this.noise(0.12, { vol: 0.12, freq: 3000, q: 2 }); break;
      case 'boom': this.tone(70, 1.2, { type: 'sine', vol: 0.8, slide: 0.4 }); this.noise(0.8, { vol: 0.4, freq: 200, type: 'lowpass' }); break;
      case 'riser': this.noise(1.6, { vol: 0.25, freq: 300, slide: 12, attack: 1.4 }); this.tone(220, 1.6, { type: 'sawtooth', vol: 0.05, slide: 4, attack: 1.4 }); break;
      case 'reveal': [523, 659, 784, 1047].forEach((f, i) => this.tone(f, 0.5, { type: 'triangle', vol: 0.15, when: i * 0.07 })); break;
      case 'bigreveal': [392, 523, 659, 784, 1047, 1319].forEach((f, i) => this.tone(f, 0.9, { type: 'sawtooth', vol: 0.06, when: i * 0.06 })); this.sfx('boom'); break;
      case 'whistle': this.tone(2900, 0.35, { type: 'sine', vol: 0.18 }); this.tone(3050, 0.35, { type: 'sine', vol: 0.1 }); break;
      case 'whistle3': [0, 0.45, 0.9].forEach(w => { this.tone(2900, w === 0.9 ? 0.8 : 0.3, { type: 'sine', vol: 0.18, when: w }); }); break;
      case 'kick': this.noise(0.08, { vol: 0.35, freq: 900, q: 1.5 }); this.tone(120, 0.08, { vol: 0.3, slide: 0.5 }); break;
      case 'post': this.tone(1200, 0.5, { type: 'triangle', vol: 0.25 }); this.tone(1800, 0.4, { type: 'sine', vol: 0.1 }); break;
      case 'net': this.noise(0.4, { vol: 0.3, freq: 600, q: 0.6, type: 'lowpass' }); break;
      case 'tackle': this.noise(0.15, { vol: 0.3, freq: 300, q: 1 }); break;
      case 'goalcrowd': this.noise(3.5, { vol: 0.7, freq: 900, q: 0.5, attack: 0.15, dest: this.crowdGain2() }); break;
      case 'ooh': this.noise(1.4, { vol: 0.4, freq: 700, q: 1, attack: 0.2, slide: 0.6, dest: this.crowdGain2() }); break;
    }
  },
  crowdGain2() { return this.sfxGain; },
  /* ambient crowd bed for matches */
  crowdStart() {
    if (!this.ctx || this.crowdSrc) return;
    const c = this.ctx;
    const s = c.createBufferSource(); s.buffer = this.noiseBuf; s.loop = true;
    const f = c.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 650; f.Q.value = 0.7;
    s.connect(f); f.connect(this.crowdGain); s.start();
    this.crowdSrc = s; this.crowdFilter = f;
    this.crowdLevel(0.25);
  },
  crowdLevel(x) { if (this.crowdGain && this.ctx) this.crowdGain.gain.setTargetAtTime(x * (this._crowdBase ?? 0.7) * 0.5, this.ctx.currentTime, 0.4); },
  crowdStop() { if (this.crowdSrc) { try { this.crowdSrc.stop(); } catch (e) { } this.crowdSrc = null; this.crowdLevel(0); } },

  /* procedural menu music: 4-chord synth pad + pulse bass + hats, 120bpm */
  musicStart() {
    if (!this.ctx || this.musicOn) return;
    this.musicOn = true; this._step = 0; this._nextT = this.ctx.currentTime + 0.1;
    const tick = () => {
      if (!this.musicOn) return;
      while (this._nextT < this.ctx.currentTime + 0.25) { this._schedule(this._step, this._nextT); this._step++; this._nextT += 0.125; }
      this._timer = setTimeout(tick, 60);
    };
    tick();
  },
  musicStop() { this.musicOn = false; clearTimeout(this._timer); },
  _schedule(step, t) {
    const c = this.ctx, when = t - c.currentTime;
    const chords = [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [55, 59, 62, 66]]; // Am9 Fmaj7 Cmaj7 G
    const bar = Math.floor(step / 16) % 4, s16 = step % 16;
    const mtof = m => 440 * Math.pow(2, (m - 69) / 12);
    const ch = chords[bar];
    if (s16 === 0) ch.forEach(n => this.tone(mtof(n), 2.0, { type: 'sawtooth', vol: 0.035, attack: 0.25, when, dest: this.musicGain }));
    if (s16 % 2 === 0) this.tone(mtof(ch[0] - 24), 0.2, { type: 'triangle', vol: s16 % 4 === 0 ? 0.35 : 0.2, when, dest: this.musicGain });
    if (s16 % 4 === 0) { this.tone(55, 0.25, { type: 'sine', vol: 0.5, slide: 0.5, when, dest: this.musicGain }); }
    if (s16 % 8 === 4) this.noise(0.18, { vol: 0.12, freq: 1800, q: 0.7, when, dest: this.musicGain });
    if (s16 % 2 === 1) this.noise(0.04, { vol: 0.05, freq: 8000, q: 1, type: 'highpass', when, dest: this.musicGain });
    const arp = [0, 2, 1, 3, 2, 1, 3, 0];
    if (s16 % 2 === 0 && bar % 2 === 1) this.tone(mtof(ch[arp[(s16 / 2) % 8]] + 12), 0.18, { type: 'square', vol: 0.025, when, dest: this.musicGain });
  }
};
