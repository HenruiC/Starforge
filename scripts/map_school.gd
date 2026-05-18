class_name MapSchool
extends Node2D

# 学校副本 v3 — 宫崎英高·体验叙事重设计
# 动线: 校门→操场(安全)→教学楼→走廊(脊骨)→教室支线→体育馆Boss

const T:=48; const MW:=3200; const MH:=2400
var _w:PackedScene=preload("res://scenes/wall.tscn")
var _b:PackedScene=preload("res://scenes/boundary.tscn")
var _d:PackedScene=preload("res://scenes/door.tscn")
var _dk:PackedScene=preload("res://scenes/desk.tscn")
var _tr:PackedScene=preload("res://scenes/destructible.tscn")

func _ready()->void:_build()

func _build()->void:
	_boundary()
	_school_gate()
	_playground()
	_building()
	_classrooms()
	_boss_room()
	_scatter_trees()

# ===== 边界 =====
func _boundary()->void:
	_h(_b,0,0,MW,0);_h(_b,0,0,0,MH)
	_h(_b,0,MH,MW,MH);_h(_b,MW,0,MW,MH)

# ===== 校门(底部中央) =====
func _school_gate()->void:
	var g:=MW/2
	_h(_w,g-6*T,MH-T,g-T,MH-T)
	_h(_w,g+T,MH-T,g+6*T,MH-T)
	_door(g,MH-T,Color.GOLD)
	_label(g-40,MH-T-20,"▼ 校门 · 起点",Color(0.9,0.8,0.2))

# ===== 操场(开阔地, 主干道无障碍)=====
func _playground()->void:
	for i in 8:
		var x:=randf_range(6*T,MW-6*T);var y:=randf_range(MH-14*T,MH-3*T)
		if abs(x-MW/2)<5*T:continue  # 主干道
		_tree(x,y)
	_label(MW/2-40,MH-10*T,"操场 · 安全区",Color(0.3,0.8,0.3))

# ===== 教学楼主体 =====
func _building()->void:
	var bx:=8*T;var by:=MH-16*T;var bw:=50*T;var bh:=11*T

	# 外墙(三面, 下方开门)
	_h(_w,bx,by,bx+bw,by)          # 上
	_h(_w,bx,by,bx,by+bh)          # 左
	_h(_w,bx+bw,by,bx+bw,by+bh)    # 右
	# 下墙(留大门)
	_h(_w,bx,by+bh,bx+bw/2-3*T,by+bh)
	_h(_w,bx+bw/2+3*T,by+bh,bx+bw,by+bh)

	_door(bx+bw/2,by+bh,Color(0.3,0.5,1.0,0.9))
	_label(bx+bw/2-60,by+bh+16,"▲ 教学楼入口",Color(0.8,0.7,0.3))

	# 玄关区(教学楼内前半)
	var ox:=bx+16*T;var ow:=18*T
	_h(_w,ox,by,ox,by+bh-4*T)
	_h(_w,ox+ow,by,ox+ow,by+bh-4*T)
	_door(ox,by+bh-4*T,Color(0.3,0.5,1.0,0.9))
	_door(ox+ow,by+bh-4*T,Color(0.3,0.5,1.0,0.9))
	_label(bx+bw/2-30,by+bh/2,"玄关 · 室内",Color(0.7,0.6,0.2))

	# 走廊(教学楼内后半, 水平)
	var cy:=by+6*T
	_h(_w,bx+4*T,cy-2*T,bx+bw-4*T,cy-2*T)  # 走廊上墙
	_h(_w,bx+4*T,cy+2*T,bx+bw-4*T,cy+2*T)  # 走廊下墙

	# 走廊两端门
	_door(bx+11*T,cy,Color(0.2,0.8,0.2,0.9))
	_door(bx+bw-11*T,cy,Color(0.2,0.8,0.2,0.9))
	_label(bx+bw/2-40,cy-16,"走廊 · 脊骨",Color(0.7,0.5,0.1))

