# LiarsLand UI 设计规范

## 大型全屏页面标题区标准

大型全屏页面标题区以 `project/scenes/ui/inventory_overlay.tscn` 为唯一实现标准，设计基准为 1280x720。

- 标题背景板节点使用 `TitleBanner`，图片使用 `res://assets/ui/common/title_banner_red.png`，`layout_mode = 0`，`offset_left = -23.0`，`offset_top = 17.333`，`offset_right = 396.667`，`offset_bottom = 107.333`，`expand_mode = 1`。不得使用额外 `scale`、`rotation` 或锚点缩放模拟该位置。
- 标题文字节点使用 `TitleLabel`，`layout_mode = 0`，`offset_left = 36.0`，`offset_top = 26.0`，`offset_right = 236.0`，`offset_bottom = 80.666`，`font_size = 35`，`font_color = Color(0.964706, 0.913725, 0.796078, 1)`，`font_outline_color = Color(0.02, 0.01, 0.01, 0.95)`，`outline_size = 3`，默认左对齐，垂直居中。
- 带关闭入口的大型全屏页面必须使用 `CloseButton`，图片使用 `bag_close_normal.png`、`bag_close_hover.png`、`bag_close_pressed.png`，`layout_mode = 0`，`offset_left = 1192.0`，`offset_top = 28.0`，`offset_right = 1249.333`，`offset_bottom = 85.333`，`ignore_texture_size = true`，`stretch_mode = 0`。
- 所有大型全屏页面的 TSCN 必须直接显示该页面的实际标题文字和实际标题位置，方便在 Godot 编辑器中二次编辑；运行时只能替换动态文案，不得让 TSCN 留空或使用占位标题。
- 运行时脚本不得覆盖 TSCN 中已配置的标题区尺寸、位置、拉伸方式和按钮位置；只允许按页面状态动态替换标题文本内容。

本文档是后续 UI 设计的核心规范。当前版本仅以 `ui/final_references/` 下的最终效果图作为视觉依据，暂时不参考 `project/` 下的实现文件或资源状态。

## 1. 唯一视觉参考

以后设计 UI 时，只参考以下最终效果图：

- `ui/final_references/dialogue_scene_final_effect_v2_flat_clash.png`
- `ui/final_references/round_start_opponent_select_final_effect_v4_card.png`
- `ui/final_references/shop_page_final_effect_v5_card_unified.png`
- `ui/final_references/ascension_dominion_final_effect_v5_card_unified.png`

如果其他目录中的资源或实现与这些参考图冲突，以 `ui/final_references/` 为准。

## 2. 核心风格

- 整体气质：暗色奇幻、月市交易、伪装、契约、危险感。
- 主视觉：深色背景、强对比角色与卡牌、金色描边、厚重面板、斜切边缘。
- 形状语言：优先使用斜切、多边形切角、硬边框；避免现代圆角卡片和轻薄扁平风。
- 材质语言：允许磨损、噪声、刮痕、暗纹理，保持黑市告示牌和契约卡牌的质感。

## 2.1 通用标题栏和背景框基准色

通用标题栏、通用背景框使用同一套黑色手绘高边资产语言：边界为厚薄不均的黑色墨线，中心色块保持简单、低纹理，便于九宫格拉伸。标题栏允许轻微斜切端角或外轮廓起伏，但不得使用复杂尖刺、重浮雕或强金属立体感。

通用基准色如下：

| Token | Hex | 用途 |
| --- | --- | --- |
| `common_frame_gold` | `#D99018` | 默认确认、主流程、正向提示标题与面板 |
| `common_frame_dark_teal` | `#0E6A66` | 情报、状态、规则、冷静信息标题与面板 |
| `common_frame_dark_red` | `#7A2E35` | 风险、代价、警告、敌对行动标题与面板 |
| `common_frame_dark_purple` | `#4A315F` | 背包、遗物、神秘内容、次级深色标题与面板 |

以上颜色用于资产中心填充色。外轮廓统一使用近黑墨线，推荐范围 `#050403` 到 `#11100D`，不得改成彩色描边。九宫格切割时应保留完整手绘边缘和角部变化，中心区域必须尽量干净，避免图案、文字或强渐变。

通用标题栏和背景框必须使用标准九宫格组件，不得在业务界面中手写 patch margin：

- 编辑器挂载：实例化 `res://scenes/ui/common_title_bar.tscn` 或 `res://scenes/ui/common_background_panel.tscn`，在 Inspector 中设置 `frame_color`。
- 代码创建：使用 `CommonFrame.make_title_bar(color)` 或 `CommonFrame.make_background_panel(color)`。
- 已有节点套用：对 `NinePatchRect` 调用 `CommonFrame.apply_title_bar(node, color)` 或 `CommonFrame.apply_background_panel(node, color)`。
- 支持颜色：`CommonFrame.GOLD`、`CommonFrame.DARK_TEAL`、`CommonFrame.DARK_RED`、`CommonFrame.DARK_PURPLE`。

