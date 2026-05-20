# 怪物 AI 行为模式与敌人技能系统设计 V1.0

> **基于代码库**: `scripts/enemy.gd` / `scripts/skill_manager.gd` / `scripts/skills/skill_base.gd`
> **核心目标**: 让敌人使用与玩家同一套技能系统，用行为模式替代当前硬编码的 `is_ranged` 二选一

---

## 1. 当前架构诊断

读完 `enemy.gd` 后，以下问题是对现有设计的直接观察，也是本方案的输入约束：

### 1.1 行为系统 — 硬编码二分

```gdscript
# enemy.gd:89-90
if is_ranged:
    _ranged_behavior(delta)
else:
    _melee_behavior()
```

**问题**:
- `is_ranged` bool 只能表达两种模式，无法扩展
- `_melee_behavior()` 就是直线追，碰撞后做一次 wall-slide 补救
- `_ranged_behavior()` 有 preferred_distance 维持逻辑，但 strafe 方向固定，不根据弹幕动态变化
- 没有行为转换的概念（低血量逃跑、巡逻等）

### 1.2 技能系统 — 敌人完全不使用

`skill_manager.gd` 已经提供了完整的技能框架：
- `SkillBase` 抽象类（cooldown, `try_execute()`, `execute()`）
- 9 个已实现技能：slash, aoe, multi_shot, chain_lightning, whirlwind, snipe, ice_nova, fire_trail, shadow_clone
- 冷却系统 + 升级系统

**但敌人完全不使用这个系统**。远程敌人通过硬编码 `_shoot()` 发射 EnemyProjectile，近战敌人通过 `move_and_slide()` 接触伤害。

### 1.3 寻路 — 直线追踪 + 简单墙滑

`_melee_behavior()` 的 wall-slide 逻辑（enemy.gd:99-107）试图在碰撞时沿法线滑动，但在复杂 TileMap 墙壁前会卡住。

`NavManager` 已经存在，但只用于敌人生成位置的随机采样，没有连接到敌人寻路。

---

## 2. 怪物 AI 行为模式系统

### 2.1 架构概览

```
Enemy (CharacterBody2D)
  ├── AIStateMachine (Node)       ← 新增：行为状态机
  │     ├── state: int            ← 当前行为模式
  │     ├── _ai_timer: float      ← 行为决策冷却
  │     └── evaluate()            ← 每帧评估是否转换行为
  ├── EnemySkillManager (Node)    ← 新增：敌人专属技能管理器
  │     └── skills: Array[SkillBase]
  ├── NavigationAgent2D           ← 新增：Godot 导航代理
  └── (原有节点: Sprite, HealthBar, ContactArea, ...)
```

### 2.2 行为模式枚举

```gdscript
enum AIState {
    IDLE        = 0,  # 待机，不移动
    CHASE       = 1,  # 追踪玩家，近战攻击
    KITE        = 2,  # 保持距离，远程攻击
    AMBUSH      = 3,  # 潜伏不动，进入范围后突袭
    PATROL      = 4,  # 沿路径巡逻，发现玩家后切换 CHASE
    GUARD       = 5,  # 守卫固定区域，不追击超出范围
    FLEE        = 6,  # 低血量逃跑，回复后返回
    STUNNED     = 7,  # 被控/冻结/眩晕
    RETURN      = 8,  # 回到巡逻/守卫出发点
}
```

### 2.3 行为模式定义表

每个行为模式有四个要素：**触发条件、持续条件、退出条件、技能选择策略**。

#### CHASE（追踪近战）

| 要素 | 定义 |
|------|------|
| 触发条件 | `distance > melee_range AND player_visible` |
| 持续条件 | `distance > melee_range AND player_in_leash_range` |
| 退出条件 | `distance <= melee_range` → 开始攻击；`distance > leash_range` → 转 RETURN |
| 技能策略 | 使用 slash（CD 0.5s），距离近时优先 whirlwind |

```gdscript
# 行为参数（export 到编辑器）
@export var melee_range: float = 30.0
@export var leash_range: float = 400.0  # 最大追击距离
@export var player_detection_range: float = 250.0
```

#### KITE（保持距离远程）

