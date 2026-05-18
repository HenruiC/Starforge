class_name AssetLoader
extends Node

# 统一资产加载器 — 马斯克架构
# 解决: 1)JPG导入链 2)文件名映射 3)导出兼容 4)fallback占位

const GEN_DIR := "res://assets/generated/"

# 文件名映射: skill_id → 实际文件名
const NAME_MAP := {
	"icon_chain_lightning": "icon_lightning",
	"icon_ice_nova": "icon_ice",
	"icon_fire_trail": "icon_fire",
	"icon_shadow_clone": "icon_shadow",
}

static var _cache: Dictionary = {}

# 加载纹理
static func texture(name: String, size: int = 64, fallback_color: Color = Color.GRAY) -> Texture2D:
	# 检查缓存
	if _cache.has(name): return _cache[name] as Texture2D

	# 尝试1: .import + load (导出兼容)
	var mapped: String = NAME_MAP.get(name, name)
	var paths := [
		GEN_DIR + mapped + ".jpg",
		GEN_DIR + mapped + ".png",
		GEN_DIR + name + ".jpg",
		GEN_DIR + name + ".png",
	]
	for p in paths:
		if ResourceLoader.exists(p):
			var tex := load(p) as Texture2D
			if tex:
				_cache[name] = tex
				return tex

	# 尝试2: Image.load (编辑器中可靠)
	var img := Image.new()
	for p in paths:
		if img.load(p) == OK:
			var tex := ImageTexture.create_from_image(img)
			_cache[name] = tex
			return tex

	# 尝试3: 绝对路径
	var abs: String = "D:/AI/GodotProjects/combat-demo/assets/generated/" + mapped + ".jpg"
	var abs2: String = abs.replace(".jpg", ".png")
	for ap in [abs, abs2]:
		var img2 := Image.new()
		if img2.load(ap) == OK:
			var tex := ImageTexture.create_from_image(img2)
			_cache[name] = tex
			return tex

	# Fallback: 纯色占位
	var placeholder := Image.create(size, size, false, Image.FORMAT_RGBA8)
	placeholder.fill(fallback_color)
	var pt := ImageTexture.create_from_image(placeholder)
	_cache[name] = pt
	return pt

# 清除缓存(热重载用)
static func clear_cache() -> void:
	_cache.clear()
