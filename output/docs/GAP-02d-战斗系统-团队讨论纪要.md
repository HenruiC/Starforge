# GAP-02d 战斗系统 -- 团队讨论纪要

> 宫崎英高 主持, Starforge 战斗设计评审
> 2026-05-19 | 时长: 2h 30min
> 讨论素材: `GAP-02a/b/c-战斗系统-程序/交互/美术需求.md` (草案)
> 目标: 评审三份需求文档，收集各角色反馈，识别遗漏和矛盾

---

## 会议记录

### 与会人员

| 角色 | 姓名 | 关注领域 |
|------|------|---------|
| 战斗设计 (主持) | 宫崎英高 | 攻击可读性、战斗节奏、Boss 机制 |
| 战斗程序 | 卡马克 (John Carmack) | AI 状态机、技能前摇实现 |
| 系统程序 | 系统策划 (原始设计者) | CombatUnit 框架、StatsComponent |
| 交互策划 | 沈逸 | 攻击预警 UI、HUD 节奏 |
| 主程/工程可行性 | 马斯克 (Elon Musk) | 减法、性能、NavAgent |
| 制作人/叙事 | 小岛秀夫 (Hideo Kojima) | 叙事节奏、玩家情感 |

---

## 议题 1: 攻击前摇系统 (GAP-02a 需求 1)

### 战斗程序 -- 卡马克

**"await 协程方案有隐藏陷阱。"**

我仔细看了 `try_execute()` 的改造方案。用 `await get_tree().create_timer(windup_duration).timeout` 来做前摇，逻辑上没问题，但有两个坑:

**坑 1: 技能在 await 期间被取消。** 如果前摇期间敌人被冻结 (STUNNED)，`try_execute()` 还在 await 状态 -- 前摇结束后它会继续走 `execute()`，产生"冻住了但还挥刀"的 bug。

**解决方案:** 在 `await` 返回后立即检查 `can_execute()` 和 `owner_unit.is_dead`:

```gdscript
await get_tree().create_timer(_windup_duration).timeout
if not can_execute() or owner_unit.is_dead:
	_is_windup = false
	_is_recovery = true
	recovery_started.emit(_recovery_duration)  # 进入硬直（虽然没有攻击）
	await get_tree().create_timer(_recovery_duration).timeout
	_is_recovery = false
	recovery_ended.emit()
	return true  # 技能视为"被中断"（已消耗冷却）
```

**坑 2: SkillComponent.process_all() 已经被调用但技能在 await 中。** `process_all()` 在每帧调用 `try_execute()`。如果一个技能在 await 中 (前摇期间)，`is_ready = false` 已经设置了，所以不会重复触发 -- 这个是安全的。但需要确认 `_is_windup` 的检查也在 `try_execute()` 入口处。

**追加改动:** 在 `SkillBase.try_execute()` 入口处增加:
```gdscript
if _is_windup or _is_recovery:
	return false
```

**结论:** 方案可行。补充中断处理逻辑 + 双重检查。

### 系统程序

**"前摇参数应该放在哪里？技能自身还是 AI 配置？"**

宫崎文档中，前摇参数出现在两个地方:
1. `SkillBase._windup_duration` (技能自身)
2. `BossAttackData.windup_duration` (Boss 攻击配置)

如果同一个技能既给玩家用 (0s 前摇) 又给敌人用 (0.4s 前摇)，冲突了。

**建议:** 前摇参数**默认由技能自身定义** (每个技能有自己的 `windup_duration` 默认值)。`BossAttackData` 可以 **override** -- 当技能被 Boss 使用时，覆盖默认前摇。实现方式:

```gdscript
# SkillBase
var _windup_override: float = -1.0  # -1 = 使用默认值

func get_effective_windup() -> float:
	return _windup_duration if _windup_override < 0 else _windup_override

# AIBehaviorController 在攻击前设置:
skill._windup_override = boss_attack_data.windup_duration
```

**双方同意。**

---

