// Main canvas — composes the design exploration.

const PHONE_W = 360;
const PHONE_H = 780;
const FRAME_W = PHONE_W + 20;   // includes phone bezel
const FRAME_H = PHONE_H + 20;

function PhoneCard({ children }) {
  // Just the phone, no extra wrapper
  return (
    <div style={{
      width: FRAME_W, height: FRAME_H,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      background: '#fff',
    }}>
      <WirePhone width={PHONE_W} height={PHONE_H}>
        {children}
      </WirePhone>
    </div>
  );
}

// Used for narrowed-down isolated demos.
function DummyCtx(extra = {}) {
  return {
    lang: 'en', trans: 'ESV',
    setLang: () => {}, setTrans: () => {},
    onTab: () => {}, onChange: () => {}, onContinue: () => {},
    ...extra,
  };
}

function App() {
  return (
    <DesignCanvas>
      {/* ─────────── Windowed scrubber + edge auto-scroll ─────────── */}
      <DCSection
        id="scrubber-w"
        title="Windowed scrubber · edge auto-scroll  ·  PRIMARY"
        subtitle="Resting state shows only the current Book · Chapter. On press-hold the strip rises up to the finger and a window of 20 chapters appears. Drag toward the edges to auto-scroll — closer to the edge = faster (200 / 80 / 30 / 8 ch·s; 400 past the edge).">
        <DCArtboard id="scw-rest" label="1 · Resting (label only)" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberWindowedDemo state="rest"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="scw-active" label="2 · Active · 1:1 position" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberWindowedDemo state="active"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="scw-near" label="3 · Near edge · 30 ch/s →" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberWindowedDemo state="near"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="scw-edge" label="4 · Past edge · 400 ch/s ←" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberWindowedDemo state="edge"/>
          </PhoneCard>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Book scrubber states (variable-speed) ─────────── */}
      <DCSection
        id="scrubber"
        title="Variable-speed scrubber · alternative"
        subtitle="All 1,189 chapters compressed into the strip; press-hold then drag away vertically to fine-tune. Apple Books / iOS Music pattern. Kept here for comparison — less precise than the windowed approach above.">
        <DCArtboard id="sc-rest" label="1 · Resting" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberDemo state="rest"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="sc-active" label="2 · Active · full speed" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberDemo state="active"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="sc-precision" label="3 · Variable speed · 25%" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <ScrubberDemo state="precision"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="sc-anatomy" label="4 · Anatomy" width={520} height={FRAME_H}>
          <ScrubberAnatomy/>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Click-through prototype ─────────── */}
      <DCSection
        id="prototype"
        title="Click-through prototype"
        subtitle="Tap through the full first-launch flow → main app. Click ↻ reset to start over.">
        <DCArtboard id="proto" label="Live prototype" width={FRAME_W} height={FRAME_H + 40}>
          <div style={{
            width: FRAME_W, height: FRAME_H + 40,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            paddingTop: 30,
            background: '#fff',
          }}>
            <div style={{ position: 'relative' }}>
              <WirePhone width={PHONE_W} height={PHONE_H}>
                <Prototype />
              </WirePhone>
            </div>
          </div>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Onboarding variations ─────────── */}
      <DCSection
        id="onboarding"
        title="Onboarding approaches"
        subtitle="Three ways to handle the first-launch language → translation → done sequence.">
        <DCArtboard id="ob-classic" label="A · Classic list (recommended)" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <OnboardingPreview variant="default"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="ob-grid" label="B · Native-name grid" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <OnboardingPreview variant="grid"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="ob-detect" label="C · Auto-detect + confirm" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <OnboardingDetectPreview/>
          </PhoneCard>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Translation picker (used everywhere) ─────────── */}
      <DCSection
        id="picker"
        title="Translation picker · unified component"
        subtitle="Same sheet used in onboarding step 2 AND when changing translation from Settings. Bottom sheet, 96% height, rounded top corners — keeps the host screen visible above so the user understands context.">
        <DCArtboard id="pk-onb" label="From onboarding" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <TranslationStep2Host ctx={DummyCtx({ trans: 'ESV' })} onClose={() => {}}/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="pk-set" label="From settings" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SettingsHostWithPicker/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="pk-empty" label="Empty state (rare language)" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <EmptyLangHost/>
          </PhoneCard>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Search results layouts ─────────── */}
      <DCSection
        id="search"
        title="Search result layouts"
        subtitle="Three ways to organize exact, related, and cross-language matches. The yellow banner explains any auto-expanded search consistently across all three.">
        <DCArtboard id="se-grouped" label="A · Grouped sections" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SearchScreen ctx={DummyCtx()} variant="grouped"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="se-tabs" label="B · Tabbed by match type" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SearchScreen ctx={DummyCtx()} variant="tabs"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="se-unified" label="C · Unified ranked list" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SearchScreen ctx={DummyCtx()} variant="unified"/>
          </PhoneCard>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Settings variations ─────────── */}
      <DCSection
        id="settings"
        title="Settings organization"
        subtitle="Same content, three layouts. All open the same translation picker from §3.">
        <DCArtboard id="se-list" label="A · iOS-style grouped lists" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SettingsScreen ctx={DummyCtx()} variant="list"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="se-cards" label="B · Card stack" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SettingsScreen ctx={DummyCtx()} variant="cards"/>
          </PhoneCard>
        </DCArtboard>
        <DCArtboard id="se-tab" label="C · Top tabs" width={FRAME_W} height={FRAME_H}>
          <PhoneCard>
            <SettingsScreen ctx={DummyCtx()} variant="tabbed"/>
          </PhoneCard>
        </DCArtboard>
      </DCSection>

      {/* ─────────── Flow map ─────────── */}
      <DCSection
        id="flow"
        title="Screen flow map"
        subtitle="Every screen and how they connect. The translation picker is reused across onboarding and settings — same component, two entry points.">
        <DCArtboard id="flow-map" label="All screens · arrows" width={2200} height={1280}>
          <FlowMap/>
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

