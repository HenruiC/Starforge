# Boss 机制设计 v2 — 四阶段差异化方案

> 宫崎英高, 战斗策划, Starforge 工作室
> 2026-05-19

---

## 0. 诊断：当前代码的问题

### 0.1 基础设施已存在，但未接入

`scripts/boss/` 下已有完整的 Boss 子系统：

| 文件 | 职责 | 当前状态 |
|------|------|---------|
| `boss_phase_controller.gd` | 四乐章 HP 阈值检测 + 转换演出 | 已创建但 `BossPhaseData` 只填了 3 个字段 |
| `boss_phase_data.gd` | 每乐章完整参数 (移速/防御/光环/攻击间隔/召唤/核心暴露) | 15 个字段中只用了 3 个 |
| `boss_ai.gd` | 四乐章移动策略 + 攻击选择 + 召唤计时 | **完全未被 enemy.gd 实例化** |
| `boss_attack_data.gd` | 每个攻击的前摇/硬直/伤害/弹道/突进参数 | **完全未被使用** |
| `boss_aura_controller.gd` | 光环颜色切换 + 呼吸脉冲 + 碎裂演出 | 已连接 EventBus 但依赖外部调用 `set_phase()` |
| `boss_visual.gd` | Boss 七部件 ColorRect 拼装工厂 | **未被 enemy.gd 调用 (enemy.gd 自己拼)** |
| `boss_visual_animator.gd` | 攻击姿态动画 (13 个攻击各有独立前摇/释放/硬直 pose) | 已连接 EventBus.boss_attack_started |

### 0.2 enemy.gd 的 `_boss_behavior` 是平行实现

```gdscript
# enemy.gd:236-265 — 当前 Boss 行为（完全绕过上述所有子系统）
func _boss_behavior(delta: float) -> void:
    # 简陋的距离判断 → 靠近/后退
    # 每 3s/(1+phase*0.3) 发射 3 发扇形弹幕
    # HP 比例改变 modulate 颜色
    # 没有: BossAI、阶段演出、召唤、冲刺、核心暴露
```

### 0.3 核心问题清单

1. **四个阶段行为完全一样** — `_boss_behavior` 中只有 `phase_speed` 改变攻击间隔 (3.0s → 3.0/1.9 ≈ 1.58s)，没有机制变化
2. **没有阶段转换演出** — `BossPhaseController._do_transition()` 只是 `await timer` + 发信号，enemy.gd 未响应信号做后撤/无敌/变色
3. **弹幕太稀疏** — 始终是 3 发扇形，角度固定 30 度 (PI/6)，速度恒定，任何阶段都可轻松躲避
4. **没有召唤** — Phase 3 "集合" 没有任何 summon 逻辑
5. **没有冲刺/冲撞** — Boss 只能匀速靠近/后退
6. **判定问题** — Boss 碰撞体是 enemy.tscn 的默认 Area2D，没有匹配 Boss 身体尺寸；弹幕 hitbox 未知

---

## 1. Boss 数值总表

### 1.1 基础属性

| 属性 | 值 | 说明 |
|------|-----|------|
| Boss ID | `boss_sato` | 体育老师·佐藤 |
| 总 HP | 1600 | 每阶段 400 HP |
| 基础防御 | 5 | Phase 4 降为 0 |
| 基础接触伤害 | 25 | Phase 4 升为 30 |
| 身体尺寸 | 72 x 96 px | Body ColorRect，由 BossVisual 创建 |
| 光环尺寸 | 104 x 104 px | Aura ColorRect |

### 1.2 四阶段参数速查

