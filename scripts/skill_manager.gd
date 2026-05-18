class_name SkillManager
extends Node

var player: CharacterBody2D = null
var effect_parent: Node2D = null
var attack_area: Area2D = null
var skills: Array[SkillBase] = []

# 天赋池 (自由选择3个)
const TALENT_POOL := {
	"slash": {"name": "斩击", "icon": "⚔", "desc": "自动近战斩击", "color": Color(0.9, 0.6, 0.2)},
	"aoe": {"name": "范围爆发", "icon": "💥", "desc": "周期性冲击波", "color": Color(1.0, 0.5, 0.1)},
	"multi_shot": {"name": "多重投射", "icon": "✨", "desc": "扇形弹幕射击", "color": Color(0.2, 0.8, 0.4)},
	"chain_lightning": {"name": "连锁闪电", "icon": "⚡", "desc": "弹跳闪电链", "color": Color(0.3, 0.5, 1.0)},
	"whirlwind": {"name": "旋风斩", "icon": "🌀", "desc": "持续旋转切割", "color": Color(0.5, 0.7, 1.0)},
	"snipe": {"name": "狙击", "icon": "🎯", "desc": "超远程高伤弹", "color": Color(1.0, 0.3, 0.1)},
	"ice_nova": {"name": "冰霜新星", "icon": "❄", "desc": "冻结+伤害", "color": Color(0.3, 0.7, 1.0)},
	"fire_trail": {"name": "火焰路径", "icon": "🔥", "desc": "脚下火焰灼烧", "color": Color(1.0, 0.4, 0.05)},
	"shadow_clone": {"name": "暗影分身", "icon": "👥", "desc": "分身+爆炸", "color": Color(0.6, 0.2, 0.8)},
}

# 武器池 (自由选择1个)
const WEAPON_POOL := {
	"sword": {"name": "长剑", "icon": "🗡", "mult": 1.2, "spd": 280, "range": 130, "desc": "伤害+20%, 防御+2"},
	"bow": {"name": "弓", "icon": "🏹", "mult": 0.9, "spd": 340, "range": 170, "desc": "高移速, 超远射程"},
	"staff": {"name": "法杖", "icon": "🪄", "mult": 1.5, "spd": 260, "range": 140, "desc": "技能伤害+50%"},
}

func init(ply: CharacterBody2D, eff: Node2D, area: Area2D, skill_ids: Array) -> void:
	player = ply
	effect_parent = eff
	attack_area = area

	for skill_id in skill_ids:
		var skill := _create_skill(skill_id)
		if skill:
			add_skill(skill)

func _create_skill(id: String) -> SkillBase:
	match id:
		"slash":
			var s := SkillSlash.new()
			s.skill_id = "slash"; s.skill_name = "斩击"; s.icon = "⚔"
			s.cooldown = 0.5; s.damage = 15; s.description = "自动锁定最近敌人斩击"
			return s
		"aoe":
			var s := SkillAOE.new()
			s.skill_id = "aoe"; s.skill_name = "范围爆发"; s.icon = "💥"
			s.cooldown = 4.0; s.damage = 25; s.visual_radius = 50.0; s.description = "以自身为中心扩散冲击波"
			return s
		"multi_shot":
			var s := SkillMultiShot.new()
			s.skill_id = "multi_shot"; s.skill_name = "多重投射"; s.icon = "✨"
			s.cooldown = 1.5; s.damage = 12; s.projectile_count = 3; s.description = "扇形发射弹幕"
			return s
		"chain_lightning":
			var s := SkillChainLightning.new()
			s.skill_id = "chain_lightning"; s.skill_name = "连锁闪电"; s.icon = "⚡"
			s.cooldown = 2.5; s.damage = 18; s.chain_count = 3; s.description = "弹跳闪电链伤害"
			return s
		"whirlwind":
			var s := SkillWhirlwind.new()
			s.skill_id = "whirlwind"; s.skill_name = "旋风斩"; s.icon = "🌀"
			s.cooldown = 6.0; s.damage = 40; s.duration = 1.5; s.description = "持续旋转切割周围敌人"
			return s
		"snipe":
			var s := SkillSnipe.new()
			s.skill_id = "snipe"; s.skill_name = "狙击"; s.icon = "🎯"
			s.cooldown = 3.0; s.damage = 40; s.projectile_speed = 700.0; s.description = "超远距离高伤害狙击弹"
			return s
		"ice_nova":
			var s := SkillIceNova.new()
			s.skill_id = "ice_nova"; s.skill_name = "冰霜新星"; s.icon = "❄"
			s.cooldown = 5.0; s.damage = 15; s.freeze_duration = 2.0; s.description = "冰冻周围敌人2秒"
			return s
		"fire_trail":
			var s := SkillFireTrail.new()
			s.skill_id = "fire_trail"; s.skill_name = "火焰路径"; s.icon = "🔥"
			s.cooldown = 0.0; s.damage = 0; s.burn_damage = 5; s.description = "移动留下火焰灼烧敌人"
			return s
		"shadow_clone":
			var s := SkillShadowClone.new()
			s.skill_id = "shadow_clone"; s.skill_name = "暗影分身"; s.icon = "👥"
			s.cooldown = 8.0; s.damage = 0; s.clone_duration = 3.0; s.explode_damage = 30; s.description = "分身吸引敌人+爆炸"
			return s
	return null

