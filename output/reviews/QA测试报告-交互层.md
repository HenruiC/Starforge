# QA测试报告：UI动效和交互功能

**测试日期**: 2026-05-19
**测试方法**: 静态审查（代码审查 + 交叉引用设计文档）
**审查范围**: game_manager.gd, player.gd, char_select_ui.gd, upgrade_ui.gd, dialogue_panel.gd, ui_effects.gd, ui_helpers.gd, combat_feedback.gd, damage_number.gd, mission_prompt_ui.gd

---

## 1. 按钮 hover

### 状态: FAIL — 存在阻断性BUG

#### 问题 1.1 — CONNECT_ONE_SHOT 导致 hover 仅生效一次（严重）

所有 hover 信号连接使用了 `CONNECT_ONE_SHOT`，导致 `mouse_entered` / `mouse_exited` 信号只触发一次后自动断开。

**受影响的位置**:

| 文件 | 行 | 按钮来源 |
|---|---|---|
| `scripts/ui/ui_helpers.gd` | 47-52 | CharSelect 三区按钮（武器/天赋） |
| `scripts/ui/char_select_ui.gd` | 126-131 | CharSelect 确认按钮 |
| `scripts/ui/upgrade_ui.gd` | 32-37 | LevelUp 升级按钮 |

**根因**: `CONNECT_ONE_SHOT` 在信号第一次发射后自动断开连接。后续 `mouse_entered` 或 `mouse_exited` 不再触发回调，hover 放大效果仅存在一次。示例代码（`ui_helpers.gd:47`）:

```gdscript
b.mouse_entered.connect(func():
    UIEffects.hover_in(b)
, CONNECT_ONE_SHOT)  # ← 此处第一次 hover 后连接断开
```

**验证方法**: 鼠标扫过同一按钮两次，第二次无 scale 反馈。

**修复建议**: 移除 `CONNECT_ONE_SHOT` 标志，让连接持久存在。或者使用 `SignalManager` 管理，避免每次 `_build()` 重复连接。

---

#### 问题 1.2 — `__hover` 组冲突导致快速扫过残留（中）

`UIEffects.hover_in()` 和 `UIEffects.hover_out()` 共用 `"__hover"` 组，每次调用都 `kill_group("__hover")` 杀死之前的 hover tween：

```gdscript
static func hover_in(ctrl: Control) -> void:
    kill_group("__hover")  # ← 杀死所有之前 hover 的 tween
    ...
```

快速扫过多按钮时，btn1 的 `hover_in` tween 被 btn2 的 `hover_in` 杀死，btn1 卡在 scale=1.05 无法恢复。反之亦然 — 如果 `hover_out` 在 `hover_in` 之前被杀，按钮残留放大态。

**设计预期**: 0.12s EASE_OUT 平滑恢复。
**当前表现**: 快速扫过 3 个按钮以上时，前一按钮有概率残留 1.05 放大。

**修复建议**: 
- 选项 A：不为全局共享组，采用 per-button tween 独立管理。
- 选项 B：在 `hover_in` 启动前，先将被替换按钮的 scale 归位。

---

## 2. 击杀弹跳 + 仪式感递减

### 状态: PASS

**实现验证**:

| 阈值 | peak_scale | 常量值 |
|---|---|---|
| 1-10 次 | 1.2 | `BOUNCE_SCALE_PEAK_1` |
| 11-50 次 | 1.1 | `BOUNCE_SCALE_PEAK_2` |
| 51+ 次 | 1.05 | `BOUNCE_SCALE_PEAK_3` |

关键逻辑：`game_manager.gd:596-606` 在 `_update_ui()` 中检查 `_kill_count != _prev_kill_count`，确保每次击杀时 `_kill_bounce_count` 仅递增 1。

```gdscript
# game_manager.gd:596
if _kill_count != _prev_kill_count:
    _kill_bounce_count += 1
    ...
    UIEffects.bounce_with_peak(kill_label, peak_scale)
```

**Tween 配置正确**: 
- 每次 `bounce_with_peak` 使用 `Tween.TRANS_BACK` + `Tween.EASE_OUT`
- bounce 流程：kill_group("__bounce") → 从 1.0 弹到 peak (0.125s) → 回到 1.0 (0.125s)
- 使用 `__bounce` 组管理，前一个 bounce 未完成时会被中断，不会叠加速度

**边界检查**:
- 阈值为 `<=` 判定（`_kill_bounce_count <= BOUNCE_DECAY_THRESHOLD_1` 为 1-10 次使用 1.2），与设计一致
- 51 次之后正确使用 `BOUNCE_SCALE_PEAK_3 = 1.05`

