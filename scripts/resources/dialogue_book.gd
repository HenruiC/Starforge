class_name DialogueBook
extends Resource

## 对话书 — 所有组 + 起始组

@export var book_id: String = ""
@export var book_name: String = ""
@export var groups: Array[DialogueGroup] = []
@export var start_group_id: String = ""

## 按 ID 查找组
func find_group(gid: String) -> DialogueGroup:
	for g: DialogueGroup in groups:
		if g.group_id == gid:
			return g
	return null
