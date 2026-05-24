# Node iOS — UI kit

Interactive recreation of the Node. iOS observation flow.

## Surfaces

| Screen | File | Purpose |
|---|---|---|
| Collection | `CollectionScreen.jsx` | Plant grid, the home screen |
| Plant detail | `PlantDetailScreen.jsx` | Hero photo + observation timeline |
| Camera | `CameraScreen.jsx` | Full-bleed dark camera, plant chip context |
| Compare | `CompareScreen.jsx` | Before / After + interval card + scrubber |
| Quick Log | `QuickLogScreen.jsx` | Bottom sheet — water / repot / note |

## Atoms

`shared.jsx` exports `N` (token map), `NodePhoto`, `Meta`, `SyncDot`, `Icon`, and the `PLANTS` fixture used by every screen.

## Open

Open `index.html`. The first phone is live (tap a plant → detail → Observe / Compare). The remaining phones display static states for cross-screen review.

## Visual notes

- Every photo is a deterministic CSS gradient + SVG noise overlay — no stock imagery is bundled. Replace `NodePhoto` with a real `<img>` for production.
- The tab bar floats over content with a 24px backdrop blur (`color-mix(void, 65%)`).
- All sync state is communicated by a single 5–6 px colored dot — never a label or a banner.
