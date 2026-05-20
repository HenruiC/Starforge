# GAP-01a 程序任务 — Boss 战实现

> **基于：GAP-01 Boss战最终设计-合并版**
> **负责人分配：系统程序 / 战斗程序 / 关卡程序**
> **总计工时：~15 天（不含预依赖 CombatUnit 迁移）**

---

## 前置依赖

以下任务必须在 Boss 战代码编写前完成：

| 依赖 ID | 内容 | 负责人 | 状态 |
|---------|------|--------|------|
| DEP-01 | `scripts/combat/combat_unit.gd` 基类创建并通过编译 | 系统程序 | 待实施 |
| DEP-02 | `SkillBase` 改造完成（`player` → `owner_unit`） | 系统程序 | 待实施 |
| DEP-03 | `scripts/combat/ai_controller.gd` 创建（enum + switch 方案） | 战斗程序 | 待实施 |
| DEP-04 | `NavManager` 扩展 NavigationAgent2D 注册/管理 | 战斗程序 | 待实施 |
| DEP-05 | `event_bus.gd` 新增 Boss 专用信号 | 系统程序 | 待实施 |

---

## 任务清单

### TASK-P01: EventBus 新增 Boss 信号

- **负责人**：系统程序
- **工作量**：0.25 天
- **依赖**：无
- **文件**：`scripts/event_bus.gd`

**具体内容**：

在 `event_bus.gd` 中新增以下 4 个信号：

```gdscript
@warning_ignore("unused_signal")
signal boss_approach_started(boss_id: String)
@warning_ignore("unused_signal")
signal boss_activated(boss_id: String)
@warning_ignore("unused_signal")
signal boss_phase_changed(boss_id: String, phase: int)
@warning_ignore("unused_signal")
signal boss_killed(boss_id: String, position: Vector2, boss_name: String)
```

**验收标准**：Godot 编辑器无编译错误。信号可在任何节点 `connect()`。

---

### TASK-P02: BossPhaseController 创建

- **负责人**：战斗程序
- **工作量**：1.5 天
- **依赖**：DEP-01, DEP-02, TASK-P01
- **新增文件**：
  - `scripts/combat/boss_phase_controller.gd` + `.uid`
  - `scripts/resources/boss_phase_data.gd` + `.uid`

**具体内容**：

1. **创建 `BossPhaseData` (Resource)**：
```gdscript
class_name BossPhaseData
extends Resource

@export var phase_index: int = 0
@export var health_threshold: float = 1.0   # 进入此 Phase 的 HP 比例
@export var move_speed: float = 60.0
@export var defense: int = 5
@export var aura_color: Color = Color(1.0, 0.5, 0.1)
@export var aura_pulse_period: float = 0.5
@export var attack_interval_min: float = 1.5
@export var attack_interval_max: float = 2.0
@export var skill_slots: Array[int] = []     # 使用的技能槽位
@export var summon_enabled: bool = false
@export var summon_interval: float = 12.0
@export var summon_count: int = 3
@export var core_exposed: bool = false        # 核心弱点暴露
```

2. **创建 `BossPhaseController` (Node)**：
   - 挂载在 Boss CombatUnit 下
   - `var _current_phase: int = 0`
   - `var _phases: Array[BossPhaseData] = []`
   - `var _is_transitioning: bool = false`（阶段转换锁）
   
   **核心方法**：
   - `func init(phases_data: Array[BossPhaseData]) -> void` — 从数据初始化
   - `func check_transition(hp_ratio: float) -> bool` — 检查是否跨阶段，返回 true 表示触发了转换
   - `func get_current_phase() -> BossPhaseData` — 获取当前阶段数据
   - `func enter_phase(phase_index: int) -> void` — 进入新阶段（触发演出、切换技能组、更新参数）
   - `func _transition_sequence(from: int, to: int) -> void` — 阶段转换演出序列：
     - 设置 `_is_transitioning = true`
     - 调用 `CombatFeedback.big_hit_stop()` + `CombatFeedback.screen_shake(8.0)`
     - 播放转阶段视觉动画（发出信号让视觉层处理——光环变色等）
     - 锁定 0.8s → `_is_transitioning = false`
   - `func is_transitioning() -> bool` — 供 AI 和技能系统查询

