// My items — 2-col grid + floating + button. Empty state.
const MyItemsScreen = ({ onBack, onAdd, onEdit, empty }) => {
  const items = itemsBy('me');
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)', position: 'relative' }}>
      <TopBar variant="hier" title="My items" onBack={onBack} />
      {(empty || items.length === 0) ? (
        <EmptyState
          icon={<IconPlus size={40} />}
          headline="Nothing to swap yet"
          description="Add an item from your room — books, clothes, kitchen things — anything you don't use anymore."
          cta="Add your first item"
          onCta={onAdd}
        />
      ) : (
        <div className="phone-scroll" style={{ flex: 1, overflow: 'auto', padding: '8px 16px 100px' }}>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', padding: '6px 0 12px' }}>
            {items.length} items · all visible to nearby swappers
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            {items.map(it => (
              <div key={it.id} style={{
                background: 'var(--surface-alt)', borderRadius: 12, padding: 12,
                position: 'relative',
              }}>
                <ItemThumb item={it} size={'100%'} radius={8} />
                <div style={{ marginTop: 8, fontSize: 14, fontWeight: 600, lineHeight: 1.3 }}>{it.name}</div>
                <div style={{ marginTop: 4, display: 'flex', gap: 4, alignItems: 'center', justifyContent: 'space-between' }}>
                  <Pill variant="cond">{it.cond}</Pill>
                  <IconBtn
                    style={{ width: 28, height: 28 }}
                    onClick={() => onEdit?.(it)}
                    ariaLabel={`Edit ${it.name}`}
                  ><IconPencil size={14} /></IconBtn>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
      {/* FAB */}
      <button onClick={onAdd} style={{
        position: 'absolute', right: 16, bottom: 16, width: 56, height: 56,
        borderRadius: '50%', border: 'none',
        background: 'var(--green-primary)', color: '#fff',
        boxShadow: '0 6px 16px rgba(29,158,117,0.35)',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
      }}>
        <IconPlus size={26} />
      </button>
    </div>
  );
};
Object.assign(window, { MyItemsScreen });
