# GAP-01c 美术任务 — Boss 战视觉实现

> **基于：GAP-01 Boss战最终设计-合并版**
> **负责人：杨奇（美术总监）**
> **总计工时：~5.5 天**

---

## 前置说明

所有视觉实现**完全基于 ColorRect 拼装体系**——不引入任何外部图片资源。不需要手绘。不需要 3D 模型。不需要 Sprite2D。一切都用 Godot 内置的 ColorRect + Tween + GradientTexture2D 完成。

杨奇的话："用 ColorRect 能做到的比你们想象的多得多。"

---

## 任务清单

### TASK-V01: Boss 多 ColorRect 拼装视觉

- **负责人**：杨奇
- **工作量**：1 天
- **依赖**：无
- **产出**：`scenes/boss_sato.tscn` 场景文件

**设计目标**：用 5 个 ColorRect 节点拼出一个"体育老师"的形象——宽肩站姿、银色口哨、可变色光环。

**具体设计**：

1. **节点结构**（所有节点为 ColorRect）：
```
BossSato (CombatUnit / CharacterBody2D)
├── Aura (光环层，z_index=0)
│   - 颜色：随乐章变化（橙/黄/白/无）
│   - 尺寸：96x96（比主体大一圈）
│   - 位置：居中（offset = -48, -48 到 48, 48）
│   - modulate.a：0.1-0.4（脉冲呼吸）
│   - mouse_filter = IGNORE
│
├── Body (主体，z_index=2)
│   - 颜色：Color(0.6, 0.08, 0.05) 深红
│   - 尺寸：64x80（宽 > 高——宽肩站姿）
│   - 位置：居中（offset = -32, -40 到 32, 40）
│   - 注意：使用 offset_left/right/top/bottom 控制位置
│
├── Whistle (口哨，z_index=3)
│   - 颜色：Color(0.6, 0.6, 0.65) 银色
│   - 尺寸：10x8（小方块）
│   - 位置：在 Body 的"颈部"——offset = (-5, -42) 到 (5, -34)
│   - 这是佐藤最标志性的视觉锚点
│
├── ArmL (左臂，z_index=1)
│   - 颜色：同 Body
│   - 尺寸：14x40（细长）
│   - 位置：Body 左侧，offset = (-46, -20) 到 (-32, 20)
│   - pivot_offset = (7, 20)（旋转轴在"肩膀"处）
│
├── ArmR (右臂，z_index=3)
│   - 颜色：同 Body
│   - 尺寸：14x40
│   - 位置：Body 右侧，offset = (32, -20) 到 (46, 20)
│   - pivot_offset = (7, 20)（旋转轴在"肩膀"处）
│
├── HitFlash (受击闪白，z_index=4)
│   - 颜色：Color.WHITE, alpha=0
│   - 尺寸：覆盖整体
│
├── CoreHighlight (核心高亮，z_index=5)
│   - 颜色：Color(1.0, 0.2, 0.05, 0) 红色
│   - 尺寸：16x16 小方块
│   - 位置：Body 胸口位置
│   - 默认 invisible，第四乐章暴露弱点时显示
│
└── HealthBar (头顶小血条，ProgressBar, z_index=6)
    - 在头顶上方 8px
    - 仅在 Boss 血条（屏幕顶部）不可用时作为 fallback
```

2. **整体 scale**：
   - Boss 根节点 `scale = Vector2(3.0, 3.0)`（与现有 Boss 3x 缩放保持一致）
   - Aura/Body/Whistle/Arms 的 offset 值基于 scale=1 设计，scale=3 自动放大

3. **潜伏姿态（登场前）**：
   - `Body.scale.y = 0.5`（蹲伏——像一个蹲在角落的巨大阴影）
   - `ArmL.scale.y = 0.5`
   - `ArmR.scale.y = 0.5`
   - `modulate.a = 0.3`（半透明——"那个轮廓不是器材室的阴影"）
   - 动画：微弱的 alpha 呼吸（0.28 ↔ 0.32，周期 2s）

