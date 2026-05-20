# 敌人 AI 全面优化专项设计

> 宫崎英高, 战斗策划, Starforge 工作室
> 2026-05-20
>
> 专项范围：教室出口 / 导航烘焙 / 狂暴系统 / 通用 AI 配置
> 关联文档：`战斗系统设计-宫崎英高.md` / `怪物AI与技能设计-V1.0.md` / `Boss强化与AI包围-宫崎英高.md`

---

## 设计铁则：通用性 > 副本特化

本方案所有系统必须满足以下硬性约束。**审核时以此表格为准，不满足则打回重做。**

| 系统 | 通用性要求 | 验证方式 |
|------|-----------|----------|
| **狂暴系统** | 任何 `Enemy` 子类挂上就能用，不依赖 `is_boss`/`is_elite`/学校副本特有逻辑 | 创建全新敌人类型，仅设置 `ai_config.berserk_enabled = true`，受伤即触发 |
| **AI 参数** | 完全由 `AIEnemyConfig` Resource 驱动，`enemy.gd` 中零硬编码行为参数 | 在编辑器中创建新 `.tres`，修改任意字段，拖给 Enemy 节点，行为即时生效 |
| **导航烘焙** | 适配任意 `TileMap` 布局，不 hardcode 坐标/尺寸/墙壁 source ID | 新建空场景，用不同 TileSet 搭地图，NavManager 自动解析并烘焙 |
| **行为模式** | 新副本新增敌人行为（如"潜行刺杀型"）只需新建配置，不改 `AIBehaviorController` 代码 | 创建 `ai_cfg_stealth.tres` 设置 `initial_behavior = AMBUSH`，无需改任何 .gd 文件 |
| **跨副本复用** | 学校副本的 AI 配置 .tres 可直接拖到"地牢副本"的敌人上使用 | 复制 `ai_cfg_melee_basic.tres` 到新副本目录，无需修改 |

**唯一例外**：第 1 节"教室出口"是为学校副本的 `school_map.gd` 做的**地图设计修复**——给建筑开多个门洞。这不是 AI 系统，是关卡设计补丁。后续副本的地图设计参照此模式即可，不需要代码改动。

---

## 0. 现状诊断 — 代码级根因分析

以下每个问题都有对应的代码根因和精确行号，不是猜测。

### 0.1 "AI 太傻" 的根因

**文件**: `scripts/enemy.gd` L194-L232

```gdscript
# enemy.gd:214 — 近战行为就是直线追，没有前摇/硬直/攻击协调
func _melee_behavior(delta: float) -> void:
    var direction := global_position.direction_to(_player_ref.global_position)
    velocity = direction * move_speed
    move_and_slide()
```

问题链：
1. 敌人没有攻击前摇——碰到玩家就造成伤害 (`contact_area`)
2. 敌人没有攻击硬直——可以一边挨打一边追击
3. `NavigationAgent2D` 已声明但从未创建（L39: `var _nav_agent: NavigationAgent2D = null`）
4. `AIBehaviorController` 已实现（`scripts/ai/ai_behavior_controller.gd`）但 Enemy 的 `_physics_process()` 直接调用 `_melee_behavior()` / `_ranged_behavior()`，**绕过了行为控制器**

### 0.2 "教室没出口" 的根因

**文件**: `scripts/school_map.gd` L262-L267, `_building()` 函数

```gdscript
# school_map.gd:263-267 — 只开南墙门洞
@warning_ignore("integer_division")
var mx := x + bw / 2
for dx in range(-2, 3):
    _tm.erase_cell(1, Vector2i(mx + dx, y + bh - 1))
    _tm.set_cell(1, Vector2i(mx + dx, y + bh - 1), door_sid, Vector2i(0, 0))
```

**只有 `y + bh - 1`（南墙）被打开**。北墙 `y`、东墙 `x + bw - 1`、西墙 `x` 都没有开口。

左教学楼 (bx=14, by=54, lw=26, lh=22) 和右教学楼 (rx=68, by=54, lw=26, lh=22) 的预置敌人在 `get_preplaced_enemies()` 中生成在教室内部 (y=58..75 tile)，这些敌人出来后只有南面一个出口。如果玩家在南面，敌人确实能出来。但敌人向南追玩家后如果被卡在墙壁拐角，**无法从北面绕出来**。

### 0.3 "路网未利用" 的根因

**文件**: `scripts/nav_manager.gd` L13-L36

```gdscript
# nav_manager.gd:18-23 — 导航多边形是一个大矩形，没有排除墙壁
var nav_poly := NavigationPolygon.new()
var outline := PackedVector2Array([
    Vector2(48, 48), Vector2(3152, 48),
    Vector2(3152, 2352), Vector2(48, 2352)
])
nav_poly.add_outline(outline)
```

虽然调用了 `_nav_region.bake_navigation_polygon()`，但烘焙需要 `StaticBody2D` 子节点作为障碍物。当前 TileMap 的墙壁碰撞直接设置在 TileSet 的 physics layer 上（`school_map.gd` L70-L72），**没有对应的 StaticBody2D 节点**，所以 NavigationServer2D 的烘焙无法识别这些墙壁。

同时 `enemy.gd` 中 `_nav_agent` 声明了但从未赋值（L39: `var _nav_agent: NavigationAgent2D = null`），既没有 `NavigationAgent2D.new()` 也没有 `add_child()`。

### 0.4 "AI 不够疯" 的根因

没有任何狂暴/激怒机制。`enemy.gd` 的 `take_damage()` (L569-L593) 只做了伤害数字和受击闪白。`AIBehaviorController` (L149-L151) 在 windup/recovery 期间阻塞了行为转换评估。

好消息：`EnemyVisualStateMachine` (`scripts/ai/visual_state_machine.gd`) 已经定义了 `BERSERK` 状态（红色 + alpha 脉冲 + 光环放大），`StatsComponent` (`scripts/components/stats_component.gd`) 有完整的修改器系统——两者可以直接复用。

---

## 1. 教室出口 — 多方向开口方案

> **注意**：本节是学校副本专属的地图设计修复。不是 AI 系统，不要求跨副本通用。
> 但 `_building()` 增加开口参数的**机制**是通用的——后续副本的建筑类函数可复用同一套"多方向开口"参数。

### 1.1 改造目标

左教学楼和右教学楼各需要 **3 个出口**：

| 出口位置 | 坐标（tile） | 开口宽度 | 用途 |
|----------|-------------|:-------:|------|
| 南门（已有） | 左: x=25..29, y=75 / 右: x=79..83, y=75 | 5 tiles | 敌人向南追击 |
| 北门（新增） | 左: x=25..29, y=54 / 右: x=79..83, y=54 | 5 tiles | 敌人向北绕出 |
| 侧门-连廊（新增） | 左: x=39, y=63..66 / 右: x=68, y=63..66 | 4 tiles | 敌人进入连廊区域 |

北门让敌人被引诱到教室后方后能从北侧绕回；侧门直接连通连廊（x=39..69, y=63..67），让教室内敌人能快速进入横向通道参与战斗。

### 1.2 地图坐标验证

```
地图尺寸: 5760 x 4320 px, tile=48px, 120 x 90 tiles

左教学楼: bx=14, by=54, bw=26, lh=22
  - 北墙: y=54, x=14..39    → 北门中心 tile(27, 54)
  - 南墙: y=75, x=14..39    → 南门中心 tile(27, 75)
  - 东墙: x=39, y=54..75    → 侧门 tile(39, 64..66)

右教学楼: rx=68, by=54, bw=26, lh=22
  - 北墙: y=54, x=68..93    → 北门中心 tile(81, 54)
  - 南墙: y=75, x=68..93    → 南门中心 tile(81, 75)
  - 西墙: x=68, y=54..75    → 侧门 tile(68, 64..66)

连廊: x=39..69, y=63..67    → 走廊地板 source 2
  - 侧门开在 y=63..66 正好对齐连廊 (y=63..67)
```

