# Boss 战优化专项 — 小岛秀夫

> **制作人：Hideo Kojima**
> **日期：2026-05-20**
> **性质：Boss 战体验优化方案。覆盖四阶段攻击模式重设计、数值调整、演出设计、开发任务拆解。**
> **前提：一切流程代码必须通用化——佐藤只是一个 Resource 配置。后续新 Boss 不改流程只配数据。**

---

## 零、现状诊断

审阅了全部现有代码后，以下是我的诊断，坦率地讲：

### 0.1 系统性问题

**问题一：双重攻击系统互相干扰。**

`enemy.gd:_boss_behavior()` 驱动一套硬编码的"特殊攻击"（shockwave、floor_aoe、charge），`boss_ai.gd:tick()` 驱动另一套技能系统。两套系统共享同一个 `_is_attacking/_is_boss_shooting` 标志位，但不协调。结果是 Boss 有时什么都不做——因为一边重置了 timer 另一边还在冷却。

**建议：彻底废除 `_boss_behavior()` 中的特殊攻击冷却系统。所有攻击行为统一由 BossAI + SkillBase 体系调度。这是宫崎 AI 专项应该覆盖的范围。**

**问题二：攻击间隔营造"发呆感"。**

当前 P1 攻击间隔 3.0s，加上技能前摇 0.6s 和后摇 0.5s，Boss 每 4 秒只做一件有意义的事。在玩家看来，Boss 站在那看着你——这不是体育老师，这是迟到的代课老师。

**问题三：阶段体验没有本质变化。**

P1→P4 的差异是"弹丸多了几颗、速度快了一点、间隔短了一点"。玩家感受不到"换乐章了"——只感受到"同一个技能，变了一点参数"。尤其是特殊攻击（shockwave/floor_aoe/charge）从 P1 就有，没有"新招式"的惊喜感。

**问题四：死亡演出被 game_manager 独揽。**

整个死亡序列在 `game_manager._boss_defeated_sequence()` 中用 `await get_tree().create_timer()` 硬编码。不通用、不可复用、不与 Boss 本体联动。新 Boss 需要重写整个序列。

**问题五：数值撑不起叙事。**

设计文档说 140 秒的 Boss 战。玩家实际 30 秒打完。原因可能是：防御系统未生效、有效 DPS 被低估、或 Boss 不动时玩家输出窗口 100% 而非设计的 40%。无论哪个原因，数值需要重新校准。

### 0.2 好消息

基础架构不差。`BossPhaseData` 已经是 Resource，`BossAI + SkillBase` 的可扩展性够用，`BossPhaseController` 的信号系统合理。问题在于内容——攻击模式的设计和数值的调校——而不是框架。

---

## 一、进攻欲望 —— "他不该让你有喘息的机会"

### 1.1 核心原则

> "一个好的 Boss 让玩家每 0.5 秒做一次决策。一个伟大的 Boss 让玩家忘记自己在做决策。"

Boss 的攻击节奏应该像心跳——越来越快，越来越密，直到玩家感觉自己被压碎。

### 1.2 乐章攻击间隔重设计

```
乐章    攻击间隔    间隔感觉           设计意图
─────────────────────────────────────────────────
P1      2.0s        从容               教学：给玩家时间看懂每种攻击
P2      1.5s        有节奏             压力：玩家需要开始认真走位
P3      1.0s        密集               压制：同时处理 Boss + 学生 + AOE
P4      0.8s→0.5s   窒息              绝望：几乎没有停顿，连续输出
```

**P4 间隔递减细则**（随剩余 HP 逐步缩减）：

| 剩余 HP | 攻击间隔 | 行为变化 |
|---------|---------|---------|
| > 300 | 0.8s | 正常 P4 |
| > 200 | 0.7s | 冲刺频率提升 |
| > 100 | 0.6s | 器材雨 CD 减半 |
| > 50 | 0.5s | 不再 KITE，全程 CHASE |
| < 50 | 0.4s | 站桩，所有技能连续释放，核心永久暴露 |

### 1.3 近战反制 —— "靠太近就要付出代价"

当玩家距离 Boss 小于 80px 时，Boss 应该立刻反击——不是"有时"，是"总是"。这模拟了体育老师的应激反应：你冲到面前，他本能地挥臂砸下来。

```gdscript
# 伪代码 — 在 BossAI 的 _movement_phaseX 中
var dist_to_player: float = _unit.global_position.distance_to(_player_ref.global_position)
if dist_to_player < 80.0 and _can_attack and not _is_attacking:
    # 打断当前技能队列，强制近战反击
    _force_melee_counter()
    return
```

近战反击技能池（每个乐章至少一个）：

