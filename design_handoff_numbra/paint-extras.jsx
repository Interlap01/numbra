// paint-extras.jsx — Minimap, TutorialOverlay, Toast.
// Exports (to window): Minimap, TutorialOverlay, Toast

function Minimap({ view, thumb, show }) {
  if (!view || !thumb) return null;
  const { scale, tx, ty, w, h, cssW, cssH, fit } = view;
  const visible = show && view.zoomed;
  const MW = 86, MH = Math.round(MW * (h / w));
  const sx = MW / w, sy = MH / h;
  // visible image rect in image coords
  const vx0 = Math.max(0, (-tx) / scale), vy0 = Math.max(0, (-ty) / scale);
  const vx1 = Math.min(w, (cssW - tx) / scale), vy1 = Math.min(h, (cssH - ty) / scale);
  return (
    <div style={{
      position: 'absolute', top: 116, left: 14, zIndex: 28,
      width: MW, height: MH, borderRadius: 10, overflow: 'hidden',
      boxShadow: '0 4px 14px rgba(0,0,0,0.25)', border: '2px solid rgba(255,255,255,0.85)',
      opacity: visible ? 1 : 0, transform: visible ? 'scale(1)' : 'scale(0.9)',
      transition: 'opacity .25s ease, transform .25s ease', pointerEvents: 'none',
    }}>
      <img src={thumb} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
      <div style={{
        position: 'absolute', left: vx0 * sx, top: vy0 * sy,
        width: (vx1 - vx0) * sx, height: (vy1 - vy0) * sy,
        border: '1.5px solid #fff', borderRadius: 3, boxShadow: '0 0 0 9999px rgba(20,15,10,0.32)',
      }} />
    </div>
  );
}

function TutorialOverlay({ onDone }) {
  const STEPS = [
    { title: 'Welcome to the canvas', body: 'Each area shows a number. Fill it with the matching color to reveal your painting.', target: null },
    { title: 'Your palette', body: 'Pick a color here — the matching numbers light up on the canvas. It greys out when finished.', target: { top: 792, left: 10, width: 384, height: 80 }, card: 'top' },
    { title: 'Two ways to color', body: 'Tap fills one piece at a time. Switch to Paint to drag your finger and fill as you go.', target: { top: 734, left: 14, width: 250, height: 48 }, card: 'top' },
    { title: 'Magic & hints', body: 'The wand fills every piece of the current color. Tap the target up top to fly to your next piece.', target: { top: 730, left: 326, width: 52, height: 52 }, card: 'top' },
  ];
  const [i, setI] = React.useState(0);
  const step = STEPS[i];
  const t = step.target;
  const cardTop = step.card === 'top' ? 300 : 470;
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 90 }}>
      {/* spotlight (or full dim when no target) */}
      {t ? (
        <div style={{ position: 'absolute', top: t.top, left: t.left, width: t.width, height: t.height, borderRadius: 16, boxShadow: '0 0 0 9999px rgba(18,13,8,0.62)', border: '2px solid rgba(255,255,255,0.9)', transition: 'all .3s ease' }} />
      ) : (
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(18,13,8,0.62)' }} />
      )}
      {/* card */}
      <div style={{ position: 'absolute', top: cardTop, left: 24, right: 24, background: 'var(--card)', borderRadius: 22, padding: '20px 20px 16px', boxShadow: '0 16px 40px rgba(0,0,0,0.3)' }}>
        <div style={{ display: 'flex', gap: 5, marginBottom: 12 }}>
          {STEPS.map((_, k) => <div key={k} style={{ width: k === i ? 18 : 6, height: 6, borderRadius: 99, background: k === i ? 'var(--terra)' : 'var(--card-2)', transition: 'width .25s' }} />)}
        </div>
        <h3 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 23, color: 'var(--ink)', fontWeight: 400 }}>{step.title}</h3>
        <p style={{ margin: '6px 0 16px', fontFamily: 'var(--ui)', fontSize: 14.5, lineHeight: 1.45, color: 'var(--muted)' }}>{step.body}</p>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <button onClick={onDone} style={{ background: 'none', border: 'none', color: 'var(--muted)', fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 14, cursor: 'pointer' }}>Skip</button>
          <Btn variant="primary" size="sm" onClick={() => (i < STEPS.length - 1 ? setI(i + 1) : onDone())}>
            {i < STEPS.length - 1 ? 'Next' : 'Start painting'}
          </Btn>
        </div>
      </div>
    </div>
  );
}

function Toast({ toast }) {
  const [show, setShow] = React.useState(false);
  React.useEffect(() => {
    if (!toast) return;
    setShow(true);
    const id = setTimeout(() => setShow(false), toast.duration || 2600);
    return () => clearTimeout(id);
  }, [toast && toast.id]);
  if (!toast) return null;
  return (
    <div style={{
      position: 'absolute', top: 58, left: '50%', transform: `translateX(-50%) translateY(${show ? '0' : '-24px'})`,
      zIndex: 95, opacity: show ? 1 : 0, transition: 'all .35s cubic-bezier(.22,1,.36,1)', pointerEvents: 'none',
      display: 'flex', alignItems: 'center', gap: 11, background: 'var(--ink)', color: 'var(--paper)',
      padding: '11px 18px 11px 13px', borderRadius: 999, boxShadow: '0 10px 30px rgba(0,0,0,0.32)', maxWidth: 320,
    }}>
      <div style={{ width: 34, height: 34, borderRadius: 999, background: toast.color || 'var(--terra)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon name={toast.icon || 'star'} size={18} stroke="#fff" sw={2} />
      </div>
      <div>
        <div style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 14.5 }}>{toast.title}</div>
        {toast.sub && <div style={{ fontFamily: 'var(--ui)', fontSize: 12.5, opacity: 0.7 }}>{toast.sub}</div>}
      </div>
    </div>
  );
}

Object.assign(window, { Minimap, TutorialOverlay, Toast });