### 1.3 具体实现

**文件**: `scripts/school_map.gd`
**位置**: `_building()` 函数，在南墙门洞代码 (L262-L267) 之后追加以下逻辑。

```
改造方案: 给 _building() 增加两个参数: open_north: bool = false, open_side: bool = false

然后在调用处:
- _building(bx, by, lw, lh, 5, 7, "左楼", 1, 5, true, true)    # 左楼: 开北门+侧门
- _building(rx, by, lw, lh, 8, 7, "右楼", 1, 8, true, true)    # 右楼: 开北门+侧门
- _building(gx-12, gy, 24, 18, 6, 0, "", 3, 6)                  # 体育馆: 不需要额外开口
```

**伪代码**（在现有南墙门洞代码之后追加）:

```gdscript
# 北墙门洞 — 与南墙对称，开在 mx 位置
if open_north:
    for dx in range(-2, 3):
        _tm.erase_cell(1, Vector2i(mx + dx, y))
        _tm.set_cell(1, Vector2i(mx + dx, y), door_sid, Vector2i(0, 0))
    # 北门外铺走廊地板 (4 tiles 深)，确保敌人出来后有导航区域
    for dy in range(1, 5):
        for dx in range(-3, 4):
            var tx := mx + dx
            var ty := y - dy
            if tx >= 0 and tx < cols and ty >= 0:
                _tm.set_cell(0, Vector2i(tx, ty), 2, Vector2i(0, 0))  # 走廊地板

# 侧门 — 面向连廊的开口
if open_side:
    var side_x: int       # 开门的那面墙的 x 坐标
    var side_door_range   # y 范围
    if x < 60:            # 左楼 → 东墙开门
        side_x = x + bw - 1   # 39
        side_door_range = range(y + 9, y + 13)  # y=63..66
    else:                 # 右楼 → 西墙开门
        side_x = x             # 68
        side_door_range = range(y + 9, y + 13)  # y=63..66
    
    for dy in side_door_range:
        _tm.erase_cell(1, Vector2i(side_x, dy))
        _tm.set_cell(1, Vector2i(side_x, dy), door_sid, Vector2i(0, 0))
```

### 1.4 出口开口对敌人生成位置的影响

当前教室内的预置敌人（`get_preplaced_enemies()`, L438-L493）坐标完全在建筑内部。开口后：
- 敌人可以从北门绕到教学楼北侧
- 敌人可以从侧门直接进入连廊（走廊），再向南北方向移动
- 不再被困在单出口的"死胡同"里

开口后不需要调整敌人生成位置——它们仍然从教室内部出生，但行为上有了更多路径选择。

---

## 2. 导航烘焙 — NavigationServer2D 方案

### 2.1 当前状态

| 组件 | 状态 | 问题 |
|------|:----:|------|
| NavManager / NavigationRegion2D | 已创建 | 烘焙多边形是大矩形，不排除墙壁 |
| TileMap 墙壁碰撞 | 已配置 (physics layer 0, collision layer 8) | 碰撞在 TileSet 级别，NavigationServer2D 烘焙不识别 |
| Enemy NavigationAgent2D | 已声明未初始化 | `var _nav_agent: NavigationAgent2D = null` 从未赋值 |

### 2.2 烘焙方案：从 TileMap 通用烘焙

> **通用性保证**：以下方案不依赖 school_map 的任何硬编码数据。NavManager 通过扫描整个 TileMap 的 collision layer 来自动识别墙壁，适用于任意 TileSet/地图布局。

Godot 4.6 的 `NavigationServer2D` 支持 `source_geometry_group_name` 和 `NavigationMeshSourceGeometryData2D`。最干净的方案是利用 TileMap 的 physics layer 数据直接烘焙，**不依赖具体 source ID 或坐标**。

**方案 A（推荐）：NavigationServer2D 接口烘焙**

核心思路：让 `bake_navigation_polygon()` 在烘焙时解析 TileMap 的 physics layer 碰撞数据。NavManager **不关心墙壁是什么 source ID**——只关心哪些 tile 有碰撞。

```
实现步骤:
1. NavManager 通过 SceneTree 查找场景中的 TileMap 节点（不硬编码路径）
2. 利用 NavigationServer2D 解析 TileMap 所有 physics layer
3. 以地图总尺寸为 navigation polygon 轮廓
4. 调用 bake_navigation_polygon()，自动排除所有有碰撞的 tile
5. 将导航地图 RID 暴露给所有 NavigationAgent2D
```

具体代码改动（`nav_manager.gd` 重写为通用版）:

```gdscript
# NavManager — 通用导航管理器（不依赖任何特定地图）
class_name NavManager
extends Node2D

const MW := 5760  # 地图总宽（可通过 export 覆盖）
const MH := 4320  # 地图总高（可通过 export 覆盖）

## 目标 TileMap 节点路径（相对于 NavManager 的父节点）
@export var tilemap_path: NodePath = NodePath("../TileMap")

var _nav_region: NavigationRegion2D
var _tile_map: TileMap = null
var _baked: bool = false

func _ready() -> void:
    _setup_navigation()

func _setup_navigation() -> void:
    # 通用查找 TileMap — 按传入的 NodePath，找不到则遍历场景
    if tilemap_path and has_node(tilemap_path):
        _tile_map = get_node(tilemap_path) as TileMap
    else:
        # 自动搜索：遍历父节点 children 找第一个 TileMap
        var parent := get_parent()
        if parent:
            for child in parent.get_children():
                if child is TileMap:
                    _tile_map = child
                    break

    if not _tile_map:
        push_warning("NavManager: 未找到 TileMap，导航将退化为全矩形")
    
    _nav_region = NavigationRegion2D.new()
    _nav_region.name = "NavRegion"
    
    var nav_poly := NavigationPolygon.new()
    var outline := PackedVector2Array([
        Vector2(0, 0), Vector2(MW, 0),
        Vector2(MW, MH), Vector2(0, MH)
    ])
    nav_poly.add_outline(outline)
    
    # 关键：告诉 Godot 在烘焙时解析场景中的静态碰撞体
    # PARSED_GEOMETRY_STATIC_COLLIDERS 会识别所有 StaticBody2D 和 TileMap physics layer
    nav_poly.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
    # 设置解析的碰撞层掩码 — 匹配 TileMap 中设置的 collision_layer
    nav_poly.parsed_collision_mask = 0xFFFF  # 解析所有层的碰撞
    
    _nav_region.navigation_polygon = nav_poly
    add_child(_nav_region)
    
    # 等物理体加载完成后烘焙
    await get_tree().create_timer(0.5).timeout
    call_deferred("_bake_nav")

func _bake_nav() -> void:
    await get_tree().process_frame
    if _nav_region:
        _nav_region.bake_navigation_polygon()
        _baked = true
        print("NavManager: 导航烘焙完成, 区域=%s" % _nav_region.navigation_polygon.get_vertices().size())
```

**方案 B（备选）：通用 StaticBody2D 障碍物生成器**

如果方案 A 的 `parsed_collision_mask` 在特定 Godot 版本中不工作，提供通用 fallback —— **遍历 TileMap 所有 tile 自动生成 StaticBody2D，不依赖特定 source ID**：

