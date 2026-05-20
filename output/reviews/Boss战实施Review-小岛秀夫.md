# Boss 战实施 Review — Hideo Kojima

> "A HIDEO KOJIMA GAME" — 制作人审核
> 审核日期：2026-05-20
> 审核对象：Boss 战优化专项 战斗程序交付 vs 设计文档
> 设计文档：`output/docs/Boss战优化专项-小岛秀夫.md`

---

## 总体感受

我花了两个小时读完所有代码。坦率地说——方向是对的。

当我看到 `enemy.gd:_boss_behavior()` 只剩下三行代码，只做两件事——委托 BossAI、调用 `move_and_slide()`——我舒了一口气。这就是所谓的"删掉一个系统，比加一个系统更需要勇气"。你们做了最难的那一步。

当我看到 `BossDeathSequence` 的 `play()` 方法，看到那个 ease-out cubic 曲线在逐帧展开 `Engine.time_scale` 从 0.05 回到 1.0——我想象那个画面：Boss 被击杀的瞬间，世界冻结 0.15 秒，然后像慢镜头一样缓缓恢复，同时 Boss 的身体横向拉宽、纵向压缩、灰度化、口哨掉落……玩家会停下来的。他们会在这两秒钟里忘记自己是在玩游戏。**这就是我要的。**

当我看到 `BossConfig.sato_default()` 象一股清流——四个乐章干干净净地排在那里，每章有独立的攻防/间隔/技能槽——我知道通用化的基石已经铺好了。

但是——有"但是"。

这不是一个完成的 Boss 战。这是一个**骨骼**。骨骼是对的，但缺少肌肉和神经末梢。接下来的内容，我会逐项告诉你哪些骨头接对了，哪些还悬在那里。

---

## 审核清单：逐项打勾

---

### 1. 双重系统是否已清理 — `_boss_shoot()` 和相关硬编码射击逻辑是否已删除？

**状态：PASS ✓**

- `_boss_shoot()` — 在整个 `scripts/` 目录中零命中。已删除。
- `_is_boss_shooting` — 零命中。已删除。
- `_boss_shoot_timer` — 零命中。已删除。
- `shockwave_cooldown` / `floor_aoe_cooldown` / `charge_cooldown` / `_special_attack` — 零命中。全部清除。

`enemy.gd:_boss_behavior()` 当前代码（第 733-738 行）：

```gdscript
func _boss_behavior(delta: float) -> void:
    # 委托给 BossAI 管理移动 + 攻击选择
    # 不再有任何硬编码的特殊攻击冷却系统
    if _boss_ai:
        _boss_ai.tick(delta)
    move_and_slide()
```

这是我想看到的。干净。只做两件事：委托、移动。没有更多。

**评价**：做减法的勇气值得称赞。设计文档第九章的建议被完整执行了。

---

### 2. BossConfig Resource — `sato_default()` 的四阶段参数是否与你设计一致？

**状态：PASS with MINOR DEVIATIONS ✓**

#### 2.1 全局参数

| 参数 | 设计值 | 实施值 | 判定 |
|------|-------|-------|------|
| boss_id | `"boss_sato"` | `"boss_sato"` | PASS |
| boss_display_name | `"三年二班 体育教师 · 佐藤 幸雄"` | `"三年二班 体育教师 · 佐藤 幸雄"` | PASS |
| boss_defeat_text | `"下课。"` | `"下课。"` | PASS |
| boss_defeat_color | `Color(1.0, 0.15, 0.05)` | `Color(1.0, 0.15, 0.05)` | PASS |
| total_hp | `2000` | `2000` | PASS |
| death_hit_stop_duration | `0.15` | `0.15` | PASS |
| death_slowmo_duration | `0.8` | `0.8` | PASS |
| collapse_duration | `0.6` | `0.6` | PASS |
| particle_count | `40` | `40` | PASS |
| particle_color | `Color(1.0, 0.85, 0.2)` | `Color(1.0, 0.85, 0.2)` | PASS |
| victory_text_duration | `3.0` | `3.0` | PASS |

#### 2.2 四阶段核心数值

