// onboarding.jsx — first-launch onboarding with famous-painting motifs.
// Exports (to window): Onboarding

// ── Painting motifs (hand-built SVG homages) ──────────────────
function SwirlMotif() { // after Van Gogh — The Starry Night
  const spiral = (cx, cy, turns, col, sw) => {
    let d = `M ${cx} ${cy}`;
    const steps = turns * 24;
    for (let i = 1; i <= steps; i++) {
      const a = i * 0.26, r = i * 1.05;
      d += ` L ${(cx + Math.cos(a) * r).toFixed(1)} ${(cy + Math.sin(a) * r).toFixed(1)}`;
    }
    return <path d={d} fill="none" stroke={col} strokeWidth={sw} strokeLinecap="round" opacity="0.9" />;
  };
  return (
    <svg viewBox="0 0 240 200" width="100%" height="100%">
      <rect width="240" height="200" fill="#162a63" />
      <rect width="240" height="200" fill="url(#sg)" />
      <defs><linearGradient id="sg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#1b3a8c" stopOpacity="0.5" /><stop offset="1" stopColor="#0c1840" stopOpacity="0.7" /></linearGradient></defs>
      {spiral(150, 70, 4, '#7fa8e8', 4)}
      {spiral(150, 70, 3, '#e7c044', 2.2)}
      {[ [60, 50, 13], [200, 130, 10], [40, 120, 8], [110, 40, 7] ].map(([x, y, r], i) => (
        <g key={i}>
          <circle cx={x} cy={y} r={r} fill="#e7c044" opacity="0.25" />
          <circle cx={x} cy={y} r={r * 0.42} fill="#f4dd86" />
        </g>
      ))}
      {/* cypress */}
      <path d="M30 200 C18 150 30 120 24 96 C40 124 46 158 44 200 Z" fill="#10371f" />
      {/* village rooftops */}
      <g fill="#1d2c4a">
        <rect x="70" y="172" width="120" height="28" />
        {[80, 104, 128, 152, 176].map((x, i) => <path key={i} d={`M${x} 172 l12 -12 l12 12 Z`} />)}
      </g>
      {[100, 140, 168].map((x, i) => <rect key={i} x={x} y={180} width="6" height="9" fill="#e7c044" />)}
    </svg>
  );
}
function WaveMotif() { // after Hokusai — The Great Wave off Kanagawa
  return (
    <svg viewBox="0 0 240 200" width="100%" height="100%">
      <rect width="240" height="200" fill="#ece6d4" />
      <circle cx="170" cy="60" r="22" fill="#f0e3c4" />
      {/* Mt Fuji */}
      <path d="M150 150 L188 96 L226 150 Z" fill="#3a5d77" />
      <path d="M188 96 l-14 20 l9 4 l5 -8 l5 9 l9 -5 Z" fill="#f4f1e6" />
      {/* big wave */}
      <path d="M-5 150 C30 90 70 80 110 110 C150 140 130 70 175 64 C120 60 120 130 78 120 C120 150 60 175 20 150 Z" fill="#173a5e" />
      <path d="M-5 158 C40 120 90 118 120 138 C160 165 200 150 245 158 L245 205 L-5 205 Z" fill="#1f4f78" />
      {/* foam fingers */}
      <g fill="#f4f1e6">
        {[ [40, 96, 7], [62, 86, 6], [88, 92, 7], [108, 104, 5], [150, 70, 6] ].map(([x, y, r], i) => <circle key={i} cx={x} cy={y} r={r} />)}
      </g>
      <path d="M-5 175 C50 160 110 168 160 175 C200 180 230 174 245 176 L245 205 L-5 205 Z" fill="#102a44" />
    </svg>
  );
}
function LeavesMotif() { // after Matisse — cut-outs
  return (
    <svg viewBox="0 0 240 200" width="100%" height="100%">
      <rect width="240" height="200" fill="#1E8A78" />
      <path d="M50 30 C90 20 96 70 70 90 C40 110 20 70 50 30 Z" fill="#E0492F" />
      <path d="M150 24 C200 30 196 96 150 96 C120 96 110 40 150 24 Z" fill="#E0A52E" />
      <path d="M40 130 C80 110 120 140 96 174 C72 200 20 170 40 130 Z" fill="#F2EAD8" />
      <path d="M150 120 C200 116 210 170 170 184 C140 194 120 130 150 120 Z" fill="#2746C9" />
      {/* a starry accent */}
      <g fill="#F2EAD8">
        {[ [120, 60], [200, 150], [30, 90] ].map(([x, y], i) => (
          <path key={i} d={`M${x} ${y - 8} l2.5 5.5 l5.5 .7 l-4 4 l1 5.6 l-5 -2.8 l-5 2.8 l1 -5.6 l-4 -4 l5.5 -.7 Z`} />
        ))}
      </g>
    </svg>
  );
}