| 反击名称 | 前摇 | 伤害 | 范围 | 硬直 | 效果 |
|---------|------|------|------|------|------|
| 哨子砸击 | 0.4s | 30 | Boss前方 60° 扇形，半径 90px | 0.6s | 击退 60px |
| 身体冲撞 | 0.5s | 35 | Boss前方 45° 扇形，半径 70px | 0.8s | 击退 100px + 1s 眩晕 |
| 震地反击 | 0.6s | 20 | Boss 周围 120px 圆形 | 1.0s | 全方向击退 80px |

### 1.4 追杀行为 —— "逃课？不存在的"

当玩家与 Boss 距离 > 300px 且持续超过 2.5s 时（P3/P4 缩短至 1.5s）：

1. Boss 停止当前技能
2. 短暂咆哮（0.3s，口哨闪光）
3. 向玩家方向高速冲刺（速度 500px/s，距离 350px）
4. 冲刺结束接一次哨子砸击

这不是一个"偶尔触发"的行为——这是 Boss 的惩罚机制。设计意图：告诉玩家"你不能在这间体育馆里逃跑。这堂课还没结束。"

---

## 二、机制丰富 —— "每一章是一首不同的曲子"

### 2.1 设计哲学

> 如果 P1 是"他在教你"，P2 是"他在测试你"，P3 是"他在呼唤"，P4 是"他在杀死你"——那么每一章必须有属于自己的一首曲子。

### 2.2 第一乐章：热身 — "示范动作"

**主题**：教学阶段。Boss 缓慢展示四种基本攻击模式，每种有充足的反应时间。

**移动策略**：KITE，保持 120-180px 距离。移速 55 px/s。

**攻击清单**（按固定循环 A→B→C→D）：

| ID | 名称 | 前摇 | 伤害 | 弹速 | 范围/弹道 | 视觉提示 |
|----|------|------|------|------|----------|---------|
| P1-A | 示范重击 | 0.7s | 25 | — | 前方 120° 扇形，半径 100px | 双臂后摆→身体亮白→前挥 |
| P1-B | 哨声音波 | 0.7s | 12 | 160 px/s | 前方 60° 扇形，3 发 | 口哨脉冲×3→白色声波圈 |
| P1-C | 前滚翻 | 0.8s | 20 | 冲刺 350 px/s | 直线冲刺 150px | 蹲下→拖痕粒子→前翻 |
| P1-D | 跳马践踏 | 1.0s | 15 | — | 60px 圆形，跟随玩家 | 红色预警圈从淡→深，锁定后爆炸 |

**循环间隔**：每击间隔 2.0s（从上一硬直结束到下一前摇开始）。

**为什么这样设计**：
- 4 种攻击涵盖 4 种躲法（侧闪/走位/翻滚/离开圈），教会玩家所有 Boss 战基础
- 固定循环：玩家可以学习节奏，"重击之后是声波，声波之后是前翻"
- 慢速弹幕：160px/s 几乎看到子弹飞来再反应都来得及

### 2.3 第二乐章：球类训练 — "器材从黑暗中飞来"

**主题**：场地利用和弹幕躲避。Boss 拿出"体育器材"。

**移动策略**：KITE 为主，保持 100-180px 距离。移速 70 px/s。

**新增攻击**（5 种，权重随机，不连续重复）：

| ID | 名称 | 前摇 | 伤害 | 参数 | 特殊 |
|----|------|------|------|------|------|
| P2-A | 抛投直球 | 0.4s | 18 | 直线，350 px/s | 快速球，打断站桩 |
| P2-B | 抛投高吊 | 0.6s | 22 | 抛物线，200 px/s，顶点 80px | 慢但范围大，落地留 0.5s 光斑 |
| P2-C | 哨声尖啸 | 0.6s | 12/发 | 前方 120°，5 发，250 px/s | 碰篮球架反弹一次（反弹伤害减半） |
| P2-D | 铁山靠 | 0.7s | 35 | 侧向冲刺 160px，400 px/s | 撞墙硬直 0.8s（引诱撞墙是战术） |
| P2-E | 震地三连 | 1.2s | 15/波 | 50/100/180px 三波 | 可跳跃/闪避帧穿越 |

**P2 新机制：场地互动**。
- P2-C 弹丸碰篮球架反弹——玩家可以用篮球架做掩体，但反弹弹幕可能从背后袭来
- P2-D 撞墙硬直——引诱 Boss 冲向墙壁是高风险高回报策略

### 2.4 第三乐章：集合 — "哨声叫来了学生"

**主题**：多线程威胁。玩家必须同时管理 Boss 和小怪。

