// 3-step setup wizard. Progress dots top center. Each step has back + Next.
const Dots = ({ step, total = 3 }) => (
  <div style={{ display: 'flex', gap: 6, justifyContent: 'center' }}>
    {Array.from({ length: total }).map((_, i) => (
      <div key={i} style={{
        width: i === step ? 24 : 6, height: 6, borderRadius: 999,
        background: i <= step ? 'var(--green-primary)' : 'var(--border)',
        transition: 'all 220ms ease',
      }} />
    ))}
  </div>
);

// Photo upload affordance — big avatar circle + camera button overlay.
const PhotoUpload = ({ name, hasPhoto, onTake }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '8px 0 8px' }}>
    <button onClick={onTake} style={{
      position: 'relative', width: 112, height: 112, borderRadius: '50%',
      border: 'none', padding: 0, background: 'transparent', cursor: 'pointer',
    }}>
      <div style={{
        width: 112, height: 112, borderRadius: '50%',
        background: hasPhoto ? '#B8D4C0' : 'var(--green-soft)',
        color: 'var(--green-dark)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        fontSize: 44, fontWeight: 600, fontFamily: 'Inter',
        border: '2px dashed transparent',
        boxSizing: 'border-box',
        transition: 'background 120ms ease',
      }}>
        {hasPhoto ? (
          <span style={{
            fontFamily: 'JetBrains Mono, monospace',
            fontSize: 11, color: 'var(--green-dark)', opacity: 0.7,
            padding: '0 12px', textAlign: 'center', lineHeight: 1.3,
          }}>your photo</span>
        ) : (name?.slice(0, 1) || 'N')}
      </div>
      {/* Camera badge */}
      <div style={{
        position: 'absolute', right: 2, bottom: 2,
        width: 36, height: 36, borderRadius: '50%',
        background: 'var(--green-primary)', color: '#fff',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 2px 6px rgba(0,0,0,0.2), 0 0 0 3px var(--surface)',
      }}>
        <IconCamera size={18} />
      </div>
    </button>
    <div style={{ marginTop: 14, fontSize: 13, color: 'var(--text-secondary)', textAlign: 'center' }}>
      {hasPhoto ? 'Tap to change' : 'Tap to add a photo'}
    </div>
  </div>
);

// Sample list of Thai amphoe / khet for the area search.
const AMPHOE = [
  { thai: 'บางมด',      name: 'Bang Mod',      district: 'Thung Khru',   province: 'Bangkok' },
  { thai: 'คลองสาน',    name: 'Khlong San',    district: 'Khlong San',   province: 'Bangkok' },
  { thai: 'อโศก',       name: 'Asoke',         district: 'Watthana',     province: 'Bangkok' },
  { thai: 'พระโขนง',    name: 'Phra Khanong',  district: 'Phra Khanong', province: 'Bangkok' },
  { thai: 'บางนา',      name: 'Bang Na',       district: 'Bang Na',      province: 'Bangkok' },
  { thai: 'ธนบุรี',      name: 'Thonburi',      district: 'Thonburi',     province: 'Bangkok' },
  { thai: 'จตุจักร',     name: 'Chatuchak',     district: 'Chatuchak',    province: 'Bangkok' },
  { thai: 'ลาดพร้าว',   name: 'Lat Phrao',     district: 'Lat Phrao',    province: 'Bangkok' },
  { thai: 'บางซื่อ',     name: 'Bang Sue',      district: 'Bang Sue',     province: 'Bangkok' },
  { thai: 'หาดใหญ่',    name: 'Hat Yai',       district: 'Hat Yai',      province: 'Songkhla' },
];

const formatArea = (a) => a ? `${a.name}, ${a.province}` : '';

// State A — Searching. Permanent dropdown panel, first row preview-selected.
const AreaSearching = ({ query, onQuery, onPick, selectedKey }) => {
  const matches = React.useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return AMPHOE.slice(0, 6);
    return AMPHOE.filter(a =>
      a.name.toLowerCase().includes(q) ||
      a.thai.includes(query.trim()) ||
      a.province.toLowerCase().includes(q)
    ).slice(0, 8);
  }, [query]);

  return (
    <>
      <div style={{ position: 'relative' }}>
        <input
          value={query}
          onChange={(e) => onQuery(e.target.value)}
          placeholder="Search your district..."
          style={{
            width: '100%', minHeight: 48, padding: '12px 14px 12px 44px',
            background: 'var(--surface)',
            border: '1px solid var(--border)',
            borderRadius: 10, fontSize: 15, color: 'var(--text-primary)',
            outline: 'none', boxSizing: 'border-box',
          }}
        />
        <div style={{ position: 'absolute', left: 14, top: '50%', transform: 'translateY(-50%)', color: 'var(--text-tertiary)' }}>
          <IconMapPin size={20} />
        </div>
      </div>

      <div style={{
        marginTop: 8,
        background: 'var(--surface)',
        borderRadius: 10,
        boxShadow: 'var(--shadow-modal)',
        maxHeight: 280, overflow: 'auto',
      }}>
        {matches.map((a, i) => {
          // Preview first row as "selected" if no key provided — per spec.
          const isSelected = selectedKey ? selectedKey === a.thai : i === 0;
          return (
            <div key={a.thai + i} onClick={() => onPick(a)} style={{
              height: 48, padding: '0 16px', cursor: 'pointer',
              display: 'flex', alignItems: 'center', gap: 4,
              background: isSelected ? 'var(--green-soft)' : 'transparent',
              borderBottom: i < matches.length - 1 ? '1px solid var(--border)' : 'none',
            }}>
              <span style={{ fontSize: 15, fontWeight: 600, color: 'var(--text-primary)' }}>{a.thai}</span>
              <span style={{ fontSize: 15, color: 'var(--text-secondary)' }}>· {a.name}, {a.province}</span>
              {isSelected && (
                <IconCheck size={18} style={{ color: 'var(--green-primary)', marginLeft: 'auto' }} />
              )}
            </div>
          );
        })}
      </div>
    </>
  );
};