## 议题 2: 敌人视觉状态机 (GAP-02a 需求 2)

### 战斗程序 -- 卡马克

**"状态栈模型是正确的。但执行顺序有一个问题。"**

`pop_state()` 调用 `_apply_state()` 会 kill 当前 Tween 再创建新的。如果在 `_physics_process` 的同一帧中 push_state + pop_state (比如: 受击 → 闪白 → 0.05s 后自动 pop → 回到 NORMAL)，Tween kill/recreate 的开销可以忽略，但可能有视觉抖动。

**建议:** 加一个 `_dirty` 标记。同一帧内多次状态变更只执行最后一次 `_apply_state()`:

```gdscript
var _dirty: bool = false

func push_state(state, duration = -1.0):
	_state_stack.append(state)
	_mark_dirty()

func pop_state(expected):
	var idx = _state_stack.rfind(expected)
	if idx >= 0: _state_stack.remove_at(idx)
	_mark_dirty()

func _mark_dirty():
	if not _dirty:
		_dirty = true
		call_deferred("_flush_state")

func _flush_state():
	_dirty = false
	_apply_state(_state_stack.back() if _state_stack.size() > 0 else NORMAL)
```

**采纳。** 宫崎: "这个优化不影响设计意图，实现层面的事情由程序决定。"

### 小岛秀夫

**"视觉状态机应该在沉默时刻期间被覆盖吗？"**

在 Boss 出场前的 3 秒沉默时刻，HUD 消失但游戏仍在运行。此时敌人仍然可能生成 (宫崎要求的 "30 秒接近时间中有普通敌人")。这些普通敌人的视觉状态应该正常显示还是也被压抑？

**宫崎回答:** 普通敌人正常显示。沉默时刻影响的是 HUD 层 (UI Control 节点) -- 敌人的视觉状态是游戏世界层的 (Node2D)。两者不冲突。暗角效果 (Vignette) 覆盖在 HUD 和游戏世界之间，不影响敌人本体的颜色显示。

**小岛:** "可以。但有一个例外 -- 在 Boss 光环第一次亮起 (三次快闪) 的那 0.45s，所有普通敌人的视觉是否能短暂变暗？让这个瞬间的视觉焦点完全在 Boss 身上。"

**宫崎:** "可以接受。用 EnemyVisualState 加一个临时的 DIMMED 状态，Boss 激活时给所有现存敌人 push，0.5s 后 pop。"

---

## 议题 3: AI 组件化 (GAP-02a 需求 3)

### 马斯克

**"我说三点。"**

**1. enum + switch 是正确的 MVP 方案。** 我之前在最终实施计划里说过这个问题。8 个行为类文件的架构在理想情况下更优雅，但 MVP 用它成本太高。switch case 在 Godot GDScript 中的性能足够 (8 个分支的 switch 约 0.0001ms)。唯一要求: 每个 `_tick_xxx` 函数必须在自己的代码块中，逻辑不要交叉引用。将来重构为类继承时，每个函数可以独立抽离。

**2. NavigationAgent2D 的回退策略需要写死在 AI 里。** `NavManager` 当前已经烘焙了导航网格，但这只在 `school_map.gd` 构建的场景中生效。如果将来有其他地图没有导航网格 (或烘焙失败)，AI 不能崩溃。AIController 初始化时需要:
```gdscript
func _setup_navigation():
	var nav_map = NavigationServer2D.map_get_first()
	if nav_map.is_valid():
		_nav_agent = NavigationAgent2D.new()
		add_child(_nav_agent)
	else:
		# 回退到直线移动
		_nav_agent = null
```
然后在移动逻辑中 `if _nav_agent: ... else: _fallback_chase()`。

**3. AIBehaviorConfig 的 `guard_position` 和 `patrol_path` 用全局坐标还是相对坐标？** 必须明确。我建议用**全局坐标** -- 因为关卡编辑时关卡建筑师 (罗梅罗) 在 Godot 编辑器中就能看到位置。如果用相对坐标，增加一个"出生点 + 偏移"的计算层，出 bug 时难调试。

