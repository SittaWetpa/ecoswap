// Discover / Swipe feed. The card MUST showcase items, not just the photo.
// Photo ~50%, items row clearly visible below.

const SwipeCard = ({ person, items, drag, incomingInterest }) => {
  // drag = { dx, dy, rotating } applied to top card only
  const dx = drag?.dx || 0;
  const dy = drag?.dy || 0;
  const rot = dx / 12;
  const likeOpacity = Math.min(Math.max(dx / 100, 0), 1);
  const skipOpacity = Math.min(Math.max(-dx / 100, 0), 1);
  // Incoming interest mode flips the top-of-card overlays and switches the
  // photo:info split from 52/48 -> 60/40 so the green badge has room to breathe.
  const photoHeight = incomingInterest ? '60%' : '52%';
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: 'var(--surface)',
      borderRadius: 20,
      border: '1px solid var(--border)',
      boxShadow: 'var(--shadow-card)',
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
      transform: drag ? `translate(${dx}px, ${dy}px) rotate(${rot}deg)` : 'none',
      transition: drag ? 'none' : 'transform 280ms cubic-bezier(0.2,0.7,0.2,1), opacity 280ms ease',
      touchAction: 'none'
    }}>
      {/* Photo */}
      <div style={{
        position: 'relative', height: photoHeight, flexShrink: 0,
        background: `linear-gradient(135deg, ${person.color}, ${person.color}cc 60%, ${person.color}99)`
      }}>
        {/* placeholder mono label */}
        <div style={{
          position: 'absolute', inset: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: 'JetBrains Mono, monospace', fontSize: 11,
          color: '#ffffffaa', letterSpacing: 0.5
        }}>portrait of {person.name.toLowerCase()}</div>

        {incomingInterest ?
        <React.Fragment>
            {/* District pill — bucket-based, no km */}
            <div style={{ position: 'absolute', top: 12, left: 12 }}>
              <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 4,
              background: 'rgba(255,255,255,0.85)',
              color: 'var(--text-primary)',
              padding: '4px 10px', borderRadius: 9999,
              fontSize: 11, fontWeight: 500, lineHeight: 1.3,
              backdropFilter: 'blur(4px)'
            }}>
                <IconMapPin size={14} />
                {person.location}
              </span>
            </div>
            {/* Interest badge — THE highlight */}
            <div style={{ position: 'absolute', top: 12, right: 12, maxWidth: '70%' }}>
              <span style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              background: 'var(--green-primary)',
              color: '#fff',
              padding: '6px 12px', borderRadius: 9999,
              fontSize: 13, fontWeight: 600, lineHeight: 1.3,
              boxShadow: '0 2px 6px rgba(15,110,86,0.35)'
            }}>
                <IconHeart size={14} color="#fff" style={{ fill: '#fff' }} />
                {`Wants your ${incomingInterest.name}`}
              </span>
            </div>
          </React.Fragment> :

        <React.Fragment>
            <div style={{ position: 'absolute', top: 12, right: 12 }}>
              <span style={{
              display: 'inline-flex', gap: 4,
              background: 'rgba(255,255,255,0.85)',
              color: 'var(--text-primary)',
              padding: '4px 10px', borderRadius: 9999,
              fontSize: 11, fontWeight: 500, lineHeight: 1.3,
              backdropFilter: 'blur(4px)', alignItems: "center", justifyContent: "flex-start", flexDirection: "row"
            }}>
                <IconMapPin size={14} />
                {person.location}
              </span>
            </div>
          </React.Fragment>
        }
        {/* LIKE/SKIP overlay */}
        <div style={{
          position: 'absolute', top: 28, left: 16,
          opacity: likeOpacity, transform: `rotate(-12deg) scale(${0.9 + likeOpacity * 0.2})`,
          padding: '6px 14px', border: '3px solid var(--green-primary)',
          borderRadius: 8, color: 'var(--green-primary)',
          fontWeight: 700, fontSize: 22, letterSpacing: 2,
          background: '#ffffffee'
        }}>WANT</div>
        <div style={{
          position: 'absolute', top: 28, right: 16,
          opacity: skipOpacity, transform: `rotate(12deg) scale(${0.9 + skipOpacity * 0.2})`,
          padding: '6px 14px', border: '3px solid var(--danger)',
          borderRadius: 8, color: 'var(--danger)',
          fontWeight: 700, fontSize: 22, letterSpacing: 2,
          background: '#ffffffee'
        }}>SKIP</div>
      </div>

      {/* Info section */}
      <div style={{ padding: 16, display: 'flex', flexDirection: 'column', gap: 12, flex: 1, minHeight: 0 }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10 }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ fontSize: 22, fontWeight: 600 }}>{person.name}</div>
            <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 2 }}>{person.location}</div>
          </div>
        </div>

        {/* Items row — THE differentiator */}
        <div style={{ marginTop: 'auto' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
            <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-tertiary)', letterSpacing: 0.5, textTransform: 'uppercase' }}>
              Swapping {items.length} {items.length === 1 ? 'item' : 'items'}
            </div>
            <div style={{ ...{ fontSize: 12, color: incomingInterest ? 'var(--green-primary)' : 'var(--text-tertiary)', fontWeight: incomingInterest ? 500 : 400 }, color: "rgb(29, 158, 117)" }}>tap to see all</div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            {items.slice(0, 3).map((it) =>
            <div key={it.id} style={{ flex: 1, minWidth: 0 }}>
                <ItemThumb item={it} size={'100%'} radius={10} />
                <div style={{ fontSize: 11, fontWeight: 500, color: 'var(--text-primary)', marginTop: 6, lineHeight: 1.3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{it.name}</div>
              </div>
            )}
            {items.length > 3 &&
            <div style={{ width: 60, aspectRatio: '1 / 1', borderRadius: 10, background: 'var(--surface-alt)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 600, color: 'var(--text-secondary)', fontSize: 14, alignSelf: 'flex-start' }}>+{items.length - 3}</div>
            }
          </div>
        </div>
      </div>
    </div>);

};

const PROXIMITY_OPTIONS = [
  { id: 'district',  label: 'Same district',     sub: 'Bang Mod only' },
  { id: 'province',  label: 'Same province',     sub: 'Bangkok area' },
  { id: 'nearby',    label: 'Nearby provinces',  sub: 'Bangkok + 5 surrounding provinces' },
  { id: 'thailand',  label: 'All Thailand',      sub: 'Show everyone' },
];

const IconChevronDown = (p) => <Icon {...p}><path d="m6 9 6 6 6-6"/></Icon>;

const ProximityPicker = ({ open, onClose, value, onPick }) => (
  <Sheet open={open} onClose={onClose} height="50%">
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 16px 4px' }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 18, fontWeight: 600, color: 'var(--text-primary)' }}>Show me swappers in…</div>
        <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 4, lineHeight: 1.4 }}>
          Wider ranges show more people but less local matches.
        </div>
      </div>
      <button onClick={onClose} aria-label="Close" style={{
        border: 'none', background: 'transparent', cursor: 'pointer',
        color: 'var(--text-secondary)', padding: 6, marginLeft: 8,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center'
      }}><IconX size={20} /></button>
    </div>
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4, padding: '12px 12px 16px' }}>
      {PROXIMITY_OPTIONS.map(opt => {
        const selected = opt.id === value;
        return (
          <button key={opt.id} onClick={() => onPick(opt.id)} style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            height: 56, padding: '0 16px', borderRadius: 10,
            background: selected ? 'var(--green-soft)' : 'transparent',
            border: 'none', cursor: 'pointer', textAlign: 'left', width: '100%',
          }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
              <span style={{ fontSize: 15, fontWeight: 500, color: 'var(--text-primary)' }}>{opt.label}</span>
              <span style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{opt.sub}</span>
            </div>
            {selected && <IconCheck size={20} color="var(--green-dark)" />}
          </button>
        );
      })}
    </div>
  </Sheet>
);

