# Boss 机制强化 + AI 包围战术 — 实施设计

> 宫崎英高, 战斗策划, Starforge 工作室
> 2026-05-19
>
> 回应反馈 #3/4/6/7：Boss 攻击太简单、出场不够震撼、小怪 AI 不会包围、整体太简单

---

## 0. 改动范围总览

| 文件 | 改动行 | 内容 |
|------|--------|------|
| `scripts/game_manager.gd` | L1046-1104 (`_spawn_boss_now`) | 重写 Boss 出场序列 (2s 戏剧性暂停) |
| `scripts/game_manager.gd` | L179-186 (插入新函数) | 新增 `_boss_entrance_sequence()` |
| `scripts/enemy.gd` | L85-98 (`_physics_process`) | 传递 delta 给 `_melee_behavior` / `_ranged_behavior` |
| `scripts/enemy.gd` | L100-103 (`_melee_behavior`) | 包围战术：3+ 敌人时外侧包抄 |
| `scripts/enemy.gd` | L105-121 (`_ranged_behavior`) | 远程对角线站位 |
| `scripts/enemy.gd` | L385-389 (`_boss_behavior`) | 注入 Phase 感知的特殊攻击逻辑 |
| `scripts/enemy.gd` | L243-383 (`_build_boss_systems`) | 新增 3 个 Boss 技能槽 + 特殊攻击状态变量 |
| `scripts/boss/boss_ai.gd` | L94-125 (`tick`), L130-171 (`_movement_phaseX`) | 注入特殊攻击冷却计时 |

---

## 1. Boss 出场演出 — 宫崎英高式沉默时刻

### 1.1 设计目标

玩家走进体育馆 zone_gym_boss 后：
- 游戏暂停 2 秒 — 画面定格，HUD 全部消退
- 暗角加深到最大 (alpha 0.9) — 视野收窄，制造不安
- Boss 从阴影中缓缓现身 (modulate.a 0→1, 1.5s)
- Camera2D 以不同频率连续震动 — 压迫感
- 大字 "三年二班 体育教师 · 佐藤 幸雄" 居中浮现
- 然后 Boss HP 条出现，HUD 恢复，战斗开始

### 1.2 game_manager.gd : `_spawn_boss_now()` 完整重写

**文件**: `scripts/game_manager.gd`
**位置**: L1046-1104 (替换整个 `_spawn_boss_now` 函数体)

