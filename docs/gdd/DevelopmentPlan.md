# 《骗子大陆》开发总计划与代码规范

## 当前纵切片

- Web 优先的 LLM 剧情冒险原型。
- 玩家只能编辑长期行为文件，不能直接替角色发言。
- LLM 负责生成玩家发言、NPC 回应和战后行动意图。
- 系统规则负责亲近度、敌友判断、情报透露、身份暴露、战后结算和胜负。
- 第一章数据位于 `project/data/chapter_01.json`。

## 模块边界

- `scripts/main.gd`：只负责启动、读取配置、选择主玩法或隐藏 Debug 模式。
- `scripts/core/game_state.gd`：运行时状态。
- `scripts/core/rules_engine.gd`：规则裁判。
- `scripts/core/chapter_loader.gd`：章节 JSON 读取和基础校验。
- `scripts/llm/llm_client.gd`：桌面/Web LLM 请求、JSON 提取和 fallback。
- `scripts/llm/prompt_builder.gd`：玩家、NPC、战后行动 Prompt。
- `scripts/ui/adventure_screen.gd`：剧情冒险流程控制。
- `scripts/ui/adventure_layout.gd`：剧情冒险界面搭建。
- `scripts/ui/debug_keyword_mode.gd`：旧关键词玩法隐藏调试入口。

## 代码规范

- 不把 UI、网络、规则、数据写进同一个文件。
- 单个 `.gd` 文件建议不超过 300 行；超过时优先拆模块。
- 文件名、函数名、变量名使用 `snake_case`。
- 类名使用 `PascalCase`，可复用脚本添加 `class_name`。
- 常量使用 `UPPER_SNAKE_CASE`。
- 私有辅助函数使用 `_` 前缀。
- UI 只展示状态和触发流程，不直接写复杂规则。
- Prompt 只在 `prompt_builder.gd` 维护。
- LLM 不能直接修改状态或决定胜负，只能输出文本和行动意图。

## 美术规范

- 风格参考《哈迪斯》的高对比神话感、暖红/熔金/青绿冲突色和强轮廓，不复制具体素材。
- 最终资源放在 `project/assets/generated/`。
- 角色立绘必须是透明 PNG。
- 生成前源图或中间文件放在 `project/assets/generated/source/`。
- Prompt 记录在 `project/assets/generated/prompts.md`。