**移动策略**：CHASE 为主（Boss 不再风筝，主动靠近）。移速 85 px/s。

**全新攻击模式**：

| ID | 名称 | 前摇 | 伤害 | 参数 | 特殊 |
|----|------|------|------|------|------|
| P3-A | 吹哨集合 | 1.2s | — | 召唤 3×学生 | 每 12s 触发，第 3 次为空哨 |
| P3-B | 抛投直球 | 同 P2-A | 18 | 同 P2-A | 复用，配合小怪压制 |
| P3-C | 冲刺追击 | 0.5s | 25 | 冲刺 160px，400 px/s | 玩家逃跑时优先使用 |
| P3-D | 地板 AOE ×5 | 0.8s | 20 | 5 个 80px 圆圈 | 散布在玩家周围，依次爆炸 |
| P3-E | 哨声震地 | 0.8s | 18 | 全屏圆形冲击波 500px | 击退效果，伤害低但打乱走位 |

**P3 新机制：小怪协同**。
- 学生不仅追玩家，还会**站位**：至少 1 个学生站在玩家撤退方向
- Boss 在地板 AOE 期间学生仍在移动——玩家不能只盯着 Boss
- 空哨叙事时刻：第 3 次吹哨无学生出现，Boss 停顿 1s，光环不稳定闪烁

### 2.5 第四乐章：毕业考试 — "最后的力量"

**主题**：一切压上来。绝望的、没有退路的终局。

**移动策略**：CHASE 全程（不再给玩家任何喘息）。移速 110 px/s，但 P4 开始后不再 KITE——Boss 始终向玩家移动。

**最终攻击模式**：

| ID | 名称 | 前摇 | 伤害 | 参数 | 特殊 |
|----|------|------|------|------|------|
| P4-A | 绝望冲刺×4 | 0.3s×4 | 18/次 | 4 连冲刺，每次锁定玩家方向 | 4 次后 Boss 喘气 1.5s，核心暴露 |
| P4-B | 全屏器材雨 | 1.5s | 22/波 | 5 波，每波 4 个器材从顶部落下 | 释放后核心暴露 2s |
| P4-C | 全屏扇形弹幕 | 0.5s | 20/发 | 前方 180°，11 发，400 px/s | 几乎覆盖前方整个半圆 |
| P4-D | 自爆学生 | 1.0s | 25/个 | 召唤 3 个爆炸学生 | 学生直接冲向玩家，3s 后自爆 |

**P4 新机制：核心暴露**。
- 每轮攻击后 Boss 胸口出现红色高亮方块（"核心"），受到 1.5x 伤害
- 核心暴露时间 = Boss 硬直时间
- HP < 50 时核心永久暴露——最后冲刺阶段，看谁能先杀掉对方

### 2.6 阶段转换演出 —— "幕间的沉默"

这不是一个简单的 alpha 闪烁。这是交响乐的乐章间休止。

**通用流程**（由 `BossPhaseController._do_transition_spectacle()` 驱动）：

```
t=0.00s  世界减速至 0.3x (持续 0.8s)
t=0.00s  屏幕暗角拉到 0.75 alpha
t=0.00s  Boss 光环从旧颜色 Tween 到新颜色 (1.0s)
t=0.15s  全屏文字淡入："第X乐章 —— [乐章叙事标题]" 
         文字呼吸 pulse (scale 1.0 ↔ 1.05, period 0.8s)
t=0.30s  Boss 仰头咆哮：口哨脉冲×3 + 光环扩张 scale 1.0→2.0→1.0
t=0.25s  粒子从 Boss 位置 8 方向爆发 (颜色 = 新光环色)
t=0.60s  暗角回到战斗水平
t=0.80s  世界恢复 1.0x
t=0.80s  大字淡出
t=0.80s  Boss 获得 0.5s 无敌帧（防止玩家在转换期间偷袭）
         → transition_finished 信号发出，AI 恢复
```

**通用实现要点**：
- `BossPhaseController` 不硬编码任何"佐藤"文本——叙事标题从 `BossPhaseData` 的 `transition_title` 和 `transition_subtitle` 新字段读取
- 全屏文字控件复用已有的 `VictoryTextUI` 模式（临时 Label + Tween 进入/退出）
- 暗角操作通过已有的 `VignetteController.BOSS_PHASE_TRANSITION` 新状态
- 世界减速使用 `Engine.time_scale`，但必须用 `Tween.TWEEN_PROCESS_IDLE` 保证 UI Tween 不受影响

---

## 三、成就感 —— "他终于下课了"

### 3.1 最后一击

当前：Boss HP 降到 0 → `_die()` → `game_manager._boss_defeated_sequence()` 独立播放。

