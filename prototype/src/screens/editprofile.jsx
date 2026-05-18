// Edit Profile — friendly form to update photo / name / district / bio.
// Wired from the Profile screen's "Edit profile" button.

const BIO_MAX = 150;

// — Atom: text input matching upload.jsx field style —
const EpTextField = ({ value, onChange, placeholder }) => {
  const [focus, setFocus] = React.useState(false);
  return (
    <input
      value={value || ''}
      onChange={(e) => onChange(e.target.value)}
      placeholder={placeholder}
      onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
      style={{
        width: '100%', minHeight: 48, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: focus ? '1.5px solid var(--green-primary)' : '1px solid var(--border)',
        borderRadius: 8, fontSize: 15, color: 'var(--text-primary)',
        outline: 'none', boxSizing: 'border-box',
        fontFamily: 'inherit',
      }}
    />
  );
};

// — Atom: textarea matching upload.jsx style —
const EpTextArea = ({ value, onChange, placeholder, rows = 4, maxLength }) => {
  const [focus, setFocus] = React.useState(false);
  return (
    <textarea
      value={value || ''}
      onChange={(e) => onChange(e.target.value.slice(0, maxLength))}
      placeholder={placeholder}
      rows={rows}
      onFocus={() => setFocus(true)} onBlur={() => setFocus(false)}
      style={{
        width: '100%', padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: focus ? '1.5px solid var(--green-primary)' : '1px solid var(--border)',
        borderRadius: 8, fontSize: 15, lineHeight: 1.45,
        color: 'var(--text-primary)',
        outline: 'none', boxSizing: 'border-box',
        resize: 'none',
        fontFamily: 'inherit',
      }}
    />
  );
};