function Onboarding({ onDone }) {
  const SLIDES = [
    { motif: <SwirlMotif />, bg: '#162a63', kicker: 'Welcome to Numbra', title: 'Painting,\nby the numbers', body: 'Color the calm — one numbered piece at a time. From the great masters to your own photos.' },
    { motif: <WaveMotif />, bg: '#1f4f78', kicker: 'Any image, transformed', title: 'Every photo\nbecomes a canvas', body: 'Numbra traces any picture into paintable regions and assigns a palette. Choose a difficulty and begin.' },
    { motif: <LeavesMotif />, bg: '#1E8A78', kicker: 'Made for unwinding', title: 'Tap, drag,\nunwind', body: 'Two relaxing ways to color, gentle sound, hints when you’re stuck, and a timelapse of every piece you place.' },
  ];
  const [i, setI] = React.useState(0);
  const last = i === SLIDES.length - 1;
  const s = SLIDES[i];
  return (
    <div style={{ position: 'absolute', inset: 0, zIndex: 120, background: s.bg, transition: 'background .5s ease', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      {/* motif stage */}
      <div style={{ position: 'relative', height: '52%', minHeight: 360 }}>
        <div style={{ position: 'absolute', inset: 0, display: 'flex' }}>
          {SLIDES.map((sl, k) => (
            <div key={k} style={{ position: 'absolute', inset: 0, opacity: k === i ? 1 : 0, transform: `scale(${k === i ? 1 : 1.06})`, transition: 'opacity .5s ease, transform .6s ease' }}>
              {sl.motif}
            </div>
          ))}
        </div>
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: -1, height: 90, background: `linear-gradient(to top, ${s.bg}, ${s.bg}00)`, transition: 'background .5s' }} />
        <button onClick={onDone} style={{ position: 'absolute', top: 56, right: 18, background: 'rgba(255,255,255,0.16)', border: 'none', color: '#fff', fontFamily: 'var(--ui)', fontWeight: 600, fontSize: 13.5, padding: '7px 14px', borderRadius: 999, cursor: 'pointer' }}>Skip</button>
      </div>

      {/* copy */}
      <div style={{ flex: 1, padding: '6px 30px 0', display: 'flex', flexDirection: 'column' }}>
        <div style={{ fontFamily: 'var(--ui)', fontSize: 13, fontWeight: 700, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'rgba(255,255,255,0.65)' }}>{s.kicker}</div>
        <h1 style={{ margin: '10px 0 0', fontFamily: 'var(--display)', fontSize: 44, lineHeight: 1.02, fontWeight: 500, color: '#fff', whiteSpace: 'pre-line', letterSpacing: '-0.01em' }}>{s.title}</h1>
        <p style={{ margin: '16px 0 0', fontFamily: 'var(--ui)', fontSize: 16, lineHeight: 1.5, color: 'rgba(255,255,255,0.82)', maxWidth: 320 }}>{s.body}</p>

        <div style={{ marginTop: 'auto', paddingBottom: 'calc(34px + env(safe-area-inset-bottom))' }}>
          <div style={{ display: 'flex', gap: 7, marginBottom: 22 }}>
            {SLIDES.map((_, k) => <div key={k} style={{ width: k === i ? 26 : 8, height: 8, borderRadius: 99, background: k === i ? '#fff' : 'rgba(255,255,255,0.32)', transition: 'width .3s ease' }} />)}
          </div>
          <button onClick={() => (last ? onDone() : setI(i + 1))} style={{
            width: '100%', border: 'none', cursor: 'pointer', borderRadius: 999, padding: '17px 24px',
            background: '#fff', color: s.bg, fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 17, letterSpacing: '-0.01em',
            transition: 'color .5s ease', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 9,
          }}>
            {last ? 'Start painting' : 'Continue'}
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={s.bg} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"><path d="M5 12h14M13 6l6 6-6 6" /></svg>
          </button>
        </div>
      </div>
    </div>
  );
}

window.Onboarding = Onboarding;
