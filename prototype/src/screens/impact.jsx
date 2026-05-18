// Impact Tracker — 3 variations, switchable via tweaks.
// Variant A: Data-confident dashboard
// Variant B: Story-driven timeline
// Variant C: Comparison vs goal & average

const calcImpact = () => {
  // Per swap: CO2 saved = weight(received) × CO2 intensity of its category
  // (the new-production footprint of the item you'd have otherwise bought).
  // Waste diverted = weight of the item you gave. Missing weights fall back
  // to the category's typical_weight.
  let co2 = 0,waste = 0;
  const rows = TRADES.
  map((t) => {
    const mine = itemById(t.mine),theirs = itemById(t.theirs);
    if (!mine || !theirs) return null;
    const theirCat = CATEGORY[theirs.cat];
    const mineCat = CATEGORY[mine.cat];
    const theirWeight = theirs.weight ?? theirCat.typical_weight;
    const mineWeight = mine.weight ?? mineCat.typical_weight;
    const c = theirWeight * theirCat.co2_per_kg;
    const w = mineWeight;
    co2 += c;waste += w;
    return { ...t, mine, theirs, c: +c.toFixed(1), w: +w.toFixed(1), person: personById(t.with) };
  }).
  filter(Boolean);
  return { co2: +co2.toFixed(1), waste: +waste.toFixed(1), items: rows.length, rows };
};

const ImpactScreen = ({ variant = 'dashboard', onOpenTrade, empty }) => {
  const data = calcImpact();
  if (empty) {
    return (
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
        <TopBar variant="top" left={<div style={{ fontSize: 22, fontWeight: 600 }}>Impact</div>} />
        <EmptyState
          icon={<IconLeaf size={40} />}
          headline="Your impact starts soon"
          description="After your first swap, you'll see how much CO₂ and waste you've kept out of the landfill." />
        
      </div>);

  }

  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', background: 'var(--surface)' }}>
      <TopBar variant="top" left={<div style={{ fontSize: 22, fontWeight: 600 }}>Impact</div>} />
      <div className="phone-scroll" style={{ flex: 1, overflow: 'auto' }}>
        {variant === 'dashboard' && <ImpactDashboard data={data} onOpenTrade={onOpenTrade} />}
        {variant === 'timeline' && <ImpactTimeline data={data} onOpenTrade={onOpenTrade} />}
        {variant === 'compare' && <ImpactCompare data={data} onOpenTrade={onOpenTrade} />}
      </div>
    </div>);

};

// ─── A: Dashboard ──────────────────────────────────────────────────────────
const ImpactDashboard = ({ data, onOpenTrade }) =>
<div style={{ padding: '16px 16px 40px' }}>
    {/* Hero number */}
    <div style={{ padding: '24px 16px 28px', textAlign: 'center' }}>
      <div style={{ fontSize: 13, color: 'var(--text-secondary)', fontWeight: 500 }}>CO₂ kept out of new production</div>
      <div style={{ marginTop: 8, fontSize: 64, fontWeight: 700, color: 'var(--green-primary)', letterSpacing: -2.5, lineHeight: 1, fontVariantNumeric: 'tabular-nums' }}>
        {data.co2.toFixed(1)}<span style={{ fontSize: 28, fontWeight: 500, color: 'var(--text-secondary)', marginLeft: 4 }}>kg</span>
      </div>
      <div style={{ marginTop: 10, fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'JetBrains Mono, monospace' }}>
        {data.items} swaps · weight × category CO₂ factor
      </div>
    </div>

    {/* Two metric cards */}
    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
      <MetricCard icon={<IconSwap size={16} />} value={TRADES.length} unit="" label="Swaps completed" />
      <MetricCard icon={<IconTrash size={16} />} value={data.waste.toFixed(1)} unit="kg" label="Waste diverted" />
    </div>

    {/* Recent trades */}
    <div style={{ marginTop: 24 }}>
      <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
        <div style={{ fontSize: 16, fontWeight: 600 }}>Recent swaps</div>
        <a style={{ fontSize: 13, color: 'var(--green-primary)', fontWeight: 500, cursor: 'pointer' }}></a>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {data.rows.slice(0, 4).map((r, i) => <TradeRow key={i} row={r} onClick={() => onOpenTrade?.(r)} />)}
      </div>
    </div>
  </div>;