```gdscript
# NavManager — 通用 StaticBody2D 墙障碍物生成
func _build_wall_obstacles_generic() -> void:
    ## 通用方法：扫描 TileMap 所有 layer 的所有 cell，
    ## 任何有碰撞的 cell 都参与障碍物构建。
    ## 不依赖 source ID，不依赖坐标硬编码。
    
    if not _tile_map: return
    var tile_set := _tile_map.tile_set
    if not tile_set: return
    
    # 获取 TileMap 实际使用的 tile 范围（动态计算，不硬编码）
    var used_rect := _tile_map.get_used_rect()
    var cells: Array[Vector2i] = []
    
    # 遍历所有 layer
    for layer_idx in _tile_map.get_layers_count():
        for x in range(used_rect.position.x, used_rect.position.x + used_rect.size.x):
            for y in range(used_rect.position.y, used_rect.position.y + used_rect.size.y):
                var cell := Vector2i(x, y)
                var source_id := _tile_map.get_cell_source_id(layer_idx, cell)
                if source_id < 0: continue
                
                # 检查该 tile 是否有碰撞（通用方法：读取 physics layer）
                var has_collision := false
                var source := tile_set.get_source(source_id)
                if source is TileSetAtlasSource:
                    var atlas_coords := _tile_map.get_cell_atlas_coords(layer_idx, cell)
                    for phys_layer in tile_set.get_physics_layers_count():
                        var tile_data := source.get_tile_data(atlas_coords, phys_layer)
                        if tile_data and tile_data.get_collision_polygons_count(phys_layer) > 0:
                            has_collision = true
                            break
                
                if has_collision:
                    cells.append(cell)
    
    # 对 tiles 做连通域分析，每段连续墙生成一个 StaticBody2D + CollisionPolygon2D
    _create_obstacle_bodies(cells, _tile_map.tile_set.tile_size)

func _create_obstacle_bodies(tiles: Array[Vector2i], tile_size: Vector2i) -> void:
    ## 将 tile 列表分组合并为矩形 StaticBody2D 障碍物
    if tiles.is_empty(): return
    
    var visited: Dictionary = {}
    for tile in tiles:
        var key := "%d,%d" % [tile.x, tile.y]
        if key in visited: continue
        
        # BFS 找连通区域
        var region: Array[Vector2i] = []
        var queue: Array[Vector2i] = [tile]
        while not queue.is_empty():
            var t := queue.pop_front()
            var tk := "%d,%d" % [t.x, t.y]
            if tk in visited: continue
            visited[tk] = true
            region.append(t)
            for off in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
                var neighbor := t + off
                if neighbor in tiles:
                    var nk := "%d,%d" % [neighbor.x, neighbor.y]
                    if nk not in visited:
                        queue.append(neighbor)
        
        if region.size() > 0:
            var body := StaticBody2D.new()
            body.collision_layer = 1
            body.collision_mask = 0
            var collision := CollisionPolygon2D.new()
            # 用 region tile 的包围盒作为碰撞多边形
            var min_x := 1e9; var min_y := 1e9
            var max_x := -1e9; var max_y := -1e9
            for t in region:
                min_x = minf(min_x, t.x * tile_size.x)
                min_y = minf(min_y, t.y * tile_size.y)
                max_x = maxf(max_x, (t.x + 1) * tile_size.x)
                max_y = maxf(max_y, (t.y + 1) * tile_size.y)
            collision.polygon = PackedVector2Array([
                Vector2(min_x, min_y), Vector2(max_x, min_y),
                Vector2(max_x, max_y), Vector2(min_x, max_y),
            ])
            body.add_child(collision)
            _nav_region.add_child(body)

### 2.3 Enemy 接入 NavigationAgent2D

**文件**: `scripts/enemy.gd`

在 `_ready()` 中创建 NavigationAgent2D 并注册到 NavManager:

```gdscript
# enemy.gd — _ready() 中新增
func _setup_navigation_agent() -> void:
    _nav_agent = NavigationAgent2D.new()
    _nav_agent.name = "NavAgent"
    _nav_agent.path_desired_distance = 8.0
    _nav_agent.target_desired_distance = 24.0
    _nav_agent.radius = 10.0
    add_child(_nav_agent)
    
    # 注册到 NavManager
    var nav_mgr := get_node_or_null("/root/Game/World/SchoolMap/NavManager")
    if not nav_mgr:
        nav_mgr = get_node_or_null("/root/Game/NavManager")
    if nav_mgr and nav_mgr.has_method("register_agent"):
        nav_mgr.register_agent(_nav_agent)

# NavManager 新增
func register_agent(agent: NavigationAgent2D) -> void:
    agent.navigation_finished.connect(_on_agent_navigation_finished.bind(agent))

func get_next_path_position(agent: NavigationAgent2D) -> Vector2:
    if agent.is_navigation_finished():
        return Vector2.ZERO
    return agent.get_next_path_position()
```

然后在 `_melee_behavior()` 中将 `direction_to(player)` 改为基于 NavAgent 的路径追踪:

```gdscript
func _melee_behavior(delta: float) -> void:
    if not _player_ref: return
    
    var speed := move_speed
    if _is_berserk:
        speed *= _berserk_speed_mult
    
    if _nav_agent and is_instance_valid(_nav_agent):
        # 基于导航路径追踪
        _nav_agent.target_position = _player_ref.global_position
        var next_pos := _nav_agent.get_next_path_position()
        if next_pos != Vector2.ZERO:
            var dir := global_position.direction_to(next_pos)
            velocity = dir * speed
        else:
            # 已到达或导航不可用，直线追
            var dir := global_position.direction_to(_player_ref.global_position)
            velocity = dir * speed
    else:
        # fallback: 直线追踪 + move_and_slide 墙壁滑动
        var direction := global_position.direction_to(_player_ref.global_position)
        velocity = direction * speed
    
    move_and_slide()
```

### 2.4 性能优化

| 条件 | 路径更新频率 | 说明 |
|------|:----------:|------|
| 距离玩家 < 400px | 每 3 帧 (~0.05s) | 近距离需要精确导航 |
| 距离玩家 400-800px | 每 10 帧 (~0.17s) | 中距离降频 |
| 距离玩家 > 800px | 每 30 帧 (~0.5s) | 远距离几乎不需要更新 |
| 玩家不在索敌范围内 | 不更新 | 闲置敌人不消耗导航 |

在 `AIBehaviorController._process()` 中通过 `_path_timer` 控制。

### 2.5 墙壁烘焙验证标准

烘焙完成后用以下方法验证：
1. 在编辑器中打开 NavigationRegion2D 的 debug 可视化
2. 确认教室内部、走廊、操场全部是可行走区域（蓝色）
3. 确认所有墙壁 tile（source 4/5/6/8）被排除在导航区域外
4. 确认门洞（source 7）是可通行的
5. 在运行时让一个敌人用 NavigationAgent2D 从教室内部追玩家到操场——路径应自动绕开墙壁

---

## 3. AI 狂暴系统 — BERSERK 状态机设计

### 3.0 通用性声明

狂暴系统通过三个现有组件接入，**不依赖敌人类型、不依赖副本、不 hardcode 任何数值**:

| 接入点 | 机制 | 通用性 |
|--------|------|:---:|
| `StatsComponent` | `add_modifier(berserk_mod)` 修改 move_speed / cooldown | 任何拥有 StatsComponent 的 CombatUnit 自动生效 |
| `EnemyVisualStateMachine` | `push_state(BERSERK)` 驱动颜色+脉冲+微震 | 任何挂载了 VisualStateMachine 的 Node 自动生效 |
| `AttackCoordinator` | `cancel_attack()` + `ignore_coordinator` 标志 | 全局单例，所有 Enemy 共用同一套排队逻辑 |

**所以**：新副本定义新敌人类型时，只要 Enemy 节点挂载了 `StatsComponent` 和 `EnemyVisualStateMachine`（这是 `CombatUnit` 的标准子节点），狂暴系统零代码接入。差异只在 `AIEnemyConfig` 配置文件的 `berserk_*` 字段。

如果某个副本有**完全不同的视觉风格**（如地牢副本的敌人狂暴后变紫而不是变红），只需新建一个 `EnemyVisualStateMachine` 子类覆盖 `BERSERK` 状态的颜色常量，不改任何逻辑代码。

### 3.1 设计目标

敌人不是永远冷静的机器。受到伤害后，它们应该"发疯"——这是战斗叙事的需要，也是难度曲线的需要。

### 3.2 状态机扩展

在当前 `AIBehaviorController` 的 9 个状态之上，**BERSERK 不是一个独立的状态，而是一个叠加的修正器**。它叠加在 CHASE / KITE 等基础行为之上，临时修改移动速度和攻击节奏。

```
                 ┌─────────────────────────┐
                 │    正常行为状态机        │
                 │  (CHASE/KITE/GUARD...)  │
                 └───────────┬─────────────┘
                             │
              take_damage 触发
                             │
                             v
                 ┌─────────────────────────┐
                 │     BERSERK 修正器       │  ← 叠加层
                 │  - move_speed × 1.5     │
                 │  - 攻击间隔 × 0.5       │
                 │  - 忽略群组协调         │
                 │  - 视觉: 红色+微震      │
                 │  - 持续 4.0s (可配置)   │
                 └───────────┬─────────────┘
                             │
              持续时间结束 / 死亡
                             │
                             v
                      恢复正常行为