**问题**：两套死亡逻辑（enemy.gd 的 `_die()` 有一版，game_manager 有另一版），两者各做一半且不协调。

**改造方案**：死亡演出做成通用管线。

#### 3.1.1 死亡演出通用管线

新信号链：

```
CombatUnit._die()               # 内部：设置 is_dead=true，禁用 AI
  → EventBus.boss_executing.emit(boss_id)    # "Boss 正在死亡"（区别于 killed）
  → enemy.gd 中 Boss 专属死亡协程接管        # 这里处理所有视觉演出
  
enemy.gd:_boss_death_sequence():
  1. Big Hit Stop — Engine.time_scale = 0.05, 持续 0.15s
  2. 时缓展开 — time_scale 0.05→0.3→0.6→1.0, 持续 0.8s (缓出)
  3. Boss 坍塌 — 纵向压缩(scale.y→0.3) + 横向拉宽(scale.x→1.5) + 灰度化
  4. 口哨掉落 — whistle 部件脱离 body，旋转→落地→消失
  5. 金色粒子爆发 — 从坍塌位置 40 个金色粒子
  6. 大字文字 — 调用 BossDeathTextUI (通用组件)
  7. → EventBus.boss_killed.emit(boss_id, position, display_name)
  
game_manager._on_boss_killed():
  → 接收信号，执行战后逻辑（清理/经验/升级/门解锁）
  → 不做视觉演出——那是 enemy.gd 的职责
```

#### 3.1.2 大字文字组件：BossDeathTextUI

通用组件，接收参数：
- `boss_display_name: String` — 如 "佐藤 幸雄"
- `defeat_text: String` — 如 "下课。"
- `text_color: Color` — 如 Color(1.0, 0.15, 0.05)
- `duration: float` — 停留秒数，默认 3.0

行为：
1. 从屏幕中央偏上位置淡入（scale 0.5→1.0，alpha 0→1，0.3s）
2. 呼吸脉冲（scale 1.0 ↔ 1.03，period 1.0s）
3. 停留 duration 秒
4. 淡出（0.4s）
5. queue_free()

#### 3.1.3 专属胜利反馈："佐藤的馈赠"

**触发条件**：Boss 被击败后弹出的第一个升级面板。

**效果**：
- 标题从"升级！"改为"佐藤的馈赠"
- 入场动画从 Boss 倒下位置（屏幕坐标）放大绽放，而非从屏幕中心
- 面板间 stagger 0.3s（比通常的 0.5s 快——"馈赠涌来了"）
- 15% 概率出现第四选项"哨声"（Operator Protocol）：
  - 描述："你听到了一声哨响——但你已经听不到哨响了。"
  - 选中后 UI 乱码 5s

**实现要点**：
- 在 `game_manager._boss_defeated_sequence()` 中设置 `_is_post_boss_upgrade = true`
- `_show_upgrade_panel()` 检测此标志，走 Boss 专属逻辑
- Boss 倒下时的屏幕坐标存入 `_boss_defeat_screen_pos: Vector2`，供面板入场动画使用

---

## 四、数值调整 —— "让体育课持续 3 分钟"

### 4.1 当前问题分析

当前 Boss 被 30 秒击败。设计目标 140 秒。差距约 4.7 倍。

可能原因分析：
1. **防御系统未生效**：需要验证 `take_damage()` 是否实际减去了 `defense` 值
2. **有效 DPS 被低估**：设计文档算 12，实际可能 25-35（玩家升级后）
3. **Boss 不动 = 100% 输出窗口**：如果 Boss 保持 KITE 距离且攻击间隔长，玩家全程无压力输出
4. **暴击/技能爆发未计入**：玩家技能可能有额外的伤害来源

### 4.2 数值调整方案

#### 4.2.1 HP 提升

```
方案 A（保守）：2000 HP (500 × 4)
    有效 DPS 约 16 → 125s 战斗

方案 B（推荐）：2400 HP (600 × 4)  
    有效 DPS 约 16 → 150s 战斗
    
方案 C（硬核）：3200 HP (800 × 4)
    有效 DPS 约 16 → 200s 战斗
```

**推荐方案 B**。2400 总 HP 给予每个乐章充足的叙事时间，同时不会拖到令人疲惫。

如果后续 Boss 需要不同时长，通过 `DungeonConfig.boss_hp_multiplier` 参数化调整。

#### 4.2.2 防御力重设

防御力必须在伤害计算中生效。检查 `CombatUnit.take_damage()` 是否需要加防御减免。

```gdscript
# 推荐公式：实际伤害 = max(原始伤害 - defense * 0.5, 1)
# 即每点防御减少 0.5 伤害，保证伤害至少为 1
```

