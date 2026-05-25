// Windowed scrubber with edge auto-scroll.
//
// Pattern: position control inside the visible 20-chapter window, +
// rate control as the finger nears the strip edges (velocity = f(% of
// strip width from edge)). References: Pinterest card-drag-near-edge,
// macOS Finder window-edge auto-scroll, map editors' edge-pan.
//
// Behaviour:
//   • Resting:     "Book Chapter" label only (no visible strip)
//   • Press 180ms: activates; strip raises up to the finger
//   • Drag X:      thumb tracks finger, idx = winStart + ratio·(N-1)
//   • Near edges:  velocity gears auto-scroll the window
//                  edge          400 ch/s   (past the strip)
//                  0-5%          200 ch/s
//                  5-10%          80 ch/s
//                  10-20%         30 ch/s
//                  20-35%          8 ch/s
//                  middle 30%      —  (1:1 position only)
//   • Release:     commits position

const VISIBLE_CHAPTERS = 20;
const STRIP_H = 36;
const STRIP_BOTTOM = 8;     // resting offset from container bottom
const ACTIVE_RAISE = 120;   // fixed distance strip rises on press-hold

function velocityFromFx(fx, width) {
  // fx: finger x relative to strip left; can be < 0 or > width
  if (width <= 0) return { v: 0, dir: 0 };
  if (fx < 0) return { v: 400, dir: -1 };
  if (fx > width) return { v: 400, dir: 1 };
  const leftPct = fx / width;
  const rightPct = (width - fx) / width;
  const isLeft = leftPct <= rightPct;
  const pct = isLeft ? leftPct : rightPct;
  const dir = isLeft ? -1 : 1;
  let v = 0;
  if (pct < 0.05) v = 200;
  else if (pct < 0.10) v = 80;
  else if (pct < 0.20) v = 30;
  else if (pct < 0.35) v = 8;
  else return { v: 0, dir: 0 };
  return { v, dir };
}