```gdscript
func _spawn_boss_now() -> void:
    # ============================================================
    # 第一步：创建 Boss 实体，暂不可见
    # ============================================================
    var e: CharacterBody2D = _enemy_scene.instantiate()
    e.global_position = Vector2(1584, 420)
    e.is_boss = true
    e.max_health = _dungeon_config.s3_boss_hp if _dungeon_config else 1600
    e.score_value = 10
    e.xp_value = 100
    e.modulate = Color(1, 1, 1, 0)  # 完全透明 — 从阴影中现身
    e.set_process(false)              # 冻结 AI，出场期间不行动
    e.set_physics_process(false)
    _boss_enemy = e
    enemies.add_child(e)

    # ============================================================
    # 第二步：2s 沉默时刻 — 画面定格 + HUD 消退 + 暗角最深
    # ============================================================
    # 暂停游戏 (注意: get_tree().paused 会冻结所有 Tween,
    # 我们必须用 Engine.time_scale = 0 配合 CombatFeedback 的模式)
    var original_time_scale: float = Engine.time_scale
    Engine.time_scale = 0.0  # 冻结物理/process，但 Tween (IDLE 模式) 继续

    # 暗角拉到最深 (0.9 alpha) — 比战斗时 (0.6) 更深
    if _vignette_controller and is_instance_valid(_vignette_controller):
        # 直接用 0.5s 渐变（比 BOSS_BATTLE 状态 0.6 更深）
        UIEffects.kill_group("hud_vignette")
        var vignette_overlay: TextureRect = _vignette_controller.get_node_or_null("VignetteOverlay") as TextureRect
        if vignette_overlay:
            var v_tween: Tween = vignette_overlay.create_tween()
            v_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
            v_tween.tween_property(vignette_overlay, "modulate:a", 0.9, 0.5)

    # HUD 完全消退 (silence_controller 可能已触发，确保)
    if _silence_controller and is_instance_valid(_silence_controller):
        _silence_controller.trigger_silence()

    # SFX: 低沉轰鸣 (实体化 AudioStreamPlayer 或触发信号)
    # AudioManager.play("boss_entrance_rumble")  # 如果后续接入音频系统

    # 等待 2s — 这是沉默时刻的核心
    # Tween delay 不受 time_scale 影响(IDLE 模式)
    await get_tree().create_timer(2.0, false, true).timeout  # ignore_time_scale=true

    # ============================================================
    # 第三步：Boss 从阴影中现身 (modulate.a 0→1, 1.5s)
    # ============================================================
    var appear_tween: Tween = create_tween()
    appear_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
    appear_tween.tween_property(e, "modulate", Color.WHITE, 1.5)

    # 暗角从 0.9 退回到战斗水平 0.6
    if _vignette_controller and is_instance_valid(_vignette_controller):
        # 在 Boss 现身到一半时 (>0.7s) 暗角开始回退
        var vg_delay_tween: Tween = create_tween()
        vg_delay_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
        vg_delay_tween.tween_interval(0.7)
        vg_delay_tween.tween_callback(func():
            if _vignette_controller and is_instance_valid(_vignette_controller):
                _vignette_controller.set_state(VignetteController.State.BOSS_BATTLE, 0.8)
        )

    # ============================================================
    # 第四步：连续震动 — 在 Boss 半现身时触发
    # ============================================================
    # 第 1 次震动 (t=0.7s) — Boss 半透明，开始显现力量
    await get_tree().create_timer(0.7, false, true).timeout
    CombatFeedback.screen_shake(6.0)

    # 第 2 次震动 (t=1.1s) — Boss 几乎完全现身
    await get_tree().create_timer(0.4, false, true).timeout
    CombatFeedback.screen_shake(9.0)

    # 第 3 次震动 (t=1.5s) — Boss 完全现身，战斗即将开始
    await get_tree().create_timer(0.4, false, true).timeout
    CombatFeedback.screen_shake(12.0)

    # ============================================================
    # 第五步：大字标题 — Boss 名称揭示
    # ============================================================
    var reveal_label := Label.new()
    reveal_label.name = "BossNameReveal"
    reveal_label.text = "三年二班 体育教师 · 佐藤 幸雄"
    reveal_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
    reveal_label.add_theme_font_size_override("font_size", 32)  # 大字
    reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    reveal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    reveal_label.modulate = Color(1, 1, 1, 0)
    reveal_label.size = get_viewport().get_visible_rect().size
    $"../HUDLayer".add_child(reveal_label)
    reveal_label.z_index = 20

    # 名称从透明淡入 → 停留 1.8s → 淡出
    var reveal_tween: Tween = create_tween()
    reveal_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
    reveal_tween.tween_property(reveal_label, "modulate", Color.WHITE, 0.4)
    reveal_tween.tween_interval(1.8)
    reveal_tween.tween_property(reveal_label, "modulate:a", 0.0, 0.5)
    reveal_tween.tween_callback(func():
        if is_instance_valid(reveal_label):
            reveal_label.queue_free()
    )

    # ============================================================
    # 第六步：恢复游戏 — Boss AI 激活，战斗开始
    # ============================================================
    Engine.time_scale = original_time_scale
    e.set_process(true)
    e.set_physics_process(true)

    # Boss 血条显示
    if _boss_hp_bar and is_instance_valid(_boss_hp_bar):
        _boss_hp_bar.enter()
        _boss_hp_bar.set_hp(e.max_health, e.max_health)

    # 标记 Boss 战激活
    _boss_fight_active = true

    # 沉默结束：HUD 恢复
    if _silence_controller and is_instance_valid(_silence_controller):
        _silence_controller.trigger_restore()

    # 广播 Boss 激活
    EventBus.boss_activated.emit("boss_sato")
    EventBus.boss_phase_changed.emit(1, "热身")

    # Phase 4 — 递增 Boss 遭遇次数（仪式感递减）
    GamePersistence.increment_boss_encounter_count()
```

**关键时序总结**:

```
t=0.0s   进入体育馆 → time_scale=0, 暗角 alpha→0.9, HUD 消退
t=0.0s   沉默开始 — 画面定格，玩家只能看
t=2.0s   沉默结束 — Boss 开始现身 (modulate.a 0→1, 1.5s)
t=2.7s   第 1 次震动 (强度 6) — Boss 半透明
t=3.1s   第 2 次震动 (强度 9) — 暗角开始回退到 0.6
t=3.5s   第 3 次震动 (强度 12) — Boss 完全现身
t=3.5s   名称大字淡入
t=5.3s   名称大字淡出
t=3.5s   Engine.time_scale 恢复, Boss AI 激活, HP 条出现
         战斗开始!
```

---

## 2. Boss 攻击多样化 — 三大新攻击类型

### 2.1 新增攻击概览

当前 Boss 已有 8 个技能 (SingleShot, WhistleWave, Fan5, RollCharge, Fan5Fast, TripleBarrage, DesperateDash, SummonWhistle)，但都是扇形弹幕/冲刺/召唤的组合。玩家反馈"打来打去都是扇形弹幕"。

