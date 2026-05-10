# Guidelines Page Asset Handoff

References:
- `ui/concepts/guidelines/guidelines_ui_design.png`
- `ui/concepts/guidelines/guidelines_final_reference.png`
- Style anchors: `ui/final_references/dialogue_scene_final_effect_v2_flat_clash.png`, `ui/final_references/shop_page_final_effect_v5_card_unified.png`, `ui/final_references/ascension_dominion_final_effect_v5_card_unified.png`

## Generation Rules

- Style: Hades-like flat cartoon game UI, dark fantasy moon-market contract archive, angular panels, thick gold edges, red/teal/purple/gold functional zones.
- Transparent PNG assets must have clean alpha: no colored fringe, no chroma residue, no dirty semi-opaque background, no baked shadows outside intended shape.
- Do not include text inside generated split assets unless explicitly listed; text is rendered in Godot.
- Avoid meaningless decorations. Every piece should support page hierarchy, tab state, panel framing, or countdown feedback.

## Split Asset List

| File name | Use | Recommended size | States | Transparency |
| --- | --- | --- | --- | --- |
| `guidelines_bg_contract_archive.png` | Full-screen backdrop behind the page | 1920x1080 | 1 | Opaque |
| `guidelines_main_panel.png` | Large central editor panel/frame | 1280x760 | 1 | Transparent outside frame |
| `guidelines_tab_identity.png` | Tab icon: public identity, mask + contract paper | 128x128 | 1 | Transparent |
| `guidelines_tab_behavior.png` | Tab icon: dialogue/action, speech seal + dagger | 128x128 | 1 | Transparent |
| `guidelines_tab_growth.png` | Tab icon: growth, star chart + coin/relic | 128x128 | 1 | Transparent |
| `guidelines_tab_plate_normal.png` | Tab background normal | 320x96 | normal | Transparent outside angular plate |
| `guidelines_tab_plate_hover.png` | Tab background hover | 320x96 | hover | Transparent outside angular plate |
| `guidelines_tab_plate_selected.png` | Tab background selected | 320x96 | selected | Transparent outside angular plate |
| `guidelines_editor_panel.png` | Direct-edit text area backing | 920x470 | 1 | Transparent outside frame |
| `guidelines_append_panel.png` | Append-rules input backing | 920x140 | 1 | Transparent outside frame |
| `guidelines_decision_modal.png` | 5-second decision confirmation modal | 820x360 | 1 | Transparent outside frame |
| `guidelines_countdown_track.png` | Countdown progress track | 620x34 | 1 | Transparent outside track |
| `guidelines_countdown_fill.png` | Countdown progress fill | 620x34 | 1 | Transparent outside fill |
| `guidelines_divider_gold.png` | Small angled separator | 760x18 | 1 | Transparent |
| `guidelines_status_chip.png` | Merge/save status hint backing | 360x56 | 1 | Transparent outside chip |

## Reused Existing Assets

- Title banner: `project/assets/ui/common/title_banner_red.png`
- Close button: `project/assets/ui/common/bag_close_normal.png`, `bag_close_hover.png`, `bag_close_pressed.png`
- Primary button: `project/assets/ui/common/button_primary_gold_normal.png`, `button_primary_gold_hover.png`, `button_primary_gold_pressed.png`
- Secondary button: `project/assets/ui/common/button_secondary_blank_normal.png`, `button_secondary_blank_hover.png`, `button_secondary_blank_pressed.png`
- Existing fallback panels may be used until split assets arrive: `panel_large_dark.png`, `panel_large_teal.png`, `label_teal.png`, `label_purple.png`, `label_red.png`, `meta_plate_dark_blank.png`

## Runtime Integration Notes

- Keep node names stable in `project/scenes/ui/guidelines_page.tscn`: `CloseButton`, `IdentityTab`, `BehaviorTab`, `GrowthTab`, `GuidelineEdit`, `AppendEdit`, `MergeButton`, `SaveButton`, `ResetButton`, `CloseTextButton`, `AutoActionCheck`, `AutoGrowthCheck`, `DecisionPanel`.
- The page must remain usable before final split assets arrive. Use existing common UI assets as fallbacks.
- Final split assets should be copied under `project/assets/ui/guidelines/` and loaded by `project/scripts/ui/guidelines_page.gd`.
