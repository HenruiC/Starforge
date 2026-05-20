import sys

with open('D:/AI/GodotProjects/combat-demo/scripts/enemy.gd', 'r', encoding='utf-8') as f:
    content = f.read()

changes = 0

# CHANGE 1: Remove @export from detection_range and preferred_distance
old1 = '@export var preferred_distance: float = 180.0'
if old1 in content:
    content = content.replace(old1, 'var preferred_distance: float = 180.0')
    changes += 1
    print("CHANGE 1a done: preferred_distance @export removed")

old1b = '@export var detection_range: float = 600.0'
if old1b in content:
    new1b = 'var detection_range: float = 600.0  # set from AIEnemyConfig'
    content = content.replace(old1b, new1b)
    changes += 1
    print("CHANGE 1b done: detection_range @export removed")

# CHANGE 2: Add ai_config export and berserk fields
old2 = '# 闪避中\nvar _is_dodging: bool = false'
new2 = '# 闪避中\nvar _is_dodging: bool = false\n\n# AI 配置（由 AIEnemyConfig Resource 驱动，零硬编码行为参数）\n@export var ai_config: AIEnemyConfig = null\n\n# 狂暴系统\nvar _is_berserk: bool = false\nvar _berserk_timer: float = 0.0\nvar _berserk_duration: float = 4.0\nvar _berserk_speed_mult: float = 1.5\nvar _berserk_cooldown_mult: float = 0.5\nvar _ignore_coordinator: bool = false'
if old2 in content:
    content = content.replace(old2, new2)
    changes += 1
    print("CHANGE 2 done: added ai_config and berserk fields")
else:
    print("CHANGE 2 FAIL: old2 not found")

# CHANGE 3: Modify _ready() end
old3 = '\t\t# 根据类型调整碰撞体大小\n\t\t_setup_collision_size()'
new3 = '\t\t# 根据类型调整碰撞体大小\n\t\t_setup_collision_size()\n\n\t\t# 加载 AI 配置（未赋值时按敌人类型选择默认配置）\n\t\tif ai_config == null:\n\t\t\tai_config = _load_default_config()\n\t\t_apply_ai_config()\n\t\t_setup_navigation_agent()'
if old3 in content:
    content = content.replace(old3, new3, 1)
    changes += 1
    print("CHANGE 3 done: _ready() extended with config + nav setup")
else:
    print("CHANGE 3 FAIL: old3 not found")

# CHANGE 4: Add berserk timer to _physics_process()
old4 = '\tfunc _physics_process(delta: float) -> void:\n\t\tif is_dead or _player_ref == null: return'
new4 = '\tfunc _physics_process(delta: float) -> void:\n\t\tif is_dead or _player_ref == null: return\n\t\t# 狂暴计时更新\n\t\tif _is_berserk:\n\t\t\t_berserk_timer += delta\n\t\t\tif _berserk_timer >= _berserk_duration:\n\t\t\t\t_on_berserk_expired()'
if old4 in content:
    content = content.replace(old4, new4, 1)
    changes += 1
    print("CHANGE 4 done: berserk timer in _physics_process()")
else:
    print("CHANGE 4 FAIL: old4 not found")

# CHANGE 5: Replace _melee_behavior()
old5 = '\tfunc _melee_behavior(delta: float) -> void:\n\t\tif not _player_ref:\n\t\t\treturn\n\t\t# 包围战术状态\n\t\tif _is_rushing or _is_dodging:\n\t\t\treturn\n\t\tvar melee_count: int = _count_nearby_melee()\n\t\tvar direction := global_position.direction_to(_player_ref.global_position)\n\t\tif melee_count >= 3:\n\t\t\t_flank_timer += delta\n\t\t\tif _flank_timer >= _flank_reassess_interval or _assigned_flank == 0:\n\t\t\t\t_flank_timer = 0.0\n\t\t\t\t_assigned_flank = 1 if randf() > 0.5 else -1\n\t\t\t\t_flank_angle = PI / 4.0 * float(_assigned_flank)\n\t\t\tvar flank_dir := direction.rotated(_flank_angle)\n\t\t\tvelocity = (flank_dir * 0.7 + direction * 0.3).normalized() * move_speed\n\t\telse:\n\t\t\tvelocity = direction * move_speed\n\t\tmove_and_slide()'