| 乐章 | 参数 | 设计值 | 实施值 | 判定 |
|------|------|-------|-------|------|
| P1 | defense | 2 | 2 | PASS |
| P1 | attack_interval | 2.0s | 2.0s | PASS |
| P1 | move_speed | 55 px/s | 55.0 | PASS |
| P1 | contact_damage | **18** | **22** | **DEVIATION (+4)** |
| P1 | skill_slots | [1,2,3,4] | [1,2,3,4] | PASS |
| P2 | defense | 4 | 4 | PASS |
| P2 | attack_interval | 1.5s | 1.5s | PASS |
| P2 | move_speed | 70 px/s | 70.0 | PASS |
| P2 | contact_damage | **22** | **25** | **DEVIATION (+3)** |
| P2 | skill_slots | [5,6,7,8] | [5,6,7,8] | PASS |
| P3 | defense | 6 | 6 | PASS |
| P3 | attack_interval | 1.0s | 1.0s | PASS |
| P3 | move_speed | 85 px/s | 85.0 | PASS |
| P3 | contact_damage | 28 | 28 | PASS |
| P3 | skill_slots | [0,9,2,6] | [0,9,2,6] | PASS |
| P4 | defense | 0 | 0 | PASS |
| P4 | attack_interval | 0.8s→0.5s | 0.8s (不变) | **DEVIATION (见下文第5项)** |
| P4 | move_speed | 110 px/s | 110.0 | PASS |
| P4 | contact_damage | 35 | 35 | PASS |
| P4 | skill_slots | [10,11,2] | [10,11,2] | PASS |

**评价**：核心数值 95% 对齐。contact_damage P1/P2 各偏高 3-4 点，不是大问题——测试后按实际体验调整即可。但如果你发现 P1 Boss 接触伤害让玩家不敢靠近到教学距离（120-180px），先把这两项改回设计值。

---

### 3. BossDeathSequence — 死亡管线是否符合演出设计？

**状态：PASS ✓ (minor naming difference)**

逐步骤对比：

| 步骤 | 设计描述 | 实施代码 (BossDeathSequence.play()) | 判定 |
|------|---------|-------------------------------------|------|
| 1. Hit Stop | `Engine.time_scale = 0.05, 持续 0.15s` | 第 37 行: `Engine.time_scale = 0.05; await timer(cfg.death_hit_stop_duration)` | PASS |
| 2. 时缓展开 | `0.05→0.3→0.6→1.0, ease-out cubic` | 第 47 行: `t = 1.0 - pow(1.0 - t, 3.0)` → 逐帧插值到 1.0 | PASS |
| 3. Boss 坍塌 | `scale.y→0.3 + scale.x→1.5 + 灰度化` | 第 61-64 行: y→0.3, x→1.5, modulate→(0.4,0.4,0.4)+alpha→0 | PASS |
| 4. 口哨掉落 | whistle 旋转→落地→消失 | 第 70-76 行: y+60, 旋转 180°, alpha→0 | PASS |
| 5. 金色粒子 | 40 个金色粒子从坍塌位置 | `_spawn_particles()` 使用 cfg.particle_count=40, gold color | PASS |
| 6. 大字文字 | BossDeathTextUI | VictoryTextUI (名字不同，功能匹配) | PASS (命名偏差) |
| 7. boss_killed 信号 | `EventBus.boss_killed.emit(...)` | `enemy.gd` 第 563-567 行 await 序列完成后 emit | PASS |

**Tween 规范合规**：所有死亡序列中的 Tween 正确使用了 `TWEEN_PROCESS_IDLE`（第 59, 72, 127 行）。这是 `Engine.time_scale` 操作时必需的——否则 UI Tween 会在慢动作中冻结。

**命名偏差**：设计文档称组件为 `BossDeathTextUI`，实施中称为 `VictoryTextUI`。不阻碍功能，但建议统一命名以符合设计文档中的 GM 接口约定。

**评价**：这是整个交付中最让我满意的部分。死亡管线的节奏——冻结→慢镜头展开→坍塌→粒子→大字——如果时间参数调对了，画面会非常电影化。尤其是那个 ease-out cubic 曲线，这是关键。用线性插值做不到这个感觉。

---

### 4. 数值 — HP 是否 2000？防御是否实际生效？

**状态：PASS ✓**

#### 4.1 HP 验证