```

### 3.3 实现架构

利用现有系统，最小化新增代码：

```
Enemy.take_damage()
  └→ _check_berserk_trigger()
       ├→ StatsComponent.add_modifier(berserk_mod)   # 移速×1.5, 攻击冷却×0.5
       ├→ EnemyVisualStateMachine.push_state(BERSERK)  # 红色+脉冲+光环放大
       ├→ ignore_coordinator = true                   # 跳过 AttackCoordinator
       ├→ start 4.0s timer → _on_berserk_expired()
       └→ if is_elite / is_boss: _enrage_nearby_minions()
```

### 3.4 详细实现

#### 3.4.1 Enemy 新增字段

**文件**: `scripts/enemy.gd`，在 `var` 声明区新增：

```gdscript
# 狂暴系统
var _is_berserk: bool = false
var _berserk_timer: float = 0.0
var _berserk_duration: float = 4.0  # 默认 4 秒，由 AIEnemyConfig 覆盖
var _berserk_speed_mult: float = 1.5
var _berserk_cooldown_mult: float = 0.5  # 攻击间隔乘以 0.5 = 两倍速
var _ignore_coordinator: bool = false  # 狂暴期间无视 AttackCoordinator
```

#### 3.4.2 take_damage 中触发

**文件**: `scripts/enemy.gd`
**位置**: `take_damage()` 函数 (L569-L593)，在伤害处理后、死亡检查前插入:

```gdscript
func take_damage(amount: int, source: CombatUnit = null) -> void:
    if is_dead: return
    if _is_invincible or modulate.a < 0.5: return
    
    # ... 现有的护盾/伤害计算 ...
    _health = max(_health - actual, 0)
    _update_hp()
    
    # ---- 狂暴系统触发 ----
    _check_berserk_trigger()
    
    # ... 现有的伤害数字/视觉 ...
    
    if _health <= 0:
        _die()

func _check_berserk_trigger() -> void:
    # 死亡不触发狂暴
    if is_dead: return
    # Boss 的狂暴由阶段控制，不由受伤触发
    # （Boss Phase 4 本身已经是狂暴态）
    
    # 已经在狂暴中 → 刷新计时
    if _is_berserk:
        _berserk_timer = 0.0
        return
    
    # 触发条件: 受到任意伤害
    # 后续可通过 AIEnemyConfig 配置触发阈值
    _enter_berserk()

func _enter_berserk() -> void:
    _is_berserk = true
    _berserk_timer = 0.0
    _ignore_coordinator = true
    
    # 1. 属性修改 — 通过 StatsComponent (如果 Enemy 继承了 CombatUnit.stats)
    if has_node("StatsComponent"):
        var stats := get_node("StatsComponent") as StatsComponent
        var speed_mod := StatModifier.new()
        speed_mod.stat_name = "move_speed"
        speed_mod.mod_type = StatModifier.ModType.PERCENT_ADD
        speed_mod.value = _berserk_speed_mult - 1.0  # +50%
        speed_mod.source_id = "berserk"
        stats.add_modifier(speed_mod)
    
    # 2. 视觉 — 推入 BERSERK 状态
    var visual_sm := get_node_or_null("VisualStateMachine") as EnemyVisualStateMachine
    if visual_sm:
        visual_sm.push_state(EnemyVisualStateMachine.VisualState.BERSERK)
    
    # 3. 精英/Boss 狂暴时激怒周围小怪
    if is_elite or is_boss:
        _enrage_nearby_minions()
    
    # 4. 攻击协调器：通知离开队列
    var coordinator := _get_coordinator()
    if coordinator:
        coordinator.cancel_attack(self as CombatUnit)

func _on_berserk_expired() -> void:
    _is_berserk = false
    _ignore_coordinator = false
    
    # 移除属性修改器
    if has_node("StatsComponent"):
        var stats := get_node("StatsComponent") as StatsComponent
        stats.remove_modifiers_by_source("berserk")
    
    # 弹出视觉状态
    var visual_sm := get_node_or_null("VisualStateMachine") as EnemyVisualStateMachine
    if visual_sm:
        visual_sm.pop_state(EnemyVisualStateMachine.VisualState.BERSERK)
```

#### 3.4.3 精英/Boss 激怒周围小怪

```gdscript
func _enrage_nearby_minions() -> void:
    ## 当精英或 Boss 受伤时，半径 500px 内的所有普通敌人同步进入狂暴
    var tree := get_tree()
    if not tree: return
    
    var all_enemies := tree.get_nodes_in_group("enemies")
    if all_enemies.is_empty():
        # fallback: 遍历父节点
        var p := get_parent()
        if p:
            for child in p.get_children():
                if child is Enemy and child != self and not child.is_boss and not child.is_elite:
                    var dist := global_position.distance_to(child.global_position)
                    if dist < 500.0:
                        child._enter_berserk()
        return
    
    for e in all_enemies:
        if e == self: continue
        var enemy := e as Enemy
        if enemy and not enemy.is_boss and not enemy.is_elite:
            var dist := global_position.distance_to(enemy.global_position)
            if dist < 500.0 and not enemy._is_berserk:
                enemy._enter_berserk()
```

#### 3.4.4 _physics_process 中狂暴计时和衰减

```gdscript
# enemy.gd — _physics_process() 中新增（在行为分发之前）
func _physics_process(delta: float) -> void:
    # ... 现有检查 ...
    
    # 狂暴计时更新
    if _is_berserk:
        _berserk_timer += delta
        if _berserk_timer >= _berserk_duration:
            _on_berserk_expired()
    
    # ... 行为分发 ...
```

#### 3.4.5 _melee_behavior 中应用狂暴修正

```gdscript
func _melee_behavior(delta: float) -> void:
    var melee_count := _count_nearby_melee()
    
    # 狂暴期间无视包围战术——直接冲脸
    if _is_berserk:
        var direction := global_position.direction_to(_player_ref.global_position)
        velocity = direction * move_speed * _berserk_speed_mult
        move_and_slide()
        # 狂暴期间的攻击间隔也缩短（在 try_melee_attack 中靠 StatsComponent 的 CD modifier 实现）
        return
    
    # 正常逻辑...
