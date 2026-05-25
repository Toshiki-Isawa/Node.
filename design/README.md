# Node. Design System

> 植物の時間を残す — preserve plant time.

A design system for **Node.**, a "plant observation archive" iOS app for plant collectors (agave, platycerium, caudex, aroid). Built on a single thesis:

> **Node. is not a management app. It is an instrument for observing time.**

The system is photo-first, dark-first, and quiet. Every token is tuned so that the user's plant photograph is the protagonist — chrome recedes, type holds its breath, color stays botanical, never gardening-shop.

Source: `specification.md` (Node. 要件定義書 v2.8, 2026-05-25).
No prior codebase, brand assets, or screens were provided — this system was authored fresh from the requirements document. Where the spec specifies SF Pro, this system uses the Apple system font stack (which delivers SF Pro on Apple devices) with `Noto Sans JP` as a cross-platform fallback that handles the Japanese copy.

---

## Index

| File / folder | Contains |
|---|---|
| `colors_and_type.css` | All design tokens — colors, type, spacing, radius, shadow, motion |
| `preview/` | Static cards that populate the Design System tab |
| `ui_kits/node-ios/` | iOS app kit: components + `index.html` interactive demo |
| `SKILL.md` | Cross-compatible Agent Skill manifest |

---

## 1. Brand essence

**Name.** *Node.* The trailing period is part of the wordmark. It is the punctuation of an observation — a moment fixed in time, never to be edited.

**Dual meaning:**
- *Botanical:* a **node** is the point on a stem where growth occurs.
- *Technical:* a **node** is a point in a network of observations across time.

The two meanings collapse into the same idea: **observation = node**.

**Positioning.** Not a watering reminder. Not a plant-ID AI. Not a social feed. A quiet archive — closer to a Leica than to a houseplant app.

---

## 2. Content fundamentals

### Voice
- **Quiet, declarative, archival.** Short sentences. No exclamation points. No marketing hyperbole.
- **First person collector, not first person plant.** "Observed today" — never "Your plant is thirsty!"
- **Bilingual JP / EN.** Japanese is the primary language; English microcopy is acceptable as the secondary language for taxonomic terms and short verbs. Mix sparingly inside one block.

### Tone words
`still · observed · archived · interval · trace · grew · returned · unchanged`

### Tone to avoid
`care · happy · oops · friend · cute · let's · plant parent · 🌱`

### Copy patterns

| Surface | Example | Why |
|---|---|---|
| Empty state | `No observations yet.` | A fact, not a prompt. |
| Save confirm | `Observed · 19:42` | Two words and a timestamp. |
| Section label | `OBSERVATIONS · 142` | All-caps mono metadata. |
| Premium offer | `For longer archives.` | Value, not urgency. |
| Comparison cue | `Day 1 → Day 120` | The interval itself is the headline. |

### Casing & punctuation
- Section headings: **UPPERCASE** with `letter-spacing: 0.04em`, mono.
- Body and labels: **Sentence case** in Japanese order. Avoid Title Case.
- Periods inside the wordmark only. Inline UI copy avoids trailing periods on single phrases.
- Emoji: **never.** They break the archival register instantly.

---

## 3. Visual foundations

### 3.1 Color philosophy

A **single chromatic axis** — green — runs through the entire palette. Three accents (Moss, Olive, Sage) share `chroma ≈ 0.05` and differ only in hue and lightness, so they live together in the same family. Everything else is neutral on a green-tinted gray axis (`hue ≈ 120–130`). This produces a soft "behind glass" feel under photography — never neon, never institutional gray.

| Token | OKLCH | Use |
|---|---|---|
| `--c-void` | `0.12 0.005 130` | Behind photographs, modal scrim |
| `--c-graphite` | `0.17 0.005 130` | App background |
| `--c-charcoal` | `0.21 0.005 130` | Cards, list rows |
| `--c-bark` | `0.26 0.006 120` | Elevated surfaces, sheets |
| `--c-stone` | `0.34 0.006 120` | Hairline dividers |
| `--c-fossil` | `0.46 0.006 120` | Disabled glyphs |
| `--c-bone` | `0.93 0.008 95` | Primary text |
| `--c-paper` | `0.86 0.008 95` | Body text |
| `--c-fog` | `0.70 0.008 110` | Caption, secondary |
| `--c-mist` | `0.56 0.008 110` | Metadata, quiet labels |
| `--c-moss` | `0.58 0.05 135` | Primary accent — synced, primary CTA |
| `--c-moss-deep` | `0.42 0.05 135` | Pressed state |
| `--c-olive` | `0.62 0.05 105` | Secondary accent — Quick Log |
| `--c-sage` | `0.74 0.03 130` | Muted accent — borders, inactive |

Sync state colors (`local_only`, `syncing`, `synced`, `failed`) are derived from this same axis, with `failed` being the only token allowed to step off-axis into a warm rust hue.

### 3.2 Typography

- **Display / Title:** Apple system font (SF Pro Display) — `font-weight: 300–400`. Light weights only at large sizes; never bold display.
- **Body / Label:** Apple system font (SF Pro Text) — `font-weight: 400–500`.
- **Mono:** JetBrains Mono — used exclusively for metadata, timestamps, and section labels.
- **Japanese fallback:** Noto Sans JP, loaded from Google Fonts.
- **Letter-spacing:** display sizes use `-0.025em` (tighter, more confident); metadata uses `0.04em` uppercase (archival catalog feel).