---

## 3. 升级面板 stagger

### 状态: PASS（有低风险观察项）

**入场动画** (`game_manager.gd:377-405`):
1. 背景 `Bg` 从透明度 0 → 0.5（0.2s）
2. `Title` 从 scale 0.6 → 1.0（0.35s, TRANS_BACK EASE_OUT）
3. 三枚按钮从 scale 0.5 → 1.0（stagger 0.06s each, TRANS_BACK EASE_OUT）

```gdscript
t.set_parallel(true)
for i in btns.size():
    t.tween_property(btns[i], "scale", Vector2.ONE, 0.15) \
     .set_delay(i * 0.06).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
```

**Stagger 时序正确**: delay = [0.0, 0.06, 0.12]，依次弹出，不阻塞点击（按钮处于可用状态）。

**连续升级处理** (`game_manager.gd:476-485`):
```gdscript
func _finish_upgrade_chosen() -> void:
    ...
    if player.has_pending_level_ups():
        await get_tree().create_timer(0.2).timeout
        _show_upgrade_panel()
```
升级面板关闭后，如果 `_pending_level_ups > 0`，延迟 0.2s 再次打开。动画不会重叠。

#### 低风险观察项：快速连续升级潜在竞态

当 `_pending_level_ups` 从 0→1→2 在极短时间内跳变（例如击杀获取大量经验），`level_up_available` 信号会连续发射两次。`_on_level_up_available` 中有 `await get_tree().create_timer(0.15).timeout`：

```gdscript
func _on_level_up_available(_count: int) -> void:
    await get_tree().create_timer(0.15).timeout
    _show_upgrade_panel()
```

第一个 timer 触发 → `_show_upgrade_panel()` → `get_tree().paused = true`。第二个 timer 在 paused 状态下冻结（`SceneTreeTimer` 默认不处理暂停帧）。恢复 unpause 后两个 timer 可能几乎同时触发，导致 `_show_upgrade_panel()` 在短时间内被调用两次。

**实际影响**: 由于 `_show_upgrade_panel()` 内部先清空按钮再重建，第二次调用会覆盖第一次的 UI 状态，视觉上只是重新刷新面板。不会造成 crash。但在低配机器上可能出现短暂闪烁。

**建议**: 加防重入锁 `_is_upgrading: bool`。

---

## 4. 打字机效果

### 状态: PASS

**实现验证** (`dialogue_panel.gd:169-198`):

| 功能 | 实现 | 状态 |
|---|---|---|
| 逐字出现 | `tween_property(text_label, "visible_characters", len, dur)` | 正确 |
| 每字间隔 | `TYPEWRITE_SPEED = 0.02s` → `dur = len * 0.02` | 正确 |
| 空格跳过 | `_is_typing` 判定 → `kill` 当前 tween → `visible_characters = text.length()` | 正确 |
| 翻页 | 旧内容淡出 0.1s → `_apply_content` → `_start_typewriter` | 正确 |
| 动画兼容 | 翻页时旧内容淡出 + 新内容打字机不会重叠（通过 `_is_transitioning` 锁） | 正确 |
| 输入不冲突 | 空格/回车/左键三种输入方式统一走 `_advance()` | 正确 |

**翻页过渡流程** (`_fade_transition`):
```
旧 label/speaker 文字: modulate:a 1.0 → 0.0 (0.1s)
              ↓ callback
_apply_content(msg) → 新内容
_start_typewriter() → visible_characters: 0 → len (dur)
```

**边界情况检查**:
- 空文本跳过打字机动画（`dialogue_panel.gd:182`）
- `dialogue_finished` 信号在滑出动画完成后发射（`_close`, line 107）
- 面板滑入时 `modulate.a: 0→1` + `position.y: base+40→base` 并行（0.25s EASE_IN_OUT）

---

## 5. 低血量警告

### 状态: PASS

**实现验证** (`game_manager.gd:80-95, 716-734`):

| 功能 | 实现 | 状态 |
|---|---|---|
| 30% 阈值 | `pct < 0.3` → `target_alpha = (0.3 - pct) / 0.3 * 0.65` | 正确 |
| 径向渐变 | `GradientTexture2D.FILL_RADIAL`，从中心到边缘红到透明 | 正确 |
| 渐变纹理 | `Gradient` colors: `[红(0,0,0), 红(0.8,0,0,0.55)]` | 正确 |
| 恢复淡出 | HP ≥ 30% 时 `target_alpha = 0.0`，tween 0.3s 过渡 | 正确 |
| 防抖 | `_last_hp_pct` 对比，差值 <0.01 不触发更新 | 正确 |
| 生命周期 | overlay 在 `_ready()` 时创建，悬挂在 HUDLayer 下 | 正确 |