| 要素 | 定义 |
|------|------|
| 触发条件 | `preferred_range_min < distance < detection_range` |
| 持续条件 | `distance < leash_range AND not cornered` |
| 退出条件 | `distance < preferred_range_min` → 转 CHASE 或侧移；`distance > leash_range` → 转 RETURN |
| 技能策略 | multi_shot / snipe 交替；玩家靠近时 ice_nova 自保 |

**从当前 is_ranged 行为的差异**: 当前 `_ranged_behavior()` 使用固定 preferred_distance，没有考虑被玩家逼近后的反直觉行为（往玩家方向走）。需要加入 `cornered` 检测——当背后有墙壁且玩家逼近时，用闪避技能或强行穿侧。

#### AMBUSH（潜伏突袭）

| 要素 | 定义 |
|------|------|
| 触发条件 | 出生时进入 AMBUSH；非 combat 状态 |
| 持续条件 | `distance > ambush_trigger_distance` 或 `未暴露` |
| 退出条件 | `distance <= ambush_trigger_distance` → 转 CHASE + 爆发技能 |
| 特殊规则 | 进入 CHASE 后 2 秒内攻击力 x1.5；transparent modulate 表示潜伏 |

```gdscript
@export var ambush_trigger_distance: float = 60.0
@export var ambush_bonus_damage_mult: float = 1.5
@export var ambush_bonus_duration: float = 2.0
```

潜伏状态下的视觉：sprite modulate alpha 0.3-0.5 + 静止不动。玩家靠近触发距离后，闪白并转 CHASE，第一击带额外伤害。

#### PATROL（巡逻）

| 要素 | 定义 |
|------|------|
| 触发条件 | 出生时进入 PATROL，且有 patrol_path |
| 持续条件 | `未发现玩家` 且 `alive` |
| 退出条件 | `player_detected` → 转 CHASE 或 KITE |
| 特殊规则 | 沿 patrol_points 列表顺序移动，到达终点后反向循环 |

```gdscript
@export var patrol_points: Array[Vector2] = []  # 全局坐标路径点
@export var patrol_wait_time: float = 1.0        # 到达每个点后等待
@export var detection_angle: float = 120.0       # 视野锥角度
@export var detection_range_patrol: float = 180.0
```

**视野锥检测**：在 PATROL 模式下，只在移动方向前方检测玩家。用点积过滤：
```gdscript
var to_player := player.global_position - global_position
var forward := Vector2.RIGHT.rotated(patrol_direction.angle())
if forward.dot(to_player.normalized()) > cos(deg_to_rad(detection_angle * 0.5)):
    # 玩家在视野内
```

#### GUARD（守卫）

| 要素 | 定义 |
|------|------|
| 触发条件 | 出生时进入 GUARD，或巡逻/追敌返回后 |
| 持续条件 | `distance_to_guard_point < guard_radius` |
| 退出条件 | `player_in_guard_radius` → 转 CHASE/KITE |
| 特殊规则 | 敌人不会追击超出 guard_limit_range；超出后转 RETURN |

```gdscript
@export var guard_position: Vector2          # 守卫点
@export var guard_radius: float = 60.0       # 守卫区域半径（不移动的范围）
@export var guard_limit_range: float = 200.0 # 最大追击半径
```

#### FLEE（逃跑）

| 要素 | 定义 |
|------|------|
| 触发条件 | `health_ratio < flee_health_threshold` 且 `not is_boss` |
| 持续条件 | `health_ratio < flee_return_threshold` |
| 退出条件 | `health_ratio >= flee_return_threshold` → 转原行为；`flee_timeout` → 转原行为 |
| 技能策略 | 逃跑时沿远离玩家方向移动，放置 fire_trail 或 shadow_clone 阻隔追兵 |

```gdscript
@export var flee_health_threshold: float = 0.2    # 20% HP 时逃跑
@export var flee_return_threshold: float = 0.4    # 回到 40% HP 后返回
@export var flee_speed_mult: float = 1.3           # 逃跑时加速
@export var flee_timeout: float = 5.0              # 最多逃跑 5 秒
```

#### STUNNED / RETURN

- **STUNNED**: `move_speed = 0`，不执行状态机更新。由 SkillIceNova 等技能触发。进入时记录来源状态，结束后恢复。
- **RETURN**: 沿 NavigationAgent2D 回到 guard_position 或 patrol_path 上最近点。到达后转 GUARD 或 PATROL。

---

## 3. 技能复用架构 — EnemySkillManager

### 3.1 设计原则

