// Item picker — single-step bottom sheet (~70% of screen).
// Ploy just swiped right on Fah. She picks ONE of Fah's items to send an
// anonymous expression of interest. No "offer in return" step here — that
// only happens later, after a mutual right-swipe.

const PickerScreen = ({ person, onCancel, onSend }) => {
  const theirItems = itemsBy(person?.id);
  // Mockup default: first item pre-selected so we can show the selected state.
  const [pick, setPick] = React.useState(theirItems[0]?.id || null);

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 10,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
      background: 'rgba(0,0,0,0.4)',
    }}>
      {/* Tap backdrop to dismiss */}
      <div onClick={onCancel} style={{ flex: 1 }} />

      <div style={{
        height: '70%',
        background: 'var(--surface)',
        borderTopLeftRadius: 20,
        borderTopRightRadius: 20,
        boxShadow: 'var(--shadow-modal)',
        display: 'flex', flexDirection: 'column',
        position: 'relative',
      }}>
        {/* Drag handle — 12px from top */}
        <div style={{ display: 'flex', justifyContent: 'center', paddingTop: 12, flexShrink: 0 }}>
          <div style={{ width: 36, height: 4, borderRadius: 2, background: 'var(--border)' }} />
        </div>

        {/* Close X — top-left, 16px from edges */}
        <button onClick={onCancel} aria-label="Close" style={{
          position: 'absolute', top: 16, left: 16,
          width: 32, height: 32, padding: 0,
          border: 'none', background: 'transparent',
          color: 'var(--text-primary)', cursor: 'pointer',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          borderRadius: 8,
        }}>
          <IconX size={24} />
        </button>

        {/* Header — 24px below handle */}
        <div style={{ padding: '24px 16px 0' }}>
          <h2 style={{
            margin: 0,
            fontSize: 22, fontWeight: 600, lineHeight: 1.25,
            color: 'var(--text-primary)',
            letterSpacing: -0.2,
          }}>
            What of {person?.name}'s do you want?
          </h2>
          <p style={{
            margin: '8px 0 0',
            fontSize: 14, lineHeight: 1.5,
            color: 'var(--text-secondary)',
          }}>
            Pick one item to send an anonymous nudge. {person?.name} will see
            your interest in this item if she swipes back.
          </p>
        </div>

        {/* Item grid — 20px below subhead */}
        <div className="phone-scroll" style={{
          flex: 1, minHeight: 0, overflow: 'auto',
          padding: '20px 16px 0',
        }}>
          <div style={{
            display: 'grid',
            gridTemplateColumns: '1fr 1fr',
            gap: 12,
          }}>
            {theirItems.map(it => (
              <ItemPickCard
                key={it.id}
                item={it}
                selected={pick === it.id}
                onClick={() => setPick(it.id)}
              />
            ))}
          </div>
        </div>

        {/* Footer — caption + CTA */}
        <div style={{ padding: '16px 16px 16px', flexShrink: 0 }}>
          <div style={{
            fontSize: 12, lineHeight: 1.4,
            color: 'var(--text-tertiary)',
            textAlign: 'center',
            marginBottom: 12,
          }}>
            You can change your mind later — nothing is locked yet.
          </div>
          <Button
            disabled={!pick}
            onClick={() => onSend?.({ theirPick: itemById(pick) })}
          >
            {`Send interest to ${person?.name}`}
          </Button>
        </div>
      </div>
    </div>
  );
};

// Single item card. --surface-alt bg, photo on top, name + condition pill below.
// Selected state: 2px --green-primary border + checkmark badge top-right of photo.
const ItemPickCard = ({ item, selected, onClick }) => {
  const cat = CATEGORY[item.cat] || {};
  return (
    <div onClick={onClick} style={{
      background: 'var(--surface-alt)',
      borderRadius: 12,
      padding: 12,
      border: selected ? '2px solid var(--green-primary)' : '2px solid transparent',
      cursor: 'pointer',
      boxSizing: 'border-box',
      position: 'relative',
    }}>
      {/* Square photo placeholder with category label */}
      <div style={{ position: 'relative' }}>
        <div style={{
          width: '100%', aspectRatio: '1 / 1',
          borderRadius: 8,
          background: `repeating-linear-gradient(135deg, ${item.swatch}26 0 6px, ${item.swatch}14 6px 12px), ${item.swatch}33`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          overflow: 'hidden',
        }}>
          <span style={{
            fontFamily: 'JetBrains Mono, monospace',
            fontSize: 11, fontWeight: 500,
            color: '#fffe', mixBlendMode: 'difference',
            textAlign: 'center', padding: '0 6px',
          }}>{cat.label?.toLowerCase()}</span>
        </div>

        {/* Selected check overlay — top-right corner of photo */}
        {selected && (
          <div style={{
            position: 'absolute', top: 6, right: 6,
            width: 24, height: 24, borderRadius: '50%',
            background: 'var(--green-primary)', color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 1px 3px rgba(0,0,0,0.15)',
          }}>
            <IconCheck size={16} />
          </div>
        )}
      </div>

      {/* Item name — 12px below photo */}
      <div style={{
        marginTop: 12,
        fontSize: 14, fontWeight: 600, lineHeight: 1.3,
        color: 'var(--text-primary)',
      }}>{item.name}</div>

      {/* Condition pill — 4px below name */}
      <div style={{ marginTop: 4 }}>
        <span style={{
          display: 'inline-block',
          padding: '4px 10px',
          borderRadius: 9999,
          background: 'var(--surface)',
          color: 'var(--text-secondary)',
          fontSize: 11, fontWeight: 500, lineHeight: 1.3,
        }}>{item.cond}</span>
      </div>
    </div>
  );
};

Object.assign(window, { PickerScreen, ItemPickCard });
