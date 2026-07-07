// app.jsx — Numbra: navigation, samples, packs, progression, paywall, Tweaks.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#E0492F",
  "paper": "#F4EEDF",
  "dark": false,
  "showNumbers": true,
  "defaultMode": "tap",
  "colorblind": false
}/*EDITMODE-END*/;

const SAMPLE_META = [
  { id: 'starry', key: 'starry', title: 'Starry Night', colors: 14, progress: 0 },
  { id: 'wave', key: 'wave', title: 'The Great Wave', colors: 14, progress: 0 },
  { id: 'sunset', key: 'sunset', title: 'Sunset Coast', colors: 14, progress: 0 },
  { id: 'lake', key: 'lake', title: 'Mountain Lake', colors: 14, progress: 1 },
  { id: 'bloom', key: 'bloom', title: 'In Bloom', colors: 14, progress: 0 },
  { id: 'balloon', key: 'balloon', title: 'Sky Drifter', colors: 14, progress: 0 },
];

const PACK_META = [
  { id: 'masters', title: 'The Masters', sceneIds: ['starry', 'wave'], plus: false },
  { id: 'coast', title: 'Coastlines', sceneIds: ['sunset', 'lake'], plus: false },
  { id: 'florals', title: 'Florals', sceneIds: ['bloom', 'sunset'], plus: false },
  { id: 'skies', title: 'Big Skies', sceneIds: ['balloon', 'starry'], plus: true, count: 12 },
  { id: 'nights', title: 'City Nights', sceneIds: ['starry', 'balloon'], plus: true, count: 10 },
];

