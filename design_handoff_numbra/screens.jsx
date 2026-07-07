// screens.jsx — Numbra screens: Gallery, Upload/Transform, Difficulty, Processing, Complete.
// Exports (to window): Gallery, UploadScreen, DifficultyScreen, ProcessingScreen, CompleteScreen

// thumbnail tile that renders a source canvas (or a PBN preview) to an <img>
function Thumb({ src, radius = 20, style }) {
  const ref = React.useRef(null);
  React.useEffect(() => {
    if (ref.current && src) ref.current.src = src.toDataURL ? src.toDataURL() : src;
  }, [src]);
  return <img ref={ref} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', borderRadius: radius, display: 'block', ...style }} />;
}

// ─────────────────────────────────────────────────────────────
function Gallery({ projects, progress, daily, dailyDone, streak, packs, onNew, onOpen, onDaily, onOpenPack, onAchievements }) {
  const inProgress = projects.filter((p) => p.progress > 0 && p.progress < 1);
  const featured = inProgress[0] || projects[0];
  return (
    <div style={{ padding: '0 0 40px', minHeight: '100%' }}>
      <div style={{ padding: '70px 22px 8px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: 'var(--ui)', fontSize: 13, fontWeight: 700, letterSpacing: '0.14em', textTransform: 'uppercase', color: 'var(--terra)' }}>Numbra</div>
          <h1 style={{ margin: '2px 0 0', fontFamily: 'var(--display)', fontSize: 38, fontWeight: 400, color: 'var(--ink)', lineHeight: 1, whiteSpace: 'nowrap' }}>Your studio</h1>
        </div>
        <LevelBadge progress={progress} onClick={onAchievements} />
      </div>

      {daily && <DailyBanner sample={daily} done={dailyDone} streak={streak} onStart={onDaily} />}

      {/* Featured continue card */}
      {featured && (
        <div onClick={() => onOpen(featured)} style={{
          margin: '18px 18px 6px', borderRadius: 28, overflow: 'hidden', position: 'relative',
          aspectRatio: '3/2', cursor: 'pointer', boxShadow: '0 14px 34px rgba(60,40,25,0.16)',
        }}>
          <Thumb src={featured.thumb} radius={28} />
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(20,14,8,0.7), rgba(20,14,8,0) 55%)' }} />
          <div style={{ position: 'absolute', left: 18, bottom: 16, right: 18, display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
            <div>
              <div style={{ color: 'rgba(255,255,255,0.8)', fontFamily: 'var(--ui)', fontSize: 12.5, fontWeight: 700, letterSpacing: '0.08em', textTransform: 'uppercase' }}>{featured.progress > 0 ? 'Continue' : 'Featured'}</div>
              <div style={{ color: '#fff', fontFamily: 'var(--display)', fontSize: 27, marginTop: 2, whiteSpace: 'nowrap' }}>{featured.title}</div>
            </div>
            <Ring value={featured.progress} size={50} sw={5} track="rgba(255,255,255,0.28)" color="#fff">
              <span style={{ color: '#fff', fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 12 }}>{Math.round(featured.progress * 100)}%</span>
            </Ring>
          </div>
        </div>
      )}

      {packs && packs.length > 0 && <PacksRail packs={packs} onOpen={onOpenPack} />}

      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 22px 12px' }}>
        <h2 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 22, color: 'var(--ink)', fontWeight: 400 }}>Library</h2>
        <span style={{ fontFamily: 'var(--ui)', fontSize: 13.5, color: 'var(--muted)', fontWeight: 600 }}>{projects.length} canvases</span>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, padding: '0 18px' }}>
        {/* New painting tile */}
        <button onClick={onNew} style={{
          aspectRatio: '1', borderRadius: 24, border: '2px dashed rgba(224,73,47,0.4)',
          background: 'rgba(224,73,47,0.06)', cursor: 'pointer', display: 'flex',
          flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 10, color: 'var(--terra)',
        }}>
          <div style={{ width: 52, height: 52, borderRadius: 16, background: 'var(--terra)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 8px 18px rgba(224,73,47,0.34)' }}>
            <Icon name="plus" size={26} stroke="#fff" sw={2.4} />
          </div>
          <span style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 14.5 }}>New painting</span>
        </button>

        {projects.map((p) => (
          <div key={p.id} onClick={() => onOpen(p)} style={{ cursor: 'pointer' }}>
            <div style={{ position: 'relative', aspectRatio: '1', borderRadius: 24, overflow: 'hidden', boxShadow: '0 8px 20px rgba(60,40,25,0.1)' }}>
              <Thumb src={p.thumb} radius={24} />
              {p.progress >= 1 && (
                <div style={{ position: 'absolute', top: 9, right: 9, width: 28, height: 28, borderRadius: 99, background: 'var(--sage)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 3px 8px rgba(0,0,0,0.2)' }}>
                  <Icon name="check" size={16} stroke="#fff" sw={2.6} />
                </div>
              )}
              {p.progress > 0 && p.progress < 1 && (
                <div style={{ position: 'absolute', left: 8, right: 8, bottom: 8, height: 5, borderRadius: 99, background: 'rgba(255,255,255,0.45)', overflow: 'hidden' }}>
                  <div style={{ width: `${p.progress * 100}%`, height: '100%', background: '#fff', borderRadius: 99 }} />
                </div>
              )}
            </div>
            <div style={{ padding: '8px 4px 0' }}>
              <div style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 14.5, color: 'var(--ink)' }}>{p.title}</div>
              <div style={{ fontFamily: 'var(--ui)', fontSize: 12.5, color: 'var(--muted)', marginTop: 1 }}>
                {p.progress >= 1 ? 'Completed' : p.progress > 0 ? `${Math.round(p.progress * 100)}% done` : `${p.colors} colors`}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
function UploadScreen({ samples, onBack, onPick, isPlus, onPaywall }) {
  const fileRef = React.useRef(null);
  const [chosen, setChosen] = React.useState(null); // {src, title, custom}
  const onFile = (e) => {
    const f = e.target.files[0]; if (!f) return;
    const img = new Image();
    img.onload = () => setChosen({ src: img, title: 'My photo', custom: true });
    img.src = URL.createObjectURL(f);
  };
  const wantCustom = () => { if (isPlus) fileRef.current.click(); else onPaywall && onPaywall(); };
  const Lock = () => (
    <div style={{ position: 'absolute', top: 12, right: 12, display: 'flex', alignItems: 'center', gap: 3, background: 'var(--terra)', borderRadius: 99, padding: '3px 8px 3px 6px' }}>
      <Icon name="lock" size={11} stroke="#fff" sw={2.2} /><span style={{ color: '#fff', fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 9.5 }}>PLUS</span>
    </div>
  );
  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '64px 18px 6px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: 99, border: 'none', background: 'var(--card-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <Icon name="back" size={22} stroke="var(--ink)" sw={2} />
        </button>
        <h1 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 28, color: 'var(--ink)', fontWeight: 400, whiteSpace: 'nowrap' }}>New painting</h1>
      </div>

      <div style={{ padding: '14px 18px 0' }}>
        <div style={{ display: 'flex', gap: 12 }}>
          <button onClick={wantCustom} style={{
            flex: 1, borderRadius: 22, border: 'none', cursor: 'pointer', padding: '18px 14px', position: 'relative',
            background: 'var(--ink)', color: 'var(--paper)', display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-start',
          }}>
            {!isPlus && <Lock />}
            <Icon name="image" size={24} stroke="var(--paper)" sw={1.9} />
            <div style={{ textAlign: 'left' }}>
              <div style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 15, whiteSpace: 'nowrap' }}>Upload photo</div>
              <div style={{ fontFamily: 'var(--ui)', fontSize: 12, opacity: 0.6 }}>From your library</div>
            </div>
          </button>
          <button onClick={wantCustom} style={{
            flex: 1, borderRadius: 22, border: '1.5px solid var(--line)', cursor: 'pointer', padding: '18px 14px', position: 'relative',
            background: 'var(--card)', color: 'var(--ink)', display: 'flex', flexDirection: 'column', gap: 10, alignItems: 'flex-start',
          }}>
            {!isPlus && <Lock />}
            <Icon name="camera" size={24} stroke="var(--ink)" sw={1.9} />
            <div style={{ textAlign: 'left' }}>
              <div style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 15, whiteSpace: 'nowrap' }}>Take photo</div>
              <div style={{ fontFamily: 'var(--ui)', fontSize: 12, color: 'var(--muted)' }}>Use camera</div>
            </div>
          </button>
        </div>
        <input ref={fileRef} type="file" accept="image/*" onChange={onFile} style={{ display: 'none' }} />
        {!isPlus && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 12, padding: '10px 14px', borderRadius: 14, background: 'rgba(224,73,47,0.08)' }}>
            <Icon name="sparkle" size={16} stroke="var(--terra)" sw={1.6} fill="var(--terra)" />
            <span style={{ fontFamily: 'var(--ui)', fontSize: 12.5, color: 'var(--ink)', fontWeight: 600 }}>Turning your own photos into canvases is a Numbra Plus feature.</span>
          </div>
        )}
      </div>

      <div style={{ padding: '24px 22px 8px' }}>
        <h2 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 20, color: 'var(--ink)', fontWeight: 400 }}>Free starter scenes</h2>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, padding: '0 18px 14px' }}>
        {samples.map((s) => {
          const active = chosen && chosen.id === s.id;
          return (
            <button key={s.id} onClick={() => setChosen({ ...s, custom: false })} style={{
              border: active ? '2.5px solid var(--terra)' : '2.5px solid transparent', padding: 0,
              borderRadius: 22, overflow: 'hidden', cursor: 'pointer', background: 'none', position: 'relative',
            }}>
              <div style={{ aspectRatio: '1' }}><Thumb src={s.src} radius={18} /></div>
              <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '20px 12px 9px', background: 'linear-gradient(to top, rgba(15,10,6,0.7), transparent)', textAlign: 'left' }}>
                <span style={{ color: '#fff', fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 14 }}>{s.title}</span>
              </div>
            </button>
          );
        })}
      </div>

      <div style={{ marginTop: 'auto', position: 'sticky', bottom: 0, padding: '14px 18px calc(20px + env(safe-area-inset-bottom))', background: 'linear-gradient(to top, var(--paper) 62%, transparent)' }}>
        <Btn variant="primary" size="lg" icon="sparkle" disabled={!chosen}
          onClick={() => onPick(chosen)} style={{ width: '100%' }}>
          {chosen ? `Use “${chosen.title}”` : 'Choose an image'}
        </Btn>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