# ===== 6间教室(走廊上下各3间) =====
func _classrooms()->void:
	var bx:=8*T;var by:=MH-16*T;var bw:=50*T;var bh:=11*T;var cy:=by+6*T
	# 上排
	_room(bx+4*T, by+T,  bx+18*T, cy-3*T,"教室A")
	_room(bx+19*T,by+T,  bx+31*T, cy-3*T,"教室B")
	_room(bx+32*T,by+T,  bx+bw-4*T,cy-3*T,"教室C")
	# 下排
	_room(bx+4*T,  cy+3*T,bx+18*T, by+bh-T,"教室D")
	_room(bx+19*T, cy+3*T,bx+31*T, by+bh-T,"教室E")
	_room(bx+32*T, cy+3*T,bx+bw-4*T,by+bh-T,"教室F")

# ===== Boss间(教学楼正上方) =====
func _boss_room()->void:
	var bx:=8*T;var bw:=50*T;var by:=MH-16*T
	var bbx:=bx+8*T;var bby:=by-3*T;var bbw:=34*T;var bbh:=4*T
	_h(_w,bbx,bby,bbx+bbw,bby)
	_h(_w,bbx,bby,bbx,bby+bbh)
	_h(_w,bbx+bbw,bby,bbx+bbw,bby+bbh)
	_h(_w,bbx+4*T,bby+bbh,bbx+bbw-4*T,bby+bbh)
	_door(bbx+bbw/2,bby+bbh,Color(1.0,0.15,0.05,0.9))
	_label(bbx+bbw/2-90,bby-24,"⚠ Boss间 · 体育馆",Color(1.0,0.15,0.05))

# ===== 散落树 =====
func _scatter_trees()->void:
	var bx:=8*T;var by:=MH-16*T;var bw:=50*T;var bh:=11*T
	for i in 8:
		_tree(randf_range(bx+2*T,bx+bw-2*T),randf_range(by+bh+T,MH-2*T))
		_tree(randf_range(bx-T,bx),randf_range(by,by+bh))
		_tree(randf_range(bx+bw,bx+bw+T),randf_range(by,by+bh))

# ===== 工具函数 =====
func _h(p:PackedScene,x1:float,y1:float,x2:float,y2:float)->void:
	var dist:=Vector2(x2-x1,y2-y1).length()
	var dir:=Vector2(x2-x1,y2-y1).normalized()
	var pos:=Vector2(x1,y1);var done:=0.0
	while done<dist-1:
		var o:=p.instantiate();o.global_position=pos
		add_child(o);pos+=dir*T;done+=T

func _door(x:float,y:float,c:Color)->void:
	var d:=_d.instantiate();d.global_position=Vector2(x,y);add_child(d)
	var sp:=d.get_node_or_null("Sprite")as ColorRect
	if sp:sp.color=c;sp.scale=Vector2(3.0,2.0)

func _tree(x:float,y:float)->void:
	var t:=_tr.instantiate()
	t.object_name="树";t.max_health=20;t.drop_xp=15
	t.object_color=Color(0.15,0.55,0.15,1.0)
	t.global_position=Vector2(x,y);add_child(t)

func _room(x1:float,y1:float,x2:float,y2:float,nm:String)->void:
	_h(_w,x1,y1,x2,y1);_h(_w,x1,y1,x1,y2);_h(_w,x2,y1,x2,y2)
	# 下墙留5格门洞
	var mx:=(x1+x2)/2
	_h(_w,x1,y2,mx-int(2.5*T),y2)
	_h(_w,mx+int(2.5*T),y2,x2,y2)
	_door(mx,y2,Color(0.85,0.85,0.1,0.9))
	_label(mx-24,y2+16,nm,Color(0.9,0.7,0.2))
	# 课桌(3x2)
	for c in 3:
		for r in 2:
			var dk:=_dk.instantiate()
			dk.global_position=Vector2(x1+(x2-x1)/4.0*float(c+1),y1+(y2-y1)/3.0*float(r+1))
			add_child(dk)

func _label(x:float,y:float,t:String,c:Color)->void:
	var l:=Label.new();l.text=t
	l.add_theme_font_size_override("font_size",13)
	l.add_theme_color_override("font_color",c)
	l.position=Vector2(x,y);l.size=Vector2(180,18)
	add_child(l)
