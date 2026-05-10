# NPC 扩展生产流程规格

本文档定义第一章 NPC 从 5 个扩展到 20 个时的设定、图片、数据、代码接入和验收标准。所有路径均相对仓库根目录。

## 1. 目标产物

每个 NPC 必须有完整数据和可运行图片资源：

- 章节数据：`project/data/chapter_01.json`
- 概念图：`arts/concepts/actors/<actor_id>_concept_v1.png`
- 透明立绘源图：`project/assets/generated/source/<npc_id>_portrait.png`
- 游戏立绘：`project/assets/generated/<npc_id>_portrait.png`
- 对话半身图：`project/assets/generated/<npc_id>_portrait_half.png`
- 情报小头像：`project/assets/generated/<npc_id>_head_avatar.png`
- 回合选择卡：`project/assets/ui/characters/cards/<npc_id>_select_card.png`

每个 NPC 绑定一个场景背景：

- 场景概念图：`arts/concepts/scenes/scene_<scene_id>_concept_v1.png`
- 运行时背景：`project/assets/generated/bg_<scene_id>.png`

## 2. NPC 数据字段

`chapter_01.json` 中每个 NPC 必须包含：

- `id`：统一使用 `npc_<role>`，例如 `npc_moth_lamplighter`。
- `public_name`：玩家可见中文名。
- `animal_species`：动物物种。
- `public_identity`：公开身份，一句话说明初见信息。
- `true_stance`：`friend`、`enemy` 或 `neutral`。
- `affinity`：初始好感度，建议 1 到 3。
- `friend_judgement`：初始固定为 `unknown`。
- `territory`：中文地点或势力范围。
- `liked_topics`：3 个可提升好感的话题。
- `portrait`：`<npc_id>_portrait.png`。
- `background`：`bg_<scene_id>.png`。
- `join_threshold`：邀请门槛；敌方通常为 99。
- `ally_bonus_chars`：加入队伍后的字符奖励。
- `stats`：`hp`、`frontal_defense`、`frontal_attack`、`assassination_defense`、`assassination_attack`、`charm`。
- `identity_info`：击杀或深度信任后可获得的隐藏信息。
- `intel`：绑定现有 `world_intel_questions`，不新增世界情报题。
- `passive`：加入后的被动能力描述；敌方可写 `无。`。

## 3. 图片 Prompt 标准

### 3.1 共同风格

所有图片必须遵循：

- 参考《哈迪斯》游戏的高对比神话漫画感，但不能照搬其角色、UI 或具体构图。
- 必须是大色块、卡通化、平面化、强剪影的 2D 游戏概念图；不要写实渲染、真实材质、真实光影或 3D 塑料感。
- 使用粗黑手绘勾边、硬边 cel-shading、冷暖撞色、少量高亮边光。
- 细节必须克制：角色服装、道具和纹理都要被概括成少量清晰几何块面，避免碎片化小零件、复杂绑带、复杂纹样和写实褶皱。
- 颜色冲击要强：使用 2 到 3 个高饱和主色形成大面积对撞，不要灰暗、低饱和或过多中间调。
- 立体感要弱：不要厚涂体积塑造，不要复杂渐变，不要真实材质反光；只允许少量硬边明暗块和边缘高光。
- 角色设计必须优先使用大的结构和大的色块：一个头部形状、一个身体主块面、一个披风或外套主块面、1 到 2 个身份道具即可；不要用大量小配件堆设定。
- 背景用于角色设定图时必须是纯色平面背景，不能有场景、地面、投影、渐变、纹理或装饰图案，方便后续参考和抠图。
- 一张图里可包含一个主姿势和一个小比例辅助姿势，但主姿势必须占主体，不能像写实角色海报。
- 不出现文字、数字、水印、UI、按钮、对话框、图标标签。

通用负面 prompt：

```text
no text, no letters, no numbers, no watermark, no UI, no speech bubble, no logo, no photorealism, no realistic rendering, no 3D render, no soft airbrush realism, no cinematic realism, no painterly volume, no realistic fabric folds, no tiny cluttered details, no intricate straps, no ornate micro-patterns, no extra story characters
```

### 3.2 角色概念图 Prompt

用途：沉淀角色视觉方向，保存到 `arts/concepts/actors/`。

版式标准：

- 设定图推荐尺寸为横版 `1536x1024`。
- 画面一半放大半身像，另一半放全身像，用于同时检查脸部识别度和整体剪影。
- 背景必须是一个完整纯色，例如高饱和紫、青、黄、红，不出现任何场景元素。
- 角色只能使用少量大色块和大结构表达，优先保证剪影、物种、身份一眼可读；细碎纹样、复杂层叠服装和真实体积光影均不合格。

模板：

```text
1536x1024 concept sheet for one anthropomorphic <animal species> NPC, <public identity>, personality: <true temperament>, key props reduced to <one or two props>, visual keywords: <keywords>. Exact layout: left half is one oversized bust portrait, right half is one full-body pose. Pure solid <background color> background only. Hades-inspired high-contrast mythic comic energy without copying any Hades character or UI, but much flatter and simpler: huge hard-edged color blocks, thick black hand-drawn outlines, poster-like 2D cartoon, strong readable silhouette, intense warm and cool color clash, only 4 to 6 main color shapes, minimal internal lines, no text, no UI, no photorealism, no 3D shading, no painterly volume, no tiny details.
```

示例：