新增 3 种**完全不同机制**的攻击：

| 攻击 | 类型 | Phase | 前摇 | 机制 |
|------|------|:-----:|:----:|------|
| **哨声冲击波** | 全屏圆形 pushback | 1/2/3 | 1.0s | Boss 中心扩散的 500px 冲击波，推飞玩家 |
| **地板 AOE** | 预警圆圈+延迟爆炸 | 2/3/4 | 0.8s(预警) | 玩家脚下 3 个红色圆圈 → 0.8s 后依次爆炸 |
| **冲刺冲撞 (轻)** | 快速冲撞+撞墙硬直 | 2/3 | 0.6s | 150px 直线冲刺，撞墙额外硬直 0.5s |

### 2.2 enemy.gd : `_build_boss_systems()` 尾部新增特殊攻击状态变量

**文件**: `scripts/enemy.gd`
**位置**: `_build_boss_systems()` 函数末尾 (L383 `func _on_phase_transition_finished` 之前), 插入以下代码

```gdscript
    # ---- 8. 特殊攻击状态变量 ----
    # 这些是独立于 BossAI skill slots 的特殊攻击，
    # 由 _boss_behavior() 在每个 Phase 按条件触发

    # 哨声冲击波 (Phase 1/2/3 可用)
    var _shockwave_cooldown: float = 0.0
    var _shockwave_cooldown_max: float = 8.0  # 每 8 秒一次

    # 地板 AOE (Phase 2/3/4 可用)
    var _floor_aoe_cooldown: float = 0.0
    var _floor_aoe_cooldown_max: float = 6.0  # 每 6 秒一次
    var _floor_aoe_count: int = 3

    # 冲刺冲撞-轻 (Phase 2/3 可用)
    var _charge_cooldown: float = 0.0
    var _charge_cooldown_max: float = 5.0   # 每 5 秒一次
    var _is_charging: bool = false
```

### 2.3 enemy.gd : `_boss_behavior()` 重写 — 注入特殊攻击逻辑

**文件**: `scripts/enemy.gd`
**位置**: L385-389 (替换现有的 `_boss_behavior`)

```gdscript
func _boss_behavior(delta: float) -> void:
    # 基础：委托给 BossAI 管理移动 + 常规攻击选择
    if _boss_ai:
        _boss_ai.tick(delta)
    move_and_slide()

    # ---- 特殊攻击冷却递减 ----
    if _player_ref == null:
        return

    _shockwave_cooldown = maxf(_shockwave_cooldown - delta, 0.0)
    _floor_aoe_cooldown   = maxf(_floor_aoe_cooldown - delta, 0.0)
    _charge_cooldown      = maxf(_charge_cooldown - delta, 0.0)

    # 获取当前 Phase 信息
    var bp := get_node_or_null("PhaseController") as BossPhaseController
    if not bp or bp.is_transitioning:
        return
    var phase_data: BossPhaseData = bp.get_current_phase_data()
    if not phase_data:
        return
    var phase_idx: int = phase_data.phase_index

    # ---- 哨声冲击波 (Phase 0/1/2 即乐章 1/2/3) ----
    if phase_idx <= 2 and _shockwave_cooldown <= 0.0 and not _is_charging:
        var dist := global_position.distance_to(_player_ref.global_position)
        # 只在玩家离较远时使用，近身时优先近战技能
        if dist > 120.0 and randf() < 0.012:  # 每帧 ~1.2% 概率
            _execute_shockwave()
            _shockwave_cooldown = _shockwave_cooldown_max
            return  # 冲击波覆盖本帧，不继续检查

    # ---- 地板 AOE (Phase 1/2/3 即乐章 2/3/4) ----
    if phase_idx >= 1 and _floor_aoe_cooldown <= 0.0:
        var dist := global_position.distance_to(_player_ref.global_position)
        # 不要在太近时放（玩家已经在 Boss 脸上输出）
        if dist > 80.0 and randf() < 0.008:  # 每帧 ~0.8% 概率
            _execute_floor_aoe(phase_idx)
            _floor_aoe_cooldown = _floor_aoe_cooldown_max
            return

    # ---- 冲刺冲撞-轻 (Phase 1/2 即乐章 2/3) ----
    if (phase_idx == 1 or phase_idx == 2) and _charge_cooldown <= 0.0 and not _is_charging:
        var dist := global_position.distance_to(_player_ref.global_position)
        # 适合中距离突进
        if dist > 100.0 and dist < 300.0 and randf() < 0.01:
            _execute_charge()
            _charge_cooldown = _charge_cooldown_max
            return
```

### 2.4 enemy.gd : 三个特殊攻击方法的实现

