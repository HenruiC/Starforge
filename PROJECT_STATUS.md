# PROJECT STATUS — Combat Demo (Starforge 幸存者Like)

> 最后更新: 2026-05-20 | 新会话第一时间读此文档 + CLAUDE.md
> 引擎: Godot 4.6.2 mono | 分辨率: 1280x720 | 类型: 学校副本俯视角2D割草

---

## 一、项目概要

- **项目路径**: `D:\AI\GodotProjects\combat-demo`
- **引擎路径**: `D:\Godot_v4.6.2-stable_mono_win64`
- **主场景**: `res://scenes/main.tscn`
- **Autoload**: EventBus, CombatFeedback, GameState, Coordinator (AttackCoordinator)
- **操控**: WASD 移动 / 自动攻击 / M 地图 / 空格对话

---

## 二、一句话状态

Phase A/B/D/E 已交付。Phase C (Boss AI + 技能) 大部分完成。Phase F (副本配置 + 数值) 待 C 完成后启动。目标：完整可玩的学校副本（叙事 + 5 Stage 任务 + Boss 战 + 结算）。

---

## 三、已完成功能（按模块）

### 3.1 CombatUnit 统一战斗框架
- `CombatUnit` (CharacterBody2D) — Player/Enemy 公共基类
- Team 阵营 (FRIENDLY/ENEMY/NEUTRAL) + HP 管理 + 击退
- StatsComponent — 属性公式: `(base + flat) * (1 + sum%) * product`
- BuffComponent — StatModifier Resource 叠加
- SkillBase 改造: `owner_unit` + `target_node` + windup/recovery 协程
- Player extends CombatUnit — PlayerController (WASD 输入)
- Enemy extends CombatUnit — AIController

### 3.2 AI 系统
- AIBehaviorController — 9 行为模式 (enum + switch)
- NavigationAgent2D 寻路 (path_desired_distance=10, target_desired_distance=20)
- 近战冲刺攻击状态机: idle → windup → lunge → retreat + cooldown + hit detection
- 远程行为: kite at preferred_distance, shoot timer
- 躲闪行为 (dodger): 绕圈移动
- 狂暴 (Berserk): speed * 1.5 + timer
- 驻守 (DEFEND_ZONE): 低优先级敌人驻守 zone target
- VisualStateMachine — 9 状态: NORMAL/WINDUP/BERSERK/STUNNED/DEAD 等
- 攻击前摇系统: >=0.35s, 方向锁定, 橙黄变色
- AttackCoordinator (Autoload): 同帧攻击 <=3, 优先级排序
- EnemyVisualFactory: ColorRect 拼装 (竖=近战/横=远程/大=精英)
- 敌人墙壁滑动: move_and_slide 碰撞检测 + 侧移绕行
- AIEnemyConfig Resource: melee_default/ranged_default/elite_default

### 3.3 Boss 系统
- **BossConfig** Resource — 工厂方法 `sato_default()`, 含四乐章全部参数
- **BossPhaseController** — HP 阈值触发阶段转换, `check_transition(hp_ratio)`
- **BossAI** — 四乐章独立移动策略 + 攻击选择逻辑
  - P1 热身: 固定循环 M1-A→B→C→D
  - P2 球类训练: 权重随机, 不连续重复
  - P3 集合: 召唤学生 + 随机攻击
  - P4 毕业考试: 绝望冲刺 + 器材雨, 攻击间隔递减
- **BossDeathSequence** — 通用死亡管线:
  1. Big Hit Stop (0.05x time_scale, 0.15s)
  2. 时缓展开 (cubic ease-out → 1.0x)
  3. Boss 坍塌 (纵向压缩 + 横向拉宽 + 灰度化 + 口哨掉落)
  4. 金色粒子爆发 (40 particles)
  5. VictoryTextUI 大字
- **13 Boss 技能** (SkillBase 子类):
  - M1: HeavySweep, WhistleWave, RollCharge, VaultStomp
  - M2: Fastball, Lob, WhistleShriek, IronShoulder, GroundShockwave
  - M3: SummonWhistle, Dash
  - M4: DesperateDash, EquipmentRain
- **BossPhaseData** Resource — 每乐章独立配置
- **BossAttackData** Resource
- **Boss 可视化**:
  - BossVisual — 5 部件拼装 (Body/Head/ArmL/ArmR/Legs)
  - BossVisualAnimator — 攻击动画协调
  - BossAuraController — 光环脉冲
  - SonicWave — 声波效果
