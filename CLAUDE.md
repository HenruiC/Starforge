# Combat Demo — Starforge 幸存者Like战斗原型

Godot 4.6.2 mono 项目。学校副本俯视角割草战斗Demo。
引擎路径：`D:\Godot_v4.6.2-stable_mono_win64`
项目路径：`D:\AI\GodotProjects\combat-demo`

## 当前状态（2026-05-20）

### 编译
- 清缓存后重启 Godot 验证
- `rm -rf .godot/editor .godot/global_script_class_cache.cfg .godot/uid_cache.bin`

### 已完成架构
- **CombatUnit** 统一基类 (Player/Enemy extends)
- **5 Stage 任务链**：校门→教室→驻守走廊→体育馆→下课铃
- **NavigationAgent2D** 寻路 + **冲刺攻击**状态机（近战猛冲回退）
- **Boss**：BossConfig Resource + BossDeathSequence 通用管线 + 四阶段
- **面板队列**：panel_manager 优先级（对话>升级>地图>结算）
- **世界雾**：TileMap layer2 黑层 z=50
- **LockedDoor** 门系统：击败精英→completion_action→解锁
- **结算**：校门打开→SABC评分→奖励槽
- **DEFEND_ZONE**：全图敌人冲向防御区

### 关键文件
- `scripts/enemy.gd` — 近战冲刺/Boss/远程/闪避/狂暴（~260行，刚重建）
- `scripts/game_manager.gd` — 1771行，所有流程
- `scripts/school_map.gd` — 616行，5760×4320地图
- `scripts/boss/boss_ai.gd` — Boss AI
- `scripts/resources/boss_config.gd` — BossConfig Resource
- `scripts/resources/ai_enemy_config.gd` — AI配置
- `scripts/locked_door.gd` — 门系统
- `scripts/ui/panel_manager.gd` — 面板优先级队列
- `scripts/ui/boss_death_sequence.gd` — Boss死亡管线
- `scripts/ui/dungeon_result_panel.gd` — 结算面板
- `scripts/mission_trigger_manager.gd` — 任务触发器引擎（8种类型）
- `scripts/mission_manager.gd` — 5 Stage学校副本

### 新增 class_name（需缓存刷新）
BossConfig, AIEnemyConfig, LockedDoor, BossDeathSequence, DungeonResultPanel, VFXUtils, BossPhaseController, BossAI, EnemyVisualStateMachine, AIBehaviorController, AttackCoordinator

### 调试
- 日志: `%APPDATA%\Godot\app_userdata\Combat Demo\logs\godot.log`
- 说 "check errors" 读日志
- 技术手册在 CLAUDE.md 底部（GDScript规范速查）

### 待优化
- Boss四阶段参数补全（bullet_count/spread对WhistleWave生效）
- 地图位置偶有偏移
- enemy.gd 今早从git恢复重写，需验证所有功能
