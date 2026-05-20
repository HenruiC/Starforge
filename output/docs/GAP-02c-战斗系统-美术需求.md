# GAP-02c 战斗系统 -- 美术需求

> 宫崎英高, Starforge 战斗设计顾问
> 2026-05-19
> 输入文档: `战斗系统设计-宫崎英高.md` (2.1~2.5)
> 执行方: 杨奇 (美术总监) -- 本文档为美术需求规格，所有视觉方案限定在 ColorRect 体系内
> 约束: 不使用任何手绘/外部图片资源。100% 程序化生成。

---

## 需求 1: 敌人视觉语言体系 (ColorRect 实现)

### 背景
宫崎文档 (2.2~2.3 节) 定义了三条视觉通道分配原则:
1. 敌人类型 → 轮廓/形状 (最快辨识，不受色盲影响)
2. 当前行为 → 颜色变化 + 动作姿态
3. 血量状态 → 粒子效果 + 尺寸变化

当前所有敌人都是正方形 ColorRect，颜色区分类型。需要改造为形状区分。

### 1.1 敌人类型基础形状定义

所有形状使用多个 ColorRect 节点拼装。每个敌人场景有一个根 Control 节点 `VisualBody` 管理所有子 ColorRect。

#### 近战杂兵 -- "追迹者"

```
结构:
  VisualBody (Control)
	├── Body (ColorRect)           # 竖长方形 18x28
	├── Head (ColorRect)           # 小方块 10x10, 在 Body 上方
	└── WeaponArm (ColorRect)      # 窄条 4x14, 在 Body 右侧 (攻击时后摆)

颜色:
  默认: Body/Head/WeaponArm 均为 #8B7355 (灰褐色)
  攻击蓄力: Body 颜色渐变到 #FF8C00 (橙黄)
  受击: 所有部件闪白 0.05s
  死亡: Body 从下往上 alpha 渐变到 0 (0.3s)

动作 (Tween):
  攻击前摇: Body scale.y 从 1.0 压缩到 0.85, WeaponArm 向右旋转 (rotation 0→0.5)
  攻击伤害帧: Body scale.y 快速恢复 0.85→1.0 + WeaponArm 前挥 (rotation 0.5→-0.3)
  受击: Body position 左右震动 (x: 0→3→-3→0, 0.06s)
  死亡: Body scale.y 从 1.0→0.0 (从脚到头的溶解效果: 用第二个 Body color.a 从 0→1 的遮罩, 从下往上 cover)
```

#### 远程射手 -- "投掷者"

```
结构:
  VisualBody (Control)
	├── Body (ColorRect)           # 扁长方形 28x18 (宽>高, 横向)
	├── LeftArm (ColorRect)        # 小方块 6x10, 在左侧
	├── RightArm (ColorRect)       # 小方块 6x10, 在右侧
	└── WeaponPoint (ColorRect)    # 小点 4x4, 在 RightArm 末端

颜色:
  默认: Body #556B2F (暗橄榄绿), 手臂同色
  攻击蓄力: WeaponPoint 从暗绿渐变到亮黄 #FFFF00 (0.4s), 手臂向后偏移
  受击: 同近战
  死亡: 同近战

动作:
  攻击前摇 (0.4s): LeftArm/RightArm position 向后移动 (左右臂同时后摆, 像张开双臂蓄力)
  射击瞬间: RightArm 快速前推 + WeaponPoint 闪光
  射击后硬直 (0.3s): 双臂缓慢收回, Body 不移动
```

关键: 近战和远程的形状完全不同 -- 竖长方形 vs 宽长方形 -- 玩家用余光即可区分。

#### 精英 -- "变异体"

```
结构:
  基于基础类型的形状 +
	├── 2~3 个 IrregularGrowth (ColorRect)   # 不规则突起, 附着在 Body 边缘
	│   - 大小: 5x8 ~ 8x12 随机
	│   - 位置: Body 边缘外侧 2~5px
	│   - 颜色: 比 Body 暗 20% 的同色系
	└── GroundShadow (ColorRect)              # 底部暗影
		- 颜色: 深紫 #3A0D5E, alpha 0.3
		- 大小: 比 Body 宽 20%, 位于脚下

颜色:
  默认: Body 深紫 #4B1A7D (近战精英) 或 #3A5E0D (远程精英)
  特殊: Body alpha 周期性变化 0.8→1.0→0.8, 周期 1.5s (脉搏光泽)
  攻击蓄力: 前摇比普通敌人长 1.5 倍, 颜色渐变到对应蓄力色时更缓慢

大小:
  scale = 1.6x (与现有设定一致)
  移速: 比普通版慢 20% (在 AI 配置中设置)
```

