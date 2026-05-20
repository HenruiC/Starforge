# QA 测试报告 — 系统层

**审查人**: Starforge 系统QA
**日期**: 2026-05-19
**项目**: combat-demo (Godot 4.6)
**范围**: 穿墙碰撞系统 / 地图面板 / 任务触发系统 / 任务提示UI

---

## 总览

| 项目 | 数值 |
|------|------|
| 审查文件数 | 38 (.gd + .tscn + .godot) |
| P0 (致命) | 2 |
| P1 (严重) | 4 |
| P2 (一般) | 6 |
| **总计** | **12** |
| Tween规范合规违规 | 8项 |

---

## P0 — 致命 (游戏逻辑崩溃 / 核心机制失效)

### P0-1: EventBus.player_died 信号签名不匹配导致游戏无法进入死亡流程

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\event_bus.gd` (第8行) / `scripts\player.gd` (第110行)

**问题**: `EventBus` 定义信号为 `signal player_died(kill_count: int)`，要求一个 `int` 参数。但 `player.gd:_die()` 以无参数方式调用 `EventBus.player_died.emit()`。Godot 4.x 带类型信号的 `emit()` 必须匹配声明的参数个数，否则抛运行时错误，信号不发射。

**影响**: 
- `EventBus.player_died` 信号永不触发
- `game_manager.gd` 中连接的 `_on_player_died()` 从不执行
- 整个死亡流程（spawn_timer.stop()、GameOver面板显示、Tween清理、状态切换）全部跳过
- 玩家死亡后进入不可操作但游戏继续的"僵死"状态
- 致死 — 核心循环断裂

**触发路径**: 玩家 HP <= 0 → `_die()` → `EventBus.player_died.emit()` → 运行时错误 → 信号不触发 → 游戏挂起

**修复**: 将第8行改为 `signal player_died()`（移除 kill_count 参数），或将第110行改为 `EventBus.player_died.emit(_kill_count)`。

---

### P0-2: 远程敌人弹幕完全无视墙壁碰撞

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\enemy_projectile.gd` (第29-32行)

**问题**: `_on_hit(body)` 仅检查 `body.is_in_group("player")`。墙壁（包括 wall.tscn 和 TileMap 墙体）不在 "player" 组，故弹幕径直穿过所有墙壁。

**影响**: 
- 远程敌人在墙壁后仍可击中玩家（弹幕穿透墙壁）
- 玩家躲在柱子/墙角后无安全区
- 核心战斗逻辑失效

**触发路径**: 远程敌人 → shoot() → EnemyProjectile 飞行 → 穿过墙壁 → 命中玩家

**对比**: PlayerProjectile 有 `body.is_in_group("destructible")` 检查，至少可被独立墙壁实例拦截。EnemyProjectile 完全没有墙体碰撞逻辑。

**修复**: 在 `_on_hit` 中添加墙体组检测：
```gdscript
if body.is_in_group("destructible") or body is TileMap:
    queue_free()
    return
```

---

## P1 — 严重 (功能异常 / 用户体验崩溃)

### P1-1: PlayerProjectile 无法被 TileMap 墙体阻挡

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\player_projectile.gd` (第39-42行) / `scripts\school_map.gd`

**问题**: 实际游戏使用 `school_map.gd` 的 TileMap 方式生成地图墙壁，其物理体为 TileMap 节点本身。PlayerProjectile 的 `_on_hit` 检查 `body.is_in_group("destructible")`，但 TileMap 节点未被加入任何组。故 TileMap 墙壁对玩家弹幕无阻挡。

**影响**: 
- 玩家弹幕飞出边界围墙，击杀边界外的敌人
- 教室柱子（2x2掩体）对弹幕无效
- 走廊墙壁不能阻挡弹幕，战斗节奏异常

**触发路径**: player_projectile 飞行 → 接触 TileMap 墙体 cell → body_entered 触发，body=TileMap → `is_in_group("destructible")=false` → 弹幕穿过

**修复选项** (任选一):
1. 在 `school_map.gd` 中为 TileMap 添加组: `_tm.add_to_group("destructible")`
2. 在 `_on_hit` 中添加 `body is TileMap` 检查
3. 添加 `collision_layer` 位掩码检查

---

### P1-2: Stage 切换后新阶段的任务标题从未显示

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\game_manager.gd` (第538-549行)

