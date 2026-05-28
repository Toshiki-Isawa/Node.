// AddPlantScreen.jsx — New plant registration. First observation = Day 0.

function AddPlantScreen({ onBack, onSave }) {
  const cats = ['アガベ', '塊根', 'ビカクシダ', 'アロイド', 'ユーフォルビア', 'その他'];
  return (
    <div style={{ background: N.graphite, minHeight: '100%', color: N.bone, fontFamily: N.fontText, position: 'relative' }}>
      {/* Top bar */}
      <div style={{
        padding: '62px 16px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        position: 'sticky', top: 0, zIndex: 5, background: `linear-gradient(to bottom, ${N.graphite} 70%, transparent)`,
      }}>
        <div onClick={onBack} style={{
          padding: '8px 4px', color: N.fog, fontFamily: N.fontText, fontSize: 15, cursor: 'pointer',
          display: 'flex', alignItems: 'center', gap: 4,
        }}>
          <Icon.Close width={18} height={18}/>
        </div>
        <div style={{ fontFamily: N.fontText, fontSize: 15, fontWeight: 500 }}>コレクションに追加</div>
        <div onClick={onSave} style={{
          padding: '8px 4px', color: N.fossil, fontFamily: N.fontText, fontSize: 15, fontWeight: 500, cursor: 'pointer',
        }}>保存</div>
      </div>

      {/* Hero — first observation slot */}
      <div style={{ padding: '6px 16px 22px' }}>
        <div style={{
          aspectRatio: '4/5', borderRadius: 14, border: `1px dashed ${N.stone}`,
          background: N.charcoal, position: 'relative', overflow: 'hidden',
          display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 14, cursor: 'pointer',
        }}>
          {/* faint hatch pattern */}
          <div style={{ position: 'absolute', inset: 0, opacity: 0.04,
            backgroundImage: 'repeating-linear-gradient(45deg, transparent 0 6px, currentColor 6px 7px)',
            color: N.bone,
          }}/>
          <div style={{
            width: 56, height: 56, borderRadius: 999, background: N.bark, border: `1px solid ${N.hairline}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: N.bone,
          }}>
            <Icon.Camera width={24} height={24}/>
          </div>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontFamily: N.fontText, fontSize: 14, color: N.bone, fontWeight: 500 }}>最初の観測</div>
            <Meta size={9} color={N.fog} style={{ marginTop: 6, display: 'block' }}>タップして撮影 · 任意</Meta>
          </div>
        </div>
      </div>

      {/* Form */}
      <div style={{ padding: '0 16px 140px', display: 'flex', flexDirection: 'column', gap: 14 }}>

        {/* Plant name (required) */}
        <Field label="植物名" required>
          <input autoFocus placeholder="例: アガベ チタノタ"
            style={inputStyle}/>
        </Field>

        {/* Scientific name */}
        <Field label="学名 · クローン" hint="任意">
          <input placeholder="例: Agave titanota 'FO-076'"
            style={{ ...inputStyle, fontStyle: 'italic' }}/>
        </Field>

        {/* Category chips */}
        <Field label="分類" hint="任意">
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 4 }}>
            {cats.map((c, i) => (
              <div key={c} style={{
                padding: '8px 12px', borderRadius: 999,
                background: i === 0 ? 'color-mix(in oklab, oklch(0.58 0.05 135) 14%, transparent)' : 'transparent',
                border: `1px solid ${i === 0 ? 'color-mix(in oklab, oklch(0.58 0.05 135) 40%, transparent)' : N.hairline}`,
                color: i === 0 ? N.mossSoft : N.paper,
                fontFamily: N.fontText, fontSize: 12, cursor: 'pointer',
              }}>{c}</div>
            ))}
          </div>
        </Field>

        {/* Acquired date */}
        <Field label="入手日" hint="任意">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', paddingTop: 2 }}>
            <input value="2026.05.24" readOnly style={{ ...inputStyle, flex: 'none', width: 'auto' }}/>
            <Meta size={9} color={N.moss}>今日</Meta>
          </div>
        </Field>

        {/* Source / origin */}
        <Field label="入手元" hint="任意">
          <input placeholder="例: 鶴仙園 / 個人売買 / 実生"
            style={inputStyle}/>
        </Field>

        {/* Note */}
        <Field label="メモ" hint="任意">
          <textarea rows={3} placeholder="—"
            style={{ ...inputStyle, resize: 'none', lineHeight: 1.45 }}/>
        </Field>

        {/* Quiet hint */}
        <div style={{ marginTop: 4, padding: '12px 14px', borderRadius: 12, background: 'transparent', border: `1px solid ${N.hairline}` }}>
          <Meta size={9} color={N.fog}>登録後のメモ</Meta>
          <div style={{ marginTop: 4, fontFamily: N.fontText, fontSize: 12, color: N.fog, lineHeight: 1.5 }}>
            植物名以外は後から追加できます。最初の観測は今すぐ撮らなくても構いません。
          </div>
        </div>

        {/* Primary CTA */}
        <button onClick={onSave} style={{
          marginTop: 12, padding: 15, borderRadius: 999, border: 'none',
          background: N.moss, color: N.graphite,
          fontFamily: N.fontText, fontSize: 15, fontWeight: 600, cursor: 'pointer',
        }}>コレクションに追加</button>
      </div>
    </div>
  );
}

// — Field wrapper —
function Field({ label, hint, required, children }) {
  return (
    <div style={{
      background: N.charcoal, border: `1px solid ${N.hairline}`, borderRadius: 14,
      padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: 4,
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <Meta size={9}>{label}{required && <span style={{ color: N.moss, marginLeft: 4 }}>必須</span>}</Meta>
        {hint && <Meta size={9} color={N.fossil}>{hint}</Meta>}
      </div>
      {children}
    </div>
  );
}

const inputStyle = {
  width: '100%', background: 'transparent', border: 0, outline: 0,
  color: 'oklch(0.93 0.008 95)', fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Noto Sans JP", sans-serif',
  fontSize: 15, padding: 0, marginTop: 2,
};

Object.assign(window, { AddPlantScreen });