在 `enemy.gd` 中，`_on_phase_transition_finished()` 之后（L429 之后）插入三个新方法：

```gdscript
# =============================================================================
# 特殊攻击 1: 哨声冲击波 — 全屏圆形 pushback
# =============================================================================

func _execute_shockwave() -> void:
    ## 前摇 1.0s: Boss 口哨脉冲 3 次 → 全屏冲击波扩散
    ## 波半径 500px, 速度 600px/s, 到达边缘约 0.83s
    ## 路径上碰到玩家: 推飞 (knockback 80) + 伤害 12

    if not _player_ref:
        return

    # 前摇阶段: 口哨视觉提示 (3 次脉冲)
    var whistle_rect := _get_boss_part_optional("whistle")
    for i in range(3):
        if whistle_rect and is_instance_valid(whistle_rect):
            var w_tween: Tween = create_tween()
            w_tween.tween_property(whistle_rect, "scale", Vector2(1.3, 1.3), 0.1)
            w_tween.tween_property(whistle_rect, "scale", Vector2(1.0, 1.0), 0.1)
        await get_tree().create_timer(0.33).timeout

    # 冲击波视觉: 大环形从 Boss 中心扩散
    var ring := ColorRect.new()
    ring.color = Color(1.0, 1.0, 1.0, 0.5)
    ring.size = Vector2(60, 60)  # 初始小圈
    ring.global_position = global_position - Vector2(30, 30)
    ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ring.z_index = 9
    var effect_parent := get_parent() as Node2D
    if effect_parent:
        effect_parent.add_child(ring)

    var ring_tween: Tween = create_tween()
    ring_tween.set_parallel(true)
    ring_tween.tween_property(ring, "scale", Vector2(16.7, 16.7), 0.83)  # 60×16.7≈1000px
    ring_tween.tween_property(ring, "color:a", 0.0, 0.83)
    ring_tween.tween_callback(ring.queue_free)

    # 碰撞检测: 在扩散过程中每帧检测玩家
    var elapsed: float = 0.0
    var max_radius: float = 500.0
    var expand_speed: float = 600.0
    var current_radius: float = 0.0
    while elapsed < 0.83 and is_instance_valid(ring):
        await get_tree().process_frame
        elapsed += get_process_delta_time()
        current_radius = elapsed * expand_speed
        if _player_ref and is_instance_valid(_player_ref):
            var p_dist := global_position.distance_to(_player_ref.global_position)
            # 检测波峰是否碰到玩家 (容忍 40px 误差)
            if abs(p_dist - current_radius) < 40.0:
                _deal_shockwave_damage()
                break

    if is_instance_valid(ring):
        ring.queue_free()

    # 后摇 0.4s
    await get_tree().create_timer(0.4).timeout


func _deal_shockwave_damage() -> void:
    if not _player_ref or not is_instance_valid(_player_ref):
        return
    if _player_ref.has_method("take_damage"):
        _player_ref.take_damage(12, self)
    # 推飞
    var push_dir := (_player_ref.global_position - global_position).normalized()
    if _player_ref.has_method("knockback"):
        _player_ref.knockback(push_dir * 80.0)
    CombatFeedback.hit_particles(_player_ref.global_position, 6, Color(1.0, 1.0, 0.8))
    CombatFeedback.screen_shake(4.0)


# =============================================================================
# 特殊攻击 2: 地板 AOE — 预警圆圈 → 延迟爆炸
# =============================================================================

func _execute_floor_aoe(phase_idx: int) -> void:
    ## 在玩家位置附近生成 3 个预警圆圈，0.8s 后依次爆炸
    ## 爆炸半径 80px，伤害 18/发
    ## Phase 4 (phase_idx==3): 爆炸速度加快，每次生成 4 个

    if not _player_ref:
        return

    var count: int = 4 if phase_idx >= 3 else _floor_aoe_count
    var explosion_delay: float = 0.8
    var explosion_radius: float = 80.0
    var explosion_damage: int = 18
    var aoe_color := Color(1.0, 0.3, 0.05, 0.5)  # 红橙预警色
    var explosion_color := Color(1.0, 0.2, 0.0, 0.8)

    var effect_parent := get_parent() as Node2D
    if not effect_parent:
        return

    # 生成预警圆圈 — 散布在玩家身边
    var circles: Array[ColorRect] = []
    for i in range(count):
        var circle := ColorRect.new()
        circle.color = aoe_color
        circle.size = Vector2(explosion_radius * 2, explosion_radius * 2)
        # 位置: 玩家周围 60-180px 随机散布
        var angle := deg_to_rad(float(i) * 360.0 / float(count) + randf_range(-20, 20))
        var offset_dist := randf_range(60.0, 180.0)
        circle.global_position = _player_ref.global_position \
            + Vector2(cos(angle), sin(angle)) * offset_dist \
            - Vector2(explosion_radius, explosion_radius)
        circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
        circle.z_index = 8
        effect_parent.add_child(circle)
        circles.append(circle)

    # 预警阶段: 闪烁 0.8s
    for i in range(4):
        for c in circles:
            if is_instance_valid(c):
                var flicker_on: Tween = create_tween()
                flicker_on.tween_property(c, "color:a", 0.8, 0.1)
                var flicker_off: Tween = create_tween()
                flicker_off.tween_property(c, "color:a", 0.2, 0.1).set_delay(0.1)
        await get_tree().create_timer(0.2).timeout

    # 爆炸阶段: 依次爆炸，间隔 0.2s
    for c in circles:
        if not is_instance_valid(c):
            continue

        # 爆炸视觉: 从预警色变为爆炸色 + 放大
        var exp_tween: Tween = create_tween()
        exp_tween.set_parallel(true)
        exp_tween.tween_property(c, "color", explosion_color, 0.15)
        exp_tween.tween_property(c, "scale", Vector2(1.3, 1.3), 0.15)
        exp_tween.tween_property(c, "color:a", 0.0, 0.3).set_delay(0.15)
        exp_tween.tween_callback(c.queue_free).set_delay(0.3)

        # 伤害判定: 检测玩家是否在圆圈内
        if _player_ref and is_instance_valid(_player_ref):
            var circle_center := c.global_position + Vector2(explosion_radius, explosion_radius)
            var p_dist := _player_ref.global_position.distance_to(circle_center)
            if p_dist < explosion_radius:
                if _player_ref.has_method("take_damage"):
                    _player_ref.take_damage(explosion_damage, self)
                CombatFeedback.hit_particles(_player_ref.global_position, 4, Color(1.0, 0.3, 0.05))
                CombatFeedback.screen_shake(3.0)

        await get_tree().create_timer(0.2).timeout  # 爆炸间隔


# =============================================================================
# 特殊攻击 3: 冲刺冲撞 (轻) — 快速冲撞+撞墙硬直
# =============================================================================

func _execute_charge() -> void:
    ## 前摇 0.6s → 冲刺 150px (速度 400px/s) → 撞墙额外硬直 0.5s
    ## 伤害 20 (路径上碰到玩家)
    ## 与 Phase 4 的 DesperateDash x4 区分：单次、轻量、撞墙奖励

    if not _player_ref:
        return

    _is_charging = true

    # 前摇: Boss 身体微蹲 + 方向锁定
    var locked_dir: Vector2 = global_position.direction_to(_player_ref.global_position)
    var sprite_ref := get_node_or_null("Sprite") as ColorRect

    # 蹲下姿态 (scale.y → 0.6)
    if sprite_ref:
        var squat_tween: Tween = create_tween()
        squat_tween.tween_property(sprite_ref, "scale:y", sprite_ref.scale.y * 0.6, 0.3)
        squat_tween.tween_interval(0.3)
        squat_tween.tween_property(sprite_ref, "scale:y", sprite_ref.scale.y, 0.15)

    await get_tree().create_timer(0.6).timeout

    # 冲刺阶段
    if sprite_ref:
        sprite_ref.modulate = Color(0.7, 0.7, 0.7)  # 金属化闪灰

    var charge_distance: float = 150.0
    var charge_speed: float = 400.0
    var traveled: float = 0.0
    var hit_wall: bool = false

    while traveled < charge_distance and not hit_wall:
        var dt: float = get_process_delta_time()
        var step: float = charge_speed * dt
        traveled += step

        # 碰撞检测 (使用 move_and_collide 而非直接位移)
        var collision := move_and_collide(locked_dir * step, false, 0.08, false, 3)
        if collision:
            hit_wall = true
            # 撞墙反馈
            CombatFeedback.screen_shake(5.0)
            CombatFeedback.hit_particles(global_position + locked_dir * 10, 8, Color(0.8, 0.6, 0.3))
            break

        # 伤害判定: 路径上碰到玩家
        if _player_ref and is_instance_valid(_player_ref):
            if global_position.distance_to(_player_ref.global_position) < 30.0:
                if _player_ref.has_method("take_damage"):
                    _player_ref.take_damage(20, self)
                if _player_ref.has_method("knockback"):
                    _player_ref.knockback(locked_dir * 50.0)
                CombatFeedback.hit_particles(_player_ref.global_position, 4, Color(1.0, 0.5, 0.1))

        await get_tree().process_frame

    # 恢复阶段
    if sprite_ref:
        sprite_ref.modulate = sprite_ref.color  # 恢复原色

    var recovery: float = 0.8 if hit_wall else 0.3
    # 撞墙额外硬直 — 奖励玩家引诱 Boss 撞墙
    if hit_wall:
        var dizzy_effect: Tween = create_tween()
        dizzy_effect.tween_property(sprite_ref, "rotation", deg_to_rad(5), 0.1)
        dizzy_effect.tween_property(sprite_ref, "rotation", deg_to_rad(-5), 0.1)
        dizzy_effect.tween_property(sprite_ref, "rotation", 0.0, 0.1)

    await get_tree().create_timer(recovery).timeout
    _is_charging = false


# =============================================================================
# 辅助: 安全获取 Boss 视觉部件（可能不存在）
# =============================================================================

func _get_boss_part_optional(part_name: String) -> ColorRect:
    var visual_root := get_node_or_null("BossVisual")
    if not visual_root:
        return null
    return visual_root.get_node_or_null(part_name.capitalize()) as ColorRect
```