**问题**: `_on_stage_cleared` 中信号同步顺序问题：
1. `stage_completed.emit()` 触发 `_on_stage_cleared`
2. `_on_stage_cleared` 调用 `_refresh_prompt_ui_from_stage()`
3. 此时 `_try_advance_to_next()` 尚未执行，故当前 stage 仍为旧 stage
4. `_refresh_prompt_ui_from_stage()` 获取旧 stage 的数据（所有 objective 已完成），清空提示
5. 随后 `_try_advance_to_next()` 激活新 stage，但无需重新刷新提示 UI
6. **结果**: 新 stage 的激活标题（暗金大字提示）永不显示，玩家不知道任务已推进

**触发路径**: Stage 1 完成 → 自动推进 Stage 2 → Stage 2 标题 "第二试炼 · 沉默的教室" 不出现

**修复**: 在 `_on_stage_cleared` 末尾延迟刷新，或在 `_on_internal_stage_activated` 信号中触发刷新。

---

### P1-3: 对话期间可打开地图导致界面重叠

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\game_manager.gd` (第688-693行)

**问题**: `_trigger_stage_dialogue` 直接调用 `get_tree().paused = true` 和 `dlg.show_dialogue(msgs)`，但未调用 `GameState.set_state(State.DIALOGUE)`。故 `GameState.current_state` 仍为 `PLAYING`。

当 M 键处理 `_input` 检查 `event.keycode == KEY_M and _game_started` 时，不检查当前状态。对话期间按 M 会：
1. 打开 MapPanel（z_index=5）
2. DialoguePanel（z_index=10）仍在顶层，半边重叠
3. 两个面板同时可见，交互状态混乱

**触发路径**: Stage 完成 → 对话弹出 → 玩家按 M → 地图面板在对话面板下方打开 → 界面重叠

**修复**: 
1. `_trigger_stage_dialogue` 中设置 `GameState.set_state(State.DIALOGUE)`
2. `_input` 中 M 键处理前检查 `GameState.current_state != State.DIALOGUE`

---

### P1-4: Stage 结束对话与提示UI刷新并发执行

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\game_manager.gd` (第551-571行)

**问题**: `_trigger_stage_dialogue` 是隐式 async 函数（包含 `await`），但在 `_on_stage_cleared` 中以非 `await` 方式调用。导致：
1. 对话开始播放（`await dlg.dialogue_finished` 挂起）
2. `_refresh_prompt_ui_from_stage()` 立即执行（对话播放中）
3. MissionTriggerManager 的 TIME_SURVIVE 定时器在对话期间暂停
4. 对话结束后 `get_tree().paused = false` 恢复

并发执行意味着对话播放期间，`_process` 仍运行（虽然 paused=true 时会跳过 TIME_SURVIVE），但 MissionManager 和 GameManager 仍在处理帧逻辑。

**触发路径**: Stage 完成 → 对话弹出 → 对话播放期间 PromptUI 刷新 → 可能导致 objective 状态不同步

**修复**: 添加 `await` 或重构为状态机：

```gdscript
func _on_stage_cleared(cleared_stage_id: int) -> void:
    CombatFeedback.screen_shake(8.0); CombatFeedback.big_hit_stop()
    _mission_prompt_ui.hide_direction_arrow()
    await _trigger_stage_dialogue(cleared_stage_id)
    _refresh_prompt_ui_from_stage()
```

---

## P2 — 一般 (规范违规 / 代码质量问题)

### P2-1: 多处 create_tween() 未设置 group_name (违反 Tween 规范 §2.2.1)

**文件**: 以下文件所有 create_tween() 调用点