**验收标准**：在测试场景中，手动降低 Boss HP 触发 `check_transition()`，阶段正确切换。`_is_transitioning` 锁正确工作。

---

### TASK-P03: Boss AI 状态机实现 — 四乐章行为

- **负责人**：战斗程序
- **工作量**：2.5 天
- **依赖**：DEP-01, DEP-03, TASK-P02
- **新增文件**：`scripts/combat/boss_ai_controller.gd` + `.uid`
- **修改文件**：`scripts/combat/ai_controller.gd`（如果需要基类改造）

**具体内容**：

创建 `BossAIController`，继承或组合 `AIController`。核心是四个乐章的行为逻辑：

**第一乐章 (CHASE + 固定循环攻击)**：
```gdscript
func _movement1_behavior(delta: float) -> void:
    # 向玩家走（速度 60px/s）
    # 维持 nav_agent 追踪玩家
    # 攻击循环：按 M1-A→M1-B→M1-C→M1-D→M1-A...固定顺序
    # 每个攻击之间间隔 2s
    # 攻击时停止移动，硬直结束后恢复移动

var _m1_attack_index: int = 0
var _m1_attack_order: Array[int] = [0, 1, 2, 3]  # 技能槽位索引

func _select_m1_attack() -> int:
    var idx := _m1_attack_order[_m1_attack_index]
    _m1_attack_index = (_m1_attack_index + 1) % _m1_attack_order.size()
    return idx
```

**第二乐章 (KITE 保持中距离 + 随机攻击池)**：
```gdscript
func _movement2_behavior(delta: float) -> void:
    # 维持 preferred_distance = 150-200px
    # 攻击选择：从 [M2-A, M2-B, M2-C, M2-D, M2-E] 权重 [0.25, 0.25, 0.2, 0.2, 0.1] 随机
    # 同一攻击不连续出现两次
    # 间隔 1.5-2s 随机

func _select_m2_attack(last_attack: int) -> int:
    var pool := [0, 1, 2, 3, 4]  # M2-A 到 M2-E
    var weights := [0.25, 0.25, 0.2, 0.2, 0.1]
    # 移除 last_attack
    # 按权重随机选择
```

**第三乐章 (CHASE + 召唤独立计时 + 混合攻击池)**：
```gdscript
var _m3_summon_timer: float = 0.0
var _m3_summon_count: int = 0   # 记录吹哨次数，第 3 次触发空哨

func _movement3_behavior(delta: float) -> void:
    # CHASE 追踪（速度 85px/s），不固定保持距离
    # 召唤计时器独立运行（每 12-15s）
    # _m3_summon_timer += delta
    # if _m3_summon_timer >= summon_interval:
    #     if _m3_summon_count == 2:  # 第 3 次（0-indexed）
    #         _trigger_empty_whistle()
    #     else:
    #         _summon_students()
    #     _m3_summon_count += 1
    # 普通攻击从 [M3-B, M3-C, M3-D] 随机
    # 场上学生 ≥ 6 时暂停召唤
```

**第四乐章 (CHASE 狂暴 + 冲刺间隔递减 + 核心暴露)**：
```gdscript
var _m4_dash_interval: float = 2.0  # 随 HP 降低递减

func _movement4_behavior(delta: float) -> void:
    # CHASE 追踪（速度 110px/s）
    # 绝望冲刺×4 (M4-A) 为主力
    # _m4_dash_interval 根据 HP 动态调整：
    #   HP<300 → 2s, HP<200 → 1.5s, HP<100 → 1s, HP<50 → 0.8s
    # 器材雨 (M4-B) CD 12s，HP<250 时优先释放
    # HP<80 (5%)：停止移动，站桩释放，核心永久暴露
```

**验收标准**：在测试场景中，Boss 从第一乐章一直打到第四乐章。所有攻击选择逻辑正确。阶段转换不卡住。

---