```

#### 3.4.6 视觉层次复用

现有 `EnemyVisualStateMachine` 已经实现了完整的 BERSERK 视觉：

```gdscript
# visual_state_machine.gd L37-L38 — 已有配置
VisualState.BERSERK: {"color": Color(1.0, 0.13, 0.13, 1.0), "time": 0.2},
# L262-L272 — 已有脉冲效果
func _start_berserk_pulse() -> void:
    _pulse_tween = create_tween().set_loops(0)
    _pulse_tween.tween_property(_sprite, "modulate:a", 0.6, 0.25)
    _pulse_tween.tween_property(_sprite, "modulate:a", 1.0, 0.25)
    # 光环放大
    if _glow:
        gt.tween_property(_glow, "scale", Vector2(1.3, 1.3), 0.25)
        gt.tween_property(_glow, "scale", Vector2(1.0, 1.0), 0.25)
```

但需要增加**体型微震**效果：

```gdscript
# visual_state_machine.gd — _apply_state() 的 BERSERK 分支新增
VisualState.BERSERK:
    _apply_color_tween(target_color, duration)
    _start_berserk_pulse()
    _start_berserk_shake()  # 新增: 体型微震
    return

func _start_berserk_shake() -> void:
    ## 体型微震 — 2-3px 的随机偏移，制造"愤怒发抖"的视觉
    if not _sprite: return
    var shake_tween := create_tween().set_loops(0)
    shake_tween.tween_property(_sprite, "position:x", _sprite.position.x + 2.0, 0.05)
    shake_tween.tween_property(_sprite, "position:x", _sprite.position.x - 2.0, 0.05)
    shake_tween.tween_property(_sprite, "position:x", _sprite.position.x + 1.0, 0.05)
    shake_tween.tween_property(_sprite, "position:x", _sprite.position.x, 0.05)
```

### 3.5 狂暴系统状态时序

```
t=0.0s    Enemy 受到攻击 → _enter_berserk()
          ├── StatsComponent: move_speed +50%, 攻击 CD -50%
          ├── VisualStateMachine: push BERSERK (红色+alpha脉冲+光环放大+体型微震)
          ├── AttackCoordinator: cancel_attack, ignore_coordinator = true
          └── Elite/Boss: _enrage_nearby_minions (500px radius)
          
t=0.0~4.0s 狂暴持续中
          ├── 每次新伤害: _berserk_timer 重置为 0
          ├── 移动: 不参与包围战术, 直线冲脸
          ├── 攻击: 无视 AttackCoordinator 3 人上限
          └── 视觉: 红色脉冲 + 光环放大 + 体型微震

t=4.0s   (如果不再受伤) _berserk_timer >= _berserk_duration
          ├── StatsComponent: remove_modifiers_by_source("berserk")
          ├── VisualStateMachine: pop BERSERK
          └── ignore_coordinator = false
```

### 3.6 Boss 的特殊处理

Boss 有自己的阶段系统。Phase 4（毕业考试，HP < 25%）已经是 Boss 的"狂暴态"。因此：
- Boss 在 Phase 1-3 受伤时**不**触发 `_enter_berserk()`（由 `_check_berserk_trigger()` 中的 `is_boss` 判断跳过）
- Boss 受伤时**仍然**触发 `_enrage_nearby_minions()`——让 Boss 周围的小怪同步暴走
- Phase 4 的 Boss 自身行为已在 `boss_ai.gd` 的 `_movement_phase4()` 中实现（移速 120，攻击间隔 1.0s）

---

## 4. 通用 AI 配置 — 数据驱动设计

### 4.1 设计原则

- 每种敌人类型的 AI 参数**可配置、可复用、可在编辑器中调整**
- 后续新增副本时，只需创建新的 Resource 实例填入参数
- 不依赖代码修改来调整 AI 行为

### 4.2 AIEnemyConfig Resource 定义

**新文件**: `scripts/resources/ai_enemy_config.gd`

```gdscript
class_name AIEnemyConfig
extends Resource

## 通用 AI 配置 — 数据驱动敌人行为
##
## 每种敌人类型对应一个 .tres 实例。
## 在 Enemy 的 _ready() 中加载对应配置，注入到 AIBehaviorController。

# =============================================================================
# 基础行为参数
# =============================================================================

## 初始行为模式 (CHASE / KITE / PATROL / GUARD / AMBUSH)
@export var initial_behavior: int = 1  # AIBehaviorController.AIState.CHASE

## 索敌范围（px），超过此距离敌人完全无视玩家
@export var detection_range: float = 600.0

## 最大追击距离（px），超出后转 RETURN
@export var leash_range: float = 800.0

## 战斗移速倍率（相对于 Enemy.move_speed 的倍数）
@export var chase_speed_mult: float = 1.0

# =============================================================================
# 近战参数
# =============================================================================

## 近战攻击距离（px），进入此范围后开始近战攻击
@export var melee_range: float = 45.0

## 近战攻击基础冷却（秒）
@export var melee_cooldown: float = 1.2

# =============================================================================
# 远程参数
# =============================================================================

## 偏好距离（px），远程敌人试图维持在此距离
@export var preferred_distance: float = 180.0

## 远程攻击冷却（秒）
@export var ranged_cooldown: float = 2.0

# =============================================================================
# 巡逻参数
# =============================================================================

## 巡逻路径点（全局坐标）
@export var patrol_points: Array[Vector2] = []

## 到达每个巡逻点后的等待时间（秒）
@export var patrol_wait_time: float = 1.0

## 巡逻视野锥角度（度）
@export var patrol_vision_angle: float = 120.0

## 巡逻视野距离（px）
@export var patrol_vision_range: float = 180.0

# =============================================================================
# 守卫参数
# =============================================================================

## 守卫点位置
@export var guard_position: Vector2 = Vector2.ZERO

## 守卫区域半径（px），在此范围内慢速移动
@export var guard_radius: float = 60.0

## 守卫追击限制（px），玩家超出此距离则不再追击
@export var guard_leash: float = 200.0

# =============================================================================
# 逃跑参数
# =============================================================================

## 触发逃跑的 HP 比例（0.0-1.0）
@export var flee_health_ratio: float = 0.2

## 逃跑移速倍率
@export var flee_speed_mult: float = 1.3

## 最大逃跑时长（秒），超时后原地硬直
@export var flee_timeout: float = 5.0

# =============================================================================
# 伏击参数
# =============================================================================

## 伏击触发距离（px），玩家进入此范围后突袭
@export var ambush_trigger_distance: float = 60.0

## 伏击首击伤害倍率
@export var ambush_bonus_damage_mult: float = 1.5

## 伏击加速持续时间（秒）
@export var ambush_bonus_duration: float = 2.0

# =============================================================================
# 狂暴参数
# =============================================================================

## 是否启用狂暴系统（false = 受伤不触发狂暴）
@export var berserk_enabled: bool = true

## 狂暴持续时间（秒）
@export var berserk_duration: float = 4.0

## 狂暴移速倍率
@export var berserk_speed_mult: float = 1.5

## 狂暴攻击冷却倍率（< 1.0 = 更快攻击, 如 0.5 = 两倍速）
@export var berserk_cooldown_mult: float = 0.5

## 狂暴触发伤害阈值（单次伤害 >= 此值才触发, 0 = 任意伤害触发）
@export var berserk_damage_threshold: int = 0

## 精英/Boss 狂暴时激怒周围小怪的半径（px, 0 = 不激怒）
@export var enrage_radius: float = 0.0