- **StudentMinion** — P3 学生小怪系统
- **Boss UI**:
  - SilenceController — HUD 5 层 stagger 消退
  - BossHpBar — 顶部居中, 三条阶段标记线
  - VictoryTextUI — "体育老师 · 佐藤 —— 下课"
  - VignetteController — 四状态暗角 (NORMAL/APPROACH/BATTLE/DEFEAT)

### 3.4 任务系统 (V2)
- **MissionChain** — 多 Stage 任务链 Resource
- **MissionStage** — 单阶段: 条件 + 目标 + 提示 + 对话
- **MissionObjective** — completion_action 支持 door_id / defend_zone
- **MissionTriggerManager** — 通用触发引擎, 5 种 Evaluator:
  - LOCATION_REACH / KILL_COUNT / TIME_SURVIVE / DEFEND_ZONE / PROTECT_OBJECT
- **MissionManager** — 向后兼容接口层, 学校副本 5 Stage 链:
  - Stage 1: 踏入校园 (KILL_COUNT)
  - Stage 2: 铃声响起 (DEFEND_ZONE)
  - Stage 3: 锁住的门 (KILL_COUNT → 解锁 gym_lock_door)
  - Stage 4: 体育馆的哨声 (Boss 战)
  - Stage 5: 放学 (到达校门 → 结算)
- **LockedDoor** — 门锁系统, EventBus.door_unlock_requested 事件驱动
- **MissionPromptUI** — 方向箭头 + 进度弹窗
- TriggerConfig / PromptConfig Resources

### 3.5 面板队列
- **PanelManager** — 优先级队列状态机
  - dialogue(0) > levelup(1) > map(2) > dungeon_result(3)
  - 高优先级预占, 低优先级推入队列前端保留
  - 淡入淡出过渡 + 中断处理 + 状态追踪
- **UIEffects** — 静态动效工具类 + Tween 注册表
- **UIHelpers** — 共享样式工厂
- 角色选择面板 (CharSelectUI) + 升级面板 (UpgradeUI) + 对话面板 (DialoguePanel)

### 3.6 地图系统
- **school_map.gd** — 8 色 TileMap 区域 (罗梅罗关卡分区)
  - 浅沙操场 / 深灰教室 / 暗红棕左墙 / 暗绿棕右墙 / 中灰走廊 / 红褐体育馆
  - 锁住的门 (暗红褐) / 校门 / 门外白光
- **tilemap_builder.gd** — 简化版地图 (3200x2400), 测试用
- **MapSystem** — 迷雾系统: TileMap layer 2 + 玩家标记 + 探索率
  - 玩家周围 5x5 grid 揭示, 每 0.25s 刷新
- ImageTexture 地图: 运行时从 Image 生成俯视图纹理
- **NavManager** — NavigationRegion2D 导航区域
- **AssetLoader** — PNG 优先 → JPG fallback

### 3.7 结算系统
- **DungeonResultPanel** — "暗金琥珀"配色 (杨奇色板)
  - 纯代码构建, 无 .tscn
  - S/A/B/C 评分 (基于时间、击杀、死亡)
- Stage 4/5 到达校门 → 触发结算面板
- 结算数据: kill_count, current_wave, time_elapsed, death_count

### 3.8 持久化与伤疤系统
- **GamePersistence** — ConfigFile 读写 user://game_persistence.cfg
  - Boss 遭遇次数 (仪式感递减: 登场时长/沉默时长/HitStop)
  - 累计死亡次数 + 伤疤等级 (0-3)
  - 击败 Boss 减少死亡计数 ("半治愈")
- **UIScarController** — HUD 伤疤闪烁效果

### 3.9 UI 动效 (Phase 1-3)
- 按钮 hover (scale 1.05)
- 击杀/波次数字弹跳 (仪式感递减)
- 升级面板 stagger (0.06s)
- 打字机效果 (0.02s/字)
- GameOver 序列 (死亡 5 次后加速)
- 低血量警告 (径向红幕)
- 尖叫时刻 A (第四选项, 5% 概率)
- CharSelect 入场两层节奏
- "踏入试炼"过渡

