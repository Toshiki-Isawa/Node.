// QuickLogScreen.jsx — bottom-sheet overlay for non-photo records

function QuickLogScreen({ plantId = 'agave', onClose }) {
  const plant = PLANTS.find(p => p.id === plantId) || PLANTS[0];
  return (
    <div style={{ position: 'relative', height: '100%', fontFamily: N.fontText, color: N.bone }}>
      {/* dim background showing plant detail */}
      <div style={{ position: 'absolute', inset: 0 }}>
        <NodePhoto seed={plant.seed} style={{ position: 'absolute', inset: 0, filter: 'brightness(0.5)' }}/>
        <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.4)' }}/>
      </div>

      {/* Sheet */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0,
        background: N.charcoal, borderTopLeftRadius: 28, borderTopRightRadius: 28,
        padding: '14px 20px 28px',
        boxShadow: '0 -30px 60px -20px rgba(0,0,0,0.7)',
        borderTop: `1px solid ${N.hairline}`,
      }}>
        {/* drag handle */}
        <div style={{ width: 36, height: 4, background: N.stone, borderRadius: 999, margin: '0 auto 18px' }}/>

        {/* header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
          <div>
            <Meta size={9}>{(plant.ja || plant.name).toUpperCase()}</Meta>
            <div style={{ marginTop: 4, fontFamily: N.fontDisplay, fontSize: 22, fontWeight: 300, letterSpacing: '-0.01em' }}>クイックログ</div>
          </div>
          <div onClick={onClose} style={{
            width: 32, height: 32, borderRadius: 999, background: N.bark,
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.fog, cursor: 'pointer',
          }}><Icon.Close width={16} height={16}/></div>
        </div>

        {/* Action cards — 2 rows: 栄養系 / イベント系 */}
        <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 8 }}>
          {[
            [
              { icon: Icon.Drop,      label: '水やり',   active: true },
              { icon: Icon.Fertilize, label: '施肥' },
              { icon: Icon.Tonic,     label: '活力剤' },
            ],
            [
              { icon: Icon.Repot,     label: '植え替え' },
              { icon: Icon.Note,      label: 'メモ' },
            ],
          ].map((row, ri) => (
            <div key={ri} style={{
              display: 'grid',
              gridTemplateColumns: `repeat(${row.length}, 1fr)`,
              gap: 8,
            }}>
              {row.map((a, i) => (
                <div key={i} style={{
                  padding: '16px 10px 14px',
                  background: a.active ? 'color-mix(in oklab, oklch(0.58 0.05 135) 12%, transparent)' : N.bark,
                  border: `1px solid ${a.active ? 'color-mix(in oklab, oklch(0.58 0.05 135) 35%, transparent)' : N.hairline}`,
                  borderRadius: 14,
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, cursor: 'pointer',
                }}>
                  <a.icon width={22} height={22} style={{ color: a.active ? N.mossSoft : N.bone }}/>
                  <div style={{ fontFamily: N.fontText, fontSize: 13, fontWeight: 500, textAlign: 'center', lineHeight: 1.15 }}>{a.label}</div>
                </div>
              ))}
            </div>
          ))}
        </div>

        {/* Note + record */}
        <div style={{ marginTop: 16 }}>
          <div style={{ padding: '12px 14px', background: N.bark, borderRadius: 14, border: `1px solid ${N.hairline}` }}>
            <Meta size={9}>メモ · 任意</Meta>
            <input placeholder="—" style={{
              width: '100%', background: 'transparent', border: 0, outline: 0,
              color: N.bone, fontFamily: N.fontText, fontSize: 15, marginTop: 4,
            }}/>
          </div>

          <button style={{
            width: '100%', marginTop: 16, padding: 14, borderRadius: 999, border: 'none',
            background: N.moss, color: N.graphite, fontFamily: N.fontText, fontSize: 15, fontWeight: 600, cursor: 'pointer',
          }}>19:42 で記録</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { QuickLogScreen });
