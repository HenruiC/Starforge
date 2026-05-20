class_name DialogueEntry
extends Resource

## 单条对话 — 谁说、说什么、什么节奏

@export var speaker: String = ""
@export_multiline var text: String = ""
@export var text_speed: float = 0.02
@export var duration: float = 0.0
@export var text_color: Color = Color.WHITE
## 下一条索引（-1=末尾，触发分支或推进组）
@export var next_entry: int = -1
