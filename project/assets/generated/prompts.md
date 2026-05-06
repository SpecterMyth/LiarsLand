# Image Generation Prompts

Global style:

High-contrast mythic underworld fantasy, bold ink-like silhouettes, dramatic rim light, jewel-toned shadows, warm crimson and molten gold accents, poisonous teal highlights, ornate spy-fantasy costumes, painterly 2D game illustration, no text, no watermark.

Palette:

- Main colors: deep purple-black, wine red, charred black, dark bronze.
- Accent colors: molten gold, crimson, peacock green, spectral blue.
- Every image should include warm/cool contrast and avoid becoming a single dark-blue or single-purple palette.

Character portrait prompt template:

Anthropomorphic animal spy-fantasy character, three-quarter body portrait, transparent PNG final use, sharp readable silhouette, ornate leather and silk costume, dramatic rim light, Hades-inspired high-contrast mythic color mood without copying any Hades character or UI, no text, no watermark.

Background prompt template:

Wide cinematic location background for a dialogue adventure game, lower area left readable for dialogue UI, mythic underworld spy city mood, warm crimson and molten gold light colliding with poisonous teal shadows, no text, no watermark.

Card UI generated asset rules:

- Output directory: `project/assets/generated/ui/card/`.
- Visual source: latest card-style round-start concept, using flat comic cards, heavy black shadows, saturated red/purple/teal/yellow blocks, square utility buttons, and no ornate European linework.
- V2 pass: `project/tools/generate_card_v2_ui_assets.py` derives the shared dark background and character portrait crops from `ui/final_references/round_start_opponent_select_final_effect_v4_card.png`, then procedurally generates transparent card frames, requirement panels, item cards, labels, stat rows, and button plates with matching noise/scratch texture.
- Character assets: fox player and wolf opponent are transparent card portraits with simplified flat shapes and high contrast.
- Artifact icons: 10 reusable transparent `256x256` PNGs, one per artifact id, drawn as simple saturated symbols rather than realistic rendered objects.
- Utility icons: six reusable transparent PNGs for info, bag, history, rules, status, settings, matching the right-side square button language.
- Background: shared dark abstract city `1920x1080` PNG for all three card pages.