**透明度计算**: 在 0% HP 时 alpha = (0.3 - 0.0) / 0.3 * 0.65 = 0.65，在 30% 时 alpha 严格为 0。透明度变化线性，符合预期。

---

## 6. 尖叫时刻 A（Operator Protocol）

### 状态: PASS — 但有可优化点

**触发概率** (`game_manager.gd:368`):
```gdscript
var is_operator: bool = not _operator_protocol_active and randf() < 0.05
```
- 一次游戏内最多触发一次（`_operator_protocol_active` 锁定）
- 严格 5% 概率

**"???" 按钮生成** (`game_manager.gd:407-422`):
- 第四个红色按钮插入 `upgrade_buttons`，位置由 `idx = mini(3, pool.size()-1)` 确定
- 暗红色风格 + 禁用 hover 颜色变化
- 按钮不可被普通选择（pressed 连接 `_on_operator_upgrade_chosen`）

**闪烁消失** (`game_manager.gd:424-446`):
```gdscript
t.tween_callback(func(): level_up_panel.visible = false)
t.tween_interval(0.04)
t.tween_callback(func(): level_up_panel.visible = true)
t.tween_interval(0.04)
...
```
闪烁 4 次 (0.04s 间隔) → 最后一次隐藏 → 0.06s 延迟 → 完成回调。

**HUD 乱码** (`game_manager.gd:487-536`):
- 5 个 HUD Label + 4 个玩家 Label（通过 `_garbled_string()` 生成乱码）
- 20 帧 × 0.1s = 2s 乱码时间
- `_recover_text()` 恢复原文 → 设置 `_operator_protocol_active = false`

#### 可优化点

- **无防连点**: 闪烁期间 operator 按钮仍可被点击（`paused = true` 但闪烁 tweens 使用 `TWEEN_PROCESS_IDLE` 所以仍运行），但 level_up_available 信号不会在升级面板打开时重复发射。如果玩家在闪烁期间疯狂点击，可能触发多余的行为。但 `_finish_upgrade_chosen()` 的 `_is_paused = true` 和 `get_tree().paused = true` 确保了输入不会意外推进游戏。

---

## 7. GameOver 序列

### 状态: PASS

**实现验证** (`game_manager.gd:263-326`):

| 阶段 | 实现 | 状态 |
|---|---|---|
| 遮罩淡入 | `panel_bg.color.a: 0 → 0.92`，持续时间 0.3s（5+ 死亡加速为 0.1s） | 正确 |
| 标题弹出 | `title_label.scale: 0.5→1.0` (TRANS_BACK EASE_OUT) + 透明度 0→1（延迟 title_delay） | 正确 |
| 战绩展示 | 文本使用 `_kill_count` / `_current_wave` / `player.level` | 正确 |
| 5 次加速 | `fast_mode = _death_count >= 5`，所有 duration 缩短 2-3x | 正确 |
| W 跳过 | `Input.is_action_pressed("move_up")` → `reload_current_scene()` | 正确 |

**加速参数对比**:

| 参数 | 正常 | 加速 (5+死) |
|---|---|---|
| 遮罩持续时间 | 0.3s | 0.1s |
| 标题动画时间 | 0.4s | 0.2s |
| 标题延迟 | 0.5s | 0.15s |
| 战绩淡入时间 | 0.3s | 0.15s |
| stats 间隔 | 0.2s | 0.05s |

**提示呼吸动画** (`_start_hint_breathing`):
- 透明度 0.4 ↔ 1.0 循环，每周期 2s
- 使用独立的 `_hint_breathing_tween` 引用管理，包含生命周期检查和 `kill()` 清理

**W 键跳过**: W 键跳转前调用 `UIEffects.kill_group("panel_gameover")`，但 `_on_player_died()` 中的 tweens 未注册到 "panel_gameover" 组，`kill_group` 不会生效。不过 `reload_current_scene()` 已足够直接重置场景，tween 组管理无实际影响。

---

## 8. 角色选择入场

### 状态: PASS（有轻微隐患）

**入场第一层** — 面板弹入 (`game_manager.gd:118-120`):
```gdscript
char_select_panel.scale = Vector2(0.85, 0.85)    # 起始状态
char_select_panel.pivot_offset = char_select_panel.size * 0.5  # 居中锚点
# 动画：
t_main.tween_property(char_select_panel, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_IN_OUT)
```