// State B — Selected. Confirmation card + info note.
const AreaSelected = ({ value, onChange }) => (
  <>
    <div style={{
      background: 'var(--surface-alt)',
      borderRadius: 12,
      padding: 16,
      border: '1px solid var(--border)',
      display: 'flex', alignItems: 'center', gap: 12,
    }}>
      <IconMapPin size={20} style={{ color: 'var(--text-secondary)' }} />
      <div style={{ flex: 1, fontSize: 15, lineHeight: 1.4 }}>
        <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{value.thai}</span>
        <span style={{ color: 'var(--text-secondary)' }}> · {value.name}, {value.province}</span>
      </div>
      <button onClick={() => onChange(null)} style={{
        background: 'transparent', border: 'none', padding: 0,
        color: 'var(--green-primary)', fontWeight: 600, fontSize: 15, cursor: 'pointer',
      }}>Change</button>
    </div>
    <div style={{
      marginTop: 16, display: 'flex', alignItems: 'center', gap: 8,
      color: 'var(--text-secondary)', fontSize: 13,
    }}>
      <IconInfo size={16} />
      <span>We'll show you swappers in {value.name} and nearby districts.</span>
    </div>
  </>
);

// Wrapper that swaps between the two states based on whether a value is set.
const AreaSearch = ({ value, onChange }) => {
  const [query, setQuery] = React.useState('');
  return (
    <div>
      <div style={{
        fontSize: 13, fontWeight: 500,
        color: 'var(--text-secondary)', marginBottom: 12,
        textTransform: 'none', letterSpacing: 0,
      }}>Your area</div>
      {value ? (
        <AreaSelected value={value} onChange={onChange} />
      ) : (
        <AreaSearching
          query={query}
          onQuery={setQuery}
          onPick={(a) => { onChange(a); setQuery(''); }}
        />
      )}
    </div>
  );
};

const SetupScreen = ({ onDone, onBack }) => {
  const [step, setStep] = React.useState(0);
  const [name, setName] = React.useState('Nong');
  const [hasPhoto, setHasPhoto] = React.useState(false);
  const [area, setArea] = React.useState({ thai: 'บางมด', name: 'Bang Mod', district: 'Thung Khru', province: 'Bangkok' });
  const [bio,  setBio]  = React.useState('KMUTT student, decluttering before the semester ends.');

  const next = () => step < 2 ? setStep(s => s + 1) : onDone?.();
  const back = () => step === 0 ? onBack?.() : setStep(s => s - 1);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      <TopBar variant="hier" onBack={back} right={
        step === 2 ? <a onClick={() => onDone?.()} style={{ fontSize: 14, color: 'var(--text-secondary)', cursor: 'pointer', paddingRight: 8 }}>Skip</a> : null
      } />
      <div style={{ padding: '0 16px 8px' }}><Dots step={step} /></div>
      <div className="phone-scroll" style={{ flex: 1, overflow: 'auto', padding: '24px 16px 16px', display: 'flex', flexDirection: 'column', gap: 20 }}>
        {step === 0 && (
          <>
            <div>
              <div style={{ fontSize: 24, fontWeight: 600 }}>What should we call you?</div>
              <div style={{ marginTop: 6, fontSize: 14, color: 'var(--text-secondary)' }}>Add a photo and a name so other swappers recognise you.</div>
            </div>
            <PhotoUpload name={name} hasPhoto={hasPhoto} onTake={() => setHasPhoto(v => !v)} />
            <Input label="Display name" value={name} onChange={setName} />
          </>
        )}
        {step === 1 && (
          <>
            <div style={{ marginTop: 8 }}>
              <div style={{ fontSize: 24, fontWeight: 600, lineHeight: 1.25 }}>Where are you based?</div>
              <div style={{ marginTop: 8, fontSize: 14, color: 'var(--text-secondary)', lineHeight: 1.5 }}>
                We only show your district to others, never your exact location.
              </div>
            </div>
            <AreaSearch value={area} onChange={setArea} />
          </>
        )}
        {step === 2 && (
          <>
            <div>
              <div style={{ fontSize: 24, fontWeight: 600 }}>Tell people about yourself</div>
              <div style={{ marginTop: 6, fontSize: 14, color: 'var(--text-secondary)' }}>One short line is enough.</div>
            </div>
            <label>
              <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', marginBottom: 6 }}>Short bio</div>
              <textarea value={bio} onChange={e => setBio(e.target.value)} rows={4} style={{
                width: '100%', padding: 14, background: 'var(--surface-alt)',
                border: '1px solid var(--border)', borderRadius: 8,
                fontSize: 15, fontFamily: 'Inter', resize: 'none', outline: 'none', boxSizing: 'border-box',
                color: 'var(--text-primary)',
              }} />
              <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 4, textAlign: 'right' }}>{bio.length}/140</div>
            </label>
          </>
        )}
      </div>
      <div style={{ padding: 16, borderTop: step > 0 ? '1px solid var(--border)' : 'none' }}>
        <Button onClick={next} disabled={step === 1 && !area}>{step === 2 ? 'Start swapping' : 'Next'}</Button>
      </div>
    </div>
  );
};
Object.assign(window, { SetupScreen, PhotoUpload, AreaSearch, AreaSearching, AreaSelected, AMPHOE, Dots });
