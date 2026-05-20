class_name BossConfig
extends Resource

## Boss 顶层配置资源
##
## 包含: 标识/名称/HP/四乐章数据/技能场景/小怪场景/死亡演出参数
## 每个 Boss 只需新建一个 Resource 配置，无需改流程代码
##
## 用法：
##   var cfg := BossConfig.sato_default()
##   _build_boss_systems(cfg)

# ==============================================================================
# 核心标识
# ==============================================================================

## Boss 唯一标识
@export var boss_id: String = "boss_default"
## 显示名称（如 "三年二班 体育教师 · 佐藤 幸雄"）
@export var boss_display_name: String = "UNKNOWN"
## 击败文案（如 "下课。"）
@export var boss_defeat_text: String = "已击败"
## 击败大字颜色
@export var boss_defeat_color: Color = Color(1.0, 0.15, 0.05)

# ==============================================================================
# 战斗数值
# ==============================================================================

## 总 HP
@export var total_hp: int = 2000

# ==============================================================================
# 乐章数据
# ==============================================================================

## 四乐章配置（按顺序索引 0-3）
@export var phases: Array[BossPhaseData] = []

# ==============================================================================
# 技能系统
# ==============================================================================

## 全局技能场景列表（PackedScene 格式，技能子类用 Resource 也可）
## 索引顺序决定了 skill_slots 的映射值
@export var skill_scenes: Array[PackedScene] = []

# ==============================================================================
# 小怪配置
# ==============================================================================

## 学生小怪场景（如有）
@export var minion_scene: PackedScene = null

# ==============================================================================
# 死亡演出参数
# ==============================================================================

## 坍塌动画时长（秒）
@export var collapse_duration: float = 0.6
## 金色粒子数量
@export var particle_count: int = 40
## 粒子颜色
@export var particle_color: Color = Color(1.0, 0.85, 0.2)
## 胜利大字停留时长（秒）
@export var victory_text_duration: float = 3.0
## 死亡时缓展开总时长（秒）
@export var death_slowmo_duration: float = 0.8
## Hit Stop 冻结时长（秒）
@export var death_hit_stop_duration: float = 0.15

# ==============================================================================
# Boss 登场参数
# ==============================================================================

## 登场揭示文本（如 "三年二班 体育教师 · 佐藤 幸雄"）
@export var entrance_reveal_text: String = ""
## 登场文本颜色
@export var entrance_font_color: Color = Color(0.7, 0.3, 0.3)

# ==============================================================================
# 工厂方法
# ==============================================================================