print("CHANGE 5 check...")
idx5 = content.find('func _melee_behavior')
if idx5 >= 0:
    # Find the end of the function (next function def or section header)
    end5 = content.find('\n\tfunc ', idx5 + 1)
    if end5 < 0:
        end5 = content.find('\n# ====', idx5 + 1)
    old_melee = content[idx5:end5]
    new_melee = '''\tfunc _melee_behavior(delta: float) -> void:
\t\tif not _player_ref:
\t\t\treturn
\t\tif _is_rushing or _is_dodging:
\t\t\treturn

\t\tvar speed := move_speed
\t\tif _is_berserk:
\t\t\tspeed *= _berserk_speed_mult

\t\t# NavigationAgent2D 路径追踪（由 _setup_navigation_agent 初始化）
\t\t_nav_agent.target_position = _player_ref.global_position
\t\tvar next_pos := _nav_agent.get_next_path_position()
\t\tif next_pos != Vector2.ZERO:
\t\t\tvar dir := global_position.direction_to(next_pos)
\t\t\tvelocity = dir * speed
\t\telse:
\t\t\t# NavAgent 尚未返回有效路径，不动（等待烘焙完成）
\t\t\tvelocity = Vector2.ZERO

\t\tmove_and_slide()
'''
    content = content[:idx5] + new_melee + content[end5:]
    changes += 1
    print("CHANGE 5 done: _melee_behavior() rewritten with NavigationAgent2D")
else:
    print("CHANGE 5 FAIL: func _melee_behavior not found")

# CHANGE 6: Add berserk trigger to take_damage()
old6a = '\t\tif _health <= 0:\n\t\t\t_die()'
new6a = '\t\t# 狂暴系统触发\n\t\t_check_berserk_trigger()\n\n\t\tif _health <= 0:\n\t\t\t_die()'
# Find the LAST occurrence (in take_damage, not in any other function)
# Count occurrences
count6 = content.count(old6a)
if count6 >= 1:
    # Replace the LAST occurrence (the one in take_damage, not _die itself)
    # _die() also contains this pattern, but we want the one in take_damage
    # The one in take_damage is followed by _show_hit_effect or similar
    # Let's use a broader context
    old6b = '\t\t_show_hit_effect()\n\n\t\tif _health <= 0:\n\t\t\t_die()'
    new6b = '\t\t_show_hit_effect()\n\n\t\t# 狂暴系统触发\n\t\t_check_berserk_trigger()\n\n\t\tif _health <= 0:\n\t\t\t_die()'
    if old6b in content:
        content = content.replace(old6b, new6b, 1)
        changes += 1
        print("CHANGE 6 done: berserk trigger in take_damage()")
    else:
        print("CHANGE 6 FAIL: old6b not found")
else:
    print("CHANGE 6 FAIL: pattern not found")

