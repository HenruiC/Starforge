# GAP-01b 交互任务 — Boss 战 UI/UX 与演出

> **基于：GAP-01 Boss战最终设计-合并版**
> **负责人：交互策划**
> **总计工时：~5 天**

---

## 前置说明

这些任务关注"玩家看到什么、感受到什么"。所有 Tween 使用 `TWEEN_PROCESS_IDLE`（遵循 Tween 生命周期规范 v1.0）。所有 Tween group 名称在 `UIEffects` 中注册。

---

## 任务清单

### TASK-I01: 沉默时刻 HUD 消退/恢复

- **负责人**：交互策划
- **工作量**：1 天
- **依赖**：需要程序提供 HUD 元素注册表（`HUDManager` 单例）
- **修改文件**：
  - 新增 `scripts/ui/hud_manager.gd` + `.uid`
  - 可能需要修改 `scripts/game_manager.gd` 中 HUD Tween 管理

**设计目标**：Boss 出场前 2-3 秒，HUD 全部消退。消退不是瞬间消失——是从边缘向中心阶梯式抽走，像光从视野边缘被剥夺。

**具体设计**：

1. **HUD 消退顺序**（按 stagger 消退，间隔 0.1s）：
```
第 1 步 (t=0.0s): 地图按钮 / 技能图标（外围标签）
第 2 步 (t=0.1s): 任务目标文字 / 波次标签
第 3 步 (t=0.2s): 计时器 / 击杀数标签中心信息
第 4 步 (t=0.3s): 经验条 / 等级标签
第 5 步 (t=0.4s): HP 条 / MP 资源（核心数值——最后消退）
```
消退动效：`modulate.a → 0`，每个元素 0.5s 淡出。不改变 `visible`（保持布局稳定）。

2. **消退前 kill 所有进行中的 HUD Tween**：
```
先 kill 以下 group：hud_killcount, hud_wave, hud_timer, hud_mission, hud_cooldown, hud_exp
防止消退 Tween 与 KillCount 弹跳动效冲突
```

3. **HUD 恢复顺序**（与消退相反，更快）：
```
第 1 步 (t=0.0s): HP 条 / 经验条（核心数值——先回来，你准备好了）
第 2 步 (t=0.08s): 计时器 / 击杀数
第 3 步 (t=0.16s): 任务目标 / 波次标签
第 4 步 (t=0.24s): 技能图标 / 地图按钮（外围标签——最后回来）
```
恢复动效：`modulate.a 0→1`，每个元素 0.3s 淡入。比消退快——"消退是远离，恢复是回归"。

4. **与 Tween group 的互斥**：
   - 沉默时刻使用独占 group name: `hud_silence`
   - 消退开始前：`UIEffects.kill_group("hud_silence")` 再 `UIEffects.kill_group` 所有常规 HUD group
   - 恢复开始前：`UIEffects.kill_group("hud_silence")`
   - 恢复完成后：重新允许常规 HUD group 运作

**技术实现参考**：
```gdscript
# HUDManager.gd
class_name HUDManager
extends Node

# HUD 元素注册表（按消退顺序排列）
var _fade_out_order: Array[Control] = []
var _fade_in_order: Array[Control] = []

func register_element(ctrl: Control, out_priority: int, in_priority: int) -> void:
    # out_priority: 0=最先消退, 4=最后消退
    # in_priority: 0=最先恢复, 4=最后恢复

func trigger_silence() -> void:
    # 1. kill 所有常规 HUD Tween groups
    # 2. 按 out_priority 升序 stagger 消退
    for i in range(5):
        for elem in _fade_out_order:
            if elem.out_priority == i:
                _fade_element(elem, false, i * 0.1)

func trigger_silence_restore() -> void:
    # 1. kill hud_silence group
    # 2. 按 in_priority 升序 stagger 恢复
    for i in range(5):
        for elem in _fade_in_order:
            if elem.in_priority == i:
                _fade_element(elem, true, i * 0.08)
```

