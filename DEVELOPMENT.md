# Combat Demo — 开发状态速查

> 最后更新：2026-05-19 | 新会话第一件事：读此文档 + 读 CLAUDE.md

## 一句话状态

Phase A/B/D 已交付。Phase C (Boss战) + Phase E (美术) 正在后台 agent 运行。Phase F (副本融合) 等 C+E 完成后启动。目标：完整可玩的学校副本（叙事+任务+Boss战）。

---

## 立即行动（新会话打开后）

```
1. check errors — 读 Godot 日志看有没有编译错误
2. 注册 AttackCoordinator Autoload（见下方）
3. 清除脚本缓存
4. 在 Godot 中运行项目测试
```

### 手动步骤

**注册 AttackCoordinator Autoload：**
- Godot → Project Settings → Autoload
- 添加 `res://scripts/ai/attack_coordinator.gd`，名称 `AttackCoordinator`

**清除脚本缓存：**
```bash
rm -f "D:/AI/GodotProjects/combat-demo/.godot/global_script_class_cache.cfg"
```

---

## 架构全景

```
CombatUnit (extends CharacterBody2D)
├── StatsComponent — (base+flat)*(1+sum%)*(product)
├── BuffComponent — StatModifier 叠加
├── SkillComponent (改造自 SkillManager)
├── Player extends CombatUnit — PlayerController (WASD输入)
└── Enemy extends CombatUnit — AIController (状态机)
    ├── AIBehaviorController — 9状态
    ├── EnemyVisualStateMachine — 颜色区分状态
    ├── AttackCoordinator (Autoload) — 同帧攻击≤3
    └── EnemyVisualFactory — ColorRect 拼装

Boss = Enemy + BossPhaseController + BossAI(四乐章) + BossVisual + BossHpBar
```

---

## 已完成功能

### 核心架构
- ✅ CombatUnit 基类 (team/HP/stats/death/knockback)
- ✅ StatsComponent / BuffComponent / StatModifier Resource
- ✅ BossAttackData Resource
- ✅ SkillBase 改造 (owner_unit + target_node + windup/recovery 协程)
- ✅ Player extends CombatUnit
- ✅ Enemy extends CombatUnit
- ✅ EventBus Boss 信号 (boss_phase_changed/boss_attack_started/boss_defeated)

### AI 系统
- ✅ AIBehaviorController (9 行为模式, enum+switch)
- ✅ EnemyVisualStateMachine (NORMAL/WINDUP/BERSERK/STUNNED/DEAD 等 9 状态)
- ✅ 攻击前摇系统 (≥0.35s, 方向锁定, 橙黄变色)
- ✅ AttackCoordinator (同帧攻击≤3, 优先级排序)
- ✅ EnemyVisualFactory (竖=近战/横=远程/大=精英)
- ✅ 敌人墙壁滑动

### Boss UI
- ✅ 沉默时刻 (HUD 5层 stagger 消退/恢复, 0.25s 间隔)
- ✅ Boss 血条 (顶部居中, 三条阶段标记线, 0.3s 平滑)
- ✅ "下课"胜利文字 ("体育老师 · 佐藤 —— 下课")
- ✅ Vignette 暗角 (四状态: NORMAL/APPROACH/BATTLE/DEFEAT)
- ✅ Boss 战后升级面板 ("佐藤的馈赠")

### UI 动效 (Phase 1-3)
- ✅ PanelManager 状态机 + 淡入淡出
- ✅ UIEffects 静态工具类 + Tween 注册表
- ✅ 按钮 hover (scale 1.05)
- ✅ 击杀/波次数字弹跳 (仪式感递减)
- ✅ 升级面板 stagger (0.06s)
- ✅ 打字机效果 (0.02s/字)
- ✅ GameOver 序列 (死亡5次后加速)
- ✅ 低血量警告 (径向红幕)
- ✅ 尖叫时刻 A (第四选项, 5% 概率)
- ✅ CharSelect 入场两层节奏
- ✅ "踏入试炼"过渡