#### Boss -- "体育老师变异体" (详见 GAP-01)

Boss 的完整视觉不在此文档中。这里只说明: Boss 的拼装结构是 5+ 个 ColorRect (主体+四肢+口哨+光环)，实现路径与普通敌人一致，只是节点数量更多。

### 1.2 敌人场景模板结构

为了支持形状区分，`enemy.tscn` 需要改造:

```
Enemy (CharacterBody2D / CombatUnit)
├── VisualBody (Control)
│   ├── Body (ColorRect)
│   ├── [可选] Head (ColorRect)
│   ├── [可选] LeftArm / RightArm (ColorRect)
│   ├── [可选] WeaponArm (ColorRect)
│   ├── [可选] WeaponPoint (ColorRect)
│   ├── [可选] IrregularGrowth1/2/3 (ColorRect)
│   └── [可选] GroundShadow (ColorRect)
├── GlowRect (ColorRect)               # 光环层 (精英/Boss 专属)
├── StatusIndicator (Node2D)           # 头顶状态指示器 (GAP-02b 需求 2)
├── HitFlash (ColorRect)               # 受击闪光层
├── HealthBar (ProgressBar)            # 血量条 (非 Boss)
├── ContactArea (Area2D)
├── AttackArea (Area2D)
├── ShootTimer (Timer)
└── AIBehaviorController (Node)        # 或 AIController
```

### 1.3 颜色语义约束 (必须遵守)

| 颜色 | 用途 | 使用时长 | 是否常态 |
|------|------|---------|---------|
| 红色 #FF2020 | 狂暴 / 极度危险 | 只在狂暴/低血量时 | **否** -- 绝不作为默认色 |
| 橙黄 #FF8C00 | 攻击蓄力 / 前摇 | 0.35~1.5s | 否 -- 只在蓄力期间 |
| 白色 #FFFFFF | 受击反馈 | 0.05~0.1s | 否 -- 瞬间 |
| 蓝色 #4488FF | 冻结 / 麻痹 | 控制期间 | 否 |
| 灰褐 #8B7355 | 近战敌人常态 | 持续 | 是 (近战默认) |
| 暗绿 #556B2F | 远程敌人常态 | 持续 | 是 (远程默认) |
| 深紫 #4B1A7D | 精英常态 | 持续 | 是 (精英默认) |
| 半透明 (alpha<0.5) | 潜伏 | 潜伏期间 | 否 |
| 金色 #FFD700 | Boss死亡粒子 | 死亡序列 2s | 否 |

### 优先级: **P0** (第二阶段 -- AI 行为模式完成后)

---

## 需求 2: 蓄力/狂暴颜色参数

### 2.1 攻击蓄力颜色渐变规范

所有敌人攻击蓄力使用统一的颜色渐变系统。渐变从默认颜色平滑过渡到蓄力颜色:

| 敌人类型 | 默认颜色 | 蓄力颜色 | 渐变公式 |
|---------|---------|---------|---------|
| 近战杂兵 | #8B7355 (灰褐) | #FF8C00 (橙黄) | lerp(normal, charge, t) 其中 t = elapsed / windup_duration |
| 远程射手 | #556B2F (暗绿) | #CCFF00 (亮黄绿) | 同上 |
| 近战精英 | #4B1A7D (深紫) | #FF5500 (橙红) | 同上, 但 t 曲线映射更慢 (t = ease_in(elapsed/windup)) |
| 远程精英 | #3A5E0D (暗绿) | #FFFF00 (纯黄) | 同上 |
| Boss Phase 1 | 暗红 | 橙黄 #FF8C00 | lerp(0.6,0.08,0.05) → (1.0,0.55,0.0) |
| Boss Phase 2 | 金属灰 | 黄色 #FFC800 | lerp(0.5,0.5,0.5) → (1.0,0.78,0.0) |
| Boss Phase 3 | 深红+金裂 | 白色 #FFFFFF | lerp(dark_red, white, t) |
| Boss Phase 4 | 暗红近黑 | 无 (不再蓄力) | -- |