**全员同意用全局坐标。**

### 战斗程序 -- 卡马克

**"AI 决策间隔可以差异化。"**

`decision_interval = 0.1` 对所有敌人是浪费的。离玩家远的敌人不需要 0.1s 决策:

```gdscript
func _get_decision_interval() -> float:
	var dist = _unit.global_position.distance_to(_player_pos)
	if dist < 200: return 0.05   # 近距: 高频决策 (近战格斗需要快速反应)
	if dist < 600: return 0.1    # 中距: 默认
	return 0.3                    # 远距: 低频 (只是走过来)
```

**采纳。** 宫崎: "这个细节不影响设计，只影响性能。马斯克你评估。"

**马斯克:** "50 个敌人 x 3 种决策频率，平均每帧约 8 次决策。完全可以。"

---

## 议题 4: 群组协调 (GAP-02a 需求 4)

### 战斗程序 -- 卡马克

**"AttackCoordinator 单例有一个问题: 它是全局顺序的。如果两个敌人在同一帧请求攻击，且 slot 只剩 1 个，谁拿到？"**

当前方案中 `register_attack()` 是 FIFO (先请求先得)。但两个敌人在同一帧到达 -- 谁的 `_physics_process` 先执行？这是 Godot 的 SceneTree 遍历顺序决定的，不可预测。

**解决方案:** 引入优先级规则:
1. 距离更近的敌人优先 (距离玩家 < 30px > 30~45px)
2. 精英优先于普通敌人
3. 同优先级同距离: 按 `_attack_phase` 随机偏移排序 (防止同一敌人一直插队)

```gdscript
func _get_attack_priority(unit: CombatUnit) -> float:
	var dist = unit.global_position.distance_to(_player_pos)
	var dist_score = 1.0 / maxf(dist, 1.0)
	var elite_bonus = 1.5 if unit.is_elite else 1.0
	return dist_score * elite_bonus + unit._attack_phase * 0.1
```

**采纳。**

### 小岛秀夫

**"排队等待的敌人不能站着不动。它们必须看起来像在'等待时机'。"**

宫崎文档中说"停在 60px 外等待" -- 但视觉上如果 3 个敌人整齐地站在 60px 外一动不动，这不像等待，像 bug。

**建议:** 排队中的敌人做小幅随机移动 (在等候点 ±20px 范围内)。不是巡逻，是"按捺不住的晃动"。视觉上传递"它在等，但不是静止的"。

**宫崎:** "完全同意。这是'视觉叙事'的一部分 -- 三个敌人在 60px 外围着你，小幅晃动，这比三个站桩的敌人更有压迫感。"

**交互策划 (沈逸):** "可以在排队敌人头顶显示一个小的'...' 省略号，暗示'正在等待'。但只在 Boss 战/精英战时显示，避免视觉噪音。"

**全员同意。** 宫崎: "省略号方案与 GAP-02b 需求 2 的敌人状态指示器合并。"

---

## 议题 5: Boss 攻击可读性 (GAP-02a 需求 5 / GAP-02b 需求 1)

### 交互策划 -- 沈逸

**"AOE 预览的虚线弧方案很好，但有一个交互问题。"**

AOE 预览是通过 `_draw()` 在世界空间中绘制的。如果 AOE 非常大 (全屏体操垫雨, 5 波 x 5 个 = 最多 25 个)，玩家的视野可能看不到所有投影 -- 尤其是屏幕边缘的。

**建议:** 对超出屏幕范围的 AOE 投影，在屏幕边缘显示**迷你箭头**指示 "那边还有危险区"。4 个方向 (上下左右)，只在对应方向有超出屏幕的 AOE 时显示。颜色与 AOE 预览一致。

**宫崎:** "这个思路是对的。但全屏体操垫雨 (25 个) 的设计本身就假设玩家可以看到全部投影 -- 体操垫的投影是 40px 半径，不是 200px。25 个 40px 的圈分布在体育馆 200x150 的范围内，玩家在屏幕中央可以看到大约 80% 的投影。屏幕外的用暗角脉冲提示就够了 (GAP-02b 需求 1.3)。不需要额外箭头。"

