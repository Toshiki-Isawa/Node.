// CameraScreen.jsx — full-bleed dark camera with framing reticle and plant chip

function CameraScreen({ onClose, onShutter, plantId = 'agave' }) {
  const plant = PLANTS.find(p => p.id === plantId) || PLANTS[0];
  return (
    <div style={{ position: 'relative', height: '100%', background: '#000', color: N.bone, fontFamily: N.fontText, overflow: 'hidden' }}>
      {/* Viewfinder — a faint plant silhouette in the dark */}
      <NodePhoto seed={plant.seed + 50} style={{ position: 'absolute', inset: 0, filter: 'brightness(0.55) saturate(0.85)' }}/>

      {/* —— 定点補助 / Onion-skin: previous observation, low opacity, exactly aligned —— */}
      <div style={{ position: 'absolute', inset: '14% 10% 22% 10%', pointerEvents: 'none' }}>
        <NodePhoto seed={plant.seed} style={{ position: 'absolute', inset: 0, opacity: 0.28, mixBlendMode: 'screen' }}/>
        {/* edge-trace silhouette (a deterministic blob to fake "前回の輪郭") */}
        <svg viewBox="0 0 100 120" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
          <path d="M50 18 C 30 22, 22 40, 24 60 C 26 82, 38 100, 50 102 C 62 100, 74 82, 76 60 C 78 40, 70 22, 50 18 Z"
                fill="none" stroke={N.moss} strokeWidth="0.35" strokeDasharray="0.8 1.2" />
        </svg>
      </div>

      {/* —— グリッド: rule of thirds inside the reticle —— */}
      <div style={{ position: 'absolute', inset: '14% 10% 22% 10%', pointerEvents: 'none' }}>
        <div style={{ position: 'absolute', left: '33.33%', top: 0, bottom: 0, width: 1, background: 'rgba(255,255,255,0.22)' }}/>
        <div style={{ position: 'absolute', left: '66.66%', top: 0, bottom: 0, width: 1, background: 'rgba(255,255,255,0.22)' }}/>
        <div style={{ position: 'absolute', top: '33.33%', left: 0, right: 0, height: 1, background: 'rgba(255,255,255,0.22)' }}/>
        <div style={{ position: 'absolute', top: '66.66%', left: 0, right: 0, height: 1, background: 'rgba(255,255,255,0.22)' }}/>
      </div>

      {/* Framing reticle — corner brackets only, on top of grid */}
      <div style={{ position: 'absolute', inset: '14% 10% 22% 10%', pointerEvents: 'none' }}>
        {[[0,0],[1,0],[0,1],[1,1]].map(([x,y], i) => (
          <div key={i} style={{
            position: 'absolute', width: 22, height: 22,
            ...(x === 0 ? { left: 0, borderLeft: `1px solid ${N.bone}` } : { right: 0, borderRight: `1px solid ${N.bone}` }),
            ...(y === 0 ? { top: 0, borderTop: `1px solid ${N.bone}` } : { bottom: 0, borderBottom: `1px solid ${N.bone}` }),
            opacity: 0.85,
          }}/>
        ))}
        {/* center crosshair — fixed-point anchor */}
        <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)',
          width: 18, height: 18, pointerEvents: 'none' }}>
          <div style={{ position: 'absolute', left: '50%', top: 0, bottom: 0, width: 1, background: 'rgba(255,255,255,0.55)' }}/>
          <div style={{ position: 'absolute', top: '50%', left: 0, right: 0, height: 1, background: 'rgba(255,255,255,0.55)' }}/>
          <div style={{ position: 'absolute', left: '50%', top: '50%', transform: 'translate(-50%, -50%)',
            width: 5, height: 5, borderRadius: 999, border: `1px solid ${N.moss}` }}/>
        </div>
      </div>

      {/* —— 水平器 / Level indicator at top of viewfinder —— */}
      <div style={{ position: 'absolute', top: 'calc(14% - 28px)', left: 0, right: 0,
        display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 10, pointerEvents: 'none' }}>
        <div style={{ width: 90, height: 1, background: 'rgba(255,255,255,0.35)' }}/>
        <div style={{
          width: 30, height: 1, background: N.moss,
          transform: 'rotate(-2deg)', boxShadow: '0 0 4px rgba(126,146,112,0.6)',
        }}/>
        <div style={{ width: 90, height: 1, background: 'rgba(255,255,255,0.35)' }}/>
      </div>
      <div style={{ position: 'absolute', top: 'calc(14% - 44px)', left: 0, right: 0, display: 'flex', justifyContent: 'center', pointerEvents: 'none' }}>
        <Meta size={9} color={N.moss}>-2°</Meta>
      </div>

      {/* Top chrome */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, padding: '62px 16px 8px',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div onClick={onClose} style={{
          width: 36, height: 36, borderRadius: 999,
          background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(14px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone, cursor: 'pointer',
        }}>
          <Icon.Close width={18} height={18}/>
        </div>
        {/* Plant chip — context, always visible */}
        <div style={{
          padding: '8px 14px', borderRadius: 999,
          background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(14px)',
          display: 'flex', alignItems: 'center', gap: 8, color: N.bone,
        }}>
          <SyncDot state={plant.state} size={5}/>
          <div style={{ display: 'flex', flexDirection: 'column' }}>
            <span style={{ fontFamily: N.fontText, fontSize: 12, fontWeight: 500, lineHeight: 1.1 }}>{plant.ja || plant.name}</span>
            <Meta size={9} color={N.fog}>{plant.days}日目 · 観測 {plant.obs + 1}回目</Meta>
          </div>
        </div>
        <div style={{ width: 36, height: 36, borderRadius: 999,
          background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(14px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone,
        }}>
          <Icon.Flash width={16} height={16}/>
        </div>
      </div>

      {/* —— Right rail: 撮影補助トグル —— */}
      <div style={{
        position: 'absolute', right: 14, top: '50%', transform: 'translateY(-50%)',
        display: 'flex', flexDirection: 'column', gap: 8,
        padding: 6, borderRadius: 999,
        background: 'rgba(0,0,0,0.42)', backdropFilter: 'blur(14px)',
        border: `1px solid ${N.hairline}`,
      }}>
        {[
          { icon: Icon.GridLines, label: 'グリッド', active: true },
          { icon: Icon.Onion,     label: '前回',     active: true },
          { icon: Icon.Level,     label: '水平',     active: true },
        ].map((t, i) => (
          <div key={i} style={{
            position: 'relative',
            width: 36, height: 36, borderRadius: 999,
            background: t.active ? N.moss : 'transparent',
            color: t.active ? N.graphite : N.bone,
            display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
          }}>
            <t.icon width={16} height={16}/>
          </div>
        ))}
      </div>

      {/* Bottom HUD */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '24px 24px 40px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.7), transparent)' }}>
        {/* mode selector */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: 24, marginBottom: 22 }}>
          {['撮影', '比較', 'タイムラプス'].map((m, i) => (
            <span key={m} style={{
              fontFamily: N.fontMono, fontSize: 10, letterSpacing: '0.08em',
              color: i === 0 ? N.bone : 'rgba(236,233,223,0.4)',
            }}>{m}</span>
          ))}
        </div>
        {/* shutter row */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          {/* last shot thumbnail */}
          <NodePhoto seed={plant.seed * 10} style={{ width: 44, height: 44, borderRadius: 8, border: `1px solid ${N.hairline}` }}/>
          {/* shutter */}
          <div onClick={onShutter} style={{
            width: 76, height: 76, borderRadius: 999,
            border: `2px solid ${N.bone}`, padding: 4, display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
          }}>
            <div style={{ width: '100%', height: '100%', borderRadius: 999, background: N.bone }}/>
          </div>
          <div style={{ width: 44, height: 44, borderRadius: 999,
            background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(14px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone,
          }}>
            <Icon.Flip width={20} height={20}/>
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { CameraScreen });