| 位置 | 行号 | 问题 |
|------|------|------|
| `player.gd` — take_damage 受击闪红 | 101 | 无 group_name |
| `player.gd` — level_up_effect exp_bar | 138 | 应为 "hud_exp" |
| `player.gd` — Level Up 飘字 | 154 | 无 group_name |
| `enemy.gd` — 受击震动 | 152-155 | 无 group_name |
| `enemy.gd` — 粒子碎片 | 168-172 | 无 group_name |
| `enemy.gd` — Boss光环脉冲 | 79-81 | 无 group_name |
| `enemy.gd` — 死亡扩散 | 190-192 | 无 group_name |
| `enemy.gd` — 射击闪光 | 127 | 无 group_name |
| `game_manager.gd` — CharSelect入场 | 118-134 | 无 group_name |
| `game_manager.gd` — 选择确认 | 142-148 | 无 group_name |
| `game_manager.gd` — GameOver序列 | 311-326 | 无 group_name |
| `game_manager.gd` — 呼吸提示 | 331-335 | 无 group_name |
| `game_manager.gd` — 升级选择反馈 | 456-474 | 无 group_name |
| `game_manager.gd` — Operator乱码 | 504-518 | 无 group_name |
| `game_manager.gd` — 低血量覆盖 | 731-734 | 无 group_name |
| `door.gd` — 开门动画 | 28-31 | 无 group_name |
| `door.gd` — 受击闪烁 | 41 | 无 group_name |
| `destructible.gd` — 受击闪烁 | 30-34 | 无 group_name |
| `destructible.gd` — 销毁动画 | 57-60 | 无 group_name |

**影响**: 这些 Tween 在面板切换/死亡时无法通过 `kill_group()` 清理，可能导致属性残留。特别是 `player.gd:tak_e_damage` 的受击闪红 Tween — 如果玩家在闪红过程中死亡，flash 不会被清理。

**修复**: 所有 create_tween() 调用点必须紧跟 `t.group_name = "xxx"`，其中 xxx 对应该 Tween 的功能域。

---

### P2-2: Tween 缺少 process_mode 设置

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\game_manager.gd`

| 位置 | 行号 |
|------|------|
| `_enter_char_select` | 118 |
| `_on_char_select_started` | 142 |
| `_play_upgrade_selection_feedback` | 456 |
| `_apply_garbled_text` | 504 |
| `_update_low_hp_overlay` | 731 |

Tween 规范 §2.1 要求所有 UI Tween 使用 `TWEEN_PROCESS_IDLE`。上述5处未设置 process_mode，使用默认值 `TWEEN_PROCESS_PHYSICS`，在低帧率下可能出现动效节奏异常。

---

### P2-3: MissionPromptUI._process 中创建 Tween (违反 §2.4.1)

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\ui\mission_prompt_ui.gd` (第206-207行 → 第289-297行)

**问题**: `_update_arrow_position` 在箭头接近/远离目标的状态转换时创建 Tween（淡入/淡出），该函数从 `_process(delta)` 每帧调用。虽然 Tween 仅在状态转换时创建（非每帧），但仍违反 §2.4.1 "禁止在 _process() 内创建 Tween" 的强制性规定。

**风险**: 在极端条件下（如箭头在近距离/远距离之间抖动），每帧都可能触发状态转换和 Tween 创建，造成性能退化。

**修复**: 改为信号或 Timer 触发箭头淡入/淡出，不在 _process 评估路径中直接创建 Tween。

---

### P2-4: MapSystem 玩家标记坐标无拉回限制

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\map_system.gd` (第44-50行)

**问题**: `PlayerMarker` 的 `offset_left` / `offset_top` 基于玩家世界坐标线性映射，无 clamp。当玩家在 3200x2400 边界外（因碰撞穿透或边界出生点），标记会移到地图 TextureRect 外，产生"标记飞出地图"的视觉异常。

**修复**: 为偏移量添加 clamp：
```gdscript
mk.offset_left = clamp(-400 + _player.global_position.x * rx - 10, -400, 400 - 20)
mk.offset_top = clamp(80 + _player.global_position.y * ry - 12, 0, 400 - 24)
```

---

### P2-5: MissionTriggerManager Zone 连接使用 Callable.bind() 导致内存泄漏风险

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\mission_trigger_manager.gd` (第293-296行)