| 乐章 | 防御力 | 减免 | 设计意图 |
|------|-------|------|---------|
| P1 | 3 | -1.5 | 正常伤害，教学阶段 |
| P2 | 7 | -3.5 | 开始有韧性 |
| P3 | 12 | -6.0 | 最硬阶段，逼玩家先清小怪 |
| P4 | 0 | 0 | 外壳碎裂，核心暴露 1.5x |

P4 的 0 防御 + 1.5x 核心伤害 = 等效伤害 1.5x 原始值。这是有意为之——让最终乐章在"Boss 最危险"和"Boss 最脆弱"之间建立张力。

#### 4.2.3 伤害重设

| 攻击类型 | P1 | P2 | P3 | P4 |
|---------|----|----|----|-----|
| 基础弹幕（每发） | 12 | 18 | 22 | 28 |
| 近战重击 | 25 | 30 | 35 | 40 |
| 冲刺撞击 | 20 | 28 | 32 | 18×4=72 |
| AOE 技能 | 15 | 20 | 25 | 25 |
| 接触伤害（碰到 Boss 本体） | 18 | 22 | 28 | 35 |

**注意**：P4 绝望冲刺是 4 连击。单次伤害低（18），但如果全中 = 72。这是有意为之——"你可以躲前 3 次，但第 4 次不一定"。

#### 4.2.4 学生小怪调整

当前学生 HP=15 太脆——AOE 一碰就碎。适度提升让玩家必须面对选择：先清学生还是继续输出 Boss。

| 属性 | 旧值 | 新值 | 原因 |
|------|-----|------|------|
| HP | 15 | 25 | 不会一碰就碎 |
| 移速 | 140 | 120 | 稍慢一点，让学生群更有"包围"感 |
| 接触伤害 | 8 | 12 | 不能被玩家完全忽视 |
| 最大数量 | 9 | 8 | 减少 1 个保持场面可管理 |

### 4.3 数值验证公式

```
目标战斗时长 T_target = sum(phase_hp / (player_dps * window_ratio - phase_def * 0.5))

假设：
  player_dps = 20（考虑升级）
  window_ratio = 0.55（P1 高窗口）→ 0.30（P4 低窗口）
  
  P1: 600 / (20 * 0.55 - 3 * 0.5) = 600 / 9.5 = 63s
  P2: 600 / (20 * 0.45 - 7 * 0.5) = 600 / 5.5 = 109s ← 太长了
  
  调整：P2 提高窗口比至 0.50
  P2: 600 / (20 * 0.50 - 7 * 0.5) = 600 / 6.5 = 92s ← 仍偏长
  
  问题：防御公式导致窗口期被过度惩罚。修正防御公式：
  实际伤害 = max(原始伤害 - defense * 0.33, 1)
  
  P1: 600 / (20 * 0.55 - 3 * 0.33) = 600 / 10.01 = 60s
  P2: 600 / (20 * 0.50 - 7 * 0.33) = 600 / 7.69 = 78s
  P3: 600 / (20 * 0.40 - 12 * 0.33) = 600 / 4.04 = 149s ← P3 太长了
  
  问题核心：P3 防御太高 + 窗口低。降低 P3 防御：
  P3 defense = 8 (减免 -2.64)
  P3: 600 / (20 * 0.40 - 8 * 0.33) = 600 / 5.36 = 112s ← 仍偏长
  
  进一步调整：P3 窗口比提高到 0.45
  P3: 600 / (20 * 0.45 - 8 * 0.33) = 600 / 6.36 = 94s

P4: defense=0, 核心暴露 1.5x, window≈0.35
  P4: 600 / (20 * 1.5 * 0.35) = 600 / 10.5 = 57s

总计: 60 + 78 + 94 + 57 = 289s ≈ 4.8分钟 ← 太长了
```

数值反推暴露了一个问题：防御力让有效 HP 膨胀太多。需要更保守的数值。

#### 4.3.1 修正方案（迭代后）

```
防御公式：实际伤害 = max(原始伤害 - defense, 1)
          即 1 点防御减 1 点伤害（直观、可预测）

HP 分配：2000 总 HP (500 × 4)

| 乐章 | HP  | 防御 | 攻击间隔 | 玩家有效DPS | 预计时长 |
|------|-----|------|---------|------------|---------|
| P1   | 500 | 2    | 2.0s    | ~13        | ~38s    |
| P2   | 500 | 4    | 1.5s    | ~11        | ~45s    |
| P3   | 500 | 6    | 1.0s    | ~9         | ~56s    |
| P4   | 500 | 0    | 0.8s→0.5s| ~18 (核心) | ~28s    |

总计: 38 + 45 + 56 + 28 = 167s ≈ 2分47秒
```