// — District tap-row: looks like an input, opens picker on tap. —
// Shows current value with a map-pin prefix and chevron suffix.
const DistrictRow = ({ value, onOpen }) => {
  // value example: { thai: 'บางมด', en: 'Bang Mod', city: 'Bangkok' }
  return (
    <button
      onClick={onOpen}
      style={{
        width: '100%', minHeight: 48, padding: '12px 14px',
        background: 'var(--surface-alt)',
        border: '1px solid var(--border)',
        borderRadius: 8,
        display: 'flex', alignItems: 'center', gap: 10,
        boxSizing: 'border-box', cursor: 'pointer',
        fontFamily: 'inherit', textAlign: 'left',
      }}>
      <IconMapPin size={20} color="var(--text-secondary)" />
      <div style={{ flex: 1, minWidth: 0, fontSize: 15, lineHeight: 1.3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
        <span style={{ color: 'var(--text-primary)', fontWeight: 600 }}>{value.thai}</span>
        <span style={{ color: 'var(--text-secondary)', fontWeight: 400 }}> · {value.en}, {value.city}</span>
      </div>
      <IconChevR size={20} color="var(--text-secondary)" />
    </button>
  );
};

// — Editable avatar with camera badge —
const EditableAvatar = ({ person, onChange }) => (
  <button
    onClick={onChange}
    aria-label="Change photo"
    style={{
      position: 'relative', width: 96, height: 96, borderRadius: '50%',
      border: 'none', padding: 0, background: 'transparent',
      cursor: 'pointer', flexShrink: 0,
    }}>
    <div style={{
      width: 96, height: 96, borderRadius: '50%',
      background: 'var(--green-soft)',
      color: 'var(--green-dark)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontSize: 40, fontWeight: 600,
      fontFamily: 'Inter',
    }}>
      {person.name.slice(0, 1)}
    </div>
    {/* Camera badge */}
    <div style={{
      position: 'absolute', right: -2, bottom: -2,
      width: 28, height: 28, borderRadius: '50%',
      background: 'var(--green-primary)',
      border: '2px solid var(--surface)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      color: '#fff',
    }}>
      <IconCamera size={14} color="#fff" />
    </div>
  </button>
);

const EditProfileScreen = ({ onBack, onSave, initial = {} }) => {
  const me = { name: initial.name || 'Nong', color: '#B8D4C0' };

  const [name, setName] = React.useState(initial.name || 'Nong');
  const [district, setDistrict] = React.useState(initial.district || {
    thai: 'บางมด', en: 'Bang Mod', city: 'Bangkok',
  });
  const [bio, setBio] = React.useState(
    initial.bio != null ? initial.bio : 'KMUTT student, decluttering before the semester ends.'
  );

  const dirty =
    name.trim() !== (initial.name || 'Nong') ||
    bio !== (initial.bio != null ? initial.bio : 'KMUTT student, decluttering before the semester ends.') ||
    district.en !== (initial.district?.en || 'Bang Mod');

  const valid = name.trim().length > 0 && bio.length <= BIO_MAX;

  const save = () => {
    if (!valid) return;
    onSave?.({ name: name.trim(), district, bio });
  };

  // Toggle through a few district options for prototype feel
  const cycleDistrict = () => {
    const options = [
      { thai: 'บางมด', en: 'Bang Mod', city: 'Bangkok' },
      { thai: 'สีลม', en: 'Silom', city: 'Bangkok' },
      { thai: 'อารีย์', en: 'Ari', city: 'Bangkok' },
      { thai: 'พระโขนง', en: 'Phra Khanong', city: 'Bangkok' },
    ];
    const idx = options.findIndex(o => o.en === district.en);
    setDistrict(options[(idx + 1) % options.length]);
  };

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)', minHeight: 0, position: 'relative' }}>
      {/* sticky top bar */}
      <div style={{
        background: 'var(--surface)',
        borderBottom: '1px solid var(--border)',
        flexShrink: 0,
      }}>
        <TopBar variant="hier" title="Edit profile" onBack={onBack} />
      </div>

      {/* scrollable form area */}
      <div className="phone-scroll" style={{
        flex: 1, overflow: 'auto',
        padding: '20px 16px 32px',
        display: 'flex', flexDirection: 'column', gap: 24,
      }}>
        {/* 1 — Photo */}
        <div>
          <FieldLabel>Photo</FieldLabel>
          <div style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center',
            gap: 8, padding: '8px 0',
          }}>
            <EditableAvatar person={me} onChange={() => {}} />
            <button
              onClick={() => {}}
              style={{
                background: 'transparent', border: 'none', padding: '4px 8px',
                color: 'var(--green-primary)', fontSize: 15, fontWeight: 600,
                cursor: 'pointer', fontFamily: 'inherit',
              }}>
              Change photo
            </button>
          </div>
        </div>

        {/* 2 — Display name */}
        <div>
          <FieldLabel>Display name</FieldLabel>
          <EpTextField value={name} onChange={setName} placeholder="Your name" />
          <div style={{ fontSize: 12, color: 'var(--text-tertiary)', marginTop: 6, lineHeight: 1.5 }}>
            This is what other swappers see.
          </div>
        </div>

        {/* 3 — Home district */}
        <div>
          <FieldLabel>Home district</FieldLabel>
          <DistrictRow value={district} onOpen={cycleDistrict} />
        </div>

        {/* 4 — Bio */}
        <div>
          <FieldLabel>Bio (optional)</FieldLabel>
          <EpTextArea
            value={bio} onChange={setBio} rows={4} maxLength={BIO_MAX}
            placeholder="A line or two about what you swap and why."
          />
          <div style={{
            fontSize: 12, color: 'var(--text-tertiary)',
            marginTop: 6, textAlign: 'right',
            fontVariantNumeric: 'tabular-nums',
          }}>
            {bio.length}/{BIO_MAX}
          </div>
        </div>

        <div style={{ height: 32 }} />
      </div>

      {/* sticky bottom save */}
      <div style={{
        background: 'var(--surface)',
        borderTop: '1px solid var(--border)',
        padding: '16px',
        flexShrink: 0,
      }}>
        <Button disabled={!valid} onClick={save}>Save changes</Button>
      </div>
    </div>
  );
};

Object.assign(window, { EditProfileScreen });