4. **战斗姿态（激活后）**：
   - `Body.scale = Vector2(1.0, 1.0)`（正常站立）
   - `modulate.a = 1.0`
   - 左臂/右臂在身体两侧微摆（±2° rotation，周期 0.8s——呼吸感）

**验收标准**：Boss 场景在编辑器中正确显示——主体+四肢+口哨+光环 5 个 ColorRect。潜伏姿态和战斗姿态可切换。

---

### TASK-V02: Boss 攻击动画/姿态

- **负责人**：杨奇
- **工作量**：1.5 天
- **依赖**：TASK-V01
- **产出**：`scripts/combat/boss_visual_animator.gd` + `.uid`

**设计目标**：每个攻击动作有独特的视觉姿态变化——让玩家看到 Boss 的 ColorRect 形状变化就知道"它要做什么"。

**具体设计**：

创建 `BossVisualAnimator` 节点（挂在 Boss 下），连接技能信号 `windup_started` / `windup_finished` / `recovery_finished` 来驱动姿态动画。

每个攻击的姿态变化：

| 攻击 ID | 前摇姿态 | 释放姿态 | 硬直姿态 | 持续时间 |
|---------|---------|---------|---------|---------|
| M1-A 示范重击 | 双臂同时后摆 (rotation -30°) + Body 微后仰 (rotation -5°) | 双臂前挥 (rotation +20°) + Body 微前倾 (rotation +3°) + 光环扩张 scale 1.0→1.3 | 双臂恢复原位 | 前摇 0.6s / 释放 0.1s / 硬直 0.5s |
| M1-B 哨声音波 | Whistle scale 脉冲 1.0→1.2→1.0 (0.15s) + Whistle 颜色白→橙红渐变 | 3 个白色声波圈从 Boss 位置扩散 | 保持站立 | 前摇 0.6s / 硬直 0.4s |
| M1-C 前滚翻冲撞 | Body.scale.y 压缩到 0.5（蹲下）+ Body 颜色变深红。地面出现横向拖痕粒子（3 个小 ColorRect 在 Boss 脚下） | 向玩家方向冲刺，Body.scale.x 拉伸 1.0→1.3（速度线效果） | Body 恢复正常 scale | 前摇 0.8s / 冲刺 0.5s / 硬直 0.3-0.5s |
| M1-D 跳马践踏 | 双臂撑地：ArmL+ArmR rotation -60°→身体前倾 Body rotation -15°。地面出现红色圆形标记（独立 ColorRect，scale 从 0→1.0，颜色淡红→深红） | Boss 跳跃（position.y -20 → 0，0.2s）→落地震动（Body scale.y 短暂压缩到 0.8 再恢复） | 恢复站立 | 前摇 1.0s / 硬直 0.8s |
| M2-A 抛投直球 | 右臂大幅后摆 rotation -45°。右臂末端出现亮黄色"器材"小方块（独立 ColorRect 临时创建） | 右臂前甩 rotation +30°。器材沿直线飞出。器材方块在飞行中旋转 | 右臂归位 | 前摇 0.4s / 硬直 0.3s |
| M2-B 抛投高吊 | 右臂后摆 + 身体后仰 Body rotation -8°。器材方块颜色更亮（橙黄） | 右臂上举 rotation -60°（向上）。器材以弧线飞出 | 右臂归位。器材落地后 0.5s 光斑留在原地 | 前摇 0.5s / 硬直 0.3s |
| M2-C 哨声尖啸 | Whistle 快速闪白 2 次 (0.1s 间隔)。Boss 身体短暂膨胀 scale 1.0→1.05 | 5 个白色声波圈同时扩散（比 M1-B 多 2 个，角度更宽） | 恢复正常 scale | 前摇 0.5s / 硬直 0.4s |
| M2-D 铁山靠 | Body 旋转 90°（侧向姿态）+ Body 颜色短暂金属化（闪灰 `Color(0.5, 0.5, 0.55)`）。双臂紧贴身体 | 侧向横靠——Body 沿横向快速位移。释放瞬间金属光泽闪烁 | Body 转回正面 + 颜色恢复深红 | 前摇 0.6s / 硬直 0.6s |
| M2-E 震地波 | 双臂高抬 rotation -80°→→双手砸地 rotation +10°。Body.scale.y 压缩→扩张。地面出现 3 道红色圆环 | 3 道圆环从 Boss 中心向外扩散（独立 ColorRect，scale 0.3→各自目标尺寸） | 恢复正常站立 | 前摇 1.2s / 硬直 1.0s |
| M3-A 吹哨集合 | Whistle scale 快速脉冲 3 次 (0.08s×3)。Boss 仰头 Body rotation -10°。3 道白色声波从 Boss 扩散至屏幕边缘 | 声波到达边缘后 3 个白色小方块（学生）在边缘出现 | 恢复站立 | 前摇 1.2s / 硬直 0.5s |
| M4-A 绝望冲刺×4 | 每次冲刺前 Body 短暂闪烁（modulate 变亮 0.1s）。第 4 次后：Body 颜色变暗 + 上半身低垂 Body rotation -8°（"喘气"） | 每次冲刺 Body.scale.x 拉伸 | 第 4 次后硬直 1.0s，期间 CoreHighlight 可见 | 前摇 0.4s×4 |
| M4-B 器材雨 | 屏幕变暗（全屏半透明黑 ColorRect alpha 0→0.3, 0.5s）。Boss 跳至场地中央→缩成一团 scale 0.6。天空出现红色方形投影 | 5 波器材坠落，每波器材 ColorRect（16x16 暗红色）从屏幕顶部 tween 到地面。落地时投影闪烁→器材出现 | Boss 展开 + CoreHighlight 可见 | 前摇 1.5s / 硬直 2.0s |

