class_name GamePersistence
extends RefCounted

## ConfigFile 持久化工具 — Phase 4
##
## 读写 user://game_persistence.cfg，存储 Boss 遭遇次数、累计死亡次数等跨局数据。
## 纯静态接口，无需实例化。
##
## 文件格式：
##   [Boss]
##   boss_encounter_count=3
##   [Stats]
##   total_deaths=7

const CONFIG_PATH: String = "user://game_persistence.cfg"
const SECTION_BOSS: String = "Boss"
const SECTION_STATS: String = "Stats"
const SCAR_REDUCE_AMOUNT: int = 5  # 击败 Boss 降低的死亡计数


# =============================================================================
# Boss 遭遇次数
# =============================================================================

static func get_boss_encounter_count() -> int:
	return _get_config(SECTION_BOSS, "boss_encounter_count", 0) as int


static func increment_boss_encounter_count() -> void:
	var count: int = get_boss_encounter_count() + 1
	_set_config(SECTION_BOSS, "boss_encounter_count", count)


# =============================================================================
# 累计死亡次数
# =============================================================================

static func get_total_deaths() -> int:
	return _get_config(SECTION_STATS, "total_deaths", 0) as int


static func increment_total_deaths() -> void:
	var count: int = get_total_deaths() + 1
	_set_config(SECTION_STATS, "total_deaths", count)


## 击败 Boss 后减少死亡次数的"半治愈"效果
static func reduce_total_deaths(amount: int = SCAR_REDUCE_AMOUNT) -> void:
	var count: int = get_total_deaths()
	count = maxi(0, count - amount)
	_set_config(SECTION_STATS, "total_deaths", count)


# =============================================================================
# 伤疤等级计算
# =============================================================================

## 0: 0-2 次死亡 — 无伤疤
## 1: 3-5 次死亡 — 轻微裂痕
## 2: 6-10 次死亡 — 明显裂痕
## 3: 11+ 次死亡 — 严重裂痕
static func get_scar_level() -> int:
	var deaths: int = get_total_deaths()
	if deaths <= 2:
		return 0
	if deaths <= 5:
		return 1
	if deaths <= 10:
		return 2
	return 3


# =============================================================================
# 仪式感递减 — Boss 登场参数
# =============================================================================

## Boss 登场淡入时长（modulate.a 0→1）
static func get_boss_appear_duration() -> float:
	var count: int = get_boss_encounter_count()
	if count <= 1:
		return 2.0    # 第1次：完整登场（2s）
	if count <= 3:
		return 1.0    # 第2-3次：缩短登场（1s）
	return 0.3        # 第4次+：快速登场（0.3s）


## 沉默时刻持续时长（HUD 消退后保持沉默的时间）
static func get_silence_hold_duration() -> float:
	var count: int = get_boss_encounter_count()
	if count <= 1:
		return 2.5    # 第1次：完整沉默
	if count <= 3:
		return 1.0    # 第2-3次：缩短
	return 0.1        # 第4次+：几乎跳过


## Hit Stop 帧数（Boss 最后一击）
static func get_hit_stop_frames() -> int:
	var count: int = get_boss_encounter_count()
	if count <= 1:
		return 6      # 第1次：完整 6 帧
	if count <= 3:
		return 3      # 第2-3次：3 帧
	return 1          # 第4次+：1 帧


# =============================================================================
# 伤疤效果参数
# =============================================================================

## HUD 闪烁间隔秒数。-1 表示不闪烁
static func get_scar_flicker_interval() -> float:
	var level: int = get_scar_level()
	match level:
		0:
			return -1.0   # 无闪烁
		1:
			return 8.0    # 轻微：每 8 秒一次
		2:
			return 4.0    # 明显：每 4 秒一次
		3:
			return 2.0    # 严重：每 2 秒一次
	return -1.0


## 沉默时刻消退行为：staggered / fast / instant
static func get_silence_behavior() -> String:
	var level: int = get_scar_level()
	if level <= 1:
		return "staggered"  # 正常阶梯消退
	if level == 2:
		return "fast"       # 加速消退
	return "instant"        # 瞬间消失（旧电视关机效果）


# =============================================================================
# 内部 — ConfigFile 读写
# =============================================================================

static func _get_config(section: String, key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		return default
	return cfg.get_value(section, key, default)


static func _set_config(section: String, key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	# 忽略文件不存在或加载失败——创建/追加写入
	cfg.load(CONFIG_PATH)
	cfg.set_value(section, key, value)
	cfg.save(CONFIG_PATH)
