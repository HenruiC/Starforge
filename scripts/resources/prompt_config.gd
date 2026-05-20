class_name PromptConfig
extends Resource

@export var text: String = ""
@export var text_color: Color = Color.WHITE
@export var show_arrow: bool = false
@export var arrow_target: Vector2 = Vector2.ZERO
@export var arrow_target_zone: String = ""
@export var display_duration: float = 0.0   # 0 = 直到 Stage 完成
@export var animation: String = "slide_down"
@export var priority: int = 0
@export var sound_id: String = ""