**入场第二层** — 三区依次淡入 (`game_manager.gd:122-135`):
- 遍历 `char_select_buttons` → 找到 HBoxContainer → 三个 VBoxContainer 子节点
- stagger 延迟 0.08s/项（第一项 delay=0, 第二项=0.08, 第三项=0.16）
- 透明度 0 → 1（0.2s each）

#### 轻微隐患

- **pivot_offset 时机问题**: `char_select_panel.size` 在 `_ready()` 上下文中可能不是最终布局尺寸。Control 节点在 `_ready()` 时 `size` 一般是准确的，但如果面板内有动态内容导致重新布局（`Container` 自动布局），`size` 可能后续变化。不过 `scale` 动画在 `_enter_char_select()` 中执行，该函数在 `_show_char_select()` 中被调用（`_ready` 末尾）。此时 Layout 应已完成，风险较低。
- **`kill_group("panel_levelup")` 无注册方**: `_enter_upgrade_panel()` 开头调用 `UIEffects.kill_group("panel_levelup")`，但后续创建的 tweens 全部是裸 `create_tween()` 且未通过 `UIEffects._register_tween()` 注册。`kill_group` 找不到目标，形如空操作。同理 `game_over_panel` 跳转时的 `kill_group("panel_gameover")` 也找不到目标。
- **死代码行**: `game_manager.gd` 中存在多个裸变量表达式：`ct`(line 144)、`t`(line 312, 333, 394, 457, 505)、`t_zones`(line 131)。不是语法错误（GDScript 把变量名当作表达式求值，无副作用），属于残留调试代码或格式化残留。

---

## 9. Tween 生命周期规范检查

### 状态: PASS — 规范一致

| 检查项 | 结果 |
|---|---|
| 所有动效 Tween 使用 `set_process_mode(Tween.TWEEN_PROCESS_IDLE)` | 通过 — 4 个文件共 29 处全部正确 |
| 无 `group_name` 引用 | 通过 — 0 处 |
| 无 `kill_tweens_by_group` 调用 | 通过 — 0 处 |

所有 Tween 创建遵循统一规范：`create_tween()` → `set_process_mode(Tween.TWEEN_PROCESS_IDLE)` → 动画属性 → 回调。

---

## 综合验收结果

| 分类 | 状态 | 发现数 |
|---|---|---|
| 按钮 hover | **FAIL** | 2 issues（1 严重阻断, 1 中等残留） |
| 击杀弹跳 + 递减 | **PASS** | 0 |
| 升级面板 stagger | **PASS** | 0（1 低风险观察项） |
| 打字机效果 | **PASS** | 0 |
| 低血量警告 | **PASS** | 0 |
| 尖叫时刻 A | **PASS** | 0（1 可优化点） |
| GameOver 序列 | **PASS** | 0 |
| 角色选择入场 | **PASS** | 0（2 轻微隐患） |
| Tween 生命周期规范 | **PASS** | 0 |

### 必须修复项（按优先级）

**P0 — 阻断**:
1. `CONNECT_ONE_SHOT` 导致 hover 仅生效一次。涉及文件: `ui_helpers.gd:47-52`, `char_select_ui.gd:126-131`, `upgrade_ui.gd:32-37`。修复后所有按钮 hover 应达到 scale 1.05 且每次 hover 均可触发。

**P2 — 体验优化**:
2. 全局 `"__hover"` 组导致快速扫过残留放大态。建议 per-button tween 管理或 `hover_in` 前主动复位被中断按钮。

**P3 — 代码整洁**:
3. 移除 `game_manager.gd` 中的裸变量表达式残留（`ct`, `t`, `t_zones` 共 6 处）。
4. 确认 `kill_group("panel_levelup")` 和 `kill_group("panel_gameover")` 是否为有意的防御式清理；若是，将相关 tweens 注册到对应组。

### 弹幕/对象泄漏检查

本次审查未涉及弹幕系统（由 `player_projectile.gd` / `skill_*.gd` 管理）。各 UI 面板的节点创建都有 `queue_free()` 或 `visible = false` 清理路径：
- CharSelect: `build()` 开头移除旧叙事 Label; `_toggle_talent` 不产生泄漏
- Upgrade: `create()` 开头 `queue_free()` 旧按钮
- Dialogue: `close()` 中 kill 所有 tween 并隐藏面板
- DamageNumber: `tween_callback(queue_free)` 自动清理

无发现 UI 层节点泄漏。
