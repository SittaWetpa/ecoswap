// User detail — full-screen modal. Photo on top, bio, items grid, sticky Like.
// Tapping an item card opens an ItemDetailSheet (bottom sheet, 70% tall).

const IconWeight = (p) => (
  <Icon {...p}>
    <path d="M6 4h12l2 16H4L6 4z" />
    <path d="M9 8a3 3 0 0 1 6 0" />
  </Icon>
);

const ItemDetailSheet = ({ item, person, onClose }) => {
  const cat = CATEGORY[item.cat] || {};
  const weight = item.weight;
  const weightLabel = weight != null
    ? `Approx. ${weight} kg`
    : `Approx. ~${cat.typical_weight} kg`;

  return (
    <Sheet open onClose={onClose} height="70%">
      {/* Close icon — sits over the rounded sheet top, 16px from edges */}
      <div style={{ position: 'relative', flexShrink: 0 }}>
        <IconBtn
          ariaLabel="Close"
          onClick={onClose}
          style={{
            position: 'absolute', top: 16, left: 16,
            background: 'var(--surface-alt)',
            width: 32, height: 32,
            zIndex: 2,
          }}
        ><IconX size={20} /></IconBtn>
      </div>

      {/* Body */}
      <div className="phone-scroll" style={{
        flex: 1, overflow: 'auto',
        padding: 16, paddingTop: 24,
      }}>
        {/* Photo — full-width minus 32px gutters, 4:3, radius-lg */}
        <div style={{
          width: '100%', aspectRatio: '4 / 3', borderRadius: 16,
          background: `repeating-linear-gradient(135deg, ${item.swatch}26 0 10px, ${item.swatch}14 10px 20px), ${item.swatch}33`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          overflow: 'hidden',
        }}>
          <span style={{
            fontFamily: 'JetBrains Mono, monospace',
            fontSize: 13, color: '#fffe',
            mixBlendMode: 'difference',
            fontWeight: 500, letterSpacing: 0.3,
          }}>{(cat.label || '').toLowerCase()}</span>
        </div>

        {/* Name */}
        <div style={{
          marginTop: 24,
          fontSize: 22, fontWeight: 600, color: 'var(--text-primary)',
          lineHeight: 1.25,
        }}>{item.name}</div>

        {/* Category · condition */}
        <div style={{
          marginTop: 8,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{cat.label}</span>
          <span style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>·</span>
          <Pill variant="cond">{item.cond}</Pill>
        </div>

        {/* Weight */}
        <div style={{
          marginTop: 16,
          display: 'flex', alignItems: 'center', gap: 6,
          fontSize: 12, color: 'var(--text-secondary)',
        }}>
          <IconWeight size={16} />
          <span>{weightLabel}</span>
        </div>

        {/* Description */}
        <div style={{ marginTop: 24 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 6 }}>
            Description
          </div>
          {item.desc ? (
            <div style={{ fontSize: 14, color: 'var(--text-primary)', lineHeight: 1.5 }}>
              {item.desc}
            </div>
          ) : (
            <div style={{ fontSize: 14, fontStyle: 'italic', color: 'var(--text-tertiary)', lineHeight: 1.5 }}>
              {person.name} didn't add a description.
            </div>
          )}
        </div>

        {/* Looking for in return */}
        <div style={{ marginTop: 24 }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text-primary)', marginBottom: 6 }}>
            Looking for in return
          </div>
          {item.want ? (
            <div style={{ fontSize: 14, color: 'var(--text-primary)', lineHeight: 1.5 }}>
              {item.want}
            </div>
          ) : (
            <div style={{ fontSize: 14, fontStyle: 'italic', color: 'var(--text-tertiary)', lineHeight: 1.5 }}>
              Open to anything.
            </div>
          )}
        </div>

        {/* Owner attribution */}
        <div style={{
          marginTop: 24,
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <Avatar person={person} size={24} />
          <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>
            Owned by {person.name}
          </span>
        </div>
      </div>
    </Sheet>
  );
};

const UserDetailScreen = ({ person, onBack, onLike }) => {
  if (!person) return null;
  const items = itemsBy(person.id);
  const [openItem, setOpenItem] = React.useState(null);

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)', position: 'relative' }}>
      <style>{`
        .ud-item-card { transition: background 80ms ease; }
        .ud-item-card:active { background: var(--border) !important; }
      `}</style>
      <div className="phone-scroll" style={{ flex: 1, overflow: 'auto', paddingBottom: 100 }}>
        {/* Photo */}
        <div style={{
          height: 360, position: 'relative',
          background: `linear-gradient(180deg, ${person.color} 0%, ${person.color}cc 100%)`,
        }}>
          <div style={{ position: 'absolute', top: 16, left: 16 }}>
            <IconBtn style={{ background: 'rgba(255,255,255,0.9)' }} onClick={onBack}><IconBack /></IconBtn>
          </div>
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, padding: '32px 16px 20px',
            background: 'linear-gradient(to bottom, transparent, rgba(0,0,0,0.5))', color: '#fff' }}>
            <div style={{ fontSize: 28, fontWeight: 600 }}>{person.name}</div>
            <div style={{ fontSize: 14, opacity: 0.9, marginTop: 4 }}>{person.location} · Same district</div>
          </div>
        </div>

        {/* Bio */}
        <div style={{ padding: '20px 16px', display: 'flex', flexDirection: 'column', gap: 16 }}>
          <p style={{ margin: 0, fontSize: 15, lineHeight: 1.5, color: 'var(--text-primary)' }}>{person.bio}</p>

          <div>
            <div style={{ fontSize: 16, fontWeight: 600, marginBottom: 12 }}>{person.name}'s items ({items.length})</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
              {items.map(it => (
                <div
                  key={it.id}
                  className="ud-item-card"
                  onClick={() => setOpenItem(it)}
                  style={{
                    background: 'var(--surface-alt)', borderRadius: 12, padding: 12,
                    cursor: 'pointer',
                  }}
                >
                  <ItemThumb item={it} size={'100%'} radius={8} />
                  <div style={{ marginTop: 8, fontSize: 14, fontWeight: 600 }}>{it.name}</div>
                  <div style={{ marginTop: 4, display: 'flex', gap: 6 }}>
                    <Pill variant="cond">{it.cond}</Pill>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Sticky Like */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: 16, background: 'var(--surface)', borderTop: '1px solid var(--border)' }}>
        <Button onClick={() => onLike?.(person)} icon={<IconHeart size={18} />}>I want to swap with {person.name}</Button>
      </div>

      {openItem && (
        <ItemDetailSheet
          item={openItem}
          person={person}
          onClose={() => setOpenItem(null)}
        />
      )}
    </div>
  );
};
Object.assign(window, { UserDetailScreen });