### 3.10 像素风资产标准
- Tile 尺寸: 48px
- 纯色 Texture2D 生成的墙/地板/门 tile
- 技能图标: PNG (带 .import 文件)
- 武器图标: sword/bow/staff (PNG+JPG 双版本)
- 地图纹理: map_full.jpg

### 3.11 其他系统
- **CombatFeedback** (Autoload): 顿帧/震动/伤害数字/粒子
- **GameState** (Autoload): 状态机 (INIT/PLAYING/PAUSED/GAMEOVER)
- **EventBus** (Autoload): 全局信号枢纽, 40+ 信号
- **Door** — 可交互门 (进入/退出)
- **Destructible** — 可破坏物
- **CameraController** — 相机跟随
- **DamageNumber** — 伤害数字浮出效果
- **VFXUtils** — 粒子特效工具

---

## 四、当前编译状态

### 已知问题
1. **SCRIPT ERROR**: `game_manager.gd:813` — `activation_range` 赋值失败
   - 原因: `_spawn_preplaced_enemies()` 中实例化为 `CharacterBody2D` 类型，`Enemy.activation_range` 不可见
   - 修复: `var e := ... as Enemy` 或显式类型标注
2. **WARNING**: NavManager 未找到 TileMap (某些场景布局下)
3. enemy.gd 近期从 git 重写恢复 — 近战冲刺攻击状态机完整重建
4. Boss 技能参数需要用 BossConfig 工厂方法补全数值

### 手动步骤（新会话打开后）
1. 在 Godot 编辑器中打开项目
2. 删除 `.godot/global_script_class_cache.cfg`
3. 确认 AttackCoordinator 已在 Autoload 中注册
4. 在 Godot 中运行项目验证编译通过

---

## 五、关键文件索引

### 核心脚本 (scripts/)

| 文件 | 说明 |
|------|------|
| `combat_unit.gd` | 统一战斗基类 (CharacterBody2D), HP/受伤/死亡/击退 |
| `player.gd` | 玩家: WASD 输入 + 自动攻击 + 技能 + 升级 |
| `enemy.gd` | 敌人: 近战冲刺/远程/躲闪/狂暴/Boss, NavigationAgent2D |
| `game_manager.gd` | 主循环: 波次/生成/UI面板/任务/对话/动效 (~900行) |
| `event_bus.gd` | 全局信号枢纽 (Autoload), 40+ 信号 |
| `combat_feedback.gd` | 顿帧/震动/伤害数字/粒子 (Autoload) |
| `game_state.gd` | 状态机 INIT/PLAYING/PAUSED/GAMEOVER (Autoload) |
| `skill_manager.gd` | 技能管理 (9 个玩家技能) |
| `mission_manager.gd` | 任务系统 V2 接口层, 委托 MissionTriggerManager |
| `mission_trigger_manager.gd` | 通用触发引擎, 5 种 Evaluator |
| `nav_manager.gd` | NavigationRegion2D 导航区域 |
| `school_map.gd` | 8 色 TileMap 区域, 罗梅罗关卡分区 (5760x4320) |
| `tilemap_builder.gd` | 简化地图构建器 (3200x2400) |
| `map_system.gd` | 迷雾 + 玩家标记 + 探索率 |
| `map_school.gd` | 学校地图辅助 |
| `map_manager.gd` | 地图纹理管理 |
| `asset_loader.gd` | PNG 优先资源加载 |
| `asset_manager.gd` | 资源管理辅助 |
| `camera_controller.gd` | 2D 相机跟随 |
| `locked_door.gd` | 锁住的门, EventBus 事件解锁 |
| `door.gd` | 可交互门 (进入/退出) |
| `destructible.gd` | 可破坏物 |
| `damage_number.gd` | 伤害数字浮出 |
| `player_projectile.gd` | 玩家弹射物 |
| `enemy_projectile.gd` | 敌人弹射物 |

### 组件 (scripts/components/)

| 文件 | 说明 |
|------|------|
| `stats_component.gd` | 属性公式: (base+flat)*(1+sum%)*product |
| `buff_component.gd` | Buff 管理, StatModifier 叠加 |

### AI 系统 (scripts/ai/)

| 文件 | 说明 |
|------|------|
| `ai_behavior_controller.gd` | AI 行为状态机 (9 模式) |
| `visual_state_machine.gd` | 视觉状态: NORMAL/WINDUP/BERSERK 等 |
| `attack_coordinator.gd` | 攻击协调器 (Autoload), 同帧 <=3 |
| `enemy_visual_factory.gd` | ColorRect 拼装工厂 |

