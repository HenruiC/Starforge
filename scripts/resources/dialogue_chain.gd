class_name DialogueChain
extends Resource

## 对话序列 — 多条 DialogueData 组成一段完整对话

## 对话链唯一标识
@export var dialogue_id: String = ""
## 对话条目列表
@export var entries: Array[DialogueData] = []


## 总对话条数
func count() -> int:
	return entries.size()


## 获取指定索引的对话
func get_entry(idx: int) -> DialogueData:
	if idx >= 0 and idx < entries.size():
		return entries[idx]
	return null


## 添加一条对话
func add_entry(speaker: String, text: String) -> DialogueData:
	var d := DialogueData.new()
	d.speaker = speaker
	d.text = text
	entries.append(d)
	return d


## 创建一个简单的单人说对话链
static func simple(speaker: String, text: String) -> DialogueChain:
	var chain := DialogueChain.new()
	chain.dialogue_id = "simple"
	chain.add_entry(speaker, text)
	return chain
