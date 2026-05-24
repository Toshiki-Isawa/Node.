// CollectionScreen.jsx — Node. home / plant collection

function CollectionScreen({ onPlantTap, onAddPlant }) {
  return (
    <div style={{ background: N.graphite, minHeight: '100%', color: N.bone, fontFamily: N.fontText }}>
      {/* Header */}
      <div style={{ padding: '62px 20px 18px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 22 }}>
          <Meta size={10}>2026.05.24 水 · 19:42</Meta>
          <div style={{ display: 'flex', gap: 16, color: N.fog }}>
            <Icon.Search width={20} height={20} />
            <div onClick={() => onAddPlant && onAddPlant()} style={{ cursor: 'pointer', color: N.bone }}>
              <Icon.Plus width={22} height={22} />
            </div>
            <Icon.Settings width={20} height={20} />
          </div>
        </div>
        <div style={{
          fontFamily: N.fontDisplay, fontSize: 40, fontWeight: 300,
          letterSpacing: '-0.025em', lineHeight: 1, color: N.bone,
        }}>Node<span style={{ color: N.moss }}>.</span></div>
        <div style={{ marginTop: 10, display: 'flex', gap: 8, alignItems: 'baseline' }}>
          <Meta>コレクション</Meta>
          <Meta color={N.fog}>· 植物 6 · 観測 346</Meta>
        </div>
      </div>

      {/* Filter chips */}
      <div style={{ padding: '0 20px 16px', display: 'flex', gap: 8, overflowX: 'auto' }}>
        {['すべて', 'アガベ', '塙根', 'ビカクシダ', 'アロイド'].map((t, i) => (
          <div key={t} style={{
            padding: '7px 12px', borderRadius: 999,
            background: i === 0 ? 'color-mix(in oklab, oklch(0.58 0.05 135) 14%, transparent)' : 'transparent',
            border: `1px solid ${i === 0 ? 'color-mix(in oklab, oklch(0.58 0.05 135) 40%, transparent)' : N.hairline}`,
            color: i === 0 ? N.mossSoft : N.fog,
            fontFamily: N.fontMono, fontSize: 10, letterSpacing: '0.06em', whiteSpace: 'nowrap',
          }}>{t}</div>
        ))}
      </div>

      {/* Grid */}
      <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10, paddingBottom: 120 }}>
        {PLANTS.map((p) => (
          <div key={p.id} onClick={() => onPlantTap && onPlantTap(p.id)}
            style={{ cursor: 'pointer', display: 'flex', flexDirection: 'column', gap: 8 }}>
            <NodePhoto seed={p.seed} style={{
              aspectRatio: '4/5', borderRadius: 10, boxShadow: '0 12px 32px -12px rgba(0,0,0,0.6)',
            }}>
              <div style={{ position: 'absolute', top: 10, right: 10,
                background: 'color-mix(in oklab, oklch(0.12 0.005 130) 65%, transparent)',
                backdropFilter: 'blur(10px)', WebkitBackdropFilter: 'blur(10px)',
                borderRadius: 999, padding: '4px 8px', display: 'flex', alignItems: 'center', gap: 5,
              }}>
                <SyncDot state={p.state} size={5}/>
                <Meta size={9} color={N.bone}>{
                  p.state === 'synced' ? `${p.obs}` :
                  p.state === 'local_only' ? 'ローカル' :
                  p.state === 'syncing' ? '同期中' : '失敗'
                }</Meta>
              </div>
              <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0,
                height: '50%', background: 'linear-gradient(to top, oklch(0.10 0.005 130 / 0.7), transparent)',
              }}/>
              <div style={{ position: 'absolute', left: 12, bottom: 10 }}>
                <Meta size={9} color={N.fog}>{p.days}日目</Meta>
              </div>
            </NodePhoto>
            <div style={{ paddingLeft: 2 }}>
              <div style={{ fontFamily: N.fontText, fontSize: 13, fontWeight: 500, color: N.bone, letterSpacing: '-0.005em' }}>{p.ja || p.name}</div>
              <div style={{ fontFamily: N.fontText, fontSize: 12, color: N.fog, fontStyle: 'italic', marginTop: 1 }}>{p.name} {p.clone}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Floating tab bar */}
      <NodeTabBar active="collection" />
    </div>
  );
}

function NodeTabBar({ active = 'collection', onShoot }) {
  const items = [
    { id: 'collection', icon: Icon.Grid,    label: 'コレクション' },
    { id: 'timeline',   icon: Icon.Clock,   label: 'タイムライン'   },
    { id: 'shoot',      icon: Icon.Camera,  label: '観測', primary: true },
    { id: 'compare',    icon: Icon.Compare, label: '比較'    },
  ];
  return (
    <div style={{
      position: 'absolute', left: 16, right: 16, bottom: 30,
      background: 'color-mix(in oklab, oklch(0.12 0.005 130) 65%, transparent)',
      backdropFilter: 'blur(24px) saturate(160%)',
      WebkitBackdropFilter: 'blur(24px) saturate(160%)',
      border: `1px solid ${N.hairline}`,
      borderRadius: 999, padding: 6, display: 'flex', gap: 4,
      boxShadow: '0 20px 50px -20px rgba(0,0,0,0.7), inset 0 1px 0 rgba(255,255,255,0.05)',
    }}>
      {items.map(it => {
        const isActive = it.id === active;
        const isPrimary = it.primary;
        return (
          <div key={it.id} onClick={() => isPrimary && onShoot && onShoot()} style={{
            flex: 1, padding: '10px 6px', borderRadius: 999,
            background: isPrimary ? N.moss : isActive ? N.bark : 'transparent',
            color: isPrimary ? N.graphite : isActive ? N.bone : N.fog,
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, cursor: 'pointer',
          }}>
            <it.icon width={isPrimary ? 22 : 18} height={isPrimary ? 22 : 18}/>
            <span style={{ fontFamily: N.fontText, fontSize: 10, fontWeight: isPrimary ? 600 : 400 }}>{it.label}</span>
          </div>
        );
      })}
    </div>
  );
}

Object.assign(window, { CollectionScreen, NodeTabBar });