| 参数 | Phase 1 "热身" | Phase 2 "球类训练" | Phase 3 "集合" | Phase 4 "毕业考试" |
|------|:---:|:---:|:---:|:---:|
| HP 范围 | 1600→1200 | 1200→800 | 800→400 | 400→0 |
| HP 比例 | 100%→75% | 75%→50% | 50%→25% | 25%→0% |
| 移速 (px/s) | 60 | 78 | 95 | 115 |
| 防御力 | 5 | 5 | 5 | 0 |
| 接触伤害 | 25 | 25 | 25 | 30 |
| 攻击间隔 (s) | 2.8 | 2.2 | 1.8 | 1.5→0.8 |
| 移动模式 | KITE | KITE | CHASE | CHASE |
| 理想距离 (px) | 180-300 | 150-260 | 120-220 | 80-180 |
| 光环颜色 | 橙 #FF801A | 黄 #FFB31A | 白 #E6D9B3 | 无 (碎裂) |
| 光环 alpha 范围 | 0.10↔0.35 | 0.15↔0.40 | 0.10↔0.45 | — |
| 光环脉冲周期 | 2.0s 均匀 | 2.0s 均匀 | 随机 0.5-2.5s | — |
| 召唤 | 无 | 无 | 3-4 学生/10s | 无 |
| 核心暴露 | 无 | 无 | 无 | 攻击硬直期间 |

---

## 2. 各阶段详细行为设计

### 2.1 Phase 1: 热身 (100% → 75%, HP 1600→1200)

**设计意图**: 这是教学阶段。Boss 展示三种基本攻击模式，教玩家识别前摇动作。攻击慢、弹幕疏、节奏固定。

**移动行为 — KITE**:
```
维持距离: 180-300px
太近 (< 180px): 倒退 (移速 × 0.6)
太远 (> 300px): 接近 (移速 × 1.0)
理想区内: 横向慢速绕行 (移速 × 0.3, 随机左/右)
```

**攻击 1 — 哨声音波 (M1-A)**:
- 类型: 远程单发直线弹幕
- 前摇: 0.6s (口哨 ColorRect 从银变橙红, scale 脉冲 1.0→1.2→1.0)
- 弹幕: 1 发, 直线飞向玩家, 速度 150 px/s
- 伤害: 15
- 硬直: 0.4s
- 躲避: 侧移一步即可

**攻击 2 — 扇形 3 发 (M1-B)**:
- 类型: 远程扇形弹幕
- 前摇: 0.6s (右臂后摆 45°, 身体微后仰)
- 弹幕: 3 发, 扇形展开, 相邻夹角 25°, 速度 170 px/s
- 伤害: 12/发
- 硬直: 0.4s
- 躲避: 弹幕间有清晰的 25° 空隙, 站着不动也可从间隙穿过

**攻击循环**: M1-A → M1-B → M1-A → M1-B (固定交替)
**攻击间隔**: 每次攻击后 2.8s 冷却

**视觉反馈**:
- 光环: 橙色, 均匀呼吸 pulse (2s 周期, alpha 0.10↔0.35)
- 移速缓慢, 身体姿态松弛 (arms at sides)
- 口哨偶尔微闪 (每 4s 一次随机 0.05s 闪白)
- 被击中: 身体闪白 (标准 hitFlash)

---

### 2.2 Phase 2: 球类训练 (75% → 50%, HP 1200→800)

**设计意图**: 压力升级。弹幕从 3 发改 5 发 + 角度扩大; 新增冲刺攻击打破玩家站桩节奏; 攻击不再是固定循环, 改为权重随机。

**移动行为 — KITE (缩小距离)**:
```
维持距离: 150-260px
太近 (< 150px): 倒退 (移速 × 0.6)
太远 (> 260px): 接近 (移速 × 1.0)
理想区内: 横向绕行 (移速 × 0.4, 随机方向)
```

**攻击 1 — 扇形 5 发 (M2-A)**:
- 前摇: 0.5s (双臂同时后摆, 身体微蹲)
- 弹幕: 5 发, 扇形 90° 展开, 相邻夹角 22.5°, 速度 220 px/s
- 伤害: 15/发
- 硬直: 0.35s
- 躲避: 弹幕间空隙更窄, 需要侧移穿过或后退

**攻击 2 — 冲刺冲撞 (M2-B)**:
- 前摇: 0.6s (Boss 蹲下 scale.y→0.5, 体色加深, 方向在 0.4s 时锁定)
- 冲刺: 向锁定方向冲刺 200px, 速度 380 px/s, 持续约 0.53s
- 伤害: 30 (冲刺路径上)
- 撞墙: 额外 0.5s 硬直 (奖励玩家引诱 Boss 撞墙)
- 撞空: 0.3s 缓冲后恢复正常
- 硬直: 0.5s (撞墙: 0.5 + 0.5 = 1.0s 输出窗口)
- CD: 不能连续使用 (如果上次是 M2-B, 本次强制选 M2-A)