**验收标准**：
- Boss 出场前 HUD 阶梯消退完整（5 层，间隔 0.1s）
- Boss 激活后 HUD 反向恢复完整（5 层，间隔 0.08s）
- 消退期间 KillCount 弹跳不与消退 Tween 冲突
- Player 始终可以操作（无冻结）

---

### TASK-I02: Boss 血条 UI（屏幕顶部）

- **负责人**：交互策划
- **工作量**：0.75 天
- **依赖**：程序提供 `BossHealthBar` 节点（TASK-P08）
- **修改文件**：HUDLayer 场景 / 新增 `scripts/ui/boss_health_bar.gd`

**设计目标**：屏幕顶部中央的独立 Boss 血条。这是游戏中第一次出现"顶部血条"——之前所有敌人都在头顶显示小血条。Boss 需要一个更有仪式感的血条位置。

**具体设计**：

1. **位置与尺寸**：
   - 锚定屏幕顶部中央
   - 宽度：屏幕宽度的 60%，最小 600px，最大 800px
   - 高度：14px
   - 距离屏幕顶部边缘：24px

2. **视觉层次**：
```
┌─────────────────────────────────────────────────────┐
│  [背景层] 深灰半透明 ColorRect (alpha 0.25)         │
│  [前景层] 深红 ProgressBar (随 HP 减少而缩短)        │
│  [标记线] 3 条竖线（在 75%/50%/25% 位置）            │
│  [名称]   "体育老师 · 佐藤" 在血条左上方              │
│  [HP数值] "1200 / 1600" 在血条右上方（可选）          │
└─────────────────────────────────────────────────────┘
```

3. **入场动效**：
   - Boss 激活（光环首次亮起）时，血条从屏幕顶部滑入 + 淡入
   - `position.y: -30 → 24` (0.3s, Tween.EASE_OUT)
   - `modulate.a: 0 → 1` (0.25s)
   - group name: `hud_boss_hp`

4. **HP 减少动效**：
   - 不是瞬间跳到新值——用 0.3s 平滑 Tween
   - 类似"他在流血"的感觉
   - 实现：维护一个 `display_hp` 变量，每次 `set_hp()` 时 Tween `display_hp` 到目标值
   ```gdscript
   func set_hp(current: int, max_hp: int) -> void:
       var target_ratio := float(current) / float(max_hp)
       var t := create_tween()
       t.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
       t.tween_property(self, "value", target_ratio * 100.0, 0.3)
   ```

5. **阶段标记线**：
   - 3 条细竖线（2px 宽），分别位于 ProgressBar 的 75%/50%/25% 位置
   - 颜色：灰白 `Color(0.7, 0.7, 0.7, 0.6)`
   - 当 HP 通过标记线时（阶段转换），该标记线做一个微型脉冲（scale 闪一下）

6. **退场动效**：
   - Boss 死亡后：血条淡出 + 上滑消失 (0.3s)
   - `modulate.a → 0` + `position.y: 24 → -10`

**验收标准**：Boss 激活时血条滑入。受击时平滑减少。3 条阶段标记线可见。Boss 死亡后血条退场。

---

### TASK-I03: 乐章/阶段转换提示（视觉暗示，不弹文字）

- **负责人**：交互策划
- **工作量**：0.5 天
- **依赖**：TASK-I02
- **文件**：`scripts/ui/boss_health_bar.gd` 扩展

**设计原则**：不弹"Phase 2"文字。小岛："Show, don't tell." 玩家通过视觉变化感知阶段转换。

**具体设计**：

1. **第一乐章→第二乐章（HP 降到 75%）**：
   - 血条 75% 标记线做一次闪光脉冲（短暂变亮，0.3s）
   - 血条前景颜色从深红微调为略偏橙 `Color(0.7, 0.1, 0.02) → Color(0.75, 0.15, 0.02)`（暗示光环从橙→黄的变化正在发生）
   - 以上是血条自身的表演。Boss 本体的视觉变化（后退+光环变色）由美术层处理

2. **第二乐章→第三乐章（HP 降到 50%）**：
   - 血条 50% 标记线做一次闪光脉冲
   - 血条背景短暂出现微弱的白色波纹（一个大型脉冲 Tween，alpha 0→0.15→0，scale 1.0→1.05→1.0，0.6s）——呼应 Boss 的白色声波