### TASK-P04: Boss 攻击技能实现（基于 SkillBase 体系）

- **负责人**：战斗程序
- **工作量**：3 天
- **依赖**：DEP-02, TASK-P02, TASK-P03
- **新增文件**（每个攻击一个技能类）：
  - `scripts/skills/boss/skill_m1_heavy_sweep.gd` + `.uid`
  - `scripts/skills/boss/skill_m1_whistle_wave.gd` + `.uid`
  - `scripts/skills/boss/skill_m1_roll_charge.gd` + `.uid`
  - `scripts/skills/boss/skill_m1_vault_stomp.gd` + `.uid`
  - `scripts/skills/boss/skill_m2_fastball.gd` + `.uid`
  - `scripts/skills/boss/skill_m2_lob.gd` + `.uid`
  - `scripts/skills/boss/skill_m2_whistle_shriek.gd` + `.uid`
  - `scripts/skills/boss/skill_m2_iron_shoulder.gd` + `.uid`
  - `scripts/skills/boss/skill_m2_ground_shockwave.gd` + `.uid`
  - `scripts/skills/boss/skill_m3_summon_whistle.gd` + `.uid`
  - `scripts/skills/boss/skill_m4_desperate_dash.gd` + `.uid`
  - `scripts/skills/boss/skill_m4_equipment_rain.gd` + `.uid`
  - `scripts/skills/boss/skill_m3_dash.gd` + `.uid`（M3-D 冲刺追击）

**每个技能必须实现的接口**（继承 SkillBase，覆盖以下方法）：

```gdscript
class_name SkillM1_HeavySweep
extends SkillBase

# 必须 override 的常量
const WINDUP_DURATION: float = 0.6
const RECOVERY_DURATION: float = 0.5

# 前摇阶段
func can_execute() -> bool:
    # 检查 owner_unit 非空、非死亡、非阶段转换中

# 执行（在 WINDUP 结束后调用）
func execute() -> void:
    # 1. 创建扇形检测区域
    # 2. 检测范围内的敌人（player）
    # 3. 造成伤害
    # 4. 施加击退

# 必须 emit 信号：
# windup_started(duration)
# windup_finished()
# recovery_finished()
```

**重点攻击实现细节**：

**M1-C 前滚翻冲撞**：
```gdscript
# 方向在 windup 0.5s 时锁定
# 冲刺距离 200px，速度 400px/s
# 碰撞检测：撞到墙壁 → 0.5s 额外硬直
# 撞空（到达 200px）→ 0.3s 缓冲
# 冲刺期间移动由技能控制（覆盖 AI 的移动）
```

**M2-E 震地波**：
```gdscript
# 创建 3 个同心圆形 ColorRect，从 Boss 位置向外扩散
# 第 1 波：半径 50px，0.3s 到达边缘
# 第 2 波：半径 100px，0.6s 到达边缘
# 第 3 波：半径 180px，0.9s 到达边缘
# 每波到达边缘时检测范围内的玩家并造成伤害
# 玩家可通过闪避无敌帧躲避
```

**M3-A 吹哨集合**：
```gdscript
# 前摇 1.2s：白色声波视觉（由视觉层处理）
# 释放：在屏幕边缘随机 3 个位置生成 StudentMinion
# 学生出生后自动追踪玩家（CHASE 模式）
# 学生最大同时存在数 9，超过时不召唤
```

**M4-A 绝望冲刺×4**：
```gdscript
# 连续 4 次冲刺
# for i in range(4):
#    - 锁定玩家方向（每次重新锁定）
#    - 前摇 0.4s：Boss 身体闪烁
#    - 冲刺 150px，速度 400px/s
#    - 0.2s 停顿
# 第 4 次后硬直 1.0s + 核心暴露
```

**M4-B 全屏器材雨**：
```gdscript
# CD 12s
# 前摇 1.5s：屏幕变暗 + Boss 跳至场地中央
# 释放：5 波器材从屏幕顶部落下
# 每波 3-5 个，随机 x 位置（在场地范围内）
# 每个器材落地前 0.5s 出现红色方形投影（地面预警）
# 落地造成半径 40px AOE 伤害 25
# 释放后硬直 2s + 核心暴露
```

