class_name BossPhaseData
extends Resource

## Boss 乐章数据配置
## 每个乐章定义：HP阈值、移速、防御、光环颜色、攻击间隔、技能槽位、召唤参数
##
## === 新增字段（小岛秀夫 V2）===
##   - transition_title / subtitle / narrative / particle_color
##   - close_range_skill_slot / chase_* 追杀参数
##   - summon_skill_slot / empty_summon_trigger_count / max_minions

# ------------------------------------------------------------------------------
# 基础参数
# ------------------------------------------------------------------------------

## 乐章索引（0=第一乐章, 1=第二乐章, 2=第三乐章, 3=第四乐章）
@export var phase_index: int = 0
## 乐章名称
@export var phase_name: String = ""
## 进入此乐章的 HP 比例阈值（如 0.75 = HP≤75% 时进入）
@export var health_threshold: float = 1.0
## 移速（px/s）
@export var move_speed: float = 60.0
## 防御力（直接减免：damage = max(raw - defense, 1)）
@export var defense: int = 5
## 接触伤害
@export var contact_damage: int = 25
## 阶段转换演出时长（秒）
@export var transition_duration: float = 0.8

# ------------------------------------------------------------------------------
# 攻击参数
# ------------------------------------------------------------------------------

## 攻击间隔最小值（秒）— BossAI 中 randf_range(min, max)
@export var attack_interval_min: float = 2.0
## 攻击间隔最大值（秒）
@export var attack_interval_max: float = 2.0
## 可用技能槽位索引列表（指向 BossConfig.skill_scenes 的索引）
@export var skill_slots: Array[int] = []

# ------------------------------------------------------------------------------
# 光环参数
# ------------------------------------------------------------------------------

## 光环颜色
@export var aura_color: Color = Color(1.0, 0.5, 0.1)
## 光环最小 alpha
@export var aura_alpha_min: float = 0.1
## 光环最大 alpha
@export var aura_alpha_max: float = 0.35
## 光环脉冲周期（秒）
@export var aura_pulse_period: float = 0.5

# ------------------------------------------------------------------------------
# 弹幕参数（SkillM1_WhistleWave 使用）
# ------------------------------------------------------------------------------

## 弹幕弹丸数量（扇形弹幕每轮发射数）
@export var bullet_count: int = 5
## 弹幕弹丸速度（px/s）
@export var bullet_speed: float = 200.0
## 弹幕扇形展开总角度（度）
@export var bullet_spread_angle: float = 90.0

# ------------------------------------------------------------------------------
# 召唤参数
# ------------------------------------------------------------------------------

## 是否启用召唤
@export var summon_enabled: bool = false
## 召唤间隔（秒）
@export var summon_interval: float = 12.0
## 每次召唤数量
@export var summon_count: int = 3
## 召唤技能槽位（覆盖默认 slot 0 约定）
@export var summon_skill_slot: int = -1
## 第几次召唤触发空哨（0=不触发）
@export var empty_summon_trigger_count: int = 3
## 场上最大学生数
@export var max_minions: int = 8

# ------------------------------------------------------------------------------
# 核心暴露（P4 机制）
# ------------------------------------------------------------------------------

## 是否暴露核心弱点
@export var core_exposed: bool = false

# ------------------------------------------------------------------------------
# 近战反击参数（小岛秀夫 — 靠太近就反击）
# ------------------------------------------------------------------------------

## 近战反击技能槽位（玩家距离 < 80px 时强制使用）
@export var close_range_skill_slot: int = -1

# ------------------------------------------------------------------------------
# 追杀参数（小岛秀夫 — 逃课惩罚）
# ------------------------------------------------------------------------------

## 距离超过此阈值（px）触发追杀
@export var chase_distance_threshold: float = 300.0
## 距离超阈值允许的忍耐时间（秒）
@export var chase_patience: float = 2.5
## 追杀冲刺速度（px/s）
@export var chase_speed: float = 500.0
## 追杀冲刺距离（px）
@export var chase_distance: float = 350.0

# ------------------------------------------------------------------------------
# 阶段转换演出（小岛秀夫 — 幕间叙事）
# ------------------------------------------------------------------------------

## 乐章标题（如 "第一乐章"）
@export var transition_title: String = ""
## 乐章副标题（如 "热身"）
@export var transition_subtitle: String = ""
## 叙事描述（如 "他在示范动作。看好了。"）
@export var transition_narrative: String = ""
## 转阶段粒子颜色
@export var transition_particle_color: Color = Color.WHITE
