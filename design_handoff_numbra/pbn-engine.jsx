// pbn-engine.jsx
// Turns any image (a <canvas> or <img>) into paint-by-numbers data:
// color quantization (median cut) -> nearest-color index map -> majority
// smoothing -> connected-component regions -> small-region merging ->
// per-region color, centroid, pixel lists, and a boundary segment list.
//
// Exports (to window): PBNEngine = { generate, makeSample, SAMPLES }

(function () {
  // ---- small helpers ---------------------------------------------------
  function toHex(r, g, b) {
    const h = (n) => n.toString(16).padStart(2, '0');
    return '#' + h(r) + h(g) + h(b);
  }
  // perceived luminance 0..255
  function luma(r, g, b) { return 0.299 * r + 0.587 * g + 0.114 * b; }

  // ---- downscale an image source into a small RGBA buffer --------------
  function downscale(src, targetLong) {
    const sw = src.width || src.naturalWidth;
    const sh = src.height || src.naturalHeight;
    const scale = targetLong / Math.max(sw, sh);
    const w = Math.max(8, Math.round(sw * scale));
    const h = Math.max(8, Math.round(sh * scale));
    const cv = document.createElement('canvas');
    cv.width = w; cv.height = h;
    const ctx = cv.getContext('2d', { willReadFrequently: true });
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(src, 0, 0, w, h);
    return { data: ctx.getImageData(0, 0, w, h).data, w, h };
  }

  // ---- median cut quantization ----------------------------------------
  function medianCut(data, w, h, n) {
    const px = [];
    for (let i = 0; i < w * h; i++) {
      px.push([data[i * 4], data[i * 4 + 1], data[i * 4 + 2]]);
    }
    let boxes = [px];
    const channelRange = (box) => {
      const mn = [255, 255, 255], mx = [0, 0, 0];
      for (const p of box) for (let c = 0; c < 3; c++) {
        if (p[c] < mn[c]) mn[c] = p[c];
        if (p[c] > mx[c]) mx[c] = p[c];
      }
      return [mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]];
    };
    while (boxes.length < n) {
      // pick box with largest single-channel range and >1 pixel
      let bi = -1, best = -1, bc = 0;
      for (let i = 0; i < boxes.length; i++) {
        if (boxes[i].length < 2) continue;
        const r = channelRange(boxes[i]);
        const m = Math.max(r[0], r[1], r[2]);
        if (m > best) { best = m; bi = i; bc = r.indexOf(m); }
      }
      if (bi < 0) break;
      const box = boxes[bi];
      box.sort((a, b) => a[bc] - b[bc]);
      const mid = box.length >> 1;
      boxes.splice(bi, 1, box.slice(0, mid), box.slice(mid));
    }
    return boxes.map((box) => {
      let r = 0, g = 0, b = 0;
      for (const p of box) { r += p[0]; g += p[1]; b += p[2]; }
      const k = Math.max(1, box.length);
      return [Math.round(r / k), Math.round(g / k), Math.round(b / k)];
    });
  }

  // nearest palette index for a color
  function nearest(pal, r, g, b) {
    let bi = 0, bd = Infinity;
    for (let i = 0; i < pal.length; i++) {
      const dr = pal[i][0] - r, dg = pal[i][1] - g, db = pal[i][2] - b;
      const d = dr * dr + dg * dg + db * db;
      if (d < bd) { bd = d; bi = i; }
    }
    return bi;
  }

  // majority filter (3x3) over index map to remove single-pixel speckles
  function smooth(idx, w, h) {
    const out = idx.slice();
    const counts = new Int32Array(64);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        counts.fill(0);
        let bestC = idx[y * w + x], bestN = -1;
        for (let dy = -1; dy <= 1; dy++) {
          const yy = y + dy; if (yy < 0 || yy >= h) continue;
          for (let dx = -1; dx <= 1; dx++) {
            const xx = x + dx; if (xx < 0 || xx >= w) continue;
            const c = idx[yy * w + xx];
            counts[c]++;
            if (counts[c] > bestN) { bestN = counts[c]; bestC = c; }
          }
        }
        out[y * w + x] = bestC;
      }
    }
    return out;
  }

  // ---- connected components (4-connectivity) --------------------------
  function label(idx, w, h) {
    const labels = new Int32Array(w * h).fill(-1);
    const stack = new Int32Array(w * h);
    let next = 0;
    const regionColor = [];
    const regionPixels = [];
    for (let s = 0; s < w * h; s++) {
      if (labels[s] !== -1) continue;
      const color = idx[s];
      const id = next++;
      let sp = 0; stack[sp++] = s; labels[s] = id;
      const pix = [];
      while (sp > 0) {
        const p = stack[--sp];
        pix.push(p);
        const x = p % w, y = (p / w) | 0;
        if (x > 0) { const q = p - 1; if (labels[q] === -1 && idx[q] === color) { labels[q] = id; stack[sp++] = q; } }
        if (x < w - 1) { const q = p + 1; if (labels[q] === -1 && idx[q] === color) { labels[q] = id; stack[sp++] = q; } }
        if (y > 0) { const q = p - w; if (labels[q] === -1 && idx[q] === color) { labels[q] = id; stack[sp++] = q; } }
        if (y < h - 1) { const q = p + w; if (labels[q] === -1 && idx[q] === color) { labels[q] = id; stack[sp++] = q; } }
      }
      regionColor.push(color);
      regionPixels.push(pix);
    }
    return { labels, regionColor, regionPixels, count: next };
  }

  // find the dominant adjacent region (most shared border) for region rid
  function dominantNeighbor(labels, w, h, pix, rid) {
    const tally = new Map();
    for (const p of pix) {
      const x = p % w, y = (p / w) | 0;
      const ns = [];
      if (x > 0) ns.push(p - 1);
      if (x < w - 1) ns.push(p + 1);
      if (y > 0) ns.push(p - w);
      if (y < h - 1) ns.push(p + w);
      for (const q of ns) {
        const l = labels[q];
        if (l !== rid) tally.set(l, (tally.get(l) || 0) + 1);
      }
    }
    let best = -1, bn = -1;
    for (const [l, c] of tally) if (c > bn) { bn = c; best = l; }
    return best;
  }

  // merge regions smaller than minSize into their dominant neighbor
  function mergeSmall(labels, w, h, reg, minSize) {
    const { regionColor, regionPixels } = reg;
    const alive = new Array(reg.count).fill(true);
    // process repeatedly, smallest first
    let order = [];
    for (let i = 0; i < reg.count; i++) order.push(i);
    order.sort((a, b) => regionPixels[a].length - regionPixels[b].length);
    for (const rid of order) {
      if (!alive[rid]) continue;
      if (regionPixels[rid].length >= minSize) continue;
      const nb = dominantNeighbor(labels, w, h, regionPixels[rid], rid);
      if (nb < 0 || !alive[nb]) continue;
      // reassign
      for (const p of regionPixels[rid]) labels[p] = nb;
      regionPixels[nb] = regionPixels[nb].concat(regionPixels[rid]);
      regionPixels[rid] = [];
      alive[rid] = false;
    }
    // compact ids
    const remap = new Int32Array(reg.count).fill(-1);
    let n = 0;
    const newColor = [], newPix = [];
    for (let i = 0; i < reg.count; i++) {
      if (!alive[i] || regionPixels[i].length === 0) continue;
      remap[i] = n;
      newColor.push(regionColor[i]);
      newPix.push(regionPixels[i]);
      n++;
    }
    for (let p = 0; p < labels.length; p++) labels[p] = remap[labels[p]];
    return { labels, regionColor: newColor, regionPixels: newPix, count: n };
  }

  // boundary segments between differing labels, in image coords (Float32)
  function boundaries(labels, w, h) {
    const seg = [];
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const l = labels[y * w + x];
        // right edge
        if (x === w - 1 || labels[y * w + x + 1] !== l) {
          seg.push(x + 1, y, x + 1, y + 1);
        }
        // bottom edge
        if (y === h - 1 || labels[(y + 1) * w + x] !== l) {
          seg.push(x, y + 1, x + 1, y + 1);
        }
        // also the very top/left outer border
        if (x === 0) seg.push(0, y, 0, y + 1);
        if (y === 0) seg.push(x, 0, x + 1, 0);
      }
    }
    return new Float32Array(seg);
  }

  // representative interior point + a label-size hint per region
  function centroids(labels, w, h, regionPixels) {
    return regionPixels.map((pix) => {
      let sx = 0, sy = 0;
      for (const p of pix) { sx += p % w; sy += (p / w) | 0; }
      const cx = sx / pix.length, cy = sy / pix.length;
      // nearest actual pixel to the mean so the number sits inside
      let best = pix[0], bd = Infinity;
      for (const p of pix) {
        const x = p % w, y = (p / w) | 0;
        const d = (x - cx) * (x - cx) + (y - cy) * (y - cy);
        if (d < bd) { bd = d; best = p; }
      }
      // crude inscribed radius -> font hint
      const r = Math.sqrt(pix.length / Math.PI);
      return { x: (best % w) + 0.5, y: ((best / w) | 0) + 0.5, r };
    });
  }

  // ---- main entry ------------------------------------------------------
  // opts: { colors, detail }  detail = long-side px in the working buffer
  function generate(src, opts) {
    opts = opts || {};
    const colors = opts.colors || 16;
    const detail = opts.detail || 90;
    const minSize = opts.minSize || Math.max(4, Math.round((detail * detail) / 2600));

    const { data, w, h } = downscale(src, detail);
    const pal = medianCut(data, w, h, colors);

    // index map
    let idx = new Uint8Array(w * h);
    for (let i = 0; i < w * h; i++) {
      idx[i] = nearest(pal, data[i * 4], data[i * 4 + 1], data[i * 4 + 2]);
    }
    idx = smooth(idx, w, h);

    let reg = label(idx, w, h);
    reg = mergeSmall(reg.labels, w, h, reg, minSize);
    // a second gentle pass for stragglers created by merging
    reg = mergeSmall(reg.labels, w, h, reg, Math.max(3, minSize - 2));

    const cents = centroids(reg.labels, w, h, reg.regionPixels);
    const seg = boundaries(reg.labels, w, h);

    // sort the palette light->dark so numbering feels natural, then remap
    const palOrder = pal
      .map((c, i) => ({ i, l: luma(c[0], c[1], c[2]) }))
      .sort((a, b) => b.l - a.l)
      .map((o) => o.i);
    const palRemap = new Int32Array(pal.length);
    palOrder.forEach((oldI, newI) => { palRemap[oldI] = newI; });
    const palette = palOrder.map((oldI, newI) => ({
      r: pal[oldI][0], g: pal[oldI][1], b: pal[oldI][2],
      hex: toHex(pal[oldI][0], pal[oldI][1], pal[oldI][2]),
      light: luma(pal[oldI][0], pal[oldI][1], pal[oldI][2]) > 150,
      num: newI + 1,
    }));

    const regionColor = new Int32Array(reg.count);
    for (let i = 0; i < reg.count; i++) regionColor[i] = palRemap[reg.regionColor[i]];

    // count regions per palette color (so empty colors can be dropped)
    const colorCounts = new Int32Array(palette.length);
    for (let i = 0; i < reg.count; i++) colorCounts[regionColor[i]]++;

    return {
      w, h,
      palette,
      colorCounts,
      labels: reg.labels,
      regionColor,
      regionPixels: reg.regionPixels,
      regionCount: reg.count,
      centroids: cents,
      segments: seg,
    };
  }

  // ---------------------------------------------------------------------
  // Procedural sample "photos" (so the demo needs no external assets).
  // Busy compositions + smooth multi-octave texture so quantization yields a
  // satisfying number of regions (like a real photo would).
  // ---------------------------------------------------------------------
  function clampB(v) { return v < 0 ? 0 : v > 255 ? 255 : v; }
  function addTexture(c, s, amp) {
    amp = amp || 20;
    const img = c.getImageData(0, 0, s, s), d = img.data;
    for (let y = 0; y < s; y++) {
      for (let x = 0; x < s; x++) {
        const i = (y * s + x) * 4;
        const n =
          Math.sin(x * 0.017 + y * 0.009) * 0.55 +
          Math.sin(x * 0.004 - y * 0.021 + 1.3) * 0.5 +
          Math.sin((x + y) * 0.012 + 2.1) * 0.42 +
          Math.sin(x * 0.031 + 0.7) * 0.32 * Math.sin(y * 0.024 + 0.4) +
          Math.sin((x - y) * 0.026 + 4.2) * 0.3 +
          Math.sin(x * 0.052 + y * 0.041 + 1.7) * 0.26 +
          Math.sin((x + 2 * y) * 0.047 + 3.1) * 0.2;
        const v = n * amp;
        d[i] = clampB(d[i] + v); d[i + 1] = clampB(d[i + 1] + v); d[i + 2] = clampB(d[i + 2] + v);
      }
    }
    c.putImageData(img, 0, 0);
  }

  function makeSample(name, size) {
    size = size || 520;
    const cv = document.createElement('canvas');
    cv.width = size; cv.height = size;
    const c = cv.getContext('2d');
    const fns = SAMPLE_FNS[name] || SAMPLE_FNS.sunset;
    fns(c, size);
    addTexture(c, size, name === 'bloom' ? 15 : 22);
    return cv;
  }

  const SAMPLE_FNS = {
    sunset(c, s) {
      const sky = c.createLinearGradient(0, 0, 0, s * 0.66);
      sky.addColorStop(0, '#33336b'); sky.addColorStop(0.3, '#7d4f86');
      sky.addColorStop(0.55, '#d76a55'); sky.addColorStop(0.78, '#f0a64f'); sky.addColorStop(1, '#ffe09c');
      c.fillStyle = sky; c.fillRect(0, 0, s, s);
      // sun + glow
      const glow = c.createRadialGradient(s * 0.5, s * 0.5, 6, s * 0.5, s * 0.5, s * 0.28);
      glow.addColorStop(0, '#fff3c8'); glow.addColorStop(1, 'rgba(255,220,140,0)');
      c.fillStyle = glow; c.beginPath(); c.arc(s * 0.5, s * 0.5, s * 0.28, 0, 7); c.fill();
      c.fillStyle = '#fff0bd'; c.beginPath(); c.arc(s * 0.5, s * 0.5, s * 0.1, 0, 7); c.fill();
      // layered hills (each its own colour band, overlapping)
      const hills = [['#caa15a', 0.62], ['#9c7a6e', 0.7], ['#6f5a72', 0.78], ['#4a3f63', 0.86], ['#2f2a4d', 0.94]];
      hills.forEach(([col, base], k) => {
        c.fillStyle = col; c.beginPath(); c.moveTo(0, s * base);
        for (let x = 0; x <= s; x += s / 6) {
          c.lineTo(x, s * base - Math.sin(x * 0.01 + k * 1.7) * s * 0.05 - (k % 2) * s * 0.02);
        }
        c.lineTo(s, s); c.lineTo(0, s); c.closePath(); c.fill();
      });
      // cypress trees
      c.fillStyle = '#2b2540';
      [0.16, 0.27, 0.8, 0.9].forEach((x, i) => {
        c.beginPath(); c.ellipse(s * x, s * (0.74 + i * 0.01), s * 0.022, s * 0.1, 0, 0, 7); c.fill();
      });
    },
    lake(c, s) {
      const sky = c.createLinearGradient(0, 0, 0, s * 0.5);
      sky.addColorStop(0, '#aedcee'); sky.addColorStop(1, '#f2ead9');
      c.fillStyle = sky; c.fillRect(0, 0, s, s * 0.52);
      // sun
      c.fillStyle = '#fbf0cf'; c.beginPath(); c.arc(s * 0.74, s * 0.16, s * 0.06, 0, 7); c.fill();
      // mountains with facets + snow
      const peaks = [[0.16, 0.2, '#8fa6bd'], [0.46, 0.12, '#7e95ad'], [0.78, 0.18, '#9aaec0']];
      peaks.forEach(([px, top, col]) => {
        c.fillStyle = col; c.beginPath();
        c.moveTo(s * (px - 0.2), s * 0.52); c.lineTo(s * px, s * top); c.lineTo(s * (px + 0.2), s * 0.52); c.closePath(); c.fill();
        // shadow facet
        c.fillStyle = 'rgba(40,60,90,0.28)'; c.beginPath();
        c.moveTo(s * px, s * top); c.lineTo(s * (px + 0.2), s * 0.52); c.lineTo(s * (px + 0.04), s * 0.52); c.closePath(); c.fill();
        // snow cap
        c.fillStyle = '#f4f8fb'; c.beginPath();
        c.moveTo(s * px, s * top); c.lineTo(s * (px - 0.05), s * (top + 0.08)); c.lineTo(s * px, s * (top + 0.05)); c.lineTo(s * (px + 0.05), s * (top + 0.08)); c.closePath(); c.fill();
      });
      // forest of little triangles
      c.fillStyle = '#3f6f53';
      for (let i = 0; i < 18; i++) {
        const x = (i / 18) * s + (i % 2) * 6, h = s * (0.05 + (i % 3) * 0.012);
        c.beginPath(); c.moveTo(x, s * 0.52); c.lineTo(x + s * 0.03, s * 0.52 - h); c.lineTo(x + s * 0.06, s * 0.52); c.closePath(); c.fill();
      }
      // lake with ripple bands
      const lake = c.createLinearGradient(0, s * 0.52, 0, s);
      lake.addColorStop(0, '#5d93a8'); lake.addColorStop(1, '#1f4a64');
      c.fillStyle = lake; c.fillRect(0, s * 0.52, s, s * 0.48);
      c.fillStyle = 'rgba(244,248,251,0.5)';
      for (let i = 0; i < 5; i++) c.fillRect(s * (0.2 + i * 0.02), s * (0.6 + i * 0.07), s * 0.5, s * 0.012);
      // reflected peaks (muted)
      c.fillStyle = 'rgba(126,149,173,0.4)';
      c.beginPath(); c.moveTo(s * 0.26, s * 0.52); c.lineTo(s * 0.46, s * 0.66); c.lineTo(s * 0.66, s * 0.52); c.closePath(); c.fill();
    },
    bloom(c, s) {
      c.fillStyle = '#efe6d4'; c.fillRect(0, 0, s, s);
      // soft table shadow
      c.fillStyle = 'rgba(150,130,100,0.15)'; c.beginPath(); c.ellipse(s * 0.5, s * 0.82, s * 0.34, s * 0.08, 0, 0, 7); c.fill();
      const flowers = [
        [0.32, 0.4, 0.17, '#e8748c', '#c64f6e'],
        [0.64, 0.34, 0.14, '#f4a259', '#e07a3c'],
        [0.58, 0.62, 0.15, '#8e7bc4', '#6a55a0'],
        [0.28, 0.66, 0.12, '#7bb37a', '#4f8a5b'],
        [0.46, 0.26, 0.1, '#e3c34a', '#c89a2e'],
        [0.74, 0.56, 0.1, '#6fa8c4', '#4f86a8'],
      ];
      // stems + leaves first
      c.strokeStyle = '#5d7e4f'; c.lineWidth = s * 0.012; c.lineCap = 'round';
      flowers.forEach(([x, y]) => { c.beginPath(); c.moveTo(s * x, s * y); c.lineTo(s * 0.5, s * 0.8); c.stroke(); });
      c.fillStyle = '#6aa06a';
      [[0.42, 0.6, 0.7], [0.58, 0.7, -0.5], [0.5, 0.52, 0.2]].forEach(([x, y, r]) => {
        c.beginPath(); c.ellipse(s * x, s * y, s * 0.045, s * 0.13, r, 0, 7); c.fill();
      });
      // flower heads
      flowers.forEach(([x, y, r, p1, p2]) => {
        for (let i = 0; i < 8; i++) {
          const a = (i / 8) * Math.PI * 2;
          c.fillStyle = p1;
          c.beginPath(); c.ellipse(s * x + Math.cos(a) * s * r * 0.62, s * y + Math.sin(a) * s * r * 0.62, s * r * 0.42, s * r * 0.66, a, 0, 7); c.fill();
        }
        c.fillStyle = p2; c.beginPath(); c.arc(s * x, s * y, s * r * 0.46, 0, 7); c.fill();
        c.fillStyle = '#f4d06a'; c.beginPath(); c.arc(s * x, s * y, s * r * 0.22, 0, 7); c.fill();
      });
    },
    balloon(c, s) {
      const sky = c.createLinearGradient(0, 0, 0, s);
      sky.addColorStop(0, '#5fb4d8'); sky.addColorStop(0.6, '#bfe3ee'); sky.addColorStop(0.82, '#cfeae0'); sky.addColorStop(1, '#9ecb86');
      c.fillStyle = sky; c.fillRect(0, 0, s, s);
      c.fillStyle = '#fbf0cf'; c.beginPath(); c.arc(s * 0.82, s * 0.16, s * 0.07, 0, 7); c.fill();
      // clouds
      c.fillStyle = 'rgba(255,255,255,0.9)';
      [[0.22, 0.22, 0.07], [0.7, 0.4, 0.055], [0.42, 0.58, 0.05]].forEach(([x, y, r]) => {
        c.beginPath(); c.arc(s * x, s * y, s * r, 0, 7);
        c.arc(s * x + s * r, s * y + s * 0.008, s * r * 0.8, 0, 7);
        c.arc(s * x - s * r * 0.8, s * y + s * 0.008, s * r * 0.7, 0, 7); c.fill();
      });
      // three balloons
      const drawBalloon = (bx, by, br, cols) => {
        for (let i = 0; i < cols.length; i++) {
          c.fillStyle = cols[i];
          c.beginPath(); c.moveTo(bx, by);
          c.arc(bx, by, br, -Math.PI / 2 + i * (Math.PI * 2 / cols.length), -Math.PI / 2 + (i + 1) * (Math.PI * 2 / cols.length));
          c.closePath(); c.fill();
        }
        c.fillStyle = '#caa15a'; c.beginPath();
        c.moveTo(bx - br * 0.5, by + br * 0.92); c.lineTo(bx + br * 0.5, by + br * 0.92); c.lineTo(bx, by + br * 1.35); c.closePath(); c.fill();
        c.fillStyle = '#7a5230'; c.fillRect(bx - s * 0.025, by + br * 1.32, s * 0.05, s * 0.045);
      };
      drawBalloon(s * 0.4, s * 0.36, s * 0.16, ['#e35d6a', '#f3a64b', '#4f9d8b', '#5a6fb0', '#e8c14b']);
      drawBalloon(s * 0.72, s * 0.6, s * 0.1, ['#7b5ea8', '#e35d6a', '#4f9d8b', '#f3a64b']);
      drawBalloon(s * 0.2, s * 0.66, s * 0.085, ['#4f9d8b', '#5a6fb0', '#e8c14b', '#e35d6a']);
      // distant hills
      c.fillStyle = '#7fb06a'; c.beginPath(); c.moveTo(0, s); c.lineTo(0, s * 0.9);
      for (let x = 0; x <= s; x += s / 5) c.lineTo(x, s * 0.9 - Math.sin(x * 0.012) * s * 0.04);
      c.lineTo(s, s); c.closePath(); c.fill();
    },
    starry(c, s) { // homage to Van Gogh — The Starry Night
      const sky = c.createLinearGradient(0, 0, 0, s);
      sky.addColorStop(0, '#1b2f6b'); sky.addColorStop(0.5, '#23408f'); sky.addColorStop(1, '#142457');
      c.fillStyle = sky; c.fillRect(0, 0, s, s);
      // swirling concentric bands
      const cx = s * 0.6, cy = s * 0.4;
      for (let r = s * 0.34, k = 0; r > 5; r -= s * 0.05, k++) {
        c.beginPath(); c.arc(cx, cy, r, 0, 7);
        c.strokeStyle = k % 2 ? 'rgba(127,168,232,0.85)' : 'rgba(231,192,68,0.6)';
        c.lineWidth = s * 0.034; c.stroke();
      }
      c.fillStyle = 'rgba(231,192,68,0.3)'; c.beginPath(); c.arc(s * 0.81, s * 0.17, s * 0.11, 0, 7); c.fill();
      c.fillStyle = '#f4dd86'; c.beginPath(); c.arc(s * 0.81, s * 0.17, s * 0.06, 0, 7); c.fill();
      [[0.18, 0.16], [0.34, 0.3], [0.13, 0.5], [0.46, 0.13], [0.28, 0.6]].forEach(([x, y]) => {
        c.fillStyle = 'rgba(231,192,68,0.28)'; c.beginPath(); c.arc(s * x, s * y, s * 0.05, 0, 7); c.fill();
        c.fillStyle = '#f4dd86'; c.beginPath(); c.arc(s * x, s * y, s * 0.02, 0, 7); c.fill();
      });
      c.fillStyle = '#172a52'; c.fillRect(0, s * 0.78, s, s * 0.22);
      // cypress flame
      c.fillStyle = '#0f3a20'; c.beginPath();
      c.moveTo(s * 0.14, s); c.bezierCurveTo(s * 0.03, s * 0.58, s * 0.17, s * 0.5, s * 0.1, s * 0.3);
      c.bezierCurveTo(s * 0.24, s * 0.56, s * 0.21, s * 0.82, s * 0.2, s); c.closePath(); c.fill();
      // village
      c.fillStyle = '#26396a'; c.fillRect(s * 0.32, s * 0.8, s * 0.62, s * 0.13);
      for (let i = 0; i < 5; i++) { const x = s * (0.34 + i * 0.115); c.beginPath(); c.moveTo(x, s * 0.8); c.lineTo(x + s * 0.05, s * 0.74); c.lineTo(x + s * 0.1, s * 0.8); c.closePath(); c.fill(); }
      c.fillStyle = '#e7c044'; for (let i = 0; i < 5; i++) c.fillRect(s * (0.37 + i * 0.115), s * 0.84, s * 0.02, s * 0.035);
      // church spire
      c.fillStyle = '#1a2c52'; c.fillRect(s * 0.46, s * 0.66, s * 0.04, s * 0.16);
      c.beginPath(); c.moveTo(s * 0.45, s * 0.66); c.lineTo(s * 0.48, s * 0.58); c.lineTo(s * 0.51, s * 0.66); c.closePath(); c.fill();
    },
    wave(c, s) { // homage to Hokusai — The Great Wave off Kanagawa
      const sky = c.createLinearGradient(0, 0, 0, s * 0.6);
      sky.addColorStop(0, '#d8ceb2'); sky.addColorStop(1, '#f0e8d2');
      c.fillStyle = sky; c.fillRect(0, 0, s, s);
      c.fillStyle = '#efe0bd'; c.beginPath(); c.arc(s * 0.7, s * 0.22, s * 0.09, 0, 7); c.fill();
      // Mt Fuji
      c.fillStyle = '#37566f'; c.beginPath(); c.moveTo(s * 0.54, s * 0.62); c.lineTo(s * 0.74, s * 0.34); c.lineTo(s * 0.94, s * 0.62); c.closePath(); c.fill();
      c.fillStyle = '#f4f1e6'; c.beginPath(); c.moveTo(s * 0.74, s * 0.34); c.lineTo(s * 0.67, s * 0.44); c.lineTo(s * 0.71, s * 0.46); c.lineTo(s * 0.74, s * 0.41); c.lineTo(s * 0.77, s * 0.46); c.lineTo(s * 0.81, s * 0.44); c.closePath(); c.fill();
      // sea base
      c.fillStyle = '#1f4f78'; c.fillRect(0, s * 0.6, s, s * 0.4);
      // great wave
      c.fillStyle = '#173a5e'; c.beginPath();
      c.moveTo(0, s * 0.62);
      c.bezierCurveTo(s * 0.15, s * 0.33, s * 0.42, s * 0.28, s * 0.56, s * 0.5);
      c.bezierCurveTo(s * 0.42, s * 0.32, s * 0.52, s * 0.18, s * 0.64, s * 0.25);
      c.bezierCurveTo(s * 0.46, s * 0.27, s * 0.52, s * 0.56, s * 0.3, s * 0.55);
      c.bezierCurveTo(s * 0.4, s * 0.67, s * 0.18, s * 0.8, s * 0.05, s * 0.66);
      c.closePath(); c.fill();
      // inner curl
      c.fillStyle = '#2f6b94'; c.beginPath();
      c.moveTo(s * 0.1, s * 0.62); c.bezierCurveTo(s * 0.22, s * 0.45, s * 0.4, s * 0.42, s * 0.48, s * 0.54);
      c.bezierCurveTo(s * 0.36, s * 0.46, s * 0.3, s * 0.6, s * 0.18, s * 0.62); c.closePath(); c.fill();
      // foam fingers
      c.fillStyle = '#f4f1e6';
      [[0.14, 0.42, 0.045], [0.27, 0.34, 0.038], [0.4, 0.38, 0.042], [0.52, 0.46, 0.032], [0.62, 0.25, 0.03], [0.2, 0.5, 0.03]].forEach(([x, y, r]) => { c.beginPath(); c.arc(s * x, s * y, s * r, 0, 7); c.fill(); });
      // foreground swell
      c.fillStyle = '#102a44'; c.beginPath(); c.moveTo(0, s * 0.82);
      c.bezierCurveTo(s * 0.3, s * 0.72, s * 0.6, s * 0.84, s, s * 0.78); c.lineTo(s, s); c.lineTo(0, s); c.closePath(); c.fill();
    },
  };

  window.PBNEngine = { generate, makeSample, SAMPLES: Object.keys(SAMPLE_FNS) };
})();