**敌人使用与玩家**完全相同的 SkillBase 派生类。差异只在于：
1. 技能参数不同（CD 更长、伤害更低或更高、范围更小）
2. 触发条件不同（敌人基于 AI 状态 + 距离 + 血量，玩家基于鼠标/按键）
3. "攻击者" 不同（技能中的 `player` 引用指向敌人自身）

### 3.2 EnemySkillManager 实现

```gdscript
class_name EnemySkillManager
extends Node

var owner: CharacterBody2D = null          # 敌人自身
var attack_area: Area2D = null
var skills: Array[SkillBase] = []

signal skill_used(skill_id: String)

# 从技能定义表初始化
func init(owner_node: CharacterBody2D, skill_defs: Array[Dictionary]) -> void:
    owner = owner_node
    for def in skill_defs:
        var skill := _create_skill(def)
        if skill:
            add_skill(skill)

func add_skill(skill: SkillBase) -> void:
    skill.setup(owner, owner.get_parent())
    skill.attack_area = attack_area
    skills.append(skill)
    add_child(skill)

func process_all(delta: float) -> void:
    for s in skills:
        s._process(delta)

func try_use_skill(index: int) -> bool:
    if index >= 0 and index < skills.size():
        if skills[index].try_execute():
            skill_used.emit(skills[index].skill_id)
            return true
    return false

# 冷却重置（Boss 阶段转换时用）
func reset_all_cooldowns() -> void:
    for s in skills:
        s.is_ready = true
        s.cooldown_remaining = 0.0

func set_all_cooldown_mult(mult: float) -> void:
    for s in skills:
        s.cooldown *= mult
```

### 3.3 敌人技能定义

在 `enemy.gd` 中用字典表声明 spawn 时注入的技能：

```gdscript
# 敌人类型 → 技能列表映射
const ENEMY_SKILL_DEFS := {
    "melee_basic": [
        {"id": "slash", "cooldown": 0.8, "damage": 8, "attack_range": 45.0},
    ],
    "ranged_basic": [
        {"id": "snipe", "cooldown": 2.0, "damage": 10, "projectile_speed": 500.0},
        {"id": "multi_shot", "cooldown": 3.5, "damage": 6, "projectile_count": 2, "spread_angle": 30.0},
    ],
    "elite_melee": [
        {"id": "slash", "cooldown": 0.5, "damage": 15},
        {"id": "whirlwind", "cooldown": 5.0, "damage": 8, "duration": 2.0, "spin_radius": 100.0},
    ],
    "elite_ranged": [
        {"id": "snipe", "cooldown": 1.5, "damage": 15},
        {"id": "ice_nova", "cooldown": 6.0, "damage": 8, "freeze_duration": 1.5, "nova_radius": 120.0},
    ],
    "ambusher": [
        {"id": "slash", "cooldown": 1.0, "damage": 20},  # ambush_bonus 叠加后更高
    ],
    "boss_phase1": [
        {"id": "snipe", "cooldown": 2.0, "damage": 18, "projectile_speed": 600.0, "aoe_on_hit": 60.0},
        {"id": "multi_shot", "cooldown": 3.0, "damage": 10, "projectile_count": 4, "spread_angle": 35.0},
    ],
    "boss_phase2": [
        {"id": "aoe", "cooldown": 4.0, "damage": 20, "knockback": 300.0, "visual_radius": 80.0},
        {"id": "shadow_clone", "cooldown": 8.0, "explode_damage": 25, "clone_duration": 4.0, "explode_radius": 150.0},
    ],
    "boss_phase3": [
        {"id": "chain_lightning", "cooldown": 2.5, "damage": 22, "chain_count": 4, "chain_range": 180.0},
        {"id": "whirlwind", "cooldown": 6.0, "damage": 12, "duration": 3.0, "spin_radius": 150.0},
    ],
}
```

### 3.4 SkillBase 适配

`SkillBase` 中对 `player` 的引用——敌人技能中这个引用指向的是敌人自身。需要检查技能代码中对 `player` 的用法：