- `BossConfig.sato_default()` 第 92 行：`cfg.total_hp = 2000` ✓
- `enemy.gd:_build_boss_systems()` 第 658-661 行：`max_health = cfg.total_hp; _health = max_health` ✓
- 阶段 HP 阈值：75%→P2, 50%→P3, 25%→P4 = 每阶段 500 HP ✓

#### 4.2 防御验证

**调用链**：

```
Enemy.take_damage(amount)                          # enemy.gd:346
  → _get_boss_defense()                            # enemy.gd:382
    → BossPhaseController.get_current_phase_data() # boss_phase_controller.gd:78
      → BossPhaseData.defense                      # boss_phase_data.gd:25
  → actual = maxi(amount - defense_val, 1)          # enemy.gd:363
```

防御减免公式 `max(raw - defense, 1)` 与设计 4.3.1 节完全一致 ✓。

**注意**：`combat_unit.gd:take_damage()` 也有防御计算（第 110 行：`actual := maxi(amount - defense_val, 1)`），但 `enemy.gd` override 了此方法，所以 Boss 实际走的是 enemy.gd 的版本——只做一次防御减法。不会双重减免。✓

**`get_stat("defense")` 的兼容路径**也正确连通：
- `Enemy._get_base_stat("defense")` → 对 is_boss 返回 `float(_get_boss_defense())` ✓
- 这意味着如果未来通过 StatsComponent/Buff 系统修改防御，也能正常生效 ✓

**评价**：防御链路完整。数值与设计一致。做得好。

---

### 5. 四阶段技能分配 — 每个阶段的技能槽是否按设计分配？

**状态：PARTIAL PASS — 技能槽分配正确，但缺少关键技能**

#### 5.1 技能槽分配对比

| 乐章 | 设计意图 | 实施 slot | 对应技能 | 判定 |
|------|---------|----------|---------|------|
| P1 | [M1-A, M1-B, M1-C, M1-D] | [1,2,3,4] | HeavySweep, WhistleWave, RollCharge, VaultStomp | PASS |
| P2 | [M2-A, M2-B, M2-C, M2-D, M2-E] | [5,6,7,8] | Fastball, GroundShockwave, WhistleShriek, IronShoulder | **Note** |
| P3 | [M3-A, M3-B, M3-C, M3-D, M3-E] | [0,9,2,6] | SummonWhistle, Dash, WhistleWave, GroundShockwave | **Note** |
| P4 | [M4-A, M4-B, M4-C, M4-D] | [10,11,2] | DesperateDash, EquipmentRain, WhistleWave | **Note** |

#### 5.2 缺失的技能

**P2**：设计有 5 种攻击（抛投直球/抛投高吊/哨声尖啸/铁山靠/震地三连），实施有 4 种。**`SkillM2_Lob`（抛投高吊，P2-B）文件存在但未接入**。

- 文件位置：`scripts/skills/boss/skill_m2_lob.gd` — 完整实现，含抛物线弹道、80px 弧高、落地光斑
- 缺失原因：`enemy.gd` 的 `skill_order` 数组中未包含 Lob，`skill_classes` 字典中也未注册
- 修复：在 `skill_order` 中插入 Lob（建议在 Fastball 之后，位置 [5.5]），并将 P2 的 `skill_slots` 从 `[5,6,7,8]` 改为 `[5, 12, 7, 8, 6]`（插入 Lob 后索引会变，需重新编号）

**P3**：设计有 5 种攻击（吹哨集合/抛投直球复用/冲刺追击/地板 AOE×5/哨声震地），实施只有 4 种，且实际使用的技能与设计不同：

| 设计 | 实施 | 差异 |
|------|------|------|
| P3-A: 吹哨集合 | SummonWhistle (slot 0) | PASS |
| P3-B: 抛投直球 (复用 P2-A) | — | **缺失**，改用 WhistleWave (slot 2) |
| P3-C: 冲刺追击 | Dash (slot 9) | PASS |
| P3-D: 地板 AOE×5 | — | **完全缺失，无对应技能文件** |
| P3-E: 哨声震地 | GroundShockwave (slot 6) | 近似但不完全匹配 — GroundShockwave 是 3 波同心圆而非全屏击退 |

