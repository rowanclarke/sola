// Wireframe primitives — clean, grayscale, Linear/Notion-ish
// All sizes assume a 360×780 phone canvas.

const WIRE = {
  ink: '#18181b',
  ink2: '#3f3f46',
  mid: '#71717a',
  mid2: '#a1a1aa',
  line: '#d4d4d8',
  line2: '#e4e4e7',
  bg: '#fafafa',
  card: '#ffffff',
  fill: '#f4f4f5',
  yellow: '#fde68a',
  yellowInk: '#854d0e',
  blue: '#dbeafe',
  blueInk: '#1e40af',
  font: '"Manrope", -apple-system, BlinkMacSystemFont, system-ui, sans-serif',
  mono: '"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace',
};

// inject fonts + base style once
if (typeof document !== 'undefined' && !document.getElementById('wire-styles')) {
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = 'https://fonts.googleapis.com/css2?family=Manrope:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap';
  document.head.appendChild(link);
  const s = document.createElement('style');
  s.id = 'wire-styles';
  s.textContent = `
    .w-phone *{box-sizing:border-box}
    .w-screen{position:absolute;inset:0;background:${WIRE.bg};font-family:${WIRE.font};color:${WIRE.ink};display:flex;flex-direction:column;overflow:hidden}
    .w-status{height:36px;display:flex;align-items:center;justify-content:space-between;padding:0 22px 0 24px;font-family:${WIRE.font};font-size:13px;font-weight:600;color:${WIRE.ink};flex-shrink:0}
    .w-status-r{display:flex;gap:5px;align-items:center}
    .w-home{position:absolute;bottom:7px;left:50%;transform:translateX(-50%);width:108px;height:4px;border-radius:99px;background:${WIRE.ink};opacity:.85;z-index:5}
    .w-stripe{background-image:repeating-linear-gradient(45deg,${WIRE.line2} 0 1px,transparent 1px 8px);background-color:${WIRE.fill}}
    .w-stripe-dark{background-image:repeating-linear-gradient(45deg,${WIRE.line} 0 1px,transparent 1px 8px);background-color:${WIRE.fill}}
    .w-btn{display:flex;align-items:center;justify-content:center;gap:6px;cursor:pointer;user-select:none;font-family:${WIRE.font};transition:background .12s,opacity .12s}
    .w-btn:active{opacity:.7}
    .w-tap{cursor:pointer;user-select:none;transition:background .1s}
    .w-tap:active{background:${WIRE.line2}}
    .w-mono{font-family:${WIRE.mono};font-variant-numeric:tabular-nums}
    .w-scroll{overflow-y:auto;overflow-x:hidden;flex:1;min-height:0}
    .w-scroll::-webkit-scrollbar{display:none}
    .w-scroll{scrollbar-width:none}
    .w-callout{font-family:${WIRE.mono};font-size:10px;letter-spacing:.02em;color:${WIRE.yellowInk};background:${WIRE.yellow};padding:2px 6px;border-radius:3px;text-transform:uppercase;font-weight:500;display:inline-block}
    .w-pill{display:inline-flex;align-items:center;gap:4px;font-family:${WIRE.mono};font-size:10px;padding:2px 7px;border-radius:99px;background:${WIRE.fill};color:${WIRE.mid};border:1px solid ${WIRE.line2}}
    .w-divider{height:1px;background:${WIRE.line2}}
    .w-divider-v{width:1px;background:${WIRE.line2}}
    .w-h1{font-size:28px;font-weight:700;letter-spacing:-0.02em;line-height:1.15;color:${WIRE.ink}}
    .w-h2{font-size:20px;font-weight:600;letter-spacing:-0.015em;color:${WIRE.ink}}
    .w-h3{font-size:15px;font-weight:600;letter-spacing:-0.01em;color:${WIRE.ink}}
    .w-body{font-size:14px;line-height:1.5;color:${WIRE.ink2}}
    .w-meta{font-size:12px;color:${WIRE.mid};font-family:${WIRE.font}}
    .w-anno{font-family:${WIRE.mono};font-size:10px;color:${WIRE.mid};letter-spacing:.02em;text-transform:uppercase;font-weight:500}
    .w-tab-active{color:${WIRE.ink} !important}
    .w-tab-active .w-tab-dot{background:${WIRE.ink} !important}
  `;
  document.head.appendChild(s);
}

