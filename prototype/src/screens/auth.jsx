// Auth screen: sign-in or sign-up. Single-column form, Google placeholder.
const AuthScreen = ({ onSubmit, onBack, mode = 'signup', onModeChange }) => {
  const [email, setEmail] = React.useState('nong@kmutt.ac.th');
  const [pass,  setPass]  = React.useState('••••••••');
  const signup = mode === 'signup';
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      <TopBar variant="hier" onBack={onBack} />
      <div style={{ flex: 1, padding: '8px 16px 16px', display: 'flex', flexDirection: 'column', gap: 20 }}>
        <div>
          <div style={{ fontSize: 24, fontWeight: 600, color: 'var(--text-primary)', lineHeight: 1.3 }}>
            {signup ? 'Create your account' : 'Welcome back'}
          </div>
          <div style={{ marginTop: 6, fontSize: 14, color: 'var(--text-secondary)' }}>
            {signup ? 'Start swapping with people near you.' : 'Sign in to keep swapping.'}
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <Input label="Email" value={email} onChange={setEmail} placeholder="you@example.com" />
          <Input label="Password" value={pass} onChange={setPass} type="password" placeholder="••••••••" />
          {!signup && (
            <a style={{ alignSelf: 'flex-end', fontSize: 13, color: 'var(--info)', textDecoration: 'none' }}>Forgot password?</a>
          )}
        </div>

        <Button onClick={onSubmit}>{signup ? 'Create account' : 'Sign in'}</Button>

        <div style={{ marginTop: 'auto', textAlign: 'center', fontSize: 13, color: 'var(--text-secondary)' }}>
          {signup ? "Already have an account? " : "New here? "}
          <a onClick={() => onModeChange?.(signup ? 'signin' : 'signup')} style={{ color: 'var(--green-primary)', fontWeight: 500, cursor: 'pointer' }}>
            {signup ? 'Sign in' : 'Create an account'}
          </a>
        </div>
      </div>
    </div>
  );
};
Object.assign(window, { AuthScreen });