function ScrubberWindowed({
  initialIndex = bookToIndex('John', 3),
  onCommit, onChange,
  mockActive = false,
  mockFingerX = 0.5,   // 0..1 within strip width (can exceed for "past edge")
  mockWinStart,
}) {
  const containerRef = React.useRef(null);
  const stripRef = React.useRef(null);
  const initWS = mockWinStart != null
    ? mockWinStart
    : Math.max(0, Math.min(BIBLE_TOTAL - VISIBLE_CHAPTERS, initialIndex - Math.floor(VISIBLE_CHAPTERS / 2)));

  const [idx, setIdx] = React.useState(initialIndex);
  const [winStart, setWinStart] = React.useState(initWS);
  const [active, setActive] = React.useState(mockActive);
  // thumbRatio: where the finger sits across the strip (clamped 0..1)
  const initialRatio = mockActive
    ? Math.max(0, Math.min(1, mockFingerX))
    : (initialIndex - initWS) / (VISIBLE_CHAPTERS - 1);
  const [thumbRatio, setThumbRatio] = React.useState(initialRatio);
  const raiseY = active ? ACTIVE_RAISE : 0;

  // Initial velocity (for static mock states)
  const initialVel = mockActive
    ? velocityFromFx(mockFingerX, 1)
    : { v: 0, dir: 0 };
  const [vel, setVel] = React.useState(initialVel);

  const info = chapterToInfo(Math.round(idx));

  // ── Derive idx from winStart + thumbRatio ──
  React.useEffect(() => {
    const newIdx = Math.max(0, Math.min(BIBLE_TOTAL - 1, winStart + thumbRatio * (VISIBLE_CHAPTERS - 1)));
    setIdx(newIdx);
    if (onChange) onChange(Math.round(newIdx));
  }, [winStart, thumbRatio]);

  // ── RAF: edge-driven auto-scroll ──
  React.useEffect(() => {
    if (mockActive) return;       // canvas-static demos hold their position
    if (!active || vel.v === 0) return;
    let last = performance.now();
    let raf;
    const tick = (t) => {
      const dt = Math.min(0.05, (t - last) / 1000);
      last = t;
      setWinStart((ws) => Math.max(0, Math.min(BIBLE_TOTAL - VISIBLE_CHAPTERS, ws + vel.v * vel.dir * dt)));
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [active, vel.v, vel.dir]);

  // ── Sync window back to centre on release ──
  React.useEffect(() => {
    if (active) return;
    const half = Math.floor(VISIBLE_CHAPTERS / 2);
    const target = Math.max(0, Math.min(BIBLE_TOTAL - VISIBLE_CHAPTERS, Math.round(idx) - half));
    setWinStart(target);
    setThumbRatio((Math.round(idx) - target) / (VISIBLE_CHAPTERS - 1));
  }, [active]);

  // ── Pointer / touch handling ──
  const onPointerDown = (e) => {
    if (mockActive) return;
    e.preventDefault();
    if (!stripRef.current || !containerRef.current) return;
    const stripRect = stripRef.current.getBoundingClientRect();
    const containerRect = containerRef.current.getBoundingClientRect();
    let isActive = false;
    let startX = e.clientX;
    let startY = e.clientY;

    const updateFromPointer = (cx /*, cy */) => {
      const stripW = stripRect.width;
      const fx = cx - stripRect.left;
      const ratio = Math.max(0, Math.min(1, fx / stripW));
      setThumbRatio(ratio);
      setVel(velocityFromFx(fx, stripW));
    };

    const activate = () => {
      isActive = true;
      setActive(true);
      updateFromPointer(e.clientX, e.clientY);
    };
    const holdTimer = setTimeout(activate, 180);

    const move = (ev) => {
      if (!isActive) {
        // tolerate small jitter; activate on real movement
        if (Math.abs(ev.clientX - startX) > 8 || Math.abs(ev.clientY - startY) > 8) {
          clearTimeout(holdTimer);
          activate();
        }
        return;
      }
      updateFromPointer(ev.clientX);
    };
    const up = () => {
      clearTimeout(holdTimer);
      const wasActive = isActive;
      isActive = false;
      setActive(false);
      setVel({ v: 0, dir: 0 });
      document.removeEventListener('pointermove', move);
      document.removeEventListener('pointerup', up);
      document.removeEventListener('pointercancel', up);
      if (wasActive && onCommit) setTimeout(() => onCommit(Math.round(idx)), 0);
    };
    document.addEventListener('pointermove', move);
    document.addEventListener('pointerup', up);
    document.addEventListener('pointercancel', up);
  };

  // ── Build window contents: split into book-spans ──
  const winEnd = Math.min(BIBLE_TOTAL - 1, winStart + VISIBLE_CHAPTERS - 1);
  const windowBooks = [];
  for (let c = Math.floor(winStart); c <= winEnd; c++) {
    const ci = chapterToInfo(c);
    const last = windowBooks[windowBooks.length - 1];
    if (last && last.bookIndex === ci.bookIndex) last.end = c;
    else windowBooks.push({ bookIndex: ci.bookIndex, book: ci.book, start: c, end: c });
  }
  // Bands are positioned relative to fractional winStart so they slide smoothly
  const winSpan = VISIBLE_CHAPTERS;
  const winStartF = winStart;

  // Active visual: black strip
  const stripBg = active ? WIRE.ink : 'transparent';
  const stripFg = active ? '#fff' : WIRE.ink;
  const stripLine = active ? 'rgba(255,255,255,.18)' : WIRE.line;

  return (
    <div ref={containerRef} style={{
      flexShrink: 0,
      background: WIRE.bg,
      borderTop: `1px solid ${WIRE.line2}`,
      position: 'relative',
      touchAction: 'none',
      userSelect: 'none',
      padding: `14px 16px ${STRIP_BOTTOM + 8}px`,
      minHeight: 56,
    }}>
      {/* Resting hit area — invisible but interactive across the whole bar */}
      {!active && (
        <div onPointerDown={onPointerDown} style={{
          position: 'absolute',
          inset: 0,
          cursor: 'pointer',
        }}/>
      )}

      {/* Book + chapter label — centered at rest, floats above strip when active */}
      <div style={{
        position: 'absolute',
        left: 0, right: 0,
        bottom: active
          ? `${STRIP_BOTTOM + STRIP_H + raiseY + 8}px`
          : '50%',
        transform: active ? 'translateY(0)' : 'translateY(50%)',
        textAlign: 'center',
        pointerEvents: 'none',
        transition: active ? 'bottom .04s linear' : 'bottom .2s ease-out, transform .2s ease-out',
        fontFamily: WIRE.mono,
        fontSize: 13,
        fontWeight: 600,
        color: WIRE.ink,
        letterSpacing: '-.005em',
        zIndex: 10,
        whiteSpace: 'nowrap',
      }}>
        {info.book.abbr} {info.chapter}
      </div>

      {/* The strip — hidden at rest, raises up to finger on hold */}
      <div
        ref={stripRef}
        onPointerDown={onPointerDown}
        style={{
          position: 'absolute',
          left: 16, right: 16,
          bottom: STRIP_BOTTOM,
          height: STRIP_H,
          borderRadius: 8,
          background: stripBg,
          border: `1px solid ${active ? WIRE.ink : 'transparent'}`,
          transform: `translateY(${-raiseY}px)`,
          transition: active
            ? 'background .12s, border-color .12s'
            : 'transform .22s ease-out, background .15s, border-color .15s, opacity .18s',
          opacity: active ? 1 : 0,
          overflow: 'hidden',
          cursor: 'grab',
        }}>
        {/* Book bands. Each label is positioned in strip coordinates,
            anchored to max(bookStart, visibleLeft) so as the book scrolls
            in from the right the label hugs the book's true start, and
            once the start passes off-screen-left the label sticks to the
            strip's left edge until the book itself exits — no jitter. */}
        <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
          {/* Dividers between visible books */}
          {windowBooks.map((bk, i) => {
            if (i >= windowBooks.length - 1) return null;
            const dividerLeftR = (bk.end + 1 - winStartF) / winSpan;
            return (
              <div key={`d-${bk.bookIndex}`} style={{
                position: 'absolute',
                left: `${dividerLeftR * 100}%`,
                top: 0, bottom: 0,
                width: 1,
                background: stripLine,
              }}/>
            );
          })}
          {/* Sticky-left book labels */}
          {windowBooks.map((bk) => {
            const bookStart = BOOK_STARTS[bk.bookIndex];
            const bookEnd = bookStart + bk.book.ch - 1;
            // Label left position: clamped so it can't escape past the
            // book's visible right edge (4px breathing room).
            const anchorR = (Math.max(bookStart, winStartF) - winStartF) / winSpan;
            const maxR = (bookEnd + 1 - winStartF) / winSpan;
            const isCurrent = bk.bookIndex === info.bookIndex;
            const visWidthR = (bk.end - bk.start + 1) / winSpan;
            if (visWidthR * 100 <= 6) return null;
            return (
              <div key={`l-${bk.bookIndex}`} style={{
                position: 'absolute',
                left: `calc(${anchorR * 100}% + 8px)`,
                maxWidth: `calc(${(maxR - anchorR) * 100}% - 12px)`,
                top: 0, bottom: 0,
                display: 'flex', alignItems: 'center',
                color: stripFg,
                opacity: isCurrent ? 1 : 0.55,
                pointerEvents: 'none',
                fontFamily: WIRE.mono, fontSize: 10.5,
                fontWeight: isCurrent ? 700 : 500,
                letterSpacing: '.01em',
                whiteSpace: 'nowrap',
                lineHeight: 1.1,
                overflow: 'hidden',
              }}>{bk.book.abbr}</div>
            );
          })}
        </div>

        {/* The thumb */}
        <div style={{
          position: 'absolute',
          left: `${thumbRatio * 100}%`,
          top: -3, bottom: -3,
          width: 3,
          background: '#fff',
          transform: 'translateX(-50%)',
          boxShadow: '0 0 0 5px rgba(255,255,255,.15)',
        }}/>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScrubberWindowed, VISIBLE_CHAPTERS,
  velocityFromFx,
});