**攻击选择**: 权重随机 [M2-A: 0.55, M2-B: 0.45], 不连续重复
**攻击间隔**: 2.2s (每次攻击后)

**视觉反馈**:
- 光环: 黄色, 快节奏 pulse (2s 周期, alpha 0.15↔0.40)
- 冲刺蓄力时地面出现横向拖痕粒子 (4-5 个深色小 ColorRect 沿冲刺方向排列)
- 冲刺中体色短暂金属化 (闪灰)
- 弹幕不再是慢速橙色, 改为黄白高速弹

---

### 2.3 Phase 3: 集合 (50% → 25%, HP 800→400)

**设计意图**: 从单目标战斗变为多目标管理。玩家必须在躲避 Boss 弹幕 + 冲刺的同时处理小怪包围。

**移动行为 — CHASE (主动追击)**:
```
维持距离: 120-220px
太近 (< 120px): 倒退 (移速 × 0.5)
太远 (> 220px): 全速追击 (移速 × 1.0)
理想区内: 停止, 专注攻击
```

**攻击 1 — 扇形 5 发快速版 (M3-A)**:
- 同 M2-A, 但弹幕速度提升至 240 px/s, 伤害 18/发
- 前摇: 0.45s (比 M2-A 快 0.05s)
- 硬直: 0.3s

**攻击 2 — 召唤学生 (M3-B, 独立计时器)**:
- 计时器: 每 10s 触发一次, 独立于攻击循环
- 前摇: 1.0s (口哨 3 次快速脉冲 + 白色声波从 Boss 扩散至屏幕边缘)
- 召唤: 3-4 个"学生残影"从屏幕边缘出现

**学生小怪参数**:
| 属性 | 值 |
|------|-----|
| 视觉 | 白色半透明 ColorRect (16x24), scale 0.7, alpha 0.8 |
| HP | 15 |
| 移速 | 130 px/s |
| 行为 | CHASE 近战追踪 |
| 接触伤害 | 8 |
| 攻击前摇 | 0.35s |
| 攻击硬直 | 0.2s |
| 死亡效果 | alpha→0 + scale→0.5, 0.3s |
| 最大同时存在 | 9 |
| 组 (group) | `student_minion` |
| Phase 4 进入时 | 全部停住 → 消散 (alpha→0, 0.5s) |
| Boss 死亡时 | 同上, 全部消散 |

**空哨事件 (第 3 次吹哨)**:
- 口哨脉冲 → 声波扩散 → ...没有学生出现
- Boss 停顿 1.0s (alpha 不稳定闪烁)
- 此后 summon CD 延长至 20s

**攻击选择**: M3-A 持续, M3-B 独立触发
**攻击间隔**: 1.8s

**视觉反馈**:
- 光环: 白色/暖白, 不稳定随机 pulse (周期 0.5-2.5s 随机, alpha 0.10↔0.45)
- 每 3s 一次大型脉冲 (scale 1.0→1.25→1.0), 模拟吹哨声波
- Boss 移速明显加快, 身体略微前倾 (body rotation -3°)
- 召唤时口哨亮度加倍, 声波视觉为扩散的白色半透明圈

---

### 2.4 Phase 4: 毕业考试 (25% → 0%, HP 400→0)

**设计意图**: 狂暴终局。弹幕三连发, 冲刺频率大幅提升, 攻击间隔随 HP 降低递减。但 Boss 硬直窗口也更长, 核心暴露给予 1.5x 伤害机会。

**移动行为 — CHASE AGGRESSIVE**:
```
维持距离: 80-180px (更近)
太近 (< 80px): 不后退, 直接横向绕行
太远 (> 180px): 全速追击
理想区内: 横向快速绕行 (移速 × 0.5)
HP < 80 (5%): 停止移动, 站桩狂攻, 核心永久暴露
```

