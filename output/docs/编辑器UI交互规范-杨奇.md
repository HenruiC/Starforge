# 编辑器 UI 交互规范

> **审美底线**: 暗而不黑，灵而不乱。每个控件必须有存在的理由。
> **色板**: 底 `#1a1a1e` / 金 `#b8860b` / 文 `#f0e6d3`

---

## 总则：按钮行为契约

所有编辑器按钮必须遵循三段式响应：**(1) 即时视觉反馈 → (2) 执行逻辑 → (3) 产出可感知结果**。不可出现点击后无任何视觉变化的情况。按钮按下态(pressed)到恢复(normal)超过 300ms 未完成操作时，必须显示进度指示。

| 按钮状态 | 视觉表现 |
|---|---|
| normal | 暗底 `#2a2a32`，暗金描边 1px，文字 `#f0e6d3` |
| hover | 底微亮 `#3a3a42`，描边加亮至 `#b8860b` alpha=0.8 |
| pressed | 底变 `#b8860b` alpha=0.12，缩放 0.96x |
| disabled | 底 `#1a1a1e`，文字 `#555555` |

---

## 一、对话编辑器

**用户**: 叙事策划 | **产出**: `DialogueChain.tres`

### 布局

| 区域 | 内容 |
|---|---|
| 顶部工具栏 | 新建 / 打开 / 保存 / 另存为 / +条目 (按钮组，`separation=4`) |
| 主内容区(左) | 条目列表 (ItemList)，显示 `序号. [说话人] 文本前30字` |
| 主内容区(右) | 说话人输入 / 正文编辑区 / 速度(SpinBox) / 时长(SpinBox) / 颜色(ColorPicker) |
| 底部预览栏 | 预览 / 停止 按钮，预览中列表逐条高亮 |

### 按钮行为表

| 按钮 | 点击后步骤 | 视觉反馈 | 产出 |
|---|---|---|---|
| **新建** | 清空当前 chain → 创建空 DialogueChain `dialogue_id="new_dialogue"` | 列表清空，右侧控件置灰/清空，标题栏显示"(未保存)" | 内存中空链 |
| **打开** | 弹出 EditorFileDialog(过滤 `*.tres` DialogueChain)→ 选中后 `load(path)` → 赋值 `_chain` → `_refresh_list()` | 列表加载完成时闪一次(光标跳到首条)；文件对话框出现期间工具栏按钮 disabled | `_chain` 引用到磁盘资源 |
| **保存** | `resource_path` 为空则跳转"另存为"流程；非空直接 `ResourceSaver.save()` | 保存期间工具栏显示保存中... 暗金闪烁，保存成功底部弹出"已保存" toast(2s后消失) | 写入 .tres |
| **另存为** | EditorFileDialog(SAVE_FILE) → `file_selected` 信号 → 写出 | 同保存 | 新路径 .tres |
| **+条目** | `DialogueData.new()` → `_chain.entries.append()` → `_refresh_list()` → `_load_entry(last)` | 列表末尾滚入新行，右侧编辑区获得焦点，说话人输入自动获焦(autofocus) | 新增 1 条 DialogueData |
| **预览** | `_chain.entries` 逐条打印到输出控制台，duration > 0 用 duration 否则默认 2s | 当前预览条目在列表中暗金高亮，预览中按钮变为"预览中..."(disabled) | 控制台输出文本序列 |
| **停止** | `_preview_running = false` | 按钮恢复 normal，列表高亮消失 | 中断预览循环 |

### 空状态

- 打开编辑器但无数据: 列表显示一条灰字提示"点击「新建」创建对话链，或「打开」加载已有 .tres"
- 右侧编辑区 placeholder: 说话人="输入说话人名称"，文本编辑区="在这里输入对话内容..."
- 引导第一步: **+条目**按钮高亮闪烁(暗金呼吸动画)

### 与其他编辑器衔接

- 产出 `DialogueChain.tres` 文件，任务编辑器的 StageNode 通过 `OnActDialogue`/`OnCompDialogue` 字段填入 `res://` 路径引用
- 副本蓝图编辑器的 `PlayDialogue` Action 节点同样填入 .tres 路径即可触发

---

## 二、任务编辑器

**用户**: 关卡策划 | **产出**: `MissionChain.tres`

### 布局

| 区域 | 内容 |
|---|---|
| 顶部工具栏 | 新建链 / 打开 / 保存 / 另存为 / +Stage (按钮组 + 当前文件路径显示) |
| 主内容区 | GraphEdit 画布，ChainRoot 节点(绿色输出端口) → Stage 节点链 |
| 底部属性面板 | 选中节点时显示当前节点属性摘要；未选中时显示引导文字 |

### 按钮行为表