## 3. 按钮三态规范

所有按钮都必须设计三种状态：普通状态、高亮状态、点击状态。这是强制 UI 规范。

- 普通状态：默认可点击状态，亮度克制，边框清晰。
- 高亮状态：悬停或选中预备状态，提升亮度、边框、高光或局部饱和度。
- 点击状态：按下反馈，整体更沉、更暗或有下陷感，必须明显区别于普通和高亮状态。

适用范围包括文字按钮、图标按钮、卡牌选择按钮、商店购买按钮、确认/继续按钮、属性加减按钮等所有可点击 UI。

如果最终参考图中某类按钮只展示了静态外观，则该外观视为普通状态；后续补充高亮和点击状态时，必须延续同一材质、轮廓、色相和层级。

建议命名：

- `<button_name>_normal`
- `<button_name>_hover`
- `<button_name>_pressed`

## 4. 核心检查清单

新增或修改 UI 前，必须确认：

- 是否只对齐 `ui/final_references/` 的最终视觉方向。
- 是否保持暗色奇幻、月市、契约感。
- 是否使用深色底、金色描边、厚重面板和斜切边缘。
- 红、青绿、紫、金黄的功能分区是否清晰。
- 所有按钮是否具备普通、高亮、点击三态。
- 文字、图标、数值和按钮是否清晰可读、易于扫视。
- 关键行动按钮是否足够醒目。

## 5. 通用页面组件规格

如无特殊说明，普通图素使用直接拉伸；标准文字按钮必须使用九宫格拉伸，不得直接缩放整张按钮图。

如无特殊说明，大部分页面应采用以下规格：

1. 标题位于左上角。所有标题采用统一背景板，拉伸背景板覆盖全部标题文字，背景板使用 `title_banner_red.png`。
2. 右上角为 X 返回按钮。图素使用 `bag_close_*.png`，必须包含普通、高亮、点击三态。
3. 主要按钮使用 `button_primary_gold_normal.png`、`button_primary_gold_hover.png`、`button_primary_gold_pressed.png`，必须通过标准按钮组件做九宫格拉伸，黑色文字居中。用于确认、提交、购买、继续、选择、保存等关键动作。
4. 次要按钮使用 `button_secondary_blank_normal.png`、`button_secondary_blank_hover.png`、`button_secondary_blank_pressed.png`，必须通过标准按钮组件做九宫格拉伸，白色文字居中。用于取消、返回、重置、辅助编辑等非关键动作。
5. 标准文字按钮统一使用 `project/scripts/ui/standard_button.gd` 或同等的 `StandardButton.apply()` 样式入口。业务界面不得用 `TextureRect + Label` 手写模拟标准文字按钮三态，也不得继续混用 `button_primary_blank.png`、`button_secondary_blank.png` 这类无三态旧资源。
6. 以下按钮属于特例，不套用标准横向文字按钮：右上角 `bag_close_*` 关闭按钮、左右侧图标工具按钮、整张卡牌/情报选项按钮、透明热点按钮、首屏专属开始按钮。

## 6. TSCN 场景化规范

每个大的界面都必须制作成一个独立的 TSCN 场景，允许用户在 Godot 编辑器中直接修改该界面内图素、控件的大小、位置等信息。

生成的 TSCN 中的所有元素，都必须可以通过 Godot 编辑器修改大小、位置、锚点、图片等配置；运行时必须读取并使用这些场景数据，不允许在脚本中用硬编码覆盖编辑器配置。

UI 的位置、大小、对齐方式、锚点、拉伸方式、图片资源和基础可见状态等信息，应尽量全部写入 TSCN 文件；脚本只负责数据填充、状态切换、事件响应和必要的动态内容替换，避免在代码中硬编码布局数值或图片路径，方便后续直接在 Godot 编辑器中调整。

当一个界面被制作成 TSCN 场景时，必须保证该界面内的元素和实际游戏运行中的元素保持一致，确保所见即所得。每个元素都应在场景中配置游戏运行时可能出现的图片、背景板和必要状态资源，避免只在脚本运行时临时补齐视觉资源。

默认情况下，所有图片的 `stretch_mode` 都必须设为 `scale`，不要使用 `tile`。

所有图片背景板的 `stretch_mode` 都必须设为 `scale`。

## 7. 禁止事项

- 不以 `project/` 下的当前实现作为本规范依据。
- 不使用浅色办公风、玻璃拟态、现代圆角卡片或轻薄扁平风作为主视觉。
- 不允许按钮只有单一静态状态。
- 不随意混用红、青绿、紫等功能色。
- 不让复杂背景压过文字、按钮和卡牌主体。