### 2.5 enemy.gd : `_physics_process` 传递 delta

**文件**: `scripts/enemy.gd`
**位置**: L85-98 (替换 `_physics_process` 的调用部分)

```gdscript
func _physics_process(delta: float) -> void:
    if is_dead or _player_ref == null: return
    if GameState.current_state != GameState.State.PLAYING: return
    if activation_range > 0.0:
        var dist_to_player := global_position.distance_to(_player_ref.global_position)
        if dist_to_player > activation_range:
            return  # 玩家未进入激活范围，待机

    if is_boss:
        _boss_behavior(delta)
    elif is_ranged:
        _ranged_behavior(delta)  # 原来没传 delta，现在传入
    else:
        _melee_behavior(delta)    # 原来没传 delta，现在传入
```

### 2.6 game_manager.gd : 为 `_spawn_boss_now` 补充 Boss AI 激活

`_spawn_boss_now` 最后恢复 game 时，需要确保 Boss AI 不被时间缩放影响。在重写后的 `_spawn_boss_now` 末尾 (恢复时间缩放那行) 之前，检查当前的 `e.modulate` 是否已经到位：

```gdscript
    # 确保 Boss 完全可见（如果 tween 还未完成，强制完成）
    e.modulate = Color.WHITE
```

(以上行应插入到 `Engine.time_scale = original_time_scale` 之前)