**验收标准**：每个技能在独立测试中：前摇动画正确、伤害判定准确、硬直锁定正确、不会在阶段转换中崩溃。

---

### TASK-P05: StudentMinion 实现

- **负责人**：战斗程序
- **工作量**：0.5 天
- **依赖**：DEP-01, DEP-03
- **新增文件**：
  - `scripts/combat/student_minion.gd` + `.uid`
  - `scenes/student_minion.tscn`

**具体内容**：

继承 CombatUnit（或 Enemy），配置如下：
```gdscript
class_name StudentMinion
extends CombatUnit  # 或 Enemy（取决于 DEP-06 Enemy 迁移进度）

# 默认参数
# max_health = 15, move_speed = 140, contact_damage = 8
# team = Team.ENEMY
# 视觉: ColorRect 白色 16x24, scale 0.7
# AI: CHASE 模式（复用 AIStateMachine）
# 攻击前摇 0.35s, 攻击硬直 0.2s
```

**特殊行为**：
- `func dissipate() -> void` — 停住 + modulate.a→0 + scale→0.5，0.5s 后 queue_free。无粒子。
- `func on_boss_phase_4() -> void` — 连接 Boss 阶段转换信号，收到后调用 dissipate()
- `func on_boss_death() -> void` — 连接 Boss 死亡信号，收到后调用 dissipate()

**验收标准**：学生小怪可以正常追踪玩家、造成伤害、被击杀。dissipate() 动画正确。Boss 阶段转换/死亡时自动消散。

---

### TASK-P06: Boss 登场序列实现

- **负责人**：系统程序 + 战斗程序
- **工作量**：1.5 天
- **依赖**：DEP-01, DEP-05, TASK-P02
- **修改文件**：
  - `scripts/game_manager.gd` — 修改 `_on_boss_spawn()` 或新增信号处理
  - `scripts/mission_manager.gd` — 修改 Stage 3 激活逻辑

**具体内容**：

1. **修改 `mission_manager.gd`**：
   - Stage 3 激活时不再立即发出 `boss_spawned`
   - 改为发出 `boss_approach_started("sato")`
   - 新增 `zone_gym_boss` 进入检测 → 触发 `boss_activated("sato")`

2. **修改 `game_manager.gd` — 新增 `_on_boss_approach_started()`**：
```gdscript
func _on_boss_approach_started(boss_id: String) -> void:
    # 1. MissionPromptUI: 显示"前往体育馆" + 方向箭头
    # 2. 不冻结游戏
    # 3. 敌人继续正常刷新
    
func _on_player_entered_gym_boss() -> void:
    # 1. 暗角开始 15s 渐变 (alpha 0→0.3)
    #    - 使用现有 _low_hp_overlay 的技术路径
    #    - 或新建 vignette_overlay (TextureRect)
    # 2. 30s 接近时间开始
    #    - _approach_timer = 30.0
    # 3. Boss 实体提前实例化（潜伏姿态）:
    #    var boss := _boss_scene.instantiate()
    #    boss.global_position = Vector2(1400, 380)
    #    boss.modulate.a = 0.3
    #    boss.process_mode = PROCESS_MODE_DISABLED
    #    boss._set_crouch_pose()  # Body.scale.y = 0.5
    #    enemies.add_child(boss)
    #    _pending_boss = boss
    # 4. 方向箭头指向 Boss 位置
```

3. **触发沉默时刻**（玩家进入 Boss 150px 内或 30s 计时结束）：
```gdscript
func _trigger_silence_moment() -> void:
    # 1. 发出信号: EventBus.boss_activated.emit("sato")
    # 2. 沉默时刻 HUD 消退（由交互层处理——见 GAP-01b）
    # 3. 2-3s 后 Boss 激活:
    #    _pending_boss.process_mode = PROCESS_MODE_INHERIT
    #    _pending_boss.activate()  # 光环首次亮起 + 进入第一乐章
    #    _pending_boss = null
```

