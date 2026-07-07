// studio-extras.jsx — TimelapsePlayer, ShareCard, AchievementsSheet, LevelBadge,
// DailyBanner, PacksRail.
// Exports (to window): TimelapsePlayer, ShareCard, AchievementsSheet, LevelBadge,
//                      DailyBanner, PacksRail

// ─── Timelapse replay ────────────────────────────────────────
function TimelapsePlayer({ data, order, paper = '#F7F3EA', onClose }) {
  const cref = React.useRef(null);
  const wrapRef = React.useRef(null);
  const stRef = React.useRef({}).current;
  const [idx, setIdx] = React.useState(0);
  const [playing, setPlaying] = React.useState(true);
  const [speed, setSpeed] = React.useState(1);
  // fall back to a natural order if none was recorded
  const seq = React.useMemo(() => {
    if (order && order.length === data.regionCount) return order;
    const all = Array.from({ length: data.regionCount }, (_, i) => i);
    all.sort((a, b) => data.regionColor[a] - data.regionColor[b] || a - b);
    return all;
  }, [order, data]);
  const total = seq.length;

  React.useEffect(() => {
    const cv = cref.current, wrap = wrapRef.current;
    const W = wrap.clientWidth, H = wrap.clientHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    cv.width = W * dpr; cv.height = H * dpr;
    const ctx = cv.getContext('2d');
    const fit = Math.min((W - 40) / data.w, (H - 40) / data.h);
    const off = document.createElement('canvas'); off.width = data.w; off.height = data.h;
    const octx = off.getContext('2d');
    const img = octx.createImageData(data.w, data.h);
    const path = new Path2D();
    const seg = data.segments;
    for (let i = 0; i < seg.length; i += 4) { path.moveTo(seg[i], seg[i + 1]); path.lineTo(seg[i + 2], seg[i + 3]); }
    stRef.ctx = ctx; stRef.off = off; stRef.octx = octx; stRef.img = img; stRef.path = path;
    stRef.fit = fit; stRef.W = W; stRef.H = H; stRef.dpr = dpr; stRef.rendered = -1;
    renderUpTo(idx);
    // eslint-disable-next-line
  }, [data]);

  function renderUpTo(k) {
    const { octx, img, off, ctx, path, fit, W, H, dpr } = stRef;
    if (!octx) return;
    const d = img.data;
    const pr = parseInt(paper.slice(1, 3), 16), pg = parseInt(paper.slice(3, 5), 16), pb = parseInt(paper.slice(5, 7), 16);
    for (let i = 0; i < data.w * data.h; i++) { d[i * 4] = pr; d[i * 4 + 1] = pg; d[i * 4 + 2] = pb; d[i * 4 + 3] = 255; }
    for (let n = 0; n < k; n++) {
      const r = seq[n]; const col = data.palette[data.regionColor[r]];
      for (const p of data.regionPixels[r]) { d[p * 4] = col.r; d[p * 4 + 1] = col.g; d[p * 4 + 2] = col.b; d[p * 4 + 3] = 255; }
    }
    octx.putImageData(img, 0, 0);
    ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.clearRect(0, 0, W * dpr, H * dpr);
    const ox = (W - data.w * fit) / 2, oy = (H - data.h * fit) / 2;
    ctx.setTransform(fit * dpr, 0, 0, fit * dpr, ox * dpr, oy * dpr);
    ctx.save(); ctx.shadowColor = 'rgba(0,0,0,0.25)'; ctx.shadowBlur = 20 / fit; ctx.shadowOffsetY = 6 / fit;
    ctx.fillStyle = paper; ctx.fillRect(0, 0, data.w, data.h); ctx.restore();
    ctx.imageSmoothingEnabled = false; ctx.drawImage(off, 0, 0);
    ctx.lineWidth = Math.max(0.4, 0.7 / fit); ctx.strokeStyle = 'rgba(60,45,30,0.22)';
    ctx.lineJoin = 'round'; ctx.stroke(path);
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    stRef.rendered = k;
  }

  React.useEffect(() => { renderUpTo(idx); /* eslint-disable-next-line */ }, [idx]);

  React.useEffect(() => {
    if (!playing) return;
    let raf, last = performance.now(), acc = 0;
    const perStep = 26 / speed; // ms per piece
    const loop = (now) => {
      acc += now - last; last = now;
      if (acc >= perStep) {
        const add = Math.floor(acc / perStep); acc = acc % perStep;
        setIdx((v) => {
          const nv = Math.min(total, v + add);
          if (nv >= total) setPlaying(false);
          return nv;
        });
      }
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, [playing, speed, total]);

  const done = idx >= total;
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 92, background: 'var(--canvas-bg, #16130f)', display: 'flex', flexDirection: 'column' }}>
      <div style={{ background: '#16130f', position: 'absolute', inset: 0 }} />
      <div style={{ position: 'relative', zIndex: 1, padding: '56px 16px 8px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontFamily: 'var(--display)', fontSize: 22, color: '#fff' }}>Timelapse</span>
        <button onClick={onClose} style={{ width: 40, height: 40, borderRadius: 99, border: 'none', background: 'rgba(255,255,255,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <Icon name="close" size={20} stroke="#fff" sw={2.2} />
        </button>
      </div>
      <div ref={wrapRef} style={{ position: 'relative', zIndex: 1, flex: 1, margin: '0 8px' }}>
        <canvas ref={cref} style={{ width: '100%', height: '100%', display: 'block' }} />
      </div>
      <div style={{ position: 'relative', zIndex: 1, padding: '12px 22px calc(28px + env(safe-area-inset-bottom))' }}>
        <input type="range" min={0} max={total} value={idx} onChange={(e) => { setPlaying(false); setIdx(+e.target.value); }}
          style={{ width: '100%', accentColor: 'var(--terra)' }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18, marginTop: 10 }}>
          <button onClick={() => { setIdx(0); setPlaying(true); }} style={tlBtn()}><Icon name="back" size={20} stroke="#fff" sw={2} /></button>
          <button onClick={() => { if (done) { setIdx(0); setPlaying(true); } else setPlaying((p) => !p); }} style={{ ...tlBtn(), width: 58, height: 58, background: 'var(--terra)' }}>
            <Icon name={playing && !done ? 'minus' : 'play'} size={26} stroke="#fff" sw={2.2} />
          </button>
          <button onClick={() => setSpeed((s) => (s >= 4 ? 1 : s * 2))} style={{ ...tlBtn(), width: 'auto', padding: '0 14px', fontFamily: 'var(--ui)', fontWeight: 800, color: '#fff', fontSize: 14 }}>{speed}×</button>
        </div>
      </div>
    </div>
  );
}
function tlBtn() { return { width: 46, height: 46, borderRadius: 99, border: 'none', background: 'rgba(255,255,255,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }; }

// ─── Before / after share card ───────────────────────────────
function ShareCard({ before, after, title, time, pieces, isPlus, onPaywall, onClose }) {
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 92, display: 'flex', flexDirection: 'column' }}>
      <div onClick={onClose} style={{ position: 'absolute', inset: 0, background: 'rgba(20,14,8,0.6)', backdropFilter: 'blur(3px)' }} />
      <div style={{ position: 'relative', zIndex: 1, margin: 'auto', width: 320, background: 'var(--card)', borderRadius: 26, overflow: 'hidden', boxShadow: '0 24px 60px rgba(0,0,0,0.4)' }}>
        <div style={{ padding: '20px 20px 14px', background: 'var(--ink)' }}>
          <div style={{ display: 'flex', gap: 10 }}>
            <Frame img={before} label="Photo" />
            <Frame img={after} label="Painted" />
          </div>
        </div>
        <div style={{ padding: '16px 20px 20px' }}>
          <div style={{ fontFamily: 'var(--ui)', fontSize: 12, fontWeight: 800, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--terra)' }}>Numbra</div>
          <div style={{ fontFamily: 'var(--display)', fontSize: 26, color: 'var(--ink)', marginTop: 2 }}>{title}</div>
          <div style={{ display: 'flex', gap: 16, marginTop: 8, fontFamily: 'var(--ui)', fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>
            <span>⏱ {time}</span><span>◧ {pieces} pieces</span>
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
            <Btn variant="soft" size="md" icon="share" style={{ flex: 1 }}>Share</Btn>
            <Btn variant={isPlus ? 'primary' : 'dark'} size="md" icon={isPlus ? 'check' : 'lock'} style={{ flex: 1 }}
              onClick={() => { if (!isPlus) onPaywall && onPaywall(); }}>{isPlus ? 'Save HD' : 'HD · Plus'}</Btn>
          </div>
        </div>
      </div>
      <button onClick={onClose} style={{ position: 'relative', zIndex: 1, margin: '0 auto 30px', background: 'none', border: 'none', color: 'rgba(255,255,255,0.85)', fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 15, cursor: 'pointer' }}>Close</button>
    </div>
  );
}
function Frame({ img, label }) {
  return (
    <div style={{ flex: 1 }}>
      <div style={{ aspectRatio: '1', borderRadius: 14, overflow: 'hidden', background: '#fff', boxShadow: 'inset 0 0 0 4px rgba(255,255,255,0.9)' }}>
        <img src={img} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      </div>
      <div style={{ textAlign: 'center', marginTop: 6, fontFamily: 'var(--ui)', fontSize: 11, fontWeight: 700, color: 'rgba(255,255,255,0.7)', textTransform: 'uppercase', letterSpacing: '0.08em' }}>{label}</div>
    </div>
  );
}

// ─── Level badge (gallery header) ────────────────────────────
function LevelBadge({ progress, onClick }) {
  const lv = Progress.levelFor(progress.xp);
  return (
    <button onClick={onClick} style={{ border: 'none', background: 'none', cursor: 'pointer', padding: 0 }}>
      <Ring value={lv.pct} size={48} sw={4}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', lineHeight: 1 }}>
          <span style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 15, color: 'var(--ink)' }}>{lv.level}</span>
          <span style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 7.5, color: 'var(--muted)', letterSpacing: '0.1em' }}>LVL</span>
        </div>
      </Ring>
    </button>
  );
}

