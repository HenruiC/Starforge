class_name DialogueData
extends Resource

## 单条对话 — 谁说、说什么、什么节奏

## 说话人名称
@export var speaker: String = ""
## 头像资源路径（可选，如 "res://assets/portraits/sato.png"）
@export var portrait: String = ""
## 对话文本
@export_multiline var text: String = ""
## 打字机速度（秒/字），0.02 为默认节奏
@export var text_speed: float = 0.02
## 显示时长（秒），0 = 等待玩家按键推进
@export var duration: float = 0.0
## 文字颜色
@export var text_color: Color = Color.WHITE