const DiscoverScreen = ({ onNavigate, onLike, density, deck, setDeck, empty, interestMap }) => {
  // drag state
  const [drag, setDrag] = React.useState(null);
  const startRef = React.useRef(null);
  const [flying, setFlying] = React.useState(null); // {dir: 'left'|'right'}
  const [proximity, setProximity] = React.useState('district');
  const [pickerOpen, setPickerOpen] = React.useState(false);
  const proximityLabel = PROXIMITY_OPTIONS.find(o => o.id === proximity)?.label || 'Same district';
  const top = deck[0];
  const next = deck[1];

  const finalize = (dir) => {
    setFlying({ dir });
    setTimeout(() => {
      setDrag(null);setFlying(null);
      if (dir === 'right') onLike?.(top);
      setDeck((d) => d.slice(1));
    }, 280);
  };

  const onPointerDown = (e) => {
    if (flying) return;
    startRef.current = { x: e.clientX, y: e.clientY };
    setDrag({ dx: 0, dy: 0 });
    e.currentTarget.setPointerCapture(e.pointerId);
  };
  const onPointerMove = (e) => {
    if (!startRef.current) return;
    setDrag({ dx: e.clientX - startRef.current.x, dy: e.clientY - startRef.current.y });
  };
  const onPointerUp = (e) => {
    if (!startRef.current) return;
    const { dx = 0, dy = 0 } = drag || {};
    startRef.current = null;
    if (dx > 80) { finalize('right'); return; }
    if (dx < -80) { finalize('left'); return; }
    // Tap detection: if movement under 8px in both axes, treat as tap
    if (Math.abs(dx) < 8 && Math.abs(dy) < 8) {
      setDrag(null);
      onNavigate?.('detail', { person: top });
      return;
    }
    setDrag(null);
  };

  const triggerSwipe = (dir) => {
    if (flying || !top) return;
    setDrag({ dx: dir === 'right' ? 90 : -90, dy: 0 });
    setTimeout(() => finalize(dir), 30);
  };

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface-alt)' }}>
      <TopBar variant="top" left={<Wordmark size={18} />} />
      {/* Filter chip row — single active proximity bucket, tappable */}
      <div style={{ padding: '0 16px 12px', display: 'flex', gap: 8, alignItems: 'center', background: 'var(--surface)', borderBottom: '1px solid var(--border)' }}>
        <button onClick={() => setPickerOpen(true)} style={{
          display: 'inline-flex', alignItems: 'center', gap: 4,
          background: 'var(--green-soft)', color: 'var(--green-dark)',
          padding: '4px 10px', borderRadius: 9999,
          fontSize: 12, fontWeight: 500, lineHeight: 1.3,
          border: 'none', cursor: 'pointer',
        }}>
          <IconMapPin size={12} />
          {proximityLabel}
          <IconChevronDown size={12} color="var(--green-dark)" style={{ opacity: 0.6 }} />
        </button>
      </div>
      <ProximityPicker
        open={pickerOpen}
        onClose={() => setPickerOpen(false)}
        value={proximity}
        onPick={(id) => { setProximity(id); setPickerOpen(false); }}
      />

      {/* Card stack */}
      <div style={{ flex: 1, position: 'relative', padding: 16, display: 'flex', flexDirection: 'column' }}>
        {empty || !top ?
        <EmptyState
          icon={<IconCompass size={40} />}
          headline="No one nearby yet"
          description="Try broadening to nearby districts, or check back later — new swappers join every day."
          cta="Include nearby districts"
          onCta={() => alert('Now showing nearby districts')} /> :


        <>
            <div style={{ position: 'relative', flex: 1, minHeight: 0 }}>
              {/* underlay card */}
              {next &&
            <div style={{ position: 'absolute', inset: 0, transform: 'scale(0.96) translateY(8px)', opacity: 0.7, pointerEvents: 'none' }}>
                  <SwipeCard person={next} items={itemsBy(next.id)} incomingInterest={interestMap?.[next.id]} />
                </div>
            }
              {/* top card */}
              <div
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
              onPointerCancel={onPointerUp}
              style={{
                position: 'absolute', inset: 0,
                cursor: 'pointer',
                // applying fly-off transform
                ...(flying ? {
                  transform: `translate(${flying.dir === 'right' ? 600 : -600}px, 60px) rotate(${flying.dir === 'right' ? 30 : -30}deg)`,
                  opacity: 0,
                  transition: 'transform 280ms ease-out, opacity 240ms ease-out'
                } : {})
              }}>
              
                <SwipeCard person={top} items={itemsBy(top.id)} drag={drag} incomingInterest={interestMap?.[top.id]} />
              </div>
            </div>

            {/* Action buttons */}
            <div style={{ display: 'flex', gap: 24, justifyContent: 'center', padding: '20px 0 12px' }}>
              <button onClick={() => triggerSwipe('left')} style={swipeBtn('var(--danger)', 'var(--danger-soft)')}>
                <IconX size={26} />
              </button>
              <button onClick={() => triggerSwipe('right')} style={swipeBtn('var(--green-primary)', 'var(--green-soft)')}>
                <IconHeart size={26} />
              </button>
            </div>
          </>
        }
      </div>
    </div>);

};

const swipeBtn = (iconColor, borderColor) => ({
  width: 56, height: 56, borderRadius: '50%',
  background: 'var(--surface)', border: `1px solid ${borderColor}`,
  color: iconColor, display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
  boxShadow: 'var(--shadow-card)', cursor: 'pointer'
});

Object.assign(window, { DiscoverScreen, SwipeCard, ProximityPicker });