// All screens — each is a function that takes a state + setter context.
// Designed to compose: Screen({ ctx }) returns content inside a <WirePhone>.

// Sample data
const LANGUAGES = [
  { code: 'en', name: 'English', native: 'English', count: 23 },
  { code: 'es', name: 'Spanish', native: 'Español', count: 18 },
  { code: 'fr', name: 'French', native: 'Français', count: 9 },
  { code: 'de', name: 'German', native: 'Deutsch', count: 7 },
  { code: 'pt', name: 'Portuguese', native: 'Português', count: 11 },
  { code: 'zh', name: 'Chinese', native: '中文', count: 6 },
  { code: 'ja', name: 'Japanese', native: '日本語', count: 3 },
  { code: 'ko', name: 'Korean', native: '한국어', count: 4 },
  { code: 'ar', name: 'Arabic', native: 'العربية', count: 5 },
  { code: 'he', name: 'Hebrew', native: 'עברית', count: 4 },
  { code: 'el', name: 'Greek', native: 'Ελληνικά', count: 3 },
  { code: 'ru', name: 'Russian', native: 'Русский', count: 6 },
  { code: 'sw', name: 'Swahili', native: 'Kiswahili', count: 2 },
  { code: 'hi', name: 'Hindi', native: 'हिन्दी', count: 4 },
];

const TRANSLATIONS_EN = [
  { abbr: 'ESV', name: 'English Standard Version', pub: 'Crossway', books: 66, year: 2001 },
  { abbr: 'NIV', name: 'New International Version', pub: 'Biblica', books: 66, year: 2011 },
  { abbr: 'KJV', name: 'King James Version', pub: 'Public Domain', books: 66, year: 1611 },
  { abbr: 'NRSV', name: 'New Revised Standard Version', pub: 'NCC', books: 73, year: 2021 },
  { abbr: 'NASB', name: 'New American Standard Bible', pub: 'Lockman Foundation', books: 66, year: 2020 },
  { abbr: 'NKJV', name: 'New King James Version', pub: 'Thomas Nelson', books: 66, year: 1982 },
  { abbr: 'CSB', name: 'Christian Standard Bible', pub: 'Holman', books: 66, year: 2017 },
  { abbr: 'NLT', name: 'New Living Translation', pub: 'Tyndale', books: 66, year: 2015 },
];

// ────────────────────────────────────────────────────────
// Reusable header bar
// ────────────────────────────────────────────────────────
function WireHeader({ title, onBack, right, subtitle, large = false }) {
  return (
    <div style={{
      flexShrink: 0,
      padding: large ? '6px 20px 14px' : '8px 16px 12px',
      borderBottom: `1px solid ${WIRE.line2}`,
      background: WIRE.bg,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', minHeight: 36, gap: 8 }}>
        {onBack && (
          <div className="w-tap" onClick={onBack} style={{ padding: 8, margin: -8, borderRadius: 6 }}>
            {WireIcons.back(18)}
          </div>
        )}
        {!large && <div style={{ flex: 1, fontSize: 15, fontWeight: 600, textAlign: 'center', letterSpacing: '-0.01em' }}>{title}</div>}
        {!large && <div style={{ width: 18, display: 'flex', justifyContent: 'flex-end' }}>{right}</div>}
      </div>
      {large && (
        <div style={{ marginTop: 4 }}>
          <div className="w-h1">{title}</div>
          {subtitle && <div className="w-meta" style={{ marginTop: 4 }}>{subtitle}</div>}
        </div>
      )}
    </div>
  );
}

// ────────────────────────────────────────────────────────
// Search input row
// ────────────────────────────────────────────────────────
function WireSearchField({ value, placeholder = 'Search…', onClear, autoFocus }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 8,
      height: 38, padding: '0 12px',
      background: WIRE.fill,
      borderRadius: 10,
      border: `1px solid ${WIRE.line2}`,
    }}>
      {WireIcons.search(15, WIRE.mid)}
      <div style={{ flex: 1, fontSize: 14, color: value ? WIRE.ink : WIRE.mid2, fontFamily: WIRE.font }}>
        {value || placeholder}
        {autoFocus && <span style={{ display: 'inline-block', width: 1.5, height: 14, background: WIRE.ink, marginLeft: 2, verticalAlign: 'middle', animation: 'w-blink 1s steps(2) infinite' }}/>}
      </div>
      {value && onClear && (
        <div className="w-tap" onClick={onClear} style={{ padding: 2 }}>
          {WireIcons.close(12, WIRE.mid)}
        </div>
      )}
    </div>
  );
}

// Add blink animation
if (!document.getElementById('w-anim')) {
  const s = document.createElement('style');
  s.id = 'w-anim';
  s.textContent = '@keyframes w-blink{50%{opacity:0}}@keyframes w-sheet-up{from{transform:translateY(100%)}to{transform:translateY(0)}}@keyframes w-fade-in{from{opacity:0}to{opacity:1}}@keyframes w-search-grow{from{opacity:0;transform:translateX(-8px) scaleX(.92);transform-origin:left center}to{opacity:1;transform:translateX(0) scaleX(1)}}';
  document.head.appendChild(s);
}