### Boss 系统 (scripts/boss/)

| 文件 | 说明 |
|------|------|
| `boss_phase_controller.gd` | 四乐章 HP 阈值管理 |
| `boss_ai.gd` | 四乐章移动策略 + 攻击选择 |
| `student_minion.gd` | P3 学生小怪 |

### Boss 技能 (scripts/skills/boss/)

| 文件 | 说明 |
|------|------|
| `skill_m1_heavy_sweep.gd` | P1: 重扫攻击 |
| `skill_m1_whistle_wave.gd` | P1: 哨声波 |
| `skill_m1_roll_charge.gd` | P1: 前滚冲撞 |
| `skill_m1_vault_stomp.gd` | P1: 撑竿跳踩踏 |
| `skill_m2_fastball.gd` | P2: 快速投球 |
| `skill_m2_lob.gd` | P2: 高抛球 |
| `skill_m2_whistle_shriek.gd` | P2: 尖哨 |
| `skill_m2_iron_shoulder.gd` | P2: 铁山靠 |
| `skill_m2_ground_shockwave.gd` | P2: 地面冲击波 |
| `skill_m3_summon_whistle.gd` | P3: 召集哨 |
| `skill_m3_dash.gd` | P3: 冲刺 |
| `skill_m4_desperate_dash.gd` | P4: 绝望冲刺 |
| `skill_m4_equipment_rain.gd` | P4: 器材雨 |

### Boss 可视化 (scripts/visual/)

| 文件 | 说明 |
|------|------|
| `boss_visual.gd` | 5 部件拼装 + 坍塌动画 |
| `boss_visual_animator.gd` | 攻击动画协调 |
| `boss_aura_controller.gd` | 光环脉冲 |
| `student_minion_visual.gd` | 学生小怪视觉 |
| `sonic_wave.gd` | 声波效果 |

### UI 系统 (scripts/ui/)

| 文件 | 说明 |
|------|------|
| `panel_manager.gd` | 面板优先级队列 + 状态机 |
| `ui_effects.gd` | Tween 工具类 + 注册表 |
| `ui_helpers.gd` | UI 样式工厂 |
| `silence_controller.gd` | Boss 登场沉默时刻 |
| `boss_hp_bar.gd` | Boss 血条 (阶段标记线) |
| `victory_text_ui.gd` | 击败大字 |
| `vignette_controller.gd` | 暗角 (4 状态) |
| `boss_death_sequence.gd` | Boss 死亡演出管线 |
| `char_select_ui.gd` | 角色选择 |
| `upgrade_ui.gd` | 升级面板 |
| `dialogue_panel.gd` | 对话 (打字机 + 滑入) |
| `mission_prompt_ui.gd` | 任务提示 (标题 + 箭头 + 进度) |
| `dungeon_result_panel.gd` | 副本结算 (暗金琥珀) |
| `ui_scar_controller.gd` | 伤疤闪烁效果 |

### Resources (scripts/resources/)

| 文件 | 说明 |
|------|------|
| `boss_config.gd` | Boss 顶层配置, sato_default() 工厂 |
| `boss_phase_data.gd` | 单乐章参数 |
| `boss_attack_data.gd` | Boss 攻击数据 |
| `stat_modifier.gd` | 属性修改器 |
| `mission_chain.gd` | 任务链 |
| `mission_stage.gd` | 任务阶段 |
| `mission_objective.gd` | 任务目标 |
| `trigger_config.gd` | 触发器配置 |
| `prompt_config.gd` | 提示配置 |
| `enemy_config.gd` | 敌人配置 |
| `ai_enemy_config.gd` | AI 敌人配置 |
| `wave_config.gd` | 波次配置 |
| `dungeon_config.gd` | 副本参数 (3 Stage 数值) |

### 玩家技能 (scripts/skills/)

| 文件 | 说明 |
|------|------|
| `skill_base.gd` | 技能基类 (owner_unit + windup/recovery) |
| `skill_slash.gd` | 斩击 |
| `skill_multi_shot.gd` | 多重射击 |
| `skill_aoe.gd` | 范围攻击 |
| `skill_whirlwind.gd` | 旋风斩 |
| `skill_chain_lightning.gd` | 闪电链 |
| `skill_snipe.gd` | 狙击 |
| `skill_ice_nova.gd` | 冰霜新星 |
| `skill_fire_trail.gd` | 火焰轨迹 |
| `skill_shadow_clone.gd` | 影分身 |