function renderFinal(data, up = 6) {
  const cv = document.createElement('canvas');
  cv.width = data.w * up; cv.height = data.h * up;
  const c = cv.getContext('2d');
  for (let r = 0; r < data.regionCount; r++) {
    const col = data.palette[data.regionColor[r]];
    c.fillStyle = col.hex;
    for (const p of data.regionPixels[r]) {
      const x = (p % data.w) * up, y = ((p / data.w) | 0) * up;
      c.fillRect(x, y, up, up);
    }
  }
  return cv.toDataURL();
}
function toThumb(src) {
  if (!src) return null;
  if (src.toDataURL) return src.toDataURL();
  const cv = document.createElement('canvas');
  const w = src.naturalWidth || src.width, h = src.naturalHeight || src.height;
  cv.width = w; cv.height = h; cv.getContext('2d').drawImage(src, 0, 0);
  return cv.toDataURL();
}
function fmtTime(ms) {
  const s = Math.round(ms / 1000); const m = Math.floor(s / 60);
  return `${m}:${String(s % 60).padStart(2, '0')}`;
}

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const [screen, setScreen] = React.useState('gallery');
  const [projects, setProjects] = React.useState([]);
  const [picked, setPicked] = React.useState(null);
  const [data, setData] = React.useState(null);
  const [initialFilled, setInitialFilled] = React.useState(null);
  const [sourceThumb, setSourceThumb] = React.useState(null);
  const [activeId, setActiveId] = React.useState(null);
  const [isPlus, setIsPlus] = React.useState(false);
  const [paywall, setPaywall] = React.useState(null);   // pending cfg | 'generic'
  const [complete, setComplete] = React.useState(null);
  const [progress, setProgress] = React.useState(() => Progress.touchOpen());
  const [overlay, setOverlay] = React.useState(null);    // {kind:'timelapse'|'share', ...}
  const [achOpen, setAchOpen] = React.useState(false);
  const [packSheet, setPackSheet] = React.useState(null);
  const [toast, setToast] = React.useState(null);
  const [tutSeen, setTutSeen] = React.useState(() => { try { return localStorage.getItem('numbra_tut') === '1'; } catch (e) { return false; } });
  const [onboarded, setOnboarded] = React.useState(() => { try { return localStorage.getItem('numbra_onboarded') === '1'; } catch (e) { return false; } });
  const startRef = React.useRef(0);
  const metaRef = React.useRef({});

  React.useEffect(() => {
    const ps = SAMPLE_META.map((m) => {
      const cv = PBNEngine.makeSample(m.key, 520);
      return { ...m, src: cv, thumb: cv, session: null };
    });
    setProjects(ps);
  }, []);

  const sampleById = (id) => projects.find((p) => p.id === id);
  const daily = projects.length ? projects[Progress.dailyIndex(SAMPLE_META.length)] : null;

  const packs = React.useMemo(() => {
    if (!projects.length) return [];
    return PACK_META.map((pk) => ({
      ...pk,
      count: pk.count || pk.sceneIds.length,
      covers: pk.sceneIds.slice(0, 2).map((id) => { const s = sampleById(id); return s ? toThumb(s.thumb) : null; }).filter(Boolean),
    }));
  }, [projects]);

  const settings = {
    paper: t.paper,
    canvasBg: t.dark ? '#16130f' : '#ece3d3',
    dark: t.dark,
    showNumbers: t.showNumbers,
    defaultMode: t.defaultMode,
    colorblind: t.colorblind,
  };

  // ---- navigation ----
  const goNew = () => { setPicked(null); setScreen('upload'); };
  const pickImage = (chosen) => { setPicked(chosen); setScreen('difficulty'); };

  const startPaint = (d, filled, srcThumb) => {
    setData(d); setInitialFilled(filled); setSourceThumb(srcThumb);
    setScreen('paint');
  };

  const runEngine = (cfg) => {
    Progress.play() && setProgress(Progress.load());
    const src = picked.src;
    metaRef.current = { isCustom: !!picked.custom, isHard: cfg.id === 'hard', isDaily: !!picked.isDaily };
    setScreen('processing');
    setTimeout(() => {
      const d = PBNEngine.generate(src, { colors: cfg.colors, detail: cfg.detail });
      startRef.current = Date.now();
      const id = picked.id || 'custom-' + Date.now();
      setActiveId(id);
      if (picked.custom) {
        setProjects((prev) => [{ id, title: picked.title, src, thumb: src, colors: cfg.colors, progress: 0, session: null }, ...prev]);
      }
      startPaint(d, null, toThumb(src));
    }, 720);
  };

  const openProject = (p) => {
    setActiveId(p.id);
    metaRef.current = { isCustom: String(p.id).startsWith('custom'), isHard: false, isDaily: false };
    if (p.session) {
      Progress.play() && setProgress(Progress.load());
      startRef.current = Date.now() - (p.session.elapsed || 0);
      metaRef.current.isHard = p.session.isHard || false;
      startPaint(p.session.data, p.session.filled, toThumb(p.src));
    } else if (p.progress >= 1) {
      setComplete({ img: toThumb(p.thumb), time: '—', pieces: '✓', data: p.session && p.session.data, order: p.session && p.session.order, before: toThumb(p.src) });
      setScreen('complete');
    } else {
      setPicked({ src: p.src, title: p.title, custom: false, id: p.id });
      setScreen('difficulty');
    }
  };

  const startDaily = () => {
    if (!daily) return;
    setPicked({ src: daily.src, title: daily.title, custom: false, id: daily.id, isDaily: true });
    setScreen('difficulty');
  };

  const openPack = (pack) => {
    if (pack.plus && !isPlus) { setPaywall('generic'); return; }
    setPackSheet(pack);
  };

  const saveSession = (st) => {
    if (!st || !data) return;
    const elapsed = Date.now() - startRef.current;
    setProjects((prev) => prev.map((p) => p.id === activeId
      ? { ...p, progress: st.done / st.total, session: { data, filled: st.filled, order: st.order, elapsed, isHard: metaRef.current.isHard } }
      : p));
  };
  const exitPaint = (st) => { saveSession(st); setScreen('gallery'); };

  const finishPaint = (st) => {
    const elapsed = Date.now() - startRef.current;
    const mistakes = (st && st.mistakes) || 0;
    const order = st && st.order;
    setProjects((prev) => prev.map((p) => p.id === activeId ? { ...p, progress: 1, session: { data, filled: st ? st.filled : null, order, elapsed, isHard: metaRef.current.isHard } } : p));
    const res = Progress.recordCompletion({ pieces: data.regionCount, mistakes, ...metaRef.current });
    setProgress(res.progress);
    if (res.newly.length) {
      setToast({ id: Date.now(), icon: res.newly[0].icon, color: 'var(--sage)', title: res.newly[0].title, sub: 'Achievement unlocked · +' + res.xpGain + ' XP' });
    } else {
      setToast({ id: Date.now(), icon: 'star', title: '+' + res.xpGain + ' XP', sub: res.leveledUp ? 'Level ' + res.level + ' reached!' : (mistakes === 0 ? 'Flawless run!' : 'Nicely done') });
    }
    setComplete({ img: renderFinal(data), before: toThumb((sampleById(activeId) || {}).src) || sourceThumb, time: fmtTime(elapsed), pieces: String(data.regionCount), xp: '+' + res.xpGain, data, order });
    setScreen('complete');
  };

  // ---- view ----
  const projTitle = (projects.find((p) => p.id === activeId) || {}).title || 'Your painting';
  let view;
  if (screen === 'gallery') view = (
    <Gallery projects={projects} progress={progress} daily={daily} dailyDone={Progress.dailyDone()}
      streak={progress.streak} packs={packs}
      onNew={goNew} onOpen={openProject} onDaily={startDaily} onOpenPack={openPack} onAchievements={() => setAchOpen(true)} />
  );
  else if (screen === 'upload') view = <UploadScreen samples={projects.filter((p) => SAMPLE_META.some((m) => m.id === p.id))} onBack={() => setScreen('gallery')} onPick={pickImage} isPlus={isPlus} onPaywall={() => setPaywall('generic')} />;
  else if (screen === 'difficulty') view = (
    <DifficultyScreen image={picked} isPlus={isPlus} requiresPlus={picked && picked.custom}
      onBack={() => setScreen(picked && picked.custom ? 'upload' : 'gallery')} onCreate={runEngine} onPaywall={(cfg) => setPaywall(cfg)} />
  );
  else if (screen === 'processing') view = <ProcessingScreen image={picked} label={picked && picked.custom ? 'Transforming' : 'Building canvas'} />;
  else if (screen === 'paint' && data) view = (
    <PaintScreen data={data} settings={settings} initialFilled={initialFilled} sourceThumb={sourceThumb}
      showTutorial={!tutSeen} onTutorialDone={() => { setTutSeen(true); try { localStorage.setItem('numbra_tut', '1'); } catch (e) {} }}
      onExit={exitPaint} onComplete={finishPaint} />
  );
  else if (screen === 'complete' && complete) view = (
    <CompleteScreen image={complete.img} title={projTitle} time={complete.time} pieces={complete.pieces} xp={complete.xp}
      onHome={() => setScreen('gallery')}
      onReplay={() => { if (complete.data) setOverlay({ kind: 'timelapse', data: complete.data, order: complete.order }); }}
      onShare={() => setOverlay({ kind: 'share', before: complete.before, after: complete.img })} />
  );

  const fullBleed = screen === 'paint';

  if (!onboarded) {
    return (
      <div style={{ width: '100%', minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px 0', boxSizing: 'border-box' }}>
        <div style={{ '--terra': t.accent }}>
          <IOSDevice>
            <Onboarding onDone={() => { setOnboarded(true); try { localStorage.setItem('numbra_onboarded', '1'); } catch (e) {} }} />
          </IOSDevice>
        </div>
      </div>
    );
  }

  return (
    <div style={{ width: '100%', minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px 0', boxSizing: 'border-box' }}>
      <div style={{ '--terra': t.accent }}>
        <IOSDevice dark={t.dark && fullBleed}>
          <div style={{ position: 'absolute', inset: 0, background: fullBleed ? settings.canvasBg : 'var(--paper)', overflowY: fullBleed ? 'hidden' : 'auto', overflowX: 'hidden' }}>
            {view}
          </div>

          <Toast toast={toast} />

          {/* timelapse / share overlays */}
          {overlay && overlay.kind === 'timelapse' && (
            <TimelapsePlayer data={overlay.data} order={overlay.order} paper={settings.paper} onClose={() => setOverlay(null)} />
          )}
          {overlay && overlay.kind === 'share' && (
            <ShareCard before={overlay.before} after={overlay.after} title={projTitle} time={complete && complete.time} pieces={complete && complete.pieces}
              isPlus={isPlus} onPaywall={() => setPaywall('generic')} onClose={() => setOverlay(null)} />
          )}

          {/* achievements sheet */}
          <Sheet open={achOpen} onClose={() => setAchOpen(false)}>
            <AchievementsSheet progress={progress} onClose={() => setAchOpen(false)} />
          </Sheet>

          {/* pack sheet */}
          <Sheet open={!!packSheet} onClose={() => setPackSheet(null)}>
            {packSheet && (
              <div style={{ padding: '2px 4px 0' }}>
                <h2 style={{ margin: '0 4px 4px', fontFamily: 'var(--display)', fontSize: 26, color: 'var(--ink)', fontWeight: 400 }}>{packSheet.title}</h2>
                <p style={{ margin: '0 4px 14px', fontFamily: 'var(--ui)', fontSize: 13.5, color: 'var(--muted)' }}>Pick a scene to begin.</p>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  {packSheet.sceneIds.map((id, k) => {
                    const s = sampleById(id); if (!s) return null;
                    return (
                      <button key={k} onClick={() => { setPackSheet(null); setPicked({ src: s.src, title: s.title, custom: false, id: s.id }); setScreen('difficulty'); }}
                        style={{ border: 'none', background: 'none', padding: 0, cursor: 'pointer', textAlign: 'left' }}>
                        <div style={{ aspectRatio: '1', borderRadius: 18, overflow: 'hidden', boxShadow: '0 6px 16px rgba(60,40,25,0.14)' }}>
                          <img src={toThumb(s.thumb)} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }} />
                        </div>
                        <div style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 13.5, color: 'var(--ink)', padding: '7px 2px 0' }}>{s.title}</div>
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
          </Sheet>

          {/* paywall sheet */}
          <Sheet open={!!paywall} onClose={() => setPaywall(null)}>
            <div style={{ textAlign: 'center', padding: '4px 6px 0' }}>
              <div style={{ width: 60, height: 60, borderRadius: 20, background: 'var(--terra)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 14px', boxShadow: '0 10px 24px rgba(224,73,47,0.36)' }}>
                <Icon name="sparkle" size={30} stroke="#fff" fill="#fff" sw={1.4} />
              </div>
              <h2 style={{ margin: 0, fontFamily: 'var(--display)', fontSize: 28, color: 'var(--ink)', fontWeight: 400 }}>Numbra Plus</h2>
              <p style={{ margin: '6px 24px 16px', fontFamily: 'var(--ui)', fontSize: 14.5, color: 'var(--muted)', lineHeight: 1.45 }}>Transform any photo, unlock Hard mode &amp; premium packs, save in HD, and paint without limits.</p>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 9, textAlign: 'left', margin: '0 6px 18px' }}>
                {['Turn your own photos into canvases', 'Hard mode + premium themed packs', 'HD exports · timelapse · no ads'].map((f) => (
                  <div key={f} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div style={{ width: 22, height: 22, borderRadius: 99, background: 'var(--sage)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                      <Icon name="check" size={13} stroke="#fff" sw={3} />
                    </div>
                    <span style={{ fontFamily: 'var(--ui)', fontSize: 14.5, color: 'var(--ink)', fontWeight: 600 }}>{f}</span>
                  </div>
                ))}
              </div>
              <Btn variant="primary" size="lg" style={{ width: '100%' }} onClick={() => {
                setIsPlus(true); const cfg = paywall; setPaywall(null);
                if (cfg && cfg !== 'generic') setTimeout(() => runEngine(cfg), 250);
              }}>Start free trial · then $4.99/mo</Btn>
              <button onClick={() => setPaywall(null)} style={{ marginTop: 12, background: 'none', border: 'none', color: 'var(--muted)', fontFamily: 'var(--ui)', fontSize: 14, fontWeight: 600, cursor: 'pointer' }}>Maybe later</button>
            </div>
          </Sheet>
        </IOSDevice>
      </div>

      {/* Tweaks */}
      <TweaksPanel>
        <TweakSection label="Palette" />
        <TweakColor label="Accent" value={t.accent} options={['#E0492F', '#2746C9', '#1E8A78', '#E0A52E', '#6E3F86']} onChange={(v) => setTweak('accent', v)} />
        <TweakColor label="Canvas paper" value={t.paper} options={['#F4EEDF', '#FBFAF4', '#EFE7D6', '#ECE9E2']} onChange={(v) => setTweak('paper', v)} />
        <TweakSection label="Painting" />
        <TweakRadio label="Default mode" value={t.defaultMode} options={['tap', 'paint']} onChange={(v) => setTweak('defaultMode', v)} />
        <TweakToggle label="Show numbers" value={t.showNumbers} onChange={(v) => setTweak('showNumbers', v)} />
        <TweakToggle label="Colorblind mode" value={t.colorblind} onChange={(v) => setTweak('colorblind', v)} />
        <TweakToggle label="Dark chrome" value={t.dark} onChange={(v) => setTweak('dark', v)} />
        <TweakSection label="Demo" />
        <TweakButton label="Replay onboarding" onClick={() => {
          setScreen('gallery'); setOverlay(null); setAchOpen(false); setPackSheet(null); setPaywall(null);
          setOnboarded(false);
          try { localStorage.removeItem('numbra_onboarded'); } catch (e) {}
        }} />
        <TweakButton label="Replay canvas tutorial" secondary onClick={() => {
          setTutSeen(false);
          try { localStorage.removeItem('numbra_tut'); } catch (e) {}
        }} />
        <TweakButton label="Reset progress & streak" secondary onClick={() => {
          try { localStorage.removeItem('numbra_progress_v1'); } catch (e) {}
          setProgress(Progress.touchOpen());
        }} />
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