**沈逸:** "OK。但如果未来有大范围 AOE (比如全屏幕 Boss 技能)，需要留这个扩展口。"

**宫崎:** "同意。预留 `ScreenEdgeIndicator` 组件的接口，但不实现。"

### 小岛秀夫

**"BossAttackData 缺少一个关键字段: 攻击的'叙事意义'。"**

Boss 的每个攻击不只是机械参数 -- 它在讲述故事。哨声攻击表示"集合"/"命令"，前滚翻表示"体操训练"，跳马践踏表示"体能测试"。

**建议:** 在 `BossAttackData` 中加一个 `narrative_hint: String` 字段，用于:
- 调试时理解设计意图
- 未来可能的"敌人图鉴"系统
- 团队内部沟通: 不说"那个 windup 0.6s 的斜向直线突进"，说"铁山靠"

样例:
```gdscript
@export var narrative_hint: String = ""
# 示例: "哨声集合 — 他还在吹集合哨，但没人来了"
```

**全员同意。** 宫崎: "这个字段不影响运行时逻辑，纯文档用途。成本为零。加上。"

---

## 议题 6: "我的回合" 节奏感知 (GAP-02b 需求 4)

### 交互策划 -- 沈逸

**"技能图标边框发光 + Boss 血条弱点标记，双重反馈是好的。但需要一个'第一次教学'。"**

玩家第一次打 Boss 时不会知道 "Boss 硬直 = 我的输出窗口"。需要有一个**一次性**的轻量教学:

- 玩家第一次看到 Boss 硬直 (RECOVERY 状态): 屏幕中央出现一行半透明文字 "就是现在！攻击！"，1.5s fade out，不冻结，不阻塞操作
- 后续再出现 Boss 硬直: 不再显示文字，只靠技能图标+血条标记

**宫崎:** "同意。但文字要改一下。不要'就是现在！攻击！'。用更含蓄的: '它的防御松动了...' 或 '露出破绽了'。给玩家一种自己在观察和分析的感觉，而不是被指挥。"

**沈逸:** "可以。文字触发条件是 `boss_encounter_count == 0 AND first_recovery_witnessed`。这个变量在 GameState 中持久化。"

### 小岛秀夫

**"Boss 硬直窗口的文字提示有叙事空间。"**

不同阶段的 Boss 硬直可以用不同文字:
- Phase 1 硬直: "动作变慢了..."
- Phase 2 硬直: "金属外壳出现裂纹"
- Phase 3 硬直: "核心暴露了！"
- Phase 4 硬直: "他累了..."

这四句构成了一个微叙事 -- 从观察到瞄准到希望到怜悯。每次硬直的提示文字不同，玩家在 2 分钟内经历了四种不同的情感回应。

**宫崎:** "这个非常好。但不是'教学'层面的需求 -- 这是叙事层面的。合并到 GAP-01 (小岛的合并设计) 中。"

---

## 议题 7: 美术方案 (GAP-02c)

### 马斯克

**"ColorRect 拼装方案在性能上完全可行，但有一个构建问题。"**

所有敌人类型的 .tscn 场景文件都是手动拼的 ColorRect 树。当前 `enemy.tscn` 只有一个 `Sprite` ColorRect。构建 4 种敌人形状意味着:
- 方案 A: 4 个 .tscn 文件 (melee_enemy.tscn / ranged_enemy.tscn / elite_melee.tscn / elite_ranged.tscn)
- 方案 B: 1 个 .tscn 文件 + 代码动态构建 (根据 `enemy_type` 枚举 add_child 不同的 ColorRect)

**我建议方案 B (代码动态构建)。** 理由: 4 个 .tscn 导致"视觉参数在 .tscn 里, 行为参数在 .tres 里"的分裂。如果将来要改一个颜色，你不知道去改 .tscn 还是 .tres。统一在代码中构建 + 参数从 .tres 读取，维护清晰。

