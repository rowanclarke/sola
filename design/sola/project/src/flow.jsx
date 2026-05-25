// FlowMap — bird's-eye view with arrows connecting all screens.
// Renders mini phones at small scale + SVG arrows between them.

function MiniPhone({ scale = 0.5, label, accent, children, x, y }) {
  const w = 360, h = 780;
  return (
    <div style={{
      position: 'absolute', left: x, top: y,
      width: w * scale, height: h * scale,
      pointerEvents: 'none',
    }}>
      {accent && (
        <div style={{
          position: 'absolute', top: -22, left: 0,
          display: 'flex', alignItems: 'center', gap: 6,
        }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: accent }}/>
          <div style={{ fontFamily: WIRE.mono, fontSize: 11, fontWeight: 600, color: WIRE.ink }}>{label}</div>
        </div>
      )}
      <div style={{
        transform: `scale(${scale})`,
        transformOrigin: 'top left',
        width: w, height: h,
      }}>
        <WirePhone width={w} height={h}>
          {children}
        </WirePhone>
      </div>
    </div>
  );
}

function Arrow({ from, to, curve = 0, label, dashed = false }) {
  const [x1, y1] = from;
  const [x2, y2] = to;
  const dx = x2 - x1, dy = y2 - y1;
  const len = Math.hypot(dx, dy);
  const mx = (x1 + x2) / 2 + (dy / len) * curve;
  const my = (y1 + y2) / 2 - (dx / len) * curve;
  const d = `M${x1},${y1} Q${mx},${my} ${x2},${y2}`;
  return (
    <g>
      <path d={d} fill="none" stroke={WIRE.ink} strokeWidth="1.5" strokeDasharray={dashed ? '4 4' : ''} markerEnd="url(#arrow)"/>
      {label && (
        <g transform={`translate(${mx},${my})`}>
          <rect x={-(label.length * 3.4)} y={-9} width={label.length * 6.8} height={18} rx={9} fill={WIRE.bg} stroke={WIRE.line2}/>
          <text x={0} y={4} fontSize="10" fontFamily={WIRE.mono} fill={WIRE.ink2} fontWeight={500} textAnchor="middle">{label}</text>
        </g>
      )}
    </g>
  );
}

