class_name MissionObjective
extends Resource

@export var objective_id: String = ""
@export var description: String = ""
@export var hint: String = ""
@export var trigger: TriggerConfig = null
@export var is_optional: bool = false
@export var show_progress_bar: bool = true

# 完成奖励
@export var reward_xp: int = 0
@export var reward_heal: int = 0

## Objective 完成后触发的世界动作（纯数据配置，不绑定任何 Trigger 类型）
## 协议格式：{"type": "unlock_door", "door_id": "gym_lock_door"}
## 扩展：{"type": "spawn_wave", "wave_config_id": "..."}
@export var completion_action: Dictionary = {}

## 可选：此 Objective 依赖的前置 Objective ID
## 为空 = Stage 激活时即开始追踪（默认）
@export var depends_on_objective: String = ""
## Objective 完成时播放的对话
@export var on_complete_dialogue: DialogueBook = null
@export var on_complete_dialogue_group: String = ""