## 佐藤（体育老师）默认配置 — 学校副本
static func sato_default() -> BossConfig:
	var cfg := BossConfig.new()
	cfg.boss_id = "boss_sato"
	cfg.boss_display_name = "三年二班 体育教师 · 佐藤 幸雄"
	cfg.boss_defeat_text = "下课。"
	cfg.boss_defeat_color = Color(1.0, 0.15, 0.05)
	cfg.total_hp = 2000
	cfg.death_hit_stop_duration = 0.15
	cfg.death_slowmo_duration = 0.8
	cfg.collapse_duration = 0.6
	cfg.particle_count = 40
	cfg.particle_color = Color(1.0, 0.85, 0.2)
	cfg.victory_text_duration = 3.0
	cfg.entrance_reveal_text = "三年二班 体育教师 · 佐藤 幸雄"
	cfg.entrance_font_color = Color(0.7, 0.3, 0.3)

	# ---- 四乐章配置 ----

	# P1: 热身 — 教学期，2.0s 间隔
	var p1 := BossPhaseData.new()
	p1.phase_index = 0
	p1.phase_name = "热身"
	p1.health_threshold = 0.75
	p1.move_speed = 55.0
	p1.defense = 2
	p1.contact_damage = 22
	p1.aura_color = Color(1.0, 0.5, 0.1)
	p1.aura_alpha_min = 0.1
	p1.aura_alpha_max = 0.35
	p1.aura_pulse_period = 0.5
	p1.attack_interval_min = 2.0
	p1.attack_interval_max = 2.0
	p1.skill_slots = [1, 2, 3, 4]    # HeavySweep, WhistleWave, RollCharge, VaultStomp
	p1.bullet_count = 3
	p1.bullet_speed = 180.0
	p1.bullet_spread_angle = 60.0
	p1.core_exposed = false
	p1.transition_duration = 0.8
	p1.transition_title = "第一乐章"
	p1.transition_subtitle = "热身"
	p1.transition_narrative = "他在示范动作。看好了。"
	p1.transition_particle_color = Color(1.0, 0.5, 0.1)
	cfg.phases.append(p1)

	# P2: 球类训练 — 1.5s 间隔，中距离压力
	var p2 := BossPhaseData.new()
	p2.phase_index = 1
	p2.phase_name = "球类训练"
	p2.health_threshold = 0.50
	p2.move_speed = 70.0
	p2.defense = 4
	p2.contact_damage = 25
	p2.aura_color = Color(1.0, 0.7, 0.1)
	p2.aura_alpha_min = 0.15
	p2.aura_alpha_max = 0.4
	p2.aura_pulse_period = 0.4
	p2.attack_interval_min = 1.5
	p2.attack_interval_max = 1.5
	p2.skill_slots = [5, 6, 7, 8]    # Fastball, GroundShockwave, WhistleShriek, IronShoulder
	p2.bullet_count = 5
	p2.bullet_speed = 220.0
	p2.bullet_spread_angle = 80.0
	p2.core_exposed = false
	p2.transition_duration = 0.8
	p2.transition_title = "第二乐章"
	p2.transition_subtitle = "球类训练"
	p2.transition_narrative = "球从黑暗里飞出来。那不是篮球。"
	p2.transition_particle_color = Color(1.0, 0.7, 0.1)
	cfg.phases.append(p2)

	# P3: 集合 — 1.0s 间隔，场面混乱
	var p3 := BossPhaseData.new()
	p3.phase_index = 2
	p3.phase_name = "集合"
	p3.health_threshold = 0.25
	p3.move_speed = 85.0
	p3.defense = 6
	p3.contact_damage = 28
	p3.aura_color = Color(0.9, 0.85, 0.7)
	p3.aura_alpha_min = 0.2
	p3.aura_alpha_max = 0.5
	p3.aura_pulse_period = 0.3
	p3.attack_interval_min = 1.0
	p3.attack_interval_max = 1.0
	p3.skill_slots = [0, 9, 2, 6]    # SummonWhistle, Dash, WhistleWave, GroundShockwave
	p3.bullet_count = 7
	p3.bullet_speed = 260.0
	p3.bullet_spread_angle = 100.0
	p3.summon_enabled = true
	p3.summon_interval = 12.0
	p3.summon_count = 3
	p3.core_exposed = false
	p3.transition_duration = 1.0
	p3.transition_title = "第三乐章"
	p3.transition_subtitle = "集合"
	p3.transition_narrative = "哨声叫来了学生。还有别的东西。"
	p3.transition_particle_color = Color(0.9, 0.85, 0.7)
	cfg.phases.append(p3)

	# P4: 毕业考试 — 0.8s 间隔递减，绝望模式
	var p4 := BossPhaseData.new()
	p4.phase_index = 3
	p4.phase_name = "毕业考试"
	p4.health_threshold = 0.0
	p4.move_speed = 110.0
	p4.defense = 0
	p4.contact_damage = 35
	p4.aura_color = Color(0.5, 0.05, 0.02)
	p4.aura_alpha_min = 0.3
	p4.aura_alpha_max = 0.6
	p4.aura_pulse_period = 0.2
	p4.attack_interval_min = 0.8
	p4.attack_interval_max = 0.8
	p4.skill_slots = [10, 11, 2]     # DesperateDash, EquipmentRain, WhistleWave
	p4.bullet_count = 9
	p4.bullet_speed = 300.0
	p4.bullet_spread_angle = 120.0
	p4.attack_interval_decay = 0.15  # 每次攻击间隔递减0.15s
	p4.attack_interval_min_decayed = 0.4  # 最终不低于0.4s
	p4.core_exposed = true
	p4.transition_duration = 0.8
	p4.transition_title = "第四乐章"
	p4.transition_subtitle = "毕业考试"
	p4.transition_narrative = "一切压上来。没有退路了。"
	p4.transition_particle_color = Color(0.5, 0.05, 0.02)
	cfg.phases.append(p4)

	return cfg
