// shared.jsx — Node. design tokens + reusable atoms for the iOS kit

const N = {
  void:     'oklch(0.12 0.005 130)',
  graphite: 'oklch(0.17 0.005 130)',
  charcoal: 'oklch(0.21 0.005 130)',
  bark:     'oklch(0.26 0.006 120)',
  stone:    'oklch(0.34 0.006 120)',
  fossil:   'oklch(0.46 0.006 120)',
  bone:     'oklch(0.93 0.008 95)',
  paper:    'oklch(0.86 0.008 95)',
  fog:      'oklch(0.70 0.008 110)',
  mist:     'oklch(0.56 0.008 110)',
  moss:     'oklch(0.58 0.05 135)',
  mossDeep: 'oklch(0.42 0.05 135)',
  mossSoft: 'oklch(0.72 0.04 135)',
  olive:    'oklch(0.62 0.05 105)',
  sage:     'oklch(0.74 0.03 130)',
  fail:     'oklch(0.62 0.10 35)',
  hairline: 'rgba(236, 233, 223, 0.08)',
  hairlineStrong: 'rgba(236, 233, 223, 0.14)',
  fontDisplay: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Helvetica Neue", "Noto Sans JP", sans-serif',
  fontText: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", "Noto Sans JP", sans-serif',
  fontMono: '"JetBrains Mono", ui-monospace, "SF Mono", Menlo, monospace',
};

// Generated "photo" — a noise-flecked radial gradient. Deterministic from seed.
function NodePhoto({ seed = 1, style = {}, children }) {
  const hues = [130, 120, 110, 100, 90, 140, 150];
  const h1 = hues[seed % hues.length];
  const h2 = hues[(seed + 3) % hues.length];
  const cx = 20 + (seed * 37) % 60;
  const cy = 20 + (seed * 53) % 60;
  return (
    <div style={{ position: 'relative', overflow: 'hidden', background: N.void, ...style }}>
      <div style={{ position: 'absolute', inset: 0,
        background: `radial-gradient(110% 80% at ${cx}% ${cy}%, oklch(0.5 0.04 ${h1}) 0%, oklch(0.28 0.025 ${h2}) 35%, oklch(0.13 0.008 130) 80%)`,
      }}/>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.10, mixBlendMode: 'overlay',
        backgroundImage: `url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='240' height='240'><filter id='n'><feTurbulence baseFrequency='0.85' numOctaves='2' seed='${seed}'/></filter><rect width='240' height='240' filter='url(%23n)'/></svg>")`,
      }}/>
      {/* subtle vignette */}
      <div style={{ position: 'absolute', inset: 0, boxShadow: 'inset 0 0 80px rgba(0,0,0,0.45)' }}/>
      {children}
    </div>
  );
}

function Meta({ children, color = N.mist, size = 10, style = {} }) {
  return <span style={{
    fontFamily: N.fontMono, fontSize: size, letterSpacing: '0.06em',
    textTransform: 'uppercase', color, ...style,
  }}>{children}</span>;
}

function SyncDot({ state = 'synced', size = 6 }) {
  const colors = { synced: N.moss, local_only: N.olive, syncing: 'oklch(0.70 0.05 200)', failed: N.fail };
  const pulse = state === 'syncing' ? { animation: 'nodePulse 1.4s ease-in-out infinite' } : {};
  return <span style={{
    display: 'inline-block', width: size, height: size, borderRadius: 999,
    background: colors[state], flex: 'none', ...pulse,
  }}/>;
}

