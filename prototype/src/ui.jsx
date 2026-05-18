// Shared UI primitives for EcoSwap. All read from CSS vars so the Tweaks
// panel can recolor the app live.

// --- Wordmark + geometric mark ----------------------------------------------
// Two interlocking arrowed circles = swap. No leaves.
const EcoMark = ({ size = 28, color = 'var(--green-primary)' }) => (
  <svg width={size} height={size} viewBox="0 0 28 28" fill="none" style={{ flexShrink: 0 }}>
    <path d="M5 11a8 8 0 0 1 14-4" stroke={color} strokeWidth="2.5" strokeLinecap="round"/>
    <path d="M16 4l3 3-3 3" stroke={color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
    <path d="M23 17a8 8 0 0 1-14 4" stroke={color} strokeWidth="2.5" strokeLinecap="round"/>
    <path d="M12 24l-3-3 3-3" stroke={color} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
);

const Wordmark = ({ size = 22, mark = true }) => (
  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
    {mark && <EcoMark size={size * 1.15} />}
    <span style={{
      fontFamily: 'Inter', fontWeight: 700, fontSize: size,
      letterSpacing: -0.5, color: 'var(--green-primary)',
    }}>EcoSwap</span>
  </div>
);

// --- Button -----------------------------------------------------------------
const Button = ({ children, variant = 'primary', full = true, onClick, disabled, style, icon }) => {
  const base = {
    minHeight: 48, padding: '14px 20px',
    fontSize: 15, fontWeight: 500, fontFamily: 'Inter',
    borderRadius: 8, border: 'none',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    width: full ? '100%' : 'auto',
    opacity: disabled ? 0.4 : 1,
    transition: 'background 80ms ease',
    cursor: disabled ? 'not-allowed' : 'pointer',
    lineHeight: 1.2,
  };
  const variants = {
    primary:    { background: 'var(--green-primary)', color: '#fff' },
    secondary:  { background: 'var(--surface-alt)', color: 'var(--text-primary)', border: '1px solid var(--border)' },
    destructive:{ background: 'var(--danger-soft)', color: 'var(--danger)' },
    ghost:      { background: 'transparent', color: 'var(--text-primary)' },
    dark:       { background: 'var(--text-primary)', color: '#fff' },
  };
  return (
    <button onClick={disabled ? undefined : onClick} style={{ ...base, ...variants[variant], ...style }}>
      {icon}{children}
    </button>
  );
};

// --- Top bar ----------------------------------------------------------------
// Per style guide §8. Three variants: 'hier', 'top', 'filter'
const TopBar = ({ variant = 'hier', title, onBack, right, left, style }) => (
  <div style={{
    height: 56, display: 'flex', alignItems: 'center',
    padding: '0 4px 0 4px',
    background: 'var(--surface)',
    flexShrink: 0,
    ...style,
  }}>
    {variant === 'hier' && (
      <>
        <IconBtn onClick={onBack}><IconBack /></IconBtn>
        <div style={{ flex: 1, textAlign: 'center', fontSize: 16, fontWeight: 600, color: 'var(--text-primary)' }}>{title}</div>
        <div style={{ width: 40, display: 'flex', justifyContent: 'flex-end', paddingRight: 12 }}>{right}</div>
      </>
    )}
    {variant === 'top' && (
      <>
        <div style={{ flex: 1, padding: '0 12px', display: 'flex', alignItems: 'center', gap: 10 }}>
          {left || <Wordmark size={18} />}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, paddingRight: 8 }}>{right}</div>
      </>
    )}
    {variant === 'filter' && (
      <div style={{ flex: 1, padding: '0 12px', display: 'flex', alignItems: 'center', gap: 8 }}>{left}{right}</div>
    )}
  </div>
);