// ────────────────────────────────────────────────────────
// 1. LANGUAGE PICKER — Step 1 of onboarding (full screen)
// ────────────────────────────────────────────────────────
function LanguageScreen({ ctx, variant = 'default' }) {
  const { lang, setLang, onContinue } = ctx;
  const filtered = LANGUAGES;

  // variant: 'default' (search + list), 'grid' (search + grid)
  return (
    <div className="w-screen">
      {/* progress dots */}
      <div style={{ flexShrink: 0, padding: '14px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid, letterSpacing: '.05em' }}>STEP 1 OF 3</div>
        <div style={{ display: 'flex', gap: 5 }}>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.line }}/>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.line }}/>
        </div>
      </div>
      <div style={{ flexShrink: 0, padding: '20px 20px 14px' }}>
        <div className="w-h1">Choose your language</div>
        <div className="w-body" style={{ marginTop: 6 }}>You can change this later in Settings.</div>
      </div>
      <div style={{ flexShrink: 0, padding: '0 20px 12px' }}>
        <WireSearchField placeholder="Search 140 languages…" />
      </div>

      {variant === 'grid' ? (
        <div className="w-scroll" style={{ padding: '0 20px' }}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            {filtered.map((l) => {
              const sel = lang === l.code;
              return (
                <div key={l.code} className="w-tap" onClick={() => setLang(l.code)} style={{
                  padding: '12px 12px',
                  borderRadius: 10,
                  border: `1px solid ${sel ? WIRE.ink : WIRE.line2}`,
                  background: sel ? WIRE.ink : WIRE.card,
                  color: sel ? '#fff' : WIRE.ink,
                  minHeight: 64,
                  display: 'flex', flexDirection: 'column', justifyContent: 'center',
                }}>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>{l.native}</div>
                  <div style={{ fontSize: 11, color: sel ? 'rgba(255,255,255,.6)' : WIRE.mid, marginTop: 2 }}>{l.name} · {l.count}</div>
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="w-scroll">
          {filtered.map((l, i) => {
            const sel = lang === l.code;
            return (
              <div key={l.code} className="w-tap" onClick={() => setLang(l.code)} style={{
                display: 'flex', alignItems: 'center',
                padding: '12px 20px',
                borderBottom: i === filtered.length - 1 ? 'none' : `1px solid ${WIRE.line2}`,
                background: sel ? WIRE.fill : 'transparent',
              }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, fontWeight: 500 }}>{l.native}</div>
                  <div style={{ fontSize: 12, color: WIRE.mid, marginTop: 1 }}>{l.name} · <span className="w-mono">{l.count} translations</span></div>
                </div>
                {sel ? (
                  <div style={{ width: 22, height: 22, borderRadius: 11, background: WIRE.ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    {WireIcons.check(12, '#fff')}
                  </div>
                ) : (
                  <div style={{ width: 22, height: 22, borderRadius: 11, border: `1.5px solid ${WIRE.line}` }}/>
                )}
              </div>
            );
          })}
        </div>
      )}

      <div style={{ flexShrink: 0, padding: '12px 20px 24px', borderTop: `1px solid ${WIRE.line2}`, background: WIRE.bg }}>
        <WireBtn size="lg" disabled={!lang} onClick={onContinue} style={{ width: '100%' }}>
          Continue
        </WireBtn>
      </div>
    </div>
  );
}

// 1b. LANGUAGE DETECT (variant C) — auto-detected language, with confirm.
//     Used by the click-through prototype as step 1.
function LanguageDetectScreen({ ctx }) {
  const { lang, setLang, onContinue } = ctx;
  const langObj = LANGUAGES.find((l) => l.code === lang) || LANGUAGES[0];
  const [picking, setPicking] = React.useState(false);

  if (picking) {
    return <LanguageScreen ctx={{ ...ctx, onContinue: () => setPicking(false) }}/>;
  }
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
            <div style={{ width: 36, height: 36, borderRadius: 8, background: WIRE.ink, color: '#fff', fontFamily: WIRE.mono, fontWeight: 700, fontSize: 12, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{langObj.code.toUpperCase()}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontSize: 15, fontWeight: 600 }}>{langObj.name}</div>
              <div className="w-meta" style={{ fontSize: 11.5, marginTop: 2 }}><span className="w-mono">{langObj.count}</span> translations available</div>
            </div>
            <div style={{ width: 24, height: 24, borderRadius: 12, background: WIRE.ink, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              {WireIcons.check(14, '#fff')}
            </div>
          </div>
        </WireBox>
        <div className="w-tap" onClick={() => setPicking(true)} style={{
          padding: '12px 14px',
          border: `1px dashed ${WIRE.line}`,
          borderRadius: 10,
          display: 'flex', alignItems: 'center', gap: 10,
          color: WIRE.ink2, fontSize: 13,
          cursor: 'pointer',
        }}>
          {WireIcons.globe(15, WIRE.ink2)}
          <span style={{ flex: 1 }}>Choose a different language</span>
          {WireIcons.chev(12, WIRE.mid)}
        </div>
      </div>
      <div style={{ flexShrink: 0, padding: '12px 20px 24px' }}>
        <WireBtn size="lg" onClick={onContinue} style={{ width: '100%' }}>Continue in {langObj.name}</WireBtn>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────
// 2. TRANSLATION PICKER — fullscreen, used in onboarding step 2 + settings
// `mode`: 'onboarding' | 'settings' — affects header (step indicator vs ×)
//
// Per-row state machine:
//   not-downloaded → tap row or download icon → downloading
//   downloading    → circular progress bar around a × cancel icon
//                    tap × → cancels back to not-downloaded
//   downloaded     → tap row to select; icon = empty ring (selectable)
//                    or filled check when this row is the current trans.
// Selection is only possible after download completes.
// ────────────────────────────────────────────────────────

// Circular-progress + icon used as the right-side affordance per row.
function DownloadStateIcon({ state, progress, onClick }) {
  // state: 'idle' | 'downloading' | 'ready' | 'selected'
  const size = 26;
  const r = 11;
  const c = 2 * Math.PI * r;
  const dashOffset = c * (1 - (progress || 0));

  if (state === 'selected') {
    return (
      <div onClick={onClick} className="w-tap" style={{
        width: size, height: size, borderRadius: size / 2,
        background: WIRE.ink,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0, cursor: 'pointer',
      }}>
        {WireIcons.check(13, '#fff')}
      </div>
    );
  }
  if (state === 'ready') {
    // Downloaded but not selected — empty selectable ring
    return (
      <div onClick={onClick} className="w-tap" style={{
        width: size, height: size, borderRadius: size / 2,
        background: 'transparent',
        border: `1.5px solid ${WIRE.line}`,
        flexShrink: 0, cursor: 'pointer',
      }}/>
    );
  }
  if (state === 'downloading') {
    return (
      <div onClick={onClick} className="w-tap" style={{
        position: 'relative', width: size, height: size,
        flexShrink: 0, cursor: 'pointer',
      }}>
        <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ position: 'absolute', inset: 0 }}>
          <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={WIRE.line2} strokeWidth="1.5"/>
          <circle
            cx={size/2} cy={size/2} r={r}
            fill="none" stroke={WIRE.ink} strokeWidth="1.5"
            strokeDasharray={c} strokeDashoffset={dashOffset}
            strokeLinecap="round"
            transform={`rotate(-90 ${size/2} ${size/2})`}
            style={{ transition: 'stroke-dashoffset .12s linear' }}
          />
        </svg>
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {WireIcons.close(10, WIRE.ink)}
        </div>
      </div>
    );
  }
  // idle — download icon
  return (
    <div onClick={onClick} className="w-tap" style={{
      width: size, height: size, borderRadius: size / 2,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      flexShrink: 0, cursor: 'pointer',
    }}>
      {WireIcons.download(15, WIRE.ink2)}
    </div>
  );
}

function TranslationPicker({ ctx, onClose, mode = 'onboarding' }) {
  const { lang, trans, setTrans } = ctx;
  const langObj = LANGUAGES.find((l) => l.code === lang) || LANGUAGES[0];

  // Per-translation download state:
  //   downloads[abbr] = { state: 'idle'|'downloading'|'ready', progress: 0..1 }
  // The currently-selected translation (`trans`) is implicitly ready.
  const [downloads, setDownloads] = React.useState(() => {
    const m = {};
    TRANSLATIONS_EN.forEach((t) => { m[t.abbr] = { state: 'idle', progress: 0 }; });
    if (trans) m[trans] = { state: 'ready', progress: 1 };
    return m;
  });

  // Drive download progress for any row marked 'downloading'
  React.useEffect(() => {
    const downloadingAbbrs = Object.entries(downloads)
      .filter(([, d]) => d.state === 'downloading')
      .map(([abbr]) => abbr);
    if (downloadingAbbrs.length === 0) return;
    const id = setInterval(() => {
      setDownloads((prev) => {
        const next = { ...prev };
        let dirty = false;
        downloadingAbbrs.forEach((abbr) => {
          if (next[abbr]?.state !== 'downloading') return;
          const p = Math.min(1, next[abbr].progress + 0.04 + Math.random() * 0.02);
          dirty = true;
          if (p >= 1) next[abbr] = { state: 'ready', progress: 1 };
          else next[abbr] = { state: 'downloading', progress: p };
        });
        return dirty ? next : prev;
      });
    }, 120);
    return () => clearInterval(id);
  }, [Object.values(downloads).map((d) => d.state).join(',')]);

  const handleIconClick = (abbr) => {
    const cur = downloads[abbr];
    if (!cur || cur.state === 'idle') {
      setDownloads((p) => ({ ...p, [abbr]: { state: 'downloading', progress: 0 } }));
    } else if (cur.state === 'downloading') {
      setDownloads((p) => ({ ...p, [abbr]: { state: 'idle', progress: 0 } }));
    } else if (cur.state === 'ready' && trans !== abbr) {
      setTrans(abbr);
    }
  };

  const handleRowClick = (abbr) => {
    const cur = downloads[abbr];
    if (!cur || cur.state === 'idle') {
      // Tap row to start download
      setDownloads((p) => ({ ...p, [abbr]: { state: 'downloading', progress: 0 } }));
    } else if (cur.state === 'ready') {
      setTrans(abbr);
    }
    // While downloading, ignore row taps (only × cancels)
  };

  return (
    <div className="w-screen" style={{
      background: WIRE.bg,
      display: 'flex', flexDirection: 'column',
      animation: 'w-fade-in .2s',
      zIndex: 50,
    }}>
      {/* header */}
      <div style={{ padding: '16px 20px 14px', flexShrink: 0 }}>
        {mode === 'onboarding' && (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <div style={{ fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid, letterSpacing: '.05em' }}>STEP 2 OF 3</div>
            <div style={{ display: 'flex', gap: 5 }}>
              <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
              <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
              <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.line }}/>
            </div>
          </div>
        )}
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12 }}>
          <div>
            <div className="w-h1">Choose a translation</div>
            <div style={{ fontSize: 12, color: WIRE.mid, marginTop: 6, display: 'flex', alignItems: 'center', gap: 6 }}>
              {WireIcons.globe(12, WIRE.mid)}
              <span>{langObj.native} · {langObj.name}</span>
              <span style={{ color: WIRE.line }}>•</span>
              <span className="w-mono">{TRANSLATIONS_EN.length} available</span>
            </div>
          </div>
          {mode === 'settings' && (
            <div className="w-tap" onClick={onClose} style={{ padding: 6, margin: -6 }}>
              {WireIcons.close(18, WIRE.mid)}
            </div>
          )}
        </div>
      </div>

      {/* search + filter */}
      <div style={{ padding: '0 20px 12px', display: 'flex', gap: 8, flexShrink: 0 }}>
        <div style={{ flex: 1 }}>
          <WireSearchField placeholder="Search translations…" />
        </div>
        <div className="w-tap" style={{
          width: 38, height: 38, borderRadius: 10,
          background: WIRE.fill, border: `1px solid ${WIRE.line2}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>{WireIcons.filter(16, WIRE.ink2)}</div>
      </div>

      {/* list */}
      <div className="w-scroll">
        <div style={{ padding: '0 20px' }}>
          {TRANSLATIONS_EN.map((t) => {
            const sel = trans === t.abbr;
            const dl = downloads[t.abbr] || { state: 'idle', progress: 0 };
            const iconState = sel ? 'selected' : dl.state;
            const isReady = dl.state === 'ready' || sel;
            return (
              <div key={t.abbr} className="w-tap" onClick={() => handleRowClick(t.abbr)} style={{
                display: 'flex', alignItems: 'center', gap: 12,
                padding: '12px 0',
                borderBottom: `1px solid ${WIRE.line2}`,
                opacity: !isReady && dl.state !== 'downloading' ? 0.85 : 1,
                cursor: dl.state === 'downloading' ? 'default' : 'pointer',
              }}>
                <div style={{
                  width: 48, height: 48, borderRadius: 10,
                  background: sel ? WIRE.ink : WIRE.fill,
                  border: `1px solid ${sel ? WIRE.ink : WIRE.line2}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontFamily: WIRE.mono, fontSize: 13, fontWeight: 600,
                  color: sel ? '#fff' : WIRE.ink, flexShrink: 0,
                }}>{t.abbr}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: '-0.005em', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{t.name}</div>
                  <div style={{ fontSize: 11.5, color: WIRE.mid, marginTop: 2 }}>
                    {t.pub} · <span className="w-mono">{t.year}</span>
                    {dl.state === 'downloading' && (
                      <> · <span className="w-mono" style={{ color: WIRE.ink2 }}>{Math.round(dl.progress * 100)}%</span></>
                    )}
                    {!isReady && dl.state === 'idle' && (
                      <> · <span className="w-mono" style={{ color: WIRE.mid }}>Not downloaded</span></>
                    )}
                  </div>
                </div>
                <DownloadStateIcon
                  state={iconState}
                  progress={dl.progress}
                  onClick={(e) => { e.stopPropagation(); handleIconClick(t.abbr); }}
                />
              </div>
            );
          })}
        </div>
      </div>

      {/* footer CTA */}
      {mode === 'onboarding' && (
        <div style={{ flexShrink: 0, padding: '12px 20px 24px', borderTop: `1px solid ${WIRE.line2}`, background: WIRE.bg }}>
          <WireBtn size="lg" disabled={!trans} onClick={ctx.onContinue} style={{ width: '100%' }}>Continue</WireBtn>
        </div>
      )}
      {mode === 'settings' && trans && (
        <div style={{ flexShrink: 0, padding: '12px 20px 24px', borderTop: `1px solid ${WIRE.line2}`, background: WIRE.bg }}>
          <WireBtn size="lg" onClick={onClose} style={{ width: '100%' }}>Use {trans}</WireBtn>
        </div>
      )}
    </div>
  );
}