3. **第三乐章→第四乐章（HP 降到 25%）**：
   - 血条 25% 标记线做一次闪光脉冲
   - 血条前景颜色变为暗红近乎黑 `Color(0.35, 0.03, 0.01)`
   - 血条周围短暂出现碎裂粒子（白色小方块从标记线处飞出，0.4s）——呼应光环碎裂
   - 三条标记线在碎裂后同时消失（"阶段标记已经没有意义了"）

4. **通用规则**：
   - 所有提示都是血条自身的微表演，不弹文字
   - 不会中断战斗
   - 闪光脉冲持续时间 ≤ 0.3s

**验收标准**：玩家在战斗中看到血条标记线闪光→就知道进入了新阶段。没有文字弹窗。所有微表演不干扰战斗可读性。

---

### TASK-I04: 击败后的"下课"文字演出

- **负责人**：交互策划
- **工作量**：0.75 天
- **依赖**：TASK-P07（终结序列）提供信号
- **新增文件**：`scripts/ui/victory_text.gd` + `.uid`

**设计目标**：Boss 死亡后屏幕中央出现"体育老师 · 佐藤 —— 下课"。不是廉价的"Victory!"弹窗。是一个呼吸着的、有重量的文字。

**具体设计**：

1. **文字规格**：
   - 内容："体育老师 · 佐藤 —— 下课"
   - 字号：28px（比通常 UI 大）
   - 颜色：`Color(1.0, 0.15, 0.05)` 红色警告色（复用 PromptConfig 的 `is_warning` 配色）
   - 字体描边：2px 黑色描边（保证在金色粒子背景下可读）
   - 位置：屏幕中央，y 偏移 -40px（给 Stage Complete 提示留空间）
   - z_index：100（在所有 UI 之上，但在 Stage Complete 提示之下）

2. **入场动效**（总计 0.8s）：
   ```
   t=0.0s  文字出现，初始 scale = 0.3, modulate.a = 0
   t=0.0→0.4s  文字从下方飘入 + 缩放：
              position.y: +30 → 0 (相对于锚点)
              scale: 0.3 → 1.0
              modulate.a: 0 → 1.0
              (Tween.EASE_OUT, Tween.TRANS_BACK)
   t=0.4→0.8s  文字微微回弹：
              scale: 1.0 → 1.03 → 1.0 (呼吸 pulse)
   ```

3. **停留期间的呼吸动效**（持续 2 秒）：
   ```
   var breath := create_tween().set_loops()
   breath.tween_property(label, "scale", Vector2(1.03, 1.03), 1.2).set_ease(Tween.EASE_IN_OUT)
   breath.tween_property(label, "scale", Vector2.ONE, 1.2).set_ease(Tween.EASE_IN_OUT)
   ```

4. **退场动效**（0.5s）：
   ```
   t=0.0→0.5s  fade out + 微微上浮：
              modulate.a: 1.0 → 0
              position.y: 0 → -20
   ```

5. **与 Stage Complete 提示的时序**：
   - 胜利文字消失后 → 0.2s 间隔 → Stage Complete 提示接管（已有系统）
   - Stage Complete 提示显示："✓ 体育馆变异体已被击败"

**验收标准**：Boss 死亡后约 1s 文字入场。呼吸动效持续 2s。文字退场后 Stage Complete 提示正常出现。在金色粒子背景下文字清晰可读。

---

### TASK-I05: 击败后升级序列的微型电影

- **负责人**：交互策划
- **工作量**：1 天
- **依赖**：TASK-P10（战后升级延迟弹出）、TASK-I04 的胜利文字系统
- **修改文件**：`scripts/game_manager.gd`（`_show_upgrade_panel()` 扩展）

**设计目标**：Boss 战后的第一个升级面板不是常规弹出——它是一个微型电影。面板从 Boss 倒下的位置"绽放"出来，标题不是"升级！"而是"佐藤的馈赠"。

**具体设计**：