const IconBtn = ({ children, onClick, style, ariaLabel }) => (
  <button onClick={onClick} aria-label={ariaLabel} style={{
    width: 40, height: 40, border: 'none', background: 'transparent',
    display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
    color: 'var(--text-primary)', borderRadius: 8,
    flexShrink: 0,
    ...style,
  }}>{children}</button>
);

// --- Bottom nav -------------------------------------------------------------
const BottomNav = ({ active, onChange }) => {
  const items = [
    { key: 'discover', icon: <IconCompass size={22} />, label: 'Discover' },
    { key: 'chats',    icon: <IconMsg size={22} />,     label: 'Chats' },
    { key: 'impact',   icon: <IconLeaf size={22} />,    label: 'Impact' },
    { key: 'profile',  icon: <IconUser size={22} />,    label: 'Profile' },
  ];
  return (
    <div style={{
      height: 64, display: 'flex', alignItems: 'stretch',
      background: 'var(--surface)', borderTop: '1px solid var(--border)',
      flexShrink: 0,
    }}>
      {items.map(it => {
        const on = it.key === active;
        return (
          <button key={it.key} onClick={() => onChange(it.key)} style={{
            flex: 1, border: 'none', background: 'transparent',
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
            color: on ? 'var(--green-primary)' : 'var(--text-secondary)',
            paddingTop: 6,
          }}>
            {it.icon}
            <span style={{ fontSize: 11, fontWeight: 500 }}>{it.label}</span>
          </button>
        );
      })}
    </div>
  );
};

// --- Avatar -----------------------------------------------------------------
const Avatar = ({ person, size = 40, ring }) => {
  if (!person) return null;
  const initials = person.name.slice(0, 1);
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: person.color || 'var(--green-soft)',
      color: 'var(--green-dark)',
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      fontSize: size * 0.42, fontWeight: 600,
      flexShrink: 0,
      boxShadow: ring ? `0 0 0 3px ${ring}` : 'none',
      fontFamily: 'Inter',
    }}>{initials}</div>
  );
};

// --- Item thumbnail (placeholder with subtle stripes + category) -----------
const ItemThumb = ({ item, size = 80, radius = 8, selected, onClick, showName = false, showCondition = false }) => {
  if (!item) return null;
  const cat = CATEGORY[item.cat] || {};
  return (
    <div onClick={onClick} style={{
      width: size, position: 'relative',
      borderRadius: radius,
      cursor: onClick ? 'pointer' : 'default',
      border: selected ? '2px solid var(--green-primary)' : 'none',
      boxSizing: 'border-box',
    }}>
      <div style={{
        width: '100%', aspectRatio: '1 / 1',
        borderRadius: radius,
        background: `repeating-linear-gradient(135deg, ${item.swatch}26 0 6px, ${item.swatch}14 6px 12px), ${item.swatch}33`,
        position: 'relative', overflow: 'hidden',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <span style={{
          fontFamily: 'JetBrains Mono, monospace',
          fontSize: Math.max(9, size * 0.11), color: '#fffe',
          mixBlendMode: 'difference',
          textAlign: 'center', padding: '0 4px',
          fontWeight: 500,
        }}>{cat.label?.toLowerCase()}</span>
      </div>
      {showName && (
        <div style={{ paddingTop: 8, fontSize: 13, fontWeight: 500, color: 'var(--text-primary)', lineHeight: 1.3 }}>
          {item.name}
          {showCondition && (
            <div style={{ marginTop: 4 }}><Pill variant="cond">{item.cond}</Pill></div>
          )}
        </div>
      )}
    </div>
  );
};

// --- Pill / Badge -----------------------------------------------------------
const Pill = ({ children, variant = 'cond', icon, style }) => {
  const variants = {
    cond:   { background: 'var(--surface-alt)', color: 'var(--text-secondary)' },
    trust:  { background: 'var(--surface-alt)', color: 'var(--text-primary)' },
    new:    { background: 'var(--green-soft)',  color: 'var(--green-dark)' },
    danger: { background: 'var(--danger-soft)', color: 'var(--danger)' },
    warn:   { background: '#FFF1DD',            color: 'var(--warning)' },
    info:   { background: '#E4EEF7',            color: 'var(--info)' },
    dark:   { background: 'var(--text-primary)',color: '#fff' },
    outline:{ background: 'transparent', color: 'var(--text-primary)', border: '1px solid var(--border)' },
  };
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 4,
      padding: '4px 10px', borderRadius: 9999,
      fontSize: 11, fontWeight: 500, lineHeight: 1.3,
      ...variants[variant], ...style,
    }}>{icon}{children}</span>
  );
};