### 3.3 Layout

- **Density:** generous. The default vertical rhythm between sections is `48px`. Cards have `24px` internal padding.
- **Grid:** flexible 4-px base. iOS layouts use `16px` screen gutter; comparison layouts split with a `1px` `--c-stone` hairline rather than a gap.
- **Photo-first:** every photograph is rendered full-bleed within its card. The only modification permitted is a 60% protection gradient at the bottom for legibility of overlay metadata — **never a rounded thumbnail with a colored ring.**

### 3.4 Backgrounds

- App background is **flat `--c-graphite`**. No gradients, no patterns, no textures.
- The single exception: photographs themselves. They are treated as the texture of the app.
- Splash / hero surfaces use `--c-void` so photographs feel like they're emerging from black.

### 3.5 Borders, shadows, elevation

- **Hairline-first.** Most separation comes from a 1px line at `rgba(bone, 0.08)`, never a heavy border.
- **Shadows are reserved for photographs.** UI cards generally use `--shadow-2` (subtle, plus an inset hairline). Photos use `--shadow-photo` — a long, soft, 60-px drop that lifts them off the surface like a museum print.
- **No glow effects, no inner highlights, no shine.**

### 3.6 Corner radii

- iOS-native scale: `2 / 6 / 10 / 14 / 20 / 28 / 999`.
- Photographs are radius `10`. Pills are `999`. Sheets are `28` (continuous corner feel).

### 3.7 Motion

- **All transitions fade, never slide unless changing screen.**
- Default easing: `cubic-bezier(0.32, 0.72, 0.24, 1)` — a quiet, slightly weighted curve.
- Entry: `cubic-bezier(0.16, 1, 0.3, 1)` (exponential ease-out, no overshoot).
- Default duration: `220ms`. Photo cross-fades: `480ms`. Bouncy springs are **prohibited**.
- The shutter has no animation — feedback is a 60ms flash of `--c-bone` at 6% opacity over the frame. No sound by default.

### 3.8 Hover / press

- Hover (iPad / web preview): drop opacity to `0.86`. No color shifts.
- Press: scale to `0.985`, opacity `0.7`, `120ms`. **Never** color the background of a tap target on press.

### 3.9 Transparency & blur

- Used **only** for floating chrome over photographs: bottom tab bar (`background-blur(24px)` + `color-mix(void, 70%)`), camera HUD, and modal scrims.
- Never used for cards in a list — those are opaque `--c-charcoal`.

### 3.10 Imagery

Photographs are assumed to be the user's own. The system never ships stock imagery. Wherever a photo would appear in a mockup, use a `--c-bark` placeholder with a thin `--c-stone` outline and a mono caption (`PLANT · 4032 × 3024`) — never a generated SVG of a plant.

---

## 4. Iconography

- **System:** [Lucide](https://lucide.dev) at 20px / 1.5 stroke for general UI, 24px / 1.5 for primary actions, 16px / 1.5 for inline metadata. Linked from CDN.
- **Stroke:** consistent 1.5 weight. **No filled icons.** Filled icons feel social-media; outline icons read as instrument.
- **Color:** glyphs inherit `currentColor`. Primary icons use `--c-bone`, secondary `--c-fog`, accent actions `--c-moss`.
- **Custom glyph:** the *Node mark* — a single `5px` circle that, in some layouts, can replace the trailing period in the wordmark. It is the only bespoke glyph in the system.
- **Emoji:** prohibited.
- **Unicode:** `·` (middle dot) is used liberally as a separator in metadata, e.g. `OBSERVATIONS · 142`.

> **Substitution note.** No icon font was provided in the source spec. Lucide is used as the closest match to a "thin, instrument-like" outline set. Please confirm or swap.

---

## 5. UI kits

| Kit | Path | Surfaces |
|---|---|---|
| **Node iOS** | `ui_kits/node-ios/` | Collection, Plant detail, Observation timeline, Camera, Comparison, Quick Log sheet（Timelapse は未収録） |

---

## 6. Things flagged for your review

- **Font.** Spec calls for SF Pro. This system uses the Apple system stack (which resolves to SF Pro on Apple devices) and Noto Sans JP as a cross-platform fallback. If you'd like web-deliverable SF Pro / a different Japanese face, swap in `colors_and_type.css`.
- **Iconography.** Lucide is used as a stand-in for "thin instrument" icons. Confirm or replace.
- **Olive / Moss / Sage hues.** All three sit on a narrow green axis. If you'd like more visible separation between them (e.g. a warmer olive), that's a one-line oklch change per token.
- **No real photographs** are bundled. Mockups use a generated placeholder pattern.

---

## 7. Iterating

**Help me make this perfect:**

1. **Confirm the green axis.** Open the Colors cards in the Design System tab — do Moss / Olive / Sage feel like the *Botanical Archive* you imagined? Tell me if any feel too gardening-shop or too institutional.
2. **Confirm the type weight.** The display uses `300` weight. Some find this too thin on retina; swap to `400` if so.
3. **Review iconography.** Is Lucide the right vibe, or would you prefer Phosphor (thin / regular), SF Symbols-style, or something custom?
4. **Anything missing.** Is there a screen / pattern (e.g. Timelapse player, Lineage tree) you want recreated in the UI kit before we move on?