### 关卡
- ✅ TileMap 墙壁碰撞 (physics layer 4)
- ✅ 教室课桌 (65个/教室)
- ✅ 地图面板 (运行时生成俯视图)
- ✅ 任务触发系统 (6种Trigger + MissionPromptUI)
- ✅ 对话系统 (滑入滑出+翻页过渡+说话人颜色)

---

## 进行中（后台 agent）

| Phase | 负责人 | 内容 |
|------|--------|------|
| **C** | 战斗程序 | BossPhaseController + 四乐章AI + 13攻击 + 学生小怪 |
| **E** | 杨奇 | Boss 拼装 + 攻击动画 + 光环 + 坍塌 + 声波 |

---

## 待做

| Phase | 内容 | 前置 |
|------|------|------|
| **F** | 副本配置 + 数值 + 完整文案 + 难度曲线 | C+E |
| 陶德文案集成 | Boss 战完整叙事文本嵌入代码 | F |
| 数值平衡 | HP/伤害/经验曲线 | F |
| Boss 遭遇持久化 | 多次战斗仪式感递减 | F |

---

## 关键文件索引

### 新增核心文件
```
scripts/
├── combat_unit.gd                 # 统一战斗基类
├── components/
│   ├── stats_component.gd         # 属性公式
│   └── buff_component.gd          # Buff管理
├── ai/
│   ├── ai_behavior_controller.gd  # AI行为状态机
│   ├── visual_state_machine.gd    # 视觉状态机
│   ├── attack_coordinator.gd      # 攻击协调器(Autoload)
│   └── enemy_visual_factory.gd    # ColorRect拼装工厂
├── ui/
│   ├── ui_effects.gd              # Tween工具类
│   ├── panel_manager.gd           # 面板状态机
│   ├── silence_controller.gd      # 沉默时刻
│   ├── boss_hp_bar.gd             # Boss血条
│   ├── victory_text_ui.gd         # 胜利文字
│   ├── vignette_controller.gd     # 暗角控制
│   ├── dialogue_panel.gd          # 对话(打字机+滑入)
│   ├── char_select_ui.gd          # 角色选择
│   ├── upgrade_ui.gd              # 升级面板
│   └── mission_prompt_ui.gd       # 任务提示
├── resources/
│   ├── stat_modifier.gd           # 属性修改器
│   └── boss_attack_data.gd        # Boss攻击数据
├── mission_trigger_manager.gd     # 任务触发器引擎
└── skills/                        # 9个技能(已改造支持owner_unit)
```

### 设计文档
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
├── 美术团队扩充方案.md
└── 程序团队扩充方案.md

output/reviews/
├── Tween生命周期规范-v1.0.md
├── UI交互动效方案-交互策划.md
├── UI动效升级方案-杨奇.md
├── QA测试报告-系统层.md
├── QA测试报告-交互层.md
├── 美术资源审核-杨奇.md
└── 最终共识-*.md
```

---

## 团队 29 人

**程序 (9)**: 马斯克/卡马克/系统程序/战斗程序/关卡程序/罗梅罗/肖(AI)/阿克顿(Gameplay)/赫克(工具)
**美术 (4)**: 杨奇/新川洋司(角色)/Jen Zee(特效)/上田文人(UI)
**策划 (9)**: 系统/数值/叙事/关卡/交互/宫崎英高(战斗)/主策划/小岛秀夫(制作人)/陶德(制作人+文案总监)
**QA (5)**: 库克(主QA)/系统QA/战斗QA/数值QA/关卡QA

---

## 调试

- Godot 日志: `%APPDATA%\Godot\app_userdata\Combat Demo\logs\godot.log`
- 引擎: `D:\Godot_v4.6.2-stable_mono_win64`
- 项目: `D:\AI\GodotProjects\combat-demo\project.godot`
- 说 "check errors" 读日志
- 技术规范速查在 CLAUDE.md 底部
