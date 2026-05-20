class_name BossAttackData
extends Resource

## Boss 单个攻击的完整参数规格

## 唯一标识
@export var attack_id: String = ""
## 可读名称（调试用）
@export var attack_name: String = ""

## 前摇总时长（秒）
@export var windup_duration: float = 0.4
## 前摇进行到此比例时锁定方向（0=开始锁定, 1=结束时锁定）
@export var direction_lock_ratio: float = 0.6
## 前摇期间移速倍率
@export var windup_move_speed_mult: float = 0.2

## 基础伤害
@export var damage: int = 10
## 伤害判定窗口时长
@export var active_frame_duration: float = 0.1

## 攻击范围（扇形半径 / 圆形半径）
@export var range: float = 120.0

## 硬直时长
@export var recovery_duration: float = 0.3
## 硬直期间移速倍率
@export var recovery_move_speed_mult: float = 0.0
## 硬直期间能否发起新攻击
@export var recovery_can_attack: bool = false

## AOE 圆形半径（0 = 非 AOE）
@export var aoe_radius: float = 0.0
## 扇形角度（0 = 非扇形）
@export var cone_angle: float = 0.0
## 扇形范围
@export var cone_range: float = 0.0

## 投射物速度（0 = 非投射物攻击）
@export var projectile_speed: float = 0.0
## 投射物数量
@export var projectile_count: int = 1

## 突进速度（0 = 无位移）
@export var dash_speed: float = 0.0
## 突进距离
@export var dash_distance: float = 0.0
## 撞墙额外硬直
@export var wall_collision_extra_recovery: float = 0.3