**技术实现要点**：

```gdscript
class_name BossVisualAnimator
extends Node

var _boss: CombatUnit
var _body: ColorRect
var _whistle: ColorRect
var _aura: ColorRect
var _arm_l: ColorRect
var _arm_r: ColorRect
var _core: ColorRect

# 攻击姿态动画
func play_windup(attack_id: String, duration: float) -> void:
    match attack_id:
        "M1-A": _heavy_sweep_windup(duration)
        "M1-B": _whistle_wave_windup(duration)
        # ...

# 所有 Tween 使用 TWEEN_PROCESS_IDLE
# 所有 Tween 的 group 使用 "boss_visual"
```

**验收标准**：每个攻击的视觉姿态可辨识。前摇姿态让玩家能预判"Boss 要做什么"。释放姿态有冲击力。硬直姿态暴露输出窗口。

---

### TASK-V03: 光环系统四乐章颜色变化

- **负责人**：杨奇
- **工作量**：0.5 天
- **依赖**：TASK-V01
- **文件**：`scripts/combat/boss_aura_controller.gd` + `.uid`

**设计目标**：光环是 Boss 最重要的视觉信号——它告诉玩家"现在在第几乐章"。光环的颜色、脉冲节奏、特殊行为在四个乐章中完全不同。

**具体设计**：

创建 `BossAuraController` 节点（挂在 Boss 下）。

```gdscript
class_name BossAuraController
extends Node

var _aura: ColorRect  # 引用 Boss 场景中的 Aura ColorRect
var _pulse_tween: Tween = null

# 四个乐章的参数
const AURA_CONFIGS := {
    1: {  # 第一乐章：热身
        "color": Color(1.0, 0.5, 0.1),      # 橙色
        "alpha_min": 0.1,
        "alpha_max": 0.35,
        "pulse_period": 0.5,                 # 0.5s 一循环（均匀呼吸）
        "special": "",                        # 重击时手动触发扩张
    },
    2: {  # 第二乐章：球类训练
        "color": Color(1.0, 0.7, 0.1),      # 黄色
        "alpha_min": 0.15,
        "alpha_max": 0.40,
        "pulse_period": 0.35,                # 0.35s 一循环（快节奏）
        "special": "",
    },
    3: {  # 第三乐章：集合
        "color": Color(0.9, 0.85, 0.7),     # 白色/暖白
        "alpha_min": 0.1,
        "alpha_max": 0.45,
        "pulse_period": -1,                  # 随机 0.2-0.5s（不稳定）
        "special": "large_pulse",             # 每 3s 一次大型脉冲
    },
    4: {  # 第四乐章：毕业考试
        "color": Color.TRANSPARENT,          # 无光环
        "alpha_min": 0.0,
        "alpha_max": 0.0,
        "pulse_period": 0.0,
        "special": "",
    },
}
```

