// Splash screen — text wordmark + simple mark + tagline. No animation.
const SplashScreen = ({ onContinue }) => (
  <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 32, background: 'var(--surface)' }}>
    <div style={{ flex: 1 }} />
    <EcoMark size={80} />
    <div style={{ height: 24 }} />
    <div style={{ fontSize: 40, fontWeight: 700, color: 'var(--green-primary)', letterSpacing: -1.5 }}>EcoSwap</div>
    <div style={{ marginTop: 12, fontSize: 17, color: 'var(--text-secondary)', fontWeight: 400 }}>Swap, don't shop.</div>
    <div style={{ flex: 1 }} />
    <div style={{ width: '100%', display: 'flex', flexDirection: 'column', gap: 12 }}>
      <Button onClick={onContinue}>Get started</Button>
      <Button variant="ghost" onClick={onContinue} style={{ color: 'var(--text-secondary)' }}>I already have an account</Button>
    </div>
  </div>
);
Object.assign(window, { SplashScreen });
