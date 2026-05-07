# Gameplay UI Spec

## Canvas And Grid
- Canvas: 1920 x 1080.
- Base grid: 8 px.
- Allowed spacing: 8 / 16 / 24 / 32 / 48 px.
- Main overlay width: 1440 px. Standard left edge: x=240.
- No hand-drawn borders, bitmap textures, blur stacks, random scratches, or non-parametric decoration.

## Typography
- Page title: 40 px, bold.
- Section title: 28 px, bold.
- Body: 22 px.
- Assistive text: 18 px.
- Button label: 24 px, bold.
- Font target: Noto Sans SC or Microsoft YaHei. Godot fallback may use any CJK sans font with the same sizes.

## Color Tokens
| Token | Hex | Use |
| --- | --- | --- |
| background | #120b0d | Page background |
| panel | #241114 | Primary panel |
| panel_2 | #32171b | Raised panel |
| panel_3 | #171114 | Item/card inner panel |
| line | #d5a34a | Main gold border |
| line_dark | #7d4f24 | Secondary border |
| text | #f6e9cb | Main text |
| muted | #a99779 | Secondary text |
| teal | #1fb7a6 | Intel/status accent |
| bag | #b77725 | Bag/item accent |
| danger | #b5423c | Risk/destructive accent |
| gold | #e4b85b | Confirm/success accent |
| gray | #5c5960 | Disabled/secondary accent |

## Components
- Panel: clipped-corner polygon, 18-24 px cut, 3 px border, 10 x 12 px shadow.
- Card: clipped panel, 16 px cut, 20 px horizontal padding, title/body only.
- Item slot: 152 x 142 px, icon diamond centered at y=44, label at y=82.
- Button: clipped panel, 12 px cut. Standard sizes: 224 x 56, 264 x 56, compact 184 x 40.
- Footer: x=240 y=880 w=1440 h=104. Right-aligned secondary and primary actions.
- Modal: centered x=520 w=880. Standard action row y=512; selector modal y=650.

## Button States For Godot
- Normal: component base fill + accent border.
- Hover: increase border brightness by 20%, add 2 px top highlight.
- Pressed: move content down 2 px, darken fill by 15%.
- Disabled: use gray border, reduce text alpha to 55%, no hover highlight.

## Screen Element Counts
- Intel: 1 title, 6 question panels, 18 option cards, each option has image/title/supporters, 2 footer buttons.
- Bag: left requirements panel with 3 dominion + 2 ascension slots, right inventory panel with 8 item slots, 2 footer buttons.
- Rules: 3 horizontal strategy input boxes, 1 large free-text input area, 2 footer buttons.
- Status: left chapter/NPC panel, right player attribute panel with 8 icon rows, 2 footer buttons.
- History: 1 dialogue timeline, 1 event list, 2 footer buttons.
- Settings: 1 volume slider, 1 auto-confirm block with 4 independent checkboxes, 1 close button.
- NPC offer popup: 2 artifact trade cards, 2 requirement strips, 2 buttons.
- Confirm/submit popups: title, body, 2 buttons.
- Artifact select popup: title, body, 4 item slots, 2 buttons.
- Result banner: title, result text, 1 continue button.
