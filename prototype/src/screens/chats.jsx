// Chats list — empty state when no matches, else list of match cards.

const CHATS = [
  { id: 'fah-1',  person: 'fah',  trade: { mine: 'mine-mug', theirs: 'kettle' }, last: "Perfect, see you there 🙌", time: '14:06', unread: 0, mine: true },
  { id: 'ploy-1', person: 'ploy', trade: { mine: 'mine-jacket', theirs: 'tote' }, last: 'Sure, I can do Saturday.', time: 'Yesterday', unread: 2, mine: false },
  { id: 'mint-1', person: 'mint', trade: { mine: 'mine-books', theirs: 'mat' }, last: 'You: Sounds good!', time: 'Mon', unread: 0, mine: true },
  { id: 'beam-1', person: 'beam', trade: { mine: 'mine-lamp', theirs: 'books2' }, last: 'Ready when you are.', time: 'May 02', unread: 0, mine: false },
];

const ChatsScreen = ({ onOpen, empty }) => {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      <TopBar variant="top" left={
        <div style={{ fontSize: 22, fontWeight: 600 }}>Chats</div>
      } />
      <div style={{ height: 1, background: 'var(--border)' }} />
      {empty ? (
        <EmptyState
          icon={<IconMsg size={40} />}
          headline="No matches yet"
          description="Start swiping on the Discover tab to find people to swap with."
          cta="Go to Discover"
          onCta={() => alert('Tab')}
        />
      ) : (
        <div className="phone-scroll" style={{ flex: 1, overflow: 'auto' }}>
          {CHATS.map(c => {
            const p = personById(c.person);
            return (
              <div key={c.id} onClick={() => onOpen?.(c)} style={{
                display: 'flex', alignItems: 'flex-start', gap: 12,
                padding: '14px 16px', cursor: 'pointer',
                borderBottom: '1px solid var(--border)',
              }}>
                <Avatar person={p} size={48} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                    <span style={{ fontSize: 15, fontWeight: 600 }}>{p.name}</span>
                    <span style={{ flex: 1 }} />
                    <span style={{ fontSize: 12, color: c.unread ? 'var(--green-primary)' : 'var(--text-tertiary)', fontWeight: c.unread ? 600 : 400 }}>{c.time}</span>
                  </div>
                  {/* trade pill */}
                  <div style={{
                    display: 'inline-flex', alignItems: 'center', gap: 6,
                    padding: '3px 8px', background: 'var(--surface-alt)',
                    borderRadius: 9999, fontSize: 11, fontWeight: 500, color: 'var(--text-secondary)',
                    marginBottom: 6,
                  }}>
                    {itemById(c.trade.mine)?.name?.split(' ')[0]}
                    <IconSwap size={10} />
                    {itemById(c.trade.theirs)?.name?.split(' ')[0]}
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <div style={{ flex: 1, fontSize: 14, color: c.unread ? 'var(--text-primary)' : 'var(--text-secondary)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', fontWeight: c.unread ? 500 : 400 }}>
                      {c.last}
                    </div>
                    {c.unread > 0 && (
                      <span style={{
                        minWidth: 18, height: 18, borderRadius: 9, padding: '0 6px',
                        background: 'var(--green-primary)', color: '#fff',
                        fontSize: 11, fontWeight: 600,
                        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
                      }}>{c.unread}</span>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

Object.assign(window, { ChatsScreen, CHATS });