**核心方法**：

1. `func set_phase(phase: int) -> void` — 切换到指定乐章的光环配置
   - 颜色渐变用 Tween：`tween_property(_aura, "color", target_color, 0.8)`
   
2. `func start_pulse() -> void` — 启动光环呼吸脉冲
   - 第一/第二乐章：固定周期的 alpha 往返 Tween
   - 第三乐章：每次 pulse 完成后随机生成下一个周期（`randf_range(0.2, 0.5)`）
   
3. `func trigger_large_pulse() -> void` — 第三乐章大型脉冲（吹哨声波）
   - 光环 scale 1.0→1.8→1.0，同时 alpha 0.45→0.8→0.45
   - 持续时间 0.8s

4. `func trigger_heavy_attack_expand() -> void` — 第一乐章重击时的光环扩张
   - scale 1.0→1.3→1.0，0.3s

5. `func shatter() -> void` — 第四乐章转阶段：光环碎裂
   - 光环瞬间变亮 (alpha 0.8)
   - 8 个方向的白色粒子（小 ColorRect）从光环位置飞出
   - 光环淡出：alpha→0, 0.5s
   - 之后进入"无光环"状态

6. `func restore() -> void` — Boss 战结束时如有需要
   - 光环快速淡入 + 恢复正常呼吸

**验收标准**：四个乐章光环颜色正确。脉冲节奏不同。颜色过渡平滑（0.8s Tween）。碎裂粒子正确。第四乐章无光环。

---

### TASK-V04: 阶段转换视觉演出

- **负责人**：杨奇
- **工作量**：1 天
- **依赖**：TASK-V01, TASK-V02, TASK-V03
- **文件**：`BossVisualAnimator.gd` 扩展

**设计目标**：Boss 的每个阶段转换都是一个微型视觉演出——不是一段"过场动画"，而是在战斗中自然发生的视觉变化。

**具体设计**：

**转阶段通用流程**（每个阶段转换重复）：
1. Big Hit Stop (6F = 0.1s) —— 世界暂停
2. Boss 短暂无敌 0.8s（`is_phase_transitioning` 锁）
3. 转阶段演出动画播放
4. 光环颜色过渡完成
5. 新阶段攻击开始

**第一乐章→第二乐章 (HP 75%)**：
```
0.0-0.5s  Boss 后退两步：
          - position 向后 Tween (direction: away from player, 30px)
          - 两步节奏：0.0s 第一步落地 → 0.25s 第二步落地
          - 身体微微后仰 (Body rotation -3°)
0.3-0.8s  光环颜色渐变：
          - Aura.color: 橙 → 黄 (Tween 0.5s)
          - 脉冲周期：0.5s → 0.35s (过渡完成时切换)
0.5s      移速变为 75px/s，新攻击池启用
```

**第二乐章→第三乐章 (HP 50%)**：
```
0.0-0.3s  Boss 仰头：
          - Body rotation -10° (仰头看天——吹哨姿势)
          - Whistle scale 脉冲 1.0→1.2→1.0 (0.2s)
0.2-1.0s  白色声波扩散：
          - 3 个白色环形 ColorRect 从 Boss 位置创建
          - 每个环 scale: 0.3→屏幕宽度/2, alpha: 0.7→0
          - 第 1 环 0.2s 创建, 第 2 环 0.35s 创建, 第 3 环 0.5s 创建
          - 每个环 0.8s 到达边缘
0.3-0.8s  光环颜色渐变：
          - Aura.color: 黄 → 白 (Tween 0.5s)
          - 脉冲模式切换为随机周期
0.5s      首次学生召唤触发 (delay 0.5s)
```