# =============================================================================
# 路径/导航参数
# =============================================================================

## 路径更新频率（秒）
@export var path_update_interval: float = 0.05

## 行为决策频率（秒）
@export var decision_interval: float = 0.15

## 是否使用 NavigationAgent2D 导航（false = 直线追踪 + 墙滑）
@export var use_nav_agent: bool = true
```

### 4.3 敌人类型预设配置

| 参数 | melee_basic | ranged_basic | melee_elite | ambusher | dodger |
|------|:----------:|:----------:|:----------:|:--------:|:-----:|
| detection_range | 600 | 650 | 700 | 400 | 600 |
| leash_range | 800 | 900 | 1000 | 600 | 800 |
| chase_speed_mult | 1.0 | 0.9 | 0.8 | 1.0 | 1.1 |
| melee_range | 45 | - | 55 | 50 | 45 |
| preferred_distance | - | 180 | - | - | 160 |
| berserk_duration | 4.0 | 3.5 | 5.0 | 4.0 | 3.0 |
| berserk_speed_mult | 1.5 | 1.4 | 1.3 | 1.6 | 1.7 |
| berserk_cooldown_mult | 0.5 | 0.6 | 0.5 | 0.4 | 0.5 |
| enrage_radius | 0 | 0 | 500 | 0 | 0 |
| ambush_trigger_distance | - | - | - | 60 | - |

以上预设作为 `.tres` 文件存储在 `resources/ai_configs/` 目录下：
- `ai_cfg_melee_basic.tres`
- `ai_cfg_ranged_basic.tres`
- `ai_cfg_melee_elite.tres`
- `ai_cfg_ambusher.tres`
- `ai_cfg_dodger.tres`

### 4.4 Enemy 加载配置

**文件**: `scripts/enemy.gd` — `_ready()` 扩展

```gdscript
@export var ai_config: AIEnemyConfig = null

func _ready() -> void:
    super._ready()
    _update_hp()
    
    # ... 现有的 player_ref / group / 外观 setup ...
    
    # 加载 AI 配置
    if ai_config == null:
        ai_config = _load_default_config()
    
    # 应用 AI 配置到自身参数
    _apply_ai_config()
    
    # 初始化 NavigationAgent2D (如果配置启用)
    if ai_config.use_nav_agent:
        _setup_navigation_agent()
    
    # 初始化 AIBehaviorController (如果有)
    _setup_ai_controller()

func _load_default_config() -> AIEnemyConfig:
    var path := "res://resources/ai_configs/ai_cfg_melee_basic.tres"
    if is_ranged:
        path = "res://resources/ai_configs/ai_cfg_ranged_basic.tres"
    if is_elite:
        path = "res://resources/ai_configs/ai_cfg_melee_elite.tres"
    if is_dodger:
        path = "res://resources/ai_configs/ai_cfg_dodger.tres"
    if ResourceLoader.exists(path):
        return ResourceLoader.load(path) as AIEnemyConfig
    return AIEnemyConfig.new()

func _apply_ai_config() -> void:
    if not ai_config: return
    
    # 将配置参数注入到运行时变量
    detection_range = ai_config.detection_range
    _berserk_duration = ai_config.berserk_duration
    _berserk_speed_mult = ai_config.berserk_speed_mult
    _berserk_cooldown_mult = ai_config.berserk_cooldown_mult
    
    # 如果使用 StatsComponent, 注入属性
    if has_node("StatsComponent"):
        var stats := get_node("StatsComponent") as StatsComponent
        stats.set_base("detection_range", ai_config.detection_range)
        stats.set_base("leash_range", ai_config.leash_range)
        stats.set_base("melee_range", ai_config.melee_range)
        stats.set_base("preferred_distance", ai_config.preferred_distance)
```

### 4.5 game_manager.gd 中生成时覆盖配置

**文件**: `scripts/game_manager.gd`

在 `_spawn_enemy()` 中支持传入 `AIEnemyConfig` 覆盖：

```gdscript
func _spawn_enemy(pos: Vector2, type: String, override_config: AIEnemyConfig = null) -> Enemy:
    var e: Enemy = _enemy_scene.instantiate()
    e.global_position = pos
    
    # 类型设置
    match type:
        "melee":  e.is_ranged = false
        "ranged": e.is_ranged = true
        "elite":  e.is_elite = true
        "dodger": e.is_dodger = true
        "stationary":  # 不移动的类型
            e.move_speed = 0
    
    # 覆盖 AI 配置（如果提供了）
    if override_config:
        e.ai_config = override_config
    
    enemies.add_child(e)
    return e
```

这样每个地图区域的敌人可以用不同的配置——操场上的敌人索敌范围更小（400px），教室里的敌人更警觉（700px），体育馆的敌人狂暴时间更长。

---

## 5. 完整状态机整合

### 5.1 整合后的 AI 控制流

```
Enemy._physics_process(delta)
  │
  ├─ [1] 狂暴计时更新 (_berserk_timer += delta, 到期则 _on_berserk_expired)
  │
  ├─ [2] AIBehaviorController._process(delta)
  │     ├── 决策评估 (_evaluate_transition)
  │     │     ├── STUNNED? → 不移动
  │     │     ├── FLEE?   → 远离玩家 (speed × flee_mult)
  │     │     ├── RETURN? → 导航回守卫点
  │     │     ├── CHASE?  → 导航追踪 (speed × chase_mult × [berserk_mult])
  │     │     ├── KITE?   → 维持距离
  │     │     ├── GUARD?  → 守卫区域
  │     │     ├── PATROL? → 巡逻路径
  │     │     └── IDLE?   → 待机
  │     └── 路径更新 (_tick_behavior → 每 path_update_interval 更新 NavAgent)
  │
  ├─ [3] 技能选择 (_try_melee_attack / _ranged_timer)
  │     ├── 狂暴中 → 攻击间隔缩短到 cooldown × berserk_cooldown_mult
  │     ├── 狂暴中 → 跳过 AttackCoordinator 排队
  │     └── 正常中 → 通过 AttackCoordinator.register_attack() 协调
  │
  ├─ [4] 移动执行 (move_and_slide)
  │
  └─ [5] 攻击前摇/硬直管理 (windup → active → recovery)
        ├── 前摇期间移速降到 20%
        ├── 硬直期间不能攻击（可移动）
        └── 由 skill.has_signal("windup_started") 等信号驱动
```

### 5.2 状态转化图（含 BERSERK 叠加层）

```
                    ┌─────────────────────────────────────────┐
                    │            BERSERK 叠加层               │
                    │  (take_damage → 进入; 4s后 → 退出)    │
                    └─────────────────────────────────────────┘
                                       │
                        叠加在以下任意状态上
                                       │
    ┌──────┐    发现玩家    ┌────────┐    丢失玩家    ┌────────┐
    │ IDLE │──────────────→│ CHASE  │──────────────→│ RETURN │
    └──────┘               └───┬────┘               └───┬────┘
                               │    到达守卫点          │
                       受伤    │              ┌─────────┘
                         ↓     │              ↓
                    ┌────────┐ │         ┌────────┐
                    │ BERSERK│ │         │ GUARD  │────→ 玩家进入范围 → CHASE
                    └────────┘ │         └────────┘
                               │
                        HP<20% │ (非Boss非精英)
                               ↓
                          ┌────────┐    恢复或超时    ┌────────┐
                          │ FLEE   │───────────────→│ RETURN │
                          └────────┘                └────────┘
