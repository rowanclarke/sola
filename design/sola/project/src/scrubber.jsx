// Book Scrubber — press-and-hold + variable-speed scrubbing across all 66 books.
//
// Behaviour:
//   • Resting:     thin strip, current-position dot, "hold to navigate" hint
//   • Press 180ms: blooms; floating callout shows Book · Chapter above finger
//   • Drag X:      moves position
//   • Drag Y up:   reduces gain (precision: 1× → 0.5× → 0.25× → 0.1×)
//   • Release:     commits position
//
// Pattern reference: Apple Books page slider + iOS Music variable-speed scrub.

const BIBLE_BOOKS = [
  ['Genesis','Gen',50,'OT'],['Exodus','Exo',40,'OT'],['Leviticus','Lev',27,'OT'],['Numbers','Num',36,'OT'],['Deuteronomy','Deu',34,'OT'],
  ['Joshua','Jos',24,'OT'],['Judges','Jdg',21,'OT'],['Ruth','Rut',4,'OT'],['1 Samuel','1Sa',31,'OT'],['2 Samuel','2Sa',24,'OT'],
  ['1 Kings','1Ki',22,'OT'],['2 Kings','2Ki',25,'OT'],['1 Chronicles','1Ch',29,'OT'],['2 Chronicles','2Ch',36,'OT'],['Ezra','Ezr',10,'OT'],
  ['Nehemiah','Neh',13,'OT'],['Esther','Est',10,'OT'],['Job','Job',42,'OT'],['Psalms','Psa',150,'OT'],['Proverbs','Pro',31,'OT'],
  ['Ecclesiastes','Ecc',12,'OT'],['Song of Solomon','Sng',8,'OT'],['Isaiah','Isa',66,'OT'],['Jeremiah','Jer',52,'OT'],['Lamentations','Lam',5,'OT'],
  ['Ezekiel','Eze',48,'OT'],['Daniel','Dan',12,'OT'],['Hosea','Hos',14,'OT'],['Joel','Joe',3,'OT'],['Amos','Amo',9,'OT'],
  ['Obadiah','Oba',1,'OT'],['Jonah','Jon',4,'OT'],['Micah','Mic',7,'OT'],['Nahum','Nah',3,'OT'],['Habakkuk','Hab',3,'OT'],
  ['Zephaniah','Zep',3,'OT'],['Haggai','Hag',2,'OT'],['Zechariah','Zec',14,'OT'],['Malachi','Mal',4,'OT'],
  ['Matthew','Mat',28,'NT'],['Mark','Mrk',16,'NT'],['Luke','Luk',24,'NT'],['John','Jhn',21,'NT'],['Acts','Act',28,'NT'],
  ['Romans','Rom',16,'NT'],['1 Corinthians','1Co',16,'NT'],['2 Corinthians','2Co',13,'NT'],['Galatians','Gal',6,'NT'],['Ephesians','Eph',6,'NT'],
  ['Philippians','Php',4,'NT'],['Colossians','Col',4,'NT'],['1 Thessalonians','1Th',5,'NT'],['2 Thessalonians','2Th',3,'NT'],
  ['1 Timothy','1Ti',6,'NT'],['2 Timothy','2Ti',4,'NT'],['Titus','Tit',3,'NT'],['Philemon','Phm',1,'NT'],
  ['Hebrews','Heb',13,'NT'],['James','Jas',5,'NT'],['1 Peter','1Pe',5,'NT'],['2 Peter','2Pe',3,'NT'],
  ['1 John','1Jn',5,'NT'],['2 John','2Jn',1,'NT'],['3 John','3Jn',1,'NT'],['Jude','Jud',1,'NT'],['Revelation','Rev',22,'NT'],
].map(([name, abbr, ch, t]) => ({ name, abbr, ch, testament: t }));

const BIBLE_TOTAL = BIBLE_BOOKS.reduce((s, b) => s + b.ch, 0); // 1189

// Pre-compute cumulative start indices
const BOOK_STARTS = (() => {
  const out = [];
  let c = 0;
  for (const b of BIBLE_BOOKS) { out.push(c); c += b.ch; }
  return out;
})();
// Testament boundary in global chapter index
const NT_START = BIBLE_BOOKS.findIndex((b) => b.testament === 'NT');
const NT_START_INDEX = BOOK_STARTS[NT_START];