**第三乐章→第四乐章 (HP 25%)**：
```
0.0-0.3s  身体颤抖：
          - Body 快速左右抖动 (position.x ±3px, 0.05s 循环 × 6 次)
          - 颜色闪烁：深红 ↔ 更暗红，3 次 (0.1s×3)
0.3-0.8s  光环碎裂：
          - Aura alpha 瞬间 0.8→0.3s 到 0
          - 8 个白色小方块从光环位置飞出 (8 方向，距离 40-80px)
          - 小方块 alpha 0.7→0，0.5s后 queue_free
0.5-0.8s  Body 变暗：
          - Body.color: Color(0.6,0.08,0.05) → Color(0.4,0.05,0.02) (Tween 0.3s)
          - 暗红近乎黑——"最后的力量"
0.8s      Whistle 方块仍然可见（银色不变）——"口哨还在"
1.0s      移速变为 110px/s，第四乐章攻击池启用
```

**验收标准**：三个阶段转换演出流畅。视觉变化清晰可辨。无敌锁正确（0.8s 内玩家攻击无效）。转换期间无崩溃。

---

### TASK-V05: 击败坍塌动画

- **负责人**：杨奇
- **工作量**：0.75 天
- **依赖**：TASK-V01
- **文件**：`BossVisualAnimator.gd` 扩展

**设计目标**：Boss 不死于爆炸——Boss 死于坍塌。一个重物坠地的 Tween 比一个粒子爆炸更能让人感到"一个存在结束了"。

**具体设计**：

```
t=0.00s (Hit Stop 期间)
  - Body 颜色瞬间变为灰白：Color(0.5, 0.5, 0.5)
  - Body.modulate.a = 0.5
  - 光环停止脉冲（如有）
  - 双臂下垂：ArmL rotation 0→+15°, ArmR rotation 0→+15°

t=0.10s (Hit Stop 结束，坍塌开始)
  并行 Tween (0.9s)：
  - Body.scale.x: 3.0 → 4.0 (横向拉宽——"一个人倒在地上")
  - Body.scale.y: 3.0 → 2.0 (垂直压缩)
  - Body.modulate.a: 0.5 → 0.0
  - ArmL.scale.x: 1.0 → 1.3, ArmL.scale.y: 1.0 → 0.3 (手臂也塌下去)
  - ArmR.scale.x: 1.0 → 1.3, ArmR.scale.y: 1.0 → 0.3
  - Aura.modulate.a → 0.0 (如果还有光环)
  - 使用 Tween.EASE_IN (加速——坠落越来越快)

t=0.40s
  - Whistle 方块开始淡出（比主体慢 0.3s 消失）：
    Whistle.modulate.a 1.0 → 0.0, 0.6s
    Whistle.scale 1.0 → 0.8 (微缩——"哨子不再响了")

t=0.80s
  - 金色粒子从 Boss 倒下位置爆发（程序负责——TASK-P07）
  - 粒子颜色：Color(1.0, 0.85, 0.2)
  - 24 个 + 16 个粒子，上升高度比精英怪高 1.5x

t=1.00s
  - 坍塌动画完成。Boss 全部 modulate.a = 0
  - Boss 节点尚未 queue_free()（留给金色粒子时间绽放）

t=3.00s
  - Boss 节点 queue_free()
```

**坍塌的"重量感"实现要点**：
- 使用 `Tween.EASE_IN` 而非 `EASE_OUT`——下落时加速，不是减速
- 横向拉宽 + 垂直压缩同时发生——像一块巨大的布丁塌到地上
- 口哨延迟消失——这个细节让"哨子不再响了"的叙事变得可见
- 没有爆炸粒子——坍塌是安静的。金色粒子是坍塌后的"光"，不是"爆炸"