---

## 3. AI 包围战术

### 3.1 近战敌人包抄逻辑

**问题**: 当前 `_melee_behavior()` (L100-103) 所有敌人直线追玩家，3+ 个敌人时他们排成一列，没有包围感。

**方案**: 超过 3 个近战敌人时，外侧敌人尝试绕到玩家背后。每 1-2 秒重新评估一次包抄角度，不是每帧变化。

**文件**: `scripts/enemy.gd`
**位置**: 在文件 class body 顶部 (`var` 声明区，约 L36 附近) 新增状态变量：

```gdscript
# 包围战术变量
var _flank_angle: float = 0.0
var _flank_timer: float = 0.0
var _flank_reassess_interval: float = 1.5  # 每 1.5s 重新评估包抄角
var _assigned_flank: int = 0  # 0=直线, 1=右侧包抄, -1=左侧包抄
```

**文件**: `scripts/enemy.gd`
**位置**: L100-103 (替换 `_melee_behavior`)

```gdscript
func _melee_behavior(delta: float) -> void:
    # ---- 包围战术: 3+ 近战敌人时外侧包抄 ----
    var melee_count := _count_nearby_melee()

    if melee_count >= 3:
        _flank_timer += delta
        if _flank_timer >= _flank_reassess_interval or _assigned_flank == 0:
            _flank_timer = 0.0
            # 重新分配: 每个敌人随机选择包抄方向 (左侧或右侧)
            _assigned_flank = 1 if randf() > 0.5 else -1
            _flank_angle = PI / 4.0 * float(_assigned_flank)  # ±45 度

        var direction := global_position.direction_to(_player_ref.global_position)
        var flank_dir := direction.rotated(_flank_angle)
        # 混合: 70% 包抄方向 + 30% 直线，避免绕太远
        velocity = (flank_dir * 0.7 + direction * 0.3).normalized() * move_speed
    else:
        # 少于 3 个敌人: 直线追击
        var direction := global_position.direction_to(_player_ref.global_position)
        velocity = direction * move_speed

    move_and_slide()


## 计算场上"活跃近战敌人数量"（同组 enemy 中 is_ranged==false, is_boss==false）
func _count_nearby_melee() -> int:
    var count: int = 0
    var tree := get_tree()
    if not tree:
        return 0
    var all_enemies := tree.get_nodes_in_group("enemies")  # 需要给普通 Enemy 加 group
    if all_enemies.is_empty():
        # fallback: 从父节点 children 中统计
        var parent_node := get_parent()
        if parent_node:
            for child in parent_node.get_children():
                if child is CharacterBody2D and child != self:
                    var enemy_child := child as Enemy
                    if enemy_child and not enemy_child.is_ranged and not enemy_child.is_boss:
                        count += 1
        return count

    for e in all_enemies:
        if e == self:
            continue
        var enemy_ref := e as Enemy
        if enemy_ref and not enemy_ref.is_ranged and not enemy_ref.is_boss:
            var dist := global_position.distance_to(e.global_position)
            if dist < 400.0:  # 只统计 400px 范围内的近战敌人
                count += 1
    return count
```