// --- Input ------------------------------------------------------------------
const Input = ({ label, value, onChange, placeholder, type = 'text', hint }) => {
  const [focus, setFocus] = React.useState(false);
  return (
    <label style={{ display: 'block' }}>
      {label && <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', marginBottom: 6 }}>{label}</div>}
      <input
        type={type} value={value} onChange={e => onChange?.(e.target.value)}
        placeholder={placeholder}
        onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
        style={{
          width: '100%', minHeight: 44, padding: '12px 14px',
          background: 'var(--surface-alt)',
          border: focus ? '2px solid var(--green-primary)' : '1px solid var(--border)',
          borderRadius: 8, fontSize: 15, color: 'var(--text-primary)',
          outline: 'none', boxSizing: 'border-box',
        }}
      />
      {hint && <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 4 }}>{hint}</div>}
    </label>
  );
};

// --- Status bar (simplified, white background) -----------------------------
const StatusBar = () => (
  <div style={{
    height: 36, display: 'flex', alignItems: 'center',
    justifyContent: 'space-between', padding: '0 20px',
    background: 'var(--surface)', flexShrink: 0,
    fontFamily: 'Inter',
  }}>
    <span style={{ fontSize: 13, fontWeight: 600, color: 'var(--text-primary)', letterSpacing: 0.2 }}>9:30</span>
    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}>
      {/* signal */}
      <svg width="15" height="11" viewBox="0 0 15 11"><path d="M0 8h2v3H0zM4 6h2v5H4zM8 3h2v8H8zM12 0h2v11h-2z" fill="var(--text-primary)"/></svg>
      {/* wifi */}
      <svg width="14" height="11" viewBox="0 0 14 11" fill="none"><path d="M7 10v0M3 6a6 6 0 0 1 8 0M.5 3a10 10 0 0 1 13 0" stroke="var(--text-primary)" strokeWidth="1.5" strokeLinecap="round"/></svg>
      {/* battery */}
      <svg width="22" height="11" viewBox="0 0 22 11"><rect x="0.5" y="0.5" width="18" height="10" rx="2" fill="none" stroke="var(--text-primary)"/><rect x="20" y="3.5" width="2" height="4" rx="0.5" fill="var(--text-primary)"/><rect x="2" y="2" width="14" height="7" rx="1" fill="var(--text-primary)"/></svg>
    </div>
  </div>
);

