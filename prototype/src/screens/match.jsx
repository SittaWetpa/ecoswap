// Match screen — focus on the TRADE, not just avatars.
// Items side-by-side with ↔, both names, "It's a Match!", chat CTA.

const MatchScreen = ({ proposal, onChat, onKeep }) => {
  if (!proposal) return null;
  const { person, theirPick, myPick } = proposal;
  return (
    <div style={{ flex: 1, position: 'relative', background: 'rgba(0,0,0,0.55)', display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '24px 20px' }}>
      <div style={{ textAlign: 'center', color: '#fff' }}>
        <div style={{ fontSize: 14, fontWeight: 600, letterSpacing: 2, opacity: 0.9, textTransform: 'uppercase', marginBottom: 8 }}>
          It's a match!
        </div>
        <div style={{ fontSize: 32, fontWeight: 700, lineHeight: 1.15, letterSpacing: -0.5 }}>
          You're swapping with<br />{person.name}.
        </div>
        <div style={{ marginTop: 8, fontSize: 15, opacity: 0.85 }}>
          You both want each other's items.
        </div>
      </div>

      {/* Trade card */}
      <div style={{
        marginTop: 28,
        background: 'var(--surface)', borderRadius: 20, padding: 20,
        boxShadow: 'var(--shadow-modal)',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          {/* Your side */}
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 10 }}>
              <Avatar person={{ name: 'You', color: 'var(--green-soft)' }} size={36} ring="#fff" />
            </div>
            <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>You give</div>
            <ItemThumb item={myPick} size={'100%'} radius={10} />
            <div style={{ marginTop: 8, fontSize: 13, fontWeight: 600, lineHeight: 1.3 }}>{myPick.name}</div>
          </div>

          {/* Swap arrow column */}
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, color: 'var(--green-primary)', padding: '0 2px' }}>
            <IconSwap size={28} />
            <div style={{ fontSize: 11, fontWeight: 600, letterSpacing: 0.5, textTransform: 'uppercase' }}>swap</div>
          </div>

          {/* Their side */}
          <div style={{ flex: 1, textAlign: 'center' }}>
            <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 10 }}>
              <Avatar person={{ ...person, color: 'var(--green-soft)' }} size={36} ring="#fff" />
            </div>
            <div style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: 0.5, marginBottom: 8 }}>You get</div>
            <ItemThumb item={theirPick} size={'100%'} radius={10} />
            <div style={{ marginTop: 8, fontSize: 13, fontWeight: 600, lineHeight: 1.3 }}>{theirPick.name}</div>
          </div>
        </div>

        <div style={{ marginTop: 16, padding: 12, background: 'var(--green-soft)', borderRadius: 10, display: 'flex', alignItems: 'center', gap: 10 }}>
          <IconLeaf size={16} style={{ color: 'var(--green-dark)' }} />
          <div style={{ fontSize: 13, color: 'var(--green-dark)', lineHeight: 1.4 }}>
            Complete this swap to save ~<b>{((theirPick.weight ?? CATEGORY[theirPick.cat].typical_weight) * CATEGORY[theirPick.cat].co2_per_kg).toFixed(1)} kg CO₂</b>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 24, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <Button onClick={onChat} icon={<IconMsg size={18} />}>Start chatting</Button>
        <Button variant="ghost" onClick={onKeep} style={{ color: '#fff' }}>Keep swiping</Button>
      </div>

      <style>{`
        @keyframes matchIn { from { opacity: 0; transform: translateY(-12px); } to { opacity: 1; transform: none; } }
        @keyframes matchCard { from { opacity: 0; transform: scale(0.85); } to { opacity: 1; transform: scale(1); } }
      `}</style>
    </div>
  );
};

Object.assign(window, { MatchScreen });
