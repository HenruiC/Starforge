class_name AssetManager
extends Node

# 资产管理器 — 杨奇监修
# 占位符→生成图片的无缝切换

const ASSET_DIR := "res://assets/"
const GEN_DIR := "res://assets/generated/"

# 当前使用的资产源: "placeholder" / "generated"
var _mode: String = "placeholder"

static var instance: AssetManager

func _ready() -> void:
	instance = self
	_check_available_assets()

func _check_available_assets() -> void:
	var dir := DirAccess.open(GEN_DIR)
	if dir:
		var files := dir.get_files()
		if files.size() > 0:
			_mode = "generated"

# 获取纹理 — 优先用生成的，fallback到占位符
func get_texture(name: String, placeholder_color: Color = Color.GRAY) -> Texture2D:
	if _mode == "generated":
		var path := GEN_DIR + name + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D

	var placeholder_path := ASSET_DIR + name + ".png"
	if ResourceLoader.exists(placeholder_path):
		return load(placeholder_path) as Texture2D

	# 完全无资源时返回占位色块(运行时生成)
	return _make_placeholder_texture(placeholder_color)

func _make_placeholder_texture(color: Color) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func set_mode(mode: String) -> void:
	_mode = mode

func get_mode() -> String:
	return _mode