**问题**: `_connect_zone_signals` 每次调用创建新的 `Callable.bind(area)` 闭包。`_cleanup()` 通过 signal map 逐一 `disconnect`，但如果 `_cleanup()` 在 `_ready()` 前被调用（边界情况），`_zone_signal_map` 中的 Callable 未被存储，导致信号泄漏。

另外，`_find_existing_zones` 获取场景中所有 `mission_zone` 组节点，但 `_cleanup()` 只断开 `_tracked_zone_areas` 中的信号。如果场景中预置的 Zone 在多次 `load_chain()` 之间未被移除，信号会重复连接。

**修复**: `_cleanup()` 中额外遍历 `_zone_signal_map` 确保所有信号断开。

---

### P2-6: NavManager 硬编码教学楼排除区域，忽略 TileMap 布局

**文件**: `D:\AI\GodotProjects\combat-demo\scripts\nav_manager.gd` (第45-47行)

**问题**: 教学楼排除区域硬编码为 `6*48, 2400-18*48, 54*48, 13*48`，假设地图使用 `map_school.gd` 的布局（48x48 tiles）。但实际游戏使用 `school_map.gd`（不同的 TileMap 坐标）。NavManager 的硬编码值与实际地图结构不匹配。

**影响**: 敌人出生点可能落在教学楼内墙壁中（"被困在墙里出生"），或反向落在空旷区域正中（失去掩体优势）。

**修复**: 从 TileMap 读取建筑区域边界，或统一使用导航多边形烘焙结果。

---

## Tween 规范合规检查 (参考规范 §7)

### 基础合规 (20项)

| # | 检查项 | 状态 | 备注 |
|---|--------|------|------|
| 1 | 所有 create_tween 使用 TWEEN_PROCESS_IDLE | **未通过** | P2-2: 5处无 process_mode 设置 |
| 2 | 所有 Tween 设置 group_name | **未通过** | P2-1: 18处无 group_name |
| 3 | 同 group 不并发 | **通过** | UIEffects.kill_group 模式正确 |
| 4 | _process 内无 create_tween | **未通过** | P2-3: MissionPromptUI 箭头 Tween |
| 5 | 暂停态面板根节点 PROCESS_MODE_ALWAYS | **通过** | MapPanel / LevelUpPanel / GameOver 均已设置 |
| 6 | 状态转移时旧 Tween 被 kill | **基本通过** | _on_player_died 中 kill 所有 HUD group |
| 7 | 死亡打断升级清理正确 | **通过** | _on_player_died 检查 level_up_panel.visible |
| 8 | 连续3次升级无重叠 | **需测试** | 有 await 间隔 + kill_group 保护 |
| 9 | 可跳过动效终点参数正确 | **待测试** | DialoguePanel 打字机跳过可用 |
| 10 | 不可跳过动效不被意外跳过 | **待测试** | GameOver 序列无跳过机制 |
| 11 | paused=true 时面板 Tween 正确推进 | **通过** | process_mode 正确，pause_mode 正确 |
| 12 | paused=false 时 HUD Tween 正确恢复 | **需测试** | HUD 无 pause 保护，暂停时冻结 |
| 13 | 低帧率 stagger 总窗口固定 | **N/A** | 当前无 stagger 实现 |
| 14 | Alt+Tab Tween 时间不累积 | **待测试** | 依赖 Godot 引擎行为 |
| 15 | GameOver 与升级残留遮罩不叠加 | **通过** | visible=false 完全移除 |
| 16 | hover 动效在按钮销毁前 kill | **N/A** | 当前无按钮 hover Tween |
| 17 | 打字机 cut 后文本完整 | **通过** | 直接设置 visible_characters |
| 18 | 场景切换所有 Tween 隐式清理 | **通过** | reload_current_scene 重建树 |
| 19 | 快速 M 键连按无叠加 | **通过** | _toggle_map 逻辑正确 |
| 20 | 对话快速翻页无打字机叠加 | **通过** | 每次 _start_typewriter 先 kill 旧的 |