// Step 2 host — kept for backwards compat (TranslationPicker is now fullscreen,
// so this just renders the picker directly).
function TranslationStep2Host({ ctx, onClose }) {
  return <TranslationPicker ctx={ctx} onClose={onClose} mode="onboarding" />;
}

// ────────────────────────────────────────────────────────
// 3. ONBOARDING COMPLETE
// ────────────────────────────────────────────────────────
function CompleteScreen({ ctx }) {
  const langObj = LANGUAGES.find((l) => l.code === ctx.lang) || LANGUAGES[0];
  const transObj = TRANSLATIONS_EN.find((t) => t.abbr === ctx.trans) || TRANSLATIONS_EN[0];
  return (
    <div className="w-screen">
      <div style={{ flexShrink: 0, padding: '14px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid, letterSpacing: '.05em' }}>STEP 3 OF 3</div>
        <div style={{ display: 'flex', gap: 5 }}>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
          <div style={{ width: 18, height: 3, borderRadius: 2, background: WIRE.ink }}/>
        </div>
      </div>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 28px', textAlign: 'center', gap: 18 }}>
        <div style={{ width: 64, height: 64, borderRadius: 16, border: `1.5px solid ${WIRE.ink}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          {WireIcons.check(28, WIRE.ink)}
        </div>
        <div>
          <div className="w-h1">You're all set</div>
          <div className="w-body" style={{ marginTop: 8 }}>Your library is ready. You can change these anytime in Settings.</div>
        </div>
        <WireBox p={14} radius={12} style={{ width: '100%' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 44, height: 44, borderRadius: 9, background: WIRE.fill, border: `1px solid ${WIRE.line2}`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: WIRE.mono, fontSize: 12, fontWeight: 600 }}>{transObj.abbr}</div>
            <div style={{ flex: 1, textAlign: 'left' }}>
              <div style={{ fontSize: 13, fontWeight: 600 }}>{transObj.name}</div>
              <div style={{ fontSize: 11, color: WIRE.mid, marginTop: 2 }}>{langObj.name} · {transObj.pub}</div>
            </div>
          </div>
        </WireBox>
      </div>
      <div style={{ flexShrink: 0, padding: '12px 20px 24px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <WireBtn size="lg" onClick={ctx.onContinue} style={{ width: '100%' }}>Start reading</WireBtn>
        <WireBtn size="md" kind="ghost" onClick={ctx.onChange} style={{ width: '100%' }}>Change language or translation</WireBtn>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────
// 4. SEARCH SCREEN
// `variant`: 'grouped' (default) | 'tabs' | 'unified'
// ────────────────────────────────────────────────────────
const SEARCH_RESULTS = {
  exact: [
    { ref: 'John 3:16', text: 'For God so loved the world, that he gave his only Son…', highlight: 'loved' },
    { ref: '1 John 4:8', text: 'Anyone who does not love does not know God, because God is love.', highlight: 'love' },
    { ref: 'Romans 8:39', text: '…will be able to separate us from the love of God in Christ Jesus.', highlight: 'love' },
  ],
  semantic: [
    { ref: 'John 13:34', text: 'A new commandment I give to you, that you love one another…', highlight: 'love' },
    { ref: '1 Cor 13:4', text: 'Love is patient and kind; love does not envy or boast…', highlight: 'Love' },
  ],
  cross: [
    { ref: 'Juan 3:16', text: 'Porque de tal manera amó Dios al mundo…', lang: 'ES · RVR', highlight: 'amó' },
    { ref: '约翰福音 3:16', text: '神爱世人,甚至将他的独生子赐给他们…', lang: 'ZH · CUV', highlight: '爱' },
  ],
};

function ResultRow({ r, dense = false }) {
  const parts = r.text.split(new RegExp(`(${r.highlight})`));
  return (
    <div className="w-tap" style={{
      padding: dense ? '10px 16px' : '12px 16px',
      borderBottom: `1px solid ${WIRE.line2}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
        <span style={{ fontFamily: WIRE.mono, fontSize: 11.5, fontWeight: 600, color: WIRE.ink }}>{r.ref}</span>
        {r.lang && <span className="w-pill">{r.lang}</span>}
      </div>
      <div style={{ fontSize: 13, lineHeight: 1.45, color: WIRE.ink2 }}>
        {parts.map((p, i) => p === r.highlight
          ? <mark key={i} style={{ background: WIRE.yellow, color: WIRE.ink, padding: '0 2px', borderRadius: 2 }}>{p}</mark>
          : <span key={i}>{p}</span>)}
      </div>
    </div>
  );
}

function SearchScreen({ ctx, variant = 'grouped' }) {
  const [query, setQuery] = React.useState('love');
  const [tab, setTab] = React.useState('all');

  return (
    <div className="w-screen">
      <div style={{ flexShrink: 0, padding: '10px 16px 8px', background: WIRE.bg }}>
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 8 }}>
          <div className="w-h2" style={{ fontSize: 16, flex: 1 }}>Search</div>
          {ctx.onClose && (
            <div className="w-tap" onClick={ctx.onClose} style={{ padding: 6, margin: -6 }}>
              {WireIcons.close(18, WIRE.ink2)}
            </div>
          )}
        </div>
        <WireSearchField value={query} placeholder="Verse, keyword, or topic" onClear={() => setQuery('')} autoFocus />
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
          <span className="w-pill">{WireIcons.globe(10, WIRE.mid)} ESV</span>
          <span className="w-pill">All books {WireIcons.chevD(10, WIRE.mid)}</span>
          <span className="w-pill">Cross-language {WireIcons.chevD(10, WIRE.mid)}</span>
        </div>
      </div>

      {/* fallback banner */}
      <div style={{ flexShrink: 0, padding: '8px 16px', background: WIRE.yellow, borderBottom: `1px solid ${WIRE.line2}` }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 8 }}>
          <div style={{ width: 4, height: 4, borderRadius: 2, background: WIRE.yellowInk, marginTop: 7 }}/>
          <div style={{ flex: 1, fontSize: 11.5, color: WIRE.yellowInk, lineHeight: 1.4 }}>
            <span style={{ fontWeight: 600 }}>Showing closest matches.</span> Expanded to 2 related languages — <a style={{ textDecoration: 'underline', cursor: 'pointer' }}>only show ESV</a>
          </div>
        </div>
      </div>

      {variant === 'tabs' && (
        <div style={{ flexShrink: 0, display: 'flex', borderBottom: `1px solid ${WIRE.line2}`, padding: '0 16px', gap: 18, background: WIRE.bg }}>
          {[
            { id: 'all', label: 'All', n: 7 },
            { id: 'exact', label: 'Exact', n: 3 },
            { id: 'semantic', label: 'Related', n: 2 },
            { id: 'cross', label: 'Other languages', n: 2 },
          ].map((t) => {
            const on = tab === t.id;
            return (
              <div key={t.id} className="w-tap" onClick={() => setTab(t.id)} style={{
                padding: '10px 0 9px',
                fontSize: 12.5, fontWeight: on ? 600 : 500,
                color: on ? WIRE.ink : WIRE.mid,
                borderBottom: on ? `2px solid ${WIRE.ink}` : '2px solid transparent',
                marginBottom: -1,
                display: 'flex', alignItems: 'center', gap: 4,
              }}>{t.label} <span className="w-mono" style={{ fontSize: 10, color: WIRE.mid }}>{t.n}</span></div>
            );
          })}
        </div>
      )}

      <div className="w-scroll">
        {variant === 'grouped' && (
          <>
            <SectionHead label="Exact matches" count={3} />
            {SEARCH_RESULTS.exact.map((r, i) => <ResultRow key={i} r={r}/>)}
            <SectionHead label="Related verses" count={2} hint="Semantic" />
            {SEARCH_RESULTS.semantic.map((r, i) => <ResultRow key={i} r={r}/>)}
            <SectionHead label="Other languages" count={2} hint="Cross-language" />
            {SEARCH_RESULTS.cross.map((r, i) => <ResultRow key={i} r={r}/>)}
          </>
        )}
        {variant === 'tabs' && (
          <>
            {(tab === 'all' || tab === 'exact') && SEARCH_RESULTS.exact.map((r, i) => <ResultRow key={'e'+i} r={r}/>)}
            {(tab === 'all' || tab === 'semantic') && SEARCH_RESULTS.semantic.map((r, i) => <ResultRow key={'s'+i} r={r}/>)}
            {(tab === 'all' || tab === 'cross') && SEARCH_RESULTS.cross.map((r, i) => <ResultRow key={'c'+i} r={r}/>)}
          </>
        )}
        {variant === 'unified' && (
          <>
            {[...SEARCH_RESULTS.exact, ...SEARCH_RESULTS.semantic, ...SEARCH_RESULTS.cross].map((r, i) => (
              <div key={i} style={{ position: 'relative' }}>
                <div style={{ position: 'absolute', left: 16, top: 12, width: 4, height: 4, borderRadius: 2, background: i < 3 ? WIRE.ink : i < 5 ? WIRE.mid : WIRE.line }}/>
                <div style={{ paddingLeft: 12 }}>
                  <ResultRow r={r} dense />
                </div>
              </div>
            ))}
          </>
        )}
      </div>

    </div>
  );
}

function SectionHead({ label, count, hint }) {
  return (
    <div style={{
      padding: '14px 16px 6px',
      display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
      background: WIRE.bg,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span className="w-anno">{label}</span>
        <span className="w-mono" style={{ fontSize: 10, color: WIRE.mid }}>{count}</span>
      </div>
      {hint && <span style={{ fontSize: 10, color: WIRE.mid2, fontFamily: WIRE.mono }}>{hint}</span>}
    </div>
  );
}

// ────────────────────────────────────────────────────────
// READER TOP PANEL — search-in-center + settings, with pull-to-search
//
// Three states:
//   idle      — search icon centered, settings icon right
//   pulling   — drag-down anywhere on the panel translates the search
//                icon downward with the finger; release ≥ threshold
//                commits to focused, else snaps back
//   focused   — search icon flies to the left (bouncy spring),
//                input field grows in & gets focus; Esc / × returns
// ────────────────────────────────────────────────────────
const READER_PANEL_H = 52;
const PULL_THRESHOLD = 36;
const PULL_MAX = 96;
// Bouncy overshoot for the icon → left transition
const SPRING = 'cubic-bezier(.34,1.56,.64,1)';

function ReaderTopPanel({ ctx }) {
  const [phase, setPhase] = React.useState('idle'); // 'idle' | 'pulling' | 'focused'
  const [pullPx, setPullPx] = React.useState(0);
  const [query, setQuery] = React.useState('');
  const inputRef = React.useRef(null);
  const panelRef = React.useRef(null);

  const focusSearch = React.useCallback(() => {
    setPhase('focused');
    setPullPx(0);
    // autoFocus after the input mounts
    requestAnimationFrame(() => {
      inputRef.current && inputRef.current.focus();
    });
  }, []);

  const dismiss = React.useCallback(() => {
    setQuery('');
    setPhase('idle');
    setPullPx(0);
    if (inputRef.current) inputRef.current.blur();
  }, []);

  // ── Pull-to-search gesture ──
  const onPullPointerDown = (e) => {
    if (phase === 'focused') return;
    // Ignore presses on the settings button (it's its own tap target)
    if (e.target.closest('[data-no-pull]')) return;
    e.preventDefault();
    const startY = e.clientY;
    let resolved = false;

    const move = (ev) => {
      const dy = ev.clientY - startY;
      if (dy <= 0) { setPhase('idle'); setPullPx(0); return; }
      setPhase('pulling');
      setPullPx(Math.min(PULL_MAX, dy));
    };
    const up = (ev) => {
      if (resolved) return;
      resolved = true;
      document.removeEventListener('pointermove', move);
      document.removeEventListener('pointerup', up);
      document.removeEventListener('pointercancel', up);
      const dy = ev.clientY - startY;
      if (dy >= PULL_THRESHOLD) {
        focusSearch();
      } else {
        setPhase('idle');
        setPullPx(0);
      }
    };
    document.addEventListener('pointermove', move);
    document.addEventListener('pointerup', up);
    document.addEventListener('pointercancel', up);
  };

  // ── Derived positions for the search icon ──
  // idle/pulling: centered (translateX(-50%)), translateY = pullPx
  // focused: pinned to left (left:16px), translateY = 0
  const iconLeft = phase === 'focused' ? 16 : '50%';
  const iconTx = phase === 'focused' ? 0 : '-50%';
  const iconTy = phase === 'pulling' ? pullPx : 0;
  // Bouncy when transitioning into focused; quick & linear during the drag
  const iconTransition = phase === 'pulling'
    ? 'none'
    : `left .42s ${SPRING}, transform .42s ${SPRING}, top .42s ${SPRING}`;

  return (
    <div
      ref={panelRef}
      data-screen-label="Reader · Top panel"
      onPointerDown={onPullPointerDown}
      style={{
        flexShrink: 0,
        position: 'relative',
        height: READER_PANEL_H,
        background: WIRE.bg,
        borderBottom: `1px solid ${WIRE.line2}`,
        touchAction: 'none',
        userSelect: 'none',
        overflow: 'visible',
        zIndex: 5,
      }}>
      {/* Search anchor — icon (always rendered) */}
      <div
        onClick={(e) => { e.stopPropagation(); if (phase !== 'focused') focusSearch(); }}
        style={{
          position: 'absolute',
          top: '50%',
          left: iconLeft,
          transform: `translate(${iconTx}, calc(-50% + ${iconTy}px))`,
          width: 34, height: 34, borderRadius: 8,
          border: `1px solid ${phase === 'focused' ? 'transparent' : WIRE.line2}`,
          background: phase === 'focused' ? 'transparent' : WIRE.bg,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer',
          transition: iconTransition,
          zIndex: 2,
        }}>
        {WireIcons.search(16, WIRE.ink2)}
      </div>

      {/* Pull-down hint (only while pulling) */}
      {phase === 'pulling' && pullPx > 8 && (
        <div style={{
          position: 'absolute',
          left: 0, right: 0,
          top: '50%',
          transform: `translateY(calc(-50% + ${pullPx + 22}px))`,
          textAlign: 'center',
          fontFamily: WIRE.mono, fontSize: 10, letterSpacing: '.04em',
          color: pullPx >= PULL_THRESHOLD ? WIRE.ink : WIRE.mid,
          textTransform: 'uppercase', fontWeight: 600,
          pointerEvents: 'none',
          transition: 'color .1s',
        }}>
          {pullPx >= PULL_THRESHOLD ? 'Release to search' : 'Pull to search'}
        </div>
      )}

      {/* Search input — only mounted while focused */}
      {phase === 'focused' && (
        <div style={{
          position: 'absolute',
          top: 0, bottom: 0,
          left: 58, right: 16,
          display: 'flex', alignItems: 'center', gap: 8,
          animation: `w-search-grow .35s ${SPRING}`,
        }}>
          <input
            ref={inputRef}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onBlur={() => { if (!query) dismiss(); }}
            onKeyDown={(e) => { if (e.key === 'Escape') dismiss(); }}
            placeholder="Search verses, books, words…"
            style={{
              flex: 1,
              height: 34,
              padding: '0 12px',
              fontFamily: WIRE.font,
              fontSize: 14,
              color: WIRE.ink,
              background: WIRE.fill,
              border: `1px solid ${WIRE.line2}`,
              borderRadius: 8,
              outline: 'none',
            }}
          />
          <div
            data-no-pull=""
            className="w-tap"
            onClick={(e) => { e.stopPropagation(); dismiss(); }}
            style={{
              width: 34, height: 34, borderRadius: 8,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer',
            }}>
            {WireIcons.close(14, WIRE.mid)}
          </div>
        </div>
      )}

      {/* Settings icon — right side, hidden while focused */}
      <div
        data-no-pull=""
        onClick={(e) => { e.stopPropagation(); ctx.onOpenSettings && ctx.onOpenSettings(); }}
        style={{
          position: 'absolute',
          top: '50%', right: 16,
          transform: 'translateY(-50%)',
          width: 34, height: 34, borderRadius: 8,
          border: `1px solid ${WIRE.line2}`,
          background: WIRE.bg,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          cursor: 'pointer',
          opacity: phase === 'focused' ? 0 : 1,
          pointerEvents: phase === 'focused' ? 'none' : 'auto',
          transition: 'opacity .18s ease-out',
          zIndex: 2,
        }}>
        {WireIcons.settings(15, WIRE.ink2)}
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────
// 5. READER (paginated)
// ────────────────────────────────────────────────────────
const JOHN_3 = [
  { n: 14, text: 'And as Moses lifted up the serpent in the wilderness, so must the Son of Man be lifted up,' },
  { n: 15, text: 'that whoever believes in him may have eternal life.' },
  { n: 16, text: 'For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.' },
  { n: 17, text: 'For God did not send his Son into the world to condemn the world, but in order that the world might be saved through him.' },
  { n: 18, text: 'Whoever believes in him is not condemned, but whoever does not believe is condemned already, because he has not believed in the name of the only Son of God.' },
  { n: 19, text: 'And this is the judgment: the light has come into the world, and people loved the darkness rather than the light because their works were evil.' },
  { n: 20, text: 'For everyone who does evil hates the light and does not come to the light, lest his works should be exposed.' },
  { n: 21, text: 'But whoever does what is true comes to the light, so that it may be clearly seen that his works have been carried out in God.' },
];

function ReaderScreen({ ctx, scrubberInitial }) {
  const [selected, setSelected] = React.useState(null);
  const [highlighted, setHighlighted] = React.useState([16]);
  const [chapterIdx, setChapterIdx] = React.useState(scrubberInitial != null ? scrubberInitial : bookToIndex('John', 3));
  const sel = selected !== null;

  return (
    <div className="w-screen">
      <ReaderTopPanel ctx={ctx}/>

      <div className="w-scroll" style={{ background: WIRE.card }}>
        <div style={{ padding: '20px 22px 12px' }}>
          <div className="w-anno" style={{ color: WIRE.mid, marginBottom: 4 }}>The Gospel According to John</div>
          <div className="w-h1" style={{ fontSize: 24, marginBottom: 4 }}>Chapter 3</div>
          <div className="w-meta">For God So Loved the World</div>
        </div>
        <div style={{ padding: '4px 22px 80px', fontSize: 15.5, lineHeight: 1.65, color: WIRE.ink }}>
          {JOHN_3.map((v) => {
            const isHi = highlighted.includes(v.n);
            const isSel = selected === v.n;
            return (
              <span key={v.n}
                onClick={() => setSelected(isSel ? null : v.n)}
                style={{
                  cursor: 'pointer',
                  background: isSel ? WIRE.blue : isHi ? WIRE.yellow : 'transparent',
                  borderRadius: 2,
                  padding: isSel || isHi ? '0 1px' : '0',
                  transition: 'background .15s',
                }}>
                <sup style={{
                  fontFamily: WIRE.mono, fontSize: 9.5,
                  fontWeight: 600, color: WIRE.mid,
                  marginRight: 3, verticalAlign: 'super', lineHeight: 0,
                }}>{v.n}</sup>
                {v.text}{' '}
              </span>
            );
          })}
        </div>
      </div>

      {/* verse action bar */}
      {sel && (
        <div style={{
          position: 'absolute', left: 12, right: 12,
          bottom: 76,
          background: WIRE.ink,
          borderRadius: 14,
          padding: '10px 12px',
          display: 'flex', alignItems: 'center', gap: 4,
          boxShadow: '0 8px 24px rgba(0,0,0,0.25)',
          zIndex: 10,
          animation: 'w-fade-in .15s',
        }}>
          <div style={{ fontFamily: WIRE.mono, fontSize: 11, color: '#fff', fontWeight: 600, padding: '0 8px 0 4px' }}>v.{selected}</div>
          <div className="w-divider-v" style={{ height: 18, background: 'rgba(255,255,255,.15)' }}/>
          {[
            { i: 'highlight', l: 'Highlight', a: () => { setHighlighted((h) => h.includes(selected) ? h.filter((x) => x !== selected) : [...h, selected]); setSelected(null); }},
            { i: 'copy', l: 'Copy', a: () => setSelected(null) },
            { i: 'link', l: 'Refs', a: () => setSelected(null) },
            { i: 'more', l: 'More', a: () => setSelected(null) },
          ].map((b) => (
            <div key={b.l} className="w-tap" onClick={b.a} style={{
              flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
              padding: '4px 0', borderRadius: 6,
            }}>
              {WireIcons[b.i](15, '#fff')}
              <div style={{ fontSize: 9.5, color: '#fff', fontWeight: 500 }}>{b.l}</div>
            </div>
          ))}
        </div>
      )}

      {/* in-chapter page indicator (small chip, top-right of reader body) */}
      <div style={{
        position: 'absolute', top: 64, right: 12,
        background: 'rgba(255,255,255,.85)', backdropFilter: 'blur(6px)',
        border: `1px solid ${WIRE.line2}`,
        padding: '3px 9px', borderRadius: 99,
        fontFamily: WIRE.mono, fontSize: 10.5, color: WIRE.mid,
      }}>page <span style={{ color: WIRE.ink, fontWeight: 600 }}>3</span><span style={{ opacity: .5 }}> / 21</span></div>

      <ScrubberWindowed
        initialIndex={chapterIdx}
        onChange={(i) => setChapterIdx(i)}
        onCommit={(i) => setChapterIdx(i)}
      />
    </div>
  );
}

// ────────────────────────────────────────────────────────
// 6. SETTINGS
// `variant`: 'list' | 'cards' | 'tabbed'
// ────────────────────────────────────────────────────────
function SettingsRow({ icon, title, detail, last, onClick, danger }) {
  return (
    <div className="w-tap" onClick={onClick} style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 16px', minHeight: 48,
      borderBottom: last ? 'none' : `1px solid ${WIRE.line2}`,
    }}>
      {icon && <div style={{
        width: 28, height: 28, borderRadius: 7,
        background: WIRE.fill, border: `1px solid ${WIRE.line2}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
      }}>{icon}</div>}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 500, color: danger ? '#b91c1c' : WIRE.ink, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{title}</div>
        {detail && <div style={{ fontSize: 11.5, color: WIRE.mid, marginTop: 1 }}>{detail}</div>}
      </div>
      {onClick && WireIcons.chev(12, WIRE.mid2)}
    </div>
  );
}

function SettingsGroup({ label, children }) {
  return (
    <div style={{ marginBottom: 16 }}>
      {label && <div className="w-anno" style={{ padding: '4px 16px 6px' }}>{label}</div>}
      <div style={{ background: WIRE.card, borderTop: `1px solid ${WIRE.line2}`, borderBottom: `1px solid ${WIRE.line2}` }}>
        {children}
      </div>
    </div>
  );
}

function SettingsScreen({ ctx, variant = 'list' }) {
  const langObj = LANGUAGES.find((l) => l.code === ctx.lang) || LANGUAGES[0];
  const transObj = TRANSLATIONS_EN.find((t) => t.abbr === ctx.trans) || TRANSLATIONS_EN[0];

  return (
    <div className="w-screen">
      <div style={{ flexShrink: 0, padding: '6px 20px 14px', borderBottom: `1px solid ${WIRE.line2}`, background: WIRE.bg }}>
        <div style={{ display: 'flex', alignItems: 'center', minHeight: 36 }}>
          <div style={{ flex: 1 }}/>
          {ctx.onClose && (
            <div className="w-tap" onClick={ctx.onClose} style={{ padding: 8, margin: -8 }}>
              {WireIcons.close(18, WIRE.ink2)}
            </div>
          )}
        </div>
        <div className="w-h1">Settings</div>
      </div>

      <div className="w-scroll" style={{ paddingTop: 14, paddingBottom: 8 }}>
        {variant === 'list' && (
          <>
            <SettingsGroup label="Translation">
              <div style={{
                padding: '14px 16px',
                display: 'flex', alignItems: 'center', gap: 12,
                borderBottom: `1px solid ${WIRE.line2}`,
              }}>
                <div style={{ width: 44, height: 44, borderRadius: 9, background: WIRE.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: WIRE.mono, fontWeight: 700, fontSize: 13 }}>{transObj.abbr}</div>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>{transObj.name}</div>
                  <div style={{ fontSize: 11.5, color: WIRE.mid, marginTop: 2 }}>{langObj.name} · {transObj.pub} · <span className="w-mono">{transObj.books} books</span></div>
                </div>
              </div>
              <SettingsRow title="Change translation" onClick={ctx.onChange}/>
              <SettingsRow title="Change language" detail={langObj.native} onClick={ctx.onChange} last/>
            </SettingsGroup>

            <SettingsGroup label="Typography">
              <SettingsRow title="Font (Latin)" detail="Charter" onClick={() => {}}/>
              <SettingsRow title="Font (Greek)" detail="GFS Neohellenic" onClick={() => {}}/>
              <SettingsRow title="Font (Hebrew)" detail="Frank Ruehl" onClick={() => {}}/>
              <SettingsRow title="Font (Arabic)" detail="Noto Naskh" onClick={() => {}}/>
              <SettingsRow title="Font (CJK)" detail="Noto Serif CJK" onClick={() => {}}/>
              <SizeRow label="Text size" pos={2}/>
              <SizeRow label="Line spacing" pos={1} last/>
            </SettingsGroup>

            <SettingsGroup label="Reading">
              <ThemeRow/>
            </SettingsGroup>

            <SettingsGroup label="Support">
              <SettingsRow title="Report a bug" onClick={() => {}}/>
              <SettingsRow title="Submit feedback" onClick={() => {}} last/>
            </SettingsGroup>

            <div style={{ padding: '20px 16px 12px', textAlign: 'center' }}>
              <div className="w-mono" style={{ fontSize: 10, color: WIRE.mid2 }}>Sola · v0.4.2 (build 1187)</div>
            </div>
          </>
        )}

        {variant === 'cards' && (
          <div style={{ padding: '0 16px' }}>
            <div style={{ marginBottom: 14, padding: '16px', background: WIRE.card, borderRadius: 12, border: `1px solid ${WIRE.line2}` }}>
              <div className="w-anno" style={{ marginBottom: 10 }}>Current translation</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
                <div style={{ width: 48, height: 48, borderRadius: 10, background: WIRE.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: WIRE.mono, fontWeight: 700, fontSize: 14 }}>{transObj.abbr}</div>
                <div>
                  <div style={{ fontSize: 14, fontWeight: 600 }}>{transObj.name}</div>
                  <div style={{ fontSize: 11.5, color: WIRE.mid, marginTop: 2 }}>{langObj.name} · {transObj.pub}</div>
                </div>
              </div>
              <WireBtn size="sm" kind="outline" onClick={ctx.onChange} style={{ width: '100%' }}>Change translation</WireBtn>
            </div>

            <CardGroup title="Typography">
              <div style={{ padding: '4px 0' }}>
                <SettingsRow title="Fonts per script" detail="5 scripts configured" onClick={() => {}}/>
                <SizeRow label="Text size" pos={2}/>
                <SizeRow label="Line spacing" pos={1} last/>
              </div>
            </CardGroup>

            <CardGroup title="Reading theme">
              <div style={{ padding: 12 }}><ThemeRow inline/></div>
            </CardGroup>

            <CardGroup title="Help">
              <SettingsRow title="Report a bug" onClick={() => {}}/>
              <SettingsRow title="Submit feedback" onClick={() => {}} last/>
            </CardGroup>

            <div style={{ padding: '12px 0 12px', textAlign: 'center' }}>
              <div className="w-mono" style={{ fontSize: 10, color: WIRE.mid2 }}>Sola · v0.4.2 (build 1187)</div>
            </div>
          </div>
        )}

        {variant === 'tabbed' && <SettingsTabbed ctx={ctx} langObj={langObj} transObj={transObj}/>}
      </div>

    </div>
  );
}

function CardGroup({ title, children }) {
  return (
    <div style={{ marginBottom: 12, background: WIRE.card, borderRadius: 12, border: `1px solid ${WIRE.line2}`, overflow: 'hidden' }}>
      <div className="w-anno" style={{ padding: '12px 14px 0' }}>{title}</div>
      {children}
    </div>
  );
}

function SizeRow({ label, pos, last }) {
  const dots = [0, 1, 2, 3];
  return (
    <div style={{ padding: '12px 16px', borderBottom: last ? 'none' : `1px solid ${WIRE.line2}` }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
        <div style={{ fontSize: 14, fontWeight: 500 }}>{label}</div>
        <div style={{ fontFamily: WIRE.mono, fontSize: 11, color: WIRE.mid }}>{['S','M','L','XL'][pos]}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', height: 16, position: 'relative' }}>
        <div style={{ position: 'absolute', left: 0, right: 0, top: 7.5, height: 1, background: WIRE.line2 }}/>
        <div style={{ position: 'absolute', left: 0, top: 7.5, width: `${(pos / 3) * 100}%`, height: 1, background: WIRE.ink }}/>
        {dots.map((d) => (
          <div key={d} style={{
            position: 'absolute', left: `calc(${(d / 3) * 100}% - 5px)`,
            width: d === pos ? 12 : 8, height: d === pos ? 12 : 8,
            top: d === pos ? 2 : 4,
            borderRadius: 99,
            background: d <= pos ? WIRE.ink : WIRE.line2,
          }}/>
        ))}
      </div>
    </div>
  );
}

function ThemeRow({ inline }) {
  const themes = [
    { id: 'light', label: 'Light', bg: '#fff', fg: WIRE.ink, border: WIRE.line },
    { id: 'sepia', label: 'Sepia', bg: '#f5ecd9', fg: '#5a4a2a', border: '#e6d9b6' },
    { id: 'dark',  label: 'Dark',  bg: '#1c1c1f', fg: '#fff', border: '#1c1c1f' },
  ];
  return (
    <div style={{ padding: inline ? 0 : '12px 16px' }}>
      {!inline && <div style={{ fontSize: 14, fontWeight: 500, marginBottom: 10 }}>Theme</div>}
      <div style={{ display: 'flex', gap: 8 }}>
        {themes.map((t, i) => (
          <div key={t.id} className="w-tap" style={{
            flex: 1, padding: '10px 8px', borderRadius: 10,
            background: t.bg, color: t.fg,
            border: `1.5px solid ${i === 0 ? WIRE.ink : t.border}`,
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
          }}>
            <div style={{ width: 24, height: 14, borderRadius: 2, border: `1px solid ${t.fg}`, opacity: .4 }}/>
            <div style={{ fontSize: 11.5, fontWeight: 500 }}>{t.label}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

function SettingsTabbed({ ctx, langObj, transObj }) {
  const [tab, setTab] = React.useState('translation');
  const tabs = [
    { id: 'translation', label: 'Translation' },
    { id: 'type', label: 'Typography' },
    { id: 'help', label: 'Help' },
  ];
  return (
    <div>
      <div style={{ padding: '0 16px 12px', display: 'flex', gap: 6 }}>
        {tabs.map((t) => {
          const on = tab === t.id;
          return (
            <div key={t.id} className="w-tap" onClick={() => setTab(t.id)} style={{
              flex: 1, padding: '8px 0', borderRadius: 8,
              background: on ? WIRE.ink : WIRE.fill,
              color: on ? '#fff' : WIRE.ink2,
              fontSize: 12, fontWeight: 600, textAlign: 'center',
            }}>{t.label}</div>
          );
        })}
      </div>

      {tab === 'translation' && (
        <div style={{ padding: '0 16px' }}>
          <WireBox p={14} radius={12}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 12 }}>
              <div style={{ width: 44, height: 44, borderRadius: 9, background: WIRE.ink, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: WIRE.mono, fontWeight: 700, fontSize: 13 }}>{transObj.abbr}</div>
              <div>
                <div style={{ fontSize: 14, fontWeight: 600 }}>{transObj.name}</div>
                <div style={{ fontSize: 11.5, color: WIRE.mid, marginTop: 2 }}>{langObj.native} · {transObj.pub}</div>
              </div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginBottom: 12 }}>
              <Stat label="Books" v={transObj.books}/>
              <Stat label="Year" v={transObj.year}/>
            </div>
            <WireBtn size="sm" kind="outline" onClick={ctx.onChange} style={{ width: '100%' }}>Change translation</WireBtn>
          </WireBox>
        </div>
      )}
      {tab === 'type' && (
        <div style={{ padding: '0 16px' }}>
          <CardGroup title="Per-script fonts">
            {['Latin','Greek','Hebrew','Arabic','CJK'].map((s,i) => (
              <SettingsRow key={s} title={s} detail={['Charter','GFS Neohellenic','Frank Ruehl','Noto Naskh','Noto Serif'][i]} onClick={() => {}} last={i===4}/>
            ))}
          </CardGroup>
          <CardGroup title="Size">
            <SizeRow label="Text size" pos={2}/>
            <SizeRow label="Line spacing" pos={1} last/>
          </CardGroup>
        </div>
      )}
      {tab === 'help' && (
        <div style={{ padding: '0 16px' }}>
          <CardGroup>
            <SettingsRow icon={WireIcons.bug(14, WIRE.ink2)} title="Report a bug" onClick={() => {}}/>
            <SettingsRow icon={WireIcons.send(14, WIRE.ink2)} title="Submit feedback" onClick={() => {}} last/>
          </CardGroup>
          <div style={{ padding: '12px 0 12px', textAlign: 'center' }}>
            <div className="w-mono" style={{ fontSize: 10, color: WIRE.mid2 }}>Sola · v0.4.2 (build 1187)</div>
          </div>
        </div>
      )}
    </div>
  );
}

function Stat({ label, v }) {
  return (
    <div style={{ padding: '8px 10px', background: WIRE.fill, borderRadius: 8 }}>
      <div className="w-mono" style={{ fontSize: 10, color: WIRE.mid, textTransform: 'uppercase' }}>{label}</div>
      <div className="w-mono" style={{ fontSize: 15, fontWeight: 600, marginTop: 2 }}>{v}</div>
    </div>
  );
}

Object.assign(window, {
  LANGUAGES, TRANSLATIONS_EN,
  WireHeader, WireSearchField,
  LanguageScreen, LanguageDetectScreen, TranslationPicker, TranslationStep2Host, CompleteScreen,
  SearchScreen, ReaderScreen, SettingsScreen,
});
