// paint-screen.jsx — the full coloring experience around <PaintCanvas>.
// Exports (to window): PaintScreen

function PaintScreen({ data, settings, initialFilled, sourceThumb, showTutorial, onTutorialDone, onExit, onComplete }) {
  const canvasRef = React.useRef(null);
  const modeRef = React.useRef(settings.defaultMode || 'tap');
  const railRef = React.useRef(null);
  const startRem = React.useMemo(() => {
    const rem = Int32Array.from(data.colorCounts);
    let d = 0;
    if (initialFilled) for (let r = 0; r < data.regionCount; r++) if (initialFilled[r]) { rem[data.regionColor[r]]--; d++; }
    return { rem, d };
  }, [data, initialFilled]);
  const [mode, setMode] = React.useState(settings.defaultMode || 'tap');
  const [sel, setSel] = React.useState(firstIncomplete(data, startRem.rem));
  const [remaining, setRemaining] = React.useState(() => Int32Array.from(startRem.rem));
  const [done, setDone] = React.useState(startRem.d);
  const [canUndo, setCanUndo] = React.useState(startRem.d > 0);
  const [shake, setShake] = React.useState(0);
  const [view, setView] = React.useState(null);
  const [tut, setTut] = React.useState(!!showTutorial);
  const [sound, setSound] = React.useState(() => { try { return localStorage.getItem('numbra_sound') === '1'; } catch (e) { return false; } });
  const total = data.regionCount;
  const seamColor = settings.colorblind ? 'rgba(22,16,9,0.6)' : 'rgba(60,45,30,0.28)';
  const showNumbers = settings.colorblind ? true : settings.showNumbers;

  React.useEffect(() => { modeRef.current = mode; }, [mode]);

  // sound lifecycle
  React.useEffect(() => {
    FX.setEnabled(sound);
    if (sound) FX.ambienceOn(); else FX.ambienceOff();
    try { localStorage.setItem('numbra_sound', sound ? '1' : '0'); } catch (e) {}
    return () => FX.ambienceOff();
  }, [sound]);

  const onFillChange = ({ done, remaining, completedColor, canUndo }) => {
    setDone(done); setRemaining(Int32Array.from(remaining)); setCanUndo(canUndo);
    if (completedColor === sel) {
      const next = firstIncomplete(data, remaining);
      if (next >= 0) setSel(next);
    }
  };
  const onWrong = () => { setShake((s) => s + 1); FX.haptic('wrong'); };
  const onFill = (ci) => { if (sound) FX.fill(ci); FX.haptic(); };
  const onMagic = () => { if (sound) FX.magic(); };
  const handleComplete = (st) => { if (sound) FX.complete(); FX.haptic('complete'); onComplete(st); };

  React.useEffect(() => {
    if (!shake) return; const el = document.getElementById('paintShake');
    if (el) { el.style.animation = 'none'; void el.offsetWidth; el.style.animation = 'shakeX .34s'; }
  }, [shake]);

  const pct = Math.round((done / total) * 100);
  const palette = data.palette;
  const ink = settings.dark ? '#fff' : 'var(--ink)';

  return (
    <div id="paintShake" style={{ position: 'absolute', inset: 0, background: settings.canvasBg, display: 'flex', flexDirection: 'column' }}>
      {/* top bar */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, zIndex: 30, padding: '54px 14px 10px', display: 'flex', alignItems: 'center', gap: 9, background: `linear-gradient(to bottom, ${settings.canvasBg}, ${settings.canvasBg}00)` }}>
        <button onClick={() => onExit(canvasRef.current && canvasRef.current.getState())} style={iconBtn(settings)}>
          <Icon name="back" size={22} stroke={ink} sw={2} />
        </button>
        <div style={{ flex: 1 }}>
          <div style={{ height: 8, borderRadius: 99, background: settings.dark ? 'rgba(255,255,255,0.14)' : 'rgba(0,0,0,0.07)', overflow: 'hidden' }}>
            <div style={{ width: `${pct}%`, height: '100%', borderRadius: 99, background: 'var(--terra)', transition: 'width .3s ease' }} />
          </div>
          <div style={{ fontFamily: 'var(--ui)', fontSize: 11.5, fontWeight: 700, color: settings.dark ? 'rgba(255,255,255,0.65)' : 'var(--muted)', marginTop: 4 }}>{pct}% · {done}/{total} pieces</div>
        </div>
        <button onClick={() => canvasRef.current && canvasRef.current.undo()} disabled={!canUndo} style={{ ...iconBtn(settings), opacity: canUndo ? 1 : 0.4 }} title="Undo">
          <Icon name="undo" size={21} stroke={ink} sw={2} />
        </button>
        <button onClick={() => canvasRef.current && canvasRef.current.hint()} style={iconBtn(settings)} title="Find next piece">
          <Icon name="target" size={21} stroke={ink} sw={1.9} />
        </button>
      </div>

      {/* canvas */}
      <PaintCanvas
        ref={canvasRef} data={data} selColor={sel} mode={mode} modeRef={modeRef} initialFilled={initialFilled}
        paper={settings.paper} seamColor={seamColor} showNumbers={showNumbers}
        onFillChange={onFillChange} onWrong={onWrong} onFill={onFill} onMagic={onMagic}
        onView={setView} onComplete={() => handleComplete(canvasRef.current && canvasRef.current.getState())}
      />

      <Minimap view={view} thumb={sourceThumb} show={true} />

      {/* zoom + sound controls */}
      <div style={{ position: 'absolute', right: 12, bottom: 188, zIndex: 28, display: 'flex', flexDirection: 'column', gap: 8 }}>
        <button onClick={() => canvasRef.current.zoomBy(1.5)} style={iconBtn(settings)}><Icon name="plusN" size={20} stroke={ink} sw={2.2} /></button>
        <button onClick={() => canvasRef.current.zoomBy(0.66)} style={iconBtn(settings)}><Icon name="minus" size={20} stroke={ink} sw={2.2} /></button>
        <button onClick={() => canvasRef.current.fitView()} style={iconBtn(settings)}><Icon name="fit" size={19} stroke={ink} sw={1.9} /></button>
        <button onClick={() => setSound((s) => !s)} style={{ ...iconBtn(settings), background: sound ? 'var(--sage)' : iconBtn(settings).background }} title="Ambience & sound">
          <Icon name={sound ? 'sound' : 'mute'} size={19} stroke={sound ? '#fff' : ink} sw={1.9} />
        </button>
      </div>

      {/* bottom dock: mode toggle + palette */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 30, padding: '14px 0 calc(20px + env(safe-area-inset-bottom))', background: `linear-gradient(to top, ${settings.canvasBg} 70%, ${settings.canvasBg}00)` }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px 12px' }}>
          <div style={{ flex: 1 }}>
            <Segmented value={mode} onChange={setMode} options={[
              { value: 'tap', label: 'Tap', icon: 'tap' },
              { value: 'paint', label: 'Paint', icon: 'brush' },
            ]} />
          </div>
          <button onClick={() => canvasRef.current && canvasRef.current.magicFill()} style={{
            width: 48, height: 48, borderRadius: 16, border: 'none', cursor: 'pointer',
            background: 'var(--sage)', display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 6px 16px rgba(30,138,120,0.34)',
          }} title="Magic-fill this color">
            <Icon name="wand" size={23} stroke="#fff" sw={1.9} />
          </button>
        </div>

        <div ref={railRef} style={{ display: 'flex', gap: 12, overflowX: 'auto', overflowY: 'hidden', padding: '16px 16px 8px', scrollbarWidth: 'none' }}>
          {palette.map((c, i) => {
            const rem = remaining[i];
            const active = i === sel;
            const finished = rem === 0;
            return (
              <button key={i} onClick={() => setSel(i)} style={{
                flex: '0 0 auto', width: 58, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
                border: 'none', background: 'none', cursor: 'pointer', padding: 0, opacity: finished ? 0.4 : 1,
                transition: 'opacity .25s, transform .15s', transform: active ? 'translateY(-6px)' : 'none',
              }}>
                <div style={{
                  position: 'relative', width: 52, height: 52, borderRadius: 16, background: c.hex,
                  border: c.light ? '1.5px solid rgba(0,0,0,0.12)' : 'none',
                  boxShadow: active ? `0 0 0 3px ${settings.canvasBg}, 0 0 0 6px var(--terra)` : '0 3px 8px rgba(0,0,0,0.16)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {finished
                    ? <Icon name="check" size={22} stroke={c.light ? '#2b2722' : '#fff'} sw={2.6} />
                    : <span style={{ fontFamily: 'var(--ui)', fontWeight: 800, fontSize: 19, color: c.light ? 'rgba(43,39,34,0.85)' : 'rgba(255,255,255,0.95)' }}>{c.num}</span>}
                </div>
                {!finished && (
                  <span style={{ fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 11.5, color: settings.dark ? 'rgba(255,255,255,0.6)' : 'var(--muted)' }}>{rem}</span>
                )}
              </button>
            );
          })}
        </div>
      </div>

      {tut && <TutorialOverlay onDone={() => { setTut(false); onTutorialDone && onTutorialDone(); }} />}
    </div>
  );
}

function iconBtn(settings) {
  return {
    width: 42, height: 42, borderRadius: 14, border: 'none', cursor: 'pointer', flexShrink: 0,
    background: settings.dark ? 'rgba(255,255,255,0.12)' : 'rgba(255,255,255,0.82)',
    backdropFilter: 'blur(8px)', WebkitBackdropFilter: 'blur(8px)',
    boxShadow: '0 3px 10px rgba(0,0,0,0.12)',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
  };
}

function firstIncomplete(data, remaining) {
  for (let i = 0; i < data.palette.length; i++) if (remaining[i] > 0) return i;
  return 0;
}

window.PaintScreen = PaintScreen;