**注意**: 需要在 `enemy.gd` 的 `_ready()` 中给普通敌人加 group：

```gdscript
# 在 _ready() 的 super._ready() 之后添加:
func _ready() -> void:
    super._ready()
    _update_hp()

    var players := get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        _player_ref = players[0]

    # 加入敌人组 (用于 AI 互感知)
    if not is_boss and not is_elite:
        add_to_group("enemies")

    # 精英外观 ...
```

### 3.2 远程敌人对角线站位

**问题**: 当前 `_ranged_behavior` (L105-121) 在舒适区保持位置射击，但没有主动寻找角度。

**方案**: 远程敌人优先找玩家对角线位置（而不是正面），这样弹幕更难躲避。

**文件**: `scripts/enemy.gd`
**位置**: L105-121 (替换 `_ranged_behavior`)

```gdscript
func _ranged_behavior(delta: float) -> void:
    var dist := global_position.distance_to(_player_ref.global_position)
    var dir := global_position.direction_to(_player_ref.global_position)

    if dist > preferred_distance * 1.5:
        # 太远: 追击
        velocity = dir * move_speed
    elif dist < 80:
        # 太近: 后退 + 侧移 (对角线退避)
        var retreat_dir := -dir
        var strafe_offset := Vector2(retreat_dir.y, -retreat_dir.x)  # 90度侧移
        velocity = (retreat_dir * 0.6 + strafe_offset * 0.4).normalized() * move_speed
    else:
        # 在舒适区: 横向绕行寻找对角线角度
        # 对角线角度 = 玩家面向方向的 ±45°
        var player_aim_dir := Vector2.RIGHT  # 默认假设玩家朝右
        if _player_ref and _player_ref.has_method("get_aim_direction"):
            player_aim_dir = _player_ref.get_aim_direction()
        if player_aim_dir == Vector2.ZERO:
            player_aim_dir = Vector2.RIGHT

        # 计算当前敌人相对玩家的角度
        var to_enemy := (global_position - _player_ref.global_position).normalized()
        var angle_to_player := player_aim_dir.angle_to(to_enemy)

        # 目标: 保持在玩家 ±45° 对角线位置
        var ideal_angle := PI / 4.0  # 45 度
        if abs(angle_to_player) < deg_to_rad(25.0):
            # 太靠近正面: 横向移动到对角线
            var strafe_dir := to_enemy.rotated(PI / 2.0 * (1.0 if randf() > 0.5 else -1.0))
            velocity = strafe_dir * move_speed * 0.5
        elif abs(angle_to_player) > deg_to_rad(65.0):
            # 太偏离: 调整回对角线范围
            var correct_dir: Vector2 = player_aim_dir.rotated(ideal_angle * sign(angle_to_player))
            var offset := (correct_dir * preferred_distance) + _player_ref.global_position
            velocity = offset.direction_to(global_position) * move_speed * 0.2
        else:
            # 在对角线舒适区内: 保持位置
            velocity = Vector2.ZERO

    move_and_slide()

    _ranged_timer += delta
    if _ranged_timer >= ranged_cooldown:
        _ranged_timer = 0.0
        _shoot()
```

---

## 4. 数值平衡速查

### 4.1 Boss 特殊攻击参数

| 攻击 | 冷却 | 前摇 | 伤害 | 额外效果 |
|------|:---:|:---:|:---:|------|
| 哨声冲击波 | 8s | 1.0s(3次口哨脉冲) | 12 | 推飞 80px |
| 地板 AOE (Phase 2/3) | 6s | 0.8s(预警闪烁) | 18/圈 | 3 个圈，间隔 0.2s |
| 地板 AOE (Phase 4) | 5s | 0.6s(预警闪烁) | 22/圈 | 4 个圈，间隔 0.15s |
| 冲刺冲撞 (单次) | 5s | 0.6s | 20 | 撞墙硬直 +0.5s |

### 4.2 哨声冲击波检测参数

```
expand_speed: 600 px/s
max_radius: 500 px
travel_time: 500/600 ≈ 0.83s
hit_tolerance: ±40px (波峰厚度)
```

