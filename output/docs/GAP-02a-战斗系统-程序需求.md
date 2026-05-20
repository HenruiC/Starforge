# GAP-02a 战斗系统 -- 程序需求

> 宫崎英高 (Hidetaka Miyazaki), Starforge 战斗设计顾问
> 2026-05-19
> 输入文档: `战斗系统设计-宫崎英高.md` (5.1~5.4, 6.1~6.7)
> 不冲突: GAP-01 (小岛正在写 Boss 合并设计，本文档不涉及 Boss 专属攻击参数，只给接口)

---

## 需求 1: 攻击前摇系统 (Attack Windup System)

### 背景
当前 `SkillBase.try_execute()` 调用后立即执行 `execute()` -- 没有前摇阶段。敌人没有"告诉我即将攻击"的机会。玩家无法阅读敌人意图。

### 改造范围

#### 1.1 SkillBase.gd 改造

**文件**: `scripts/skills/skill_base.gd`

新增内容:

```gdscript
# === 攻击阶段信号 ===
signal windup_started(duration: float)      # 前摇开始，参数=前摇总时长
signal windup_ended()                       # 前摇结束，即将进入伤害帧
signal recovery_started(duration: float)    # 硬直开始
signal recovery_ended()                     # 硬直结束，攻击流程完成

# === 前摇/硬直参数 ===
var _windup_duration: float = 0.35          # 前摇时间 (默认近战轻击)
var _recovery_duration: float = 0.2         # 硬直时间
var _is_windup: bool = false                # 是否在前摇中
var _is_recovery: bool = false              # 是否在硬直中
var _is_active_frame: bool = false          # 是否在伤害帧中
```

修改 `try_execute()`:

```gdscript
func try_execute() -> bool:
	if not is_ready: return false
	if not can_execute(): return false
	if _is_windup or _is_recovery: return false   # 新增：不重复进入
	is_ready = false
	cooldown_remaining = cooldown

	# 前摇阶段
	_is_windup = true
	windup_started.emit(_windup_duration)
	await get_tree().create_timer(_windup_duration).timeout
	_is_windup = false
	windup_ended.emit()

	# 伤害帧
	_is_active_frame = true
	execute()
	_is_active_frame = false

	# 硬直阶段
	_is_recovery = true
	recovery_started.emit(_recovery_duration)
	await get_tree().create_timer(_recovery_duration).timeout
	_is_recovery = false
	recovery_ended.emit()

	_trigger_feedback()
	return true
```

**注意**: `await` 将 `try_execute()` 变为协程。SkillComponent 的 `process_all()` 需要适配 -- 见下。

#### 1.2 SkillComponent 适配

**文件**: `scripts/combat/skill_component.gd` (待创建，来自统一战斗框架 Phase 1)

```gdscript
func try_execute_skill(index: int) -> bool:
	if index < 0 or index >= skills.size(): return false
	var skill := skills[index]
	if skill.is_ready and not skill._is_windup and not skill._is_recovery:
		skill.try_execute()  # 不 await -- 协程在后台跑
		return true
	return false
```

`process_all()` 不需要修改 -- CD tick 在 `_process` 中仍然正常，只是不重复 `try_execute` (因为 `is_ready = false` 已经设置了)。

#### 1.3 Enemy AI 对接前摇信号

**文件**: `scripts/enemy.gd` (或 `scripts/combat/ai_controller.gd`)

AI 在前摇/硬直期间的行为控制:

```gdscript
# 在 Enemy 初始化时连接技能信号
func _connect_skill_signals(skill_component: SkillComponent) -> void:
	for skill in skill_component.skills:
		skill.windup_started.connect(_on_attack_windup_start)
		skill.windup_ended.connect(_on_attack_windup_end)
		skill.recovery_ended.connect(_on_attack_recovery_end)

func _on_attack_windup_start(duration: float) -> void:
	# 前摇期间移速降低到 20%，不发起新攻击
	_windup_speed_mult = 0.2
	_can_start_new_attack = false
	# 视觉：身体后仰/颜色渐变由视觉状态机处理

func _on_attack_windup_end() -> void:
	# 伤害帧瞬间 -- 短暂速度归零
	_windup_speed_mult = 0.0

func _on_attack_recovery_end() -> void:
	# 硬直结束，恢复移动和攻击能力
	_windup_speed_mult = 1.0
	_can_start_new_attack = true

# _physics_process 中：
var effective_speed := move_speed * _windup_speed_mult
```

#### 1.4 现有技能子类兼容

