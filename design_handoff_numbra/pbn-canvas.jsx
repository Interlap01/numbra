// pbn-canvas.jsx
// The interactive paint-by-numbers canvas: zoom/pan (pinch + drag + double-tap),
// tap-to-fill and drag-to-paint modes, mistake-proof filling, selected-color
// highlight, numbers, plus imperative hint() / magicFill() helpers.
//
// Exports (to window): PaintCanvas (React.forwardRef component)
//
// Props:
//   data            PBN data from PBNEngine.generate
//   selColor        selected palette color index (0-based) or -1
//   mode            'tap' | 'paint'
//   paper           background color of unpainted regions
//   seamColor       boundary line color
//   showNumbers     bool
//   onFillChange({done,total,remaining,completedColor})
//   onComplete()
//   onWrong()       fired on a wrong tap (mistake-proof feedback)
// Ref methods: hint(), magicFill(), zoomBy(f), reset()

const PaintCanvas = React.forwardRef(function PaintCanvas(props, ref) {
  const wrapRef = React.useRef(null);
  const canvasRef = React.useRef(null);
  const S = React.useRef({}).current; // mutable engine state, no re-render

  // ---------- build offscreen buffers when data changes ----------
  React.useEffect(() => {
    const data = props.data;
    if (!data) return;
    const { w, h } = data;
    S.data = data;
    S.filled = new Uint8Array(data.regionCount);
    S.filledPerColor = new Int32Array(data.palette.length);
    S.order = [];      // region ids in fill order (for undo + timelapse)
    S.mistakes = 0;
    S.rings = []; // satisfaction pulses {x,y,t}
    S.wrong = null; // {x,y,t}

    // fill buffer (paper-coloured to start)
    S.fillCv = document.createElement('canvas'); S.fillCv.width = w; S.fillCv.height = h;
    S.fillCtx = S.fillCv.getContext('2d');
    S.fillData = S.fillCtx.createImageData(w, h);
    paintPaper();
    S.fillCtx.putImageData(S.fillData, 0, 0);

    // highlight buffer
    S.hlCv = document.createElement('canvas'); S.hlCv.width = w; S.hlCv.height = h;
    S.hlCtx = S.hlCv.getContext('2d');
    S.hlData = S.hlCtx.createImageData(w, h);

    // boundary path (image coords)
    const path = new Path2D();
    const seg = data.segments;
    for (let i = 0; i < seg.length; i += 4) {
      path.moveTo(seg[i], seg[i + 1]); path.lineTo(seg[i + 2], seg[i + 3]);
    }
    S.boundary = path;

    // restore a prior session if provided
    if (props.initialFilled && props.initialFilled.length === data.regionCount) {
      S.filled.set(props.initialFilled);
      S.filledPerColor.fill(0);
      S.order = [];
      for (let r = 0; r < data.regionCount; r++) if (S.filled[r]) { S.filledPerColor[data.regionColor[r]]++; S.order.push(r); }
      repaintAllFilled();
    }

    layout(true);
    updateHighlight();
    requestDraw();
    reportFill();
    // eslint-disable-next-line
  }, [props.data]);

  // react to selected color / numbers / paper changes
  React.useEffect(() => { if (S.data) { paintPaper(); repaintAllFilled(); updateHighlight(); requestDraw(); } /* eslint-disable-next-line */ }, [props.selColor, props.paper, props.seamColor, props.showNumbers]);

  // ---------- helpers operating on buffers ----------
  function paintPaper() {
    const d = S.fillData.data; const { paper } = props;
    const pr = parseInt(paper.slice(1, 3), 16), pg = parseInt(paper.slice(3, 5), 16), pb = parseInt(paper.slice(5, 7), 16);
    // tint paper very slightly per-region luminance hint so unpainted areas read as a faint ghost
    const data = S.data;
    for (let i = 0; i < data.w * data.h; i++) {
      d[i * 4] = pr; d[i * 4 + 1] = pg; d[i * 4 + 2] = pb; d[i * 4 + 3] = 255;
    }
  }
  function repaintAllFilled() {
    const data = S.data, d = S.fillData.data;
    for (let r = 0; r < data.regionCount; r++) {
      if (!S.filled[r]) continue;
      const col = data.palette[data.regionColor[r]];
      for (const p of data.regionPixels[r]) { d[p * 4] = col.r; d[p * 4 + 1] = col.g; d[p * 4 + 2] = col.b; d[p * 4 + 3] = 255; }
    }
    S.fillCtx.putImageData(S.fillData, 0, 0);
  }
  function updateHighlight() {
    const data = S.data; if (!data) return;
    const d = S.hlData.data; d.fill(0);
    const sel = props.selColor;
    if (sel >= 0) {
      for (let r = 0; r < data.regionCount; r++) {
        if (S.filled[r] || data.regionColor[r] !== sel) continue;
        const col = data.palette[sel];
        for (const p of data.regionPixels[r]) { d[p * 4] = col.r; d[p * 4 + 1] = col.g; d[p * 4 + 2] = col.b; d[p * 4 + 3] = 255; }
      }
    }
    S.hlCtx.putImageData(S.hlData, 0, 0);
  }
  function fillRegion(r, opts) {
    opts = opts || {};
    const data = S.data;
    if (S.filled[r]) return false;
    S.filled[r] = 1;
    S.order.push(r);
    const ci = data.regionColor[r];
    S.filledPerColor[ci]++;
    const col = data.palette[ci];
    const d = S.fillData.data, hd = S.hlData.data;
    for (const p of data.regionPixels[r]) {
      d[p * 4] = col.r; d[p * 4 + 1] = col.g; d[p * 4 + 2] = col.b; d[p * 4 + 3] = 255;
      hd[p * 4 + 3] = 0;
    }
    S.fillCtx.putImageData(S.fillData, 0, 0);
    S.hlCtx.putImageData(S.hlData, 0, 0);
    if (!opts.silent) {
      const c = data.centroids[r];
      S.rings.push({ x: c.x, y: c.y, r: c.r, t: performance.now() });
    }
    if (!opts.quiet) props.onFill && props.onFill(ci);
    reportFill(ci);
    return true;
  }
  function unfillRegion(r) {
    const data = S.data;
    if (!S.filled[r]) return;
    S.filled[r] = 0;
    const ci = data.regionColor[r];
    S.filledPerColor[ci]--;
    const d = S.fillData.data, hd = S.hlData.data;
    const { paper } = props;
    const pr = parseInt(paper.slice(1, 3), 16), pg = parseInt(paper.slice(3, 5), 16), pb = parseInt(paper.slice(5, 7), 16);
    const restoreHl = ci === props.selColor;
    for (const p of data.regionPixels[r]) {
      d[p * 4] = pr; d[p * 4 + 1] = pg; d[p * 4 + 2] = pb; d[p * 4 + 3] = 255;
      if (restoreHl) { hd[p * 4] = data.palette[ci].r; hd[p * 4 + 1] = data.palette[ci].g; hd[p * 4 + 2] = data.palette[ci].b; hd[p * 4 + 3] = 255; }
    }
    S.fillCtx.putImageData(S.fillData, 0, 0);
    S.hlCtx.putImageData(S.hlData, 0, 0);
    reportFill(ci);
  }
  function reportFill(ci) {
    const data = S.data;
    let done = 0;
    for (let r = 0; r < data.regionCount; r++) if (S.filled[r]) done++;
    const remaining = new Int32Array(data.palette.length);
    for (let i = 0; i < data.palette.length; i++) remaining[i] = data.colorCounts[i] - S.filledPerColor[i];
    const completedColor = (ci !== undefined && remaining[ci] === 0) ? ci : -1;
    props.onFillChange && props.onFillChange({ done, total: data.regionCount, remaining, completedColor, canUndo: S.order.length > 0 });
    if (done === data.regionCount) props.onComplete && props.onComplete();
  }

  // ---------- layout / transform ----------
  function layout(initial) {
    const wrap = wrapRef.current, cv = canvasRef.current, data = S.data;
    if (!wrap || !cv || !data) return;
    const cssW = wrap.clientWidth, cssH = wrap.clientHeight;
    const dpr = Math.min(window.devicePixelRatio || 1, 2.5);
    cv.width = Math.round(cssW * dpr); cv.height = Math.round(cssH * dpr);
    cv.style.width = cssW + 'px'; cv.style.height = cssH + 'px';
    S.cssW = cssW; S.cssH = cssH; S.dpr = dpr;
    S.ctx = cv.getContext('2d');
    const pad = 24;
    const fit = Math.min((cssW - pad * 2) / data.w, (cssH - pad * 2) / data.h);
    const oldFit = S.fit;
    S.fit = fit;
    S.minScale = fit * 0.85;
    S.maxScale = Math.max(fit * 6, 16);
    if (initial || !S.t) {
      S.t = { scale: fit, tx: (cssW - data.w * fit) / 2, ty: (cssH - data.h * fit) / 2 };
    } else if (oldFit) {
      const ratio = S.t.scale / oldFit;
      S.t.scale = fit * ratio;
      clampT();
    }
  }
  function clampT() {
    const data = S.data, t = S.t;
    t.scale = Math.max(S.minScale, Math.min(S.maxScale, t.scale));
    const iw = data.w * t.scale, ih = data.h * t.scale;
    const margin = 60;
    // keep image overlapping the viewport
    const minTx = Math.min(margin, S.cssW - iw - 0) - Math.max(0, 0);
    if (iw <= S.cssW) t.tx = (S.cssW - iw) / 2;
    else t.tx = Math.max(S.cssW - iw - margin, Math.min(margin, t.tx));
    if (ih <= S.cssH) t.ty = (S.cssH - ih) / 2;
    else t.ty = Math.max(S.cssH - ih - margin, Math.min(margin, t.ty));
  }

  // ---------- drawing ----------
  function requestDraw() {
    if (S.raf || S.to) return;
    const run = () => {
      if (S.raf) { cancelAnimationFrame(S.raf); S.raf = 0; }
      if (S.to) { clearTimeout(S.to); S.to = 0; }
      draw();
    };
    // rAF for smooth foreground animation; setTimeout fallback guarantees a
    // draw even when rAF is throttled (e.g. an offscreen/background iframe).
    S.raf = requestAnimationFrame(run);
    S.to = setTimeout(run, 45);
  }
  function draw() {
    const ctx = S.ctx, data = S.data, t = S.t; if (!ctx || !data) return;
    const dpr = S.dpr;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, S.cssW * dpr, S.cssH * dpr);
    ctx.setTransform(t.scale * dpr, 0, 0, t.scale * dpr, t.tx * dpr, t.ty * dpr);

    // paper drop shadow
    ctx.save();
    ctx.shadowColor = 'rgba(40,30,20,0.18)'; ctx.shadowBlur = 18 / t.scale; ctx.shadowOffsetY = 6 / t.scale;
    ctx.fillStyle = props.paper; ctx.fillRect(0, 0, data.w, data.h);
    ctx.restore();

    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(S.fillCv, 0, 0);

    // selected-colour highlight (pulses subtly)
    if (props.selColor >= 0) {
      const pulse = 0.22 + 0.12 * (0.5 + 0.5 * Math.sin(performance.now() / 520));
      ctx.globalAlpha = S.hintPulse ? Math.min(0.75, pulse + S.hintPulse) : pulse;
      ctx.drawImage(S.hlCv, 0, 0);
      ctx.globalAlpha = 1;
    }

    // boundaries
    ctx.lineWidth = Math.max(0.5, 0.85 / t.scale);
    ctx.strokeStyle = props.seamColor;
    ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.stroke(S.boundary);

    // numbers
    if (props.showNumbers) drawNumbers(ctx, t);

    // satisfaction rings
    const now = performance.now();
    S.rings = S.rings.filter((rg) => now - rg.t < 460);
    for (const rg of S.rings) {
      const k = (now - rg.t) / 460;
      ctx.beginPath();
      ctx.globalAlpha = (1 - k) * 0.6;
      ctx.lineWidth = Math.max(0.4, 2.2 * (1 - k) / t.scale);
      ctx.strokeStyle = '#ffffff';
      ctx.arc(rg.x, rg.y, rg.r * (0.4 + k * 1.3), 0, 7);
      ctx.stroke(); ctx.globalAlpha = 1;
    }
    // wrong feedback
    if (S.wrong && now - S.wrong.t < 420) {
      const k = (now - S.wrong.t) / 420;
      ctx.globalAlpha = 1 - k;
      ctx.strokeStyle = '#d8503a'; ctx.lineWidth = 1.6 / t.scale;
      const x = S.wrong.x, y = S.wrong.y, s = 2.4;
      ctx.beginPath(); ctx.moveTo(x - s, y - s); ctx.lineTo(x + s, y + s);
      ctx.moveTo(x + s, y - s); ctx.lineTo(x - s, y + s); ctx.stroke();
      ctx.globalAlpha = 1;
    } else if (S.wrong && now - S.wrong.t >= 420) S.wrong = null;

    ctx.setTransform(1, 0, 0, 1, 0, 0);

    // notify viewport changes (for the minimap) — only when it actually moved
    if (props.onView) {
      const key = (t.scale | 0) + ':' + (t.tx | 0) + ':' + (t.ty | 0);
      if (key !== S.lastViewKey) {
        S.lastViewKey = key;
        props.onView({ scale: t.scale, tx: t.tx, ty: t.ty, w: data.w, h: data.h, cssW: S.cssW, cssH: S.cssH, fit: S.fit, zoomed: t.scale > S.fit * 1.12 });
      }
    }

    // keep animating while there are transient effects or a hint pulse
    if (props.selColor >= 0 || S.rings.length || S.wrong || S.hintPulse || S.tween) requestDraw();
  }
  function drawNumbers(ctx, t) {
    const data = S.data;
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for (let r = 0; r < data.regionCount; r++) {
      if (S.filled[r]) continue;
      const c = data.centroids[r];
      const screenR = c.r * t.scale;
      if (screenR < 6.5) continue; // too small to label
      // cull off-screen
      const sx = c.x * t.scale + t.tx, sy = c.y * t.scale + t.ty;
      if (sx < -16 || sx > S.cssW + 16 || sy < -16 || sy > S.cssH + 16) continue;
      const cssFont = Math.max(6, Math.min(c.r * t.scale * 0.95, 26));
      ctx.font = `600 ${cssFont / t.scale}px ui-rounded, "SF Pro Rounded", system-ui, sans-serif`;
      const isSel = data.regionColor[r] === props.selColor;
      ctx.fillStyle = isSel ? 'rgba(60,45,30,0.95)' : 'rgba(120,108,92,0.62)';
      ctx.fillText(String(data.palette[data.regionColor[r]].num), c.x, c.y);
    }
  }

  // ---------- coordinate mapping ----------
  function localXY(e) {
    const rect = canvasRef.current.getBoundingClientRect();
    return { x: e.clientX - rect.left, y: e.clientY - rect.top };
  }
  function regionAt(cx, cy) {
    const data = S.data, t = S.t;
    const ix = Math.floor((cx - t.tx) / t.scale), iy = Math.floor((cy - t.ty) / t.scale);
    if (ix < 0 || iy < 0 || ix >= data.w || iy >= data.h) return -1;
    return data.labels[iy * data.w + ix];
  }
  function imgPt(cx, cy) {
    const t = S.t; return { x: (cx - t.tx) / t.scale, y: (cy - t.ty) / t.scale };
  }

  // ---------- painting actions ----------
  function tryFillAt(cx, cy) {
    const r = regionAt(cx, cy);
    if (r < 0) return;
    if (S.filled[r]) return;
    if (S.data.regionColor[r] === props.selColor) {
      fillRegion(r); requestDraw();
    } else {
      const p = imgPt(cx, cy);
      S.wrong = { x: p.x, y: p.y, t: performance.now() };
      S.mistakes++;
      props.onWrong && props.onWrong();
      requestDraw();
    }
  }

  // ---------- pointer gestures ----------
  React.useEffect(() => {
    const cv = canvasRef.current; if (!cv) return;
    const pointers = new Map();
    let gesture = 'none';
    let pan = null, pinch = null, tap = null, painted = null;

    const down = (e) => {
      try { cv.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
      pointers.set(e.pointerId, localXY(e));
      S.tween = null;
      if (pointers.size === 2) {
        const pts = [...pointers.values()];
        const dx = pts[0].x - pts[1].x, dy = pts[0].y - pts[1].y;
        const mid = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
        pinch = { dist: Math.hypot(dx, dy), mid, ip: imgPt(mid.x, mid.y), scale: S.t.scale };
        gesture = 'pinch'; tap = null; painted = null;
      } else if (pointers.size === 1) {
        const p = localXY(e);
        if (props.modeRef.current === 'paint') {
          gesture = 'paint'; painted = new Set();
          paintStroke(p.x, p.y, painted);
        } else {
          gesture = 'panTap';
          pan = { x: p.x, y: p.y, tx: S.t.tx, ty: S.t.ty };
          tap = { x: p.x, y: p.y, t: performance.now(), moved: false };
        }
      }
    };
    const move = (e) => {
      if (!pointers.has(e.pointerId)) return;
      const p = localXY(e); pointers.set(e.pointerId, p);
      if (gesture === 'pinch' && pointers.size >= 2) {
        const pts = [...pointers.values()];
        const dx = pts[0].x - pts[1].x, dy = pts[0].y - pts[1].y;
        const dist = Math.hypot(dx, dy);
        const mid = { x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2 };
        let ns = pinch.scale * (dist / pinch.dist);
        ns = Math.max(S.minScale, Math.min(S.maxScale, ns));
        S.t.scale = ns;
        S.t.tx = mid.x - pinch.ip.x * ns;
        S.t.ty = mid.y - pinch.ip.y * ns;
        clampT(); requestDraw();
      } else if (gesture === 'paint') {
        paintStroke(p.x, p.y, painted);
      } else if (gesture === 'panTap') {
        const ddx = p.x - pan.x, ddy = p.y - pan.y;
        if (Math.hypot(ddx, ddy) > 6) tap && (tap.moved = true);
        S.t.tx = pan.tx + ddx; S.t.ty = pan.ty + ddy;
        clampT(); requestDraw();
      }
    };
    const up = (e) => {
      pointers.delete(e.pointerId);
      if (gesture === 'panTap' && tap && !tap.moved) {
        // tap to fill (+ double-tap zoom bonus)
        tryFillAt(tap.x, tap.y);
        const now = performance.now();
        if (S.lastTap && now - S.lastTap.t < 300 && Math.hypot(tap.x - S.lastTap.x, tap.y - S.lastTap.y) < 24) {
          zoomAt(tap.x, tap.y, S.t.scale < S.fit * 2.2 ? 2.2 : 0.45);
          S.lastTap = null;
        } else S.lastTap = { x: tap.x, y: tap.y, t: now };
      }
      if (pointers.size === 0) { gesture = 'none'; pan = pinch = tap = painted = null; }
      else if (pointers.size === 1 && gesture === 'pinch') {
        // resume pan from remaining finger
        const p = [...pointers.values()][0];
        pan = { x: p.x, y: p.y, tx: S.t.tx, ty: S.t.ty };
        gesture = props.modeRef.current === 'paint' ? 'paint' : 'panTap';
        if (gesture === 'paint') painted = new Set();
      }
    };
    const wheel = (e) => {
      e.preventDefault();
      const p = localXY(e);
      zoomAt(p.x, p.y, e.deltaY < 0 ? 1.12 : 0.89, true);
    };
    cv.addEventListener('pointerdown', down);
    cv.addEventListener('pointermove', move);
    cv.addEventListener('pointerup', up);
    cv.addEventListener('pointercancel', up);
    cv.addEventListener('wheel', wheel, { passive: false });
    return () => {
      cv.removeEventListener('pointerdown', down);
      cv.removeEventListener('pointermove', move);
      cv.removeEventListener('pointerup', up);
      cv.removeEventListener('pointercancel', up);
      cv.removeEventListener('wheel', wheel);
    };
    // eslint-disable-next-line
  }, []);

  function paintStroke(cx, cy, painted) {
    const r = regionAt(cx, cy);
    if (r < 0 || painted.has(r) || S.filled[r]) {
      if (r >= 0 && S.data.regionColor[r] !== props.selColor && !painted.has(r)) {
        painted.add(r);
        const p = imgPt(cx, cy); S.wrong = { x: p.x, y: p.y, t: performance.now() };
        S.mistakes++;
        props.onWrong && props.onWrong(); requestDraw();
      }
      return;
    }
    painted.add(r);
    if (S.data.regionColor[r] === props.selColor) { fillRegion(r); requestDraw(); }
  }

  function zoomAt(cx, cy, factor, additive) {
    const ip = imgPt(cx, cy);
    let ns = S.t.scale * (additive ? factor : factor);
    ns = Math.max(S.minScale, Math.min(S.maxScale, ns));
    S.t.scale = ns; S.t.tx = cx - ip.x * ns; S.t.ty = cy - ip.y * ns;
    clampT(); requestDraw();
  }

  function tweenTo(target, dur) {
    const start = { ...S.t }, t0 = performance.now();
    S.tween = true;
    const step = () => {
      const k = Math.min(1, (performance.now() - t0) / dur);
      const e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
      S.t.scale = start.scale + (target.scale - start.scale) * e;
      S.t.tx = start.tx + (target.tx - start.tx) * e;
      S.t.ty = start.ty + (target.ty - start.ty) * e;
      requestDraw();
      if (k < 1) requestAnimationFrame(step); else S.tween = null;
    };
    requestAnimationFrame(step);
  }

  // ---------- imperative API ----------
  React.useImperativeHandle(ref, () => ({
    hint() {
      const data = S.data; if (!data || props.selColor < 0) return;
      // nearest unfilled region of selected color to viewport centre
      const ccx = (S.cssW / 2 - S.t.tx) / S.t.scale, ccy = (S.cssH / 2 - S.t.ty) / S.t.scale;
      let best = -1, bd = Infinity;
      for (let r = 0; r < data.regionCount; r++) {
        if (S.filled[r] || data.regionColor[r] !== props.selColor) continue;
        const c = data.centroids[r];
        const d = (c.x - ccx) ** 2 + (c.y - ccy) ** 2;
        if (d < bd) { bd = d; best = r; }
      }
      if (best < 0) return;
      const c = data.centroids[best];
      const targetScale = Math.max(S.t.scale, S.fit * 2.4);
      tweenTo({ scale: targetScale, tx: S.cssW / 2 - c.x * targetScale, ty: S.cssH / 2 - c.y * targetScale }, 520);
      S.hintPulse = 0.5;
      const t0 = performance.now();
      const fade = () => {
        const k = (performance.now() - t0) / 1400;
        S.hintPulse = Math.max(0, 0.5 * (1 - k));
        requestDraw();
        if (k < 1) requestAnimationFrame(fade); else S.hintPulse = 0;
      };
      requestAnimationFrame(fade);
    },
    magicFill() {
      const data = S.data; if (!data || props.selColor < 0) return;
      const targets = [];
      for (let r = 0; r < data.regionCount; r++)
        if (!S.filled[r] && data.regionColor[r] === props.selColor) targets.push(r);
      if (!targets.length) return;
      props.onMagic && props.onMagic();
      let i = 0;
      const step = () => {
        const batch = Math.max(1, Math.round(targets.length / 14));
        for (let k = 0; k < batch && i < targets.length; k++, i++) fillRegion(targets[i], { quiet: true });
        requestDraw();
        if (i < targets.length) setTimeout(step, 28);
      };
      step();
    },
    undo() {
      if (!S.order.length) return;
      const r = S.order.pop();
      unfillRegion(r);
      requestDraw();
    },
    zoomBy(f) { zoomAt(S.cssW / 2, S.cssH / 2, f); },
    fitView() { layout(true); requestDraw(); },
    getState() {
      let done = 0; for (let r = 0; r < S.data.regionCount; r++) if (S.filled[r]) done++;
      return { filled: Uint8Array.from(S.filled), order: S.order.slice(), mistakes: S.mistakes, done, total: S.data.regionCount };
    },
  }));

  // keep a live ref to mode for pointer handlers
  props.modeRef.current = props.mode;

  // resize handling
  React.useEffect(() => {
    const ro = new ResizeObserver(() => { layout(false); requestDraw(); });
    if (wrapRef.current) ro.observe(wrapRef.current);
    return () => ro.disconnect();
    // eslint-disable-next-line
  }, []);

  return (
    <div ref={wrapRef} style={{ position: 'absolute', inset: 0, touchAction: 'none', overflow: 'hidden' }}>
      <canvas ref={canvasRef} style={{ display: 'block', touchAction: 'none' }} />
    </div>
  );
});

window.PaintCanvas = PaintCanvas;