func add_skill(skill: SkillBase) -> void:
	skill.setup(player, effect_parent)
	skill.attack_area = attack_area
	skills.append(skill)
	add_child(skill)

func process_all(delta: float) -> void:
	for s in skills:
		s._process(delta)
		s.try_execute()

func get_skill(index: int) -> SkillBase:
	if index < skills.size():
		return skills[index]
	return null

func get_cooldowns() -> Array:
	var cd: Array = []
	for s in skills:
		cd.append({
			"name": s.skill_name,
			"icon": s.icon,
			"ratio": s.get_cooldown_ratio()
		})
	return cd

func get_upgrade_pool() -> Array:
	if skills.size() < 3:
		return [{"id":"atk","name":"攻击","desc":"伤害+3","icon":"⚔"}]
	return [
		{"id": "atk", "name": "攻击强化", "desc": "全技能伤害+3", "icon": "⚔"},
		{"id": "spd", "name": "敏捷强化", "desc": "移速+20/CD-8%%", "icon": "👟"},
		{"id": "def", "name": "防御强化", "desc": "DEF+2/MaxHP+25", "icon": "🛡"},
		{"id": "skill1", "name": skills[0].skill_name + "强化", "desc": skills[0].skill_name + "伤害+8/CD-10%%", "icon": skills[0].icon},
		{"id": "skill2", "name": skills[1].skill_name + "强化", "desc": skills[1].skill_name + "伤害+8/CD-10%%", "icon": skills[1].icon},
		{"id": "skill3", "name": skills[2].skill_name + "强化", "desc": skills[2].skill_name + "伤害+8/CD-10%%", "icon": skills[2].icon},
		{"id": "heal", "name": "生命恢复", "desc": "HP完全恢复", "icon": "❤"},
	]

# === 技能质变系统 ===
# 每5级触发一次，技能产生质的飞跃

var _evolution_level: int = 0

func check_skill_evolution() -> void:
	_evolution_level += 1
	for s in skills:
		_evolve_skill(s)

func _evolve_skill(s: SkillBase) -> void:
	match s.skill_id:
		"slash":
			match _evolution_level:
				1:
					s.damage += 10
					s.cooldown = maxf(s.cooldown * 0.7, 0.15)
					s.skill_name = "二连斩"
					s.description = "攻速大幅提升，快速二连击"
				2:
					s.damage += 15
					s.cooldown = maxf(s.cooldown * 0.6, 0.1)
					s.skill_name = "剑舞"
					s.description = "极速连斩，刀光剑影"
		"aoe":
			match _evolution_level:
				1:
					s.damage += 15
					(s as SkillAOE).visual_radius *= 1.5
					(s as SkillAOE).knockback *= 1.5
					s.cooldown = maxf(s.cooldown * 0.85, 1.0)
					s.skill_name = "冲击震波"
					s.description = "范围扩大，击退增强"
				2:
					s.damage += 25
					(s as SkillAOE).visual_radius *= 1.3
					(s as SkillAOE).knockback *= 1.8
					s.skill_name = "天崩地裂"
					s.description = "毁灭性冲击波，清屏利器"
		"multi_shot":
			match _evolution_level:
				1:
					(s as SkillMultiShot).projectile_count += 2
					s.damage += 8
					s.skill_name = "箭雨"
					s.description = "弹幕数量+2，覆盖更广"
				2:
					(s as SkillMultiShot).projectile_count += 3
					s.damage += 12
					s.cooldown = maxf(s.cooldown * 0.75, 0.3)
					s.skill_name = "流星暴雨"
					s.description = "铺天盖地的弹幕风暴"
		"chain_lightning":
			match _evolution_level:
				1:
					(s as SkillChainLightning).chain_count += 2
					s.damage += 10
					s.skill_name = "雷链风暴"
					s.description = "闪电链跳数+2，连环追击"
				2:
					(s as SkillChainLightning).chain_count += 3
					s.damage += 20
					(s as SkillChainLightning).damage_decay = 0.85
					s.skill_name = "天罚"
					s.description = "闪电天降，链式毁灭"
		"whirlwind":
			match _evolution_level:
				1:
					(s as SkillWhirlwind).duration *= 1.5
					(s as SkillWhirlwind).spin_radius *= 1.4
					s.damage += 15
					s.skill_name = "暴风斩"
					s.description = "持续时间更长，范围更大"
				2:
					(s as SkillWhirlwind).duration *= 2.0
					(s as SkillWhirlwind).spin_radius *= 1.5
					s.damage += 30
					s.cooldown = maxf(s.cooldown * 0.7, 2.0)
					s.skill_name = "末日风暴"
					s.description = "毁灭性的旋转风暴"
		"snipe":
			match _evolution_level:
				1:
					s.damage += 25
					(s as SkillSnipe).projectile_speed += 200
					(s as SkillSnipe).aoe_on_hit *= 1.5
					s.skill_name = "穿甲爆破弹"
					s.description = "穿透+爆炸，伤害范围双重提升"
				2:
					s.damage += 50
					(s as SkillSnipe).projectile_speed += 300
					(s as SkillSnipe).aoe_on_hit *= 2.0
					s.skill_name = "弑神之箭"
					s.description = "一击入魂，毁天灭地"