**验收标准**：Boss 坍塌动画流畅。横向拉宽+垂直压缩效果正确。口哨比主体慢 0.3s 消失。金色粒子在坍塌后爆发。

---

### TASK-V06: 学生小怪外观

- **负责人**：杨奇
- **工作量**：0.5 天
- **依赖**：无
- **产出**：`scenes/student_minion.tscn` 场景文件

**设计目标**：学生小怪用白色/灰白矩形。更小、更快（0.7x scale）。和普通敌人（灰色/暗色）形成绝对反差——"他们不是红色的敌人"。

**具体设计**：

```
StudentMinion (CombatUnit)
├── Body (ColorRect, z_index=2)
│   - 颜色：Color(0.85, 0.85, 0.8) 灰白
│   - 尺寸：16x24（竖长方形——像一个人形，但比普通敌人更瘦小）
│   - offset: -8, -12 到 8, 12
│
├── HitFlash (ColorRect, z_index=3)
│   - 颜色：Color.WHITE, alpha=0
│   - 尺寸：覆盖 Body
│
├── HealthBar (ProgressBar, z_index=4)
│   - 头顶小血条
│   - custom_minimum_size = (16, 2) —— 比普通敌人更小
│   - 颜色：浅灰前景
│
└── ContactArea (Area2D)
```

**与普通敌人的视觉区别**：

| 特征 | 普通近战敌人 | 学生小怪 |
|------|------------|---------|
| 颜色 | 灰褐 `#8B7355`（迁移前为红） | 灰白 `#D9D9CC` |
| 尺寸 | 18x28 | 16x24 (更瘦小) |
| scale | 1.0x | 0.7x（整体更小） |
| 移速 | 120px/s | 140px/s（更快） |
| 死亡 | 闪白 + 粒子 | 静默消散：modulate.a→0 + scale→0.5，0.3s。无粒子 |

**消散动画**（替代死亡粒子）：
```gdscript
func play_dissipate() -> void:
    var t := create_tween().set_parallel(true)
    t.tween_property(body, "modulate:a", 0.0, 0.3)
    t.tween_property(body, "scale", Vector2(0.5, 0.5), 0.3)
    t.chain().tween_callback(queue_free)
```

**为什么没有粒子**：学生不是"被杀死"——他们是"被解散"。下课了，他们不需要留下任何痕迹。

**验收标准**：学生小怪视觉上与普通敌人明显区分。白色/灰白色调。更小更快。消散动画静默（无粒子）。

---

### TASK-V07: 哨声视觉声波实现

- **负责人**：杨奇
- **工作量**：0.25 天
- **依赖**：无
- **文件**：复用/扩展已有 ColorRect + Tween 模式

**设计目标**：视觉声波不是音频的替代品——它是游戏语言的一部分。白色环形圈从 Boss 位置扩散，玩家的大脑会自动补全哨声。

**具体设计**：

```gdscript
# 创建视觉声波
func create_sonic_wave(color: Color, count: int, spread_angle: float, duration: float) -> void:
    for i in range(count):
        var ring := ColorRect.new()
        ring.color = color
        ring.color.a = 0.7
        ring.size = Vector2(20, 20)  # 初始小圆/方
        ring.position = boss.global_position - Vector2(10, 10)
        ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ring.z_index = 5
        effect_parent.add_child(ring)
        
        # 扩散 + 淡出
        var t := create_tween().set_parallel(true)
        t.tween_property(ring, "scale", Vector2(2.5, 2.5), duration)  # 从小变大
        t.tween_property(ring, "color:a", 0.0, duration)               # 从有到无
        t.chain().tween_callback(ring.queue_free)
```

**三种哨声的视觉差异**：

| 场景 | 颜色 | 数量 | 角度 | 持续时间 |
|------|------|------|------|---------|
| 第一乐章 哨声音波 (M1-B) | 白→橙红渐变 | 3 个 | 90° 扇形 | 0.6s |
| 第二乐章 哨声尖啸 (M2-C) | 白→橙红渐变 | 5 个 | 120° 扇形 | 0.5s |
| 第三乐章 吹哨集合 (M3-A) | 纯白 | 3 个 | 全方向 | 0.8s（扩散至屏幕边缘） |
| 第三乐章 空哨 (M3-E) | 纯白→灰 | 3 个 | 全方向 | 0.8s（扩散到一半停止→回缩→消失） |