function chapterToInfo(i) {
  const clamp = Math.max(0, Math.min(BIBLE_TOTAL - 1, Math.round(i)));
  let bi = 0;
  for (let j = BIBLE_BOOKS.length - 1; j >= 0; j--) {
    if (clamp >= BOOK_STARTS[j]) { bi = j; break; }
  }
  return { book: BIBLE_BOOKS[bi], chapter: clamp - BOOK_STARTS[bi] + 1, bookIndex: bi };
}

function bookToIndex(bookName, chapter = 1) {
  const i = BIBLE_BOOKS.findIndex((b) => b.name === bookName);
  if (i < 0) return 0;
  return BOOK_STARTS[i] + Math.max(0, chapter - 1);
}

// ────────────────────────────────────────────────────────
// Scrubber component
// ────────────────────────────────────────────────────────
function Scrubber({ initialIndex = bookToIndex('John', 3), onCommit, onChange, theme = 'light', mockActive = false, mockPrecision = 1 }) {
  const stripRef = React.useRef(null);
  const [idx, setIdx] = React.useState(initialIndex);
  const [active, setActive] = React.useState(mockActive);
  const [precision, setPrecision] = React.useState(mockPrecision);
  const [pointerX, setPointerX] = React.useState(0);

  const info = chapterToInfo(idx);
  const ratio = idx / (BIBLE_TOTAL - 1);

  const onPointerDown = (e) => {
    if (mockActive) return; // canvas-static demos don't accept input
    e.preventDefault();
    if (!stripRef.current) return;
    const rect = stripRef.current.getBoundingClientRect();
    const stripY = rect.top + rect.height / 2;

    let isActive = false;
    let baseX = e.clientX;
    let baseIdx = idx;
    let lastX = e.clientX;

    const activate = () => {
      isActive = true;
      // jump-to-touch: place position under finger immediately
      const r = (e.clientX - rect.left) / rect.width;
      const start = Math.round(Math.max(0, Math.min(1, r)) * (BIBLE_TOTAL - 1));
      baseIdx = start;
      baseX = e.clientX;
      setActive(true);
      setIdx(start);
      setPointerX(e.clientX - rect.left);
      onChange && onChange(start);
    };

    const holdTimer = setTimeout(activate, 180);

    const move = (ev) => {
      if (!isActive) {
        // cancel hold if finger moves too much before activation
        if (Math.abs(ev.clientX - lastX) > 8) {
          clearTimeout(holdTimer);
        }
        return;
      }
      // variable-speed scrubbing: gain falls off with vertical distance from strip
      const dy = Math.max(0, stripY - ev.clientY); // only when finger moves UP
      const p = dy < 30 ? 1 : dy < 80 ? 0.5 : dy < 160 ? 0.25 : 0.1;
      setPrecision(p);

      const dxScreen = ev.clientX - baseX;
      const dxScaled = dxScreen * p;
      const dRatio = dxScaled / rect.width;
      const newIdx = Math.max(0, Math.min(BIBLE_TOTAL - 1, Math.round(baseIdx + dRatio * (BIBLE_TOTAL - 1))));
      setIdx(newIdx);
      setPointerX(Math.max(0, Math.min(rect.width, ev.clientX - rect.left)));
      onChange && onChange(newIdx);
    };

    const up = () => {
      clearTimeout(holdTimer);
      const wasActive = isActive;
      isActive = false;
      setActive(false);
      setPrecision(1);
      document.removeEventListener('pointermove', move);
      document.removeEventListener('pointerup', up);
      document.removeEventListener('pointercancel', up);
      if (wasActive) onCommit && onCommit(idx);
    };

    document.addEventListener('pointermove', move);
    document.addEventListener('pointerup', up);
    document.addEventListener('pointercancel', up);
  };

  // Visual: dark theme inverts ink/bg
  const C = {
    bg: WIRE.bg,
    fill: WIRE.fill,
    line: WIRE.line2,
    ink: WIRE.ink,
    mid: WIRE.mid,
    mid2: WIRE.mid2,
  };

  // Precision label
  const pctLabel = precision === 1 ? 'Full speed' : `Precision ${Math.round(precision * 100)}%`;

  // Major labels along the strip
  const majors = [
    { i: 0, label: 'Gen' },
    { i: BOOK_STARTS[18], label: 'Psa' }, // Psalms
    { i: BOOK_STARTS[22], label: 'Isa' }, // Isaiah
    { i: NT_START_INDEX, label: 'Mat' },  // NT start
    { i: BOOK_STARTS[44], label: 'Rom' }, // Romans
    { i: BIBLE_TOTAL - 22, label: 'Rev' }, // Revelation
  ];

  return (
    <div style={{
      flexShrink: 0,
      padding: '8px 16px 16px',
      background: C.bg,
      borderTop: `1px solid ${C.line}`,
      position: 'relative',
      touchAction: 'none',
      userSelect: 'none',
    }}>
      {/* Active-state floating callout (above the strip) */}
      {active && (
        <ScrubberCallout
          info={info}
          ratio={ratio}
          pointerX={pointerX}
          precision={precision}
          pctLabel={pctLabel}
        />
      )}

      {/* Top label row */}
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        height: 16, marginBottom: 6,
        opacity: active ? 0 : 1, transition: 'opacity .15s',
      }}>
        <div style={{
          fontFamily: WIRE.mono, fontSize: 10, color: C.mid, letterSpacing: '.02em',
        }}>Hold &amp; drag to navigate</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 4,
          fontFamily: WIRE.mono, fontSize: 10.5, fontWeight: 600, color: C.ink,
        }}>
          <span>{info.book.abbr} {info.chapter}</span>
          <span style={{ color: C.mid2, fontWeight: 400 }}>·</span>
          <span style={{ color: C.mid, fontWeight: 400 }} className="w-mono">{idx + 1}/{BIBLE_TOTAL}</span>
        </div>
      </div>

      {/* The strip */}
      <div
        ref={stripRef}
        onPointerDown={onPointerDown}
        style={{
          position: 'relative',
          height: active ? 28 : 22,
          borderRadius: active ? 8 : 11,
          background: active ? C.ink : C.fill,
          border: `1px solid ${active ? C.ink : C.line}`,
          transition: 'height .15s, border-radius .15s, background .15s',
          cursor: 'grab',
          overflow: 'visible',
        }}>
        {/* Tick marks per book — visible always, denser & contrasty when active */}
        <div style={{ position: 'absolute', inset: 0 }}>
          {BIBLE_BOOKS.map((b, i) => {
            const r = BOOK_STARTS[i] / (BIBLE_TOTAL - 1);
            const isCurrent = i === info.bookIndex;
            return (
              <div key={i} style={{
                position: 'absolute', left: `${r * 100}%`,
                top: active ? 6 : 7, bottom: active ? 6 : 7,
                width: 1,
                background: active
                  ? (isCurrent ? '#fff' : 'rgba(255,255,255,.22)')
                  : (isCurrent ? C.ink : C.line),
                transition: 'background .15s',
              }}/>
            );
          })}
        </div>

        {/* OT/NT division — bolder bar */}
        <div style={{
          position: 'absolute',
          left: `${(NT_START_INDEX / (BIBLE_TOTAL - 1)) * 100}%`,
          top: -2, bottom: -2,
          width: 2,
          background: active ? '#fff' : C.mid,
          opacity: active ? .55 : .35,
          transform: 'translateX(-50%)',
        }}/>

        {/* Major book labels — visible when active */}
        {active && (
          <div style={{ position: 'absolute', inset: 0 }}>
            {majors.map((m) => (
              <div key={m.label} style={{
                position: 'absolute',
                left: `${(m.i / (BIBLE_TOTAL - 1)) * 100}%`,
                top: '50%', transform: 'translate(-50%, -50%)',
                fontFamily: WIRE.mono, fontSize: 9, fontWeight: 600,
                color: 'rgba(255,255,255,.55)',
                letterSpacing: '.02em', whiteSpace: 'nowrap',
                pointerEvents: 'none',
              }}>{m.label}</div>
            ))}
          </div>
        )}

        {/* The thumb / playhead */}
        <div style={{
          position: 'absolute',
          left: `${ratio * 100}%`,
          top: '50%',
          transform: 'translate(-50%, -50%)',
          width: active ? 4 : 12,
          height: active ? 36 : 12,
          borderRadius: active ? 2 : 6,
          background: active ? '#fff' : C.ink,
          boxShadow: active ? '0 0 0 4px rgba(255,255,255,.18)' : '0 1px 2px rgba(0,0,0,.15)',
          transition: 'width .15s, height .15s, border-radius .15s',
          pointerEvents: 'none',
        }}/>
      </div>

      {/* Bottom anchor row (testament hint) — only when inactive */}
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        marginTop: 4,
        opacity: active ? 0 : 1, transition: 'opacity .15s',
        fontFamily: WIRE.mono, fontSize: 9.5, color: C.mid2, letterSpacing: '.04em',
      }}>
        <span>OT</span>
        <span style={{ flex: 1, height: 0 }}/>
        <span style={{ paddingRight: `${(1 - NT_START_INDEX / (BIBLE_TOTAL - 1)) * 100}%` }}>|</span>
        <span style={{ flex: 1, height: 0 }}/>
        <span>NT</span>
      </div>
    </div>
  );
}