const DIFFS = [
  { id: 'easy', label: 'Easy', colors: 10, detail: 66, sub: 'Big, relaxing areas', pieces: '~50 pieces' },
  { id: 'medium', label: 'Medium', colors: 16, detail: 96, sub: 'A balanced session', pieces: '~80 pieces' },
  { id: 'hard', label: 'Hard', colors: 24, detail: 132, sub: 'Fine, intricate detail', pieces: '~130 pieces' },
];

function DifficultyScreen({ image, onBack, onCreate, requiresPlus, onPaywall, isPlus }) {
  const [diff, setDiff] = React.useState('medium');
  const needsPlus = (requiresPlus || diff === 'hard') && !isPlus;
  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column' }}>
      <div style={{ padding: '64px 18px 6px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <button onClick={onBack} style={{ width: 40, height: 40, borderRadius: 99, border: 'none', background: 'var(--card-2)', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
          <Icon name="back" size={22} stroke="var(--ink)" sw={2} />
        </button>
        <h1 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 28, color: 'var(--ink)', fontWeight: 400, whiteSpace: 'nowrap' }}>Difficulty</h1>
      </div>

      <div style={{ padding: '14px 22px 0' }}>
        <div style={{ borderRadius: 26, overflow: 'hidden', aspectRatio: '16/10', boxShadow: '0 14px 34px rgba(60,40,25,0.16)' }}>
          <Thumb src={image.src} radius={26} />
        </div>
      </div>

      <div style={{ padding: '22px 18px 0', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {DIFFS.map((d) => {
          const active = d.id === diff;
          return (
            <button key={d.id} onClick={() => setDiff(d.id)} style={{
              display: 'flex', alignItems: 'center', gap: 16, textAlign: 'left', cursor: 'pointer',
              borderRadius: 22, padding: '16px 18px', background: 'var(--card)', position: 'relative',
              border: active ? '2.5px solid var(--terra)' : '2.5px solid var(--line)',
              boxShadow: active ? '0 8px 22px rgba(224,73,47,0.16)' : 'none', transition: 'all .18s ease',
            }}>
              <div style={{ display: 'flex', gap: 4 }}>
                {[0, 1, 2].map((i) => (
                  <div key={i} style={{ width: 6, height: 22 + i * 6, borderRadius: 99, alignSelf: 'flex-end', background: (d.id === 'easy' && i < 1) || (d.id === 'medium' && i < 2) || d.id === 'hard' ? 'var(--terra)' : 'var(--card-2)' }} />
                ))}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 17, color: 'var(--ink)' }}>{d.label}</div>
                <div style={{ fontFamily: 'var(--ui)', fontSize: 13, color: 'var(--muted)', marginTop: 1 }}>{d.sub}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 13.5, color: 'var(--ink)' }}>{d.colors} colors</div>
                <div style={{ fontFamily: 'var(--ui)', fontSize: 12, color: 'var(--muted)' }}>{d.pieces}</div>
              </div>
              {d.id === 'hard' && !isPlus && (
                <div style={{ position: 'absolute', top: 10, right: 12, display: 'flex', alignItems: 'center', gap: 3, background: 'var(--terra)', borderRadius: 99, padding: '3px 8px 3px 6px' }}>
                  <Icon name="lock" size={11} stroke="#fff" sw={2.2} /><span style={{ color: '#fff', fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 10 }}>PLUS</span>
                </div>
              )}
            </button>
          );
        })}
      </div>

      <div style={{ marginTop: 'auto', padding: '18px 18px calc(20px + env(safe-area-inset-bottom))' }}>
        <Btn variant="primary" size="lg" icon="brush" onClick={() => {
          const cfg = DIFFS.find((d) => d.id === diff);
          if (needsPlus) onPaywall(cfg); else onCreate(cfg);
        }} style={{ width: '100%' }}>
          {needsPlus ? 'Unlock & create canvas' : 'Create canvas'}
        </Btn>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
