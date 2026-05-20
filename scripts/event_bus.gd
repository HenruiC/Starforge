extends Node

# 全局事件总线 — Autoload 单例
# 所有信号由外部脚本 emit/connect，本类不直接使用
# @warning_ignore 每行单独标注

@warning_ignore("unused_signal")
signal enemy_killed(position: Vector2, score_value: int)
@warning_ignore("unused_signal")
signal enemy_killed_filtered(position: Vector2, score_value: int, is_elite: bool, is_boss: bool, is_ranged: bool)
@warning_ignore("unused_signal")
signal player_hit(damage: int, current_hp: int)
@warning_ignore("unused_signal")
signal player_died(kill_count: int)
@warning_ignore("unused_signal")
signal wave_changed(wave: int)
@warning_ignore("unused_signal")
signal player_entered_zone(zone_id: String)
@warning_ignore("unused_signal")
signal player_exited_zone(zone_id: String)

# === Boss 战斗信号 ===
@warning_ignore("unused_signal")
signal boss_approach_started(boss_id: String)
@warning_ignore("unused_signal")
signal boss_activated(boss_id: String)
@warning_ignore("unused_signal")
signal boss_phase_changed(phase: int, phase_name: String)
@warning_ignore("unused_signal")
signal boss_attack_started(attack_id: String, windup_duration: float)
@warning_ignore("unused_signal")
signal boss_executing(boss_id: String)  # "Boss 正在死亡"（区别于 killed）
@warning_ignore("unused_signal")
signal boss_killed(boss_id: String, position: Vector2, boss_name: String)
@warning_ignore("unused_signal")
signal boss_defeated

# 小怪反制 — 技能施放检测（用于近战冲刺突进）
@warning_ignore("unused_signal")
signal skill_cast(skill_type: String, caster_pos: Vector2)

# === 任务系统 V2 信号 ===
@warning_ignore("unused_signal")
signal door_unlock_requested(door_id: String)                                        # 门解锁请求
@warning_ignore("unused_signal")
signal protectable_destroyed(object_id: String)                                      # 保护目标被摧毁
@warning_ignore("unused_signal")
signal protectable_damaged(object_id: String, current_hp: int, max_hp: int)          # 保护目标受伤
@warning_ignore("unused_signal")
signal defend_zone_state_changed(zone_id: String, is_active: bool)                    # 驻守区状态变更
@warning_ignore("unused_signal")
signal dialogue_triggered(book: DialogueBook, group_id: String)                        # 任务系统触发对话