| 技能 | 使用 `player` 的方式 | 敌人复用时的问题 |
|------|-------------------|-------------------|
| SkillSlash | 获取 `_aim_direction`、位置 | 敌人没有 `_aim_direction`，改为 `direction_to(player_ref)` |
| SkillWhirlwind | 获取位置、move_speed | 位置直接替换为 owner；move_speed 改为 owner.move_speed |
| SkillAOE | 获取位置、攻击 area | 直接使用 owner.position + attack_area |
| SkillMultiShot | 获取 `_aim_direction` | 敌人用 `direction_to(player)` |
| SkillSnipe | 同上 | 同上 |
| SkillChainLightning | 攻击 area 扫描敌人 | 需要反转：扫描的是 player 而不是敌人 |
| SkillIceNova | 冻结敌人 move_speed | 冻结玩家——改为冻结 player_ref 而非自身 |
| SkillShadowClone | 生成在玩家位置 | 生成在敌人位置 |
| SkillFireTrail | 在玩家脚下 | 在敌人脚下 |

**核心改造**：`SkillBase.setup()` 中的 `player` 参数改为 `owner`，代码中所有 `player` 引用改为 `owner`。对于敌人技能，`owner` 是敌人自身，攻击目标自动变为 `player_ref`。

```gdscript
# SkillBase.gd — 修改后的结构
var owner_node: CharacterBody2D = null     # 原 player 改名为 owner_node
var target_node: CharacterBody2D = null     # 对玩家技能是敌人，对敌人技能是玩家

func setup(owner_n: CharacterBody2D, ep: Node2D) -> void:
    owner_node = owner_n
    effect_parent = ep
    # 自动寻找目标组
    var target_group := "enemy" if owner_n.is_in_group("player") else "player"
    var targets := owner_n.get_tree().get_nodes_in_group(target_group)
    if targets.size() > 0:
        target_node = targets[0]
```

这样改造后，所有已有技能无需做子类修改，直接在敌人身上复用。

---

## 4. AIStateMachine 状态机

### 4.1 核心循环

```gdscript
# AIStateMachine.gd
class_name AIStateMachine
extends Node

signal state_changed(old_state: int, new_state: int)

@export var decision_interval: float = 0.1       # 决策间隔（避免每帧评估）
@export var ai_update_interval: float = 0.05     # 路径更新间隔

var _enemy: CharacterBody2D
var _player_ref: Node2D
var _current_state: int = AIState.IDLE
var _previous_state: int = AIState.IDLE
var _decision_timer: float = 0.0
var _path_timer: float = 0.0
var _state_data: Dictionary = {}                 # 行为专用状态数据
var _state_elapsed: float = 0.0                  # 当前状态持续时间

func _ready() -> void:
    _enemy = owner as CharacterBody2D
    # 外部注入 player_ref

func _process(delta: float) -> void:
    if _enemy.is_dead: return
    _state_elapsed += delta

    _decision_timer += delta
    if _decision_timer >= decision_interval:
        _decision_timer = 0.0
        _evaluate_transition()

    _path_timer += delta
    if _path_timer >= ai_update_interval:
        _path_timer = 0.0
        _update_movement(delta)

func _evaluate_transition() -> void:
    var new_state := _current_state
    # 按优先级评估行为转换（从高到低）
    match _current_state:
        AIState.STUNNED:
            # 等待冻结结束，由外部恢复
            return
        _:
            # 通用评估
            if _should_flee():
                new_state = AIState.FLEE
            elif _should_ambush():
                new_state = AIState.AMBUSH
            elif _should_chase():
                new_state = AIState.CHASE
            elif _should_kite():
                new_state = AIState.KITE
            elif _should_patrol():
                new_state = AIState.PATROL
            elif _should_guard():
                new_state = AIState.GUARD
            else:
                new_state = AIState.IDLE

    if new_state != _current_state:
        _transition_to(new_state)
```

### 4.2 行为转换图

```
                    ┌──────────────────────────┐
                    │          IDLE             │
                    └──────┬───────────────────┘
                           │ player detected
                           v
       ┌─────────────┬─────┴─────┬──────────────┐
       │             │           │              │
       v             v           v              v
   ┌──────┐    ┌────────┐  ┌────────┐    ┌────────┐
   │CHASE │◄──►│  KITE  │  │ AMBUSH │    │ PATROL │
   └──┬───┘    └───┬────┘  └───┬────┘    └───┬────┘
      │            │           │              │
      │   lost     │  lost     │ triggered    │ player seen
      │   player   │  player   │              │
      v            v           v              v
   ┌─────────────────────────────────────────────┐
   │                  RETURN                      │
   └─────────┬─────────────────────────┬─────────┘
             │ arrived                 │ arrived
             v                         v
         ┌──────┐                ┌────────┐
         │ GUARD│                │ PATROL │
         └──┬───┘                └────────┘
            │
     ┌──────┴──────┐
     │             │
     v             v
   CHASE         KITE

   任意状态 ──┬── health < flee_threshold ──► FLEE ──► 原状态(恢复后)
              │
              └── frozen/stun ──► STUNNED ──► 原状态(解控后)
```