// ─── Onboarding variation previews ───
function OnboardingPreview({ variant }) {
  const [lang, setLang] = React.useState('en');
  return <LanguageScreen ctx={DummyCtx({ lang, setLang })} variant={variant}/>;
}

// Variant C: auto-detect with confirm
function OnboardingDetectPreview() {
  return (
    <div className="w-screen">
      <div style={{ flexShrink: 0, padding: '14px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid, letterSpacing: '.05em' }}>STEP 1 OF 3</div>
        <div style={{ display: 'flex', gap: 5 }}>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.line }}/>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.line }}/>
        </div>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '0 24px', gap: 18 }}>
        <div>
          <div className="w-h1">Welcome to Sola</div>
          <div className="w-body" style={{ marginTop: 8 }}>We detected your device language. You can change this anytime.</div>
        </div>
        <WireBox p={16} radius={14} style={{ background: WIRE.card }}>
          <div className="w-anno" style={{ marginBottom: 8 }}>Detected</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 36, height: 36, borderRadius: 8, background: WIRE.ink, color: '#fff', fontFamily: WIRE.mono, fontWeight: 700, fontSize: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>EN</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 600 }}>English</div>
              <div className="w-meta" style={{ fontSize: 11.5, marginTop: 2 }}>23 translations available</div>
            </div>
            <div style={{ width: 24, height: 24, borderRadius: 12, background: WIRE.ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {WireIcons.check(14, '#fff')}
            </div>
          </div>
        </WireBox>
        <div className="w-tap" style={{
          padding: '12px 14px',
          border: `1px dashed ${WIRE.line}`,
          borderRadius: 10,
          display: 'flex', alignItems: 'center', gap: 10,
          color: WIRE.ink2, fontSize: 13,
        }}>
          {WireIcons.globe(15, WIRE.ink2)}
          <span style={{ flex: 1 }}>Choose a different language</span>
          {WireIcons.chev(12, WIRE.mid)}
        </div>
      </div>
      <div style={{ flexShrink: 0, padding: '12px 20px 24px' }}>
        <WireBtn size="lg" style={{ width: '100%' }}>Continue in English</WireBtn>
      </div>
    </div>
  );
}

// Settings + picker open
function SettingsHostWithPicker() {
  return (
    <div className="w-screen">
      <SettingsScreen ctx={DummyCtx()}/>
      <TranslationPicker ctx={DummyCtx({ trans: 'NIV' })} onClose={() => {}} mode="settings"/>
    </div>
  );
}