function FlowMap() {
  const W = 2200, H = 1280;
  const s = 0.42;
  const pw = 360 * s, ph = 780 * s;

  const positions = {
    lang:     { x: 80, y: 100,  label: '1 · Language',    accent: '#a78bfa' },
    trans:    { x: 320, y: 100, label: '2 · Translation', accent: '#a78bfa' },
    done:     { x: 560, y: 100, label: '3 · Complete',    accent: '#a78bfa' },
    reader:   { x: 880, y: 460, label: 'Reader (home)',    accent: WIRE.ink },
    search:   { x: 1180, y: 460, label: 'Search overlay',  accent: WIRE.ink },
    settings: { x: 1480, y: 460, label: 'Settings overlay', accent: WIRE.ink },
    sheet:    { x: 1780, y: 460, label: 'Translation picker (re-used)', accent: '#f59e0b' },
  };

  // Convenience: bottom-center & top-center of each phone
  const port = (id, side) => {
    const p = positions[id];
    if (side === 'bot') return [p.x + pw / 2, p.y + ph];
    if (side === 'top') return [p.x + pw / 2, p.y];
    if (side === 'right') return [p.x + pw, p.y + ph / 2];
    if (side === 'left') return [p.x, p.y + ph / 2];
    return [p.x + pw / 2, p.y + ph / 2];
  };

  const dummyCtx = { lang: 'en', trans: 'ESV', onTab: () => {}, onChange: () => {}, setLang: () => {}, setTrans: () => {} };

  return (
    <div style={{ position: 'relative', width: W, height: H, background: '#f7f7f6' }}>
      {/* grid bg */}
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: `radial-gradient(${WIRE.line2} 1px, transparent 1px)`,
        backgroundSize: '24px 24px',
        opacity: .5,
      }}/>

      {/* title */}
      <div style={{ position: 'absolute', top: 32, left: 60 }}>
        <div className="w-h1" style={{ fontSize: 32 }}>End-to-end flow</div>
        <div className="w-meta" style={{ marginTop: 4 }}>
          Three onboarding steps → reader is the home, with search &amp; settings as overlays. The translation picker is the same component everywhere.
        </div>
      </div>

      {/* sections */}
      <div style={{ position: 'absolute', top: 80, left: 60, fontFamily: WIRE.mono, fontSize: 11, fontWeight: 600, color: '#7c3aed', letterSpacing: '.05em', textTransform: 'uppercase' }}>First launch</div>
      <div style={{ position: 'absolute', top: 440, left: 60, fontFamily: WIRE.mono, fontSize: 11, fontWeight: 600, color: WIRE.ink, letterSpacing: '.05em', textTransform: 'uppercase' }}>Main app</div>

      {/* hint dotted lines */}
      <div style={{ position: 'absolute', top: 88, left: 56, right: 60, height: 1, borderTop: `1px dashed #c4b5fd` }}/>
      <div style={{ position: 'absolute', top: 448, left: 56, right: 60, height: 1, borderTop: `1px dashed ${WIRE.line2}` }}/>

      {/* SVG layer for arrows */}
      <svg width={W} height={H} style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}>
        <defs>
          <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto">
            <path d="M0,0 L10,5 L0,10 z" fill={WIRE.ink}/>
          </marker>
        </defs>
        {/* onboarding row */}
        <Arrow from={[positions.lang.x + pw, positions.lang.y + ph/2]} to={[positions.trans.x, positions.trans.y + ph/2]} label="Continue"/>
        <Arrow from={[positions.trans.x + pw, positions.trans.y + ph/2]} to={[positions.done.x, positions.done.y + ph/2]} label="Continue"/>
        {/* done → reader */}
        <Arrow from={[positions.done.x + pw/2, positions.done.y + ph]} to={[positions.reader.x + pw/2, positions.reader.y]} curve={-30} label="Start reading"/>
        {/* reader → search (overlay) */}
        <Arrow from={[positions.reader.x + pw, positions.reader.y + ph/2 - 8]} to={[positions.search.x, positions.search.y + ph/2 - 8]} label="🔍 icon"/>
        <Arrow from={[positions.search.x, positions.search.y + ph/2 + 8]} to={[positions.reader.x + pw, positions.reader.y + ph/2 + 8]} label="Close"/>
        {/* reader → settings (overlay) — long curve over the search frame */}
        <Arrow from={[positions.reader.x + pw/2, positions.reader.y + ph]} to={[positions.settings.x + pw/2, positions.settings.y + ph]} curve={140} label="⚙ icon"/>
        {/* settings → picker sheet */}
        <Arrow from={[positions.settings.x + pw, positions.settings.y + ph/2 - 8]} to={[positions.sheet.x, positions.sheet.y + ph/2 - 8]} label="Change translation"/>
        <Arrow from={[positions.sheet.x, positions.sheet.y + ph/2 + 8]} to={[positions.settings.x + pw, positions.settings.y + ph/2 + 8]} label="Use NIV"/>
        {/* step2 onboarding -> sheet reuse arrow */}
        <Arrow from={[positions.trans.x + pw/2, positions.trans.y + ph]} to={[positions.sheet.x + pw/2, positions.sheet.y]} curve={180} dashed label="Same component"/>
        {/* book scrubber callout pointing to reader */}
        <Arrow from={[positions.reader.x - 40, positions.reader.y + ph - 30]} to={[positions.reader.x, positions.reader.y + ph - 30]} label="Scrubber: navigate across books"/>
      </svg>

      {/* phones */}
      <MiniPhone scale={s} {...positions.lang}>
        <LanguageScreen ctx={{ ...dummyCtx, lang: 'en', onContinue: () => {} }}/>
      </MiniPhone>
      <MiniPhone scale={s} {...positions.trans}>
        <TranslationStep2Host ctx={{ ...dummyCtx, trans: 'ESV', onContinue: () => {} }} onClose={() => {}}/>
      </MiniPhone>
      <MiniPhone scale={s} {...positions.done}>
        <CompleteScreen ctx={{ ...dummyCtx, trans: 'ESV', onContinue: () => {}, onChange: () => {} }}/>
      </MiniPhone>
      <MiniPhone scale={s} {...positions.reader}>
        <ReaderScreen ctx={dummyCtx}/>
      </MiniPhone>
      <MiniPhone scale={s} {...positions.search}>
        <SearchScreen ctx={dummyCtx}/>
      </MiniPhone>
      <MiniPhone scale={s} {...positions.settings}>
        <SettingsScreen ctx={dummyCtx}/>
      </MiniPhone>
      <MiniPhone scale={s} {...positions.sheet}>
        <div className="w-screen" style={{ background: WIRE.fill }}>
          <SettingsScreen ctx={dummyCtx}/>
          <TranslationPicker ctx={dummyCtx} onClose={() => {}} mode="settings"/>
        </div>
      </MiniPhone>

      {/* legend */}
      <div style={{ position: 'absolute', bottom: 32, left: 60, display: 'flex', gap: 24, alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 24, height: 1.5, background: WIRE.ink, position: 'relative' }}>
            <div style={{ position: 'absolute', right: -2, top: -3, width: 0, height: 0, borderLeft: `6px solid ${WIRE.ink}`, borderTop: '3px solid transparent', borderBottom: '3px solid transparent' }}/>
          </div>
          <span className="w-meta" style={{ fontSize: 11 }}>User action</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 24, height: 1.5, background: 'transparent', borderTop: `1.5px dashed ${WIRE.ink}` }}/>
          <span className="w-meta" style={{ fontSize: 11 }}>Component reuse</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: '#a78bfa' }}/>
          <span className="w-meta" style={{ fontSize: 11 }}>First launch (once)</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{ width: 8, height: 8, borderRadius: 4, background: '#f59e0b' }}/>
          <span className="w-meta" style={{ fontSize: 11 }}>Re-usable component</span>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { FlowMap, MiniPhone });