const MetricCard = ({ icon, value, unit, label }) =>
<div style={{ background: 'var(--green-soft)', borderRadius: 12, padding: 16 }}>
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: 'var(--green-dark)' }}>
      {icon}
      <span style={{ fontSize: 11, fontWeight: 600, textTransform: 'uppercase', letterSpacing: 0.4 }}>{label}</span>
    </div>
    <div style={{ marginTop: 10, fontSize: 28, fontWeight: 700, color: 'var(--text-primary)', fontVariantNumeric: 'tabular-nums' }}>
      {value}{unit && <span style={{ fontSize: 14, fontWeight: 500, color: 'var(--text-secondary)', marginLeft: 4 }}>{unit}</span>}
    </div>
  </div>;


const TradeRow = ({ row, onClick }) =>
<div onClick={onClick} style={{
  display: 'flex', alignItems: 'center', gap: 12, padding: 12,
  background: 'var(--surface-alt)', borderRadius: 12, cursor: onClick ? 'pointer' : 'default'
}}>
    <Avatar person={row.person} size={36} />
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13, fontWeight: 500 }}>
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.mine.name.split(' ')[0]}</span>
        <IconSwap size={12} style={{ color: 'var(--green-primary)', flexShrink: 0 }} />
        <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.theirs.name.split(' ')[0]}</span>
      </div>
      <div style={{ fontSize: 11, color: 'var(--text-secondary)', marginTop: 2 }}>{row.date} · with {row.person.name}</div>
    </div>
    <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--green-primary)', fontVariantNumeric: 'tabular-nums' }}>+{row.c.toFixed(1)} kg</div>
  </div>;


// ─── B: Timeline ──────────────────────────────────────────────────────────
const ImpactTimeline = ({ data, onOpenTrade }) => {
  // Build running total
  let running = 0;
  const rowsWithTotal = data.rows.slice().reverse().map((r) => {
    running += r.c;
    return { ...r, running: +running.toFixed(1) };
  }).reverse();
  return (
    <div style={{ padding: '16px 0 40px' }}>
      <div style={{ padding: '16px 16px 4px' }}>
        <div style={{ fontSize: 13, color: 'var(--text-secondary)', fontWeight: 500 }}>You've been swapping since March</div>
        <div style={{ marginTop: 6, fontSize: 40, fontWeight: 700, color: 'var(--green-primary)', letterSpacing: -1.5, fontVariantNumeric: 'tabular-nums' }}>
          {data.co2.toFixed(1)} kg CO₂
        </div>
        <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>across {TRADES.length} swaps</div>
      </div>

      {/* Timeline */}
      <div style={{ padding: '20px 16px 0' }}>
        <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-secondary)', textTransform: 'uppercase', letterSpacing: 0.4, marginBottom: 12 }}>Trade history</div>
        <div style={{ position: 'relative' }}>
          <div style={{ position: 'absolute', left: 11, top: 6, bottom: 6, width: 2, background: 'var(--border)' }} />
          {rowsWithTotal.map((r, i) => {
            const theirWeight = r.theirs.weight ?? CATEGORY[r.theirs.cat].typical_weight;
            return (
              <div key={i} onClick={() => onOpenTrade?.(r)} style={{ display: 'flex', gap: 16, paddingBottom: 18, cursor: 'pointer', position: 'relative' }}>
              <div style={{
                  width: 24, height: 24, borderRadius: '50%',
                  background: 'var(--green-primary)', color: '#fff', flexShrink: 0,
                  display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 1
                }}>
                <IconSwap size={12} />
              </div>
              <div style={{ flex: 1, paddingTop: 2 }}>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                  <div style={{ fontSize: 12, color: 'var(--text-tertiary)', fontFamily: 'JetBrains Mono, monospace' }}>{r.date}</div>
                  <div style={{ fontSize: 12, color: 'var(--text-tertiary)' }}>total: <b style={{ color: 'var(--text-primary)' }}>{r.running} kg</b></div>
                </div>
                <div style={{
                    marginTop: 8, padding: 12, background: 'var(--surface-alt)', borderRadius: 12,
                    display: 'flex', alignItems: 'center', gap: 8
                  }}>
                  <ItemThumb item={r.mine} size={44} radius={6} />
                  <IconSwap size={14} style={{ color: 'var(--green-primary)' }} />
                  <ItemThumb item={r.theirs} size={44} radius={6} />
                  <div style={{ flex: 1, minWidth: 0, paddingLeft: 4 }}>
                    <div style={{ fontSize: 13, fontWeight: 500, lineHeight: 1.3 }}>with {r.person.name}</div>
                    <div style={{ fontSize: 11, color: 'var(--text-secondary)', marginTop: 2 }}>
                      <span style={{ fontFamily: 'JetBrains Mono, monospace' }}>
                        {CATEGORY[r.theirs.cat].label.toLowerCase()} · {theirWeight}kg × {CATEGORY[r.theirs.cat].co2_per_kg}
                      </span> = <b style={{ color: 'var(--green-primary)' }}>+{r.c.toFixed(1)} kg</b>
                    </div>
                  </div>
                </div>
              </div>
            </div>);

          })}
        </div>
      </div>
    </div>);

};

