class_name DialogueGroup
extends Resource

## 对话组 — 一组有序条目 + 分支选项

@export var group_id: String = ""
@export var group_name: String = ""
## 对话条目列表（按数组顺序播放）
@export var entries: Array[DialogueEntry] = []
## 分支选项（末尾触发，空=自动推进到 next_group_id）
@export var choices: Array[DialogueChoice] = []
## 无分支时自动跳转的目标组
@export var next_group_id: String = ""
