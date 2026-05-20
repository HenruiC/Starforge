# GAP-02b 战斗系统 -- 交互需求

> 宫崎英高, Starforge 战斗设计顾问
> 2026-05-19
> 输入文档: `战斗系统设计-宫崎英高.md` (2.2~2.5, 5.1, 5.4)
> 协作方: 交互策划 (沈逸) -- 本文档为交互需求规格，由沈逸负责具体 UI 实现方案
> 前置: GAP-02a (程序需求) 中涉及的信号和状态字段

---

## 需求 1: AOE 范围预览 UI

### 背景
宫崎文档 (5.1 节) 强制要求: "Boss AOE 必须显示范围预览"。当前系统没有任何地面范围提示 -- 玩家只能靠经验或死亡来学习 AOE 边界。这不符合 "Tough but Fair" 原则。

### 1.1 需要范围预览的 AOE 类型

| AOE 来源 | 攻击类型 | AOE 形状 | 预警时长 | 预览颜色 | 触发时机 |
|----------|---------|---------|---------|---------|---------|
| Boss Phase 1 | 跳马践踏 (C) | 圆形 (60px 半径) | 1.0s | 淡红→深红渐变 | 前摇开始时显示 |
| Boss Phase 2 | 震地波 (C') | 同心圆环 (50/100/180px) | 1.2s | 红色圆环，逐波扩散 | 前摇开始时显示第一波 |
| Boss Phase 2 | 铁山靠 (B') | 矩形 (方向锁定后) | 0.6s | 红色矩形条 | 方向锁定后显示 |
| Boss Phase 3 | 全屏体操垫雨 (E) | 圆形 (40px 半径 x N 个) | 1.5s 总 / 0.5s 每波 | 红色方形投影 | 每波释放前 0.5s |
| 精英敌人 | AOE 冲击波 | 圆形 (80px) | 0.8s | 橙色圆形，alpha 0.3→0.7 | 攻击前摇开始 |
| 远程精英 | 冰霜新星 | 圆形 (120px) | 0.6s | 蓝色圆形，alpha 0.2→0.6 | 前摇开始 |

### 1.2 实现方案

#### 1.2.1 AOE 预览组件: `AOEWarningIndicator`

**文件**: `scripts/combat/aoe_warning_indicator.gd` (新建)

这是一个挂载在攻击来源 (Boss/敌人) 下的临时视觉节点:

```gdscript
class_name AOEWarningIndicator
extends Node2D

## AOE 范围预警指示器

const DEFAULT_WARNING_DURATION := 0.8
const WARNING_START_ALPHA := 0.2
const WARNING_END_ALPHA := 0.7
const WARNING_START_COLOR := Color(1.0, 0.2, 0.1)   # 淡红
const WARNING_END_COLOR := Color(1.0, 0.0, 0.0)      # 深红
const PULSE_PERIOD := 0.3

var _shape_type: String = "circle"   # "circle" / "ring" / "rect" / "pie"
var _radius: float = 60.0
var _rect_size: Vector2 = Vector2.ZERO
var _cone_angle: float = 90.0        # 扇形角度 (degrees)
var _cone_direction: Vector2 = Vector2.RIGHT
var _duration: float = 1.0
var _color: Color = WARNING_START_COLOR
var _follows_source: bool = true     # 是否跟随攻击者移动
var _lock_after_ratio: float = 0.5   # 前摇进行到此比例时位置锁定
var _elapsed: float = 0.0
var _locked_position: Vector2 = Vector2.ZERO
```

#### 1.2.2 视觉效果

AOE 预览使用 `draw_xxx` 方法直接在 `_draw()` 中绘制 (不需要额外 ColorRect 节点):

```gdscript
func _draw() -> void:
	match _shape_type:
		"circle":
			_draw_circle_aoe()
		"ring":
			_draw_ring_aoe()
		"rect":
			_draw_rect_aoe()
		"pie":
			_draw_pie_aoe()

func _draw_circle_aoe() -> void:
	var alpha := lerpf(WARNING_START_ALPHA, WARNING_END_ALPHA, _elapsed / _duration)
	# 脉冲效果
	alpha *= 0.8 + 0.2 * sin(_elapsed * TAU / PULSE_PERIOD)
	var col := _color
	col.a = alpha
	# 填充
	draw_circle(Vector2.ZERO, _radius, col)
	# 外边缘线 (更亮)
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 32, Color(col.r, col.g, col.b, alpha * 1.3), 2.0)
```

#### 1.2.3 使用方式

在 Boss/敌人的攻击技能中:

```gdscript
# 以 Boss 跳马践踏为例
func _on_windup_start(duration: float) -> void:
	var indicator := AOEWarningIndicator.new()
	indicator.shape_type = "circle"
	indicator.radius = 60.0
	indicator.duration = duration
	indicator.color = Color(1.0, 0.2, 0.1)  # 淡红
	indicator.follows_source = false  # 跳马践踏: 前 0.5s 跟随, 后 0.5s 锁定
	indicator.lock_after_ratio = 0.5
	# 添加到场景根节点 (世界坐标)
	get_tree().current_scene.add_child(indicator)
	indicator.global_position = self.global_position
```

#### 1.2.4 性能考虑

- AOE 预览是纯 `_draw()` 调用，不创建 Area2D / CollisionShape2D -- 零碰撞检测开销
- 每帧 `queue_redraw()` 仅在有活跃 AOE 预览时触发
- 同一帧内预计最多 5 个同时存在的 AOE 预览 (Boss 全屏垫雨期间)

### 1.3 UI 层面的 AOE 信息补充

在 HUD 中，如果玩家处于 AOE 范围内，可以考虑:
- 屏幕边缘出现轻微红色暗角脉冲 (比低血量暗角更淡, alpha 0.15, 周期 0.5s)
- 这个需求改造成本低 -- 复用已有的 LowHP overlay 技术 (GradientTexture2D)，调参即可

### 优先级: **P0** (Boss 战的前置依赖 -- 没有 AOE 预览 = Boss 不可玩)

---

## 需求 2: 敌人状态 UI (蓄力/狂暴可视化)

### 背景
宫崎文档 (2.3 节) 要求敌人当前行为必须可视化: "它现在在做什么？(待机/巡逻/攻击前摇/攻击/硬直)"。当前系统只有 hp_bar 提供血量信息，行为状态完全不可见。

### 2.1 设计方案: 敌人头顶状态指示器

不要求为每个敌人做独立的 UI 面板。用**最简单的头顶图标系统**:

#### 2.1.1 状态指示器类型

| 敌人状态 | 头顶显示 | 颜色/样式 | 出现条件 |
|---------|---------|----------|---------|
| 攻击蓄力中 (WINDUP) | 旋转的感叹号 `!` | 橙黄 #FF8C00, scale 脉冲 (1.0↔1.2, 0.3s) | 前摇阶段始终显示 |
| 狂暴 (BERSERK) | 火焰/尖刺形状 `*` | 红色 #FF2020, scale 快速脉冲 (1.0↔1.3, 0.2s) | 低血量狂暴 / Boss Phase 3 |
| 硬直中 (RECOVERY) | 省略号 `...` | 灰色 #999999, 静止 | 硬直阶段 (可选 -- 对 Boss 必须显示) |
| 冻结 (STUNNED) | 雪花/冰块形状 `*` | 蓝色 #4488FF | 被控制期间 |
| 潜伏 (STEALTH) | 无标识 | -- | 不显示任何额外标识 (潜伏的意义就是不被发现) |

#### 2.1.2 实现方案

**文件**: `scripts/ui/enemy_status_indicator.gd` (新建)

```gdscript
class_name EnemyStatusIndicator
extends Node2D

## 挂在 Enemy 下，显示在头顶上方

var _label: Label
const OFFSET_ABOVE_HEAD := Vector2(0, -40)  # 头顶上方 40px

func _ready() -> void:
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	position = OFFSET_ABOVE_HEAD

func show_state(state: String, color: Color, pulse: bool = false) -> void:
	_label.text = state
	_label.add_theme_color_override("font_color", color)
	_label.visible = true
	if pulse:
		var tw := create_tween().set_loops(0)
		tw.tween_property(_label, "scale", Vector2(1.2, 1.2), 0.3)
		tw.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.3)

func hide_state() -> void:
	_label.visible = false
```

#### 2.1.3 与视觉状态机的联动

`EnemyVisualState` (GAP-02a 需求 2) 的状态变化驱动此指示器:

```gdscript
# EnemyVisualState 连接:
func _on_state_changed(new_state: int) -> void:
	match new_state:
		VisualState.WINDUP:
			_status_indicator.show_state("!", Color(1.0, 0.55, 0.0), true)
		VisualState.BERSERK:
			_status_indicator.show_state("*", Color(1.0, 0.13, 0.13), true)
		VisualState.RECOVERY:
			if _unit.is_boss:
				_status_indicator.show_state("...", Color(0.6, 0.6, 0.6), false)
		VisualState.STUNNED:
			_status_indicator.show_state("*", Color(0.27, 0.53, 1.0), true)
		_:
			_status_indicator.hide_state()
```

### 2.2 Boss 专属 UI 增强

Boss 的当前状态不仅通过头顶指示器，还需要通过**屏幕顶部血条**传递:

- 血条颜色根据 Boss 当前行为变化:
  - 正在攻击前摇: 血条边缘闪烁橙黄色
  - 硬直中: 血条中央出现弱点标记 (高亮闪烁块)
  - 狂暴: 血条整体变为暗红色 + 裂纹粒子

详见需求 3 (Boss 血条设计)。

### 优先级: **P1** (有视觉状态机即可实现 -- P1 是因为敌人头顶指示器的信息量有限，主要依赖身体颜色变化)

---

## 需求 3: Boss 血条设计

### 背景
宫崎文档 (2.4 节) 要求 "Boss 血条在 HUD 顶部单独显示 (不是挂在怪物头上)"。小岛文档要求血条上有阶段标记线。当前实现: Boss HP 条和普通敌人一样挂在头顶。

### 3.1 位置与尺寸

|| 参数 |
|----------|------|
| 位置 | 屏幕顶部中央，y=screen_top + 16px |
| 宽度 | 屏幕宽度的 60% (约 576px 在 960x540 分辨率) |
| 高度 | 8px (比普通敌人 hp_bar 的 5px 更粗) |
| 背景 | 黑色底色条 (alpha 0.5)，同宽度 10px 高 |
| 名称 | 血条上方居中: "体育老师 · 佐藤" (12pt, 颜色跟随阶段) |
| Z-index | 100 (最顶层，不被任何游戏物体遮挡) |

### 3.2 阶段标记线

三条竖线标记 Phase 转换点 (HP 75% / 50% / 25%):

```
[████████████████████|████████████████|████████████████|████████████████]
 75% 标记线           50% 标记线         25% 标记线
```

- 标记线: 白色 2px 宽竖线，alpha 0.6
- 当 HP 穿过某条线 (阶段转换完成): 该线短暂闪烁 (白色→金色→消失，0.5s)，然后移除 (因为下一个阶段不需要回顾已过的标记)

### 3.3 血量减少动画

不瞬间跳到新值。使用 Tween 平滑过渡:

```gdscript
func update_boss_hp(current: int, max_hp: int) -> void:
	var target_ratio := float(current) / float(max_hp)
	# 0.3s 平滑减少 (杨奇建议: "他正在流血")
	var tw := create_tween()
	tw.tween_property(hp_fill, "size_flags_stretch_ratio", target_ratio, 0.3)
	# 如果一次受伤超过 15% 上限:
	# 先闪白 (0.05s) 再减少 -- 强调"这一下真的很重"
	var damage_ratio := _previous_ratio - target_ratio
	if damage_ratio > 0.15:
		# 先做白色闪
		var tw_flash := create_tween()
		tw_flash.tween_property(hp_fill, "modulate", Color.WHITE, 0.05)
		tw_flash.tween_property(hp_fill, "modulate", _phase_color, 0.1)
```

### 3.4 阶段颜色

血条填充色跟随当前阶段:

| 阶段 | 血条颜色 | RGB |
|------|---------|-----|
| Phase 1 (100%-75%) | 橙色 | #FF8C00 |
| Phase 2 (75%-50%) | 黄色 | #FFC800 |
| Phase 3 (50%-25%) | 白色 | #E8E0D0 |
| Phase 4 (25%-0%) | 无血条 (光环碎裂后血条也碎裂) | -- |

Phase 4 的"血条碎裂"效果: 不是 fade out，是血条沿裂纹线碎成 4 片 + 分别向屏幕四角飞出 (Tween position + rotation)。耗时 0.5s。

### 3.5 与沉默时刻的关系

沉默时刻 (GAP-01 小岛) 中 Boss 血条**不消失**。它是唯一保留的 HUD 元素 -- 因为 "看到 Boss 血条但看不到自己的状态" 加剧了不对等感和紧张感。

### 3.6 实现文件

**文件**: `scripts/ui/boss_hp_bar.gd` (新建)

挂载在 HUD CanvasLayer 下。由 `GameManager` 在 Boss 激活时实例化，在 Boss 死亡终结序列完成后销毁。

### 优先级: **P0** (Boss 战不可分割的一部分)

---

## 需求 4: "我的回合" 节奏感知

### 背景
宫崎文档的核心理念: "战斗是回合制的舞蹈 -- 观察→决策→执行→观察"。当前战斗体验中玩家没有 "回合" 的感觉 -- 自动攻击一直在进行，玩家只需要走位。"我的回合" 意味着: 敌人攻击完的硬直窗口 = 我的输出窗口。这种节奏需要被 UI 强化传达。

### 4.1 设计: 技能图标响应 Boss 硬直

#### 4.1.1 Boss 硬直时技能图标增强

当 Boss 进入硬直状态 (RECOVERY) 时:
- 玩家技能槽图标**边框发光** (金色 or 橙黄色，0.3s 淡入)
- 技能名称下方短暂出现 "输出窗口!" 提示 (仅第一次，之后玩家自然会学会)
- Boss 血条中央弱点标记闪烁 (与硬直同步)

这个设计让玩家看到 "Boss 跪了 → 我的技能图标亮了 = 现在打它"。

#### 4.1.2 实现方式

在 SkillComponent (或现有的 SkillManager) 中:

```gdscript
# 监听 Boss 的 recovery_started/recovery_ended
func _on_boss_recovery_started(duration: float) -> void:
	for skill_ui in _skill_ui_nodes:
		skill_ui.set_damage_window_active(true, duration)

func _on_boss_recovery_ended() -> void:
	for skill_ui in _skill_ui_nodes:
		skill_ui.set_damage_window_active(false, 0)
```

Skill UI 节点的 `set_damage_window_active`:

```gdscript
func set_damage_window_active(active: bool, duration: float) -> void:
	if active:
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color(1.0, 0.85, 0.2, 1.0), 0.15)  # 金色边框
		# 倒计时圈 (可选，视觉化硬直剩余时间)
		_show_countdown_ring(duration)
	else:
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color.WHITE, 0.1)
```

### 4.2 攻击节奏的音频视觉化

用**每次攻击的 hit_stop (顿帧)** 作为节奏标点:

- 玩家攻击命中 Boss: 0.05s hit_stop (轻微)
- Boss 攻击命中玩家: 0.15s hit_stop (明显)
- Boss 进入硬直: 0.1s hit_stop (告诉玩家 "节奏变了")

这些顿帧已经由 `CombatFeedback` 支持。只需要配置不同的参数即可。

### 4.3 "战斗日志" 被否定

不要做战斗日志 (MMO 风格的文字滚动)。宫崎游戏的信息传达靠视觉和节奏，不靠阅读文字。玩家应该"感觉到"节奏变化，不是"读到"。

### 优先级: **P2** (锦上添花。技能图标边框发光可以在 Boss 战打磨阶段添加)

---

## 需求 5: 受击反馈增强

### 背景
当前受击反馈: 闪白 0.06s + 震动 + 3 个粒子。对普通敌人足够。对 Boss 战不够 -- 玩家需要更清晰地知道自己被什么打了、打得多重。

### 5.1 玩家受击反馈增强

| 当前 | 增强后 | 触发条件 |
|------|-------|---------|
| 闪白 0.06s | 保留不变 | 所有受击 |
| 位置震动 | 保留不变 | 所有受击 |
| 3 个小方粒子 | 保留不变 | 普通敌人攻击 |
| 无方向指示 | **新增: 受击方向指示** -- 屏幕边缘出现红色半圆弧，指向伤害来源方向，0.3s fade out | Boss 攻击 / 精英攻击 |
| 无音效 (当前无音频) | 用视觉替代: 屏幕短暂暗角脉冲 (alpha 0→0.3→0, 0.15s) | 单次伤害 >= 20 |
| HP 条直接扣减 | 保留不变 (但已经有 hit_stop + shake) | -- |

### 5.2 受击方向指示器

**文件**: `scripts/ui/hit_direction_indicator.gd` (新建)

```gdscript
class_name HitDirectionIndicator
extends Node2D

## 挂在玩家 HUD 层。当玩家受到伤害时，在屏幕边缘显示伤害来源方向

const INDICATOR_ALPHA := 0.7
const INDICATOR_FADE_TIME := 0.35
const EDGE_OFFSET := 40  # 距屏幕边缘的距离

func show_hit(from_position: Vector2, player_position: Vector2, damage: int) -> void:
	var dir := player_position.direction_to(from_position)
	# 计算屏幕边缘位置
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2.0
	var edge_pos := _project_to_edge(dir, center, viewport_size)

	# 创建弧形指示器
	var arc := ColorRect.new()
	arc.color = Color(1.0, 0.2, 0.1, INDICATOR_ALPHA)
	arc.size = Vector2(15, 15)
	arc.position = edge_pos
	# 根据伤害大小决定 scale
	arc.scale = Vector2.ONE * lerpf(0.8, 1.5, clampf(float(damage) / 40.0, 0.0, 1.0))
	add_child(arc)

	var tw := create_tween()
	tw.tween_property(arc, "modulate:a", 0.0, INDICATOR_FADE_TIME)
	tw.tween_callback(arc.queue_free)
```

### 5.3 敌人受击反馈 -- 当前足够

当前敌人的受击反馈 (闪白 + 震动 + 粒子) 对杂兵和精英已经足够。Boss 的受击反馈会通过以下方式增强:
- 杨奇设计的 Boss 多 ColorRect 肢体抖动 (受击时手臂方块偏移)
- Boss HP 条的平滑减少 (见需求 3)
- 阶段转换时的特殊受击效果 (GAP-01 小岛: "体色一瞬间变为全白 0.05s")

### 5.4 受击时短暂 i-frame 的视觉表示

宫崎文档 (最终实施计划 2.2 节): Boss 攻击后给玩家 0.3s 无敌帧。这段时间内:
- 玩家 sprite 半透明闪烁 (alpha 0.5↔1.0，周期 0.1s) -- 复用已有的受击闪白逻辑
- 不再额外触发新的受击反馈

### 优先级:
- 受击方向指示: **P2** (打磨阶段)
- 高风险伤害暗角脉冲: **P2**
- i-frame 视觉: **P1** (与 i-frame 机制同步)

---

## 汇总

| 需求 | P0/P1/P2 | 新建文件 | 依赖 |
|------|---------|---------|------|
| 1. AOE 范围预览 | P0 | `scripts/combat/aoe_warning_indicator.gd` | Boss 攻击技能需要调用 |
| 2. 敌人状态 UI | P1 | `scripts/ui/enemy_status_indicator.gd` | GAP-02a 视觉状态机 |
| 3. Boss 血条 | P0 | `scripts/ui/boss_hp_bar.gd` | GAP-01 Boss 合并设计 |
| 4. 回合节奏感知 | P2 | 无 -- 修改现有 Skill UI | Boss 硬直信号 |
| 5. 受击反馈增强 | P1/P2 | `scripts/ui/hit_direction_indicator.gd` | i-frame 系统 |

**新增文件: 4 个**

---

*本文档为交互需求规格。所有动效参数 (Tween 时间/easing 函数/stagger 时序) 遵循 `UIEeffects` 规范和 Tween 生命周期规范 v1.0。具体 UI 布局和字体大小由交互策划决定。*