// ─── Phone frame ───
function WirePhone({ width = 360, height = 780, children, label, style = {} }) {
  return (
    <div className="w-phone" style={{
      width, height,
      borderRadius: 38,
      background: '#1f1f23',
      padding: 8,
      position: 'relative',
      boxShadow: '0 1px 2px rgba(0,0,0,0.06), 0 8px 24px rgba(0,0,0,0.08)',
      ...style,
    }}>
      <div style={{
        position: 'absolute', inset: 8,
        borderRadius: 30,
        overflow: 'hidden',
        background: WIRE.bg,
      }}>
        {/* status bar */}
        <div className="w-status">
          <span>9:41</span>
          <div className="w-status-r">
            <svg width="16" height="10" viewBox="0 0 16 10"><rect x="0" y="6" width="2" height="4" rx="1" fill={WIRE.ink}/><rect x="4" y="4" width="2" height="6" rx="1" fill={WIRE.ink}/><rect x="8" y="2" width="2" height="8" rx="1" fill={WIRE.ink}/><rect x="12" y="0" width="2" height="10" rx="1" fill={WIRE.ink}/></svg>
            <svg width="20" height="10" viewBox="0 0 20 10"><rect x="0.5" y="0.5" width="16" height="9" rx="2.5" fill="none" stroke={WIRE.ink} strokeOpacity=".5"/><rect x="2" y="2" width="13" height="6" rx="1.5" fill={WIRE.ink}/><rect x="17" y="3.5" width="1.5" height="3" rx=".5" fill={WIRE.ink} fillOpacity=".5"/></svg>
          </div>
        </div>
        {/* screen content */}
        <div style={{ position: 'absolute', top: 36, left: 0, right: 0, bottom: 0 }}>
          {children}
        </div>
        {/* home indicator */}
        <div className="w-home" />
      </div>
      {label && (
        <div style={{
          position: 'absolute', top: -22, left: 4,
          fontFamily: WIRE.mono, fontSize: 11, color: WIRE.mid, letterSpacing: '.02em',
        }}>{label}</div>
      )}
    </div>
  );
}

// ─── Striped image placeholder ───
function WireStripe({ label, w, h, dark = false, style = {} }) {
  return (
    <div className={dark ? 'w-stripe-dark' : 'w-stripe'} style={{
      width: w, height: h,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid,
      border: `1px solid ${WIRE.line2}`,
      borderRadius: 4,
      ...style,
    }}>{label}</div>
  );
}

// ─── Generic box outlines ───
function WireBox({ children, p = 12, radius = 8, border = true, fill = WIRE.card, style = {}, onClick, className = '' }) {
  return (
    <div onClick={onClick} className={(onClick ? 'w-tap ' : '') + className} style={{
      padding: p,
      borderRadius: radius,
      border: border ? `1px solid ${WIRE.line2}` : 'none',
      background: fill,
      ...style,
    }}>{children}</div>
  );
}

// ─── Button (filled/outline) ───
function WireBtn({ children, kind = 'filled', size = 'md', disabled = false, onClick, style = {} }) {
  const h = size === 'sm' ? 32 : size === 'lg' ? 48 : 40;
  const fs = size === 'sm' ? 13 : size === 'lg' ? 15 : 14;
  const base = {
    height: h,
    borderRadius: h / 2,
    padding: `0 ${size === 'sm' ? 12 : 18}px`,
    fontSize: fs,
    fontWeight: 600,
    fontFamily: WIRE.font,
    letterSpacing: '-0.005em',
  };
  const s =
    kind === 'filled' ? { ...base, background: disabled ? WIRE.line : WIRE.ink, color: '#fff', border: 'none' }
    : kind === 'outline' ? { ...base, background: 'transparent', color: WIRE.ink, border: `1px solid ${WIRE.line}` }
    : kind === 'ghost' ? { ...base, background: 'transparent', color: WIRE.ink, border: 'none' }
    : base;
  return (
    <button className="w-btn" disabled={disabled} onClick={onClick} style={{
      ...s,
      opacity: disabled ? .4 : 1,
      cursor: disabled ? 'not-allowed' : 'pointer',
      ...style,
    }}>{children}</button>
  );
}