**攻击 1 — 三连扇形弹幕 (M4-A)**:
- 前摇: 0.4s (身体短暂闪烁)
- 弹幕: 3 波, 每波 3 发 (扇形 90°), 波间间隔 0.2s
- 弹幕速度: 280 px/s
- 伤害: 18/发
- 硬直: 0.5s (第三波后)
- 核心暴露: 硬直期间核心可见, 1.5x 伤害

**攻击 2 — 高频冲刺 (M4-B)**:
- 前摇: 0.4s (Boss 下蹲 + 方向锁定)
- 冲刺: 160px, 速度 420 px/s
- 伤害: 35 (冲刺路径)
- 撞墙: 额外 0.5s 硬直 (核心暴露 1.0s)
- 撞空: 0.4s 缓冲 → 可立即接下一个攻击
- 核心暴露: 撞墙后的 1.0s 硬直期间

**攻击间隔递减**:
```
HP 400→300: 1.5s
HP 300→200: 1.2s
HP 200→100: 1.0s
HP 100→50:  0.8s
HP 50→0:    0.6s
```

**攻击选择**: M4-A 和 M4-B 随机交替 (权重各 0.5), 不连续重复

**HP < 80 终局状态**:
- Boss 停止移动, 站桩
- 攻击间隔固定 0.6s, M4-A 和 M4-B 交替
- 核心永久暴露 (modulate.a = 0.9, visible = true)
- 这是仪式性的"处决阶段"

**视觉反馈**:
- 光环: **无** — 已在转阶段时碎裂 (8 方向白色粒子爆发 + 光环缩小淡出)
- Boss 身体颜色: 暗红近乎黑 `Color(0.18, 0.12, 0.15)`
- 口哨仍可见 (保持银色), 但不再闪烁
- 冲刺时身体短暂发亮 → 冲完变暗 (体力消耗感)
- 核心: 16x16 高亮红方块 `Color(1.0, 0.2, 0.05)`, 在胸口位置 (Body 中心)
- HP < 80 时 Boss 上半身低垂 (body rotation -5°, scale.y 0.95), 模拟"喘气"

---

## 3. 阶段转换机制

### 3.1 转换触发条件

`BossPhaseController.check_transition(hp_ratio)` 已实现穿越检测。当 HP 比例首次越过阈值时触发。

### 3.2 转换时间线 (每个阶段切换统一流程)

```
t = 0.00s    HP 越过阈值
             ├── BossPhaseController._do_transition() 开始
             ├── is_transitioning = true (AI 暂停, 技能暂停)
             └── phase_transition_started 信号发出

t = 0.00s    后撤开始:
             ├── Boss 向远离玩家方向移动 (dir = boss_pos - player_pos, 归一化)
             ├── 距离 100px, 时长 0.4s
             └── Tween: position 从当前到 (当前位置 + 后撤方向 * 100)

t = 0.00s    无敌开始:
             ├── Boss 设置 is_invincible = true
             └── Body alpha 闪烁: 0.3 → 1.0 → 0.3 → 1.0 (0.1s × 4 = 0.4s)

t = 0.00s    光环变色 (并行):
             ├── BossAuraController.set_phase(new_phase) 调用
             ├── 光环颜色 Tween 到新颜色 (0.5s)
             └── 如果是 Phase 3→4: 调用 BossAuraController.shatter() (碎裂特效)

t = 0.05s    屏幕边缘脉冲:
             ├── 4 个红色半透明 ColorRect 出现在屏幕四边 (各 8px 宽/高)
             ├── alpha: 0.0 → 0.5 → 0.0 (0.5s)
             ├── 颜色: 当前光环颜色 (Phase 3→4 时用红色)
             └── 可以用 UIEffects 实现或直接创建临时 ColorRect

t = 0.50s    转换完成:
             ├── is_transitioning = false
             ├── is_invincible = false
             ├── 新乐章参数生效 (移速/攻击间隔/行为模式)
             ├── phase_transition_finished 信号发出
             └── HUD 显示新阶段名称 (1.0s, 屏幕上方居中淡入淡出)

t = 0.50s    如果是 Phase 2→3:
             └── 首次召唤学生立即触发 (不等待 10s 计时器)
```

