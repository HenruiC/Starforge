class_name MissionChain
extends Resource

enum ChainStatus { IDLE, RUNNING, COMPLETED, FAILED }

@export var chain_id: String = ""
@export var chain_name: String = ""
@export var stages: Array[MissionStage] = []
@export var is_repeatable: bool = false

# 可选：动态创建的 Zone 区域定义
# 每条：{zone_id: String, position: Vector2, size: Vector2}
@export var zone_definitions: Array[Dictionary] = []

# 运行时状态
var status: int = ChainStatus.IDLE
var current_stage_index: int = 0
