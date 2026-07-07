// ui-kit.jsx — shared atoms for Numbra: icons, buttons, ring, sheet.
// Exports (to window): Icon, Btn, Ring, Sheet, Segmented

function Icon({ name, size = 24, stroke = 'currentColor', sw = 1.8, fill = 'none', style }) {
  const P = {
    back: <path d="M15 5l-7 7 7 7" />,
    close: <path d="M6 6l12 12M18 6L6 18" />,
    plus: <path d="M12 5v14M5 12h14" />,
    camera: <g><path d="M3 8.5A2.5 2.5 0 015.5 6h1.2l1-1.6A1.5 1.5 0 019 3.7h6a1.5 1.5 0 011.3.7l1 1.6h1.2A2.5 2.5 0 0121 8.5v9A2.5 2.5 0 0118.5 20h-13A2.5 2.5 0 013 17.5z" /><circle cx="12" cy="13" r="3.4" /></g>,
    image: <g><rect x="3" y="4.5" width="18" height="15" rx="2.6" /><circle cx="8.5" cy="9.5" r="1.7" /><path d="M4 17l5-4.5 4 3.3 3-2.6 4 3.4" /></g>,
    sparkle: <path d="M12 3l1.7 5.3L19 10l-5.3 1.7L12 17l-1.7-5.3L5 10l5.3-1.7z" />,
    share: <g><circle cx="6" cy="12" r="2.6" /><circle cx="17.5" cy="6" r="2.6" /><circle cx="17.5" cy="18" r="2.6" /><path d="M8.4 10.8l6.7-3.5M8.4 13.2l6.7 3.5" /></g>,
    check: <path d="M5 12.5l4.5 4.5L19 6.5" />,
    drop: <path d="M12 3.5s6 6.4 6 10.4a6 6 0 11-12 0c0-4 6-10.4 6-10.4z" />,
    brush: <g><path d="M15.5 4.5l4 4-7.2 7.2-4-4z" /><path d="M8.3 11.7l4 4-2 2c-1.2 1.2-4.5 1.8-5.6.7s-.5-4.4.7-5.6z" /></g>,
    tap: <g><path d="M9 11V5.5a1.8 1.8 0 013.6 0V11" /><path d="M12.6 11V8.4a1.7 1.7 0 013.4 0V12" /><path d="M16 10.2a1.7 1.7 0 013.4 0v3.6c0 3.4-2.3 6.2-6 6.2-2.3 0-3.7-.8-4.9-2.4l-3-4.2a1.7 1.7 0 012.7-2l1.8 2" /></g>,
    wand: <g><path d="M5 19l9-9" /><path d="M14.5 4.5l1 2 2 1-2 1-1 2-1-2-2-1 2-1z" /></g>,
    target: <g><circle cx="12" cy="12" r="8" /><circle cx="12" cy="12" r="3.2" /></g>,
    plusN: <path d="M12 6v12M6 12h12" />,
    minus: <path d="M6 12h12" />,
    fit: <path d="M4 9V5.5A1.5 1.5 0 015.5 4H9M15 4h3.5A1.5 1.5 0 0120 5.5V9M20 15v3.5a1.5 1.5 0 01-1.5 1.5H15M9 20H5.5A1.5 1.5 0 014 18.5V15" />,
    lock: <g><rect x="5" y="10.5" width="14" height="9.5" rx="2.2" /><path d="M8 10.5V8a4 4 0 018 0v2.5" /></g>,
    play: <path d="M8 5.5l11 6.5-11 6.5z" />,
    chevron: <path d="M9 6l6 6-6 6" />,
    grid: <g><rect x="4" y="4" width="7" height="7" rx="1.6" /><rect x="13" y="4" width="7" height="7" rx="1.6" /><rect x="4" y="13" width="7" height="7" rx="1.6" /><rect x="13" y="13" width="7" height="7" rx="1.6" /></g>,
    palette: <g><path d="M12 3.5c-4.7 0-8.5 3.6-8.5 8 0 3 2 4.8 4.4 4.8 1.6 0 2.1-1 2.1-1.9 0-1.4-1.2-1.6-1.2-2.8 0-.9.8-1.6 1.9-1.6h2.1c3 0 5.7-2 5.7-5C18.5 5.9 15.6 3.5 12 3.5z" /><circle cx="8" cy="9" r="1" fill={stroke} /><circle cx="12" cy="7.2" r="1" fill={stroke} /><circle cx="15.6" cy="9" r="1" fill={stroke} /></g>,
    star: <path d="M12 3.5l2.6 5.5 6 .7-4.4 4.1 1.2 5.9L12 16.9 6.6 19.7l1.2-5.9L3.4 9.7l6-.7z" />,
    clock: <g><circle cx="12" cy="12" r="8.2" /><path d="M12 7.5V12l3 2" /></g>,
    undo: <path d="M9 7L4.5 11.5 9 16M4.5 11.5H14a5 5 0 015 5v1" />,
    sound: <g><path d="M4 9.5h3l5-4v13l-5-4H4z" /><path d="M16 8.5a5 5 0 010 7M18.5 6a8 8 0 010 12" /></g>,
    mute: <g><path d="M4 9.5h3l5-4v13l-5-4H4z" /><path d="M16.5 9.5l5 5M21.5 9.5l-5 5" /></g>,
  };
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={stroke}
      strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" style={style}>
      {P[name]}
    </svg>
  );
}

