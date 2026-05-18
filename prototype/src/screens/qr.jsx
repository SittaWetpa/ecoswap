// QR exchange — full flow:
//   stage: 'show' (default), 'scan', 'success'
// 60-second countdown clearly visible. Anti-fraud explainer.

const QRPattern = ({ size = 220, seed = 'abc', dark = '#1A1A1A' }) => {
  // Procedurally draw a faux QR — deterministic from seed.
  const grid = 25;
  const cell = size / grid;
  // Simple hash
  const cells = [];
  let h = 0;
  for (let i = 0; i < seed.length; i++) h = (h * 31 + seed.charCodeAt(i)) | 0;
  const rand = (i) => {
    const x = Math.sin((i + h) * 12.9898) * 43758.5453;
    return x - Math.floor(x);
  };
  for (let y = 0; y < grid; y++) {
    for (let x = 0; x < grid; x++) {
      // finder patterns at three corners
      const inFinder = (x < 8 && y < 8) || (x >= grid - 8 && y < 8) || (x < 8 && y >= grid - 8);
      const dot = !inFinder && rand(y * grid + x) > 0.5;
      if (dot) cells.push(<rect key={`${x},${y}`} x={x*cell} y={y*cell} width={cell} height={cell} fill={dark}/>);
    }
  }
  const finder = (gx, gy) => (
    <>
      <rect x={gx*cell} y={gy*cell} width={cell*7} height={cell*7} fill={dark}/>
      <rect x={(gx+1)*cell} y={(gy+1)*cell} width={cell*5} height={cell*5} fill="#fff"/>
      <rect x={(gx+2)*cell} y={(gy+2)*cell} width={cell*3} height={cell*3} fill={dark}/>
    </>
  );
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ borderRadius: 12, background: '#fff' }}>
      {cells}
      {finder(0, 0)}
      {finder(grid - 7, 0)}
      {finder(0, grid - 7)}
    </svg>
  );
};

