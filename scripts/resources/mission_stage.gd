class_name MissionStage
extends Resource

enum StageStatus { PENDING, ACTIVE, COMPLETED, FAILED }

@export var stage_id: int = 0
@export var stage_title: String = ""

# null = 上个 Stage 完成后自动激活
@export var activation_condition: TriggerConfig = null

@export var objectives: Array[MissionObjective] = []

@export var on_activate_prompt: PromptConfig = null
@export var on_complete_prompt: PromptConfig = null

# 阶段切换时的对话消息：{speaker, text}（旧格式，保留兼容）
@export var dialogue_messages: Array[Dictionary] = []
## Stage 激活时播放的对话（DialogueBook 引用）
@export var on_activate_dialogue: DialogueBook = null
## Stage 激活时播放的起始组
@export var on_activate_dialogue_group: String = ""
## Stage 完成时播放的对话
@export var on_complete_dialogue: DialogueBook = null
@export var on_complete_dialogue_group: String = ""

# 运行时状态
var status: int = StageStatus.PENDING