### 3.3 各阶段转换的特殊处理

| 转换 | 后撤距离 | 无敌时长 | 光环变化 | 额外效果 |
|------|---------|---------|---------|---------|
| 1→2 | 100px | 0.5s | 橙→黄 | 光环脉冲加速至 2s 周期 |
| 2→3 | 100px | 0.5s | 黄→白 | 声波扩散 (3 道白色圈从 Boss 扩散至屏幕边缘, 0.8s), 首次召唤 |
| 3→4 | 80px | 0.5s | 白→碎裂 | 光环 8 方向粒子爆发, Boss 体色变暗红, 核心闪烁一下后隐藏 |

### 3.4 屏幕边缘脉冲实现要点

```
创建 4 个 ColorRect:
├── top:    (0, 0, screen_w, 8)
├── bottom: (0, screen_h-8, screen_w, 8)
├── left:   (0, 0, 8, screen_h)
├── right:  (screen_w-8, 0, 8, screen_h)

动画: 并行 Tween
├── modulate.a: 0.0 → 0.5 → 0.0 (0.5s, EASE_OUT then EASE_IN)
└── 完成后 queue_free()

颜色: 从当前 BossAuraController 的光环颜色读取
```

---

## 4. 碰撞判定 / Hitbox 设计

### 4.1 问题分析

用户反馈 "弹幕打不中人或者打中判定不对"。原因：

1. **Boss 身体 hitbox 不匹配视觉** — 当前 enemy.tscn 的 Area2D 可能是默认的正方形, 但 Boss 身体是 72x96 的竖长方形。玩家瞄准视觉中心发射弹幕, 可能打偏。
2. **弹幕 hitbox 不清晰** — `enemy_projectile.tscn` 的碰撞体大小未知, 可能与视觉大小不一致。
3. **没有核心弱点的独立 hitbox** — Phase 4 需要核心作为独立可打击区域。

### 4.2 Boss Hurtbox (玩家可攻击的区域)

```
Hurtbox: Area2D (挂载在 Boss CombatUnit 下)
├── 形状: RectangleShape2D
├── 尺寸: Vector2(72, 96) — 匹配 Body ColorRect
├── 偏移: (0, 0) — 居中
├── collision_layer: 0 (不需要碰撞层, 由玩家子弹的碰撞检测处理)
└── collision_mask: 玩家的子弹层

创建方式:
  在 _build_boss_systems() 中, 获取或创建 hurtbox Area2D
  设置其 CollisionShape2D 的 shape 为 RectangleShape2D.new() 并设置 size
```

### 4.3 Boss 弹幕 Hitbox (打玩家的判定)

```
每个 boss 弹幕 (EnemyProjectile):
├── 形状: CircleShape2D
├── 半径: 6px — 与视觉大小一致
├── offset: (0, 0) — 中心
├── 视觉: 8x8 或 10x10 ColorRect (圆形感觉的小方块)
└── collision_mask: 玩家 hitbox 所在的层

弹幕速度和伤害随阶段变化 (见各阶段攻击参数)
```

### 4.4 Boss 冲刺 Hitbox (Phase 2/4 冲撞判定)

```
冲刺判定: 独立 Area2D, 仅在冲刺 active 帧启用
├── 形状: RectangleShape2D
├── 尺寸: Vector2(48, 64) — 横向矩形, 模拟"侧面撞击"
├── 偏移: (0, 0) — 居中
├── 启用时机: BossAI 的 _on_skill_windup_ended / active 阶段
├── 关闭时机: 冲刺结束或撞墙
└── 碰撞检测: 与玩家的 hurtbox 重叠时造成伤害 (30/35)
```

### 4.5 核心弱点 Hitbox (Phase 4)

```
核心 Hurtbox: 独立 Area2D
├── 形状: CircleShape2D
├── 半径: 10px
├── 位置: Body ColorRect 中心 (胸口)
├── 可见性: Phase 4 攻击硬直期间 visible = true
├── 伤害倍率: 1.5x (在 CombatUnit.take_damage 中检查)
│   伪代码: if core_area.overlaps_body(damage_source):
│              actual_damage = amount * 1.5
└── HP < 80 (5%): 永久可见, 永久 1.5x
```