| 按钮 | 点击后步骤 | 视觉反馈 | 产出 |
|---|---|---|---|
| **新建链** | `clear_connections()` → 移除所有 StageNode → 创建新 ChainRoot | 画布清空，ChainRoot 节点居中出现(绿色) | 空白任务链图 |
| **打开** | EditorFileDialog → `load(path)` → `_load_chain()` 重建 Stage 节点 + 连线 | 节点逐个生成并定位(自上而下排列)，加载完成后画布缩放到合适视口 | 还原图 |
| **保存** | `_build_chain()` 序列化所有节点 → `ResourceSaver.save()` | 同对话编辑器保存反馈 | MissionChain.tres |
| **+Stage** | 创建 StageNode → `_graph.add_child()` → 首节点自动连 ChainRoot，后续节点连前驱 | 新节点淡入(y+200 纵排)，连线自动绘制为暗金色 | 新增 MissionStage |

### 空状态

- 画布仅显示 ChainRoot 节点 + 半透明文字"点击 +Stage 创建第一个任务阶段"
- 引导第一步: **+Stage**按钮边框呼吸闪烁

### 与其他编辑器衔接

- StageNode 内置 **对话引用字段**: `OnActDialogue` / `OnCompDialogue` 填入对话编辑器产出的 `res://resources/dialogue/xxx.tres` 路径
- 每个 Objective 也有独立的 `ObjDialogue` 完成对话引用

---

## 三、技能/Boss 编辑器

**用户**: 战斗策划 | **载体**: Godot 原生 Inspector 增强

### 布局

| 区域 | 内容 |
|---|---|
| 顶部(检查器标准属性区) | BossAttackData 或 BossPhaseData 的 `@export` 属性(由 Godot 内置 Inspector 渲染) |
| 中部(插件注入) | 攻击范围 2D 预览画布 (AttackPreviewCanvas, 180px 高) — 实时绘制范围/扇形/冲刺箭头/投射物 |
| 底部(阶段专属) | BossPhaseData 显示"乐章概览"RichTextLabel — HP阈值/移速/弹幕/召唤等一口看完 |

### 无自定义按钮

此编辑器依赖 Godot 原生 Inspector 的交互。插件只需定义:

| 交互 | 行为 | 视觉反馈 |
|---|---|---|
| 属性值变更 | AttackPreviewCanvas.queue_redraw() | 预览画布实时刷新，范围圆/扇形/箭头跟随参数变化 |
| 选中 BossAttackData | `_can_handle()` → `_add_attack_preview()` | 预览区平滑展开(展开动画 150ms) |
| 选中 BossPhaseData | `_can_handle()` → `_add_phase_quick_info()` | 乐章概览卡片淡入 |

### 空状态

- 未选中任何 Resource 时: 不显示任何自定义面板(由 `_can_handle` 控制)
- 选中后预览画布 180px 空白但绘制坐标系参考线(玩家位置绿点 + 暗底)

### 与其他编辑器衔接

- BossPhaseData 中的 `skill_slots` 为后续技能编辑器预留接口
- BossAttackData 参数是 BossAI 的运行时数据源，修改后需重新加载场景生效

---

## 四、副本蓝图编辑器

**用户**: 关卡策划 | **产出**: `DungeonGraph.tres`

### 布局

| 区域 | 内容 |
|---|---|
| 顶部工具栏 | 新建 / 打开 / 保存 / 另存为 / 五色类别图例(Trigger绿/Condition橙/Action蓝/Logic紫/Variable青) |
| 主内容区 | GraphEdit 画布，右键弹出分类菜单添加节点，拖拽端口连线 |
| 底部属性面板 | 选中节点显示 `[类别] 节点类型 — 属性`；未选中显示引导 |

### 按钮行为表

| 按钮 | 点击后步骤 | 视觉反馈 | 产出 |
|---|---|---|---|
| **新建** | 清除所有 GraphNode → `clear_connections()` → `_node_counter=0` | 画布清空，底部提示更新 | 空白蓝图 |
| **打开** | EditorFileDialog → `load(path)` → `_deserialize()` 每节点 create_node | 节点逐个恢复位置，连线重建，画布 `fit_to_content` | 还原蓝图 |
| **保存** | `_serialize()` 收集节点字典 + 连线字典 → `ResourceSaver.save()` | 同前 | DungeonGraph.tres |
| **右键菜单** | 五类分隔菜单 → 选中项 → `_add_node_at(def, pos)` | 节点出现在右键点击位置，同类色底 alpha=0.15 | 新增 GraphNode |

### 空状态

- 画布中央显示一行灰字"右键画布选择节点类型开始搭建副本逻辑"
- 五色图例在工具栏保持显示

### 与其他编辑器衔接

- `PlayDialogue` Action 节点的 `dialogue_path` 字段引用对话编辑器的 .tres
- `UnlockDoor` Action 的 `door_id` 对应场景中 LockedDoor 节点的 door_id
- `AdvanceStage` Action 推进任务编辑器的 Stage，依赖 MissionChain 中定义的 Stage 索引

---

*杨奇审校，2026-05-20*