// ────────────────────────────────────────────────────────
// Floating callout that follows the finger when scrubbing
// ────────────────────────────────────────────────────────
function ScrubberCallout({ info, ratio, pointerX, precision, pctLabel }) {
  // Anchor callout to the playhead's X (clamped); tether falls to the strip.
  const calloutW = 160;
  return (
    <div style={{
      position: 'absolute',
      left: 16, right: 16,
      bottom: 'calc(100% - 6px)', // sits above the scrubber area
      pointerEvents: 'none',
      zIndex: 30,
    }}>
      <div style={{ position: 'relative', height: 90 }}>
        {/* Tether */}
        <div style={{
          position: 'absolute',
          left: `${ratio * 100}%`,
          bottom: -6, top: 70,
          width: 1, background: WIRE.ink,
          opacity: .35,
        }}/>
        {/* Precision badge — fades in as it falls below 100% */}
        <div style={{
          position: 'absolute', top: 0, right: 0,
          padding: '3px 8px',
          background: precision < 1 ? WIRE.ink : 'transparent',
          color: precision < 1 ? '#fff' : WIRE.mid,
          borderRadius: 99,
          fontFamily: WIRE.mono, fontSize: 10, fontWeight: 600,
          opacity: precision < 1 ? 1 : 0.6,
          transition: 'background .15s, color .15s',
        }}>{pctLabel}</div>
        {/* Precision hint */}
        <div style={{
          position: 'absolute', top: 4, left: 0,
          display: 'flex', alignItems: 'center', gap: 5,
          color: WIRE.mid,
        }}>
          <svg width="10" height="10" viewBox="0 0 10 10" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round">
            <path d="M5 8V2M2 5l3-3 3 3"/>
          </svg>
          <span style={{ fontFamily: WIRE.mono, fontSize: 10, letterSpacing: '.02em' }}>
            Drag up to fine-tune
          </span>
        </div>

        {/* Callout chip */}
        <div style={{
          position: 'absolute',
          bottom: 0,
          left: `clamp(0px, calc(${ratio * 100}% - ${calloutW / 2}px), calc(100% - ${calloutW}px))`,
          width: calloutW,
          background: WIRE.ink,
          color: '#fff',
          borderRadius: 12,
          padding: '10px 14px',
          boxShadow: '0 8px 24px rgba(0,0,0,.25)',
          textAlign: 'center',
        }}>
          <div style={{
            fontFamily: WIRE.mono, fontSize: 9.5, letterSpacing: '.08em',
            color: 'rgba(255,255,255,.55)', textTransform: 'uppercase',
            marginBottom: 2,
          }}>{info.book.testament === 'OT' ? 'Old Testament' : 'New Testament'}</div>
          <div style={{ fontSize: 17, fontWeight: 700, letterSpacing: '-0.01em', lineHeight: 1.1 }}>
            {info.book.name}
          </div>
          <div style={{ fontSize: 12, color: 'rgba(255,255,255,.7)', marginTop: 2 }}>
            Chapter <span className="w-mono">{info.chapter}</span>
            <span style={{ opacity: .5 }}> · of </span>
            <span className="w-mono">{info.book.ch}</span>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  BIBLE_BOOKS, BIBLE_TOTAL, BOOK_STARTS, NT_START_INDEX,
  chapterToInfo, bookToIndex,
  Scrubber, ScrubberCallout,
});