// ─── Tiny icon set (1.5px line) ───
const WireIcons = {
  search: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round"><circle cx="7" cy="7" r="5"/><path d="M11 11l3 3"/></svg>,
  book: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M3 2h5a2 2 0 0 1 2 2v10a1 1 0 0 0-1-1H3V2zM13 2H8a2 2 0 0 0-2 2v10a1 1 0 0 1 1-1h6V2z"/></svg>,
  settings: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round"><circle cx="8" cy="8" r="2"/><path d="M8 1v2M8 13v2M3.5 3.5l1.4 1.4M11.1 11.1l1.4 1.4M1 8h2M13 8h2M3.5 12.5l1.4-1.4M11.1 4.9l1.4-1.4"/></svg>,
  back: (s = 16, c = WIRE.ink) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round"><path d="M10 3l-5 5 5 5"/></svg>,
  chev: (s = 14, c = WIRE.mid) => <svg width={s} height={s} viewBox="0 0 14 14" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M5 2l5 5-5 5"/></svg>,
  chevD: (s = 14, c = WIRE.mid) => <svg width={s} height={s} viewBox="0 0 14 14" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M2 5l5 5 5-5"/></svg>,
  check: (s = 14, c = WIRE.ink) => <svg width={s} height={s} viewBox="0 0 14 14" fill="none" stroke={c} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M2.5 7l3 3 6-6"/></svg>,
  close: (s = 16, c = WIRE.ink) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round"><path d="M3 3l10 10M13 3L3 13"/></svg>,
  download: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M8 2v8m0 0l-3-3m3 3l3-3M3 12v2h10v-2"/></svg>,
  filter: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round"><path d="M2 4h12M4 8h8M6 12h4"/></svg>,
  more: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill={c}><circle cx="3.5" cy="8" r="1.3"/><circle cx="8" cy="8" r="1.3"/><circle cx="12.5" cy="8" r="1.3"/></svg>,
  globe: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5"><circle cx="8" cy="8" r="6"/><ellipse cx="8" cy="8" rx="2.5" ry="6"/><path d="M2 8h12"/></svg>,
  text: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round"><path d="M3 4h10M5 4v8M8 8h5M9.5 8v4"/></svg>,
  bug: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round"><rect x="5" y="5" width="6" height="8" rx="3"/><path d="M5 8H2M14 8h-3M5 11H3M13 11h-2M5 5l-1.5-1.5M11 5l1.5-1.5M8 3v2"/></svg>,
  send: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M14 2L7 9M14 2l-5 12-2-5-5-2 12-5z"/></svg>,
  highlight: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><path d="M3 12l3 1 7-7-4-4-7 7 1 3zM2 14h5"/></svg>,
  copy: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"><rect x="5" y="5" width="9" height="9" rx="1.5"/><path d="M11 5V3.5a1.5 1.5 0 0 0-1.5-1.5h-6A1.5 1.5 0 0 0 2 3.5v6A1.5 1.5 0 0 0 3.5 11H5"/></svg>,
  link: (s = 16, c = WIRE.ink2) => <svg width={s} height={s} viewBox="0 0 16 16" fill="none" stroke={c} strokeWidth="1.5" strokeLinecap="round"><path d="M6.5 9.5L9.5 6.5M5.5 10.5l-1 1a2.5 2.5 0 0 1-3.5-3.5l3-3a2.5 2.5 0 0 1 3.5 0M10.5 5.5l1-1a2.5 2.5 0 0 1 3.5 3.5l-3 3a2.5 2.5 0 0 1-3.5 0"/></svg>,
};

// ─── Bottom tab bar ───
function WireTabBar({ active, onTab }) {
  const tabs = [
    { id: 'search', label: 'Search', icon: WireIcons.search },
    { id: 'reader', label: 'Reader', icon: WireIcons.book },
    { id: 'settings', label: 'Settings', icon: WireIcons.settings },
  ];
  return (
    <div style={{
      flexShrink: 0,
      height: 64,
      borderTop: `1px solid ${WIRE.line2}`,
      background: WIRE.card,
      display: 'flex',
      paddingBottom: 12,
    }}>
      {tabs.map((t) => {
        const on = t.id === active;
        return (
          <div key={t.id} className="w-tap" onClick={() => onTab && onTab(t.id)} style={{
            flex: 1, display: 'flex', flexDirection: 'column',
            alignItems: 'center', justifyContent: 'center', gap: 3,
            color: on ? WIRE.ink : WIRE.mid,
          }}>
            {t.icon(20, on ? WIRE.ink : WIRE.mid)}
            <div style={{ fontSize: 10.5, fontWeight: on ? 600 : 500, fontFamily: WIRE.font }}>{t.label}</div>
          </div>
        );
      })}
    </div>
  );
}

Object.assign(window, { WIRE, WirePhone, WireStripe, WireBox, WireBtn, WireIcons, WireTabBar });