**重要**: 渐变必须是线性的 (不是 ease_in/ease_out)。玩家需要从颜色深浅判断 "还有多久打我" -- 线性映射让这个判断最直观。

### 2.2 狂暴颜色参数

狂暴状态 (Boss Phase 3/4, 精英低血量激怒):

```
颜色: #FF2020 (纯红)
脉冲: alpha 在 0.9 和 1.0 之间摆动, 周期 0.4s
粒子: 身体外溢红色小方粒子 (3x3, 每秒 2~3 个, 随机方向 30~60px)
尺寸: 比正常大 5% (scale * 1.05)
```

**注意**: 这个红色是功能性红 -- "比平时更危险"。和蓄力橙黄 (马上要打) 是不同的信息。

### 2.3 低血量视觉 (非狂暴)

非精英/非 Boss 敌人在低血量 (<20%) 时:

```
颜色: 在默认颜色上略微变暗 (modulate rgb * 0.8)
粒子: 少量红色粒子从身体渗出 (每秒 1 个, 暗示"受伤")
尺寸: 不变 (不额外放大 -- 低血量是弱点，不是威胁)
```

这个视觉与 FLEE 行为模式联动 -- 低血量 + 逃跑 + 颜色变淡 = 玩家立刻知道 "它要跑了，追它"。

### 优先级: **P0** (与攻击前摇系统同步)

---

## 需求 3: AOE 预览样式

### 3.1 样式规范

AOE 预览不创建物理碰撞体 -- 纯 `_draw()` 绘制。

| AOE 形状 | 绘制方式 | 颜色渐变 | 边缘样式 |
|----------|---------|---------|---------|
| 圆形 | `draw_circle()` 填充 + `draw_arc()` 边线 | 从 alpha 0.2→0.7, 中心略亮 | 2px 白色虚线弧 (每段 8px, 间隔 4px) |
| 圆环 | `draw_arc()` 嵌套 (2~3 圈) | 从内到外 alpha 递减 (0.6→0.3) | 最外圈实线 2px |
| 矩形 | `draw_rect()` 填充 | 同圆形 | 2px 白色虚线框 |
| 扇形 | `draw_circle()` 填充扇形 + 两条射线边 | 同圆形, 从圆心向外 alpha 递减 | 两条射线边 2px 白色实线 |

### 3.2 颜色

| AOE 来源 | 填充色 | 边线色 |
|----------|-------|-------|
| Boss 物理攻击 (践踏/震地) | RGBA(1.0, 0.15, 0.05, alpha) | RGBA(1.0, 0.3, 0.15, 1.0) |
| Boss 弹幕/投掷落地 | RGBA(1.0, 0.5, 0.1, alpha) | RGBA(1.0, 0.6, 0.3, 1.0) |
| 精英 AOE | RGBA(0.9, 0.4, 0.0, alpha) | RGBA(0.9, 0.5, 0.2, 1.0) |
| 冰霜 AOE (远程精英) | RGBA(0.2, 0.5, 1.0, alpha) | RGBA(0.3, 0.6, 1.0, 1.0) |
| 全屏体操垫雨 | RGBA(1.0, 0.1, 0.0, alpha) 方形投影 | 2px 红色虚线框 |

### 3.3 动画

- **填充 alpha**: 从 0.2 线性增长到 0.7 (覆盖整个前摇时长)
- **边缘脉冲**: 边线 alpha 以 1.0→0.6→1.0 的周期脉冲 (周期 0.25s)
- **锁定位置后**: 0.05s 的 "snap" 效果 -- 边线短暂变亮 (alpha 1.0, 0.05s) 然后恢复脉冲
- **伤害帧开始时**: AOE 预览瞬间变色 (填充色变深, alpha 0.9, 0.05s) 然后整个节点 queue_free

### 优先级: **P0** (Boss 战必须)

---

## 需求 4: 受击/死亡动画

### 4.1 敌人受击动画 (所有类型通用)

当前已有实现，仅规范参数:

```
闪白: modulate = Color.WHITE, 持续时间 0.05s, 然后渐变回默认
震动: position 偏移 (3→-3→0) x 轴, 总时长 0.06s
粒子: 3 个小方块 (3x3), 随机角度放射, 距离 15~30px, 颜色橙黄 alpha 0.7→0.0, 时长 0.3s
```

### 4.2 敌人死亡动画