### 4.3 决策函数伪代码

```gdscript
func _should_flee() -> bool:
    if _enemy.is_boss: return false
    var hp_ratio := float(_enemy._health) / float(_enemy.max_health)
    if hp_ratio < _enemy.flee_health_threshold:
        if _state_elapsed < _enemy.flee_timeout:
            return true
        # 超时后即使低血也不逃了
    return false

func _should_ambush() -> bool:
    if _current_state == AIState.AMBUSH: return true  # 保持潜伏
    if not _enemy.is_ambusher: return false
    if _player_ref == null: return false
    var dist := _enemy.global_position.distance_to(_player_ref.global_position)
    return dist > _enemy.ambush_trigger_distance  # 还未被触发

func _should_chase() -> bool:
    if _player_ref == null: return false
    var dist := _enemy.global_position.distance_to(_player_ref.global_position)
    if dist < _enemy.melee_range: return true
    if dist < _enemy.player_detection_range:
        # 近程怪一律追
        if not _enemy.is_ranged: return true
    return false

func _should_kite() -> bool:
    if not _enemy.is_ranged: return false
    if _player_ref == null: return false
    var dist := _enemy.global_position.distance_to(_player_ref.global_position)
    # 在射程内且不低于最小安全距离
    return dist < _enemy.preferred_distance + 30 and dist > _enemy.melee_range

func _should_patrol() -> bool:
    return _enemy.patrol_points.size() >= 2

func _should_guard() -> bool:
    return _enemy.guard_position != Vector2.ZERO
```

---

## 5. 寻路方案

### 5.1 推荐方案: NavigationAgent2D + 导航网格烘焙

`NavManager` 已经提供了导航多边形初始化和烘焙的基础设施，但没有连接到敌人的寻路。

**实现步骤**:

**Step 1**: NavManager 扩展 —— 提供对 AI 的接口

```gdscript
# nav_manager.gd — 新增

var _agents: Array[NavigationAgent2D] = []

func register_agent(agent: NavigationAgent2D) -> void:
    agent.navigation_finished.connect(_on_agent_arrived.bind(agent))
    agent.path_desired_distance = 4.0
    agent.target_desired_distance = 16.0
    agent.radius = 8.0
    _agents.append(agent)

func get_next_path_position(agent: NavigationAgent2D) -> Vector2:
    return agent.get_next_path_position()

func _on_agent_arrived(agent: NavigationAgent2D) -> void:
    # 通知 agent 的拥有者
    var enemy := agent.owner as Enemy
    if enemy and enemy.ai_state_machine:
        enemy.ai_state_machine._on_nav_arrived()
```

**Step 2**: Enemy 添加 NavigationAgent2D

```gdscript
# enemy.gd — 在 _ready 中
func _setup_navigation() -> void:
    _navigation_agent = NavigationAgent2D.new()
    _navigation_agent.name = "NavAgent"
    add_child(_navigation_agent)
    var nav_manager: Node = get_node_or_null("../NavManager")
    if nav_manager and nav_manager.has_method("register_agent"):
        nav_manager.register_agent(_navigation_agent)
```

**Step 3**: 移动逻辑改为基于 Path 的追踪

```gdscript
func _update_path_to_player() -> void:
    if _navigation_agent.is_navigation_finished():
        return
    _navigation_agent.target_position = player_pos

func _move_along_path(speed: float) -> void:
    if _navigation_agent.is_navigation_finished():
        velocity = Vector2.ZERO
        return
    var next_pos := _navigation_agent.get_next_path_position()
    var dir := global_position.direction_to(next_pos)
    velocity = dir * speed
    move_and_slide()
    # 通知 NavAgent 已移动
    _navigation_agent.set_velocity(velocity)
```

### 5.2 备选方案: 走廊专用的射线+SDF滑墙

