// PlantDetailScreen.jsx — Plant page with hero photo + observation timeline

function PlantDetailScreen({ plantId = 'agave', onBack, onCompare }) {
  const plant = PLANTS.find(p => p.id === plantId) || PLANTS[0];
  const obs = Array.from({ length: 9 }, (_, i) => ({
    seed: plant.seed * 10 + i,
    day: plant.days - i * 14,
    date: ['5月24日','5月10日','4月26日','4月12日','3月29日','3月15日','3月1日','2月15日','2月1日'][i],
    state: i === 0 ? 'syncing' : i < 7 ? 'synced' : 'local_only',
    note: i === 0 ? '新しい棘が3本展開。' : i === 2 ? '植え替え · 4インチ素焼鉢' : '',
  }));
  return (
    <div style={{ background: N.graphite, minHeight: '100%', color: N.bone, fontFamily: N.fontText, position: 'relative' }}>
      {/* Hero photo */}
      <NodePhoto seed={plant.seed} style={{ height: 380, position: 'relative' }}>
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, oklch(0.10 0.005 130 / 0.5) 0%, transparent 30%, oklch(0.10 0.005 130 / 0.9) 100%)' }}/>
        {/* Top bar */}
        <div style={{ position: 'absolute', top: 0, left: 0, right: 0, padding: '62px 16px 8px',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div onClick={onBack} style={{
            width: 36, height: 36, borderRadius: 999,
            background: 'color-mix(in oklab, oklch(0.12 0.005 130) 50%, transparent)',
            backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone, cursor: 'pointer',
          }}>
            <Icon.Chevron width={18} height={18} style={{ transform: 'rotate(180deg)' }}/>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <div style={{ width: 36, height: 36, borderRadius: 999,
              background: 'color-mix(in oklab, oklch(0.12 0.005 130) 50%, transparent)',
              backdropFilter: 'blur(12px)', WebkitBackdropFilter: 'blur(12px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone,
            }}>
              <Icon.Sync width={16} height={16}/>
            </div>
          </div>
        </div>
        {/* Title block */}
        <div style={{ position: 'absolute', left: 20, right: 20, bottom: 20 }}>
          <Meta>{plant.days}日目 · 観測 {plant.obs}回</Meta>
          <div style={{ marginTop: 8, fontFamily: N.fontDisplay, fontSize: 32, fontWeight: 300, letterSpacing: '-0.02em', lineHeight: 1.05 }}>
            {plant.ja || plant.name}
          </div>
          <div style={{ marginTop: 2, fontFamily: N.fontDisplay, fontSize: 15, fontStyle: 'italic', color: N.fog }}>
            {plant.name} {plant.clone}
          </div>
        </div>
      </NodePhoto>

      {/* Action row */}
      <div style={{ padding: '16px 16px 8px', display: 'flex', gap: 8 }}>
        <button onClick={onCompare} style={{
          flex: 1, padding: '11px 12px', borderRadius: 999, border: 'none',
          background: N.moss, color: N.graphite, fontFamily: N.fontText, fontSize: 14, fontWeight: 600,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, cursor: 'pointer',
        }}><Icon.Compare width={16} height={16}/> 比較する</button>
        <button style={{
          flex: 1, padding: '11px 12px', borderRadius: 999,
          background: 'transparent', color: N.bone, border: `1px solid ${N.hairlineStrong}`,
          fontFamily: N.fontText, fontSize: 14, fontWeight: 500,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, cursor: 'pointer',
        }}><Icon.Note width={16} height={16}/> クイックログ</button>
      </div>

      {/* Observation timeline */}
      <div style={{ padding: '16px 16px 130px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
          <Meta>観測 · {plant.obs}回</Meta>
          <Meta color={N.fog}>新しい順</Meta>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          {obs.map((o, i) => (
            <div key={i} style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
              {/* timeline rail */}
              <div style={{ width: 36, display: 'flex', flexDirection: 'column', alignItems: 'center', paddingTop: 6 }}>
                <SyncDot state={o.state} size={6}/>
                {i < obs.length - 1 && <div style={{ width: 1, flex: 1, background: N.hairline, marginTop: 4, minHeight: 60 }}/>}
              </div>
              {/* card */}
              <div style={{ flex: 1, display: 'flex', gap: 12 }}>
                <NodePhoto seed={o.seed} style={{ width: 72, height: 96, borderRadius: 8, flex: 'none' }}/>
                <div style={{ flex: 1, minWidth: 0, paddingTop: 4 }}>
                  <Meta size={9}>{o.day}日目 · {o.date}</Meta>
                  <div style={{ marginTop: 6, fontFamily: N.fontText, fontSize: 14, color: N.bone, lineHeight: 1.4 }}>
                    {o.note || (i === 0 ? '今日の観測。' : '—')}
                  </div>
                  {i === 0 && (
                    <Meta size={9} color={N.olive} style={{ marginTop: 8 }}>· ローカル · 同期中</Meta>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <NodeTabBar active="collection" />
    </div>
  );
}

Object.assign(window, { PlantDetailScreen });
