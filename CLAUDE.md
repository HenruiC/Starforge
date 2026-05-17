# Combat Demo — Starforge 幸存者Like战斗原型

Godot 4.6 项目。俯视角割草战斗Demo。

## 操作
- **WASD** 移动
- **自动攻击** 范围内最近的敌人
- **W** 键重新开始（死亡后）

## 项目结构
```
scenes/
├── main.tscn      # 主场景（GameManager + 玩家 + UI + 相机）
├── player.tscn    # 玩家（蓝色方块，WASD移动，自动攻击）
└── enemy.tscn     # 敌人（红色方块，追踪玩家，接触伤害）

scripts/
├── game_manager.gd    # 波次管理、敌人出生、UI控制
├── player.gd          # 玩家移动 + 自动索敌攻击
├── enemy.gd           # 敌人AI + 受伤/死亡
├── event_bus.gd       # 全局事件总线（Autoload）
└── camera_controller.gd # 平滑跟随相机
```

## 系统设计
- 波次系统：每30秒一波，难度递增
- 自动索敌：检测攻击范围内的敌人，自动攻击最近目标
- 敌人出生：从屏幕边缘随机出生
- 伤害系统：接触伤害 + 攻击冷却 + 死亡事件

## 运行
用 Godot 4.6 编辑器打开 `project.godot`。
引擎路径：`D:\Godot_v4.6.2-stable_mono_win64`
