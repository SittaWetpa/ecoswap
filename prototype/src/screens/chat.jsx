// Match chat — header with avatar + agreed trade pill + Ready button.
const ChatScreen = ({ chat, onBack, onReadyExchange }) => {
  if (!chat) return null;
  const p = personById(chat.person);
  const mine = itemById(chat.trade.mine), theirs = itemById(chat.trade.theirs);
  const [text, setText] = React.useState('');
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      {/* Header */}
      <div style={{
        padding: '8px 4px 8px',
        background: 'var(--surface)',
        borderBottom: '1px solid var(--border)',
        flexShrink: 0,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
          <IconBtn onClick={onBack}><IconBack /></IconBtn>
          <Avatar person={p} size={36} />
          <div style={{ flex: 1, paddingLeft: 8 }}>
            <div style={{ fontSize: 15, fontWeight: 600 }}>{p.name}</div>
            <div style={{ fontSize: 12, color: 'var(--text-secondary)' }}>{p.location} · Active now</div>
          </div>
        </div>
        {/* Agreed trade pill */}
        <div style={{
          margin: '8px 12px 0',
          padding: '8px 12px',
          background: 'var(--surface-alt)',
          borderRadius: 12, display: 'flex', alignItems: 'center', gap: 10,
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, flex: 1, minWidth: 0 }}>
            <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', letterSpacing: 0.4, textTransform: 'uppercase' }}>Trade</span>
            <span style={{ fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{mine?.name}</span>
            <IconSwap size={12} style={{ color: 'var(--green-primary)', flexShrink: 0 }} />
            <span style={{ fontSize: 13, fontWeight: 500, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{theirs?.name}</span>
          </div>
          <button onClick={onReadyExchange} style={{
            border: 'none', background: 'var(--green-primary)', color: '#fff',
            padding: '6px 12px', borderRadius: 9999, fontSize: 12, fontWeight: 600,
            display: 'inline-flex', alignItems: 'center', gap: 4, cursor: 'pointer', flexShrink: 0,
          }}>
            <IconQR size={12} /> Exchange
          </button>
        </div>
      </div>

      {/* Messages */}
      <div className="phone-scroll" style={{ flex: 1, overflow: 'auto', padding: '16px 16px 8px', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ alignSelf: 'center', fontSize: 11, color: 'var(--text-tertiary)', padding: '4px 12px', background: 'var(--surface-alt)', borderRadius: 9999 }}>
          Today
        </div>
        {CHAT_MESSAGES.map((m, i) => (
          <Bubble key={i} who={m.who} text={m.text} time={m.time} />
        ))}
        <div style={{ alignSelf: 'center', fontSize: 11, color: 'var(--text-tertiary)', marginTop: 8 }}>
          When you meet, tap <b style={{ color: 'var(--green-primary)' }}>Exchange</b> to scan each other's QR.
        </div>
      </div>

      {/* Input */}
      <div style={{ padding: 12, borderTop: '1px solid var(--border)', display: 'flex', gap: 8, alignItems: 'center', background: 'var(--surface)', flexShrink: 0 }}>
        <input value={text} onChange={e => setText(e.target.value)} placeholder="Message..." style={{
          flex: 1, height: 40, padding: '0 14px',
          background: 'var(--surface-alt)', border: '1px solid var(--border)',
          borderRadius: 9999, fontSize: 14, outline: 'none',
        }} />
        <button style={{
          width: 40, height: 40, borderRadius: '50%', border: 'none',
          background: text ? 'var(--green-primary)' : 'var(--surface-alt)',
          color: text ? '#fff' : 'var(--text-tertiary)',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }} onClick={() => setText('')}>
          <IconSend size={18} />
        </button>
      </div>
    </div>
  );
};

const Bubble = ({ who, text, time }) => {
  const own = who === 'me';
  return (
    <div style={{ display: 'flex', justifyContent: own ? 'flex-end' : 'flex-start' }}>
      <div style={{
        maxWidth: '75%',
        background: own ? 'var(--green-primary)' : 'var(--surface-alt)',
        color: own ? '#fff' : 'var(--text-primary)',
        padding: '10px 14px',
        borderRadius: 14,
        borderBottomRightRadius: own ? 6 : 14,
        borderBottomLeftRadius: own ? 14 : 6,
        fontSize: 14, lineHeight: 1.4,
      }}>
        {text}
        <div style={{ fontSize: 10, opacity: 0.7, marginTop: 4, textAlign: 'right' }}>{time}</div>
      </div>
    </div>
  );
};

Object.assign(window, { ChatScreen });