// ─── Achievements sheet ──────────────────────────────────────
function AchievementsSheet({ progress, onClose }) {
  const lv = Progress.levelFor(progress.xp);
  return (
    <div style={{ padding: '2px 4px 0' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '4px 4px 16px' }}>
        <Ring value={lv.pct} size={58} sw={5} color="var(--terra)">
          <span style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 20, color: 'var(--ink)' }}>{lv.level}</span>
        </Ring>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: 'var(--display)', fontSize: 24, color: 'var(--ink)' }}>Level {lv.level}</div>
          <div style={{ fontFamily: 'var(--ui)', fontSize: 13, color: 'var(--muted)', fontWeight: 600 }}>{lv.into} / {lv.need} XP to next · {progress.completed} finished</div>
        </div>
        {progress.streak > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', background: 'rgba(224,73,47,0.1)', borderRadius: 14, padding: '8px 12px' }}>
            <Icon name="drop" size={18} stroke="var(--terra)" fill="var(--terra)" sw={1.4} />
            <span style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 15, color: 'var(--ink)' }}>{progress.streak}</span>
          </div>
        )}
      </div>
      <div style={{ fontFamily: 'var(--ui)', fontSize: 12.5, fontWeight: 800, letterSpacing: '0.1em', textTransform: 'uppercase', color: 'var(--muted)', padding: '0 4px 10px' }}>Achievements</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, maxHeight: 300, overflowY: 'auto', paddingBottom: 8 }}>
        {Progress.ACHIEVEMENTS.map((a) => {
          const got = !!progress.unlocked[a.id];
          return (
            <div key={a.id} style={{ display: 'flex', gap: 10, alignItems: 'center', padding: '12px', borderRadius: 16, background: got ? 'rgba(30,138,120,0.12)' : 'var(--card-2)', opacity: got ? 1 : 0.6, minHeight: 62 }}>
              <div style={{ width: 38, height: 38, borderRadius: 11, flexShrink: 0, background: got ? 'var(--sage)' : 'rgba(0,0,0,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <Icon name={got ? a.icon : 'lock'} size={20} stroke="#fff" sw={1.9} />
              </div>
              <div style={{ minWidth: 0 }}>
                <div style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 13, color: 'var(--ink)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{a.title}</div>
                <div style={{ fontFamily: 'var(--ui)', fontSize: 11, color: 'var(--muted)', lineHeight: 1.25 }}>{a.desc}</div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ─── Daily challenge banner ──────────────────────────────────
function DailyBanner({ sample, done, streak, onStart }) {
  return (
    <div style={{ margin: '14px 18px 0', borderRadius: 22, background: 'var(--ink)', overflow: 'hidden', display: 'flex', alignItems: 'center', gap: 14, padding: 12 }}>
      <div style={{ width: 70, height: 70, borderRadius: 16, overflow: 'hidden', flexShrink: 0, position: 'relative' }}>
        <img src={sample.thumb.toDataURL ? sample.thumb.toDataURL() : sample.thumb} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        {done && <div style={{ position: 'absolute', inset: 0, background: 'rgba(30,138,120,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="check" size={28} stroke="#fff" sw={3} /></div>}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ fontFamily: 'var(--ui)', fontSize: 11.5, fontWeight: 800, letterSpacing: '0.12em', textTransform: 'uppercase', color: 'var(--terra)', whiteSpace: 'nowrap' }}>Daily challenge</span>
          {streak > 0 && <span style={{ display: 'inline-flex', alignItems: 'center', gap: 3, fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 12, color: '#f3a64b' }}><Icon name="drop" size={13} stroke="#f3a64b" fill="#f3a64b" sw={1.2} />{streak}</span>}
        </div>
        <div style={{ fontFamily: 'var(--display)', fontSize: 20, color: '#fff', marginTop: 1 }}>{done ? 'Done for today' : sample.title}</div>
      </div>
      <button onClick={done ? undefined : onStart} style={{
        border: 'none', cursor: done ? 'default' : 'pointer', borderRadius: 999, padding: '10px 18px',
        background: done ? 'rgba(255,255,255,0.14)' : 'var(--terra)', color: '#fff', fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 14, flexShrink: 0,
      }}>{done ? '✓' : 'Start'}</button>
    </div>
  );
}

// ─── Themed packs rail ───────────────────────────────────────
function PacksRail({ packs, onOpen }) {
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '22px 22px 12px' }}>
        <h2 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 22, color: 'var(--ink)', fontWeight: 400, whiteSpace: 'nowrap' }}>Themed packs</h2>
      </div>
      <div style={{ display: 'flex', gap: 14, overflowX: 'auto', padding: '0 18px 4px', scrollbarWidth: 'none' }}>
        {packs.map((p) => (
          <button key={p.id} onClick={() => onOpen(p)} style={{
            flex: '0 0 auto', width: 150, border: 'none', background: 'none', cursor: 'pointer', padding: 0, textAlign: 'left',
          }}>
            <div style={{ position: 'relative', width: 150, height: 100, borderRadius: 20, overflow: 'hidden', boxShadow: '0 8px 20px rgba(60,40,25,0.12)' }}>
              <div style={{ position: 'absolute', inset: 0, display: 'flex' }}>
                {p.covers.map((cv, i) => <div key={i} style={{ flex: 1 }}><img src={cv} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} /></div>)}
              </div>
              <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(15,10,6,0.55), transparent 55%)' }} />
              {p.plus && (
                <div style={{ position: 'absolute', top: 8, right: 8, display: 'flex', alignItems: 'center', gap: 4, background: 'rgba(0,0,0,0.5)', borderRadius: 99, padding: '4px 9px 4px 7px' }}>
                  <Icon name="lock" size={12} stroke="#fff" sw={2} /><span style={{ color: '#fff', fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 10.5 }}>PLUS</span>
                </div>
              )}
              <div style={{ position: 'absolute', left: 12, bottom: 9, color: '#fff', fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 15 }}>{p.title}</div>
            </div>
            <div style={{ padding: '7px 4px 0', fontFamily: 'var(--ui)', fontSize: 12.5, color: 'var(--muted)', fontWeight: 600 }}>{p.count} scenes</div>
          </button>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { TimelapsePlayer, ShareCard, AchievementsSheet, LevelBadge, DailyBanner, PacksRail });
