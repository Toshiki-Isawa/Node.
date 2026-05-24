// CompareScreen.jsx — Day 1 → Day N before/after with scrubber

function CompareScreen({ plantId = 'agave', onBack }) {
  const plant = PLANTS.find(p => p.id === plantId) || PLANTS[0];
  return (
    <div style={{ background: N.void, minHeight: '100%', color: N.bone, fontFamily: N.fontText, position: 'relative' }}>
      {/* Header */}
      <div style={{ padding: '62px 16px 16px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div onClick={onBack} style={{
          width: 36, height: 36, borderRadius: 999, background: N.charcoal, border: `1px solid ${N.hairline}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone, cursor: 'pointer',
        }}><Icon.Chevron width={18} height={18} style={{ transform: 'rotate(180deg)' }}/></div>
        <div style={{ textAlign: 'center' }}>
          <Meta size={9}>{(plant.ja || plant.name).toUpperCase()}</Meta>
          <div style={{ fontFamily: N.fontText, fontSize: 14, fontWeight: 500, marginTop: 2 }}>比較</div>
        </div>
        <div style={{ width: 36, height: 36 }}/>
      </div>

      {/* Before / After stack */}
      <div style={{ padding: '0 16px' }}>
        <div style={{ borderRadius: 14, overflow: 'hidden', border: `1px solid ${N.hairline}` }}>
          <div style={{ position: 'relative' }}>
            <NodePhoto seed={plant.seed} style={{ aspectRatio: '4/3' }}/>
            <div style={{ position: 'absolute', top: 12, left: 12 }}>
              <span style={{ padding: '4px 9px', borderRadius: 999, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)',
                fontFamily: N.fontMono, fontSize: 9, letterSpacing: '0.08em', color: N.bone }}>BEFORE</span>
            </div>
            <div style={{ position: 'absolute', left: 14, bottom: 14 }}>
              <Meta size={9} color={N.fog}>1日目 · 2025.01.03</Meta>
              <div style={{ fontFamily: N.fontDisplay, fontSize: 22, fontWeight: 300, letterSpacing: '-0.01em', marginTop: 4 }}>入手日</div>
            </div>
          </div>
          <div style={{ height: 1, background: N.stone }}/>
          <div style={{ position: 'relative' }}>
            <NodePhoto seed={plant.seed + 7} style={{ aspectRatio: '4/3' }}/>
            <div style={{ position: 'absolute', top: 12, left: 12 }}>
              <span style={{ padding: '4px 9px', borderRadius: 999, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)',
                fontFamily: N.fontMono, fontSize: 9, letterSpacing: '0.08em', color: N.bone }}>AFTER</span>
            </div>
            <div style={{ position: 'absolute', left: 14, bottom: 14 }}>
              <Meta size={9} color={N.fog}>{plant.days}日目 · 2026.05.24</Meta>
              <div style={{ fontFamily: N.fontDisplay, fontSize: 22, fontWeight: 300, letterSpacing: '-0.01em', marginTop: 4 }}>今日</div>
            </div>
          </div>
        </div>

        {/* Interval card */}
        <div style={{ marginTop: 20, padding: 18, background: N.charcoal, border: `1px solid ${N.hairline}`, borderRadius: 14 }}>
          <Meta size={9}>期間</Meta>
          <div style={{ marginTop: 10, fontFamily: N.fontDisplay, fontSize: 28, fontWeight: 300, letterSpacing: '-0.02em', lineHeight: 1 }}>
            1日目 <span style={{ color: N.moss, fontWeight: 400 }}>→</span> {plant.days}日目
          </div>
          <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 12 }}>
            <div>
              <Meta size={9}>経過日数</Meta>
              <div style={{ marginTop: 4, fontFamily: N.fontDisplay, fontSize: 18, color: N.bone, fontWeight: 300 }}>411<span style={{ fontSize: 11, color: N.fog, marginLeft: 4 }}>日</span></div>
            </div>
            <div>
              <Meta size={9}>観測</Meta>
              <div style={{ marginTop: 4, fontFamily: N.fontDisplay, fontSize: 18, color: N.bone, fontWeight: 300 }}>{plant.obs}<span style={{ fontSize: 11, color: N.fog, marginLeft: 4 }}>回</span></div>
            </div>
            <div>
              <Meta size={9}>水やり</Meta>
              <div style={{ marginTop: 4, fontFamily: N.fontDisplay, fontSize: 18, color: N.bone, fontWeight: 300 }}>38<span style={{ fontSize: 11, color: N.fog, marginLeft: 4 }}>回</span></div>
            </div>
          </div>
        </div>

        {/* Scrubber */}
        <div style={{ marginTop: 20, padding: 18, background: N.charcoal, border: `1px solid ${N.hairline}`, borderRadius: 14 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Meta size={9}>スクラブ</Meta>
            <Meta size={9} color={N.fog}>{plant.obs}点</Meta>
          </div>
          <div style={{ marginTop: 16, height: 28, position: 'relative' }}>
            <div style={{ position: 'absolute', left: 0, right: 0, top: 13, height: 1, background: N.stone }}/>
            {Array.from({ length: 22 }, (_, i) => (
              <div key={i} style={{
                position: 'absolute', top: 8, left: `${(i / 21) * 100}%`,
                width: 1, height: 12, background: i === 0 || i === 21 ? N.bone : N.fossil,
              }}/>
            ))}
            <div style={{
              position: 'absolute', left: '0%', top: 8, width: 14, height: 14, borderRadius: 999,
              background: N.moss, border: `2px solid ${N.bone}`, transform: 'translateX(-7px)',
            }}/>
            <div style={{
              position: 'absolute', left: '100%', top: 8, width: 14, height: 14, borderRadius: 999,
              background: N.moss, border: `2px solid ${N.bone}`, transform: 'translateX(-7px)',
            }}/>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
            <Meta size={9} color={N.fog}>2025.01.03</Meta>
            <Meta size={9} color={N.fog}>2026.05.24</Meta>
          </div>
        </div>

        <button style={{
          width: '100%', marginTop: 20, padding: '14px', borderRadius: 999, border: 'none',
          background: N.moss, color: N.graphite, fontFamily: N.fontText, fontSize: 15, fontWeight: 600, cursor: 'pointer',
        }}>比較を書き出す</button>

        <div style={{ height: 40 }}/>
      </div>
    </div>
  );
}

Object.assign(window, { CompareScreen });