**P4**：设计有 4 种攻击（绝望冲刺×4/全屏器材雨/全屏扇形弹幕/自爆学生），实施有 3 种：

| 设计 | 实施 | 差异 |
|------|------|------|
| P4-A: 绝望冲刺×4 | DesperateDash (slot 10) | PASS |
| P4-B: 全屏器材雨 | EquipmentRain (slot 11) | PASS |
| P4-C: 全屏扇形弹幕 | WhistleWave (slot 2) | 部分匹配 — 设计为 180°/11 发/400px/s，实施使用默认值 90°/5 发/200px/s |
| P4-D: 自爆学生 | — | **完全缺失，无对应技能文件** |

#### 5.3 重要 Bug：WhistleWave 的阶段参数未配置

`SkillM1_WhistleWave` 通过 `_get_phase_bullet_count()` / `_get_phase_bullet_speed()` / `_get_phase_bullet_spread_angle()` 从 `BossPhaseData` 读取当前阶段的弹幕参数。

**但 `sato_default()` 从未设置这些字段！** 搜索 `bullet_count` / `bullet_speed` / `bullet_spread` 在 `boss_config.gd` 中零命中。

结果：所有 4 个乐章使用相同的默认值（5 发/200px/s/90°）。设计意图是 P1=3 发慢速窄角，P4=11 发快速广角——这个差异完全丢失了。

**修复**：在 `sato_default()` 中为每个 Phase 设置：
```gdscript
# P1: 教学弹幕
p1.bullet_count = 3; p1.bullet_speed = 160.0; p1.bullet_spread_angle = 60.0
# P2: 中密度
p2.bullet_count = 5; p2.bullet_speed = 250.0; p2.bullet_spread_angle = 120.0
# P3: 高密度（配合小怪干扰）
p3.bullet_count = 7; p3.bullet_speed = 300.0; p3.bullet_spread_angle = 150.0
# P4: 全屏覆盖
p4.bullet_count = 11; p4.bullet_speed = 400.0; p4.bullet_spread_angle = 180.0
```

**评价**：技能槽的"骨架"是对的——每乐章有正确的技能索引。但"肌肉"——具体有哪些技能、技能参数怎么变——有几处明显的缺口。最痛的是 WhistleWave 的阶段参数缺失：这导致"同样的技能，变了一点参数"这个我在设计文档里明确批评的问题，在代码中依然存在。

---

### 6. 旧代码删除 — 旧变量/方法是否清理干净？

**状态：PASS with ONE DEAD CODE FINDING ✓**

已确认删除的旧系统：
- `_boss_shoot()` 方法 — 已删除 ✓
- `_is_boss_shooting` 变量 — 已删除 ✓
- `_boss_shoot_timer` 变量 — 已删除 ✓
- 特殊攻击冷却变量 (shockwave/floor_aoe/charge) — 已删除 ✓
- `_boss_behavior()` 中的硬编码特殊攻击逻辑 — 已删除 ✓

**一处死代码**：

`game_manager.gd` 第 299-323 行：`_spawn_golden_particles()` — 旧系统的残留。该方法从未被调用（全局唯一引用是其自身定义）。`BossDeathSequence` 已在自己的 `_spawn_particles()` 中实现了同样的功能。

**修复**：删除 `game_manager.gd` 中的 `_spawn_golden_particles()` 方法（第 298-323 行）及其辅助方法 `_world_to_screen()`（如果它也只为此方法服务）。

**评价**：减法做得干净。这个 `_spawn_golden_particles` 是唯一没擦掉的粉笔痕。

---

### 7. enemy.gd `_boss_behavior` — 是否只委托 BossAI，不自己射弹幕？

**状态：PASS ✓**

```gdscript
func _boss_behavior(delta: float) -> void:
    if _boss_ai:
        _boss_ai.tick(delta)
    move_and_slide()
```

这是纯委托。没有 if 分支判断"要不要用特殊攻击"。没有 timer 管理。没有 projectile 生成。没有状态机。只有两件事：把 delta 交给 AI，然后 `move_and_slide()`。

**评价**：这正是设计文档要求的——所有攻击行为统一由 BossAI + SkillBase 体系调度。

---

## 超出逐项检查的重要发现