### 杨奇 (书面意见)

(杨奇未出席，通过文档评审反馈)

**"方案 B 可以，但代码构建的逻辑必须写在独立的工厂类里，不要散在 Enemy._ready() 中。"**

```gdscript
# 建议: EnemyVisualFactory
class_name EnemyVisualFactory
extends RefCounted

static func build_visual_body(parent: Node2D, config: EnemyVisualConfig) -> VisualBody:
	# config 是 .tres 资源，定义了形状类型、颜色、尺寸
	match config.shape_type:
		"melee_chaser": return _build_melee_chaser(parent, config)
		"ranged_thrower": return _build_ranged_thrower(parent, config)
		...
```

**全员同意方案 B + 工厂类。**

### 宫崎

**"杨奇没来，但他在最终实施计划中的反馈我已经读过了。他确认 ColorRect 拼装方案可行。唯一的问题是 -- 精英的'不规则突起'如果在代码中随机化，会导致同一个精英类型每次生成看起来不一样。这对战斗可读性有影响吗？"**

**沈逸:** "正面影响。如果精英的突起是程序化随机的，玩家不能'记住精英的突起位置'来预判它的动作。这就倒逼玩家去看精英的行为 (移动模式、攻击前摇颜色) 来判断威胁，而不是看外观。这反而强化了'用颜色判断行为'的设计意图。"

**卡马克:** "技术上简单: 3 个突起的位置和大小在 `_ready()` 中随机生成并固定。同一个精英实例的外观不会在生命期内改变。"

**宫崎:** "好。那么精英的外观有轻微的程序化随机，但近战/远程的基础形状 (竖 vs 横) 保持严格区分。这是设计边界。"

---

## 议题 8: 遗漏与补充

### 沈逸

**"缺少一个关键 UI: Boss 攻击列表/招式记忆辅助。"**

玩家在 Boss 战中需要记住 Boss 的攻击模式。有经验的玩家会数循环 -- "哨声→冲撞→践踏→哨声..."。但新玩家需要辅助。

**建议:** 在 Boss 血条下方，用一排小图标 (3~5 个) 显示 Boss 上一次使用的攻击。像音游的 note track 一样 -- 不是告诉玩家下一个是什么，是让玩家看到"刚才发生了什么"。玩家自己推断模式。

**宫崎:** "这个设计很好 -- 它不告诉答案，但提供线索。但 MVP 阶段不做。放到打磨阶段。Boss 战的第一次体验应该是'不借助外部工具，靠观察学习'。"

**小岛:** "同意。这种辅助对重玩价值有帮助 (第 5 次打 Boss 时你可能不想再用记忆力)。但第一次体验不要。"

**记录:** 阶段 6 (打磨) 实现。当前文档不包含此需求。

### 马斯克

**"有一个工程遗漏: Boss 战的性能基准测试要写死。"**

Boss 战是游戏中最密集的场景: Boss + 25 个体操垫投射物 + 学生小怪 3~6 个 + 普通敌人可能还在刷新 + AOE 预览 + HUD 动画 + 暗角。

**我要求一个性能基准:** Boss 战中任何时候帧率不低于 55fps。如果低于，必须有降级策略 (体操垫数量从 5→3 波, 学生从 3→2 等)。

**宫崎:** "如果降级到 3 波体操垫，战斗体验会显著变化吗？"

**马斯克:** "5 波 → 3 波: 总伤害从最多 125 (5×25) 降到 75。但这不是数值问题 -- 是压力峰值从 5 波降到 3 波。玩家躲避的密度降低。对体验有轻微影响但可接受。性能是第一位的。"

**宫崎:** "OK。设计上: 默认 5 波。如果 profiling 发现 < 55fps，配置表中设置 `max_waves = 3`。这是配置层面的降级，不需要改代码。"

---

## 议题 9: 与 GAP-01 的边界确认

### 小岛秀夫