1. **面板标题替换**：
   - 第一个面板标题："佐藤的馈赠"
   - 后续面板（如有多个累积升级）：恢复标准标题"升级！"
   - 标题颜色：金色 `Color(1.0, 0.85, 0.2)`（不是标准的白色）

2. **第一个面板入场（从 Boss 倒下位置绽放）**：
   - 获取 Boss 倒下位置的屏幕坐标
   - 面板初始 pivot_offset 设置为中心
   - 面板初始 global_position 设置为 Boss 倒下屏幕坐标
   - 入场动效：
   ```
   t=0.0s  面板在 Boss 位置，scale = 0.05, modulate.a = 0
   t=0.0→0.25s  面板飞行到屏幕中心：
                global_position: Boss位置 → 屏幕中心
                scale: 0.05 → 1.05
                modulate.a: 0 → 1.0
   t=0.25→0.35s  面板回弹到正常大小：
                scale: 1.05 → 1.0
   ```
   - 金色粒子从 Boss 倒下位置跟随面板飞行轨迹（3-5 个金色粒子从 Boss 位置向屏幕中心飘）

3. **面板内部 stagger 入场**：
   - 面板抵达屏幕中心后（0.35s），内部元素 stagger：
   ```
   t=0.35s  标题 "佐藤的馈赠" 淡入 + 微型弹跳
   t=0.40s  第一个选项按钮 scale 0.5→1.0
   t=0.46s  第二个选项按钮 scale 0.5→1.0
   t=0.52s  第三个选项按钮 scale 0.5→1.0
   t=0.58s  （如有）第四选项按钮 scale 0.5→1.0
   ```

4. **升级选项选择后的退场**：
   - 面板标准退场（复用现有退场逻辑）——不需要特殊处理
   - 但退场粒子用金色（呼应"馈赠"主题）

5. **15% 概率"哨声"第四选项**（已有 Operator Protocol 机制）：
   - 选项外观：红色调 `modulate = Color(0.8, 0.15, 0.15, 0.7)`
   - 文字："???\n你听到了一声哨响——但你已经听不到哨响了。"
   - hover 无反馈（已有机制）
   - 选中后 UI 乱码持续 **5s**（不是通常的 2s——"佐藤的馈赠不是那么容易被消化的"）

6. **后续累积升级面板**：
   - 第一个面板退场后 0.3s → 第二个面板标准入场（屏幕中心，标准标题"升级！"）
   - 第三个及以后同理
   - 每个面板独立退场后再弹出下一个

**验收标准**：
- 第一个升级面板从 Boss 倒下位置飞向屏幕中心
- 标题为"佐藤的馈赠"，金色
- 面板内部元素 stagger 入场
- 15% 概率哨声选项，乱码 5s
- 后续面板标准入场

---

### TASK-I06: Vignette 暗角效果控制

- **负责人**：交互策划（与美术协作）
- **工作量**：0.5 天
- **依赖**：需要美术提供暗角纹理资源（或程序化生成）
- **修改文件**：`scripts/game_manager.gd`（`_build_low_hp_overlay` 扩展或新建 vignette overlay）

**设计目标**：从 Stage 3 激活到 Boss 击败，屏幕边缘持续存在暗角。暗角的 alpha 在不同阶段动态变化。

**具体设计**：

暗角的四种状态：

| 状态 | Alpha | 触发时机 | 渐变时长 |
|------|-------|---------|---------|
| 关闭 | 0.0 | 正常游戏 / Boss 战后 | 2s |
| 接近中 | 0.0 → 0.3 | 玩家进入 zone_gym_entrance | 15s |
| 沉默时刻 | 0.3 → 0.6 | 玩家进入 zone_gym_boss 后 | 0.5s |
| Boss 战中 | 0.6 | Boss 激活后保持 | — |
| 消退中 | 0.6 → 0.0 | Boss 死亡后 1.5s | 2s |

**技术实现**：
- 在 HUDLayer 下创建 `VignetteOverlay` (TextureRect)
- 使用 `GradientTexture2D` + 径向渐变（从中心透明 → 边缘深灰/黑）
- 渐变中心 `fill_to = Vector2(0.5, 0.5)`
- 边缘颜色：`Color(0.05, 0.02, 0.02, 0.6)` 极暗红黑（不是纯黑——有体育馆的气味）
- 通过 Tween `modulate.a` 控制暗角浓度
- group: `hud_vignette`
- z_index = 8（低于 HUD 元素 ~10-15，高于游戏画面 0-5）