### 4.6 判定验证检查清单

实现后逐项检查:
- [ ] 玩家弹幕在 Boss 身体 72x96 区域内命中 → 造成伤害
- [ ] 玩家弹幕在 Boss 身体外 (光环区域) → 不造成伤害
- [ ] Boss 弹幕 6px 半径碰到玩家 → 造成伤害
- [ ] Boss 冲刺 (48x64 矩形) 碰到玩家 → 造成 30/35 伤害
- [ ] Phase 4 核心 10px 半径内命中 → 1.5x 伤害数字 (显示为黄色/金色暴击)
- [ ] 无敌帧期间 (阶段转换) → 所有伤害为 0
- [ ] 学生小怪 hitbox: 12x18 (匹配 16x24 * 0.7 scale)

---

## 5. BossPhaseData 完整配置

以下是 `_build_boss_systems()` 应该为每个阶段设置的完整 BossPhaseData 值：

```gdscript
func _build_boss_systems() -> void:
    # Phase Controller
    var bp := BossPhaseController.new()
    bp.name = "PhaseController"
    add_child(bp)

    # Phase 1: 热身
    var p1 := BossPhaseData.new()
    p1.phase_index = 0
    p1.phase_name = "热身"
    p1.health_threshold = 0.75
    p1.move_speed = 60.0
    p1.defense = 5
    p1.contact_damage = 25
    p1.aura_color = Color(1.0, 0.5, 0.1)       # 橙色
    p1.aura_alpha_min = 0.10
    p1.aura_alpha_max = 0.35
    p1.aura_pulse_period = 2.0
    p1.attack_interval_min = 2.8
    p1.attack_interval_max = 2.8
    p1.skill_slots = [0, 1]                      # M1-A, M1-B
    p1.summon_enabled = false
    p1.summon_interval = 0.0
    p1.summon_count = 0
    p1.core_exposed = false
    p1.transition_duration = 0.5

    # Phase 2: 球类训练
    var p2 := BossPhaseData.new()
    p2.phase_index = 1
    p2.phase_name = "球类训练"
    p2.health_threshold = 0.50
    p2.move_speed = 78.0
    p2.defense = 5
    p2.contact_damage = 25
    p2.aura_color = Color(1.0, 0.7, 0.1)        # 黄色
    p2.aura_alpha_min = 0.15
    p2.aura_alpha_max = 0.40
    p2.aura_pulse_period = 2.0
    p2.attack_interval_min = 2.2
    p2.attack_interval_max = 2.2
    p2.skill_slots = [2, 3]                      # M2-A, M2-B
    p2.summon_enabled = false
    p2.summon_interval = 0.0
    p2.summon_count = 0
    p2.core_exposed = false
    p2.transition_duration = 0.5

    # Phase 3: 集合
    var p3 := BossPhaseData.new()
    p3.phase_index = 2
    p3.phase_name = "集合"
    p3.health_threshold = 0.25
    p3.move_speed = 95.0
    p3.defense = 5
    p3.contact_damage = 25
    p3.aura_color = Color(0.9, 0.85, 0.7)       # 白色/暖白
    p3.aura_alpha_min = 0.10
    p3.aura_alpha_max = 0.45
    p3.aura_pulse_period = 2.0                   # 基准(实际随机 0.5-2.5)
    p3.attack_interval_min = 1.8
    p3.attack_interval_max = 1.8
    p3.skill_slots = [4, 5]                      # M3-A (projectile), M3-B (summon)
    p3.summon_enabled = true
    p3.summon_interval = 10.0
    p3.summon_count = 3                          # 3-4, 用 randf 扩展
    p3.core_exposed = false
    p3.transition_duration = 0.5

    # Phase 4: 毕业考试
    var p4 := BossPhaseData.new()
    p4.phase_index = 3
    p4.phase_name = "毕业考试"
    p4.health_threshold = 0.0
    p4.move_speed = 115.0
    p4.defense = 0                                # 外壳碎裂
    p4.contact_damage = 30
    p4.aura_color = Color.TRANSPARENT             # 无光环
    p4.aura_alpha_min = 0.0
    p4.aura_alpha_max = 0.0
    p4.aura_pulse_period = 0.0
    p4.attack_interval_min = 0.8                 # 初始, 实际随 HP 递减
    p4.attack_interval_max = 1.5
    p4.skill_slots = [6, 7]                      # M4-A, M4-B
    p4.summon_enabled = false
    p4.summon_interval = 0.0
    p4.summon_count = 0
    p4.core_exposed = true                        # 攻击硬直期间可见
    p4.transition_duration = 0.5

    bp.init_phases([p1, p2, p3, p4])

    # === 新增: 创建 BossAI 实例 ===
    var boss_ai := BossAI.new()
    boss_ai.name = "BossAI"
    add_child(boss_ai)
    # 技能数组需要先创建技能, 然后传入 setup()
    # boss_ai.setup(self, _player_ref, bp, _boss_skills)

    # === 新增: 创建 BossAuraController ===
    var aura_ctrl := BossAuraController.new()
    aura_ctrl.name = "AuraController"
    add_child(aura_ctrl)
    # 获取或创建光环 ColorRect, 然后:
    # var aura_rect := get_node("BossVisual/Aura") as ColorRect
    # aura_ctrl.init(aura_rect)

    # === 新增: 创建 BossVisualAnimator ===
    var vis_anim := BossVisualAnimator.new()
    vis_anim.name = "VisualAnimator"
    add_child(vis_anim)
    # var parts := _get_boss_parts(visual_root)
    # vis_anim.init(parts)

    # 阶段转换信号连接
    bp.phase_transition_started.connect(_on_phase_transition_started)
    bp.phase_transition_finished.connect(_on_phase_transition_finished)
```

