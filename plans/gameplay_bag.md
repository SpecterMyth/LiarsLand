# 游戏内背包界面重建计划

## Summary
用 `project/assets/ui/common/bag_*.png` 图素在 Godot 中重建全屏背包 overlay，视觉对齐 `ui/final_references/gameplay_inventory.png`。现有侧边抽屉里的 `bag` 模式不再作为背包主界面使用；点击右侧“背包”按钮时打开新的全屏背包界面，右上角 `X` 关闭，点击背景遮罩也可关闭。

## Key Changes
- 在 `AdventureLayout` 中新增背包 overlay 构建函数，返回 `inventory_overlay`、关闭按钮、需求格容器、背包网格、资源标签等节点引用；使用 `BASE_SIZE = 1672x941` 的相对布局，保证和参考图同构。
- 在 `adventure_screen.gd` 中新增 `inventory_overlay` 相关变量和 `_show_inventory_overlay()` / `_hide_inventory_overlay()` / `_refresh_inventory_overlay()`；把 `bag_button.pressed` 从 `_show_drawer("bag")` 改为打开新 overlay。
- UI 结构：
  - 左上标题横幅 + “背包”文本。
  - 顶部资源条显示：能量、背包容量、灵光、印记。当前数据只有 `energy` 和 `inventory.size()`，灵光/印记先使用固定展示值或从玩家字典读取默认 `spirit_glow=35`、`seal=6`。
  - 左侧需求面板显示 `dominion_requirement` 与 `ascension_requirement`，每项用对应 `bag_req_tile_*` 底板、现有法器图标、`0/1` 或 `1/1` 状态。
  - 右侧“当前持有”网格显示玩家背包聚合后的法器数量，最多 12 格；不足时留空格。
- 法器图标继续使用现有 `_artifact_icon_path()` 资源，不生成新图标；名称使用 `state.artifact_name()`，数量用 `_artifact_counts()`。
- 字体统一使用 `project/assets/fonts/AlibabaPuHuiTi-3-105-Heavy.ttf`；标题、卡片名、数量、资源数值都带深色描边，保持参考图厚重中文 UI 感。
- 关闭按钮使用 `bag_close_normal/hover/pressed.png` 三态；卡片/格子 hover 可叠加 `bag_card_selected_outline.png`，不可满足需求叠加 `bag_disabled_overlay.png`。

## Implementation Notes
- 不新增独立数据模型；直接读取现有 `state.player`：
  - `energy`
  - `inventory`
  - `artifact_history`
  - `dominion_requirement`
  - `ascension_requirement`
- 背包容量按参考图显示为 `当前数量/40`，容量常量放在 `adventure_screen.gd`，命名为 `INVENTORY_CAPACITY := 40`。
- 需求满足规则保持现有逻辑：
  - 统治需求看 `artifact_history`，曾经获得过即满足。
  - 深化/升华需求看当前 `inventory`。
- 交互范围保持信息展示型：打开、关闭、动态刷新、hover tooltip；不在本轮加入丢弃、排序、使用、拖拽等新玩法。

## Test Plan
- 启动游戏后点击右侧背包按钮，确认打开全屏背包 overlay，原侧边抽屉不出现。
- 点击右上角 `X` 和点击遮罩，确认 overlay 关闭且不影响其他浮层。
- 修改/触发背包变化后重新打开，确认数量、需求满足状态、背包容量和资源条刷新。
- 检查 1280x720 默认窗口下布局不溢出；卡片名、数量、需求 `0/1` 不重叠。
- 检查缺失法器图标时仍使用现有 fallback，不导致界面报错或空崩。

## Assumptions
- 本轮背包功能等同于现有 `bag` 抽屉的信息展示能力，只升级为参考图风格的全屏 UI。
- `灵光` 和 `印记` 当前没有明确状态字段时，先从 `state.player` 可选字段读取，缺省显示参考值 `35` 和 `6`。
- 右侧当前持有网格按聚合后的法器种类显示，数量角标显示该法器持有数量。