```

---

## 6. 开发任务拆分

### 6.1 程序任务

| 优先级 | 任务 | 文件 | 预估工时 | 依赖 |
|:---:|------|------|:---:|------|
| **P0** | 教室北门+侧门开口 | `scripts/school_map.gd` | 0.5d | 无 |
| **P0** | NavigationAgent2D 初始化和注册 | `scripts/enemy.gd`, `scripts/nav_manager.gd` | 0.5d | P0 出口 |
| **P0** | 导航烘焙（TileMap 障碍物解析） | `scripts/nav_manager.gd`, `scripts/school_map.gd` | 1d | P0 出口 |
| **P1** | Enemy 接入 NavAgent 路径追踪 | `scripts/enemy.gd` | 1d | P0 导航 |
| **P1** | AIEnemyConfig Resource 定义 | `scripts/resources/ai_enemy_config.gd` | 0.5d | 无 |
| **P1** | 预设配置文件生成 (5 个 .tres) | `resources/ai_configs/` | 0.25d | P1 Config |
| **P1** | Enemy._ready() 加载配置流程 | `scripts/enemy.gd` | 0.5d | P1 Config |
| **P2** | 狂暴系统核心: _enter_berserk / _on_berserk_expired | `scripts/enemy.gd` | 1d | P1 Config |
| **P2** | 狂暴视觉: 体型微震 + 光环放大 | `scripts/ai/visual_state_machine.gd` | 0.5d | P2 核心 |
| **P2** | 精英/Boss 激怒周围小怪 | `scripts/enemy.gd` | 0.25d | P2 核心 |
| **P2** | 狂暴期间跳过 AttackCoordinator | `scripts/enemy.gd`, `scripts/ai/ai_behavior_controller.gd` | 0.25d | P2 核心 |
| **P3** | AIBehaviorController 全状态接入 Enemy | `scripts/enemy.gd`, `scripts/ai/ai_behavior_controller.gd` | 1.5d | P1 Config |
| **P3** | 导航路径更新频率分级（性能优化） | `scripts/ai/ai_behavior_controller.gd` | 0.25d | P1 导航 |
| **P3** | game_manager 生成时注入 AIEnemyConfig | `scripts/game_manager.gd` | 0.5d | P1 Config |

**总程序工时**: 约 8.5 天

### 6.2 美术任务

| 优先级 | 任务 | 说明 | 预估工时 | 依赖 |
|:---:|------|------|:---:|------|
| **P1** | 狂暴态红色调色板 | BERSERK 状态颜色: 深红底色 + 橙红脉冲, 区别于正常态和精英态 | 0.25d | P2 核心 |
| **P1** | 狂暴态 particle 效果 | 敌人周围小粒子（火花/血气）向上飘散。简单方案: 3-5 个 ColorRect + 随机位移 tween | 0.5d | P2 核心 |
| **P2** | 导航 debug 可视化颜色 | 可通行/不可通行区域的半透明遮罩色（仅开发用） | 0.25d | P0 导航 |
| **P3** | 出口/门洞的视觉标识 | 门洞 tile 与墙壁 tile 颜色区分，让玩家看出"这是出口" | 0.5d | P0 出口 |

**总美术工时**: 约 1.5 天

### 6.3 交互/关卡任务

| 优先级 | 任务 | 说明 | 预估工时 | 依赖 |
|:---:|------|------|:---:|------|
| **P1** | 教室出口后的敌人行为测试 | 验证敌人从北门/侧门出来后的 AI 路径 | 0.5d | P0 全部 |
| **P1** | 狂暴系统体验调参 | 调整 berserk_duration / speed_mult 数值，确保不压迫也不无聊 | 0.5d | P2 全部 |
| **P2** | 导航路径验证 | 在多种场景下验证 NavigationAgent2D 不穿墙、不卡角 | 0.5d | P1 导航 |
| **P2** | AIEnemyConfig 预设参数数值平衡 | 5 种预设的 detection_range / cooldown / speed 参数调优 | 0.5d | P1 Config |
| **P3** | 精英激怒半径与战斗节奏测试 | 确认 500px 激怒半径不会导致"全屏狂暴" | 0.25d | P2 激怒 |

**总交互/关卡工时**: 约 2.25 天

---

## 7. 跨副本复用指南

本节说明在**后续新副本**中如何复用本方案的所有系统，以及新副本开发时需要做的最小配置工作。

### 7.1 新副本接入清单

开发新副本（如"地牢"、"森林遗迹"）时，按以下清单逐项完成。**零代码改动**，仅需配置数据。

| 步骤 | 操作 | 涉及文件 | 说明 |
|:--:|------|----------|------|
| 1 | 创建地图 TileMap | 新 `.tscn` / 脚本 | 按新副本需求搭 TileMap，墙壁 tile 在 TileSet 中设置 physics layer 碰撞 |
| 2 | 挂载 NavManager | 场景中加 `NavManager` 节点，设置 `tilemap_path` | NavManager 自动扫描 TileMap 碰撞层烘焙导航。如果使用非标准碰撞 layer，设置 `parsed_collision_mask` |
| 3 | 创建 AI 配置 .tres | `resources/ai_configs/` 新增 | 可直接复用学校副本的 5 个预设，或新建：`ai_cfg_dungeon_skeleton.tres` 等 |
| 4 | 创建敌人场景 | `.tscn` + `Enemy` 子类 | 在 Inspector 中拖入第 3 步的 `.tres` 到 `ai_config` 属性 |
| 5 | 生成敌人时注入配置 | `game_manager.gd` | `_spawn_enemy(pos, type, override_config)` |
| 6 | 给建筑加多个开口 | 地图脚本的 `_building()` 函数 | 使用 `open_north`/`open_side` 参数（从学校副本 `school_map.gd` 复用模式） |

### 7.2 场景示例：地牢副本

```
假设新副本 "dungeon_catacombs" 目录结构:

scenes/dungeon/
  └── dungeon_map.tscn       # 挂 SchoolMap 的通用版本（或新建 DungeonMap.gd）
      └── NavManager         # tilemap_path = "../TileMap"
      └── TileMap            # 使用地牢专用 TileSet
      └── Enemies            # 敌人父节点

resources/ai_configs/
  ├── ai_cfg_melee_basic.tres       ← 直接复用学校副本的
  ├── ai_cfg_dungeon_wraith.tres    ← 新建: detection_range=800 (幽灵感知远)
  └── ai_cfg_dungeon_golem.tres     ← 新建: berserk_enabled=true, berserk_duration=6.0 (魔像狂暴更久)
