// Profile screen — avatar, name, bio, impact summary, items link.
const ProfileScreen = ({ profile, onMyItems, onEdit, onLogout }) => {
  const p = profile || {
    name: 'Nong',
    district: { thai: 'บางมด', en: 'Bang Mod', city: 'Bangkok' },
    bio: 'KMUTT student, decluttering before the semester ends.',
  };
  const me = { name: p.name, color: '#B8D4C0' };
  const data = calcImpact();
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      <TopBar variant="top" left={<div style={{ fontSize: 22, fontWeight: 600 }}>Profile</div>} />
      <div className="phone-scroll" style={{ flex: 1, overflow: 'auto', padding: '16px 16px 40px' }}>
        {/* Top */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', padding: '8px 0 16px' }}>
          <Avatar person={me} size={96} />
          <div style={{ marginTop: 12, fontSize: 24, fontWeight: 600 }}>{p.name}</div>
          <div style={{ marginTop: 4, fontSize: 14, color: 'var(--text-secondary)' }}>{p.district.en}</div>
        </div>

        {/* Impact summary */}
        <div style={{
          marginTop: 16, padding: 16, background: 'var(--green-soft)', borderRadius: 12,
          display: 'flex', justifyContent: 'space-around', textAlign: 'center',
        }}>
          <SummaryStat value={TRADES.length} label="Swaps" />
          <SummaryStat value={`${data.co2.toFixed(1)}`} label="kg CO₂" />
          <SummaryStat value={`${data.waste.toFixed(1)}`} label="kg waste" />
        </div>

        {/* My items shortcut */}
        <div onClick={onMyItems} style={{
          marginTop: 16, padding: 16, background: 'var(--surface-alt)', borderRadius: 12,
          display: 'flex', alignItems: 'center', gap: 12, cursor: 'pointer',
        }}>
          <div style={{
            width: 40, height: 40, borderRadius: 10, background: 'var(--surface)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: 'var(--green-primary)',
          }}><IconLayers size={20} /></div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 14, fontWeight: 600 }}>My items</div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{itemsBy('me').length} listed for swap</div>
          </div>
          <IconChevR size={18} style={{ color: 'var(--text-tertiary)' }} />
        </div>

        {/* Bio */}
        <div style={{ marginTop: 20 }}>
          <div style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>About</div>
          <p style={{ margin: 0, fontSize: 15, lineHeight: 1.5, color: 'var(--text-primary)' }}>
            {p.bio}
          </p>
        </div>

        <div style={{ marginTop: 24, display: 'flex', flexDirection: 'column', gap: 10 }}>
          <Button variant="secondary" icon={<IconPencil size={16} />} onClick={onEdit}>Edit profile</Button>
          <Button variant="ghost" onClick={onLogout} style={{ color: 'var(--text-secondary)' }}>Log out</Button>
        </div>
      </div>
    </div>
  );
};

const SummaryStat = ({ value, label }) => (
  <div>
    <div style={{ fontSize: 22, fontWeight: 700, color: 'var(--green-dark)', fontVariantNumeric: 'tabular-nums' }}>{value}</div>
    <div style={{ fontSize: 11, color: 'var(--green-dark)', opacity: 0.7, marginTop: 2, fontWeight: 500 }}>{label}</div>
  </div>
);

Object.assign(window, { ProfileScreen });