// ─── C: Comparison ────────────────────────────────────────────────────────
const ImpactCompare = ({ data, onOpenTrade }) => {
  const goal = 60;
  const pct = Math.min(100, data.co2 / goal * 100);
  return (
    <div style={{ padding: '16px 16px 40px' }}>
      {/* Goal arc */}
      <div style={{ padding: '16px 0 20px', display: 'flex', justifyContent: 'center' }}>
        <GoalArc value={data.co2} goal={goal} />
      </div>
      <div style={{ textAlign: 'center', fontSize: 13, color: 'var(--text-secondary)' }}>
        You're <b style={{ color: 'var(--green-primary)' }}>{pct.toFixed(0)}%</b> of the way to your monthly goal.
      </div>

      {/* Vs avg user */}
      <Card style={{ marginTop: 20 }}>
        <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)' }}>You vs. average swapper</div>
        <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
          <CompareRow label="You" value={data.co2} max={50} color="var(--green-primary)" bold />
          <CompareRow label="Avg user" value={IMPACT.avgUserCo2} max={50} color="var(--text-tertiary)" />
        </div>
        <div style={{ marginTop: 12, padding: 10, background: 'var(--green-soft)', borderRadius: 8, fontSize: 13, color: 'var(--green-dark)' }}>
          You've saved <b>{(data.co2 / IMPACT.avgUserCo2).toFixed(1)}×</b> more CO₂ than the average swapper this month.
        </div>
      </Card>

      {/* By category */}
      <Card style={{ marginTop: 12 }}>
        <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-secondary)', marginBottom: 12 }}>By category</div>
        <CategoryBreakdown rows={data.rows} />
      </Card>

      {/* Equivalence */}
      <div style={{ marginTop: 12, padding: 16, background: 'var(--surface-alt)', borderRadius: 12 }}>
        <div style={{ fontSize: 13, color: 'var(--text-secondary)' }}>That's roughly</div>
        <div style={{ marginTop: 8, display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          <Pill variant="cond" style={{ padding: '6px 10px' }}>{Math.round(data.co2 / 5)} car trips skipped</Pill>
          <Pill variant="cond" style={{ padding: '6px 10px' }}>{Math.round(data.co2 / 2.3)} trees / yr</Pill>
          <Pill variant="cond" style={{ padding: '6px 10px' }}>{Math.round(data.co2 * 11)} phone charges</Pill>
        </div>
      </div>
    </div>);

};