**关键约束**：
- 全程不调用 `get_tree().paused = true`
- 不使用对话面板（废除现有 `_on_boss_spawn` 的对话冻结逻辑）
- Boss 实体在潜伏期间不消耗 AI 性能（`process_mode = PROCESS_MODE_DISABLED`）

**验收标准**：玩家从 Stage 3 激活到 Boss 战开始的完整流程：看到提示→进入体育馆→暗角渐变→普通敌人刷新→接近 Boss→沉默时刻→Boss 苏醒→战斗开始。无冻结。无对话弹窗。

---

### TASK-P07: Boss 终结序列实现

- **负责人**：战斗程序 + 系统程序
- **工作量**：1 天
- **依赖**：TASK-P04, TASK-P05, DEP-05
- **修改文件**：`scripts/game_manager.gd`

**具体内容**：

在 `game_manager.gd` 中新增 `_on_boss_killed()`：

```gdscript
func _on_boss_killed(boss_id: String, position: Vector2, boss_name: String) -> void:
    # 1. Big Hit Stop (复用 CombatFeedback.big_hit_stop())
    # 2. Boss 体色变灰白（由美术层处理，通过信号触发）
    # 3. 0.1s 后坍塌 Tween 开始（由美术层处理）
    # 4. 所有学生小怪 dissipate（发出信号）
    # 5. 0.8s 后金色粒子（复用 CombatFeedback.kill_explosion，改颜色参数）
    #    新建 CombatFeedback.boss_kill_explosion(position) —— 24+16 金色粒子
    # 6. 1.0s 后胜利文字淡入（由交互层处理——见 GAP-01b）
    # 7. 1.5s 后暗角消退
    # 8. 2.0s 后 Stage Complete 提示（已有系统）
    # 9. 3.0s 后:
    #    - Boss 节点 queue_free()
    #    - 门解锁
    #    - 地图 Boss 房间标记已探索
    #    - 检查是否有累积升级 → 弹出升级面板（延迟弹出逻辑）
```

**注意**：Boss 死亡不通过 `_die()` 触发普通 `enemy_killed` 信号。修改 `enemy.gd` 中 `_die()` 的判断逻辑（或覆盖 Boss 的 `_die()`），使其发出 `boss_killed` 而非 `enemy_killed`。

**验收标准**：Boss HP 归零后终结序列完整执行。坍塌动画流畅。学生消散。金色粒子规模和颜色正确。胜利文字出现。后续系统正常接管。

---

### TASK-P08: Boss HP 条 UI（屏幕顶部）

- **负责人**：系统程序
- **工作量**：0.5 天
- **依赖**：DEP-01, TASK-P02
- **修改文件**：`scripts/game_manager.gd`（或在 HUD 层新建 `boss_hp_bar.gd`）

**具体内容**：

1. **创建 Boss HP 条节点**（在 HUDLayer 下）：
```gdscript
# BossHealthBar (ProgressBar)
# - 位置：屏幕顶部中央
# - 尺寸：屏幕宽度的 60%（约 720px 宽，16px 高）
# - 颜色：红色底色 + 深红前景
# - 减少动画：0.3s 平滑 Tween（不是瞬间跳变）
# - 默认 visible = false，Boss 激活时显示
```

2. **三个阶段标记线**：
   - 在 ProgressBar 75%/50%/25% 位置绘制竖线标记
   - 用 3 个小的 ColorRect 作为标记线

3. **连接信号**：
   - `boss_activated` → 显示 HP 条
   - Boss `damage_taken` → 更新 HP 条值（带 0.3s Tween 平滑）
   - `boss_killed` → 隐藏 HP 条

**验收标准**：Boss 激活时 HP 条从屏幕顶部出现。受击时平滑减少。阶段标记线清晰可见。Boss 死亡后消失。

---

### TASK-P09: Boss 战场地实现

- **负责人**：关卡程序
- **工作量**：1 天
- **依赖**：无（独立于其他 Boss 任务）
- **修改/新增文件**：
  - `scripts/destructible.gd`（已存在，可能需要扩展）
  - 或在 `school_map.gd` 中新增体育馆区域配置

