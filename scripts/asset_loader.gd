class_name AssetLoader
extends Node

# 资产加载器 v3 — PNG优先，JPG fallback，完整NAME_MAP
# 杨奇监修：暗而不黑，质感优先于特效

const GEN_DIR := "res://assets/generated/"

# 全量映射 — 9个技能 + 3个武器，不依赖隐式拼接
const NAME_MAP := {
	# 技能图标 (9)
	"icon_chain_lightning": "icon_lightning",
	"icon_ice_nova": "icon_ice",
	"icon_fire_trail": "icon_fire",
	"icon_shadow_clone": "icon_shadow",
	"icon_slash": "icon_slash",
	"icon_aoe": "icon_aoe",
	"icon_multi_shot": "icon_multi_shot",
	"icon_whirlwind": "icon_whirlwind",
	"icon_snipe": "icon_snipe",
	# 武器图标 (3)
	"weapon_sword": "weapon_sword",
	"weapon_bow": "weapon_bow",
	"weapon_staff": "weapon_staff",
}

static var _cache: Dictionary = {}

static func texture(tex_name: String, _size: int = 64, fallback_color: Color = Color.GRAY) -> Texture2D:
	if _cache.has(tex_name):
		return _cache[tex_name] as Texture2D

	var mapped: String = NAME_MAP.get(tex_name, tex_name)

	# 1. PNG 优先 — ResourceLoader (需要.import)
	var png_path := GEN_DIR + mapped + ".png"
	if ResourceLoader.exists(png_path) and FileAccess.file_exists(png_path):
		var r := load(png_path)
		if r:
			_cache[tex_name] = r
			return r

	# 2. PNG — FileAccess 直接读字节 (不依赖导入)
	var png_img := _load_png(png_path)
	if png_img:
		var tex := ImageTexture.create_from_image(png_img)
		_cache[tex_name] = tex
		return tex

	# 3. JPG fallback — ResourceLoader
	var jpg_path := GEN_DIR + mapped + ".jpg"
	if ResourceLoader.exists(jpg_path):
		var r := load(jpg_path)
		if r:
			_cache[tex_name] = r
			return r

	# 4. JPG — FileAccess 直接读字节
	var jpg_img := _load_jpg(jpg_path)
	if jpg_img:
		var tex := ImageTexture.create_from_image(jpg_img)
		_cache[tex_name] = tex
		return tex

	# 5. 绝对路径 fallback
	var abs_path := "D:/AI/GodotProjects/combat-demo/assets/generated/" + mapped + ".png"
	var abs_img := _load_png(abs_path)
	if abs_img:
		var tex := ImageTexture.create_from_image(abs_img)
		_cache[tex_name] = tex
		return tex

	var abs_jpg := "D:/AI/GodotProjects/combat-demo/assets/generated/" + mapped + ".jpg"
	var abs_jpg_img := _load_jpg(abs_jpg)
	if abs_jpg_img:
		var tex := ImageTexture.create_from_image(abs_jpg_img)
		_cache[tex_name] = tex
		return tex

	# Fallback: 纯色
	var fb := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	fb.fill(fallback_color)
	var t := ImageTexture.create_from_image(fb)
	_cache[tex_name] = t
	return t

static func _load_jpg(res_path: String) -> Image:
	if not FileAccess.file_exists(res_path):
		return null
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return null
	var buf := f.get_buffer(f.get_length())
	if buf.size() == 0:
		return null
	var img := Image.new()
	if img.load_jpg_from_buffer(buf) == OK:
		return img
	return null

static func _load_png(res_path: String) -> Image:
	if not FileAccess.file_exists(res_path):
		return null
	var f := FileAccess.open(res_path, FileAccess.READ)
	if f == null:
		return null
	var buf := f.get_buffer(f.get_length())
	if buf.size() == 0:
		return null
	var img := Image.new()
	if img.load_png_from_buffer(buf) == OK:
		return img
	return null

static func clear_cache() -> void:
	_cache.clear()