const GoalArc = ({ value, goal }) => {
  const size = 220,stroke = 14;
  const r = (size - stroke) / 2;
  const cx = size / 2,cy = size / 2;
  const C = 2 * Math.PI * r;
  // arc from 135° to 405° (270° total)
  const arcLen = C * (270 / 360);
  const pct = Math.min(1, value / goal);
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      <circle cx={cx} cy={cy} r={r} fill="none" stroke="var(--surface-alt)" strokeWidth={stroke}
      strokeDasharray={`${arcLen} ${C}`} strokeLinecap="round"
      transform={`rotate(135 ${cx} ${cy})`} />
      <circle cx={cx} cy={cy} r={r} fill="none" stroke="var(--green-primary)" strokeWidth={stroke}
      strokeDasharray={`${arcLen * pct} ${C}`} strokeLinecap="round"
      transform={`rotate(135 ${cx} ${cy})`} />
      <text x={cx} y={cy - 4} textAnchor="middle" fontSize="38" fontWeight="700" fill="var(--text-primary)" style={{ fontVariantNumeric: 'tabular-nums' }}>{value.toFixed(1)}</text>
      <text x={cx} y={cy + 18} textAnchor="middle" fontSize="13" fill="var(--text-secondary)" fontWeight="500">of {goal} kg goal</text>
      <text x={cx} y={cy + 50} textAnchor="middle" fontSize="11" fill="var(--text-tertiary)" style={{ fontFamily: 'JetBrains Mono, monospace' }}>this month</text>
    </svg>);

};

const CompareRow = ({ label, value, max, color, bold }) =>
<div>
    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, marginBottom: 6 }}>
      <span style={{ fontWeight: bold ? 600 : 500, color: bold ? 'var(--text-primary)' : 'var(--text-secondary)' }}>{label}</span>
      <span style={{ fontWeight: 600, color: bold ? 'var(--text-primary)' : 'var(--text-secondary)', fontVariantNumeric: 'tabular-nums' }}>{value} kg</span>
    </div>
    <div style={{ height: 8, background: 'var(--surface-alt)', borderRadius: 4, overflow: 'hidden' }}>
      <div style={{ height: '100%', width: `${value / max * 100}%`, background: color, borderRadius: 4 }} />
    </div>
  </div>;


const CategoryBreakdown = ({ rows }) => {
  const totals = {};
  rows.forEach((r) => {
    [r.mine, r.theirs].forEach((item) => {
      const cat = CATEGORY[item.cat];
      const weight = item.weight ?? cat.typical_weight;
      totals[item.cat] = (totals[item.cat] || 0) + weight * cat.co2_per_kg;
    });
  });
  const entries = Object.entries(totals).sort((a, b) => b[1] - a[1]);
  const max = Math.max(...entries.map((e) => e[1]));
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
      {entries.map(([k, v]) =>
      <div key={k}>
          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
            <span style={{ color: 'var(--text-primary)', fontWeight: 500 }}>{CATEGORY[k].label}</span>
            <span style={{ color: 'var(--text-secondary)', fontVariantNumeric: 'tabular-nums' }}>{v.toFixed(1)} kg</span>
          </div>
          <div style={{ height: 6, background: 'var(--surface-alt)', borderRadius: 3 }}>
            <div style={{ height: '100%', width: `${v / max * 100}%`, background: 'var(--green-primary)', borderRadius: 3 }} />
          </div>
        </div>
      )}
    </div>);

};

Object.assign(window, { ImpactScreen, ImpactDashboard, ImpactTimeline, ImpactCompare });