**"我要确认一件事: 本文档 (GAP-02a/b/c) 中 Boss 攻击的具体参数 (前摇/硬直/伤害) 是'接口定义'还是'最终数值'？"**

因为我现在在写 GAP-01 (Boss 合并设计)，我需要知道这些参数是我来定还是宫崎来定。

**宫崎:** "GAP-02a 的 `BossAttackData` 定义了**参数槽位** (有哪些参数需要填)。具体数值由你在 GAP-01 中填写。但前摇/硬直的**最低标准**由我锁定 -- 前摇 >= 0.35s, 硬直 >= 0.2s。你在这些约束内自由设计。"

**小岛:** "明白。那我在 GAP-01 中会引用 `BossAttackData` 的参数槽位，填写每个攻击的具体值。如果我认为某个攻击需要 0.3s 前摇 (比你的最低标准快 0.05s)，我会提出理由。"

**宫崎:** "提出理由就可以。0.35s 是最低标准，不是教条。 如果你的设计有充分的交互理由 (比如: 这个攻击本身是'轻'的，玩家可以用更短的窗口应付)，可以破例。但最终数值需要我过一遍 -- 确保没有一个攻击让玩家感觉'不可能反应'。"

**小岛:** "同意。"

---

## 会议结论

### 已决议

| # | 决议 | 影响文档 |
|---|------|---------|
| 1 | `try_execute()` await 后增加中断检查 (can_execute + is_dead) | GAP-02a 需求 1 |
| 2 | 前摇参数默认在技能自身，BossAttackData 可 override | GAP-02a 需求 1/5 |
| 3 | EnemyVisualState 加 `_dirty` 标记 + `call_deferred` 防抖 | GAP-02a 需求 2 |
| 4 | Boss 激活时普通敌人短暂 dim (0.5s) | GAP-02a 需求 2 |
| 5 | AI 决策间隔差异化 (近/中/远 三档) | GAP-02a 需求 3 |
| 6 | AttackCoordinator 增加优先级排序 (距离+精英+相位) | GAP-02a 需求 4 |
| 7 | 排队敌人做小幅随机移动 + 头顶省略号 | GAP-02a 需求 4, GAP-02b 需求 2 |
| 8 | BossAttackData 加 `narrative_hint` 字段 | GAP-02a 需求 5 |
| 9 | 首次 Boss 硬直显示教学文字 (含蓄风格), 后续不再显示 | GAP-02b 需求 4 |
| 10 | 敌人形状用代码工厂构建 (非 .tscn 预制), 精英突起轻微随机化 | GAP-02c 需求 1 |
| 11 | Boss 性能基准: 55fps 最低; 降级策略在配置层 | 全文档 |
| 12 | 攻击具体数值由 GAP-01 (小岛) 在宫崎约束 (前摇>=0.35s, 硬直>=0.2s) 内定义 | GAP-01 与 GAP-02 边界 |

### 待后续决议

| # | 议题 | 状态 |
|---|------|------|
| 1 | Boss 攻击列表记忆辅助 UI (音游 note track) | 推迟到打磨阶段 |
| 2 | 屏幕边缘 AOE 方向指示器 | 预留接口, 暂不实现 |
| 3 | Boss 各阶段硬直提示的不同叙事文字 | 合并到 GAP-01 |

### 下一步

- **宫崎:** 更新 GAP-02a/b/c 三份文档，吸收上述决议
- **小岛:** 在 GAP-01 中引用 `BossAttackData` 参数槽位，填写具体数值; 引用 `narrative_hint` 字段编写叙事描述
- **卡马克:** 开始实现 `SkillBase` 前摇改造 (需求 1) + `EnemyVisualState` (需求 2)
- **马斯克:** 确认 NavAgent 回退策略; 准备性能 profiling 基准

---

*纪要整理: 宫崎英高*
*下次评审: Boss 攻击具体数值 (GAP-01 + GAP-02a 需求 5)*
*预计日期: 小岛完成 GAP-01 后次日*
