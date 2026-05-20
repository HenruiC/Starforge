# UI 动效生命周期规范

> **文档性质**: 强制规范 — 非建议、非指南
> **版本**: v1.0
> **审核人**: Tim Cook (Starforge 主QA)
> **起草依据**: 六人最终共识 (2026-05-18)、GameStateManager 状态机、PanelManager 现有实现、杨奇 Tween 技术补充
> **适用范围**: `scripts/ui/`、`scripts/game_manager.gd` 及所有创建 Godot Tween 的 UI 相关代码
> **生效日期**: 即日起。所有 Tween 实现代码合并前必须通过本规范验收检查清单全部项目
> **更新规则**: 任何动效参数变更、新面板动效引入、或状态机扩展必须同步更新本规范对应章节

---

## 目录

1. [术语定义](#1-术语定义)
2. [Tween 创建与销毁规则](#2-tween-创建与销毁规则)
3. [状态转移时的 Tween 处理矩阵](#3-状态转移时的-tween-处理矩阵)
4. [中断行为规范](#4-中断行为规范)
5. [跳过机制行为定义](#5-跳过机制行为定义)
6. [极端场景覆盖](#6-极端场景覆盖)
7. [验收检查清单](#7-验收检查清单)
8. [附录: Tween 注册表伪代码接口](#8-附录-tween-注册表伪代码接口)

---

## 1. 术语定义

| 术语 | 定义 |
|------|------|
| **活跃 Tween** | 已通过 `create_tween()` 创建且未完成、未被 `kill()` 的 Tween 实例 |
| **group** | Tween 的 `group_name` 属性, 用于批量管理。一个 group 对应一个面板或一个功能域 |
| **kill** | 调用 `Tween.kill()`, 将属性停在当前值, 释放 Tween 资源。被 kill 的 Tween 不会触发 `finished` 信号或 `tween_callback` 链 |
| **进场动效** | 面板从不可见到完全可见的动效序列 (fade in + scale / stagger / slide) |
| **退场动效** | 面板从完全可见到不可见的动效序列 (fade out + scale / slide) |
| **硬切 (hard cut)** | 直接设置属性到终点值, 不经过 Tween 过渡。等效于 `kill()` + 手动设置终点属性 |
| **加速跳过** | 将正在运行的 Tween 速度提升 N 倍 (如 3x), 让动效快速播完, 保留视觉引导 |
| **cut 跳过** | 等同于硬切 — Tween 属性直接设到终点, 视觉引导丢失 |
| **stagger 总窗口** | 从第一个子元素开始入场到最后一个子元素开始入场的总时间窗口。子元素延迟 = 总窗口 / (元素数 - 1) |

---

## 2. Tween 创建与销毁规则

### 2.1 process_mode: TWEEN_PROCESS_IDLE (强制性)

```
规则 2.1.1: 所有 UI Tween 必须使用 TWEEN_PROCESS_IDLE。
            不得使用 TWEEN_PROCESS_PHYSICS。
```

**原因**: 物理帧频率 (默认 60Hz 但不保证) 与渲染帧率可能不同, 导致动效在不同设备上节奏不一致。`TWEEN_PROCESS_IDLE` 跟随 `_process()` 周期, 与视觉刷新同步, 节奏可预测。

**暂停态面板的 Tween 如何工作**: Tween 设置为 `TWEEN_PROCESS_IDLE` 后, 其推进依赖所属节点的 `process_mode`。规则如下:

```
规则 2.1.2: 需要暂停态下运行动效的面板节点 (LevelUpPanel / DialoguePanel / 
            GameOver / CharSelect), 其根节点 process_mode 必须设为
            PROCESS_MODE_ALWAYS。
            已在现有代码中为 ALWAYS 的节点 (GameManager、DialoguePanel、
            GameStateManager、CombatFeedback) 保持不变。
```

此规则确保 `paused = true` 时这些面板的 Tween 仍能正常推进。

| 面板 | 根节点 process_mode | Tween process_mode | paused=true 时 Tween 运行? |
|------|--------------------|--------------------|----------------------|
| HUD (击杀弹跳、波次切换) | INHERIT (默认) | TWEEN_PROCESS_IDLE | 否 — HUD 动效仅在 PLAYING 状态运行, paused 时不需要推进 |
| LevelUpPanel | PROCESS_MODE_ALWAYS | TWEEN_PROCESS_IDLE | 是 |
| CharSelect | PROCESS_MODE_ALWAYS | TWEEN_PROCESS_IDLE | 是 |
| GameOver | PROCESS_MODE_ALWAYS | TWEEN_PROCESS_IDLE | 是 |
| DialoguePanel | PROCESS_MODE_ALWAYS | TWEEN_PROCESS_IDLE | 是 |
| MapPanel | PROCESS_MODE_ALWAYS | TWEEN_PROCESS_IDLE | 是 |

**实现验证**: `grep` 检查所有 `create_tween()` 调用点, 确认没有 `tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)` 调用。

---

### 2.2 group_name: 每个 Tween 必须指定 (强制性)

```
规则 2.2.1: 每个通过 create_tween() 创建的 Tween 必须在创建后立即设置 group_name。
            格式: "panel_{面板名}" 或 "hud_{功能名}"。
```

**预定义 group 名称表**:

| group_name | 所属面板/功能 | 包含的动效 |
|------------|-------------|-----------|
| `panel_char_select` | CharSelect 面板 | 面板入场淡入、叙事文字淡入、区块 stagger、确认按钮滑入 |
| `panel_levelup` | LevelUpPanel | 遮罩淡入、面板缩放弹入、按钮 stagger、选择确认、面板退场 |
| `panel_gameover` | GameOver | 遮罩淡入、标题弹入、战绩滚动、呼吸提示 |
| `panel_map` | MapPanel | 面板展开淡入、面板关闭淡出 |
| `panel_dialogue` | DialoguePanel | 底部黑条滑入、打字机效果、翻页过渡、面板滑出 |
| `hud_killcount` | HUD KillCount | 击杀数字弹跳 |
| `hud_wave` | HUD WaveLabel | 波次切换 flash + scale |
| `hud_timer` | HUD TimerLabel | 倒计时颜色渐变 + 最后3秒 pulse |
| `hud_mission` | HUD MissionObjectives | 目标完成动画 |
| `hud_cooldown` | HUD 技能冷却 | 冷却遮罩递减 |

**代码模式**:
```gdscript
# 正确
var t := create_tween()
t.group_name = "panel_levelup"
t.tween_property(panel, "modulate:a", 1.0, 0.35)

# 错误 — 没有 group_name
var t := create_tween()
t.tween_property(panel, "modulate:a", 1.0, 0.35)
```

---

### 2.3 kill 策略: 同 group 互斥 (强制性)

```
规则 2.3.1: 在创建属于某一 group 的新 Tween 之前, 必须先 kill 该 group 的所有活跃 Tween。
            策略: 无条件 kill — 不需要先判断是否有 Tween 在运行。
```

**执行方式**:

```gdscript
# Godot 4.x 原生方式: 使用 group_name + kill
func _play_panel_in(panel: Control, group_name: String) -> void:
    # 1. 无条件 kill 同 group 旧 Tween
    get_tree().kill_tweens_by_group(group_name)
    
    # 2. 设置初始状态 (kill 后属性可能停留在中间值)
    panel.modulate.a = 0.0
    panel.visible = true
    
    # 3. 创建新 Tween
    var t := create_tween()
    t.group_name = group_name
    t.tween_property(panel, "modulate:a", 1.0, 0.25)
    t.tween_callback(func(): pass)  # 清理逻辑
```

```
规则 2.3.2: kill 同 group 后、新 Tween 启动前, 必须将目标控件的动效属性
            手动设置为初始值。不允许依赖 Tween 的"从当前值开始"行为 —
            当前值在 kill 后是不确定的 (可能停在任意中间值)。
```

**例外**: 中断场景下的"从当前值反转"行为 (见第 4 章) 是唯一允许不重置初始值的情况, 且只适用于退场打断进场的特定场景。

---

### 2.4 禁止在 _process() 内创建 Tween (强制性)

```
规则 2.4.1: 禁止在 _process(delta) 方法内调用 create_tween()。
            Tween 必须由事件驱动创建 (信号、输入事件、状态变更回调)。
```

**原因**: `_process()` 每帧调用。在其中创建 Tween 意味着每帧创建一个新 Tween 对象, 导致无限 Tween 泄漏、CPU 尖峰、以及不可预期的视觉闪烁。

**违规示例**:
```gdscript
# 绝对禁止
func _process(delta: float) -> void:
    var t := create_tween()
    t.tween_property(label, "modulate:a", 1.0, 0.5)
```

**合法实现 — 事件驱动**:
```gdscript
func _on_kill_count_changed(new_count: int) -> void:
    if old_count != new_count:
        _animate_kill_count(new_count)  # 仅在值变化时创建 Tween

func _animate_kill_count(_count: int) -> void:
    get_tree().kill_tweens_by_group("hud_killcount")
    kill_label.scale = Vector2.ONE
    var t := create_tween()
    t.group_name = "hud_killcount"
    t.tween_property(kill_label, "scale", Vector2(1.15, 1.15), 0.08).set_ease(Tween.EASE_OUT)
    t.tween_property(kill_label, "scale", Vector2.ONE, 0.17).set_ease(Tween.EASE_OUT_BACK)
```

```
规则 2.4.2: 以下场景也禁止在 _process() 内创建 Tween:
            - TimerLabel 的每秒颜色 pulse (改用 Timer 信号触发)
            - 技能冷却遮罩的持续递减 (改用 setter + property Tween 单次触发)
            - 任何"每帧检查条件→满足条件→创建 Tween"的模式
```

---

## 3. 状态转移时的 Tween 处理矩阵

### 3.1 完整状态转移矩阵

当前 GameStateManager 定义的状态:
- `CHAR_SELECT` — 角色选择
- `PLAYING` — 战斗中
- `PAUSED` — 升级面板打开 (战斗暂停)
- `MAP` — 地图面板打开 (战斗暂停)
- `DIALOGUE` — 对话面板 (战斗暂停)
- `DEAD` — 玩家死亡

**规则**: 状态转移前, 先执行 Tween 清理; 状态转移后, 允许新状态的入场动效。

```
         → CS        → PLAYING   → PAUSED    → MAP       → DIALOGUE  → DEAD
CS        -         kill cs     N/A         N/A         N/A         N/A
PLAYING   N/A        -          kill hud    kill hud    kill hud    kill all
PAUSED   kill lvl    kill lvl    -           N/A         N/A        kill lvl
MAP      kill map    kill map    N/A          -          N/A        kill map
DIALOGUE kill dlg    kill dlg    N/A         N/A          -         kill dlg
DEAD       -          N/A        N/A         N/A         N/A          -
```

**缩写对照**:
- CS = CHAR_SELECT
- lvl = panel_levelup (group)
- map = panel_map (group)
- dlg = panel_dialogue (group)
- hud = hud_* (all HUD groups)
- kill all = kill 所有 UI Tween group (panel_* + hud_*)
- N/A = 此转移在当前游戏逻辑中不应发生

### 3.2 逐状态转移的精确行为

#### 3.2.1 CHAR_SELECT → PLAYING

**触发**: 玩家选满 3 个天赋 + 选择武器后点击"踏入试炼"

**Tween 处理**:
1. `get_tree().kill_tweens_by_group("panel_char_select")`
2. CharSelect 面板准备退场 (见 3.3 退场动效规则)
3. 退场动效完成后: `char_select_panel.visible = false`
4. 状态切换为 PLAYING
5. HUD 开始正常更新 (KillCount、WaveLabel 等)

**特殊说明**: "踏入试炼" 的点击反馈 (按钮 scale 0.95 0.06s → 面板收缩 0.3s → 场景过渡) 是 `panel_char_select` group 的一部分, 在 kill 前有独立的短序列。kill 发生在退场动效完成后, 或在进入 PLAYING 状态时强制执行。

#### 3.2.2 PLAYING → PAUSED (升级触发)

**触发**: `level_up_available` 信号 → `_show_upgrade_panel()`

**Tween 处理**:
1. kill 所有 `hud_*` group 的 Tween
2. 暂停游戏 (`get_tree().paused = true`)
3. 创建 `panel_levelup` group 的 Tween: 遮罩淡入 → 面板缩放弹入 → 按钮 stagger

**关键**: 先 kill HUD Tween, 再暂停。如果先暂停再 kill, HUD Tween (process_mode 为 IDLE) 已经冻结, kill 仍生效但不会触发 `finished` 回调, 这是安全行为。

#### 3.2.3 PLAYING → MAP

**触发**: 按 M 键

**Tween 处理**:
1. kill 所有 `hud_*` group 的 Tween
2. `get_tree().paused = true` (由 GameStateManager 自动执行)
3. 创建 `panel_map` group 的 Tween: 地图从玩家位置展开 (scale 0.3→1.0 + fade in, 0.2s)

#### 3.2.4 PLAYING → DIALOGUE

**触发**: 阶段清除后触发对话

**Tween 处理**:
1. kill 所有 `hud_*` group 的 Tween
2. `get_tree().paused = true`
3. 创建 `panel_dialogue` group 的 Tween: 底部黑条滑入 → 打字机效果

#### 3.2.5 PLAYING → DEAD (死亡)

**触发**: `player_died` 信号 → `_on_player_died()`

**Tween 处理**:
1. `get_tree().kill_tweens_by_group("hud_killcount")`
2. `get_tree().kill_tweens_by_group("hud_wave")`
3. `get_tree().kill_tweens_by_group("hud_timer")`
4. `get_tree().kill_tweens_by_group("hud_mission")`
5. `get_tree().kill_tweens_by_group("hud_cooldown")`
6. **如果 LevelUpPanel 打开中**: `get_tree().kill_tweens_by_group("panel_levelup")` + `level_up_panel.visible = false` (硬切, 不播退场)
7. **如果 MapPanel 打开中**: `get_tree().kill_tweens_by_group("panel_map")` + 硬切隐藏
8. **如果 DialoguePanel 打开中**: `get_tree().kill_tweens_by_group("panel_dialogue")` + 硬切隐藏
9. 创建 `panel_gameover` group 的 Tween: 遮罩 0.5s → 标题 → 战绩 → 提示

**优先级规则**: DEAD > PAUSED > (MAP / DIALOGUE / CHAR_SELECT)。死亡是唯一不可逆的状态, 所有非 GameOver 面板的退场动画均被硬切。

#### 3.2.6 PAUSED → PLAYING (升级完成)

**触发**: 玩家选择升级选项 → `_on_upgrade_chosen()`

**Tween 处理**:
1. kill `panel_levelup` group (停止当前退场动效或未完成的入场动效)
2. 执行选择确认反馈 (被选按钮发光+scale, 其余变暗 0.15s)
3. 面板退场: 收缩 + 淡出 0.2s
4. 退场完成后: `level_up_panel.visible = false`
5. `get_tree().paused = false`
6. 状态切换为 PLAYING
7. 恢复 HUD 更新 (KillCount 弹跳等重新激活)

#### 3.2.7 PAUSED → DEAD (升级中死亡)

**触发**: LevelUpPanel 可见期间玩家死亡

**Tween 处理**:
1. kill `panel_levelup` group (不等待退场完成)
2. `level_up_panel.visible = false` (硬切)
3. `get_tree().paused = false` (必须先恢复, 否则 GameOver Tween 无法运行)
4. 创建 `panel_gameover` group 的 Tween
5. 遮罩重叠处理: 如果 LevelUpPanel 的遮罩 (`modulate.a > 0`) 残留, GameOver 遮罩目标 alpha 不受影响; 两个遮罩 alpha 取最大值合并
6. 状态切换为 DEAD

#### 3.2.8 MAP / DIALOGUE → PLAYING

**Tween 处理**:
1. kill 对应面板的 group
2. 面板退场动效
3. 恢复 `get_tree().paused = false`
4. 状态切换为 PLAYING

#### 3.2.9 DEAD → CHAR_SELECT (按 W 重开)

**触发**: `event.is_action_pressed("move_up")`

**Tween 处理**:
1. `get_tree().paused = false` (当前实现直接 reload_scene, 无 Tween)
2. `get_tree().reload_current_scene()` — 整个场景树重建, 所有 Tween 自动清理

**注**: 此转移走场景重载, 不依赖 kill。重载是终极清理手段, 属于安全行为。

### 3.3 退场动效规则

```
规则 3.3.1: 所有面板退场动效均可被硬切。退场对玩家的功能性价值为零 —
            玩家要的是下一个面板, 不是优雅告别。
            但默认路径下应播放退场动效以保持视觉连贯性。
            退场动效被以下情况硬切:
            (a) 被更高优先级状态打断 (DEAD > PAUSED > 其他)
            (b) 同面板的下一次入场已触发 (进场优先于退场)
```

```
规则 3.3.2: 退场动效时长 0.15~0.2s, easing = EASE_IN。
            比入场动效 (0.25~0.35s) 更短 — 离开比到来更快。
```

---

## 4. 中断行为规范

### 4.1 入场中触发退场 → 从当前值反转

```
场景: 面板入场动效正在播放, 玩家操作导致该面板需要退场。
      (例: 地图展开到一半, 玩家按 M 关闭)

规范 4.1.1: 不创建新的退场 Tween。
            在现有入场 Tween 上执行属性反转:
            (a) kill 当前 Tween — 属性停在中间值
            (b) 从当前值开始, 用 0.15s EASE_IN 将属性 Tween 回退场终点
            (c) 退场完成后 visible = false
```

**精确行为** (以 MapPanel 为例):

```
时间线:
  t=0.00: 按 M 打开地图, modulate.a = 0.0, visible = true
  t=0.10: modulate.a 过渡到 ~0.5 (入场动效 mid-way)
          玩家再次按 M — 触发关闭
  t=0.10: kill panel_map group → modulate.a = ~0.5 (停在当前值)
          创建新 panel_map Tween: modulate.a 0.5 → 0.0, 0.15s EASE_IN
  t=0.25: modulate.a = 0.0, visible = false, Tween 完成
```

**视觉验证**: 地图从展开到一半的位置平滑地反向闭合。没有"闪了一下"的突变。

```
规则 4.1.2: 反转行为的 duration = max(退场标准时长, 当前进度剩余的入场时长 × 0.5)。
            这条公式确保: 无论玩家在入场动效的哪个阶段打断,
            退场都看起来是"收起"而非"消失"。
```

### 4.2 重复 show() → 更新目标值 (不排队)

```
场景: 同一面板的 show() 被连续调用, 前一次入场动效尚未完成。
      (例: 旧版代码中快速连续触发升级面板显示)

规范 4.2.1: 不创建第二个入场 Tween 并行或串行运行。
            新 show() 调用时:
            (a) kill 当前入场 Tween
            (b) 将属性终点值更新为新目标值 (通常是 modulate.a = 1.0, scale = 1.0)
            (c) 从当前中间值开始, 用更新后的参数创建新 Tween
```

**与规则 2.3.1 的差异**: 规则 2.3.1 要求先重置属性到初始值再创建 Tween。规则 4.2.1 不从零开始 — 因为目标是同一个终点, 从中间值继续推进比"跳回零再重新开始"视觉更流畅。

```
对比:
  错误行为 (排队):
    Tween1: modulate.a 0.0→1.0 (0.35s)
    Tween2: modulate.a 0.0→1.0 (0.35s) ← 串行等待 Tween1 完成
    结果: 面板 flash (先到 1.0, 跳到 0.0, 再到 1.0)

  正确行为 (更新目标):
    Tween1: modulate.a 0.0→1.0 (0.35s) ... 在 0.2s 处被打断 (当前值 ~0.57)
    新Tween: modulate.a 0.57→1.0 (0.35s * (1.0 - 0.57) = ~0.15s)
    结果: 平滑继续入场, 无闪烁
```

### 4.3 狂按 M 键场景 → 奇偶性决定最终状态

```
场景: 玩家在 0.5s 内按下 M 键 5 次 (打开→关闭→打开→关闭→打开)。

规范 4.3.1: 中间态的 Tween 不残留。
            (a) 第 1 次 M: 创建入场 Tween (panel_map, scale 0.3→1.0)
            (b) 第 2 次 M: kill 入场 Tween → 反转退场 (从当前值→0.3, 0.15s)
            (c) 第 3 次 M: kill 退场 Tween → 反转入场 (从当前值→1.0)
               ...
            最终状态由最后一次按键的奇偶性决定:
            - 奇数次: 面板打开 (visible=true, modulate.a=1.0)
            - 偶数次: 面板关闭 (visible=false, modulate.a=0.0)

规范 4.3.2: 每次 kill 旧 Tween + 创建新 Tween 必须在同一帧内完成。
            不等待旧 Tween 的 finished 信号。
            不递延到下一帧 (不使用 call_deferred / await)。
```

**压力测试标准**: 以 50ms 间隔 (20 次/秒) 连按 M 键 10 次, 面板最终状态必须与奇偶性一致, 无闪烁、无 Tween 泄漏 (通过 `get_tree().get_processed_tweens()` 检查活跃 Tween 数量)。

### 4.4 连续升级的中断与合并

```
场景: 玩家在 LevelUpPanel 退场动效期间又获得经验升级。
      (已在代码中通过 _pending_level_ups 处理, 此为动效层面的补充规范)

规范 4.4.1: 升级退场 + 新升级入场的处理:
            (a) 如果退场 Tween 正在运行: kill 退场 Tween (硬切退场)
            (b) level_up_panel.visible = false (立即)
            (c) 等待 0.05s (一个视觉"眨眼"间隙, 让面板归零)
            (d) 启动新入场 Tween (panel_levelup group)

规范 4.4.2: 如果 level_up_count >= 4 (仪式感递减触发):
            连续升级的第 2 次及以后自动使用快速模式:
            - 入场 duration 从 0.35s 压缩到 0.10s
            - stagger 总窗口从 0.18s 压缩到 0.06s
            - 不使用 ease_out_back, 改用 ease_out (无回弹)
```

---

## 5. 跳过机制行为定义

### 5.1 打字机效果 → 空格 cut 到终点

```
触发条件: DialoguePanel 打字机正在逐字显示, 玩家按空格。
          注意: 当前 DialoguePanel 的实现是一次性设置 text = msg["text"],
          打字机效果尚未实现。本规则约束打字机效果的实现。

规范 5.1.1: 跳过行为 = cut 到终点 (不是加速)。
            处理步骤:
            (a) kill 打字机 group 的 Tween
            (b) text_label.visible_characters = text.length() (显示全部文字)
            (c) 如果打字机有配套光标闪烁 Tween, 同时 kill

规范 5.1.2: 不在 cut 时重新创建入场 Tween。
            打字机效果本身是"文本逐渐可见"的过程,
            cut = 文本直接全部可见 = 功能等价于动效播完。

规范 5.1.3: 空格键的逻辑分层:
            (a) 打字机进行中 → 空格 = 跳过打字机 (cut 到全文)
            (b) 打字机已完成 → 空格 = 翻到下一页
            (c) 翻页过渡动效中 → 空格 = 跳过翻页过渡 (cut 到新文本开始打字机)
```

**验证**: 对话面板显示一句 20 字的话 (打字机速度 0.02s/字, 总需 0.4s)。在 0.15s 时按空格, 全文立即显示, 光标就位。没有残留的逐字 Tween。

### 5.2 Stagger → 点击已出现的子元素加速到 0.01s

```
触发条件: 面板入场 stagger 正在进行, 玩家点击了任意已经 visible 的子元素。
          适用面板: LevelUpPanel (3 升级选项), CharSelect (3 选择区块)

规范 5.2.1: 跳过行为 = 加速 (不是 cut)。
            剩余 stagger 间隔从配置值 (如 0.06s) 加速到 0.01s。
            原因: cut 会让所有元素同时出现, stagger 的视觉引导作用完全丢失。
            0.01s 间隔使剩余元素以"几乎同时但仍有先后"的方式出现,
            视觉引导方向还在, 但不拖沓。

规范 5.2.2: 加速仅对尚未开始入场的子元素生效。
            已入场的元素不受影响。
            当前正在入场的元素以原速度完成 (不打断中间态)。

规范 5.2.3: 加速通过修改 stagger 延迟计时器实现, 不创建新 Tween。
            具体: 遍历剩余待入场子元素, 将其延迟值设为
            current_time + (index × 0.01s)。

规范 5.2.4: 只有已经至少 1 个子元素完成入场后, 点击才触发加速。
            第一个子元素入场完成前点击不触发加速
            (此时玩家还在 stagger 引导的"视觉焦点"阶段)。
```

### 5.3 退场动效 → 无条件 cut 到终点

```
规范 5.3.1: 所有面板的退场动效均可被无条件 cut。
            实现: kill group → 将 modulate.a / scale 等属性直接设到退场终点 → 
            visible = false。

规范 5.3.2: 触发无条件 cut 的场景:
            (a) 状态转移优先级规则触发 (DEAD > PAUSED > 其他 — 见 3.2 节)
            (b) 同面板新入场请求到达 (见 4.4.1)
            (c) 玩家在退场动效期间按下可跳过键 (如 ESC)
```

### 5.4 不可跳过的动效

```
规范 5.4.1: 以下动效触发后不可被玩家输入跳过:
            (a) GameOver 入场序列 (遮罩淡入 0.5s + 标题弹入 + 战绩滚动)
                — 死亡体验的叙事完整性不可打断
                — 例外: 第 5 次及以上死亡 (仪式感递减, 用快速模式 0.1s)
            (b) "踏入试炼"点击反馈序列 (按钮缩放 0.06s → 面板收缩 0.3s → 场景过渡)
                — 这是最后一次确认操作的物理反馈, 打断会导致场景跳变
                — 注意: 此序列总时长 ~0.4s, 是全场最长不可跳过序列,
                  但没有理由让玩家跳过它 — 这是"确认→进入"的仪式,
                  跳过它就是跳过"跨过门槛"的感觉

规范 5.4.2: 不可跳过的动效如果被状态转移规则强制 cut (如死亡打断"踏入试炼"),
            视为状态转移优先级覆盖, 不视为跳过机制违规。
            优先级: DEAD > 不可跳过标记。
```

### 5.5 跳过行为与动效完成回调

```
规范 5.5.1: Tween 被 kill (无论是 cut 跳过还是加速跳过) 后,
            其 tween_callback 链不会被调用。
            依赖"动效完成后执行逻辑"的代码不得使用 tween_callback,
            必须使用独立的信号或状态标志。

规范 5.5.2: 替代方案:
            (a) 需要"面板已完成入场"信号: 在 kill 或加速完成时手动设置标志
            (b) 需要"打字机已完成"信号: 检查 visible_characters == text.length()
            (c) 需要"stagger 已完成"信号: 检查最后一个子元素 scale == Vector2.ONE
```

---

## 6. 极端场景覆盖

### 场景 6.1: 连续升级 3 次 (动画队列不重叠)

**前置条件**: 玩家瞬间获得大量 EXP, 触发 3 次 `level_up_available` (当 `_pending_level_ups > 0` 时)。

**当前代码行为**: `_on_upgrade_chosen()` 末尾有 `await get_tree().create_timer(0.2).timeout` 然后调用 `_show_upgrade_panel()`, 存在时间窗口。

**规范约束**:

```
步骤序列:
  第 1 次升级:
    - _show_upgrade_panel() → 创建 panel_levelup 入场 Tween
    - 玩家选择 → 选择确认反馈 (0.15s) → 面板退场 (0.2s)
    - _on_upgrade_chosen() 检查 _pending_level_ups > 0
    - await 0.2s → _show_upgrade_panel()

  第 2 次升级 (连续):
    - _show_upgrade_panel() 执行规则 2.3.1:
      kill panel_levelup 旧 Tween (第 1 次的退场可能还未完全结束)
    - level_up_panel.visible = false (硬切第 1 次的退场)
    - 等待 0.05s (规则 4.4.1)
    - 检查 level_up_count: 如果 >= 4, 使用快速模式入场

  第 3 次升级 (连续):
    - 同上

  验收标准:
    [ ] 3 次升级的面板动画没有任何重叠 (任何时候只能看到一套面板)
    [ ] 第 2 次和第 3 次如果触发仪式感递减, 使用快速模式 (0.10s 入场)
    [ ] 3 次选择全部正确生效 (技能被应用, 没有"丢失"的升级)
    [ ] Tween 数量正常 — 检查 get_tree().get_processed_tweens()
    [ ] 没有 tween_callback 因 kill 丢失而导致状态不一致
```

### 场景 6.2: 升级面板打开中玩家死亡 (死亡优先)

**前置条件**: LevelUpPanel 可见 + stagger 正在运行, 怪物接触伤害触发 `player_died`。

**规范约束**:

```
步骤序列:
  t=0.00: 玩家打开 LevelUpPanel, stagger 开始
          panel_levelup Tween: 遮罩 modulate.a 0.0→0.5 + 面板 scale 0.6→1.0 + 按钮 stagger
  t=0.15: 第 2 个选项按钮 stagger mid-way (scale ~0.7)
          怪物攻击判定 → player hp <= 0 → player_died signal
  t=0.15: _on_player_died() 被调用:
          (1) get_tree().kill_tweens_by_group("panel_levelup")
          (2) level_up_panel.visible = false (硬切)
          (3) get_tree().paused = false (恢复, GameOver Tween 需要运行)
          (4) _is_game_over = true
          (5) 启动 GameOver 序列:
              game_over_panel.visible = true
              game_over_panel.modulate.a = 0.0
              panel_gameover Tween: modulate.a 0.0→0.9 (0.5s)
              → 标题 scale 0.5→1.0 (0.4s, delay 0.5s)
              → 战绩数字滚动 (0.4s, delay 0.2s)
              → 呼吸提示开始循环

  验收标准:
    [ ] LevelUpPanel 在被 kill 时没有任何残留可见元素
    [ ] LevelUpPanel 按钮在 GameOver 遮罩下不可交互
    [ ] GameOver 序列完整播放, 不因为 LevelUpPanel 残留而视觉异常
    [ ] 遮罩重叠处理正确 (LevelUpPanel 遮罩被 visible=false 移除,
        不存在两套遮罩叠加变暗的问题)
    [ ] paused 状态被正确恢复 — get_tree().paused == false
```

### 场景 6.3: 低帧率下 stagger 行为 (总窗口固定, 杨奇方案)

**前置条件**: 游戏帧率降至 15 FPS (正常 60 FPS 的 1/4), LevelUpPanel 的 3 按钮 stagger 触发。

**配置参数**:
- stagger 总窗口: 0.18s
- 按钮数: 3
- 每按钮延迟: 0.18s / (3 - 1) = 0.09s
- Tween 使用 `TWEEN_PROCESS_IDLE`

**规范约束**:

```
规范 6.3.1: stagger 使用"总窗口固定"策略。
            子元素延迟 = 总窗口 / (元素数 - 1)。
            不是"每子元素固定延迟" — 这会因帧率下降导致总窗口拉伸。

规范 6.3.2: 低帧率下 (<= 20 FPS), Tween 插值由 Godot 引擎自动处理 —
            每帧推进的 delta 值更大, 单次步进更"陡"但总时长不变。
            不需要在代码层面做帧率补偿。
            TWEEN_PROCESS_IDLE 模式下, delta 在低帧率时自动增大,
            保证动效总 duration 不变。

规范 6.3.3: 验收方法:
            用以下脚本模拟低帧率:
            Engine.max_fps = 15
            get_tree().paused = false
            触发 LevelUpPanel stagger。
            检查 3 个按钮是否在 0.18s 总窗口内完成入场。

  验收标准:
    [ ] 60 FPS: 按钮1 0.00s / 按钮2 0.09s / 按钮3 0.18s — 正常 stagger 节奏
    [ ] 30 FPS: stagger 节奏略"陡"但总窗口仍为 0.18s (±0.02s)
    [ ] 15 FPS: stagger 变"陡" — 两个跳变而非平滑过渡 — 但总窗口仍为 0.18s
    [ ] 无"跳帧" — 因子元素在 15 FPS 下帧间隔为 66ms, 0.09s 间隔约 1.4 帧,
        可能按钮2 和 按钮1 在同一帧开始。这是可接受的行为,
        但不应该出现按钮3 晚于 0.22s 的情况
```

### 场景 6.4: Alt+Tab 后回来 Tween 时间不错误累积

**前置条件**: 面板入场动效正在运行 (如 LevelUpPanel 入场, 0.35s), 玩家按 Alt+Tab 切出。5 秒后切回。

**规范约束**:

```
规范 6.4.1: 所有 UI Tween 使用 TWEEN_PROCESS_IDLE。
            当窗口失去焦点时, Godot 的行为取决于
            `ProjectSettings.application/run/low_processor_mode`:
            - 默认 (0): _process() 仍然调用, 但 delta 值正常 —
              所以 Tween 会在后台继续推进。切回来时动效已经结束。
            - 如果设置为 1 (low processor mode): _process() 暂停 —
              Tween 冻结。切回来时从冻结点继续推进。

规范 6.4.2: 无论哪种模式, Tween 都不会出现"时间跳跃"或错误累积。
            Godot 4.x Tween 系统使用"
            tween 累积运行时间 vs duration 比较"的方式推进,
            不依赖 wall clock。
            切回来不会看到动效突然跳 5 秒的距离。

规范 6.4.3: 不推荐使用 TWEEN_PROCESS_PHYSICS 的另一个原因:
            物理时钟在 alt+tab 后可能出现大 delta, 导致物理帧堆积,
            Tween 以不可预期的速度推进。

  验收标准:
    [ ] 低处理器模式关闭: alt+tab 5s 后切回, 动效已完成, 面板处于最终状态。
        没有中间态残留 (如 modulate.a = 0.47)。
    [ ] 低处理器模式开启: alt+tab 5s 后切回, 动效从冻结点继续推进。
        面板最终状态正确。
    [ ] 两种模式都不出现 Tween 跳到异常位置 (如 scale 从 0.5 跳到 2.3)。
```

### 场景 6.5: 快速场景切换 (CharSelect + 地图 + 对话 组合)

**前置条件**: 玩家在 CharSelect 选择完成→场景过渡中→立即触发战斗→立即按 M→阶段切换触发对话。

**规范约束**:

```
规范 6.5.1: 任何时刻, "全屏面板" (CharSelect / LevelUpPanel / GameOver / MapPanel)
            至多只能有 1 个处于 visible=true 状态。
            DialoguePanel 为半屏面板, 可以与全屏面板共存吗? 
            否 — 对话触发时所有非对话面板应不可见。
            参见状态转移矩阵 (3.1) 中的清理规则。

规范 6.5.2: 面板在 GDScript 中的 visible 赋值与 Tween 操作必须原子化 —
            即先 kill 旧 group, 再设置 visible, 再创建新 Tween,
            这三步在同一帧内完成, 中间不 await。

  验收标准:
    [ ] 快速连续操作 (0.1s 内: 选择完成→M 键→ESC) 不出现两套面板同时可见
    [ ] 没有 panel visible = true + modulate.a = 0 的"不可见但阻挡点击"状态
    [ ] mouse_filter 在面板不可见时正确设置为 MOUSE_FILTER_IGNORE
```

### 场景 6.6: 空 Tween 目标 (节点已被 queue_free)

**前置条件**: Tween 正在对某个节点属性做动画, 该节点在此期间被 `queue_free()` 移除。

```
规范 6.6.1: 在 queue_free 面板子元素之前, 必须先 kill 该面板 group 的 Tween。
            不依赖 Tween 自动处理已释放节点的引用 (Godot 4.x 对此行为
            未定义, 可能导致错误日志或崩溃)。

规范 6.6.2: 具体先决清理顺序:
            (1) kill panel group Tween
            (2) 停止所有 Timer (如果有)
            (3) queue_free 子元素
            (4) 设置面板 visible = false

规范 6.6.3: 按钮 hover Tween (hud_hover group) 在按钮被销毁前必须 kill。
            当前 _mk_btn() 创建的按钮在 char_select_buttons.get_children() 
            遍历中被 queue_free。需要在这条语句之前先 kill 所有 hud_hover Tween。
```

---

## 7. 验收检查清单

### 7.1 基础合规检查 (20 条 — Phase 1 必须通过)

| # | 检查项 | 验收方法 | 对应规则 |
|---|--------|---------|---------|
| 1 | 所有 `create_tween()` 调用点使用 `TWEEN_PROCESS_IDLE` | grep `create_tween` + grep `TWEEN_PROCESS_PHYSICS` 确认零命中 | 2.1 |
| 2 | 所有 Tween 设置了 `group_name` | grep `create_tween` 后确认下一行有 `group_name =` | 2.2 |
| 3 | 相同 group 不会并发运行两个 Tween | 在 group 名称列表中逐项 code review | 2.3 |
| 4 | 不存在 `_process()` 内创建 Tween | grep `func _process` → 检查函数体内无 `create_tween` | 2.4 |
| 5 | 暂停态面板根节点 `process_mode` 为 `PROCESS_MODE_ALWAYS` | 检查 LevelUpPanel/GameOver/Dialogue/CharSelect 的 `process_mode` | 2.1.2 |
| 6 | 状态转移时, 旧状态的所有 Tween 被 kill | 逐状态转移 code review + 游戏内测试 | 3.1 |
| 7 | 玩家死亡打断升级时, LevelUp Tween 被正确清理 | 游戏内测试: 打开升级面板后让怪物杀死玩家 | 3.2.7 / 6.2 |
| 8 | 连续 3 次升级不会出现重叠动画 | 游戏内测试: 设置 EXP 获取极大值触发连续升级 | 6.1 |
| 9 | "可跳过"的动效在跳过时终点参数正确 (no mid-value残留) | 游戏内测试: 每项跳过机制单独测试 | 5.1-5.3 |
| 10 | "不可跳过"的动效在操作时不会被意外跳过 | 游戏内测试: 5.4 节列出的不可跳过项逐一验证 | 5.4 |
| 11 | `paused = true` 时面板 Tween 正确推进 | 游戏内测试: 升级面板入场动画在 paused 状态下播放 | 2.1.2 |
| 12 | `paused = false` 时 HUD Tween 正确恢复 | 游戏内测试: 升级完成恢复战斗时 HUD 弹跳正常 | 3.2.6 |
| 13 | 低帧率下 stagger 不会导致"跳帧" (总窗口固定) | 设置 `Engine.max_fps = 15` 测试 stagger | 6.3 |
| 14 | alt+tab 后 Tween 时间不被错误累积 | 窗口切换 5s 后切回, 检查 Tween 状态 | 6.4 |
| 15 | GameOver 与 LevelUp 残留遮罩不异常叠加 | 升级面板中死亡测试 | 3.2.7 / 6.2 |
| 16 | hover 动效在按钮销毁前正确 kill | 面板切换时 code review + 测试 | 6.6 |
| 17 | 打字机 cut 时保证最终文本完整显示 | 对话面板打字机中途按空格 | 5.1 |
| 18 | 场景切换 (DEAD→reload) 时所有 Tween 被隐式清理 | reload_current_scene 测试, 无 Tween 错误日志 | 3.2.9 |
| 19 | 快速 M 键连按不会导致地图 Tween 叠加 | 20次/秒 连按 10 次测试 | 4.3 |
| 20 | 对话翻页快速空格不会导致打字机叠加 | 快速按空格翻页 5 页 | 5.1.3 |

### 7.2 中断行为检查 (12 条)

| # | 检查项 | 验收方法 |
|---|--------|---------|
| 21 | 地图入场中按 M → 从当前值反转退场, 无闪烁 | 游戏中打开地图 0.1s 后关闭 |
| 22 | 地图退场中按 M → 从当前值反转入场, 无闪烁 | 游戏中关闭地图 0.05s 后重新打开 |
| 23 | 重复调用 show() 不排队两个入场 Tween | code review + 连续升级测试 |
| 24 | 狂按 M 键 10 次最终面板状态与奇偶性一致 | 压力测试 50ms 间隔 10 次 |
| 25 | 入场中断退场时退场 Tween 被硬切 (不是反转) | code review: 入场的优先级高于退场 |
| 26 | kill 后属性不留在中间值 (除 4.1 反转场景外) | code review: 每条 kill 后紧跟初始值设置 |
| 27 | 升级退场被打断后新入场前有 0.05s 间隔 | code review `_show_upgrade_panel` 逻辑 |
| 28 | 快速模式 (仪式感递减) 下不出现 stagger 重叠 | 第 5+ 次连续升级测试 |
| 29 | 中断行为不创建孤儿 Tween (无 group_name 的游离 Tween) | `get_tree().get_processed_tweens()` 检查 |
| 30 | 反转行为的 duration 计算公式正确 | code review 4.1.2 公式实现 |
| 31 | `tween_callback` 不用于"动效完成后必须执行"的逻辑 | code review: 关键逻辑使用信号/标志 而非 callback |
| 32 | kill 同 group + 重置属性 + 创建新 Tween 三步在同一帧内 | code review: 中间无 `await` 语句 |

### 7.3 极端场景检查 (10 条)

| # | 检查项 | 验收方法 |
|---|--------|---------|
| 33 | 连续升级 3 次无面板重叠 | 6.1 步骤测试 |
| 34 | 升级中死亡 — LevelUpPanel 不可见且不可交互 | 6.2 步骤测试 |
| 35 | 15 FPS 下 stagger 总窗口 = 0.18s (±0.02s) | 6.3 步骤测试 |
| 36 | Alt+Tab 5s 切回无 Tween 时间跳跃 | 6.4 步骤测试 |
| 37 | 两套面板不会同时 visible (全屏面板互斥) | 6.5 快速操作测试 |
| 38 | queue_free 节点前已 kill 该节点上的 Tween | 6.6 code review |
| 39 | 第 5 次死亡 GameOver 使用快速模式(0.1s) | 游戏内触发 5 次死亡 |
| 40 | CharSelect 加载时不存在"上局"残留 Tween | 死亡→按 W 重开, 检查 CharSelect 入场干净 |
| 41 | 升级选项 stagger 期间点击不会触发幽灵点击 | 面板入场 0.1s 期间点击选项按钮 |
| 42 | 对话进行中按 M 键 → 地图打开, 对话 Tween 被 kill | 测试状态转移: DIALOGUE → MAP |

### 7.4 性能与内存检查 (8 条)

| # | 检查项 | 验收方法 |
|---|--------|---------|
| 43 | 单帧活跃 Tween 数量 ≤ 12 (所有 UI Tween 之和) | `get_tree().get_processed_tweens()` 帧级监控 |
| 44 | Tween 内存不持续增长 (泄漏检测) | 运行 10 分钟 + 100 次面板开关, Tween 数量稳定 |
| 45 | 战斗中同时运行 UI Tween ≤ 5 | PLAYING 状态 `get_processed_tweens` 计数 |
| 46 | stagger 总窗口 ≤ 0.5s (任何面板) | 参数验证: 元素数 × 间隔 ≤ 0.5 |
| 47 | Tween finished 回调不循环创建新 Tween (递归爆炸) | code review: 回调链深度 ≤ 2 |
| 48 | 粒子爆发 Tween (CombatFeedback) 复用现有模式无退化 | 现有 hit_particles 的 `tween_callback(p.queue_free)` 模式保持不变 |
| 49 | 退场动效 duration ≤ 0.2s (不阻塞下一个面板) | 所有面板退场参数验证 |
| 50 | `instance` 单例 (PanelManager) 生命周期内 Tween 可追溯 | 每个 Tween 能从 group_name 反查到创建者 |

---

## 8. 附录: Tween 注册表伪代码接口

以下为 `UIEffects` 静态工具类中 `kill_group` 接口的参考实现骨架。此伪代码仅供接口规范参考, 不约束具体实现方式。

```
class_name UIEffects
# 静态工具类 — 非 Autoload, 非 Node
# 提供 Tween 生命周期管理和通用动效辅助

# === Tween 生命周期 ===

static func kill_group(group: String) -> void:
    """
    安全地 kill 指定 group 的所有活跃 Tween。
    之后不会触发任何 tween_callback 链。
    """
    var tree := _get_tree()
    if tree:
        tree.kill_tweens_by_group(group)

static func kill_all_ui() -> void:
    """kill 所有预先注册的 UI Tween group。在 DEAD 状态和场景切换时使用。"""
    var all_groups := [
        "panel_char_select", "panel_levelup", "panel_gameover",
        "panel_map", "panel_dialogue",
        "hud_killcount", "hud_wave", "hud_timer",
        "hud_mission", "hud_cooldown"
    ]
    var tree := _get_tree()
    if tree:
        for g in all_groups:
            tree.kill_tweens_by_group(g)

static func create_tween_with_group(group: String) -> Tween:
    """创建带 group_name 的 Tween。所有 UI Tween 必须通过此函数创建。"""
    var tree := _get_tree()
    if not tree:
        return null
    tree.kill_tweens_by_group(group)  # 无条件先 kill
    var t := tree.create_tween()
    t.group_name = group
    return t

# === 辅助 ===

static func _get_tree() -> SceneTree:
    """获取 SceneTree 引用。静态类无法直接访问 get_tree()。"""
    return Engine.get_main_loop() as SceneTree

# === 动效参数常量 ===

static var config := {
    hover_duration = 0.12,
    hover_scale = 1.05,
    panel_fade_duration = 0.25,
    panel_out_duration = 0.20,
    stagger_interval = 0.06,
    stagger_fast_interval = 0.01,
    levelup_entry_duration = 0.35,
    levelup_entry_fast_duration = 0.10,
    gameover_entry_duration = 0.50,
    map_entry_duration = 0.20,
    dialogue_entry_duration = 0.25,
}
```

---

## 文档版本历史

| 版本 | 日期 | 变更 | 作者 |
|------|------|------|------|
| v1.0 | 2026-05-18 | 初始发布 — 六人共识后的集成版本。覆盖状态转移矩阵、中断行为、跳过机制、6 个极端场景、50 条验收检查清单 | Tim Cook (主QA) |

---

## 审查确认

| 角色 | 签名 | 日期 |
|------|------|------|
| 主QA (库克) | 已批准 | 2026-05-18 |
| 交互策划 | 待确认 | |
| 美术总监 (杨奇) | 待确认 | |
| 技术负责人 (马斯克) | 待确认 | |
| 创意总监 (小岛) | 待确认 | |
| 系统策划 (陶德) | 待确认 | |

---

*本规范是 **强制性** 执行标准。任何偏离必须先在审查会议中讨论并更新本文档, 不得以"实现便利"为由跳过规范约束。*
*规范中的 group_name 列表、状态转移矩阵、参数常量表均为初始值。随着新面板和新动效的引入, 这些表必须同步更新。*
*与本规范冲突的代码不得合并到主分支。QA 有权在 code review 阶段标记违规代码为 "阻塞"。*