### 持久化 (scripts/persistence/)

| 文件 | 说明 |
|------|------|
| `game_persistence.gd` | ConfigFile 持久化 (Boss 遭遇 + 死亡 + 伤疤) |

### VFX (scripts/vfx/)

| 文件 | 说明 |
|------|------|
| `vfx_utils.gd` | 粒子特效工具 |

### 场景 (scenes/)

| 文件 | 说明 |
|------|------|
| `main.tscn` | 主场景 |
| `player.tscn` | 玩家 |
| `enemy.tscn` | 敌人 |
| `student_minion.tscn` | Boss 学生小怪 |
| `player_projectile.tscn` | 玩家弹射物 |
| `enemy_projectile.tscn` | 敌人弹射物 |
| `destructible.tscn` | 可破坏物 |
| `damage_number.tscn` | 伤害数字 |
| `desk.tscn` | 课桌 |
| `wall.tscn` | 墙 |
| `boundary.tscn` | 边界 |
| `door.tscn` | 门 |
| `dialogue_panel.tscn` | 对话面板 |

---

## 六、未完成 / 待优化

### 6.1 编译修复
- `game_manager.gd:813` — `activation_range` 类型推断错误, 需 `as Enemy` 转换
- NavManager 部分场景下无法找到 TileMap (非致命警告)

### 6.2 Boss 系统待补全
- BossConfig.sato_default() 中的技能场景列表 (skill_scenes) 需填充实际 PackedScene 引用
- Boss 技能参数需逐个用实际数值补全 (damage/range/cooldown/windup)
- BossPhaseData 的 close_range_skill_slot / chase_distance_threshold / chase_patience / chase_speed 需调参
- Boss 登场序列 (entrance_reveal) 与沉默时刻的衔接流程验证

### 6.3 近战攻击模式
- enemy.gd 近战冲刺攻击状态机刚从 git 恢复重建
- 需验证 windup → lunge → retreat → cooldown 完整流程
- 冲刺命中检测 (distance < 20px) 可能需要配合实际碰撞体积调校

### 6.4 地图系统
- 地图位置偶有偏移 (player marker 与实际位置不精确对齐)
- 迷雾 grid 硬编码 5760x4320, cell 80px, 需与 school_map 实际尺寸匹配
- school_map.gd 和 tilemap_builder.gd 两套地图机制共存, 需要统一

### 6.5 Phase F (副本配置) — 待 C 完成后启动
- 副本数值曲线: HP/伤害/经验 随波次增长
- 完整文案集成: 陶德撰写的叙事文本嵌入代码
- 难度曲线: Stage 1→2→3 数值平稳过渡
- Boss 遭遇持久化: 多次战斗仪式感递减