**具体内容**：

在体育馆区域（世界坐标约 1200-1600, 200-600 范围）放置障碍物：

1. **篮球架（2 个）**：`StaticBody2D` + ColorRect
   - 位置：(1280, 350), (1520, 350)
   - 尺寸：14x80
   - 颜色：`Color(0.3, 0.3, 0.35)`
   - 碰撞层：与墙壁相同
   - 特殊：子弹碰撞到此对象时触发反弹（Phase 2 哨声尖啸弹幕）

2. **跳马箱（2 个）**：复用 `destructible.gd`
   - 位置：(1350, 500), (1450, 500)
   - 尺寸：40x30
   - HP = 60
   - 可被玩家攻击和 Boss 攻击破坏
   - 破坏后消失（不重生）

3. **体操垫（2 个）**：`Area2D` + ColorRect
   - 位置：(1300, 280), (1500, 280)
   - 尺寸：50x12
   - 颜色：`Color(0.15, 0.35, 0.15)`
   - 进入范围的单位获得 `speed_mult = 0.7` 减速
   - Boss 免疫此减速

4. **门锁逻辑**：
   - 场地南侧入口（y≈600）在 Boss 激活后"锁上"
   - 实现：在入口处放置一个不可通过的 StaticBody2D（或 TileMap 碰撞层动态修改）
   - Boss 死亡后移除

**验收标准**：障碍物位置正确。篮球架阻挡弹幕。跳马箱可破坏。体操垫减速生效。Boss 不减速。门锁/解锁正确。

---

### TASK-P10: 战后升级延迟弹出

- **负责人**：系统程序
- **工作量**：0.5 天
- **依赖**：TASK-P07
- **修改文件**：`scripts/game_manager.gd`

**具体内容**：

修改 `_on_level_up_available()` 和 `_show_upgrade_panel()` 逻辑：

```gdscript
var _boss_fight_active: bool = false
var _pending_boss_upgrades: int = 0

func _on_level_up_available(_count: int) -> void:
    if _boss_fight_active:
        # Boss 战中：只累积计数，不弹出面板
        _pending_boss_upgrades += 1
        return
    # 正常流程
    await get_tree().create_timer(0.15).timeout
    _show_upgrade_panel()

func _on_boss_killed(...) -> void:
    # ... 终结序列 ...
    # 终结序列结束后 (t=3.0s)
    if _pending_boss_upgrades > 0:
        _boss_fight_active = false
        # 取得 Boss 倒下位置的屏幕坐标
        var screen_pos := _get_boss_death_screen_pos()
        # 第一个面板从 Boss 位置绽放
        _show_boss_upgrade_panel(screen_pos, _pending_boss_upgrades)
```

**第一个升级面板特化**：
- 面板标题："佐藤的馈赠"（不是"升级！"）
- 面板初始 scale 从 Boss 倒下屏幕坐标位置开始（需要 world→screen 坐标转换）
- 15% 概率第四选项"哨声"

**验收标准**：Boss 战中击杀学生升级不会弹出面板。Boss 死后连续弹出累积面板。第一个面板标题和入场位置正确。

---

### TASK-P11: Boss 遭遇次数持久化

- **负责人**：系统程序
- **工作量**：0.25 天
- **依赖**：TASK-P07
- **修改文件**：`scripts/game_state.gd`

**具体内容**：

在 `GameState` 单例中新增字段和方法：
```gdscript
# game_state.gd
var boss_encounter_count: int = 0

func increment_boss_encounter() -> void:
    boss_encounter_count += 1

func get_boss_ritual_level() -> int:
    # 返回仪式感递减级别
    if boss_encounter_count <= 0: return 1   # 第一次
    elif boss_encounter_count <= 2: return 2 # 第 2-3 次
    elif boss_encounter_count <= 4: return 3 # 第 4-5 次
    else: return 4                           # 第 6+ 次
```

在玩家 Boss 战中死亡时：`GameState.increment_boss_encounter()`

在 Boss 登场序列读取仪式感级别，调整接近时间/沉默时刻/动画速度。