这个数值符合"一场有分量的 Boss 战"的体验。如果测试后偏长，第一个调的是防御力而非 HP。

**宫崎需要在他的数值推演中确认和细化这些数字。这里给出的是方向，不是最终值。**

---

## 五、通用架构 —— "这不是佐藤的系统，这是 Boss 的系统"

### 5.1 Generalization Map

| 现有实现 | 问题 | 通用化方案 |
|---------|------|-----------|
| `enemy.gd:_boss_behavior()` 硬编码特殊攻击 | 新 Boss 需要改 enemy.gd | **废除**。所有攻击移入 SkillBase 子类 |
| `game_manager._boss_defeated_sequence()` 硬编码演出时序 | 新 Boss 重写整个序列 | **移入 enemy.gd**，由 `_boss_death_sequence()` 驱动 |
| 阶段转换只有 retreat+flicker | 无叙事 | 通用 `_do_transition_spectacle()` 读取 Resource 字段 |
| 攻击参数散落在 enemy.gd 变量中 | 不可配置 | 移入 `BossPhaseData` 新字段 |
| Boss 名称/文字硬编码在 game_manager | 不通用 | 移入 `BossPhaseData` 或 `BossConfig` Resource |

### 5.2 BossPhaseData 新增字段

```gdscript
class_name BossPhaseData
extends Resource

# === 现有字段保持不变 ===
@export var phase_index: int = 0
@export var phase_name: String = ""
# ... (所有现有字段保留)

# === 新增：阶段转换演出 ===
@export var transition_title: String = ""       # "第一乐章"
@export var transition_subtitle: String = ""    # "热身"
@export var transition_narrative: String = ""   # "他在示范动作。看好了。"
@export var transition_particle_color: Color = Color.WHITE

# === 新增：攻击模式 ===
@export var close_range_skill_slot: int = -1    # 近战反击技能槽位
@export var chase_distance_threshold: float = 300.0  # 距离>此值触发追杀
@export var chase_patience: float = 2.5         # 距离超阈值允许的忍耐时间
@export var chase_speed: float = 500.0          # 追杀冲刺速度
@export var chase_distance: float = 350.0       # 追杀冲刺距离

# === 新增：召唤系统 ===
@export var summon_skill_slot: int = -1         # 召唤技能槽位（替代原先用 slot 0 的约定）
@export var empty_summon_trigger_count: int = 3 # 第几次召唤触发空哨（0=不触发）
@export var max_minions: int = 8                # 场上最大学生数
```

### 5.3 BossConfig Resource（新增）

为支持跨 Boss 通用化，新增一个顶层配置 Resource：

```gdscript
class_name BossConfig
extends Resource

@export var boss_id: String = "boss_default"
@export var boss_display_name: String = "UNKNOWN"
@export var boss_defeat_text: String = "已击败"
@export var boss_defeat_color: Color = Color(1.0, 0.15, 0.05)
@export var total_hp: int = 2000
@export var phases: Array[BossPhaseData] = []
@export var skills: Array[PackedScene] = []       # 每个技能的 .tscn 或 Resource
@export var minion_scene: PackedScene = null       # 小怪场景（如有）
```

然后 `_build_boss_systems()` 改为接收 `BossConfig` 参数而非硬编码四阶段数据：

```gdscript
func _build_boss_systems(cfg: BossConfig) -> void:
    var bp := BossPhaseController.new()
    bp.init_phases(cfg.phases)
    # ...
```

### 5.4 通用死亡演出管线

所有 Boss 的死亡演出走同一条管道。差异仅在于 Resource 参数。

```
BossDeathPipeline (enemy.gd 或独立 Node)
  └── _boss_death_sequence(cfg: BossConfig):
        ├── _death_hit_stop(duration: float)           # 时缓 + 冻结
        ├── _death_collapse(duration: float)           # 坍塌动画
        ├── _death_particles(color: Color, count: int) # 粒子爆发
        ├── _death_text_ui(cfg)                        # 大字文字
        └── emit boss_killed signal                    # 通知外部系统
```

---

## 六、开发任务拆解

### 任务 A：Boss 数值调校
**负责人：数值策划**
**依赖：宫崎 AI 专项**

- [ ] A1. 验证当前防御系统是否生效（在 `take_damage()` 中断点调试）
- [ ] A2. 基于本文第四章数值方案，细化每阶段 HP/防御/伤害/间隔
- [ ] A3. 在 Dev 场景中放置测试按钮（直接进 Boss 战），迭代调参
- [ ] A4. 输出 `BossPhaseData` Resource 最终数值表
- [ ] A5. 与宫崎对数值（确认 DPS 窗口率推算）