```

**开发者只需做的事**:
1. 搭地牢地图（TileMap + TileSet 墙壁碰撞）
2. 创建 1-2 个新 `.tres` 配置（或用已有的）
3. 在 `.tscn` 中拖配置到 Enemy 节点

**不需要做的事**:
- 不需要改 `enemy.gd` 任何代码
- 不需要改 `nav_manager.gd`
- 不需要改 `ai_behavior_controller.gd`
- 不需要改 `visual_state_machine.gd`

### 7.3 视觉主题替换

如果新副本需要不同的狂暴视觉颜色（如地牢 = 紫色狂暴，森林 = 绿色狂暴），不需要修改 `EnemyVisualStateMachine` 代码。

**方案**: 在 `AIEnemyConfig` 中增加视觉覆盖字段:

```gdscript
# AIEnemyConfig — 新增视觉覆盖（可选，不设置则使用默认）
@export_group("Visual Override")
@export var berserk_color: Color = Color(1.0, 0.13, 0.13, 1.0)  # 默认红色
@export var berserk_glow_color: Color = Color(1.0, 0.3, 0.1, 0.4)
@export var berserk_shake_intensity: float = 2.0
```

然后在 `_enter_berserk()` 中读取 `ai_config.berserk_color` 动态设置 `EnemyVisualStateMachine.STATE_CONFIG[VisualState.BERSERK]["color"]`。

### 7.4 行为模式扩展

当前 `AIBehaviorController` 有 9 个行为状态。如果新副本需要新的行为模式（如"自杀式爆炸"、"守护特定 NPC"）：

1. 在 `AIBehaviorController.AIState` 枚举中新增一项（如在末尾加 `SUICIDE_RUSH = 9`）
2. 实现 `_tick_suicide_rush(delta)` 方法
3. 在 `_evaluate_transition()` 和 `_tick_behavior()` 中加对应 case
4. 在 `AIEnemyConfig` 中加相应参数

不需要重写整个控制器，不需要修改已有行为的代码。这是标准的"状态机+枚举扩展"模式。

---

## 8. 优先级排序和里程碑

### Milestone 1: 基础设施 (Day 1-2)
- [ ] 教室北门+侧门开口 → 敌人不再被困
- [ ] NavigationAgent2D 初始化 → 敌人生成时带导航代理
- [ ] 导航烘焙 → 路网正确排除墙壁

**验收**: 在编辑器中看到正确导航网格（蓝色覆盖走廊 + 教室内部 + 操场，墙壁处断开）

### Milestone 2: 配置系统 (Day 3)
- [ ] AIEnemyConfig Resource 类
- [ ] 5 个预设 .tres 文件
- [ ] Enemy 加载配置流程
- [ ] game_manager 生成覆盖

**验收**: 在编辑器中选中 Enemy 节点，Inspector 中可看到 AIEnemyConfig 的所有参数，修改参数立即影响行为

### Milestone 3: 狂暴系统 (Day 4-5)
- [ ] 狂暴核心: 进入/退出/计时/属性修正
- [ ] 狂暴视觉: 红色脉冲 + 体型微震 + 光环放大
- [ ] 精英/Boss 激怒周围小怪
- [ ] 狂暴期间跳过群组协调

**验收**: 玩家攻击一个敌人后，该敌人变红 + 加速 + 攻击加快。攻击精英后，半径内小怪同步变红。4 秒后恢复

### Milestone 4: 导航接入 (Day 6-7)
- [ ] Enemy 用 NavAgent 路径追踪替代直线追踪
- [ ] 路径更新频率分级
- [ ] 降级策略（NavAgent 不可用时 fallback 到墙滑）

**验收**: 敌人在教室中追玩家时自动绕开课桌和柱子，出教室后沿走廊追，不会卡在墙上

### Milestone 5: 集成与打磨 (Day 8)
- [ ] AIBehaviorController 全状态接入
- [ ] 数值平衡（各配置预期参数的 playtest）
- [ ] 性能检查（50+ 敌人同时活跃时帧率）
- [ ] 清理编译警告、删除 class cache

**验收**: 一个完整的 playtest session，从操场到教室到 Boss 间，敌人 AI 在所有阶段表现正确

---

## 9. 风险点和降级策略

| 风险 | 概率 | 影响 | 降级 |
|------|:---:|------|------|
| NavigationServer2D 烘焙不识别 TileMap physics layer | 中 | 导航网格仍然是全矩形，敌人穿墙 | 回退到方案 B: 手动创建 StaticBody2D 包裹每段墙壁（`school_map.gd` 中遍历 layer 1 构建） |
| 狂暴叠加使敌人过强 | 低 | 玩家被暴走群怪秒杀 | `berserk_damage_threshold` 参数控制触发灵敏度；`berserk_cooldown_mult` 从 0.5 上调到 0.7 |
| 精英激怒 500px 半径过大 | 低 | 全场景狂暴 | 缩小到 350px 或改为"同屏激活的敌人" |
| AIBehaviorController 完整接入后旧行为逻辑冲突 | 中 | 双重移动逻辑导致敌人抽搐 | 用 `ai_config.use_behavior_controller` bool 控制切换，默认先保持旧逻辑不减 |
| NavAgent 路径更新在大量敌人时掉帧 | 低 | 50+ 敌人同时更新路径 | 距离分级更新 + 不可见敌人暂停导航 |
| 北门开口导致地图美观问题 | 低 | 墙壁断开处没有视觉过渡 | 铺走廊地板 tile (source 2) 做视觉过渡 |

---

## 附录 A: 降级方案已并入 Section 2.2

StaticBody2D 障碍物的**通用实现**已在 Section 2.2 的方案 B 中完整给出（`NavManager._build_wall_obstacles_generic()`）。该方法扫描 TileMap 所有 layer 的所有 cell，通过 `TileData.get_collision_polygons_count()` 自动检测碰撞，**不依赖 source ID / 坐标 / 地图尺寸硬编码**。新副本直接调用即可。

原先学校副本专属版本（hardcode `wall_sids = [4,5,6,8]` + `T=48` + `MW=5760`）已废弃，不再保留。

---

## 附录 B: 文件改动清单

| 文件 | 操作 | 说明 |
|------|:---:|------|
| `scripts/school_map.gd` | 修改 | `_building()` 增加北门+侧门参数和开口逻辑 |
| `scripts/nav_manager.gd` | 重写 | NavigationServer2D 烘焙 + agent 注册管理 |
| `scripts/enemy.gd` | 修改 | NavigationAgent2D 初始化 + 狂暴系统 + AIEnemyConfig 加载 |
| `scripts/ai/ai_behavior_controller.gd` | 修改 | 狂暴期间跳过协调器 + 导航路径更新频率分级 |
| `scripts/ai/visual_state_machine.gd` | 修改 | BERSERK 状态增加体型微震效果 |
| `scripts/ai/attack_coordinator.gd` | 不修改 | 已支持 cancel_attack，无需改动 |
| `scripts/components/stats_component.gd` | 不修改 | 已支持 modifier 系统，狂暴通过 add_modifier 接入 |
| `scripts/game_manager.gd` | 修改 | `_spawn_enemy()` 支持传入 AIEnemyConfig 覆盖 |
| `scripts/resources/ai_enemy_config.gd` | **新建** | 通用 AI 配置 Resource 类 |
| `resources/ai_configs/*.tres` | **新建** | 5 个敌人类型预设配置文件 |

---

## 附录 C: 对现有设计文档的引用关系

| 本文档章节 | 引用的先前设计 | 关系 |
|-----------|---------------|------|
| 3. AI 狂暴系统 | `战斗系统设计-宫崎英高.md` 5.4 节（攻击状态机 WINDUP→ACTIVE→RECOVERY） | 狂暴叠加在现有攻击状态机之上 |
| 3.3 实现架构 | `怪物AI与技能设计-V1.0.md` 3.1 节（EnemySkillManager） | 狂暴通过 StatsComponent modifier 修改技能冷却 |
| 3.5 Boss 特殊处理 | `Boss战体验设计-小岛秀夫.md` 四乐章 + `Boss强化与AI包围-宫崎英高.md` 2-3 节 | Boss Phase 4 已有独立狂暴态，不重复触发 |
| 4. 通用 AI 配置 | `战斗系统设计-宫崎英高.md` 6.5 节（AIBehaviorConfig Resource） | 本方案是该设计的具体落地，字段更完整 |
| 1. 教室出口 | `地图布局重设计-宫崎英高.md` + `关卡视觉区域设计-罗梅罗.md` | 开口方案不影响原有区域配色和标签系统 |
| 2. 导航烘焙 | `怪物AI与技能设计-V1.0.md` 5.1 节（NavigationAgent2D 方案） | 本方案提供了具体的 TileMap 烘焙实现路径 |

---

*"AI 不是让敌人更聪明。是让敌人看起来像活了。"*

*"狂暴不是一个数值 buff。是一个敌人告诉你'我生气了'的方式。" — 宫崎英高*