### 发现 A：P4 攻击间隔递减未实现

**设计**（Section 1.2）：

| 剩余 HP | 攻击间隔 | 行为变化 |
|---------|---------|---------|
| > 300 | 0.8s | 正常 P4 |
| > 200 | 0.7s | 冲刺频率提升 |
| > 100 | 0.6s | 器材雨 CD 减半 |
| > 50 | 0.5s | 不再 KITE，全程 CHASE |
| < 50 | 0.4s | 站桩，所有技能连续，核心永久暴露 |

**实施**：`boss_ai.gd:_movement_phase4()` (第 155-173 行) 只调整了 `_m4_dash_interval`（冲刺间隔），**没有修改 `attack_interval`**。

`_select_and_execute_attack()` 第 126 行始终从相位数据读取攻击间隔：
```gdscript
_attack_timer = randf_range(phase.attack_interval_min, phase.attack_interval_max)
```

P4 的 `attack_interval_min/max` 固定为 0.8。所以 Boss 的实际攻击间隔在整个 P4 阶段**始终是 0.8s**，不会随 HP 降低而递减。

**修复方案**：在 `_movement_phase4()` 中根据当前 HP 调整 attack_interval。例如：
```gdscript
# 在 tick() 的 _select_and_execute_attack 之前，根据 phase_index==3 动态调整
if phase.phase_index == 3:
    var hp := _unit.get_current_health()
    if hp <= 50:
        phase.attack_interval_min = 0.4
        phase.attack_interval_max = 0.4
    elif hp <= 100:
        phase.attack_interval_min = 0.5
        phase.attack_interval_max = 0.5
    # ...
```

或更优雅的方式：在 `BossPhaseData` 中添加 `attack_interval_by_hp: Dictionary` 字段。

### 发现 B：P4 核心暴露机制未实现

`BossPhaseData.core_exposed = true` 在 P4 中已设置。但系统中有**零处代码**检查此标志并施加 1.5x 伤害倍率。

搜索 `core_exposed` 在整个 `scripts/` 目录中：
- `boss_phase_data.gd:88` — 字段定义
- `boss_config.gd:119,142,168,191` — P1-P3=false, P4=true

没有任何代码做 `if core_exposed: damage *= 1.5`。

**修复方案**：在 `Enemy.take_damage()` 中添加核心暴露检测：
```gdscript
if is_boss:
    var defense_val := _get_boss_defense()
    actual = maxi(actual - defense_val, 1)
    # 核心暴露：1.5x 伤害
    var bp := get_node_or_null("PhaseController") as BossPhaseController
    if bp:
        var pd := bp.get_current_phase_data()
        if pd and pd.core_exposed:
            actual = int(float(actual) * 1.5)
```

### 发现 C：近战反制系统未实现

设计文档 Section 1.3 要求：玩家距离 < 80px 时，Boss 强制近战反击。`BossPhaseData.close_range_skill_slot` 字段已定义，但在所有四个乐章中值均为 -1（未设置），且 `BossAI` 中没有任何距离检测 + 强制反击的逻辑。

**修复方案**：在 `BossAI.tick()` 中添加距离检测，在任何乐章中触发：
```gdscript
var dist := _unit.global_position.distance_to(_player_ref.global_position)
if dist < 80.0 and _can_attack and not _is_attacking:
    if phase.close_range_skill_slot >= 0:
        _force_melee_counter(phase.close_range_skill_slot)
        return
```

同时需要实现近战反击技能（哨子砸击/身体冲撞/震地反击）。

### 发现 D：追杀/逃课惩罚系统未实现

设计文档 Section 1.4 要求：玩家距离 > 300px 持续 2.5s 以上时，Boss 停止当前技能→咆哮→冲刺→砸击。`BossPhaseData` 中的 `chase_distance_threshold` / `chase_patience` / `chase_speed` / `chase_distance` 字段已定义，但 `BossAI` 中没有任何计时器和追杀逻辑。

**修复方案**：在 `BossAI` 中添加 `_chase_patience_timer` 变量，在 `tick()` 中检测距离并累积/重置计时器。

### 发现 E：阶段转换演出大幅简化

