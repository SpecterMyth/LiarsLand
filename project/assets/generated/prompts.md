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

NPC expansion v1 placeholder asset note:

- Added 15 runtime placeholder NPC portraits, half portraits, head avatars, and round-select cards so `chapter_01.json` can load all 20 NPCs without missing art.
- Added 20 runtime scene backgrounds by copying the existing `arts/concepts/scenes/scene_*_concept_v1.png` files into `project/assets/generated/bg_*.png`.
- Final replacement prompts and acceptance rules live in `specification/npc_expansion_pipeline_spec.md`.
- Placeholder style intent: flat high-contrast animal silhouettes, thick black outlines, transparent portrait edges, no text, no UI.

NPC final runtime asset rebuild v1:

- `npc_moth_lamplighter` 月蛾点灯人: rebuilt from `actor_moth_lamplighter_concept_v1.png`
- `npc_rat_debt_runner` 碎齿债跑: rebuilt from `actor_rat_debt_runner_concept_v1.png`
- `npc_lynx_mask_tailor` 猞猁面具裁缝: rebuilt from `actor_lynx_mask_tailor_concept_v1.png`
- `npc_owl_court_astrologer` 夜枭宫廷星卜师: rebuilt from `actor_owl_court_astrologer_concept_v1.png`
- `npc_boar_gate_supplier` 铁鬃军需商: rebuilt from `actor_boar_gate_supplier_concept_v1.png`
- `npc_gecko_wall_listener` 壁纹听者: rebuilt from `actor_gecko_wall_listener_concept_v1.png`
- `npc_swan_embassy_duelist` 白羽礼剑士: rebuilt from `actor_swan_embassy_duelist_concept_v1.png`
- `npc_panther_silent_guard` 黑豹静卫: rebuilt from `actor_panther_silent_guard_concept_v1.png`
- `npc_frog_poison_taster` 金喉试毒师: rebuilt from `actor_frog_poison_taster_concept_v1.png`
- `npc_hare_false_messenger` 裂耳假信使: rebuilt from `actor_hare_false_messenger_concept_v1.png`
- `npc_bat_roof_informant` 夜翼檐探: rebuilt from `actor_bat_roof_informant_concept_v1.png`
- `npc_badger_oath_notary` 獾纹誓约公证人: rebuilt from `actor_badger_oath_notary_concept_v1.png`
- `npc_eel_drain_smuggler` 暗渠鳗走私客: rebuilt from `actor_eel_drain_smuggler_concept_v1.png`
- `npc_goat_bell_keeper` 角铃桥守: rebuilt from `actor_goat_bell_keeper_concept_v1.png`
- `npc_mantis_knife_judge` 螳臂刀审: rebuilt from `actor_mantis_knife_judge_concept_v1.png`


NPC final runtime asset rebuild v1:

- `npc_moth_lamplighter` 月蛾点灯人: rebuilt from `actor_moth_lamplighter_concept_v1.png`
- `npc_rat_debt_runner` 碎齿债跑: rebuilt from `actor_rat_debt_runner_concept_v1.png`
- `npc_lynx_mask_tailor` 猞猁面具裁缝: rebuilt from `actor_lynx_mask_tailor_concept_v1.png`
- `npc_owl_court_astrologer` 夜枭宫廷星卜师: rebuilt from `actor_owl_court_astrologer_concept_v1.png`
- `npc_boar_gate_supplier` 铁鬃军需商: rebuilt from `actor_boar_gate_supplier_concept_v1.png`
- `npc_gecko_wall_listener` 壁纹听者: rebuilt from `actor_gecko_wall_listener_concept_v1.png`
- `npc_swan_embassy_duelist` 白羽礼剑士: rebuilt from `actor_swan_embassy_duelist_concept_v1.png`
- `npc_panther_silent_guard` 黑豹静卫: rebuilt from `actor_panther_silent_guard_concept_v1.png`
- `npc_frog_poison_taster` 金喉试毒师: rebuilt from `actor_frog_poison_taster_concept_v1.png`
- `npc_hare_false_messenger` 裂耳假信使: rebuilt from `actor_hare_false_messenger_concept_v1.png`
- `npc_bat_roof_informant` 夜翼檐探: rebuilt from `actor_bat_roof_informant_concept_v1.png`
- `npc_badger_oath_notary` 獾纹誓约公证人: rebuilt from `actor_badger_oath_notary_concept_v1.png`
- `npc_eel_drain_smuggler` 暗渠鳗走私客: rebuilt from `actor_eel_drain_smuggler_concept_v1.png`
- `npc_goat_bell_keeper` 角铃桥守: rebuilt from `actor_goat_bell_keeper_concept_v1.png`
- `npc_mantis_knife_judge` 螳臂刀审: rebuilt from `actor_mantis_knife_judge_concept_v1.png`

NPC Imagegen final replacement pass v2 - 2026-05-09:

- Concept sheets regenerated through built-in Imagegen for `npc_eel_drain_smuggler`, `npc_goat_bell_keeper`, and `npc_mantis_knife_judge` after art-direction feedback. Final rule: 1536x1024 concept sheet, left half oversized bust, right half full body, pure solid background, huge hard-edged color blocks, thick black outline, extremely weak volume, 4 to 6 main color shapes, no tiny costume detail, no text or UI.
- Runtime portraits, head avatars, and round-select cards for the 15 expansion NPCs were generated one asset at a time through built-in Imagegen. Local post-processing was limited to chroma-key removal, alpha validation, half-portrait cropping, and file placement.
- Chroma key standards: use pure `#00ff00` outside non-green characters; use pure `#ff00ff` for green/teal-heavy NPCs such as gecko, frog, eel, and mantis. The subject/card must not use the key color.
- Select cards: vertical half-body card, transparent outside card after key removal, no generated names, labels, buttons, icons, numbers, or stat boxes inside the image.
- Verification artifacts: `tmp/final_head_avatars_contact.png`, `tmp/final_select_cards_contact.png`, `tmp/npc_dialogue_desktop_contact.png`, `tmp/npc_dialogue_mobile_contact.png`, `tmp/npc_selection_contact.png`, `tmp/npc_shop_contact.png`, and `tmp/world_intel_archive_godot_visual.png`.