### 任务 B：Boss AI 行为改造
**负责人：战斗程序**
**依赖：宫崎 AI 专项、任务 A**

- [ ] B1. **废除** `enemy.gd:_boss_behavior()` 中的特殊攻击冷却系统（shockwave/floor_aoe/charge 独立冷却）
- [ ] B2. 在 `BossAI` 中实现近战反制逻辑（距离 < 80px 强制反击）
- [ ] B3. 在 `BossAI` 中实现追杀行为（距离 > 阈值 + 时间超限 → 冲刺追杀）
- [ ] B4. 重构 `_select_and_execute_attack()` 以支持本文第二章的新攻击选择策略
- [ ] B5. P4 攻击间隔递减逻辑（基于剩余 HP 百分比）
- [ ] B6. P4 核心暴露机制（硬直期间显示 CoreHighlight，接收 1.5x 伤害）

### 任务 C：新技能实现
**负责人：战斗程序**
**依赖：任务 B**

- [ ] C1. 实现 P1-C 前滚翻冲撞技能（复用或改造 `SkillM1_RollCharge`）
- [ ] C2. 实现 P1-D 跳马践踏技能（新 `SkillM1_VaultStomp`）
- [ ] C3. 实现 P2-A 抛投直球（已有 `SkillM2_Fastball`，确认是否满足需求）
- [ ] C4. 实现 P2-B 抛投高吊（抛物线弹道，落地 AOE）
- [ ] C5. 实现 P2-D 铁山靠（侧向冲刺，撞墙硬直）
- [ ] C6. 实现 P2-E 震地三连（三道同心冲击波）
- [ ] C7. 实现 P3-D 地板 AOE×5（散布式预警圈 + 依次爆炸）
- [ ] C8. 实现 P3-E 哨声震地（全屏击退波）
- [ ] C9. 实现 P4-D 自爆学生（冲向玩家 → 倒计时 → 爆炸）
- [ ] C10. 实现近战反击技能池（哨子砸击/身体冲撞/震地反击）

### 任务 D：演出系统
**负责人：杨奇 + 交互策划**
**依赖：任务 B**

- [ ] D1. 实现通用阶段转换演出（`BossPhaseController._do_transition_spectacle()`）
- [ ] D2. 实现全屏大字标题组件 `PhaseTransitionTitleUI`（可复用）
- [ ] D3. 实现环节转换粒子效果（杨奇 8 方向色粒子爆发）
- [ ] D4. 实现通用死亡演出管线（慢动作 → 坍塌 → 粒子 → 大字）
- [ ] D5. 实现 `BossDeathTextUI` 通用组件
- [ ] D6. P4 核心暴露的视觉表现（红色高亮方块 + 脉冲）
- [ ] D7. P4 光环碎裂效果（光环 ColorRect 裂成碎片飞出）
- [ ] D8. 阶段转换 0.3s 暂停 + 暗角变化（`VignetteController` 新状态）
- [ ] D9. Boss 咆哮效果（口哨脉冲 + 光环扩张 + 屏幕微震）

### 任务 E：通用化架构
**负责人：系统程序**
**依赖：任务 A-D 全部**

- [ ] E1. 创建 `BossConfig` Resource 类
- [ ] E2. `BossPhaseData` 新增本文 5.2 节字段
- [ ] E3. 重构 `enemy.gd:_build_boss_systems()` 接收 `BossConfig` 参数
- [ ] E4. 死亡演出从 `game_manager` 移入 `enemy.gd`（或独立 `BossDeathPipeline` Node）
- [ ] E5. 阶段转换演出从 `enemy.gd` 移入 `BossPhaseController`
- [ ] E6. 验证：创建第二个 Boss 的 Resource 配置，确认无需改流程代码

### 任务 F：UI/交互
**负责人：交互策划**
**依赖：任务 D, E**

- [ ] F1. "佐藤的馈赠"升级面板特殊逻辑
- [ ] F2. 全屏文字控件复用抽象
- [ ] F3. Boss 头顶血条阶段颜色变化（已有，确认 P3 白色/P4 暗色）
- [ ] F4. P4 低血量屏幕警告（已有 `_low_hp_overlay`，确认与 Boss 战兼容）

---

## 七、与宫崎 AI 专项的衔接点

### 7.1 共享接口

宫崎的 AI 专项在重构敌方 AI 框架。本方案依赖以下接口保持稳定：