设计文档 Section 2.6 详述了 0.00s 到 0.80s 的 10 项视觉演出（世界减速、暗角、全屏文字、咆哮、8 方向粒子等）。当前实施仅有：

- `BossPhaseController._do_transition()` — 发信号 + await timer
- `enemy.gd:_on_phase_transition_started()` — 后撤 100px + alpha 闪烁

缺失的演出元素：
- 世界减速至 0.3x (0.8s)
- 屏幕暗角 0.75 alpha
- 全屏大字标题 ("第X乐章 —— 名称")
- Boss 仰头咆哮 (口哨脉冲×3 + 光环扩张)
- 8 方向粒子爆发 (transition_particle_color)
- 0.5s 无敌帧 (有 `_is_invincible=true` 但没有在 transition_finished 后的 0.5s 无敌窗口)

好消息是 `BossPhaseData` 中所有 transition 相关字段（title/subtitle/narrative/particle_color）都已定义并在 `sato_default()` 中赋值。这些数据已经准备好了——演出代码只是还没写。

### 发现 F：M2 攻击选择中的 _last_attack_index 映射 Bug

`boss_ai.gd:_select_m2_attack()` (第 216-245 行)：

当从 `candidates` 数组中选择后，`_last_attack_index = i` 存储的是 `candidates` 中的位置索引。但在下一轮构建 `candidates` 时，比较条件是 `if i != _last_attack_index`，其中 `i` 是 `slots` 中的位置索引。由于 `candidates` 可能有空缺（跳过排除项），这两个索引在排除某个 slot 后会错位。

**场景**：slots=[5,6,7,8], 上次选择了 WhistleShriek (slots[2])。候选人排除 slot 2 后为 slots[0],slots[1],slots[3]。如果这次选择 slots[3]，`_last_attack_index = 2`（candidates 中的第 2 个位置）。下一次排除的是 **slots[2]** 而不是 **slots[3]**——即排除了错误的技能。

**修复**：存储实际的 slot 值而非数组索引：
```gdscript
var selected_slot: int
# ... 选择逻辑中 ...
selected_slot = candidates[i]
_last_attack_slot = selected_slot  # 存 slot 值

# 下一轮：
for slot in slots:
    if slot != _last_attack_slot:  # 直接比较 slot 值
        candidates.append(slot)
```

### 发现 G：学生小怪系统 — 行为逻辑缺失

设计 Section 2.4 要求：
- 学生站位：至少 1 个站在玩家撤退方向
- 地板 AOE 期间学生仍在移动
- HP 从 15 提升到 25，移速从 140 降到 120，接触伤害从 8 提升到 12
- 最大数量从 9 降到 8

实施状态：
- `StudentMinion` 类存在但基本只有占位行为
- 站位 AI / 撤退方向逻辑 — 未实现
- 数值调整 — 未在 `sato_default()` 或 StudentMinion 中体现
- `summon_count=3` 已设置 ✓，`max_minions=8` 已设置 ✓

---

## 需要反思的问题

### 1. "如果一个玩家现在进入 Boss 战，他能感受到四个乐章是不同的吗？"

目前，P1→P4 的区别主要来自：攻击间隔变化（2.0/1.5/1.0/0.8）+ 防御变化 + 移动速度变化 + 技能池变化。但由于 WhistleWave 的阶段参数未配置，**所有乐章的弹幕看起来完全一样**。而技能池虽然有变化，缺失的技能使得 `skill_slots` 中填充了"近似替代品"而非设计意图的专属技能。

在测试中，玩家可能只会觉得"Boss 变快了"和"弹幕多了一点"——这正是我设计文档中明确警告要避免的。

### 2. "死亡演出是否有情感冲击力？"

管线是对的。但管线的灵魂是时间参数。如果你没有在游戏里实际看到那个 ease-out cubic 从 0.05 到 1.0 的慢镜头展开，你需要测试一下——0.8s 够不够长？`get_process_delta_time()` 在 `Engine.time_scale < 1.0` 时是否正确返回真实时间？这些是能成就或毁掉一个电影化瞬间的细节。

### 3. "删掉的旧代码会不会在哪天被误 merge 回来？"