#### 普通敌人 (非精英):

```
阶段 1 (0.0~0.1s): 闪白 + 冻结 (不再移动)
阶段 2 (0.1~0.3s): scale 从 1.0→1.3 + modulate.a 从 1.0→0.0 (膨胀 + 消散)
				   同时 4 个击杀粒子放射 (复用 CombatFeedback.hit_particles)
阶段 3: queue_free()
```

#### 精英敌人:

```
阶段 1 (0.0~0.15s): Big Hit Stop 6 帧 + 闪白
阶段 2 (0.15~0.4s): 比普通死亡更夸张的膨胀 (scale 1.6→2.2)
					modulate.a 1.0→0.0
					CombatFeedback.kill_explosion (橙色粒子爆发)
					GroundShadow 脉冲一次 (scale 1.0→1.5→0.0, 0.3s)
阶段 3: queue_free()
```

#### Boss:

Boss 的死亡动画由 GAP-01 (小岛) 定义。此处只说明与非 Boss 的技术差异:
- Boss 不是"膨胀消散" -- 是"坍塌" (scale.x 增大, scale.y 减小)
- Boss 使用**金色**粒子 (不是橙色) -- 复用 CombatFeedback.kill_explosion 但改颜色参数
- Boss 死亡序列包含: Hit Stop → 变灰白 → 坍塌 Tween → 金色粒子 → 胜利文字 (总计 ~2s)

### 4.3 死亡粒子颜色语义

| 敌人类型 | 死亡粒子颜色 | RGB | 数量 | 说明 |
|---------|------------|-----|------|------|
| 普通近战 | 橙黄 | (1.0, 0.5, 0.1) | 4 | -- |
| 普通远程 | 黄绿 | (0.6, 1.0, 0.1) | 4 | -- |
| 精英 | 紫色 + 橙 | (0.7, 0.2, 0.9) + (1.0, 0.5, 0.1) | 8+4 | 精英用 CombatFeedback.kill_explosion |
| Boss | 金色 | (1.0, 0.85, 0.2) | 24+16 | 双倍粒子, 更大上升高度 |
| 学生小怪 (Boss召唤) | 白色 | (0.9, 0.9, 0.9) | 0 | 学生不爆炸 -- 静默消散 (modulate.a → 0, 0.5s, 无粒子) |

### 4.4 溶解/坍塌动画模板代码

为了让 `_die()` 在不同敌人类型上有统一接口:

```gdscript
# CombatUnit.gd (或 enemy.gd)
func play_death_animation(style: String = "default") -> void:
	match style:
		"default":
			_death_dissolve_expand()
		"elite":
			_death_elite()
		"boss_collapse":
			_death_boss_collapse()
		"silent_fade":
			_death_silent_fade()

func _death_dissolve_expand() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual_body, "scale", _visual_body.scale * 1.3, 0.3)
	tw.tween_property(_visual_body, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(queue_free)
	CombatFeedback.hit_particles(global_position, 4, Color(1.0, 0.5, 0.1))

func _death_silent_fade() -> void:
	# 学生小怪 -- 没有粒子, 只是静默消失
	var tw := create_tween()
	tw.tween_property(_visual_body, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
```

### 优先级: **P1** (现有死亡动画已可用, 增强在打磨阶段)

---

## 汇总

| 需求 | 优先级 | 新建/改造节点 | 关键参数 |
|------|--------|-------------|---------|
| 1. 视觉语言体系 | P0 | 4 种敌人形状 (7~11 ColorRect 拼装) | 近战竖18x28, 远程横28x18 |
| 2. 蓄力/狂暴颜色 | P0 | 无 -- 颜色参数 | 线性渐变, 狂暴 alpha 脉冲 0.4s |
| 3. AOE 预览样式 | P0 | `_draw()` 纯绘制 | 圆心到边缘 alpha 递减, 虚线弧 |
| 4. 受击/死亡动画 | P1 | 改造 `_die()` | 学生消散无粒子, Boss 坍塌非膨胀 |

**所有需求 100% ColorRect + Tween 体系**, 不需要任何外部资源文件。

---

*本文档为美术需求规格。所有颜色值、尺寸、Tween 参数均已量化。杨奇可根据实际视觉效果微调，但形状方案 (竖 vs 横) 和颜色语义 (默认非红色) 是宫崎确认的设计约束，不可变更。*
