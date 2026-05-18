class_name AssetLoader
extends Node

# 资产加载器 v2 — FileAccess直接读取JPG字节，绕过Godot导入系统

const GEN_DIR := "res://assets/generated/"

const NAME_MAP := {
	"icon_chain_lightning": "icon_lightning",
	"icon_ice_nova": "icon_ice",
	"icon_fire_trail": "icon_fire",
	"icon_shadow_clone": "icon_shadow",
}

static var _cache: Dictionary = {}

static func texture(tex_name: String, _size: int = 64, fallback_color: Color = Color.GRAY) -> Texture2D:
	if _cache.has(tex_name):
		return _cache[tex_name] as Texture2D

	var mapped: String = NAME_MAP.get(tex_name, tex_name)
	var path := GEN_DIR + mapped + ".jpg"

	# 1. 尝试 ResourceLoader (需要.import)
	if ResourceLoader.exists(path):
		var r := load(path)
		if r:
			_cache[tex_name] = r
			return r

	# 2. FileAccess 直接读JPG字节 (不依赖导入)
	var img := _load_jpg(path)
	if img:
		var tex := ImageTexture.create_from_image(img)
		_cache[tex_name] = tex
		return tex

	# 3. PNG fallback
	var png_path := GEN_DIR + mapped + ".png"
	var img2 := _load_png(png_path)
	if img2:
		var tex := ImageTexture.create_from_image(img2)
		_cache[tex_name] = tex
		return tex

	# 4. 绝对路径
	var abs_path := "D:/AI/GodotProjects/combat-demo/assets/generated/" + mapped + ".jpg"
	var img3 := _load_jpg(abs_path)
	if img3:
		var tex := ImageTexture.create_from_image(img3)
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
