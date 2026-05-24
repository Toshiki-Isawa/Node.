---
name: node-design
description: Use this skill to generate well-branded interfaces and assets for Node., a quiet, photo-first plant-observation iOS app. Contains essential design guidelines, dark color tokens, type (SF Pro stack), iconography, voice rules, and a SwiftUI-aligned UI kit for prototyping.
user-invocable: true
---

Read the `README.md` file at the root of this skill first, then explore the other files. The most important rules to internalize:

1. **The thesis is "observation, not management."** Every UI decision should make the user's photograph the protagonist. Chrome recedes, type stays quiet, colors stay botanical (one green axis: Moss, Olive, Sage), and motion never bounces.
2. **Dark-first.** App background is flat `--c-graphite`. No gradients on surfaces. The only "texture" is the user's photographs.
3. **Bilingual JP / EN.** Japanese is primary; English is reserved for short verbs and taxonomic terms. Never reach for emoji.
4. **Use the tokens.** `colors_and_type.css` defines all variables — colors (`--c-bone`, `--c-moss`, etc.), type (`--font-display`, `--t-display`), spacing (`--sp-4`), radius (`--r-md`), shadow (`--shadow-photo`), and motion (`--ease-quiet`, `--dur-base`). Import the file rather than hardcoding values.
5. **Voice.** Quiet, declarative, archival. `Observed · 19:42` not `Yay, photo saved!`. See `preview/brand-voice.html` for the do/don't matrix.

If creating visual artifacts (slides, mocks, throwaway prototypes), copy the assets you need into the new artifact and build static HTML files referencing `colors_and_type.css`. Reach for the React components in `ui_kits/node-ios/` when building interactive prototypes.

If working on production SwiftUI code, use this skill as a token reference: translate the oklch values into SwiftUI `Color` literals, and follow the README's iconography rules (Lucide-equivalent SF Symbols at 1.5 stroke equivalent, never filled).

If invoked without other guidance, ask the user what they want to build — likely a new screen for an existing flow, a marketing page, or a slide deck — and act as an expert in the Node. visual language, outputting HTML artifacts or SwiftUI snippets depending on the need.

## Files in this skill

- `README.md` — full system: brand, voice, visual foundations, iconography, components
- `colors_and_type.css` — design tokens, complete
- `preview/` — small reference cards (open in browser or pull as references)
- `ui_kits/node-ios/` — React + iOS frame kit; `index.html` is the live demo
