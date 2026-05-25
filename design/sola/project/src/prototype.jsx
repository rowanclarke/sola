// Click-through prototype — single phone, real navigation through the flow.
// Reader is the home; Search and Settings open as full-screen overlays from
// the header icons. The bottom tab bar is gone — its replacement is the
// press-and-hold Scrubber that lives at the bottom of the reader.

function Prototype() {
  const [step, setStep] = React.useState('lang'); // lang | trans | done | app
  const [overlay, setOverlay] = React.useState(null); // null | 'search' | 'settings'
  const [lang, setLang] = React.useState('en');
  const [trans, setTrans] = React.useState(null);
  const [transPickerOpen, setTransPickerOpen] = React.useState(false);

  const goLang = () => setStep('trans');
  const goTrans = () => setStep('done');
  const goDone = () => setStep('app');

  const ctx = {
    lang, setLang,
    trans, setTrans,
    onChange: () => setTransPickerOpen(true),
    onOpenSearch: () => setOverlay('search'),
    onOpenSettings: () => setOverlay('settings'),
    onClose: () => setOverlay(null),
  };

  const reset = () => {
    setStep('lang');
    setTrans(null);
    setOverlay(null);
    setTransPickerOpen(false);
  };

  return (
    <div style={{ position: 'relative', width: '100%', height: '100%' }}>
      {step === 'lang' && (
        <LanguageDetectScreen ctx={{ ...ctx, onContinue: goLang }}/>
      )}
      {step === 'trans' && (
        <TranslationPicker ctx={{ ...ctx, onContinue: goTrans }} onClose={() => setStep('lang')} mode="onboarding"/>
      )}
      {step === 'done' && (
        <CompleteScreen ctx={{ ...ctx, onContinue: goDone, onChange: () => setStep('lang') }}/>
      )}
      {step === 'app' && (
        <>
          <ReaderScreen ctx={ctx}/>
          {/* Overlays slide up over the reader */}
          {overlay === 'search' && (
            <div style={{ position: 'absolute', inset: 0, animation: 'w-sheet-up .25s cubic-bezier(.2,.7,.3,1)' }}>
              <SearchScreen ctx={ctx}/>
            </div>
          )}
          {overlay === 'settings' && (
            <div style={{ position: 'absolute', inset: 0, animation: 'w-sheet-up .25s cubic-bezier(.2,.7,.3,1)' }}>
              <SettingsScreen ctx={ctx} variant="cards"/>
            </div>
          )}
          {transPickerOpen && (
            <TranslationPicker ctx={ctx} onClose={() => setTransPickerOpen(false)} mode="settings"/>
          )}
        </>
      )}

      {/* tiny reset chip */}
      <div onClick={reset} className="w-tap" style={{
        position: 'absolute', top: -28, right: 4,
        fontFamily: WIRE.mono, fontSize: 10, color: WIRE.mid,
        padding: '3px 8px', borderRadius: 99,
        background: WIRE.card, border: `1px solid ${WIRE.line2}`,
        cursor: 'pointer', userSelect: 'none',
      }}>↻ reset</div>
    </div>
  );
}

Object.assign(window, { Prototype });