对于 `NavManager` 尚未烘焙或不可用的场景，作为 fallback：

```gdscript
# simplified_navigation.gd — 在 enemy 中作为 fallback
func _slide_along_wall(move_dir: Vector2, collision: KinematicCollision2D) -> Vector2:
    var normal := collision.get_normal()
    # 沿墙切向移动
    var slide := move_dir.slide(normal).normalized()
    if slide.length() < 0.1:
        # 垂直撞墙 → 选择顺时针切线
        slide = Vector2(-normal.y, normal.x)
    return slide
```

### 5.3 路径更新的性能优化

- `NavigationAgent2D.target_position` 的更新频率限制在 `ai_update_interval`（默认 0.05s）
- 离线敌人（远离玩家超过 600px）每 0.3s 才更新一次路径
- 使用 `is_navigation_finished()` 避免无效重寻

---

## 6. Boss 战程序化设计

### 6.1 Boss 资源数据定义

```gdscript
# resources/boss_data.gd
class_name BossData
extends Resource

@export var boss_name: String = ""
@export var max_health: int = 500
@export var move_speed: float = 60.0
@export var contact_damage: int = 25
@export var phases: Array[BossPhaseData] = []

# Boss 专属参数
@export var summon_interval: float = 5.0
@export var summon_count: int = 2
@export var aoe_warning_time: float = 0.8

class_name BossPhaseData
extends Resource

@export var health_threshold: float = 1.0     # 100% HP 进入 Phase 1
@export var skill_defs: Array[Dictionary] = []
@export var move_speed_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var phase_enter_sfx: String = ""
@export var phase_enter_vfx: String = "screen_shake|big"
@export var skill_cast_mult: float = 1.0      # 冷却倍率
```

### 6.2 Boss 阶段转换机制

```gdscript
# enemy.gd — Boss 专属
var _current_phase: int = 0
var _phase_health_thresholds: Array[float] = [1.0, 0.7, 0.4]  # Phase 1/2/3

func _boss_check_phase_transition() -> void:
    if not is_boss: return
    var ratio := float(_health) / float(max_health)
    var new_phase: int = 0
    for i in range(_phase_health_thresholds.size()):
        if ratio <= _phase_health_thresholds[i]:
            new_phase = i
        else:
            break

    if new_phase != _current_phase:
        _boss_enter_phase(new_phase)

func _boss_enter_phase(phase: int) -> void:
    _current_phase = phase
    _state_elapsed = 0.0

    # 1. 视觉反馈
    CombatFeedback.big_hit_stop()
    CombatFeedback.screen_shake(8.0)

    # 2. 切换技能组
    _enemy_skill_manager.reset_all_cooldowns()
    _replace_all_skills(_boss_phase_skills[phase])

    # 3. 阶段参数调整
    move_speed *= _boss_phase_data[phase].move_speed_mult
    contact_damage = int(contact_damage * _boss_phase_data[phase].damage_mult)

    # 4. 解锁成就/播放对话
    EventBus.boss_phase_changed.emit(phase)

    # 5. 短暂的不可选中/护盾
    _phase_transition_shield(0.5)
```

### 6.3 Boss 技能模式

每个阶段 Boss 使用不同技能组，技能选择策略：

```gdscript
func _boss_ai_skill_selection(delta: float) -> void:
    if not is_boss: return
    var dist := global_position.distance_to(_player_ref.global_position)
    var hp_ratio := float(_health) / float(max_health)

    match _current_phase:
        0:  # Phase 1 — 远程压制
            if dist < 150 and _enemy_skill_manager.try_use_skill(0):  # aoe 击退
                pass
            elif _enemy_skill_manager.try_use_skill(1):  # snipe
                pass

        1:  # Phase 2 — 召唤+范围
            if _enemy_skill_manager.try_use_skill(0):  # shadow_clone（召唤自爆分身）
                pass
            elif dist < 200 and _enemy_skill_manager.try_use_skill(1):  # aoe
                pass

        2:  # Phase 3 — 狂暴弹幕
            _enemy_skill_manager.set_all_cooldown_mult(0.6)  # 冷却缩短
            # 不断放技能，间隔缩短
            if _enemy_skill_manager.try_use_skill(0):  # chain_lightning
                pass
            if _enemy_skill_manager.try_use_skill(1):  # whirlwind
                pass
```

### 6.4 Boss 行为策略