// Icon set — Lucide-style, 1.5 stroke, currentColor
const Icon = {
  Camera: (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M14.5 4h-5L8 6H4a1 1 0 00-1 1v11a1 1 0 001 1h16a1 1 0 001-1V7a1 1 0 00-1-1h-4L14.5 4z"/><circle cx="12" cy="13" r="4"/></svg>,
  Grid:   (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><rect x="3" y="3" width="8" height="8" rx="1"/><rect x="13" y="3" width="8" height="8" rx="1"/><rect x="3" y="13" width="8" height="8" rx="1"/><rect x="13" y="13" width="8" height="8" rx="1"/></svg>,
  Clock:  (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>,
  Compare:(p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><path d="M12 3v18"/><path d="M5 7l-2 2 2 2"/><path d="M19 13l2 2-2 2"/><rect x="3" y="9" width="6" height="6"/><rect x="15" y="9" width="6" height="6"/></svg>,
  Chevron:(p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><path d="M9 6l6 6-6 6"/></svg>,
  Plus:   (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><path d="M12 5v14M5 12h14"/></svg>,
  Drop:   (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M12 3s6 6.5 6 11a6 6 0 11-12 0c0-4.5 6-11 6-11z"/></svg>,
  Fertilize: (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M6 8h12l-1.5 11a2 2 0 01-2 1.7H9.5a2 2 0 01-2-1.7L6 8z"/><path d="M8 8V6a2 2 0 012-2h4a2 2 0 012 2v2"/><circle cx="10" cy="13" r="0.8" fill="currentColor"/><circle cx="14" cy="14.5" r="0.8" fill="currentColor"/><circle cx="11.5" cy="16.5" r="0.8" fill="currentColor"/></svg>,
  Tonic:  (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M10 3h4v3.5l3 5.5a4 4 0 01-4 6h-2a4 4 0 01-4-6l3-5.5V3z"/><path d="M9.5 13h5"/></svg>,
  Repot:  (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M5 11h14l-2 9H7L5 11z"/><path d="M3 11h18"/><path d="M12 11V6"/><path d="M9 6h6"/></svg>,
  Note:   (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M5 4h11l3 3v13H5z"/><path d="M9 10h6M9 14h6M9 18h3"/></svg>,
  Close:  (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><path d="M6 6l12 12M18 6L6 18"/></svg>,
  Sync:   (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M21 12a9 9 0 11-3.5-7.1"/><path d="M21 4v5h-5"/></svg>,
  Flip:   (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M7 4l-3 3 3 3"/><path d="M4 7h11a5 5 0 015 5"/><path d="M17 20l3-3-3-3"/><path d="M20 17H9a5 5 0 01-5-5"/></svg>,
  Flash:  (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><path d="M13 2L4 14h7l-1 8 9-12h-7l1-8z"/></svg>,
  Search: (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>,
  Settings:(p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3h.1a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8v.1a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></svg>,
  GridLines: (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><rect x="3" y="3" width="18" height="18" rx="1"/><path d="M3 9h18M3 15h18M9 3v18M15 3v18"/></svg>,
  Onion:     (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" {...p}><rect x="3" y="5" width="13" height="13" rx="1.5"/><rect x="8" y="10" width="13" height="13" rx="1.5"/></svg>,
  Level:     (p) => <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" {...p}><circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/></svg>,
};

// Plant fixtures — scientific names stay in Latin (taxonomic convention)
const PLANTS = [
  { id: 'agave',   name: "Agave titanota", clone: "'FO-076'",      ja: 'アガベ チタノタ',  seed: 1, obs: 142, days: 412, state: 'synced' },
  { id: 'pacy',    name: "Pachypodium",    clone: "gracilius",       ja: 'パキポディウム', seed: 2, obs: 31,  days: 95,  state: 'local_only' },
  { id: 'plat',    name: "Platycerium",    clone: "ridleyi",         ja: 'ビカクシダ',  seed: 3, obs: 86,  days: 240, state: 'synced' },
  { id: 'mons',    name: "Monstera",       clone: "obliqua Peru",    ja: 'モンステラ',   seed: 4, obs: 54,  days: 188, state: 'syncing' },
  { id: 'eucho',   name: "Euphorbia",      clone: "obesa",           ja: 'ユーフォルビア', seed: 5, obs: 22,  days: 60,  state: 'synced' },
  { id: 'aloe',    name: "Aloe",           clone: "polyphylla",      ja: 'アロエ',       seed: 6, obs: 11,  days: 18,  state: 'failed' },
];

Object.assign(window, { N, NodePhoto, Meta, SyncDot, Icon, PLANTS });