---

## 6. enemy.gd 修改要点

### 6.1 当前 `_boss_behavior` 替换

```gdscript
# 旧代码 — 删除整个 _boss_behavior 函数体
func _boss_behavior(delta: float) -> void:
    if _player_ref == null: return
    var dist := ...  # 所有这行以下的代码

# 新代码 — 委托给 BossAI
func _boss_behavior(delta: float) -> void:
    # 在 _build_boss_systems 中创建 BossAI 后赋值给 _boss_ai
    if _boss_ai:
        _boss_ai.tick(delta)
```

### 6.2 `_build_boss_systems` 需要新增

1. 使用 `BossVisual.create()` 创建七部件视觉 (替换当前的简单 ColorRect 拼装)
2. 创建 `BossAuraController` 并传入光环引用
3. 创建 `BossVisualAnimator` 并传入部件引用
4. 创建攻击技能实例 (使用 BossAttackData 参数)
5. 创建 `BossAI` 并传入所有依赖
6. 连接 `phase_transition_started` → 执行后撤 + 无敌 + 屏幕脉冲
7. 连接 `phase_transition_finished` → 恢复可攻击状态

### 6.3 阶段转换回调

```gdscript
func _on_phase_transition_started(from_idx: int, to_idx: int) -> void:
    # 1. 后撤
    if _player_ref:
        var retreat_dir := (global_position - _player_ref.global_position).normalized()
        var retreat_tween := create_tween()
        retreat_tween.tween_property(self, "global_position",
            global_position + retreat_dir * 100.0, 0.4)

    # 2. 无敌 + alpha 闪烁
    set_invincible(true)
    var flicker_tween := create_tween()
    for _i in 4:
        flicker_tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
        flicker_tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

    # 3. 屏幕边缘脉冲
    _trigger_screen_edge_pulse(to_idx)
    # (实现: 创建 4 个临时 ColorRect → Tween alpha → queue_free)

    # 4. 阶段名称 HUD 显示
    var pc := get_node_or_null("PhaseController") as BossPhaseController
    var phase_data: BossPhaseData = pc.get_current_phase_data() if pc else null
    if phase_data:
        EventBus.boss_phase_name_show.emit(phase_data.phase_name)

func _on_phase_transition_finished(_new_idx: int) -> void:
    set_invincible(false)
    sprite.modulate.a = 1.0
    # 如果是 Phase 3, 首次召唤学生
```