| Phase | HP范围 | 行为模式 | 技能 |
|-------|--------|---------|------|
| 1 | 100%-70% | KITE 保持中距 | 狙击弹、扇形散射、普通弹幕 |
| 2 | 70%-40% | CHASE + 召唤 | 冲击波击退、召唤炸弹分身、地面 AOE 标记 |
| 3 | 40%-0% | 狂暴 CHASE | 连锁闪电连发、旋风斩持续、全技能 CD 减 40% |

Boss 在每个阶段进入时：
1. 屏幕震动 + 顿帧（程序化反馈）
2. 切换技能组（通过 `_replace_all_skills()`）
3. 短暂的不可选中状态 + 护盾回复（0.5s 无敌期间 modulate 闪烁）
4. 播发阶段对话（通过 EventBus）

---

## 7. 与现有系统的整合路径

### Phase A: 行为模式系统（预计 1-2 天）

1. 创建 `AIStateMachine.gd`，实现状态机和决策循环
2. 在 `enemy.gd` 中添加 `ai_state_machine` 引用和 export 参数
3. 将 `_melee_behavior()` / `_ranged_behavior()` 逻辑分别迁移到 CHASE/KITE handler
4. 为 Patrol / Guard / Ambush 添加 export 参数和 handler
5. 测试基本行为切换

**不破坏现有逻辑**：`enemy.tscn` 中旧的 bool 字段保留，AIStateMachine 初始化时读取它们作为默认值。新场景可以覆盖。

### Phase B: 敌人技能引入（预计 1 天）

1. 改造 `SkillBase.setup()`：`player` 改为 `owner_node`，新增 `target_node`
2. 创建 `EnemySkillManager.gd`
3. 迁移 `_shoot()` 到 `SkillSnipe.execute()`
4. 在 `spawn_enemy()` / `spawn_ranged_enemy()` 中注入技能定义
5. 移除硬编码的 `is_ranged` 分支

### Phase C: 导航升级（预计 1 天）

1. NavManager 添加 NavigationAgent2D 注册/管理
2. 每个 Enemy 的 `_ready()` 中创建 NavigationAgent2D 并注册
3. 移动逻辑改为基于 Path 的循路
4. 保留 wall-slide 作为 fallback

### Phase D: Boss 系统（预计 2 天）

1. 创建 `BossData.gd` / `BossPhaseData.gd` 资源类
2. 在 `enemy.gd` 中添加 Boss 专属字段和阶段切换
3. 实现 `_boss_check_phase_transition()` 在 `_physics_process()` 中调用
4. 为 Boss 注入多组 EnemySkillManager

---

## 8. 文件清单

| 文件 | 说明 |
|------|------|
| `scripts/enemy_ai_state_machine.gd` | AI 状态机（行为模式、决策、转换） |
| `scripts/enemy_skill_manager.gd` | 敌人技能管理器（基于 SkillBase） |
| `scripts/skills/skill_base.gd` | 改造：`player` → `owner_node`，新增 `target_node` |
| `scripts/nav_manager.gd` | 扩展：NavigationAgent2D 注册/管理 |
| `scripts/resources/boss_data.gd` | Boss 阶段数据资源 |
| `scripts/resources/enemy_type_defs.gd` | 敌人类型-技能映射表 |

---

## 9. 设计决策记录

| 决策 | 选择 | 理由 |
|------|------|------|
| 状态机 vs 行为树 | 状态机 | 行为树对于 8 个行为需要 16+ 节点的树结构，过于复杂。目标状态数量少，转换关系明确，状态机足够。后续需要复杂条件时再升级到行为树。 |
| 独立 AIStateMachine 节点 vs 在 enemy.gd 中 | 独立节点 | 职责分离、可复用、可独立测试、可热插拔 |
| EnemySkillManager 复用 SkillBase vs 另写一套 | 复用 SkillBase | 9 个已有技能全部可复用，只需改一个字段名 `player->owner_node`。敌人单独写一套等于重复维护两个系统 |
| NavigationAgent2D 内置 vs 外部插件 | 内置 | Godot 4.6 自带的 NavigationAgent2D 经过了充分的测试，不需要额外依赖 |
| 预制件 vs 代码定义技能 | 代码定义 | 当前技能已经是代码定义的类（SkillBase 派生），保持统一。字典表参数化即可 |
