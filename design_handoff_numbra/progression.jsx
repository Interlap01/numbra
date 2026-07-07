// progression.jsx — XP, levels, streaks, daily challenge, achievements.
// Exports (to window): Progress

const Progress = (() => {
  const KEY = 'numbra_progress_v1';
  const DEFAULTS = {
    xp: 0, completed: 0, totalPieces: 0, perfectRuns: 0,
    streak: 0, maxStreak: 0, lastPlayDay: null, dailyDoneDay: null,
    customMade: 0, hardDone: 0, unlocked: {},
  };
  function today() { return new Date().toISOString().slice(0, 10); }
  function dayDiff(a, b) {
    if (!a || !b) return Infinity;
    return Math.round((new Date(b) - new Date(a)) / 86400000);
  }
  function load() {
    try { return Object.assign({}, DEFAULTS, JSON.parse(localStorage.getItem(KEY) || '{}')); }
    catch (e) { return Object.assign({}, DEFAULTS); }
  }
  function save(p) { try { localStorage.setItem(KEY, JSON.stringify(p)); } catch (e) {} }

  function levelFor(xp) {
    let lvl = 1, need = 120, rem = xp;
    while (rem >= need) { rem -= need; lvl++; need = 120 * lvl; }
    return { level: lvl, into: rem, need, pct: rem / need };
  }

  const ACHIEVEMENTS = [
    { id: 'first', title: 'First Strokes', desc: 'Finish your first canvas', icon: 'brush', test: (p) => p.completed >= 1 },
    { id: 'flawless', title: 'Flawless', desc: 'Finish with zero mistakes', icon: 'check', test: (p) => p.perfectRuns >= 1 },
    { id: 'collector', title: 'Collector', desc: 'Complete 5 canvases', icon: 'grid', test: (p) => p.completed >= 5 },
    { id: 'marathon', title: 'Marathon', desc: 'Paint 1,000 pieces', icon: 'palette', test: (p) => p.totalPieces >= 1000 },
    { id: 'onfire', title: 'On a Roll', desc: '3-day streak', icon: 'drop', test: (p) => p.maxStreak >= 3 },
    { id: 'devoted', title: 'Devoted', desc: '7-day streak', icon: 'star', test: (p) => p.maxStreak >= 7 },
    { id: 'lvl5', title: 'Rising Artist', desc: 'Reach level 5', icon: 'sparkle', test: (p) => levelFor(p.xp).level >= 5 },
    { id: 'transformer', title: 'Alchemist', desc: 'Transform your own photo', icon: 'image', test: (p) => p.customMade >= 1 },
    { id: 'master', title: 'Master Hand', desc: 'Finish a Hard canvas', icon: 'wand', test: (p) => p.hardDone >= 1 },
  ];

  // called when the app opens — maintains streak continuity
  function touchOpen() {
    const p = load();
    const d = dayDiff(p.lastPlayDay, today());
    if (p.lastPlayDay && d > 1) p.streak = 0; // missed a day
    save(p);
    return p;
  }
  // mark today as played (called when a session starts)
  function play() {
    const p = load();
    const d = dayDiff(p.lastPlayDay, today());
    if (p.lastPlayDay == null) p.streak = 1;
    else if (d === 1) p.streak += 1;
    else if (d > 1) p.streak = 1;
    // d===0 same day → unchanged
    p.maxStreak = Math.max(p.maxStreak, p.streak);
    p.lastPlayDay = today();
    save(p);
    return p;
  }

  function recordCompletion({ pieces, mistakes, isCustom, isHard, isDaily }) {
    const p = load();
    const gain = 50 + Math.min(70, pieces) + (mistakes === 0 ? 30 : 0) + (isDaily ? 25 : 0);
    const beforeLvl = levelFor(p.xp).level;
    p.xp += gain;
    p.completed += 1;
    p.totalPieces += pieces;
    if (mistakes === 0) p.perfectRuns += 1;
    if (isCustom) p.customMade += 1;
    if (isHard) p.hardDone += 1;
    if (isDaily) p.dailyDoneDay = today();
    const newly = [];
    ACHIEVEMENTS.forEach((a) => { if (!p.unlocked[a.id] && a.test(p)) { p.unlocked[a.id] = today(); newly.push(a); } });
    save(p);
    const afterLvl = levelFor(p.xp).level;
    return { xpGain: gain, leveledUp: afterLvl > beforeLvl, level: afterLvl, newly, progress: p };
  }

  // deterministic daily pick from a list length
  function dailyIndex(n) {
    const s = today().replace(/-/g, '');
    let h = 0; for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
    return h % n;
  }
  function dailyDone() { return load().dailyDoneDay === today(); }

  return { load, save, levelFor, ACHIEVEMENTS, touchOpen, play, recordCompletion, dailyIndex, dailyDone, today };
})();

window.Progress = Progress;