// --- Gesture nav bar -------------------------------------------------------
const GestureBar = () => (
  <div style={{ height: 22, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--surface)', flexShrink: 0 }}>
    <div style={{ width: 108, height: 4, borderRadius: 2, background: 'var(--text-primary)', opacity: 0.7 }} />
  </div>
);

// --- Phone shell -----------------------------------------------------------
// 390x844 effective. We render at 390x844 as a "phone" inside the page.
const Phone = ({ children, dark, bg }) => (
  <div style={{
    width: 390, height: 844, overflow: 'hidden',
    background: bg || 'var(--surface)',
    display: 'flex', flexDirection: 'column',
    position: 'relative',
  }}>
    {children}
  </div>
);

// --- Phone hardware frame --------------------------------------------------
// Wraps Phone content with Android-style bezel + status/nav bars.
const PhoneFrame = ({ children, statusbarDark = false, hideGesture = false, statusBg }) => (
  <div style={{
    width: 410, height: 880,
    borderRadius: 38, padding: 10,
    background: '#1a1a1a',
    boxShadow: '0 30px 80px rgba(0,0,0,0.25), 0 0 0 2px rgba(255,255,255,0.06) inset',
    flexShrink: 0,
  }}>
    <div style={{
      width: '100%', height: '100%',
      borderRadius: 28, overflow: 'hidden',
      background: 'var(--surface)',
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ background: statusBg || 'var(--surface)' }}><StatusBar /></div>
      <div style={{ flex: 1, minHeight: 0, display: 'flex', flexDirection: 'column' }}>
        {children}
      </div>
      {!hideGesture && <GestureBar />}
    </div>
  </div>
);

// --- Sectioned card --------------------------------------------------------
const Card = ({ children, style, padded = true, alt = false }) => (
  <div style={{
    background: alt ? 'var(--surface-alt)' : 'var(--surface)',
    border: '1px solid var(--border)',
    borderRadius: 12,
    padding: padded ? 16 : 0,
    ...style,
  }}>{children}</div>
);

// --- Empty state -----------------------------------------------------------
const EmptyState = ({ icon, headline, description, cta, onCta }) => (
  <div style={{
    flex: 1, display: 'flex', flexDirection: 'column',
    alignItems: 'center', justifyContent: 'center',
    padding: '40px 32px', textAlign: 'center',
  }}>
    <div style={{ color: 'var(--text-tertiary)', marginBottom: 16 }}>{icon}</div>
    <div style={{ fontSize: 16, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 8 }}>{headline}</div>
    <div style={{ fontSize: 15, color: 'var(--text-secondary)', lineHeight: 1.5, maxWidth: 260, marginBottom: cta ? 24 : 0 }}>{description}</div>
    {cta && (
      <Button onClick={onCta} full={false} style={{ paddingLeft: 28, paddingRight: 28 }}>{cta}</Button>
    )}
  </div>
);

// --- Bottom sheet ----------------------------------------------------------
const Sheet = ({ open, onClose, height = '70%', children }) => {
  if (!open) return null;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 10,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      background: 'rgba(0,0,0,0.4)',
    }} onClick={onClose}>
      <div onClick={e => e.stopPropagation()} style={{
        background: 'var(--surface)',
        borderTopLeftRadius: 20, borderTopRightRadius: 20,
        boxShadow: '0 -8px 24px rgba(0,0,0,0.12)',
        height,
        display: 'flex', flexDirection: 'column',
        animation: 'sheetUp 280ms cubic-bezier(0.2,0.7,0.2,1) both',
      }}>
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 8, flexShrink: 0 }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: 'var(--border)' }} />
        </div>
        {children}
      </div>
      <style>{`@keyframes sheetUp { from { transform: translateY(40px); opacity: 0; } to { transform: none; opacity: 1; } }`}</style>
    </div>
  );
};

// --- Toast ---
const Toast = ({ children, kind = 'success', show }) => (
  <div style={{
    position: 'absolute', left: 16, right: 16, bottom: 90,
    background: kind === 'success' ? 'var(--green-soft)' : 'var(--surface-alt)',
    color: kind === 'success' ? 'var(--green-dark)' : 'var(--text-primary)',
    padding: '12px 16px', borderRadius: 12,
    boxShadow: 'var(--shadow-modal)',
    fontSize: 14, fontWeight: 500,
    pointerEvents: show ? 'auto' : 'none',
    opacity: show ? 1 : 0,
    transform: show ? 'none' : 'translateY(12px)',
    transition: 'all 220ms ease',
    zIndex: 20,
  }}>{children}</div>
);

Object.assign(window, {
  EcoMark, Wordmark, Button, TopBar, IconBtn, BottomNav,
  Avatar, ItemThumb, Pill, Input, StatusBar, GestureBar,
  Phone, PhoneFrame, Card, EmptyState, Sheet, Toast,
});