# CHANGE 7: Add new methods after _show_hit_effect / before knockback
old_knockback = '\tfunc knockback(force: Vector2) -> void:'
if old_knockback in content:
    new_methods = '''\t# =============================================================================
\t# 狂暴系统
\t# =============================================================================

\tfunc _check_berserk_trigger() -> void:
\t\tif is_dead:
\t\t\treturn
\t\tif is_boss:
\t\t\treturn
\t\tif not ai_config or not ai_config.berserk_enabled:
\t\t\treturn
\t\tif _is_berserk:
\t\t\t_berserk_timer = 0.0
\t\t\treturn
\t\t_enter_berserk()

\tfunc _enter_berserk() -> void:
\t\t_is_berserk = true
\t\t_berserk_timer = 0.0
\t\t_ignore_coordinator = true

\t\t# StatModifier: 移速 +50%
\t\tif stats:
\t\t\tvar speed_mod := StatModifier.new()
\t\t\tspeed_mod.stat_name = "move_speed"
\t\t\tspeed_mod.mod_type = StatModifier.ModType.PERCENT_ADD
\t\t\tspeed_mod.value = _berserk_speed_mult - 1.0
\t\t\tspeed_mod.source_id = "berserk"
\t\t\tstats.add_modifier(speed_mod)

\t\t# 视觉: BERSERK 状态
\t\tvar visual_sm := get_node_or_null("VisualStateMachine") as EnemyVisualStateMachine
\t\tif visual_sm:
\t\t\tvisual_sm.push_state(EnemyVisualStateMachine.VisualState.BERSERK)

\t\t# 精英/Boss 激怒周围小怪
\t\tif (is_elite or is_boss) and ai_config and ai_config.enrage_radius > 0.0:
\t\t\t_enrage_nearby_minions()

\t\t# 通知攻击协调器取消排队
\t\tvar coordinator := _get_coordinator()
\t\tif coordinator:
\t\t\tcoordinator.cancel_attack(self)

\tfunc _on_berserk_expired() -> void:
\t\t_is_berserk = false
\t\t_ignore_coordinator = false

\t\t# 移除 StatModifier
\t\tif stats:
\t\t\tstats.remove_modifiers_by_source("berserk")

\t\t# 弹出视觉状态
\t\tvar visual_sm := get_node_or_null("VisualStateMachine") as EnemyVisualStateMachine
\t\tif visual_sm:
\t\t\tvisual_sm.pop_state(EnemyVisualStateMachine.VisualState.BERSERK)

\tfunc _enrage_nearby_minions() -> void:
\t\tvar tree := get_tree()
\t\tif not tree:
\t\t\treturn
\t\tvar radius := ai_config.enrage_radius if ai_config else 500.0
\t\tvar all_enemies := tree.get_nodes_in_group("enemies")
\t\tfor e in all_enemies:
\t\t\tif e == self:
\t\t\t\tcontinue
\t\t\tvar enemy := e as Enemy
\t\t\tif enemy and not enemy.is_boss and not enemy.is_elite and not enemy._is_berserk:
\t\t\t\tvar dist := global_position.distance_to(enemy.global_position)
\t\t\t\tif dist < radius:
\t\t\t\t\tenemy._enter_berserk()

\tfunc _get_coordinator() -> AttackCoordinator:
\t\tvar tree := get_tree()
\t\tif tree and tree.root.has_node("Coordinator"):
\t\t\treturn tree.root.get_node("Coordinator") as AttackCoordinator
\t\treturn null

\t# =============================================================================
\t# AI 配置加载
\t# =============================================================================

\tfunc _load_default_config() -> AIEnemyConfig:
\t\tif is_boss:
\t\t\treturn AIEnemyConfig.boss_sato()
\t\tif is_elite:
\t\t\treturn AIEnemyConfig.elite_default()
\t\tif is_ranged:
\t\t\treturn AIEnemyConfig.ranged_default()
\t\treturn AIEnemyConfig.melee_default()

\tfunc _apply_ai_config() -> void:
\t\tif not ai_config:
\t\t\treturn
\t\tdetection_range = ai_config.detection_range
\t\tpreferred_distance = ai_config.preferred_distance
\t\t_berserk_duration = ai_config.berserk_duration
\t\t_berserk_speed_mult = ai_config.berserk_speed_mult
\t\t_berserk_cooldown_mult = ai_config.berserk_cooldown_mult

\t# =============================================================================
\t# NavigationAgent2D 初始化
\t# =============================================================================

\tfunc _setup_navigation_agent() -> void:
\t\tif not ai_config or not ai_config.use_nav_agent:
\t\t\treturn
\t\t_nav_agent = NavigationAgent2D.new()
\t\t_nav_agent.name = "NavAgent"
\t\t_nav_agent.path_desired_distance = 8.0
\t\t_nav_agent.target_desired_distance = 24.0
\t\t_nav_agent.radius = 10.0
\t\tadd_child(_nav_agent)

\tfunc knockback(force: Vector2) -> void:'''
    content = content.replace(old_knockback, new_methods, 1)
    changes += 1
    print("CHANGE 7 done: added berserk + config + nav methods")
else:
    print("CHANGE 7 FAIL: knockback not found")

# Write back
with open('D:/AI/GodotProjects/combat-demo/scripts/enemy.gd', 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nAll done! {changes} changes applied.")
sys.exit(0 if changes >= 7 else 1)
