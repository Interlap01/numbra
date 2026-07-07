// fx.jsx — sound, haptics, and confetti for Numbra.
// Exports (to window): FX (sound/haptics singleton), Confetti (React component)

const FX = (() => {
  let ctx = null;
  let master = null;
  function ac() {
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return null;
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = 0.5;
      master.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume();
    return ctx;
  }
  // warm pentatonic so any sequence sounds pleasant
  const SCALE = [392.0, 440.0, 523.25, 587.33, 659.25, 783.99, 880.0]; // G A C D E G A

  let enabled = true;
  function note(freq, dur, type, gain, when) {
    const c = ac(); if (!c || !enabled) return;
    const t0 = (when || c.currentTime);
    const o = c.createOscillator(), g = c.createGain();
    o.type = type || 'sine'; o.frequency.value = freq;
    o.connect(g); g.connect(master);
    const peak = gain == null ? 0.16 : gain;
    g.gain.setValueAtTime(0.0001, t0);
    g.gain.exponentialRampToValueAtTime(peak, t0 + 0.012);
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    o.start(t0); o.stop(t0 + dur + 0.02);
  }

  let ambGain = null, ambNodes = [];
  return {
    setEnabled(v) { enabled = v; if (!v) this.ambienceOff(); },
    isEnabled() { return enabled; },
    // a soft pluck whose pitch wanders by colour index
    fill(ci) {
      const f = SCALE[((ci || 0) * 2) % SCALE.length];
      note(f, 0.35, 'sine', 0.13);
      note(f * 2.001, 0.22, 'triangle', 0.04);
    },
    magic() {
      const c = ac(); if (!c || !enabled) return;
      for (let i = 0; i < 5; i++) note(SCALE[i + 1], 0.3, 'triangle', 0.08, c.currentTime + i * 0.05);
    },
    complete() {
      const c = ac(); if (!c || !enabled) return;
      [523.25, 659.25, 783.99, 1046.5].forEach((f, i) => note(f, 1.1, 'sine', 0.12, c.currentTime + i * 0.07));
    },
    ambienceOn() {
      const c = ac(); if (!c || !enabled || ambNodes.length) return;
      ambGain = c.createGain(); ambGain.gain.value = 0; ambGain.connect(master);
      ambGain.gain.linearRampToValueAtTime(0.08, c.currentTime + 2);
      const lp = c.createBiquadFilter(); lp.type = 'lowpass'; lp.frequency.value = 620; lp.connect(ambGain);
      [196, 261.63, 392].forEach((f, i) => {
        const o = c.createOscillator(); o.type = 'sine'; o.frequency.value = f;
        const og = c.createGain(); og.gain.value = 0.5 / (i + 1);
        // slow tremolo
        const lfo = c.createOscillator(); lfo.frequency.value = 0.07 + i * 0.03;
        const lg = c.createGain(); lg.gain.value = 0.25;
        lfo.connect(lg); lg.connect(og.gain);
        o.connect(og); og.connect(lp);
        o.start(); lfo.start();
        ambNodes.push(o, lfo);
      });
    },
    ambienceOff() {
      const c = ctx; if (!ambGain || !c) { ambNodes = []; return; }
      ambGain.gain.cancelScheduledValues(c.currentTime);
      ambGain.gain.linearRampToValueAtTime(0, c.currentTime + 0.8);
      const nodes = ambNodes; ambNodes = [];
      setTimeout(() => { nodes.forEach((n) => { try { n.stop(); } catch (e) {} }); ambGain = null; }, 900);
    },
    haptic(kind) {
      if (!navigator.vibrate) return;
      if (kind === 'wrong') navigator.vibrate([18, 30, 18]);
      else if (kind === 'complete') navigator.vibrate([12, 40, 12, 40, 30]);
      else navigator.vibrate(9);
    },
  };
})();

function Confetti({ run = true, duration = 2600 }) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    if (!run) return;
    const cv = ref.current; if (!cv) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const W = cv.clientWidth, H = cv.clientHeight;
    cv.width = W * dpr; cv.height = H * dpr;
    const ctx = cv.getContext('2d'); ctx.scale(dpr, dpr);
    const cols = ['#C9694A', '#6E8B6A', '#E3C34A', '#4F6FB0', '#E8748C', '#F4A259'];
    const N = 130;
    const ps = Array.from({ length: N }, () => ({
      x: W / 2 + (Math.random() - 0.5) * W * 0.5, y: H * 0.32 + (Math.random() - 0.5) * 40,
      vx: (Math.random() - 0.5) * 7, vy: -6 - Math.random() * 7,
      g: 0.18 + Math.random() * 0.12, s: 4 + Math.random() * 6,
      rot: Math.random() * 6.28, vr: (Math.random() - 0.5) * 0.4,
      col: cols[(Math.random() * cols.length) | 0], shape: Math.random() < 0.5 ? 0 : 1,
    }));
    const t0 = performance.now(); let raf;
    const tick = (now) => {
      const k = (now - t0) / duration;
      ctx.clearRect(0, 0, W, H);
      ps.forEach((p) => {
        p.vy += p.g; p.x += p.vx; p.y += p.vy; p.vx *= 0.99; p.rot += p.vr;
        ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.rot);
        ctx.globalAlpha = Math.max(0, 1 - k);
        ctx.fillStyle = p.col;
        if (p.shape === 0) ctx.fillRect(-p.s / 2, -p.s / 3, p.s, p.s * 0.66);
        else { ctx.beginPath(); ctx.arc(0, 0, p.s / 2, 0, 7); ctx.fill(); }
        ctx.restore();
      });
      if (k < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [run]);
  return <canvas ref={ref} style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', pointerEvents: 'none', zIndex: 5 }} />;
}

Object.assign(window, { FX, Confetti });