function Btn({ children, onClick, variant = 'primary', size = 'md', icon, style, disabled }) {
  const base = {
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 9,
    fontFamily: 'var(--ui)', fontWeight: 700, border: 'none', cursor: disabled ? 'default' : 'pointer',
    borderRadius: 999, transition: 'transform .12s ease, filter .15s ease, background .15s ease',
    letterSpacing: '-0.01em', whiteSpace: 'nowrap', opacity: disabled ? 0.45 : 1,
  };
  const sizes = {
    sm: { padding: '9px 16px', fontSize: 14 },
    md: { padding: '13px 22px', fontSize: 15.5 },
    lg: { padding: '17px 26px', fontSize: 17 },
  };
  const variants = {
    primary: { background: 'var(--terra)', color: '#fff', boxShadow: '0 6px 18px rgba(224,73,47,0.34)' },
    dark: { background: 'var(--ink)', color: 'var(--paper)' },
    ghost: { background: 'transparent', color: 'var(--ink)' },
    soft: { background: 'var(--card-2)', color: 'var(--ink)' },
    sage: { background: 'var(--sage)', color: '#fff', boxShadow: '0 6px 18px rgba(30,138,120,0.32)' },
  };
  return (
    <button onClick={disabled ? undefined : onClick}
      onPointerDown={(e) => !disabled && (e.currentTarget.style.transform = 'scale(0.96)')}
      onPointerUp={(e) => (e.currentTarget.style.transform = '')}
      onPointerLeave={(e) => (e.currentTarget.style.transform = '')}
      style={{ ...base, ...sizes[size], ...variants[variant], ...style }}>
      {icon && <Icon name={icon} size={size === 'lg' ? 21 : 18} sw={2} />}
      {children}
    </button>
  );
}

function Ring({ value = 0, size = 40, sw = 4, track = 'rgba(0,0,0,0.08)', color = 'var(--terra)', children }) {
  const r = (size - sw) / 2, C = 2 * Math.PI * r;
  return (
    <div style={{ position: 'relative', width: size, height: size, display: 'inline-flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg width={size} height={size} style={{ transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={track} strokeWidth={sw} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} strokeWidth={sw}
          strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - value)}
          style={{ transition: 'stroke-dashoffset .4s ease' }} />
      </svg>
      {children && <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{children}</div>}
    </div>
  );
}

function Sheet({ open, onClose, children, dark }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 80, pointerEvents: open ? 'auto' : 'none',
    }}>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(30,24,18,0.42)',
        backdropFilter: 'blur(2px)', opacity: open ? 1 : 0, transition: 'opacity .3s ease',
      }} />
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: dark ? '#1d1b18' : 'var(--card)', borderRadius: '30px 30px 0 0',
        padding: '12px 22px calc(28px + env(safe-area-inset-bottom))',
        transform: open ? 'translateY(0)' : 'translateY(105%)',
        transition: 'transform .42s cubic-bezier(.22,1,.36,1)',
        boxShadow: '0 -16px 50px rgba(0,0,0,0.22)',
      }}>
        <div style={{ width: 40, height: 5, borderRadius: 99, background: 'rgba(0,0,0,0.14)', margin: '0 auto 14px' }} />
        {children}
      </div>
    </div>
  );
}

function Segmented({ options, value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 4, background: 'var(--card-2)', borderRadius: 999, padding: 4 }}>
      {options.map((o) => {
        const active = o.value === value;
        return (
          <button key={o.value} onClick={() => onChange(o.value)} style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 7,
            border: 'none', cursor: 'pointer', borderRadius: 999, padding: '10px 8px',
            fontFamily: 'var(--ui)', fontWeight: 700, fontSize: 14, letterSpacing: '-0.01em',
            background: active ? 'var(--card)' : 'transparent',
            color: active ? 'var(--ink)' : 'var(--muted)',
            boxShadow: active ? '0 2px 8px rgba(0,0,0,0.1)' : 'none',
            transition: 'all .18s ease',
          }}>
            {o.icon && <Icon name={o.icon} size={17} sw={2} />}{o.label}
          </button>
        );
      })}
    </div>
  );
}

Object.assign(window, { Icon, Btn, Ring, Sheet, Segmented });