**与 LowHP Overlay 的区别**：
- LowHP overlay 是红色的，只在 HP<30% 时出现，表达"受伤"
- Vignette 是暗色/黑色的，在 Boss 战中持续存在，表达"气氛"
- 两者独立控制，不互斥

**验收标准**：暗角四种状态渐变流畅。不与 LowHP overlay 冲突。Boss 战后暗角完全消退。

---

### TASK-I07: Boss 战中 UI 的"伤疤联动"

- **负责人**：交互策划
- **工作量**：0.25 天
- **依赖**：沉默时刻 HUD 消退系统 (TASK-I01)
- **修改文件**：`scripts/ui/hud_manager.gd`

**设计目标**：小岛设计中的"UI 伤疤"概念——如果玩家带着高破损度 UI 进入 Boss 战，沉默时刻的 HUD 消退表现为"瞬间关掉"（像旧电视被直接拔了电源）。

**具体设计**：

```gdscript
# 在沉默时刻触发时检查 UI 破损度
func trigger_silence(scar_level: int) -> void:
    match scar_level:
        0:  # 无破损 — 正常阶梯消退
            _fade_hud_staggered(0.5, 0.1)  # 0.5s 淡出，间隔 0.1s
        1:  # 轻度破损 — 加速消退
            _fade_hud_staggered(0.3, 0.06)
        2:  # 重度破损 — 瞬间消失
            _fade_hud_instant()  # 无 Tween，直接 modulate.a = 0
```

> 注：UI 破损度的具体实现在其他模块中。此任务只做"检查破损级别 + 应用对应消退方式"的逻辑。如果破损系统尚未实现，默认使用 scar_level = 0（正常消退）。

**验收标准**：在破损系统可用时，高破损 UI 在沉默时刻瞬间消失。

---

## 工时汇总

| 任务 | 负责人 | 工时（天） |
|------|--------|-----------|
| TASK-I01 沉默时刻 HUD 消退/恢复 | 交互策划 | 1.0 |
| TASK-I02 Boss 血条 UI | 交互策划 | 0.75 |
| TASK-I03 阶段转换提示 | 交互策划 | 0.5 |
| TASK-I04 胜利文字演出 | 交互策划 | 0.75 |
| TASK-I05 升级序列微型电影 | 交互策划 | 1.0 |
| TASK-I06 Vignette 暗角控制 | 交互策划 | 0.5 |
| TASK-I07 UI 伤疤联动 | 交互策划 | 0.25 |
| **总计** | | **~4.75 天** |

---

## 依赖关系

```
TASK-I01 (沉默HUD) ── 独立，需 HUDManager
TASK-I02 (Boss血条) ── 依赖 TASK-P08（程序HP条节点）
TASK-I03 (阶段提示) ── 依赖 TASK-I02
TASK-I04 (胜利文字) ── 依赖 TASK-P07（终结序列）
TASK-I05 (升级微型电影) ── 依赖 TASK-P10（战后升级）+ TASK-I04
TASK-I06 (暗角) ── 独立
TASK-I07 (伤疤联动) ── 依赖 TASK-I01
```

---

## 与 Tween group 的注册

所有新增 Tween group 必须在 `UIEffects` 中注册（遵循 Tween 生命周期规范 v1.0）：

| Group Name | 用途 | 互斥对象 |
|-----------|------|---------|
| `hud_silence` | 沉默时刻 HUD 消退/恢复 | 所有常规 HUD group (hud_killcount/wave/timer/mission/cooldown/exp) |
| `hud_boss_hp` | Boss 血条入场/退场 | 自身（同 group 互斥） |
| `hud_vignette` | 暗角 alpha 渐变 | 自身 |
| `hud_victory_text` | 胜利文字入场/呼吸/退场 | 自身 |
| `hud_boss_panel` | 佐藤的馈赠面板入场 | panel_levelup |