```text
1536x1024 concept sheet for one anthropomorphic moth lamplighter NPC, a night-market lamp repairer who lights moon-bone lanterns before secret trades, personality: gentle, hesitant, frighteningly observant, afraid of harsh light, key props reduced to round goggles and one long lamp pole, visual keywords: wide moth-wing cloak, moon yellow and teal color clash. Exact layout: left half is one oversized bust portrait, right half is one full-body pose. Pure solid saturated violet background only. Hades-inspired high-contrast mythic comic energy without copying any Hades character or UI, but much flatter and simpler: huge hard-edged color blocks, thick black hand-drawn outlines, poster-like 2D cartoon, strong readable silhouette, intense warm and cool color clash, only 4 to 6 main color shapes, minimal internal lines, no text, no UI, no photorealism, no 3D shading, no painterly volume, no tiny details.
```

### 3.3 透明立绘 Prompt

用途：游戏对话与头像裁切源图。

要求：

- 单角色。
- 透明背景。
- 角色占画布主体，四周透明边不要过多。
- 头部到至少膝盖，最好完整上半身到全身，便于裁切。
- 姿态能体现身份，但不要遮挡脸。

模板：

```text
Transparent background PNG of one anthropomorphic <animal species> NPC, <public identity>, <temperament>, <props and costume>, Hades-inspired high-contrast mythic comic style without copying any Hades character or UI, flat 2D cartoon art, large clean color blocks, thick black hand-drawn outlines, hard-edge cel shading, strong silhouette, character centered and filling most of the canvas, clean transparent edges, no text, no UI, no photorealism.
```

### 3.4 半身图标准

半身图不单独生成，优先由 `project/tools/generate_half_portraits.py` 从 `project/assets/generated/<npc_id>_portrait.png` 自动裁切。

裁切规则：

- 基于 alpha 范围计算角色边界。
- 保留头部到胸腹或上腰。
- 输出到 `project/assets/generated/<npc_id>_portrait_half.png`。

### 3.5 情报小头像标准

头像优先从透明立绘裁切：

- 正方形。
- 透明背景。
- 只保留头肩。
- 脸部识别度高，不能被道具遮挡。
- 输出到 `project/assets/generated/<npc_id>_head_avatar.png`。

如需 AI 生成，使用：

```text
Transparent background square head-and-shoulders avatar of one anthropomorphic <animal species> NPC, clearly readable face, same costume colors as the full portrait, bold flat cartoon style, thick black outlines, high contrast, no text, no UI.
```

### 3.6 回合选择卡 Prompt

用途：回合选择页的 NPC 卡面。

要求：

- 竖版半身角色卡。
- NPC 位约 `365x620`。
- 卡外背景必须为纯 `#00ff00` 色键，后处理转透明。
- 不生成姓名、属性、按钮、图标、底部 UI 框。
- 角色从头部到上腰或胸腹，占画面主体。

模板：

```text
Vertical half-body character selection card for one anthropomorphic <animal species> NPC, <public identity>, <props and costume>, bold flat cartoon style, thick black hand-drawn outlines, high contrast color blocking, clean card frame with character theme colors, simple geometric background inside the card, pure #00ff00 outside the card for chroma key, no text, no numbers, no buttons, no icons, no nameplate, no stat boxes.
```

### 3.7 背景图 Prompt

用途：对话页和商店页背景。

要求：

- 16:9。
- 对话冒险背景。
- 底部三分之一相对干净，避免遮挡对话框。
- 场景主体明确表达地点功能。
- 不出现角色主角、文字、UI 或气泡。

模板：

```text
16:9 dialogue adventure background for <scene name>, <scene type>, visual keywords: <keywords>, bottom third kept visually clean for dialogue UI, bold flat cartoon style, thick black hand-drawn outlines, high contrast warm and cool color blocking, cinematic composition, no characters, no text, no signs with readable letters, no UI, no speech bubbles.
```

## 4. 场景命名与接入

场景概念图命名：

```text
arts/concepts/scenes/scene_<scene_id>_concept_v1.png
```

运行时背景命名：

```text
project/assets/generated/bg_<scene_id>.png
```

NPC 的 `background` 字段必须写运行时背景文件名。`project/scripts/ui/adventure_screen.gd` 的 `_scene_name_from_background()` 需要为每个背景返回中文场景名。

## 5. 制作流程

1. 在 `docs/gdd/NPCCharacterBible.md` 中确定 NPC 设定和场景绑定。
2. 生成或确认角色概念图，保存到 `arts/concepts/actors/`。
3. 生成透明立绘，保存到 `project/assets/generated/source/` 并复制到 `project/assets/generated/`。
4. 运行 `project/tools/generate_half_portraits.py` 生成半身图。
5. 生成或裁切小头像，保存到 `project/assets/generated/`。
6. 生成回合选择卡，保存到 `project/assets/ui/characters/cards/`。
7. 将场景概念图复制或重制为运行时背景，保存到 `project/assets/generated/`。
8. 更新 `project/data/chapter_01.json` 的 `npcs`。
9. 更新 `_scene_name_from_background()` 的中文名映射。
10. 运行 `project/tools/check_npc_assets.py` 验证数据和资源。

## 6. 验收标准

- `chapter_01.json` 可解析，NPC 数量为 20，所有 `id` 唯一。
- 每个 NPC 都有 portrait、half portrait、head avatar、select card 和 background。
- 回合选择页随机展示新增 NPC 时不缺图。
- 对话页进入新增 NPC 时背景和半身立绘都能显示。
- 商店页使用当前 NPC 背景时不缺图。
- 情报证言使用小头像时不缺图。
- 五类地点都至少抽测一次：夜市、档案馆、使馆、药铺、边门。