所有 9 个 SkillBase 子类的 `execute()` 方法**不需要改动** -- 前摇/硬直由基类 `try_execute()` 统一处理，子类的 `execute()` 仍然是纯伤害逻辑。但视觉逻辑需要检查：如果子类的 `execute()` 中有闪光效果，那些效果应该保留（伤害帧的视觉确认）。

### 工作量
| 子任务 | 工时 | 涉及文件 |
|--------|------|---------|
| 1.1 SkillBase 前摇/硬直改造 | 1d | `scripts/skills/skill_base.gd` |
| 1.2 SkillComponent 适配 | 0.25d | `scripts/combat/skill_component.gd` |
| 1.3 Enemy AI 对接信号 | 0.5d | `scripts/enemy.gd` 或 `ai_controller.gd` |
| 1.4 现有技能回归测试 | 0.5d | 全 9 个技能子类 |
| **合计** | **2.25d** | |

### 优先级: **P0**

---

## 需求 2: 敌人视觉状态机 (Enemy Visual State Machine)

### 背景
当前敌人只有一个 `sprite.color` 属性，被多个逻辑随意改写（精英=紫色、Boss=暗红、受击=白色闪、射击=绿色闪）。需要将视觉行为收敛到统一状态机，让颜色始终传递**正确且不冲突**的信息。

### 设计

#### 2.1 架构: 独立组件 `EnemyVisualState`

**文件**: `scripts/combat/enemy_visual_state.gd` (新建)

```gdscript
class_name EnemyVisualState
extends Node

## 挂在 Enemy 或 CombatUnit 下，管理所有视觉状态

enum VisualState {
	NORMAL,         # 默认外观
	WINDUP,         # 攻击蓄力中 (颜色渐变到橙黄)
	ACTIVE_FRAME,   # 伤害帧 (闪光)
	RECOVERY,       # 攻击后硬直 (颜色恢复中)
	STUNNED,        # 被控/冻结 (蓝色)
	LOW_HP,         # 低血量 (颜色变暗 + 粒子)
	BERSERK,        # 狂暴 (红色脉冲)
	STEALTH,        # 潜伏 (alpha 降低)
	DEAD,           # 死亡 (颜色变灰 + 缩放出局)
}

var _current_state: VisualState = VisualState.NORMAL
var _state_stack: Array[VisualState] = []   # 状态栈 -- 高优先级盖低优先级
var _sprite: ColorRect
var _glow_rect: ColorRect = null
var _pending_tweens: Array[Tween] = []
```

#### 2.2 状态优先级 (栈模型)

高优先级状态可以覆盖低优先级的外观。栈顶 = 当前最高优先级。

```
优先级从高到低:
8. DEAD          (最高 -- 覆盖一切)
7. STUNNED       (蓝色闪烁)
6. ACTIVE_FRAME  (伤害帧白色闪光，极短)
5. WINDUP        (橙黄渐变)
4. BERSERK       (红色脉冲)
3. LOW_HP        (颜色变暗)
2. RECOVERY      (颜色恢复中)
1. STEALTH       (alpha 降低)
0. NORMAL        (默认)
```

#### 2.3 与 AI 行为模式的关系

`EnemyVisualState` 是**独立组件**，不嵌入 AIStateMachine。理由是：
- AI 行为模式决定"做什么" (CHASE/KITE/FLEE...)
- 视觉状态决定"怎么显示" (颜色/alpha/粒子)
- 它们是**正交维度** -- 同一个 CHASE 行为的敌人可以处于 NORMAL/WINDUP/RECOVERY/LOW_HP 不同视觉状态
- 如果视觉逻辑嵌入 AI 状态机，会产生 M x N 的组合爆炸 (9 种 AI x 9 种视觉 = 81 种组合要维护)

耦合点：AI 状态机**通知**视觉状态机发生的行为变化，视觉状态机自己决策显示什么。

```gdscript
# AI 侧
signal behavior_changed(old_behavior: int, new_behavior: int)
signal attack_phase_changed(phase: String)  # "windup" / "active" / "recovery"

# 视觉侧监听这些信号，推入/弹出状态栈
func _on_behavior_changed(_old: int, new: int) -> void:
	match new:
		AIState.AMBUSH:
			push_state(VisualState.STEALTH)
		AIState.FLEE:
			push_state(VisualState.LOW_HP)
		_:
			# CHASE/KITE/PATROL 等恢复 NORMAL
			clear_to_normal()
```

#### 2.4 状态转换的视觉参数