// Empty-state demo: language with no native translations
function EmptyLangHost() {
  return (
    <div className="w-screen" style={{ background: WIRE.fill }}>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div className="w-meta">Settings</div>
      </div>
      <div onClick={(e) => e.stopPropagation()} style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        height: 'calc(100% - 28px)',
        background: WIRE.bg,
        borderRadius: '20px 20px 0 0',
        display: 'flex', flexDirection: 'column', overflow: 'hidden',
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', padding: '8px 0 0' }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: WIRE.line }}/>
        </div>
        <div style={{ padding: '12px 20px 14px' }}>
          <div className="w-h2">Choose a translation</div>
          <div style={{ fontSize: 12, color: WIRE.mid, marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
            {WireIcons.globe(12, WIRE.mid)}
            <span>Kiswahili · Swahili</span>
          </div>
        </div>
        <div style={{ padding: '0 20px 12px' }}>
          <WireSearchField placeholder="Search translations…"/>
        </div>

        {/* the missing state */}
        <div style={{ padding: '8px 20px', display: 'flex', flexDirection: 'column', gap: 12 }}>
          <div style={{
            padding: 16,
            background: WIRE.fill,
            border: `1px dashed ${WIRE.line}`,
            borderRadius: 10,
            textAlign: 'center',
          }}>
            <div className="w-anno" style={{ color: WIRE.mid }}>No matches in Kiswahili</div>
            <div style={{ fontSize: 13, color: WIRE.ink2, marginTop: 6, lineHeight: 1.45 }}>
              We don't have any Swahili translations yet. Try a related language below, or browse all.
            </div>
          </div>
          <div className="w-anno" style={{ paddingLeft: 4 }}>Closest matches</div>
        </div>

        <div className="w-scroll" style={{ padding: '0 20px' }}>
          {[
            { lang: 'English', code: 'EN', why: 'Most translations', count: 23 },
            { lang: 'French',  code: 'FR', why: 'Regional · East Africa', count: 9 },
            { lang: 'Arabic',  code: 'AR', why: 'Regional · East Africa', count: 5 },
          ].map((row) => (
            <div key={row.code} className="w-tap" style={{
              display: 'flex', alignItems: 'center', gap: 12,
              padding: '12px 0',
              borderBottom: `1px solid ${WIRE.line2}`,
            }}>
              <div style={{
                width: 40, height: 40, borderRadius: 9,
                background: WIRE.card, border: `1px solid ${WIRE.line2}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontFamily: WIRE.mono, fontSize: 12, fontWeight: 600, color: WIRE.ink2,
              }}>{row.code}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 14, fontWeight: 600 }}>{row.lang}</div>
                <div style={{ fontSize: 11.5, color: WIRE.mid, marginTop: 2 }}>{row.why} · <span className="w-mono">{row.count} translations</span></div>
              </div>
              {WireIcons.chev(12, WIRE.mid)}
            </div>
          ))}
          <div style={{ padding: '16px 0 24px' }}>
            <WireBtn kind="outline" size="md" style={{ width: '100%' }}>Browse all 140 languages</WireBtn>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Scrubber demos for the canvas ───
function ScrubberDemo({ state }) {
  // Lightweight static reader behind a Scrubber pinned to a state.
  const idx = bookToIndex('John', 3);
  const info = chapterToInfo(idx);
  const mockActive = state === 'active' || state === 'precision';
  const mockPrecision = state === 'precision' ? 0.25 : 1;
  return (
    <div className="w-screen">
      {/* mini reader header */}
      <div style={{ flexShrink: 0, padding: '10px 14px 12px', borderBottom: `1px solid ${WIRE.line2}`, background: WIRE.bg }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '7px 12px', background: WIRE.fill, borderRadius: 8, border: `1px solid ${WIRE.line2}`,
          }}>
            <div style={{ fontSize: 14, fontWeight: 600 }}>{info.book.name} {info.chapter}</div>
            {WireIcons.chevD(12, WIRE.mid)}
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 4,
            padding: '7px 10px', background: WIRE.fill, borderRadius: 8, border: `1px solid ${WIRE.line2}`,
            fontFamily: WIRE.mono, fontSize: 12, fontWeight: 600,
          }}>ESV {WireIcons.chevD(11, WIRE.mid)}</div>
          <div style={{ width: 34, height: 34, borderRadius: 8, border: `1px solid ${WIRE.line2}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{WireIcons.search(15, WIRE.ink2)}</div>
          <div style={{ width: 34, height: 34, borderRadius: 8, border: `1px solid ${WIRE.line2}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{WireIcons.settings(15, WIRE.ink2)}</div>
        </div>
      </div>

      {/* mini body */}
      <div className="w-scroll" style={{ background: WIRE.card, opacity: mockActive ? 0.55 : 1, transition: 'opacity .15s' }}>
        <div style={{ padding: '20px 22px 8px' }}>
          <div className="w-anno" style={{ color: WIRE.mid, marginBottom: 4 }}>The Gospel According to John</div>
          <div className="w-h1" style={{ fontSize: 24, marginBottom: 4 }}>Chapter 3</div>
          <div className="w-meta">For God So Loved the World</div>
        </div>
        <div style={{ padding: '4px 22px 40px', fontSize: 15.5, lineHeight: 1.65, color: WIRE.ink }}>
          <sup style={{ fontFamily: WIRE.mono, fontSize: 9.5, fontWeight: 600, color: WIRE.mid, marginRight: 3 }}>16</sup>
          <mark style={{ background: WIRE.yellow, color: WIRE.ink, padding: '0 1px' }}>For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.</mark>{' '}
          <sup style={{ fontFamily: WIRE.mono, fontSize: 9.5, fontWeight: 600, color: WIRE.mid, marginRight: 3 }}>17</sup>
          For God did not send his Son into the world to condemn the world, but in order that the world might be saved through him.{' '}
          <sup style={{ fontFamily: WIRE.mono, fontSize: 9.5, fontWeight: 600, color: WIRE.mid, marginRight: 3 }}>18</sup>
          Whoever believes in him is not condemned…
        </div>
      </div>

      <Scrubber
        initialIndex={idx}
        mockActive={mockActive}
        mockPrecision={mockPrecision}
      />
    </div>
  );
}

// ─── Scrubber anatomy diagram ───
function ScrubberAnatomy() {
  // Annotated diagram with callouts pointing to scrubber parts.
  const annot = {
    fontFamily: WIRE.mono, fontSize: 10.5, color: WIRE.ink, letterSpacing: '.01em',
  };
  const meta = { fontFamily: WIRE.font, fontSize: 11, color: WIRE.mid, lineHeight: 1.4 };
  return (
    <div style={{ width: 520, height: 800, background: '#fbfbfa', position: 'relative', padding: '24px 28px', fontFamily: WIRE.font }}>
      <div className="w-anno" style={{ color: WIRE.mid, marginBottom: 6 }}>Anatomy</div>
      <div className="w-h2" style={{ marginBottom: 4 }}>Book scrubber, dissected</div>
      <div style={{ fontSize: 12, color: WIRE.mid, lineHeight: 1.4, marginBottom: 18, maxWidth: 380 }}>
        Two visual states. Same component. Annotated below.
      </div>

      {/* RESTING state */}
      <div style={{ marginBottom: 14, fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid, letterSpacing: '.05em', textTransform: 'uppercase' }}>1 · Resting</div>
      <div style={{ background: WIRE.bg, border: `1px solid ${WIRE.line2}`, borderRadius: 12, padding: 16, marginBottom: 24, position: 'relative' }}>
        <Scrubber mockActive={false}/>
        {/* annotations */}
        <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }} width="100%" height="100%">
          <path d="M 220 6 L 220 36" stroke={WIRE.ink} strokeWidth="1" fill="none"/>
          <path d="M 380 70 L 340 70" stroke={WIRE.ink} strokeWidth="1" fill="none" markerEnd="url(#aa)"/>
          <defs>
            <marker id="aa" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto">
              <path d="M0,0 L10,5 L0,10 z" fill={WIRE.ink}/>
            </marker>
          </defs>
        </svg>
      </div>

      {/* ACTIVE state */}
      <div style={{ marginBottom: 14, fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid, letterSpacing: '.05em', textTransform: 'uppercase' }}>2 · Active</div>
      <div style={{ background: WIRE.bg, border: `1px solid ${WIRE.line2}`, borderRadius: 12, padding: '90px 16px 16px', position: 'relative' }}>
        <Scrubber mockActive={true} mockPrecision={0.5}/>
      </div>

      {/* Notes */}
      <div style={{ marginTop: 24, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
        <div>
          <div style={annot}>HOLD &gt; 180MS</div>
          <div style={meta}>Activates scrub mode. Shorter taps fall through to verse selection.</div>
        </div>
        <div>
          <div style={annot}>DRAG X</div>
          <div style={meta}>Maps absolute finger position to chapter index across 1,189 chapters.</div>
        </div>
        <div>
          <div style={annot}>DRAG Y (UP)</div>
          <div style={meta}>Reduces gain. 1× near strip → 0.5× → 0.25× → 0.1× for fine targeting.</div>
        </div>
        <div>
          <div style={annot}>RELEASE</div>
          <div style={meta}>Commits position. Reader jumps; can be cancelled by dragging off-strip.</div>
        </div>
      </div>
    </div>
  );
}

// ─── Windowed-scrubber demos for the canvas ───
function ScrubberWindowedDemo({ state }) {
  // state: 'rest' | 'active' | 'near' | 'edge'
  const idx = bookToIndex('John', 3);
  const info = chapterToInfo(idx);
  const mockActive = state !== 'rest';
  // mockFingerX: 0..1 within strip (can exceed for past-edge).
  //   active: middle (no auto-scroll)
  //   near:   ~85% — in the 10-20% band → 30 ch/s →
  //   edge:   past the left edge → 400 ch/s ←
  const mockFingerX = state === 'near' ? 0.85 : state === 'edge' ? -0.05 : 0.5;
  const mockRaiseY = state === 'edge' ? 50 : state === 'near' ? 90 : 70;
  return (
    <div className="w-screen">
      {/* mini reader header */}
      <div style={{ flexShrink: 0, padding: '10px 14px 12px', borderBottom: `1px solid ${WIRE.line2}`, background: WIRE.bg }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{
            flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '7px 12px', background: WIRE.fill, borderRadius: 8, border: `1px solid ${WIRE.line2}`,
          }}>
            <div style={{ fontSize: 14, fontWeight: 600 }}>{info.book.name} {info.chapter}</div>
            {WireIcons.chevD(12, WIRE.mid)}
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 4,
            padding: '7px 10px', background: WIRE.fill, borderRadius: 8, border: `1px solid ${WIRE.line2}`,
            fontFamily: WIRE.mono, fontSize: 12, fontWeight: 600,
          }}>ESV {WireIcons.chevD(11, WIRE.mid)}</div>
          <div style={{ width: 34, height: 34, borderRadius: 8, border: `1px solid ${WIRE.line2}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{WireIcons.search(15, WIRE.ink2)}</div>
          <div style={{ width: 34, height: 34, borderRadius: 8, border: `1px solid ${WIRE.line2}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{WireIcons.settings(15, WIRE.ink2)}</div>
        </div>
      </div>

      <div className="w-scroll" style={{ background: WIRE.card, opacity: mockActive ? 0.5 : 1, transition: 'opacity .15s' }}>
        <div style={{ padding: '20px 22px 8px' }}>
          <div className="w-anno" style={{ color: WIRE.mid, marginBottom: 4 }}>The Gospel According to John</div>
          <div className="w-h1" style={{ fontSize: 24, marginBottom: 4 }}>Chapter 3</div>
          <div className="w-meta">For God So Loved the World</div>
        </div>
        <div style={{ padding: '4px 22px 40px', fontSize: 15.5, lineHeight: 1.65, color: WIRE.ink }}>
          <sup style={{ fontFamily: WIRE.mono, fontSize: 9.5, fontWeight: 600, color: WIRE.mid, marginRight: 3 }}>16</sup>
          <mark style={{ background: WIRE.yellow, color: WIRE.ink, padding: '0 1px' }}>For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.</mark>{' '}
          <sup style={{ fontFamily: WIRE.mono, fontSize: 9.5, fontWeight: 600, color: WIRE.mid, marginRight: 3 }}>17</sup>
          For God did not send his Son into the world to condemn the world…
        </div>
      </div>

      <ScrubberWindowed
        initialIndex={idx}
        mockActive={mockActive}
        mockFingerX={mockFingerX}
        mockRaiseY={mockRaiseY}
      />
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);

