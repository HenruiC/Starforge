class_name DamageNumber
extends Label

func _ready() -> void:
	z_index = 25
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 18)

func setup(display_text: String, color: Color = Color.WHITE, display_scale: float = 1.0) -> void:
	self.text = display_text
	self.scale = Vector2(display_scale, display_scale)
	add_theme_color_override("font_color", color)

	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y - 40, 0.7).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.15)
	t.tween_property(self, "scale", Vector2(display_scale * 1.3, display_scale * 1.3), 0.1)
	t.chain().tween_property(self, "scale", Vector2(display_scale, display_scale), 0.15)
	t.chain().tween_callback(queue_free)