### 6.6 其他
- AttackCoordinator 需要手动注册 Autoload (未在 project.godot 中, 用 uid:// 但未确认)
- `.uid` 文件覆盖不完全 (部分新脚本如 boss 技能可能缺 .uid)
- 音效系统: 目前无声, 哨声/脚步声/打击声待实装

---

## 七、团队分工 (29 人)

| 部门 | 成员 | 职责 |
|------|------|------|
| **程序 (9)** | 马斯克 (主程) | 整体架构 + 团队管理 |
| | 卡马克 (技术总监) | 代码审查 + 技术规范 |
| | 系统程序 | 框架/组件/持久化 |
| | 战斗程序 | CombatUnit/Boss/AI/Skill |
| | 关卡程序 | 地图/导航/碰撞 |
| | 罗梅罗 (关卡建筑师) | TileMap 区域设计 |
| | 肖 (AI) | 敌人行为/AI 框架 |
| | 阿克顿 (Gameplay) | 手感/反馈/CombatFeedback |
| | 赫克 (工具) | 编辑器工具/管线 |
| **美术 (4)** | 杨奇 (美术总监) | 整体美术方向 + 暗金琥珀色板 |
| | 新川洋司 (角色) | Boss 拼装/学生小怪/角色设计 |
| | Jen Zee (特效) | 粒子/光环/声波/坍塌动画 |
| | 上田文人 (UI) | 面板/HUD/结算/动效 |
| **策划 (9)** | 小岛秀夫 (制作人) | 整体体验/演出节奏/Boss 死亡管线 |
| | 陶德·霍华德 (制作人+文案) | 叙事/对话/世界观 |
| | 宫崎英高 (战斗策划) | 战斗系统/AI 机制/数值/Boss 设计 |
| | 系统策划 | 框架/任务链/触发 |
| | 数值策划 | HP/伤害/经验曲线 |
| | 叙事策划 | 台词/任务文本 |
| | 关卡策划 | 地图布局/区域设计 |
| | 交互策划 | UI/UX/面板流程 |
| | 主策划 | 进度管理/里程碑 |
| **QA (5)** | 库克 (主 QA) | 测试计划 + 品质标准 |
| | 系统 QA | 框架测试 |
| | 战斗 QA | 战斗手感测试 |
| | 数值 QA | 平衡性测试 |
| | 关卡 QA | 地图碰撞测试 |

---

## 八、设计文档索引

```
output/docs/
├── 统一战斗框架设计-V1.0.md
├── 怪物AI与技能设计-V1.0.md
├── Boss战体验设计-小岛秀夫.md
├── 战斗系统设计-宫崎英高.md
├── 战斗系统-最终实施计划.md
├── GAP-01-Boss战最终设计-合并版.md
├── GAP-01a-程序任务.md
├── GAP-01b-交互任务.md
├── GAP-01c-美术任务.md
├── GAP-02a-战斗系统-程序需求.md
├── GAP-02b-战斗系统-交互需求.md
├── GAP-02c-战斗系统-美术需求.md
├── GAP-02d-战斗系统-团队讨论纪要.md
├── GAP-02e-战斗系统-副本融合方案.md
├── 文案审核与补充-陶德.md
├── 任务触发系统设计-V1.0.md
├── 学校副本故事设计-陶德.md
├── 任务流程重构-小岛秀夫.md
├── Boss机制设计-宫崎英高-v2.md
├── 地图布局重设计-宫崎英高.md
├── 关卡视觉区域设计-罗梅罗.md
├── Boss强化与AI包围-宫崎英高.md
├── 技能特效设计-杨奇.md
├── 地图扩展方案-关卡.md
├── 像素风过渡方案-杨奇.md
├── 副本结算与校门-杨奇.md
├── Boss数值强化方案-宫崎英高.md
├── 地图迷雾系统设计-小岛宫崎.md
├── 地图迷雾技术调研.md
├── Boss战优化专项-小岛秀夫.md
├── AI优化专项-宫崎英高.md
├── 任务流程优化-陶德.md
├── 近战攻击模式-宫崎杨奇.md
├── 对话文案重写-陶德.md
├── 敌人布置方案-宫崎英高.md
├── 程序团队扩充方案.md
├── 美术团队扩充方案.md
├── 全功能测试计划-V1.0.md
├── 测试场景安排.md

output/reviews/
├── Tween生命周期规范-v1.0.md
├── UI交互动效方案-交互策划.md
├── UI动效升级方案-杨奇.md
├── QA测试报告-系统层.md
├── QA测试报告-交互层.md
├── 美术资源审核-杨奇.md
├── Boss战实施Review-小岛秀夫.md
├── Boss战紧急修复-小岛秀夫.md
├── 最终共识-交互策划回应.md
├── 最终共识-杨奇回应.md
├── Phase4评估-高管讨论.md
├── 全量代码审查-技术团队.md
├── 最终缺口评估-小岛秀夫.md
├── 高管紧急会议-流程修复.md
├── 引导地图怪物-跨团队方案.md
├── 地图方案-技术讨论.md
├── 迷雾与面板修复-高管决议.md
├── 高管复盘-经验教训.md
```

---

## 九、调试速查

- Godot 日志: `%APPDATA%\Godot\app_userdata\Combat Demo\logs\godot.log`
- 清除缓存: `rm -rf .godot/editor .godot/global_script_class_cache.cfg .godot/uid_cache.bin`
- 引擎: `D:\Godot_v4.6.2-stable_mono_win64`
- 项目: `D:\AI\GodotProjects\combat-demo\project.godot`
- 说 "check errors" 读日志
- 技术规范速查在 CLAUDE.md 底部 (Godot API 陷阱 / GDScript 语法 / Tween 规范 / 文件操作)