**空哨的特殊视觉**（M3-E）：
- 声波环开始正常扩散
- 扩散到约 50% 时停止
- 环开始回缩 (scale 缩小)
- 颜色从白渐变到灰
- 全部消失——"没有学生回应"

**验收标准**：三种哨声的视觉声波正确区分。空哨的回缩-消失效果正确。声波不影响性能（最多 5 个 ColorRect 同时 Tween）。

---

## 工时汇总

| 任务 | 负责人 | 工时（天） |
|------|--------|-----------|
| TASK-V01 Boss 多 ColorRect 拼装 | 杨奇 | 1.0 |
| TASK-V02 Boss 攻击动画/姿态 | 杨奇 | 1.5 |
| TASK-V03 光环系统四乐章 | 杨奇 | 0.5 |
| TASK-V04 阶段转换视觉演出 | 杨奇 | 1.0 |
| TASK-V05 击败坍塌动画 | 杨奇 | 0.75 |
| TASK-V06 学生小怪外观 | 杨奇 | 0.5 |
| TASK-V07 哨声视觉声波 | 杨奇 | 0.25 |
| **总计** | | **~5.5 天** |

---

## 依赖关系

```
TASK-V01 (Boss拼装) ──┬── TASK-V02 (攻击动画) ──┬── TASK-V04 (阶段转换)
                      │                          │
                      ├── TASK-V03 (光环系统) ────┤
                      │                          │
                      └── TASK-V05 (坍塌动画) ────┘

TASK-V06 (学生外观) ── 独立
TASK-V07 (哨声声波) ── 独立
```

---

## ColorRect 色彩参考总表

| 元素 | 颜色值 | 用途 |
|------|--------|------|
| Boss 主体 | `Color(0.6, 0.08, 0.05)` | 深红——默认体色 |
| Boss 主体 (第四乐章) | `Color(0.4, 0.05, 0.02)` | 暗红近乎黑——最后的力量 |
| Boss 主体 (死亡) | `Color(0.5, 0.5, 0.5)` | 灰白——死亡瞬间 |
| 口哨 | `Color(0.6, 0.6, 0.65)` | 银色——标志性锚点 |
| 光环 (第一乐章) | `Color(1.0, 0.5, 0.1)` | 橙色——热身 |
| 光环 (第二乐章) | `Color(1.0, 0.7, 0.1)` | 黄色——球类训练 |
| 光环 (第三乐章) | `Color(0.9, 0.85, 0.7)` | 白色/暖白——集合 |
| 光环 (第四乐章) | `Color.TRANSPARENT` | 透明——无光环 |
| 核心弱点 | `Color(1.0, 0.2, 0.05)` | 高亮红色——暴露弱点 |
| 学生小怪 | `Color(0.85, 0.85, 0.8)` | 灰白——"不是红色的敌人" |
| 哨声声波 | `Color(1.0, 0.9, 0.8)` | 白色——声波起始色 |
| 哨声声波 (M1-B 释放) | `Color(1.0, 0.5, 0.1)` | 橙红——声波结束色 |
| 金色死亡粒子 | `Color(1.0, 0.85, 0.2)` | 金色——"他终于自由了" |
| 胜利文字 | `Color(1.0, 0.15, 0.05)` | 红色警告色——复用 PromptConfig |
| 暗角边缘 | `Color(0.05, 0.02, 0.02)` | 极暗红黑——体育馆的气味 |
| 跳马箱 | `Color(0.5, 0.35, 0.2)` | 木色 |
| 篮球架 | `Color(0.3, 0.3, 0.35)` | 深灰金属 |
| 体操垫 | `Color(0.15, 0.35, 0.15)` | 暗绿 |
