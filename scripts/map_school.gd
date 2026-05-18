class_name MapSchool
extends Node2D

const T:=48; const MW:=3200; const MH:=2400
var _w:=preload("res://scenes/wall.tscn")
var _b:=preload("res://scenes/boundary.tscn")
var _d:=preload("res://scenes/door.tscn")
var _dk:=preload("res://scenes/desk.tscn")
var _tr:=preload("res://scenes/destructible.tscn")

func _ready()->void:
	_add_floor()
	_build()

func _add_floor()->void:
	# 铺设地板纹理(TileMap替代方案: 大面积TextureRect)
	var floor_tex := AssetLoader.texture("floor_tile", 256, Color(0.1,0.1,0.12))
	var cols := int(ceil(MW/256.0))
	var rows := int(ceil(MH/256.0))
	for x in cols:
		for y in rows:
			var tr := TextureRect.new()
			tr.texture = floor_tex
			tr.size = Vector2(256,256)
			tr.position = Vector2(x*256, y*256)
			tr.z_index = -2
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(tr)

func _build()->void:
	# 边界
	_h(_b,0,0,MW,0);_h(_b,0,0,0,MH);_h(_b,0,MH,MW,MH);_h(_b,MW,0,MW,MH)

	# 校门
	var g:=MW/2
	_h(_w,g-5*T,MH-T,g-T,MH-T);_h(_w,g+T,MH-T,g+5*T,MH-T)
	_door(g,MH-T,Color.GOLD)

	# 操场树(不挡路)
	for i in 8:
		var x:=randf_range(6*T,MW-6*T);var y:=randf_range(MH-14*T,MH-3*T)
		if abs(x-MW/2)<4*T:continue
		_tree(x,y)

	# 教学楼(扩大)
	var bx:=6*T;var by:=MH-18*T;var bw:=54*T;var bh:=13*T

	# 外墙(上方+左右, 下方留门)
	_h(_w,bx,by,bx+bw,by)
	_h(_w,bx,by,bx,by+bh)
	_h(_w,bx+bw,by,bx+bw,by+bh)
	_h(_w,bx,by+bh,bx+bw/2-3*T,by+bh)
	_h(_w,bx+bw/2+3*T,by+bh,bx+bw,by+bh)
	_door(bx+bw/2,by+bh,Color(0.3,0.5,1.0))

	# 走廊(教学楼中间)
	var cy:=by+bh/2
	_h(_w,bx+4*T,cy-2*T,bx+bw-4*T,cy-2*T)
	_h(_w,bx+4*T,cy+2*T,bx+bw-4*T,cy+2*T)

	# 走廊入口
	_door(bx+12*T,cy,Color(0.2,0.8,0.2))
	_door(bx+bw-12*T,cy,Color(0.2,0.8,0.2))

	# 6间大教室(上3下3)
	_room(bx+4*T, by+T,    bx+19*T, cy-3*T, "教室A")
	_room(bx+20*T,by+T,    bx+35*T, cy-3*T, "教室B")
	_room(bx+36*T,by+T,    bx+bw-4*T,cy-3*T, "教室C")
	_room(bx+4*T,  cy+3*T,  bx+19*T, by+bh-T, "教室D")
	_room(bx+20*T, cy+3*T,  bx+35*T, by+bh-T, "教室E")
	_room(bx+36*T, cy+3*T,  bx+bw-4*T,by+bh-T, "教室F")

	# Boss间
	var bbx:=bx+8*T;var bby:=by-3*T
	_h(_w,bbx,bby,bbx+38*T,bby)
	_h(_w,bbx,bby,bbx,bby+4*T)
	_h(_w,bbx+38*T,bby,bbx+38*T,bby+4*T)
	_h(_w,bbx+4*T,bby+4*T,bbx+38*T-4*T,bby+4*T)
	_door(bbx+19*T,bby+4*T,Color(1.0,0.15,0.05))

	# 散落树
	for i in 6:
		_tree(randf_range(bx+2*T,bx+bw-2*T),randf_range(by+bh+T,MH-2*T))

# ===== 工具 =====
func _h(p:PackedScene,x1:float,y1:float,x2:float,y2:float)->void:
	var dist:=Vector2(x2-x1,y2-y1).length()
	var dir:=Vector2(x2-x1,y2-y1).normalized()
	var pos:=Vector2(x1,y1);var d:=0.0
	while d+T<=dist+1:
		var o:=p.instantiate();o.global_position=pos;add_child(o)
		pos+=dir*T;d+=T

func _door(x:float,y:float,c:Color)->void:
	var d:=_d.instantiate();d.global_position=Vector2(x,y);add_child(d)
	var sp:=d.get_node_or_null("Sprite")as ColorRect
	if sp:sp.color=c;sp.scale=Vector2(4.0,2.5)

func _tree(x:float,y:float)->void:
	var t:=_tr.instantiate();t.object_name="树";t.max_health=20;t.drop_xp=15
	t.object_color=Color(0.15,0.55,0.15,1.0);t.global_position=Vector2(x,y);add_child(t)

func _room(x1:float,y1:float,x2:float,y2:float,nm:String)->void:
	# 上墙+左墙+右墙
	_h(_w,x1,y1,x2,y1);_h(_w,x1,y1,x1,y2);_h(_w,x2,y1,x2,y2)
	# 下墙: 左边段 + 大缺口 + 右边段
	var mx:=(x1+x2)/2;var gap:=int(3.0*T)
	_h(_w,x1,y2,mx-gap,y2)
	_h(_w,mx+gap,y2,x2,y2)
	_door(mx,y2,Color(0.85,0.85,0.1))
	_label(mx-24,y2+16,nm,Color(0.9,0.7,0.2))
	# 课桌
	for c in 3:for r in 2:
		var dk:=_dk.instantiate()
		dk.global_position=Vector2(x1+(x2-x1)/4.0*float(c+1),y1+(y2-y1)/3.0*float(r+1))
		add_child(dk)

func _label(x:float,y:float,t:String,c:Color)->void:
	var l:=Label.new();l.text=t;l.add_theme_font_size_override("font_size",13)
	l.add_theme_color_override("font_color",c);l.position=Vector2(x,y);l.size=Vector2(180,18)
	add_child(l)