| 接口 | 提供方 | 消费方 | 说明 |
|------|-------|-------|------|
| `BossAI.tick(delta)` | BossAI | `enemy._boss_behavior()` | 每帧调用主循环 |
| `BossAI._chase_player(speed)` | BossAI | 内部移动逻辑 | 简单追踪 |
| `BossAI._kite_player(speed, min, max)` | BossAI | 内部移动逻辑 | 风筝 |
| `BossPhaseController.get_current_phase_data()` | BossPhaseController | BossAI / Skills | 获取当前阶段数据 |
| `SkillBase.try_execute()` | SkillBase 子类 | BossAI | 触发技能（含前摇+后摇） |
| `SkillBase.is_ready` | SkillBase | BossAI | 技能是否可用（CD/状态） |
| `EventBus.boss_phase_changed` | BossPhaseController | 全局 | 阶段变化通知 |
| `EventBus.boss_killed` | enemy.gd | game_manager | Boss 死亡通知 |

### 7.2 宫崎需要确认的事项

1. **攻击可读性标准**：本文设计的前摇区间是 0.4s（快速弹幕）到 1.5s（大招），是否满足宫崎的"魂系可读性"标准？
2. **硬直窗口**：每技能硬直 0.3-1.0s（玩家反击窗口），是否与统一战斗框架的"stagger"系统重合？
3. **防御公式**：`damage = max(raw - defense, 1)` ——宫崎的数值推演是否使用同一公式？
4. **AI 行为模式**：本文的 KITE/CHASE 分类是否与宫崎的 AI 行为模式（PATROL/FLEE/GUARD 等）冲突？BossAI 是否需要继承 AIBehaviorController？

### 7.3 代码交汇点

以下文件会被两边的改动同时触达，需要提前协调：

- `scripts/enemy.gd` → 宫崎改 `_melee_behavior/ranged_behavior`，本方案改 `_boss_behavior`
- `scripts/boss/boss_ai.gd` → 宫崎改 AI 框架，本方案改 Boss 专属移动/攻击选择
- `scripts/boss/boss_phase_controller.gd` → 本方案新增转阶段演出
- `scripts/resources/boss_phase_data.gd` → 本方案新增字段
- `scripts/skills/base/skill_base.gd` → 宫崎可能改技能基类

**建议**：让战斗程序做所有 Boss 专属代码的改动，宫崎只改框架/抽象层。两人在 `boss_ai.gd` 上的改动通过独立分支 + merge review 协调。

---

## 八、验收标准

### 8.1 体验标准

- [ ] Boss 战持续 120-180 秒（约 2-3 分钟），不是 30 秒
- [ ] 玩家能清晰感受到四个阶段的差异——不是数值变，是"感觉变了"
- [ ] Boss 从不发呆：任何时候屏幕上都有 Boss 的行动（移动/前摇/攻击/硬直/技能）
- [ ] 玩家跑远时 Boss 追杀——"逃课"被惩罚
- [ ] 玩家贴脸时 Boss 近战反击——"莽"被惩罚
- [ ] 击杀瞬间有情感冲击力——玩家会停住看 2 秒大字

### 8.2 技术标准

- [ ] 所有 Boss 行为通过 SkillBase 子类实现（不在 enemy.gd 中硬编码）
- [ ] 阶段转换演出是 `BossPhaseController` 的通用能力
- [ ] 死亡演出是通用管线（`BossDeathPipeline`），不绑定佐藤
- [ ] 新 Boss 只需新建 `BossConfig` Resource + 技能脚本，不动流程代码
- [ ] `enemy.gd:_boss_behavior()` 不再有独立冷却系统（shockwave/floor_aoe/charge 变量移除）

---

## 九、做减法的勇气

最后，一个来自制作人的建议——我们经常犯的错误是"加太多"。

看完现有代码，我注意到三件事可以删掉：

1. **`_boss_behavior()` 中的 shockwave/floor_aoe/charge 独立冷却系统**——这些是旧的临时实现，现在有技能系统了，删掉它们。Boss 不该有两套攻击系统。

2. **`_boss_shoot()` in enemy.gd**——这个和 `SkillM1_WhistleWave` 功能重叠。现在的扇形弹幕应该只走技能系统，删掉 `_boss_shoot()` 和相关的 `_is_boss_shooting` / `_boss_shoot_timer`。

3. **`_boss_defeated_sequence()` 中的硬编码时间线**——改为事件驱动的管线。`await get_tree().create_timer(0.5)` 这类硬编码值在下一个 Boss 身上一定会出错。

删掉这些，代码会干净很多。然后我们再在干净的基础上建造新东西。

> "Perfection is achieved not when there is nothing more to add, but when there is nothing left to take away."
> — Antoine de Saint-Exupery

---

*—— 小岛秀夫*
*2026-05-20*
*Kojima Productions*