const QRScreen = ({ chat, onBack, onComplete, density }) => {
  const [tab, setTab] = React.useState('show'); // show, scan
  const [stage, setStage] = React.useState('idle'); // idle, scanning, success
  const [seconds, setSeconds] = React.useState(60);
  const p = chat ? personById(chat.person) : personById('fah');
  const mine = chat ? itemById(chat.trade.mine) : itemById('mine-mug');
  const theirs = chat ? itemById(chat.trade.theirs) : itemById('kettle');

  React.useEffect(() => {
    if (stage === 'success') return;
    if (seconds <= 0) { setSeconds(60); return; }
    const id = setTimeout(() => setSeconds(s => s - 1), 1000);
    return () => clearTimeout(id);
  }, [seconds, stage]);

  // Reset timer when switching tab
  React.useEffect(() => { setSeconds(60); }, [tab]);

  if (stage === 'success') {
    return <QRSuccess person={p} mine={mine} theirs={theirs} onComplete={onComplete} />;
  }

  const dangerCountdown = seconds < 30;

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      <TopBar variant="hier" title="Confirm exchange" onBack={onBack} />

      {/* Trade summary */}
      <div style={{ padding: '8px 16px 16px', borderBottom: '1px solid var(--border)' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          background: 'var(--surface-alt)', borderRadius: 12, padding: 12,
        }}>
          <Avatar person={p} size={32} />
          <div style={{ flex: 1, minWidth: 0, fontSize: 13 }}>
            <div style={{ color: 'var(--text-secondary)', fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.4 }}>Swap with {p.name}</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
              <span style={{ fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{mine?.name}</span>
              <IconSwap size={12} style={{ color: 'var(--green-primary)', flexShrink: 0 }} />
              <span style={{ fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{theirs?.name}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Toggle */}
      <div style={{ padding: '12px 16px 0' }}>
        <div style={{ display: 'flex', background: 'var(--surface-alt)', borderRadius: 10, padding: 4 }}>
          {[{k:'show',l:'Show my QR'},{k:'scan',l:`Scan ${p.name}'s`}].map(t => (
            <button key={t.k} onClick={() => setTab(t.k)} style={{
              flex: 1, padding: '10px 0', border: 'none',
              background: tab === t.k ? 'var(--surface)' : 'transparent',
              color: tab === t.k ? 'var(--text-primary)' : 'var(--text-secondary)',
              boxShadow: tab === t.k ? '0 1px 2px rgba(0,0,0,0.06)' : 'none',
              borderRadius: 8, fontWeight: 500, fontSize: 13, cursor: 'pointer',
            }}>{t.l}</button>
          ))}
        </div>
      </div>

      {/* Body */}
      <div style={{ flex: 1, padding: '16px 16px 8px', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        {tab === 'show' ? (
          <>
            <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16, textAlign: 'center' }}>
              Show this to <b style={{ color: 'var(--text-primary)' }}>{p.name}</b> to confirm the swap.
            </div>
            <div style={{ position: 'relative', padding: 16, background: '#fff', borderRadius: 16, border: '1px solid var(--border)' }}>
              <QRPattern size={220} seed={`me-${chat?.id || 'demo'}`} />
              {/* Corner markers */}
              <CornerMarkers />
            </div>
            <Countdown seconds={seconds} danger={dangerCountdown} />
            <FraudExplainer />
          </>
        ) : (
          <>
            <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16, textAlign: 'center' }}>
              Point your camera at <b style={{ color: 'var(--text-primary)' }}>{p.name}'s</b> QR.
            </div>
            <ScannerViewfinder onScan={() => { setStage('success'); }} />
            <Countdown seconds={seconds} danger={dangerCountdown} label="Their code expires in" />
            <div style={{ width: '100%', marginTop: 12, padding: 10, background: 'var(--surface-alt)', borderRadius: 8, display: 'flex', gap: 8, alignItems: 'center' }}>
              <input placeholder="Or paste code…" style={{
                flex: 1, border: 'none', background: 'transparent', outline: 'none',
                fontSize: 13, fontFamily: 'JetBrains Mono, monospace', color: 'var(--text-secondary)',
              }} value="ESW-9F4A-2B1C" readOnly />
              <button onClick={() => setStage('success')} style={{
                border: 'none', background: 'var(--green-primary)', color: '#fff',
                padding: '6px 10px', borderRadius: 6, fontSize: 12, fontWeight: 600, cursor: 'pointer',
              }}>Submit</button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

const Countdown = ({ seconds, danger, label = 'Expires in' }) => (
  <div style={{
    marginTop: 16,
    display: 'flex', alignItems: 'center', gap: 8,
    padding: '8px 14px', borderRadius: 9999,
    background: danger ? '#FFF1DD' : 'var(--surface-alt)',
    color: danger ? 'var(--warning)' : 'var(--text-secondary)',
    fontSize: 13, fontWeight: 500,
    animation: danger ? 'pulse 1s ease-in-out infinite' : 'none',
  }}>
    <IconClock size={14} />
    {label} <b style={{ fontVariantNumeric: 'tabular-nums', color: danger ? 'var(--warning)' : 'var(--text-primary)' }}>{seconds}s</b>
    <style>{`@keyframes pulse { 0%,100% { transform: scale(1); } 50% { transform: scale(1.04); } }`}</style>
  </div>
);

const CornerMarkers = () => (
  <>
    {[['tl', { top: 8, left: 8 }], ['tr', { top: 8, right: 8 }], ['bl', { bottom: 8, left: 8 }], ['br', { bottom: 8, right: 8 }]].map(([k, pos]) => (
      <div key={k} style={{ position: 'absolute', ...pos, width: 18, height: 18, pointerEvents: 'none' }}>
        <div style={{ position: 'absolute', width: 18, height: 3, background: 'var(--green-primary)', ...(k.includes('b') ? { bottom: 0 } : { top: 0 }) }} />
        <div style={{ position: 'absolute', width: 3, height: 18, background: 'var(--green-primary)', ...(k.includes('r') ? { right: 0 } : { left: 0 }) }} />
      </div>
    ))}
  </>
);

const ScannerViewfinder = ({ onScan }) => (
  <div style={{
    width: 220, height: 220, position: 'relative', borderRadius: 16,
    background: 'linear-gradient(135deg, #1a1a1a, #2a2a2a)', overflow: 'hidden',
  }}>
    {/* scan line */}
    <div style={{
      position: 'absolute', left: 16, right: 16, height: 2,
      background: 'var(--green-primary)', boxShadow: '0 0 12px var(--green-primary)',
      animation: 'scanLine 2.2s ease-in-out infinite',
    }} />
    <CornerMarkers />
    <button onClick={onScan} style={{
      position: 'absolute', bottom: 12, left: '50%', transform: 'translateX(-50%)',
      padding: '6px 12px', borderRadius: 9999, border: 'none',
      background: '#ffffff22', color: '#fff', fontSize: 11, cursor: 'pointer',
      backdropFilter: 'blur(4px)',
    }}>tap to simulate scan</button>
    <style>{`@keyframes scanLine { 0% { top: 16px; } 50% { top: 200px; } 100% { top: 16px; } }`}</style>
  </div>
);

const FraudExplainer = () => (
  <div style={{
    width: '100%', marginTop: 16, padding: '12px 14px',
    background: 'var(--surface-alt)', borderRadius: 10,
    display: 'flex', gap: 10, alignItems: 'flex-start',
  }}>
    <IconShield size={16} style={{ color: 'var(--green-primary)', marginTop: 2, flexShrink: 0 }} />
    <div style={{ fontSize: 12, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
      Each QR is signed server-side and expires in 60s. Both sides must scan to count toward your impact — solo scans don't.
    </div>
  </div>
);

const QRSuccess = ({ person, mine, theirs, onComplete }) => {
  const theirCat = CATEGORY[theirs.cat];
  const theirWeight = theirs.weight ?? theirCat.typical_weight;
  const mineWeight = mine.weight ?? CATEGORY[mine.cat].typical_weight;
  const co2Saved = (theirWeight * theirCat.co2_per_kg).toFixed(1);
  const wasteSaved = mineWeight.toFixed(1);
  const [count, setCount] = React.useState({ co2: 0, waste: 0 });
  React.useEffect(() => {
    const start = performance.now();
    let raf;
    const tick = () => {
      const t = Math.min(1, (performance.now() - start) / 800);
      setCount({
        co2: Number((parseFloat(co2Saved) * t).toFixed(1)),
        waste: Number((parseFloat(wasteSaved) * t).toFixed(1)),
      });
      if (t < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [co2Saved, wasteSaved]);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)', alignItems: 'center', padding: 24, justifyContent: 'center' }}>
      <div style={{
        width: 96, height: 96, borderRadius: '50%',
        background: 'var(--green-soft)', color: 'var(--green-primary)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        marginBottom: 20,
      }}>
        <svg width="44" height="44" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M20 6 9 17l-5-5" style={{ strokeDasharray: 30, strokeDashoffset: 30, animation: 'drawCheck 400ms 80ms ease-out forwards' }} />
        </svg>
      </div>
      <div style={{ fontSize: 28, fontWeight: 600 }}>Swap confirmed</div>
      <div style={{ marginTop: 6, fontSize: 14, color: 'var(--text-secondary)', textAlign: 'center' }}>
        Your <b>{mine.name}</b> for {person.name}'s <b>{theirs.name}</b>.
      </div>

      {/* Counting impact */}
      <div style={{ marginTop: 28, width: '100%', display: 'flex', gap: 12 }}>
        <div style={{ flex: 1, padding: 16, background: 'var(--green-soft)', borderRadius: 12 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--green-dark)', textTransform: 'uppercase', letterSpacing: 0.5 }}>CO₂ saved</div>
          <div style={{ marginTop: 6, fontSize: 24, fontWeight: 700, color: 'var(--green-dark)', fontVariantNumeric: 'tabular-nums' }}>+{count.co2} kg</div>
        </div>
        <div style={{ flex: 1, padding: 16, background: 'var(--surface-alt)', borderRadius: 12 }}>
          <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: 0.5 }}>Waste diverted</div>
          <div style={{ marginTop: 6, fontSize: 24, fontWeight: 700, color: 'var(--text-primary)', fontVariantNumeric: 'tabular-nums' }}>+{count.waste} kg</div>
        </div>
      </div>

      <div style={{ marginTop: 12, fontSize: 12, color: 'var(--text-tertiary)', textAlign: 'center' }}>
        Added to your impact dashboard.
      </div>

      <div style={{ width: '100%', marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Button onClick={onComplete} icon={<IconLeaf size={18} />}>See my impact</Button>
        <Button variant="ghost" onClick={onComplete} style={{ color: 'var(--text-secondary)' }}>Back to chats</Button>
      </div>

      <style>{`@keyframes drawCheck { to { stroke-dashoffset: 0; } }`}</style>
    </div>
  );
};

Object.assign(window, { QRScreen, QRPattern, QRSuccess });