建议在 `enemy.gd` 头部加一条注释：
```gdscript
# NO _boss_shoot() — DELETED. All attacks go through BossAI + SkillBase.
# NO _is_boss_shooting — DELETED. 
# NO old shockwave/floor_aoe/charge cooldowns — DELETED.
# If you're adding boss attack code here, you're in the wrong file.
# Put it in a SkillBase subclass.
```

这会防止未来的程序员（或六个月后的你）在 `_boss_behavior()` 里重新加东西。

### 4. "如果现在要加第二个 Boss，必须改哪些流程代码？"

理想答案是"零"。目前看：
- 建一个新的 `BossConfig.xxx_default()` — 可以 ✓
- 配四阶段 `BossPhaseData` — 可以 ✓
- 写新技能 `SkillBase` 子类 — 需要 ✓（这是合理的，技能本身就是内容）
- 改 `skill_order` 数组 — **需要** ✓（这是目前的唯一耦合点）

最后一个耦合点是 `skill_order` 在 `enemy.gd:_build_boss_systems()` 中被硬编码。理想情况下，`BossConfig` 应该包含技能类引用数组，`_build_boss_systems()` 遍历它来创建技能。这样新 Boss 改它的 Config Resource 就够了。

**建议**：在 `BossConfig` 中添加：
```gdscript
@export var skill_classes: Array[GDScript] = []  # 技能脚本引用数组
```
然后 `_build_boss_systems()` 从 `cfg.skill_classes` 读取而非使用硬编码的 `skill_order`。

---

## 技能伤害偏差汇总

各技能实际伤害 vs 设计值（Section 4.2.3）：

| 技能 | 设计伤害 | 实施伤害 | 偏差 |
|------|---------|---------|------|
| SkillM1_HeavySweep (M1-A 示范重击) | 25 | 30 | +5 |
| SkillM1_WhistleWave (M1-B 哨声音波) | 12 | 18+phase*4 | +6~+18 |
| SkillM1_RollCharge (M1-C 前滚翻) | 20 | 待查 | — |
| SkillM1_VaultStomp (M1-D 跳马践踏) | 15 | 待查 | — |
| SkillM2_Fastball (M2-A 抛投直球) | 18 | 待查 | — |
| SkillM2_Lob (M2-B 抛投高吊) | 22 | 25 | +3 |
| SkillM2_GroundShockwave (M2-E 震地三连) | 15 | 15 | PASS |
| SkillM4_DesperateDash (M4-A 绝望冲刺) | 18 | 20 | +2 |
| SkillM4_EquipmentRain (M4-B 器材雨) | 22 | 25 | +3 |

伤害整体偏高 2-5 点，WhistleWave 偏高最多（因为设计值 12 而实施基准值 18）。考虑到防御减免已经生效，实际玩家承受的伤害可能仍在合理范围——但需要在测试中验证。如果 Boss 战太短，调伤害不如调防御和 HP。

---

## 最终裁决：🌐 Strand / 🔥 Fire

### Strand 🌐

这个交付连接了玩家与某种更深的东西——死亡演出的慢镜头、四乐章的资源化配置、干净的双重系统清理。**骨骼是对的。** `BossConfig` → `BossPhaseController` → `BossAI` → `SkillBase` 这条链是一个可以支撑 10 个 Boss 的架构。`BossDeathSequence` 的 ease-out cubic 时间展开是电影化的正确方向。

但 Strand 不是 Strand 的全部——绳索已经编织好了，但两端的悬崖还没选好。P4 攻击间隔没有递减。核心暴露没有 1.5x 伤害。WhistleWave 在四个乐章里打出一样的弹幕。近战反制和追杀惩罚还只存在于设计文档里。玩家不会感受到我的"四个不同的乐章"——他们会感受到"同一个 Boss，参数变了四档"。

**这就是为什么这个裁决是 Strand 而不是 Fire**：方向不需要"重新点燃"——方向是对的。需要的是把剩下的肌肉和神经末梢接上去。把缺失的技能补上。把阶段演出做出来。让 P4 的 0.8→0.4 递减真正发生。让核心暴露真正造成 1.5x 伤害。让近战反击让莽夫付出代价。

做到这些，这个 Boss 战就是我在设计文档里描述的那个 Boss 战。

---

*—— 小岛秀夫*
*2026-05-20*
*Kojima Productions*