---

## 7. 实施优先级

### P0 — 核心机制 (第 1-2 天)
1. enemy.gd 接入 BossAI (替换 `_boss_behavior`)
2. BossPhaseData 填入完整参数 (见第 5 节)
3. BossVisual.create() 替换当前 enemy.gd 的简单拼装
4. 修复 hurtbox/hitbox 尺寸 (见第 4 节)
5. 四阶段不同的弹幕参数 (计数/速度/扇形角度)

### P1 — 阶段转换演出 (第 3-4 天)
6. 后撤 + 无敌闪烁
7. BossAuraController 颜色切换
8. 屏幕边缘脉冲
9. 阶段名称 HUD 显示

### P2 — 阶段特有机制 (第 5-7 天)
10. Phase 2 冲刺冲撞 (M2-B)
11. Phase 3 学生召唤 (M3-B)
12. Phase 4 三连弹幕 (M4-A) + 攻击间隔递减
13. Phase 4 核心暴露 + 1.5x 伤害
14. HP < 80 终局站桩

### P3 — 打磨 (第 8-10 天)
15. BossVisualAnimator 接入所有攻击姿态
16. 学生消散动画
17. 光环碎裂粒子
18. Phase 2 地面拖痕粒子
19. 所有弹幕的速度/颜色/大小微调
20. 与 GAP-01 终结序列 (小岛) 对齐

---

## 8. 攻击参数速查 (供技能实现)

| 攻击 ID | 阶段 | 弹幕数 | 扇形角 | 弹速 | 伤害/发 | 前摇 | 硬直 |
|---------|:---:|:-----:|:-----:|:----:|:------:|:---:|:---:|
| M1-A | 1 | 1 | 0° (直线) | 150 | 15 | 0.6s | 0.4s |
| M1-B | 1 | 3 | 50° (25°间隔) | 170 | 12 | 0.6s | 0.4s |
| M2-A | 2 | 5 | 90° (22.5°间隔) | 220 | 15 | 0.5s | 0.35s |
| M2-B | 2 | — (冲刺) | — | 380 (冲速) | 30 | 0.6s | 0.5s |
| M3-A | 3 | 5 | 90° (22.5°间隔) | 240 | 18 | 0.45s | 0.3s |
| M3-B | 3 | — (召唤) | — | — | — | 1.0s | 0.5s |
| M4-A | 4 | 3波×3 | 90° (45°间隔) | 280 | 18 | 0.4s | 0.5s |
| M4-B | 4 | — (冲刺) | — | 420 (冲速) | 35 | 0.4s | 0.5s |

---

## 9. 与现有设计的对齐说明

本文档是对已有的 `boss_ai.gd`、`boss_phase_controller.gd`、`boss_aura_controller.gd`、`boss_visual_animator.gd` 的**参数填充和接线指南**, 而不是替代它们。

| GAP-01 合并版 (小岛+宫崎) | 本文档 (宫崎 v2) | 关系 |
|---------------------------|-----------------|------|
| 13 个攻击 + 完整前摇/硬直/视觉 | 简化为 8 个核心攻击 | 选取最小可行集, 保留扩展入口 |
| 四乐章叙事框架 | 四阶段机制框架 | 叙事→机制映射不变 |
| 登场/终结序列 | 引用 GAP-01 不做改动 | 本文档只覆盖战斗中段 |
| 统一攻击表 + 数值总表 | 阶段参数 + 攻击参数速查 | 本文档的数值可填入 GAP-01 的 BossAttackData |
| 光环系统参数表 | BossAuraController 配置 | 直接对应, 无需改动 |

GAP-01 的登场序列 (潜伏姿态 → 沉默时刻 → 战斗开始) 和终结序列 (坍塌 → 粒子 → 胜利文字) 由小岛负责, 本文档专注**战斗中的四阶段差异化**。

---

*"Phase 1 teaches, Phase 2 tests, Phase 3 overwhelms, Phase 4 breaks. Each death should feel like a lesson, not a lottery." - 宫崎英高*
