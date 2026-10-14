# AuctionMaster — original collectible item art

## Authorship and license

All five SVG item illustrations in this directory were newly authored for AuctionMaster on 2026-10-14. They are original layered vector illustrations, not extracted from any game, asset store, screenshot, photograph, or third-party illustration. They contain no trademarks or logos. They are distributed under the root project's MIT license. The inspection-only contact sheet was generated from these same original assets. No external artwork attribution or paid license is required.

## Runtime assets

| Asset | SVG canvas | Inventory footprint | Material treatment |
| --- | --- | --- | --- |
| `radio.svg` | 300 × 240 | 2 × 2 | Olive field receiver; perforated grille, brass dial, telescoping antenna, leather handle |
| `clock.svg` | 240 × 340 | 2 × 3 | Bronze mantel clock; enamel face, beveled case, aged wood plinth, pendulum glass |
| `vase.svg` | 180 × 320 | 1 × 2 | Ivory porcelain; cobalt botanical glaze painting, gilt rim and foot, asymmetric reflections |
| `gem.svg` | 200 × 200 | 1 × 1 | Cut sapphire; explicit facets, directional reflections and edge sparkle |
| `gold.svg` | 320 × 150 | 2 × 1 | Stacked assay ingots; warm metal planes, embossed emblem, edge wear |

The art contains no baked names, prices, rarity colors, or UI. Transparent surrounding pixels permit neutral, hover, selected, and rarity backgrounds. Grounding shadows are small and neutral. Use proportional fit, never stretch. SVG paths, gradients, and opacity avoid font, filter, and linked-image dependencies. The contact sheet is a QA artifact, not a runtime texture atlas.

## Commercial UI direction

For a 1600 × 900 desktop composition:

- Overall canvas: deep blue-black `#101A22`, very restrained grain/lighting only. Large rounded cards should not form every region.
- Top bar: 44–48 px. Single logo/game identity at left; room, round and quiet utility controls at right. Avoid duplicating the room name in multiple large headings.
- Player strip: 56–64 px. Compact avatars, names and balance; active bidder indicated with a thin warm-metal rule, not a large floating status card.
- Core zone: large 800 × 480 warehouse grid, 10 × 6 cells at 80 px, sitting in a single structural frame. Cell stroke `#31434E`, fill `#182833`. A slightly stronger line at outer bounds preserves silhouette.
- Supporting left content: compact log or room intelligence, secondary emphasis. Limit decorative prose and labels; leave the warehouse visually dominant.
- Detail inspector: 280–320 px at right. Large item art, one Chinese name, one quality label, appraisal/specific traits beneath a fine divider. Empty state should be calm and genuinely brief.
- Bottom bidding bar: 80–88 px. Current price and your balance read in one glance; 3–4 preset bid increments and one gold confirmation button. Primary CTA `#C4A56A`, hover `#DDC188`, label `#1C211F`. No oversized full-height bid panel.
- Overlay corner radius: 3–6 px. Thin strokes, narrow tabs, compact chips; reserve glow for a decisive state transition.

### Hierarchy and states

Use the supplied Noto Sans CJK font. Chinese UI copy should use 14–16 px for secondary information, 18–20 px for item names/current bid, and 28–32 px only for the principal price. Support tabular numeric alignment where possible. Text: `#E6E6DC` primary, `#A6B4BA` secondary, `#6E838E` tertiary. Gold only signals premium/primary action. Quality accents should be small edge bars or tiny tags: common `#92A4AE`, uncommon `#77A69A`, rare `#6E9FC8`, epic `#A58FC1`, legendary `#CBA869`.

Grid hover: 1 px lighter border plus at most 8% fill lift. Selected: 2 px gold outline with corner notches. Unknown items: understated stamped silhouette and brief scan label. Reveal animation may fade art and resolve the label; avoid jitter, permanent particles or competing animated panels. UI labels and prices remain runtime text, not illustrations.

## Inspection

`contact_sheet.png` was rendered with Inkscape and checked visually using an image viewer. Each asset was checked for silhouette, unclipped edges, material readability and transparent surround. All five SVGs also passed a Godot 4.6.3 headless Image.load check with the expected canvas dimensions and fully transparent top-left pixels. In-game grid verification remains part of the implementation test.