**验收标准**：`boss_encounter_count` 正确递增。重开游戏后重置为 0（当前不实现存档）。

---

### TASK-P12: Boss 战中玩家死亡处理

- **负责人**：系统程序
- **工作量**：0.5 天
- **依赖**：TASK-P11
- **修改文件**：`scripts/game_manager.gd`（`_on_player_died()` 方法）

**具体内容**：

修改 `_on_player_died()` 方法，在原有 Game Over 逻辑中增加分支判断：

```gdscript
func _on_player_died() -> void:
    # ... 原有停止 spawn/wave timer 逻辑 ...
    
    # 判断是否在 Boss 战中死亡
    var is_boss_death: bool = _boss_fight_active
    
    if is_boss_death:
        # 1. 递增遭遇次数
        GameState.increment_boss_encounter()
        # 2. Game Over 面板使用特殊文字
        #    final_score_label 或新建一个 boss_death_hint_label
        #    显示："体育课还没下课..."
        # 3. 清理 Boss 相关状态
        _boss_fight_active = false
        _pending_boss_upgrades = 0
        # 4. 清理所有学生小怪
        _clear_all_student_minions()
        # 5. 暗角重置
        _reset_vignette()
    
    # ... 原有 Game Over 面板显示逻辑 ...
```

**注意**：Game Over 面板文字修改需要在 `game_over_panel` 的 Title 或 FinalScore 中动态设置。

**验收标准**：在 Boss 战中死亡 → Game Over 面板显示"体育课还没下课..."。按 W 重开 → 回到角色选择。下次进入 Boss 战时仪式感递减生效。

---

## 依赖关系图

```
DEP-01 (CombatUnit) ──┬── TASK-P02 (BossPhaseController) ──┬── TASK-P04 (Boss技能)
                      │                                     │
DEP-02 (SkillBase)  ──┤                                     ├── TASK-P03 (BossAI)
                      │                                     │
DEP-03 (AIController)─┤                                     ├── TASK-P06 (登场序列)
                      │                                     │
DEP-04 (NavManager)  ──┘                                     ├── TASK-P07 (终结序列)
                                                             │
TASK-P01 (EventBus信号) ─────────────────────────────────────┤
                                                             │
TASK-P05 (StudentMinion) ── DEP-01 ──────────────────────┬──┘
                                                          │
TASK-P08 (BossHP条) ── DEP-01, TASK-P02                  │
                                                          │
TASK-P09 (战场地) ── 独立                                 │
                                                          │
TASK-P10 (战后升级) ── TASK-P07                          │
TASK-P11 (遭遇次数) ── TASK-P07                          │
TASK-P12 (死亡处理) ── TASK-P11                          │
```

---

## 工时汇总

| 任务 | 负责人 | 工时（天） |
|------|--------|-----------|
| TASK-P01 EventBus 信号 | 系统程序 | 0.25 |
| TASK-P02 BossPhaseController | 战斗程序 | 1.5 |
| TASK-P03 Boss AI 状态机 | 战斗程序 | 2.5 |
| TASK-P04 Boss 攻击技能（13 个） | 战斗程序 | 3.0 |
| TASK-P05 StudentMinion | 战斗程序 | 0.5 |
| TASK-P06 Boss 登场序列 | 系统程序 + 战斗程序 | 1.5 |
| TASK-P07 Boss 终结序列 | 战斗程序 + 系统程序 | 1.0 |
| TASK-P08 Boss HP 条 UI | 系统程序 | 0.5 |
| TASK-P09 Boss 战场地 | 关卡程序 | 1.0 |
| TASK-P10 战后升级延迟 | 系统程序 | 0.5 |
| TASK-P11 遭遇次数持久化 | 系统程序 | 0.25 |
| TASK-P12 死亡处理 | 系统程序 | 0.5 |
| **总计** | | **~13 天** |

> 工时按单人专职估算。如多人并行，关键路径约 7-8 天。
> 不含前置依赖 DEP-01~DEP-05 的实施时间（这些属于战斗框架迁移阶段）。