### 不合格项合计: **4/20**

---

## 详细影响分析

### 穿墙碰撞系统 (4项目标)

| 测试项 | 结论 | 说明 |
|--------|------|------|
| 玩家能否穿过墙壁？ | **通过** | collision_mask=9 包含 bit 3；move_and_slide() 正确碰撞 |
| 敌人能否穿过墙壁？ | **通过** | collision_mask=8 包含 bit 3（但无路径导航，会卡在墙边） |
| 子弹能否穿过墙壁？ | **P0失败** | PlayerProjectile 对 TileMap 不加墙壁检测；EnemyProjectile 完全无视墙壁 |
| 门洞位置能否通过？ | **通过** | Door 类型 tile 无碰撞；Door 节点检测玩家后 disable collision |
| 教室柱子碰撞？ | **通过** | _pillar() 生成 source=1 的 TileMap cells，有碰撞多边形 |

### 地图面板 (5项目标)

| 测试项 | 结论 | 说明 |
|--------|------|------|
| 按 M 打开地图？ | **通过** | GameManager._input 处理 KEY_M |
| 地图纹理正确？ | **通过** | SchoolMap.generate_map_texture() 返回正确纹理 |
| 迷雾覆盖正常？ | **通过** | MapSystem._draw_fog 动态生成迷雾 ImageTexture |
| 玩家标记位置正确？ | **通过** | offset_left/offset_top 公式在 anchor=0.5 下计算正确 |
| ESC/M 关闭地图？ | **通过** | ESC 检查 GameState==MAP，M 调用 _toggle_map |
| 快速连按不卡死？ | **通过** | 奇偶性决定最终状态，无 Tween 叠加 |

### 任务触发系统 (5项目标)

| 测试项 | 结论 | 说明 |
|--------|------|------|
| 游戏开始后有任务提示？ | **P1** | Stage 1 标题显示，但 Stage 2 起标题不显示 (P1-2) |
| 到达校门触发阶段推进？ | **通过** | LOCATION_REACH → zone_gate → objective 完成 |
| 击杀计数正确？ | **通过** | EventBus.enemy_killed_filtered → KILL_COUNT 检查 |
| 阶段切换对话正常？ | **P1** | 对话期间可打开地图 (P1-3)；对话与 UI 刷新并发 (P1-4) |
| 连续快速完成崩溃？ | **需测试** | 有 await + 信号保护，但 Zone 信号可能重复连接 (P2-5) |

### 任务提示 UI (5项目标)

| 测试项 | 结论 | 说明 |
|--------|------|------|
| Stage 激活暗金大字？ | **P1** | Stage 1 显示，Stage 2+ 不显示 (P1-2) |
| 方向箭头指向目标？ | **通过** | _update_arrow_position 计算正确 |
| 目标进度弹窗在右侧？ | **通过** | _objective_container 定位正确 |
| 进度数字弹跳？ | **通过** | ObjectiveEntry.update_progress 中 Tween 缩放动画 |
| 完成时 ✓ + 金色 flash？ | **通过** | ObjectiveEntry.complete 中打勾/颜色动画 |

---

## 总结

**最优先修复**: 
1. P0-1: EventBus.player_died 信号签名 — 否则游戏死亡流程完全断裂
2. P0-2: EnemyProjectile 穿墙 — 远程敌人无法被墙壁阻挡

**次优先修复**:
3. P1-1: PlayerProjectile 穿透 TileMap 墙体 — 玩家弹幕可飞越整个地图
4. P1-2: Stage 切换后标题不显示 — 玩家缺少任务推进的视觉反馈
5. P1-3/P1-4: 对话与地图/UI 刷新冲突 — 界面状态不一致

**框架层面**:
6. 18 处 Tween 缺少 group_name 需要系统级修复，建议在 `UIEffects` 中增加对 `create_tween_with_group` 的强制使用，或添加 `_notification` 钩子检测无 group 的 create_tween 调用。
