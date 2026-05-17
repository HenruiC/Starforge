extends Node

# 全局事件总线 — Autoload 单例

signal enemy_killed(position: Vector2, score_value: int)
signal player_hit(damage: int, current_hp: int)
signal player_died(kill_count: int)
signal wave_changed(wave: int)