每个状态定义: `modulate` 目标颜色、过渡时长、附加效果。

| VisualState | modulate 颜色 | 过渡 | 附加效果 |
|-------------|-------------|------|---------|
| NORMAL | 默认颜色 (近战#8B7355 / 远程暗绿) | - | - |
| WINDUP | 从 NORMAL 渐变到橙黄 #FF8C00 | 与 _windup_duration 同步 | 身体后仰 (scale.y 压缩) 由独立 Tween 控制 |
| ACTIVE_FRAME | 纯白 #FFFFFF | 瞬间切 (0s) | 闪光持续 0.05s 后自动 pop |
| RECOVERY | 从 WINDUP 颜色渐变回 NORMAL | 与 _recovery_duration 同步 | - |
| STUNNED | 蓝色 #4488FF + alpha 脉冲 | 0.1s 过渡到蓝色 | 冻结粒子 (小冰晶方块) |
| LOW_HP | NORMAL 颜色 + modulate:a * 0.7 | 0.3s | 红色粒子从身体渗出 |
| BERSERK | 红色 #FF2020 + alpha 脉冲(周期 0.5s) | 0.2s | 光环放大 |
| STEALTH | NORMAL 颜色 + modulate:a = 0.35 | 0.3s | 每 3s 微脉冲(alpha 0.3→0.4→0.3) |
| DEAD | 灰色 #808080 + modulate:a → 0 | 0.3s | scale 增大 1.3x |

#### 2.5 push_state / pop_state 实现

```gdscript
func push_state(state: VisualState, duration: float = -1.0) -> void:
	# duration > 0 表示自动在 duration 后 pop (如 ACTIVE_FRAME 自动出栈)
	_state_stack.append(state)
	_apply_state(state)
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(
			func(): pop_state(state))

func pop_state(expected: VisualState) -> void:
	var idx := _state_stack.rfind(expected)
	if idx >= 0:
		_state_stack.remove_at(idx)
	_apply_state(_state_stack.back() if _state_stack.size() > 0 else VisualState.NORMAL)

func _apply_state(state: VisualState) -> void:
	# kill 现有颜色 Tween
	for tw in _pending_tweens:
		if tw and tw.is_valid(): tw.kill()
	_pending_tweens.clear()

	var cfg := _STATE_CONFIG[state]
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", cfg.color, cfg.transition_time)
	_pending_tweens.append(tw)
	# 附加效果 (脉冲/粒子等) 单独处理
	match state:
		VisualState.STEALTH:
			_start_stealth_pulse()
		VisualState.BERSERK:
			_start_berserk_pulse()
```

### 工作量
| 子任务 | 工时 | 涉及文件 |
|--------|------|---------|
| 2.1 EnemyVisualState 类创建 | 1d | `scripts/combat/enemy_visual_state.gd` |
| 2.2 Enemy 集成视觉状态机 | 0.5d | `scripts/enemy.gd` |
| 2.3 与 AIStateMachine 信号对接 | 0.25d | `scripts/combat/ai_controller.gd` |
| 2.4 9 种状态视觉测试 | 0.5d | 独立测试场景 |
| **合计** | **2.25d** | |

### 优先级: **P0**

---

## 需求 3: AI 组件化 -- AIBehaviorController 挂载 CombatUnit

### 背景
当前敌人 AI 硬编码在 `enemy.gd` 的 `_physics_process` 中 (`_melee_behavior` / `_ranged_behavior`)。需要改为独立组件 `AIBehaviorController`，挂载在 CombatUnit 下，通过配置驱动。

### 设计

#### 3.1 架构

```
CombatUnit (CharacterBody2D)
  ├── StatsComponent
  ├── SkillComponent
  ├── BuffComponent
  ├── EnemyVisualState         ← 需求 2
  └── AIBehaviorController      ← 本需求
		├── AIBehaviorConfig (.tres)  ← 参数配置
		├── AIPerception              ← 感知模块
		└── AIBehavior (current)      ← 行为实例
```

#### 3.2 AIBehaviorController 主类

**文件**: `scripts/combat/ai_behavior_controller.gd` (新建)

```gdscript
class_name AIBehaviorController
extends Node

signal behavior_changed(old_behavior: int, new_behavior: int)
signal attack_phase_changed(phase: String)  # "windup", "active", "recovery", "idle"

@export var config: AIBehaviorConfig

var _unit: CombatUnit
var _perception: AIPerception
var _current_behavior: int = -1    # AIBehaviorMode 枚举值
var _behavior_elapsed: float = 0.0
var _decision_timer: float = 0.0
var _path_update_timer: float = 0.0
var _nav_agent: NavigationAgent2D = null

# 群组协调相关
var _attack_phase: float = 0.0     # 攻击相位随机偏移 [0, 1)
var _is_in_attack_queue: bool = false
var _attack_cooldown_remaining: float = 0.0

func setup(unit: CombatUnit) -> void:
	_unit = unit
	_perception = AIPerception.new()
	_perception.setup(unit, config.detection_range)
	_attack_phase = randf()  # 随机相位偏移
	_setup_navigation()
	_enter_behavior(config.preferred_behavior)

func _process(delta: float) -> void:
	if _unit.is_dead: return
	_behavior_elapsed += delta
	_perception.update(delta)
	_decision_timer += delta
	if _decision_timer >= config.decision_interval:
		_decision_timer = 0.0
		_evaluate_transition()
	_tick_behavior(delta)
```

#### 3.3 AI 行为实现方式 -- enum + switch (马斯克建议)

采用 enum + switch 状态机，不为每个行为创建独立类文件。MVP 阶段优先交付，后续可按宫崎方案重构为类继承体系。

```gdscript
func _tick_behavior(delta: float) -> void:
	match _current_behavior:
		AIBehaviorMode.CHASE:  _tick_chase(delta)
		AIBehaviorMode.KITE:   _tick_kite(delta)
		AIBehaviorMode.AMBUSH: _tick_ambush(delta)
		AIBehaviorMode.PATROL: _tick_patrol(delta)
		AIBehaviorMode.GUARD:  _tick_guard(delta)
		AIBehaviorMode.FLEE:   _tick_flee(delta)
		AIBehaviorMode.STUNNED:return  # 不做任何事
		AIBehaviorMode.RETURN: _tick_return(delta)
		_: pass  # IDLE
```

每个 `_tick_xxx` 函数实现宫崎文档 (3.2 节) 中定义的详细行为逻辑，包括：
- 移动策略 (速度/距离/方向)
- 攻击时机判断 (基于技能冷却 + 攻击相位偏移)
- 群组行为 (排队/等待)

#### 3.4 AIBehaviorConfig 资源

**文件**: `scripts/resources/ai_behavior_config.gd` (新建)

参数与宫崎文档 (6.5 节) 一致，补充群组协调参数:

```gdscript
class_name AIBehaviorConfig
extends Resource

@export var preferred_behavior: int = 0   # AIBehaviorMode
@export var detection_range: float = 250.0
@export var decision_interval: float = 0.1

# CHASE
@export var chase_speed_mult: float = 1.0
@export var melee_range: float = 45.0
@export var leash_range: float = 400.0

# KITE
@export var preferred_distance: float = 180.0
@export var kite_speed_mult: float = 0.6

# AMBUSH
@export var ambush_trigger_distance: float = 60.0
@export var ambush_bonus_mult: float = 1.5

# FLEE
@export var flee_health_ratio: float = 0.2
@export var flee_speed_mult: float = 1.3
@export var flee_timeout: float = 5.0

# GUARD
@export var guard_position: Vector2
@export var guard_radius: float = 60.0
@export var guard_leash: float = 200.0

# PATROL
@export var patrol_path: Array[Vector2] = []
@export var patrol_wait_time: float = 1.0
@export var patrol_vision_angle: float = 120.0
@export var patrol_vision_range: float = 180.0

# 群组协调
@export var enable_group_coordination: bool = true
@export var max_simultaneous_attackers: int = 2
```

#### 3.5 与现有 enemy.gd 的整合

`enemy.gd` 保留 `is_ranged / is_elite / is_boss` bool 标记但标记 deprecated。`_ready()` 中:

```gdscript
func _ready() -> void:
	_health = max_health
	_update_hp()

	if is_elite: _setup_elite()
	if is_boss: _setup_boss()

	# 旧标记转换为新配置
	var ai_cfg := _build_behavior_config()
	_ai_controller = AIBehaviorController.new()
	_ai_controller.config = ai_cfg
	_ai_controller.setup(self)   # self 最终会是 CombatUnit
	add_child(_ai_controller)

	# 初始化视觉状态机
	_visual_state = EnemyVisualState.new()
	_visual_state.setup(sprite, glow_rect)
	add_child(_visual_state)
	_ai_controller.behavior_changed.connect(_visual_state._on_behavior_changed)
	_ai_controller.attack_phase_changed.connect(_visual_state._on_attack_phase_changed)
```

`_physics_process` 中**不再包含行为逻辑** -- 只处理 AI 设置的 velocity 执行:

```gdscript
func _physics_process(delta: float) -> void:
	if is_dead: return
	# AIBehaviorController 在 _process 中设置了 velocity 和 move_target
	# 这里只执行移动
	if _ai_controller:
		_ai_controller._process(delta)
	# velocity 由 AI 设置，move_and_slide 在此执行
	move_and_slide()
```

### 工作量
| 子任务 | 工时 | 涉及文件 |
|--------|------|---------|
| 3.1 AIBehaviorController 类 | 1.5d | `scripts/combat/ai_behavior_controller.gd` |
| 3.2 AIPerception 类 | 0.5d | `scripts/combat/ai_perception.gd` |
| 3.3 AIBehaviorConfig 资源 | 0.25d | `scripts/resources/ai_behavior_config.gd` |
| 3.4 9 种行为模式 tick 实现 | 2d | `scripts/combat/ai_behavior_controller.gd` (同上) |
| 3.5 Enemy 整合迁移 | 1d | `scripts/enemy.gd` |
| **合计** | **5.25d** | |

### 优先级: **P0** (阶段二~三，与 CombatUnit 迁移同步)

---

## 需求 4: 群组协调 -- AttackCoordinator 单例

### 背景
宫崎文档 (5.3 节) 定义了三条群组协调规则:
1. 同一帧攻击者不超过 3 个 (实际建议 2 个)
2. 攻击队列: 超过 2 个时第 3 个在 60px 外等待
3. 远程优先攻击"没有被近战敌人纠缠的玩家位置"

### 设计

#### 4.1 AttackCoordinator 单例

**文件**: `scripts/combat/attack_coordinator.gd` (新建, Autoload)

```gdscript
class_name AttackCoordinator
extends Node

## 全局 Autoload, 协调所有敌人的攻击时序

const MAX_SIMULTANEOUS_MELEE_ATTACKERS := 2
const MELEE_ATTACK_RADIUS := 45.0          # 判断"正在攻击玩家"的距离
const QUEUE_DISTANCE := 60.0               # 排队等待距离

var _active_attackers: Array[CombatUnit] = []    # 当前在前摇/伤害帧的近战敌人
var _attack_queue: Array[CombatUnit] = []         # 等待中的近战敌人
var _player_pos: Vector2 = Vector2.ZERO

func register_attack(unit: CombatUnit) -> bool:
	## 敌人请求开始攻击。返回 true = 允许，false = 排队等待
	if _active_attackers.size() < MAX_SIMULTANEOUS_MELEE_ATTACKERS:
		_active_attackers.append(unit)
		return true
	else:
		_attack_queue.append(unit)
		return false

func finish_attack(unit: CombatUnit) -> void:
	## 敌人攻击结束 (进入 RECOVERY 时调用)
	_active_attackers.erase(unit)
	_dequeue_next()

func cancel_attack(unit: CombatUnit) -> void:
	## 敌人被中断 (受击/死亡/眩晕)
	_active_attackers.erase(unit)
	_attack_queue.erase(unit)

func _dequeue_next() -> void:
	if _attack_queue.size() == 0: return
	if _active_attackers.size() >= MAX_SIMULTANEOUS_MELEE_ATTACKERS: return
	var next_unit := _attack_queue.pop_front()
	_active_attackers.append(next_unit)
	# 通知该单位可以开始攻击
	if next_unit.get_node_or_null("AIBehaviorController"):
		var ai := next_unit.get_node("AIBehaviorController") as AIBehaviorController
		ai._notify_attack_granted()

func get_queue_position(unit: CombatUnit) -> int:
	## 返回排队位置 (0=下一个), -1=不在队列中
	return _attack_queue.find(unit)

func is_player_under_melee_pressure() -> bool:
	return _active_attackers.size() >= 1

func get_player_engaged_melee_count() -> int:
	return _active_attackers.size()
```

#### 4.2 AIBehaviorController 中的群组协调逻辑

在 `_tick_chase()` 中:

```gdscript
func _tick_chase(delta: float) -> void:
	var target := _perception.get_primary_target()
	if target == null:
		_unit.stop_moving()
		return

	var dist := _unit.global_position.distance_to(target.global_position)

	if dist > config.melee_range:
		# 追击阶段 -- 移速随机差异 (0.85~1.15), 防止所有敌人同时到达
		var speed_var := 0.85 + _attack_phase * 0.3
		_unit.set_move_target(target.global_position)
		_unit.effective_speed_mult = config.chase_speed_mult * speed_var
		return

	# 到达近战范围
	var coordinator := AttackCoordinator.get_instance()

	if dist < MELEE_ATTACK_RADIUS / 2.0:
		# 已经在"攻击位"
		if coordinator.register_attack(_unit):
			_try_start_melee_attack()
		else:
			# 排队 -- 停在 60px 外等待
			_hold_position_at_distance(target.global_position, QUEUE_DISTANCE)
	else:
		# 靠近但不够近 -- 进入攻击位置
		_unit.set_move_target(target.global_position)
		_unit.effective_speed_mult = 0.5  # 慢速逼近

func _try_start_melee_attack() -> void:
	_attack_cooldown_remaining -= delta
	if _attack_cooldown_remaining <= 0 and _unit.try_use_skill(0):
		_attack_cooldown_remaining = _unit.get_skill_cooldown(0)
		# 注册攻击相位偏移
		_attack_cooldown_remaining += _attack_phase * 0.15  # ±0.15s 偏移

func _hold_position_at_distance(target_pos: Vector2, dist: float) -> void:
	var dir := _unit.global_position.direction_to(target_pos)
	var hold_pos := target_pos - dir * dist
	# 微小幅偏移，避免排队敌人叠在一起
	hold_pos += Vector2(randf_range(-15, 15), randf_range(-15, 15))
	_unit.set_move_target(hold_pos)
```

#### 4.3 远程敌人配合近战

在 `_tick_kite()` 中:

```gdscript
func _tick_kite(delta: float) -> void:
	var coordinator := AttackCoordinator.get_instance()
	# 如果玩家正在被近战敌人纠缠，远程敌人调整行为
	if coordinator.is_player_under_melee_pressure():
		_preferred_distance_actual = config.preferred_distance * 0.7  # 缩短 30%
		_fire_rate_mult = 1.2  # 射速 +20%
	else:
		_preferred_distance_actual = config.preferred_distance
		_fire_rate_mult = 1.0
	# ... 后续 kiting 逻辑
```

### 工作量
| 子任务 | 工时 | 涉及文件 |
|--------|------|---------|
| 4.1 AttackCoordinator 单例 | 0.5d | `scripts/combat/attack_coordinator.gd` |
| 4.2 AIBehaviorController 集成群组逻辑 | 0.75d | `scripts/combat/ai_behavior_controller.gd` |
| 4.3 测试: 5 近战同时追玩家、排队行为 | 0.5d | 独立测试场景 |
| **合计** | **1.75d** | |

### 优先级: **P1** (AI 行为模式完成后)

---

## 需求 5: Boss 攻击可读性参数规格

### 背景
GAP-01 (小岛) 将输出 Boss 合并设计。本文档提前定义**接口层**需求 -- Boss 的每个攻击需要哪些参数，程序不需要等合并设计完成就可以先把数据结构准备好。

### 设计

#### 5.1 BossAttackData 资源

**文件**: `scripts/resources/boss_attack_data.gd` (新建)

```gdscript
class_name BossAttackData
extends Resource

## Boss 单个攻击的完整参数规格

# === 标识 ===
@export var attack_id: String = ""          # 唯一标识
@export var attack_name: String = ""        # 调试用

# === 前摇参数 (宫崎标准) ===
@export var windup_duration: float = 0.4    # 前摇总时长 (≥0.35s)
@export var direction_lock_ratio: float = 0.6  # 前摇进行到此比例时锁定方向 (0=开始就锁定, 1=结束时锁定)
@export var windup_move_speed_mult: float = 0.2  # 前摇期间移速倍率

# === 伤害帧参数 ===
@export var damage: int = 10
@export var active_frame_duration: float = 0.1   # 伤害判定窗口时长
@export var hitbox_type: String = "melee_cone"   # "melee_cone" / "projectile" / "aoe_circle" / "aoe_line"

# === 硬直参数 ===
@export var recovery_duration: float = 0.3       # 硬直时长 (≥0.2s)
@export var recovery_move_speed_mult: float = 0.0  # 硬直期间移速倍率
@export var recovery_can_attack: bool = false     # 硬直期间能否发起新攻击
@export var core_exposed_during_recovery: bool = false  # 硬直期间核心弱点是否暴露

# === 伤害区域参数 ===
@export var aoe_radius: float = 0.0              # AOE 圆形半径 (0=非AOE)
@export var aoe_warning_color: Color = Color(1.0, 0.3, 0.1, 0.5)  # 预警颜色
@export var aoe_damage_color: Color = Color(1.0, 0.1, 0.0, 0.7)   # 伤害颜色
@export var cone_angle: float = 0.0              # 扇形角度 (0=非扇形)
@export var cone_range: float = 0.0              # 扇形范围

# === 弹幕参数 ===
@export var projectile_count: int = 1
@export var projectile_speed: float = 200.0
@export var projectile_spread: float = 0.0       # 扩散角度
@export var projectile_bounces: int = 0          # 反弹次数 (0=不反弹)
@export var projectile_bounce_speed_mult: float = 0.5  # 反弹后速度倍率

# === 位移参数 (突进/冲撞) ===
@export var dash_speed: float = 0.0              # 突进速度 (0=无位移)
@export var dash_distance: float = 0.0           # 突进距离
@export var wall_collision_extra_recovery: float = 0.3  # 撞墙额外硬直

# === 召唤参数 ===
@export var summon_count: int = 0
@export var summon_enemy_config: Resource = null  # 召唤敌人的 CombatUnitConfig
@export var summon_formation: String = "random"   # "random" / "circle" / "line"

# === 视觉 ===
@export var windup_color: Color = Color(1.0, 0.55, 0.0)     # 蓄力颜色 (橙黄)
@export var active_frame_flash_color: Color = Color.WHITE    # 伤害帧闪光
@export var aoe_ground_marker_style: String = "circle"       # "circle" / "pie" / "ring"
```

#### 5.2 Boss 阶段参数

每个阶段持有攻击列表 + 阶段转换条件:

```gdscript
class_name BossPhaseData
extends Resource

@export var phase_id: int = 0
@export var phase_name: String = ""
@export var health_threshold: float = 1.0        # 进入此阶段的 HP 比例
@export var attacks: Array[BossAttackData] = []
@export var attack_sequence: String = "cycle"    # "cycle" / "random" / "one_shot"
@export var attack_cooldown: float = 2.0         # 攻击间隔
@export var move_speed: float = 60.0
@export var move_speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var defense_bonus: float = 0.0

# 阶段转换演出
@export var transition_screen_shake: float = 8.0
@export var transition_hit_stop_frames: int = 6
@export var transition_invulnerable_duration: float = 0.5
@export var transition_visual_color: Color = Color.GRAY
@export var transition_vfx: String = "explosion"  # "explosion" / "implosion" / "none"

# 光环参数
@export var glow_color: Color = Color(1.0, 0.5, 0.1, 0.35)
@export var glow_pulse_period: float = 1.0       # 脉冲周期
@export var glow_pulse_alpha_min: float = 0.1
@export var glow_pulse_alpha_max: float = 0.35
```

### 工作量
| 子任务 | 工时 | 涉及文件 |
|--------|------|---------|
| 5.1 BossAttackData 资源类 | 0.25d | `scripts/resources/boss_attack_data.gd` |
| 5.2 BossPhaseData 资源类 | 0.25d | `scripts/resources/boss_phase_data.gd` |
| **合计** | **0.5d** | |

### 优先级: **P0** (GAP-01 的前置依赖 -- 小岛需要这些参数槽来填写合并设计)

---

## 需求 6: 攻击硬直系统 -- 硬直窗口时长标准

### 背景
宫崎文档 (5.2 节) 定义了所有攻击类型的硬直时间标准。这些需要在攻击系统层面强制执行。

### 设计

#### 6.1 硬直标准表 (从宫崎文档 5.2 提取为代码可读格式)

在 `SkillBase.gd` 中以常量字典形式定义:

```gdscript
# scripts/skills/skill_base.gd

const RECOVERY_STANDARDS := {
	"melee_light":      {"min": 0.2, "recommended": 0.3, "can_move": false, "can_attack": false},
	"melee_heavy":      {"min": 0.4, "recommended": 0.6, "can_move": false, "can_attack": false},
	"ranged_single":    {"min": 0.15, "recommended": 0.2, "can_move": true,  "can_attack": false},
	"ranged_barrage":   {"min": 0.3, "recommended": 0.4, "can_move": false, "can_attack": false},
	"aoe_ground":       {"min": 0.5, "recommended": 0.8, "can_move": false, "can_attack": false},
	"dash_into_wall":   {"min": 0.5, "recommended": 0.8, "can_move": false, "can_attack": false},
	"ultimate":         {"min": 1.5, "recommended": 2.0, "can_move": false, "can_attack": false},
}

const WINDUP_STANDARDS := {
	"melee_light":      {"min": 0.35, "recommended": 0.4},
	"melee_heavy":      {"min": 0.6, "recommended": 0.8},
	"ranged_single":    {"min": 0.35, "recommended": 0.4},
	"ranged_barrage":   {"min": 0.5, "recommended": 0.7},
	"aoe_ground":       {"min": 0.8, "recommended": 1.2},
	"dash":             {"min": 0.6, "recommended": 0.7},
	"summon":           {"min": 1.0, "recommended": 1.3},
	"ultimate":         {"min": 1.5, "recommended": 2.0},
}
```

#### 6.2 硬直执行逻辑

在每个技能实例化时根据其 `attack_category` 设置硬直参数:

```gdscript
# SkillBase.gd
@export var attack_category: String = "melee_light"  # 对应 RECOVERY_STANDARDS 的 key

func _apply_recovery_standard() -> void:
	var std := RECOVERY_STANDARDS.get(attack_category, RECOVERY_STANDARDS["melee_light"])
	_recovery_duration = std["recommended"]
	# 确保不低于最低值
	_recovery_duration = maxf(_recovery_duration, std["min"])
	_can_move_during_recovery = std["can_move"]
	_can_attack_during_recovery = std["can_attack"]

func _apply_windup_standard() -> void:
	var std := WINDUP_STANDARDS.get(attack_category, WINDUP_STANDARDS["melee_light"])
	_windup_duration = maxf(_windup_duration, std["min"])
```

#### 6.3 硬直期间的行为限制

在 `AIBehaviorController` 中检查硬直状态:

```gdscript
func _can_act() -> bool:
	if _unit.skills == null: return true
	# 检查是否有技能处于硬直状态
	for skill in _unit.skills.skills:
		if skill._is_recovery and not skill._can_move_during_recovery:
			return false
	return true
```

在 `CombatUnit._physics_process` 中:

```gdscript
func _physics_process(delta: float) -> void:
	if is_dead: return
	# 如果处于不可移动的硬直状态，velocity 归零
	if not _can_move():
		velocity = Vector2.ZERO
	# 否则执行 controller 设置的 velocity
	move_and_slide()
```

### 工作量
| 子任务 | 工时 | 涉及文件 |
|--------|------|---------|
| 6.1 标准表定义 | 0.25d | `scripts/skills/skill_base.gd` |
| 6.2 硬直执行逻辑 | 0.25d | `scripts/skills/skill_base.gd` |
| 6.3 AI/CombatUnit 硬直检查 | 0.25d | `scripts/enemy.gd`, `scripts/combat/ai_behavior_controller.gd` |
| **合计** | **0.75d** | |

### 优先级: **P0** (与需求 1 同步实施)

---

## 汇总: 所有需求优先级与依赖

```
需求 1 (攻击前摇) ── P0 ── 需求 5 (Boss 攻击参数) 的前置
需求 2 (视觉状态机) ── P0 ── 独立，可与需求 1 并行
需求 3 (AI 组件化) ── P0 ── 依赖 CombatUnit 迁移 (Phase 1~2)
需求 4 (群组协调) ── P1 ── 依赖需求 3 (AI 组件化完成)
需求 5 (Boss 攻击参数) ── P0 ── GAP-01 前置依赖
需求 6 (硬直系统) ── P0 ── 与需求 1 同步
```

**总计新增: 7 个 .gd 文件、3 个 Resource 类、1 个 Autoload**

| 文件 | 需求 |
|------|------|
| `scripts/skills/skill_base.gd` (改造) | 1, 6 |
| `scripts/combat/skill_component.gd` (适配) | 1 |
| `scripts/combat/enemy_visual_state.gd` (新增) | 2 |
| `scripts/combat/ai_behavior_controller.gd` (新增) | 3 |
| `scripts/combat/ai_perception.gd` (新增) | 3 |
| `scripts/resources/ai_behavior_config.gd` (新增) | 3 |
| `scripts/combat/attack_coordinator.gd` (新增, Autoload) | 4 |
| `scripts/resources/boss_attack_data.gd` (新增) | 5 |
| `scripts/resources/boss_phase_data.gd` (新增) | 5 |
| `scripts/enemy.gd` (改造) | 1, 2, 3, 4, 6 |

**预估总工时: 约 12.75 工作日**

---

*本文档为程序需求规格，不替代设计文档。所有"为什么"参见宫崎英高 `战斗系统设计-宫崎英高.md`。所有"怎么叙事"参见 GAP-01 (小岛)。*