### 4.3 地板 AOE 散布参数

```
散布半径: 60-180px (以玩家为中心)
爆炸半径: 80px
爆炸间隔: 0.2s (Phase 4: 0.15s)
预警闪烁: 4 次, 每次 0.2s
```

### 4.4 冲刺冲撞参数

```
冲刺距离: 150px
冲刺速度: 400px/s
碰撞检测: move_and_collide (检测墙壁 layer 3)
碰撞 hitbox: 30px 半径圆形判定
撞墙硬直: +0.5s (总恢复 0.8s)
```

---

## 5. 实施检查清单

### 5.1 Boss 出场演出

- [ ] `game_manager.gd` `_spawn_boss_now` 重写(含 2s 沉默)
- [ ] 暗角 `vignette_controller` alpha 到 0.9 再回退
- [ ] 3 次递进震动 (6.0 → 9.0 → 12.0)
- [ ] Boss `modulate.a 0→1` 耗时 1.5s
- [ ] 名称大字淡入 (0.4s) → 停留 (1.8s) → 淡出 (0.5s)
- [ ] `Engine.time_scale` 正确恢复
- [ ] Boss `set_process(true)` / `set_physics_process(true)` 在恢复时调用

### 5.2 Boss 攻击多样化

- [ ] `_build_boss_systems()` 新增特殊攻击状态变量
- [ ] `_boss_behavior()` 注入 Phase 感知的特殊攻击检查
- [ ] `_execute_shockwave()` 实现 (口哨脉冲 + 冲击波扩散 + 推飞)
- [ ] `_execute_floor_aoe()` 实现 (预警圆圈 + 闪烁 + 依次爆炸)
- [ ] `_execute_charge()` 实现 (蹲下蓄力 + 冲刺 + 撞墙检测)
- [ ] `_get_boss_part_optional()` 辅助方法
- [ ] 特殊攻击与 BossAI 技能不冲突 (冷却独立管理)

### 5.3 AI 包围战术

- [ ] `_melee_behavior(delta)` 接收 delta 参数
- [ ] 包围状态变量 (`_flank_angle`, `_flank_timer`, `_assigned_flank`)
- [ ] `_count_nearby_melee()` 实现
- [ ] 普通敌人加入 `"enemies"` 组 (`_ready()`)
- [ ] `_ranged_behavior(delta)` 接收 delta 参数
- [ ] 远程对角线站位逻辑
- [ ] player 上需要有 `get_aim_direction()` 方法 (如果还没有)

### 5.4 编译/运行时检查

- [ ] `_melee_behavior` / `_ranged_behavior` 调用处已传 delta
- [ ] `get_process_delta_time()` 在冲刺协程中可用 (需要在 `_physics_process` 调用链中)
- [ ] `move_and_collide` 的 collision_mask 参数与实际墙壁层匹配
- [ ] VignetteController 有 `get_node_or_null("VignetteOverlay")` 可访问
- [ ] 所有 Tween 使用 `TWEEN_PROCESS_IDLE` (不受 time_scale 影响)
- [ ] `await` 在特殊攻击中使用时，确保不会与 BossAI 的 `tick` 产生竞态
- [ ] 删除 `.godot/global_script_class_cache.cfg` 重建类索引

---

## 6. 风险点和降级策略

| 风险 | 概率 | 影响 | 降级方案 |
|------|:---:|------|------|
| `Engine.time_scale=0` 冻结了不该冻结的东西 | 中 | Boss 出场序列卡死，游戏无法恢复 | 用 `get_tree().paused=true` 替代 time_scale，但需要确保 Tween 在 `PROCESS_MODE_ALWAYS` 下运行 |
| 特殊攻击协程与 BossAI tick 竞态 | 低 | Boss 同时执行两个攻击 | 在 `_boss_behavior` 中 `return` 防止同一帧触发多个特殊攻击 |
| 环绕包抄角度导致敌人撞墙卡住 | 中 | 敌人堆积在墙壁拐角 | 已有的墙壁滑动逻辑 (`move_and_slide` 碰撞) 可以缓解；包抄角度从 ±45° 降为 ±30° 如果不理想 |
| 远程对角线需要 `get_aim_direction()` | 中 | 如果 player.gd 没暴露此方法，编译报错 | Fallback: 用 `_player_ref` 的 velocity 方向作为 aim_direction |
| 地板 AOE 圆圈在 TileMap 墙壁上显示 | 低 | 视觉效果怪异但不影响 gameplay | 可接受；如果在意，用 TileMap 查询位置是否可通行再放置 |

---

*"让每一次出场都像第一次见面。让每一次死亡都像上了一课。" - 宫崎英高*
