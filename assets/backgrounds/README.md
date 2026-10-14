# Warehouse backdrop provenance

## Asset

- File: `auction_warehouse_original.png`
- Intended use: Full-screen 2D warehouse atmosphere behind the AuctionMaster interface.
- Generated on: 2026-10-14 (UTC).
- Origin: Original AI-generated image produced for this project with the built-in OpenAI image generation tool. This is not a copied third-party game asset and is not distributed under a claimed third-party asset license.
- External reference: A warehouse-auction game screenshot was viewed only to understand broad lighting and scene layout. No screenshot, third-party artwork, logo, interface, or inventory item was supplied as an image input to generation.
- Image format: PNG, RGB, 1586 × 992 pixels (approximately 16:10).
- Source pixels: Unmodified generation output, copied into this project.
- Contains no people, text, logo, interface panels, or item icons.

## Integration

Use `res://assets/backgrounds/auction_warehouse_original.png` as a full-screen TextureRect with aspect-cover scaling. The source nearly exactly fits a 1440 × 900 viewport. For 16:9, keep aspect-cover and crop a small amount from the top and bottom instead of stretching. Keep the right-hand low-contrast region beneath the 12 × 14 inventory grid.

The lightest area is left of center. A subtle full-image dark tint or existing atmospheric dim layer may be applied at runtime if required for text readability; avoid flattening the scene beneath opaque rectangular panels.

## Generation prompt

Use case: stylized-concept.
Asset type: original full-bleed 2D game environment background, landscape 16:10 at 2400 by 1500 pixels if possible.
Primary request: A quiet, shadowy, industrial warehouse interior for an inventory-search auction game. This is ONLY the environmental background plate, not a game interface and not a screenshot.
Scene: an old spacious utilitarian warehouse seen from eye level, slightly wide angle, strong architectural depth toward the distant center. Weathered concrete floor with extremely faint irregular reflections, simple steel roof trusses, a few soft overhead industrial lights and faint dusty cool daylight entering high windows. Recessed walls and subtle out-of-focus storage silhouettes confined near the far left and distant rear. No specific identifiable collectible, treasure, weapon, device, vehicle or sale item.
Style/medium: polished atmospheric hand-painted 2D game environment, restrained realism, painterly material detail, soft dark tonal masses, convincingly spacious but deliberately quiet.
Composition: foreground floor visible across lower half. Upper roof framing visible near the top. Central-left 55 percent is dim and visually calm so compact information text can sit directly over the image. The entire right 42 percent must be especially dark, low contrast, sparse and unobtrusive so a dense transparent inventory grid and tiny colorful item icons will remain readable over it. Do NOT draw a grid or graphic panel. No central hero object. Broad negative space with genuine subtle architectural texture, never a flat solid color. Lights strongest in the rear center-left and never bright in the right region. Leave the bottom center-left quiet for an overlaid bright bid button.
Lighting and palette: very dim charcoal gray, desaturated warm gray-brown, subtle smoky blue shadows, sparse muted warm overhead highlights, low contrast. Floor highlights soft and very subdued. Background contributes warehouse atmosphere without competing with interface elements.
Constraints: original composition; no letters, words, numbers, signs, logos, branding, watermark, people, characters, user interface, frame, panels, borders, cards, buttons, icons, inventory items, inventory grid or visible text. Full bleed 16:10 landscape. It should be a beautiful low-key atmospheric backdrop that is immediately usable underneath a game UI.