function ProcessingScreen({ image, label }) {
  const [step, setStep] = React.useState(0);
  const steps = ['Reading your image', 'Choosing a palette', 'Tracing regions', 'Numbering pieces'];
  React.useEffect(() => {
    const iv = setInterval(() => setStep((s) => Math.min(steps.length - 1, s + 1)), 520);
    return () => clearInterval(iv);
  }, []);
  return (
    <div style={{ minHeight: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 30 }}>
      <div style={{ position: 'relative', width: 220, height: 220, borderRadius: 30, overflow: 'hidden', boxShadow: '0 18px 44px rgba(60,40,25,0.22)' }}>
        <Thumb src={image.src} radius={30} />
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(120deg, transparent 30%, rgba(255,255,255,0.55) 50%, transparent 70%)', backgroundSize: '220% 100%', animation: 'sheen 1.3s linear infinite' }} />
      </div>
      <div style={{ marginTop: 34, fontFamily: 'var(--display)', fontSize: 24, color: 'var(--ink)' }}>{label || 'Transforming'}</div>
      <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 9, width: 230 }}>
        {steps.map((s, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, opacity: i <= step ? 1 : 0.34, transition: 'opacity .3s' }}>
            <div style={{ width: 22, height: 22, borderRadius: 99, background: i < step ? 'var(--sage)' : i === step ? 'var(--terra)' : 'var(--card-2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {i < step ? <Icon name="check" size={14} stroke="#fff" sw={3} /> : <div style={{ width: 7, height: 7, borderRadius: 99, background: i === step ? '#fff' : 'var(--muted)' }} />}
            </div>
            <span style={{ fontFamily: 'var(--ui)', fontSize: 14.5, fontWeight: 600, color: 'var(--ink)' }}>{s}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
function CompleteScreen({ image, title, time, pieces, xp, onHome, onReplay, onShare }) {
  return (
    <div style={{ position: 'relative', minHeight: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '80px 24px 30px', textAlign: 'center', overflow: 'hidden' }}>
      <Confetti run={true} />
      <div style={{ fontFamily: 'var(--ui)', fontSize: 13, fontWeight: 800, letterSpacing: '0.16em', textTransform: 'uppercase', color: 'var(--terra)' }}>Masterpiece complete</div>
      <h1 style={{ margin: '6px 0 0', fontFamily: 'var(--display)', fontSize: 34, color: 'var(--ink)', fontWeight: 400, whiteSpace: 'nowrap' }}>{title}</h1>
      <div style={{ position: 'relative', width: '78%', marginTop: 26, borderRadius: 24, overflow: 'hidden', boxShadow: '0 22px 50px rgba(60,40,25,0.28)', transform: 'rotate(-1.5deg)', animation: 'popIn .7s cubic-bezier(.22,1.4,.4,1) both', zIndex: 1 }}>
        <div style={{ aspectRatio: '1' }}><Thumb src={image} radius={24} /></div>
        <div style={{ position: 'absolute', inset: 0, borderRadius: 24, boxShadow: 'inset 0 0 0 8px rgba(255,255,255,0.9)' }} />
      </div>
      <div style={{ display: 'flex', gap: 26, marginTop: 28 }}>
        <Stat icon="clock" value={time} label="Time" />
        <div style={{ width: 1, background: 'var(--line)' }} />
        <Stat icon="grid" value={pieces} label="Pieces" />
        <div style={{ width: 1, background: 'var(--line)' }} />
        <Stat icon="star" value={xp || '+50'} label="XP" />
      </div>
      <div style={{ marginTop: 'auto', width: '100%', display: 'flex', flexDirection: 'column', gap: 10, paddingTop: 30, position: 'relative', zIndex: 1 }}>
        <Btn variant="primary" size="lg" icon="play" onClick={onReplay} style={{ width: '100%' }}>Watch timelapse</Btn>
        <div style={{ display: 'flex', gap: 10 }}>
          <Btn variant="soft" size="md" icon="share" onClick={onShare} style={{ flex: 1 }}>Share</Btn>
          <Btn variant="soft" size="md" icon="grid" onClick={onHome} style={{ flex: 1 }}>Studio</Btn>
        </div>
      </div>
    </div>
  );
}
function Stat({ icon, value, label }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
      <Icon name={icon} size={20} stroke="var(--muted)" sw={1.8} />
      <div style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 18, color: 'var(--ink)' }}>{value}</div>
      <div style={{ fontFamily: 'var(--ui)', fontSize: 11.5, color: 'var(--muted)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>{label}</div>
    </div>
  );
}

Object.assign(window, { Gallery, UploadScreen, DifficultyScreen, ProcessingScreen, CompleteScreen, DIFFS });
