class_name WardHUD
extends CanvasLayer

const INK = Color(.85,.87,.79)
const MUTED = Color(.51,.61,.55)
const ACCENT = Color(.65,.72,.56)
var game: Node
var root: Control
var gameplay: Control
var menus: Control
var post: ColorRect
var modal := "menu"
var font: Font
var prompt_label: Label
var health_label: Label
var ammo_label: Label
var room_label: Label
var objective_label: Label
var stamina_bar: ColorRect
var notification: Label
var notice_time := 0.0
var hit_confirm := 0.0
var crosshair: Label
var hint_level := 0
var puzzle_digits := ""
var puzzle_feedback: Label
var code_label: Label
var map_control: Control
var inspect_object: Node3D
var inspect_drag := false

func _ready() -> void:
	font = load("res://assets/fonts/regular.tres")
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 23
	root.theme = theme
	post = ColorRect.new()
	post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/post.gdshader")
	post.material = mat
	root.add_child(post)
	gameplay = Control.new()
	gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(gameplay)
	room_label = text(gameplay,"",Vector2(68,56),22,MUTED)
	objective_label = text(gameplay,"",Vector2(68,90),24,INK)
	text(gameplay,"J  调查日志     TAB  背包",Vector2(1490,60),19,MUTED)
	crosshair = text(gameplay,"·",Vector2(944,513),28,Color(.73,.78,.68,.7))
	crosshair.size = Vector2(32,42)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label = text(gameplay,"",Vector2(540,630),24,INK)
	prompt_label.size = Vector2(840,60)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel(gameplay,Rect2(65,936,270,76),Color(.018,.04,.04,.5),Color(.18,.27,.24,.45))
	text(gameplay,"VITALS",Vector2(82,943),13,MUTED)
	health_label = text(gameplay,"",Vector2(82,965),23,ACCENT)
	line(gameplay,Vector2(190,977),Vector2(310,977),Color(.21,.31,.24))
	var ecg := Line2D.new()
	ecg.points = PackedVector2Array([Vector2(194,977),Vector2(224,977),Vector2(229,970),Vector2(236,986),Vector2(246,955),Vector2(253,984),Vector2(260,977),Vector2(308,977)])
	ecg.width = 1.6
	ecg.default_color = ACCENT
	gameplay.add_child(ecg)
	stamina_bar = rect(gameplay,Rect2(66,1021,267,2),Color(.48,.59,.5,.6))
	ammo_label = text(gameplay,"",Vector2(1610,944),39,INK)
	text(gameplay,"9 × 19mm     /     R 换弹",Vector2(1610,999),17,MUTED)
	menus = Control.new()
	menus.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menus)
	notification = text(root,"",Vector2(400,845),23,INK)
	notification.size = Vector2(1120,80)
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification.add_theme_color_override("font_shadow_color",Color(0,0,0,.95))
	notification.add_theme_constant_override("shadow_offset_x",2)
	notification.add_theme_constant_override("shadow_offset_y",2)
	show_menu()

func text(parent: Node, value: String, pos: Vector2, size_: int=24, color: Color=INK) -> Label:
	var l := Label.new()
	l.text = value
	l.position = pos
	l.add_theme_font_size_override("font_size",size_)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func rect(parent: Node, area: Rect2, color: Color) -> ColorRect:
	var n := ColorRect.new()
	n.position = area.position
	n.size = area.size
	n.color = color
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(n)
	return n

func line(parent: Node, a: Vector2, b: Vector2, color: Color=MUTED) -> void:
	var n := Line2D.new()
	n.points = PackedVector2Array([a,b])
	n.default_color = color
	n.width = 1
	parent.add_child(n)

func style(bg: Color, border: Color=Color(.23,.32,.29), pad: int=18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s

func panel(parent: Node, area: Rect2, bg: Color=Color(.025,.052,.052,.96), border: Color=Color(.2,.29,.26)) -> Panel:
	var p := Panel.new()
	p.position = area.position
	p.size = area.size
	p.add_theme_stylebox_override("panel",style(bg,border))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func button(parent: Node, value: String, area: Rect2, callback: Callable, accent: bool=false) -> Button:
	var b := Button.new()
	b.text = value
	b.position = area.position
	b.size = area.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_color_override("font_color",INK)
	b.add_theme_color_override("font_hover_color",Color(.94,.95,.82))
	b.add_theme_color_override("font_focus_color",Color(.94,.95,.82))
	b.add_theme_stylebox_override("normal",style(Color(.09,.15,.13,.85) if accent else Color(.025,.055,.055,.82),Color(.39,.47,.34) if accent else Color(.16,.24,.22)))
	b.add_theme_stylebox_override("hover",style(Color(.14,.21,.18),Color(.48,.58,.45)))
	b.add_theme_stylebox_override("focus",style(Color(.1,.18,.16,.75),ACCENT))
	b.add_theme_stylebox_override("pressed",style(Color(.18,.25,.20),INK))
	b.add_theme_stylebox_override("disabled",style(Color(.04,.06,.06,.5),Color(.12,.18,.16)))
	b.add_theme_color_override("font_disabled_color",Color(.26,.33,.3))
	b.pressed.connect(func(): game.audio.one("click",-22,1.1); callback.call())
	parent.add_child(b)
	return b

func paragraph(parent: Node, value: String, area: Rect2, font_size: int=24, color: Color=INK) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.position = area.position
	l.size = area.size
	l.bbcode_enabled = true
	l.text = value
	l.add_theme_font_size_override("normal_font_size",font_size)
	l.add_theme_color_override("default_color",color)
	l.add_theme_constant_override("line_separation",12)
	l.scroll_active = true
	parent.add_child(l)
	return l

func clear_modal(next: String) -> void:
	for c in menus.get_children():
		menus.remove_child(c)
		c.queue_free()
	inspect_object = null
	modal = next
	menus.mouse_filter = Control.MOUSE_FILTER_IGNORE if next=="" else Control.MOUSE_FILTER_STOP
	gameplay.visible = next=="" and game.started
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if next=="" and game.started else Input.MOUSE_MODE_VISIBLE

func close() -> void:
	if not game.started: show_menu()
	else: clear_modal("")

func header(kicker: String, title_: String, subtitle: String="") -> void:
	rect(menus,Rect2(0,0,1920,1080),Color(.005,.018,.02,.88))
	text(menus,kicker,Vector2(130,83),18,ACCENT)
	text(menus,title_,Vector2(128,122),46,INK)
	text(menus,subtitle,Vector2(131,194),21,MUTED)
	line(menus,Vector2(130,246),Vector2(1790,246),Color(.21,.31,.28))
	button(menus,"返回  /  ESC",Rect2(1580,950,210,52),close)
	text(menus,"RAINROT     /     WARD 09",Vector2(130,977),16,MUTED)

func show_menu() -> void:
	clear_modal("menu")
	# A translucent left gradient preserves the actual in-engine corridor composition.
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(.008,.023,.026,.97),Color(.008,.023,.026,.88),Color(.008,.023,.026,.0)])
	grad.offsets = PackedFloat32Array([0,.4,1])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2.ZERO
	tex.fill_to = Vector2(1,0)
	var shade := TextureRect.new()
	shade.texture = tex
	shade.size = Vector2(1400,1080)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menus.add_child(shade)
	text(menus,"A   S U R V I V A L   H O R R O R   S T O R Y",Vector2(132,128),17,MUTED)
	line(menus,Vector2(132,181),Vector2(200,181),ACCENT)
	text(menus,"雨 蚀",Vector2(122,204),118,Color(.82,.85,.77))
	text(menus,"第   九   病   区",Vector2(134,370),32,INK)
	text(menus,"R A I N R O T   /   W A R D   0 9",Vector2(134,432),21,MUTED)
	paragraph(menus,"雨一直没有停。\n而那些病人，也从未离开。",Rect2(135,499,540,94),23,Color(.54,.62,.57))
	var b := button(menus,"01     进入疗养院                  →",Rect2(134,652,422,64),func(): game.start_new(),true)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var cont := button(menus,"02     继续调查",Rect2(134,731,422,56),func(): game.load_game())
	cont.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cont.disabled = not game.has_save()
	var opts := button(menus,"03     视听设置",Rect2(134,802,203,56),show_settings)
	opts.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button(menus,"退出",Rect2(353,802,203,56),func(): get_tree().quit())
	text(menus,"建议佩戴耳机  ·  键鼠操作",Vector2(134,964),19,MUTED)
	text(menus,"第一章   /   圣维罗妮卡",Vector2(1510,92),19,Color(.51,.63,.6))
	text(menus,"09.17   /   23:58\n外部温度   11°C\n持续降雨",Vector2(1560,905),17,Color(.43,.55,.52))
	line(menus,Vector2(1490,957),Vector2(1490,1010),Color(.43,.55,.52))

func show_pause() -> void:
	clear_modal("pause")
	header("P A U S E D", "片刻喘息", "你的调查进度会在安全区和章节节点保存。")
	button(menus,"继续调查",Rect2(710,350,500,65),close,true)
	button(menus,"视听设置",Rect2(710,435,500,65),show_settings)
	button(menus,"从最近记录继续",Rect2(710,520,500,65),func(): game.load_game())
	button(menus,"操作说明",Rect2(710,605,500,65),show_controls)
	button(menus,"返回主菜单",Rect2(710,690,500,65),func(): game.return_to_menu())

func show_controls() -> void:
	clear_modal("controls")
	header("FIELD MANUAL", "调查员手册", "活下去，比清空每一条走廊更重要。")
	paragraph(menus,"[color=#a9b893]移动与观察[/color]\nW A S D   移动     /     鼠标   观察\nShift   冲刺     /     Ctrl   蹲伏\nF   开关手电     /     E   调查、拾取与开门\n\n[color=#a9b893]生存[/color]\n左键   射击     /     右键   瞄准     /     R   换弹\nTab   打开六格补给背包，点击敷料治疗\nJ   调查日志、楼层图与可选提示\nEsc   暂停或关闭当前界面",Rect2(190,310,780,570),26)
	paragraph(menus,"缓慢移动与蹲伏能降低被发现的距离。\n\n枪声会吸引周围的感染者。\n瞄准头部能更有效地阻止它们。\n\n关键道具独立保存，不占补给格。\n\n值班室的暖灯是安全的。\n在那里调查录音机可以手动记录进度。\n\n鼠标拖动可以旋转检查关键物件。",Rect2(1090,316,560,590),25,MUTED)

func show_settings() -> void:
	clear_modal("settings")
	header("AUDIO / DISPLAY", "视听设置", "让走廊尽头仍然可辨，保留阴影中的未知。")
	var rows := [["鼠标灵敏度","sensitivity",.3,2.5,.05],["画面亮度","brightness",.75,1.45,.01],["总音量","volume",0.0,1.0,.01],["镜头晃动","bob",0.0,1.0,.1]]
	for i in rows.size():
		var row: Array = rows[i]
		var y := 327+i*113
		text(menus,row[0],Vector2(340,y),26)
		var val := text(menus,"%.2f"%game.settings[row[1]],Vector2(1470,y),23,ACCENT)
		var slider := HSlider.new()
		slider.position = Vector2(720,y+8)
		slider.size = Vector2(670,35)
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.value = game.settings[row[1]]
		slider.value_changed.connect(func(v): game.settings[row[1]]=v; val.text="%.2f"%v; game.apply_settings(); game.save_settings())
		menus.add_child(slider)
	text(menus,"画面质量",Vector2(340,803),26)
	for i in 3:
		button(menus,["低","中","高"][i]+("  ●" if game.settings.quality==i else ""),Rect2(720+i*240,800,215,55),func(): game.settings.quality=i; game.apply_settings(); game.save_settings(); show_settings(),game.settings.quality==i)
	button(menus,"切换全屏  /  F11",Rect2(1340,125,450,55),func(): game.toggle_fullscreen())

func show_note(id_: String) -> void:
	clear_modal("note")
	var note: Dictionary = WardContent.NOTES[id_]
	header("ARCHIVE  /  "+str(game.state.notes.find(id_)+1).pad_zeros(2),note.title,note.tag)
	panel(menus,Rect2(360,281,1200,611),Color(.065,.085,.071,.94))
	text(menus,"圣维罗妮卡疗养院  /  内部档案",Vector2(418,314),17,MUTED)
	line(menus,Vector2(418,359),Vector2(1500,359),Color(.22,.29,.23))
	paragraph(menus,note.text,Rect2(418,385,1080,455),27,Color(.75,.76,.65))
	text(menus,"已加入调查日志   ·   J 可随时查阅",Vector2(655,915),20,MUTED)

func show_journal() -> void:
	clear_modal("journal")
	header("INVESTIGATION", "调查日志", "线索只会在你亲手读过以后出现在这里。")
	text(menus,"当前目标",Vector2(160,292),19,MUTED)
	text(menus,WardContent.OBJECTIVES[game.state.stage],Vector2(160,332),29,ACCENT)
	paragraph(menus,WardContent.SUBOBJECTIVES[game.state.stage],Rect2(160,388,620,83),22)
	for i in game.state.notes.size():
		var id_: String = game.state.notes[i]
		var b := button(menus,"%02d   %s"%[i+1,WardContent.NOTES[id_].title],Rect2(160,487+i*43,620,39),func(): show_note(id_))
		b.add_theme_font_size_override("font_size",19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button(menus,"提示  /  逐步揭示",Rect2(930,805,720,57),func():
		var hint: String = WardContent.HINTS[game.state.stage][mini(hint_level,2)]
		hint_level += 1
		puzzle_feedback.text = hint)
	puzzle_feedback = text(menus,"提示不会自动出现。需要时再打开它。",Vector2(930,884),21,MUTED)
	draw_map(Vector2(1000,300),7.4)

func draw_map(origin: Vector2, scale_: float) -> void:
	text(menus,"1 F   /   疏散示意",origin-Vector2(20,0),21,ACCENT)
	var rects := [Rect2(-2.6,-38,5.2,52),Rect2(15,-34,5,45),Rect2(2.6,-34,12.4,5),Rect2(2.6,6,12.4,5),Rect2(-12,1,9.4,8),Rect2(-11,-10,8.4,8),Rect2(-14,-27,11.4,14),Rect2(-12,-38,9.4,8),Rect2(2.6,-7,12.4,12),Rect2(3.4,-28,11.6,16)]
	var offset := origin+Vector2(150,325)
	for r in rects: panel(menus,Rect2(offset+r.position*scale_,r.size*scale_),Color(.08,.13,.12),Color(.26,.36,.29))
	for spec in [["值班室",Vector2(-10,3)],["配电间",Vector2(-10,-8)],["病房",Vector2(-12,-22)],["冷库",Vector2(-11,-36)],["药房",Vector2(5,-3)],["B1 ↓",Vector2(7,-21)]]:
		text(menus,spec[0],offset+spec[1]*scale_,15,INK)
	text(menus,"EXIT ↓",offset+Vector2(-2,15)*scale_,16,ACCENT)
	var p: Vector3 = game.player.global_position
	text(menus,"◆",offset+Vector2(p.x,p.z)*scale_-Vector2(7,11),20,Color(.88,.61,.34))

func show_inventory() -> void:
	clear_modal("inventory")
	header("PERSONAL EFFECTS", "随身物品", "六格补给背包  /  关键道具独立保管")
	text(menus,"补给    %d / 6"%game.state.inventory.size(),Vector2(175,300),23,MUTED)
	for i in 6:
		var x := 175+(i%3)*296
		var y := 365+(i/3)*215
		panel(menus,Rect2(x,y,270,188))
		text(menus,str(i+1).pad_zeros(2),Vector2(x+20,y+14),17,MUTED)
		if i<game.state.inventory.size():
			var item: Dictionary = game.state.inventory[i]
			text(menus,"＋" if item.kind=="med" else "▰",Vector2(x+105,y+35),42,ACCENT)
			text(menus,"急救敷料" if item.kind=="med" else "9mm 弹药 × "+str(int(item.amount)),Vector2(x+35,y+105),23,INK)
			if item.kind=="med":
				button(menus,"使用  +55",Rect2(x+34,y+145,200,35),func():
					if game.state.heal(i): game.audio.one("pickup",-12); show_inventory()
					else: toast("目前不需要治疗"))
	text(menus,"重要物件",Vector2(1170,300),23,MUTED)
	var key_titles := {"cold_key":"冷库钥匙","lab_card":"地下通行卡","evidence":"雨蚀记录匣"}
	for i in game.state.keys.size():
		var key: String = game.state.keys[i]
		button(menus,"◇   "+key_titles[key]+"     检查 →",Rect2(1170,370+i*110,500,85),func(): show_inspect(key),true)
	if game.state.keys.is_empty(): text(menus,"还没有找到关键物件。",Vector2(1170,391),23,MUTED)
	paragraph(menus,"弹药在换弹时自动取用。\n关键物品无法丢弃，也不会占用补给格。\n\n当前生命  %d / 100"%game.state.health,Rect2(1170,740,510,150),21,MUTED)

func show_inspect(key: String) -> void:
	clear_modal("inspect")
	var names := {"cold_key":"冷库钥匙","lab_card":"地下通行卡","evidence":"雨蚀记录匣"}
	header("EXAMINE",names[key],"按住鼠标左键拖动，旋转检查物件。")
	var container := SubViewportContainer.new()
	container.position = Vector2(350,285)
	container.size = Vector2(1100,600)
	container.stretch = true
	menus.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(1100,600)
	vp.own_world_3d = true
	vp.transparent_bg = true
	container.add_child(vp)
	var scene := Node3D.new()
	vp.add_child(scene)
	var cam := Camera3D.new()
	cam.position = Vector3(0,.05,2)
	cam.fov = 35
	scene.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 2
	scene.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1,0,1)
	fill.light_color = Color(.35,.65,.75)
	fill.light_energy = 2
	scene.add_child(fill)
	inspect_object = Node3D.new()
	scene.add_child(inspect_object)
	var G = preload("res://tools/geometry.gd")
	var m := G.material(Color(.48,.43,.25),.25,.7)
	if key=="cold_key":
		G.cylinder(inspect_object,Vector3(0,.23,0),.12,.04,m).rotation.x = PI*.5
		G.cylinder(inspect_object,Vector3(0,.23,.023),.065,.004,G.material(Color(.02,.04,.04))).rotation.x = PI*.5
		G.box(inspect_object,Vector3(0,-.06,0),Vector3(.047,.47,.03),m)
		for y in [-.2,-.12]: G.box(inspect_object,Vector3(.052,y,0),Vector3(.1,.035,.03),m)
		G.label(inspect_object,"COLD / 09",Vector3(0,.245,.028),28,.0013)
	elif key=="lab_card":
		G.box(inspect_object,Vector3.ZERO,Vector3(.64,.41,.025),G.material(Color(.5,.59,.52)))
		G.box(inspect_object,Vector3(0,.105,.015),Vector3(.64,.06,.004),G.material(Color(.08,.2,.17)))
		G.label(inspect_object,"ST. VERONICA\nB1  /  09\n周 宁  ·  061",Vector3(0,-.035,.017),30,.002,Color(.035,.09,.065))
		G.label(inspect_object,"RESTRICTED",Vector3(0,0,-.017),28,.002,INK,PI)
	else:
		G.box(inspect_object,Vector3.ZERO,Vector3(.47,.32,.12),m)
		G.label(inspect_object,"RAINROT\nFINAL RECORD",Vector3(0,0,.062),30,.002,Color(.04,.08,.065))
	container.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT: inspect_drag=event.pressed
		if event is InputEventMouseMotion and inspect_drag and is_instance_valid(inspect_object):
			inspect_object.rotation.y+=event.relative.x*.01
			inspect_object.rotation.x+=event.relative.y*.01)
	button(menus,"返回背包",Rect2(700,875,450,55),show_inventory)

func show_puzzle(kind: String) -> void:
	clear_modal("puzzle_"+kind)
	match kind:
		"power":
			header("ENGINEERING / 019","西翼应急配电","先设置四条支路，再接通主回路。检修单就在配电间。")
			for i in 4:
				var x := 315+i*335
				panel(menus,Rect2(x,360,285,355))
				text(menus,["A  /  病房","B  /  冷库","C  /  药房","D  /  排水"][i],Vector2(x+32,395),28,INK)
				line(menus,Vector2(x+140,460),Vector2(x+140,545),ACCENT if game.state.breakers[i] else MUTED)
				button(menus,"ON  /  接通" if game.state.breakers[i] else "OFF  /  断开",Rect2(x+30,542,225,110),func(): game.state.breakers[i]=not game.state.breakers[i]; show_puzzle("power"),game.state.breakers[i])
			button(menus,"合上总闸",Rect2(660,770,600,70),func():
				if game.state.stage>0: toast("西翼供电已恢复")
				elif game.state.solve_power(): solved("西翼通电了。走廊深处，传来了一声脚步。")
				else: puzzle_feedback.text="回路过载 · 请按检修规程隔离故障支路。",true)
		"cabinet":
			puzzle_digits = ""
			header("PHARMACY / CONTROLLED","护士药柜","三位密码。交班记录给出顺序，病床观察卡给出数字。")
			panel(menus,Rect2(690,292,540,115),Color(.015,.03,.026))
			code_label = text(menus,"_  _  _",Vector2(833,305),54,ACCENT)
			for i in 9: button(menus,str(i+1),Rect2(690+(i%3)*185,438+(i/3)*92,170,77),func(): enter_digit(str(i+1)))
			button(menus,"清除",Rect2(690,714,170,77),func(): puzzle_digits=""; code_label.text="_  _  _")
			button(menus,"0",Rect2(875,714,170,77),func(): enter_digit("0"))
			button(menus,"确认",Rect2(1060,714,170,77),submit_code,true)
		"specimen":
			header("PATHOLOGY / ARCHIVE","标本归档终端","把三个编号归入相应组织。尸检索引就在解剖台上。")
			for i in 3:
				var x := 385+i*405
				panel(menus,Rect2(x,350,340,375))
				text(menus,["肺组织","神经束","培养体"][i],Vector2(x+104,390),29)
				text(menus,game.state.specimens[i],Vector2(x+107,478),77,ACCENT)
				button(menus,"切换标本  ↻",Rect2(x+30,625,280,65),func():
					var values := ["09","14","23"]
					game.state.specimens[i]=values[(values.find(game.state.specimens[i])+1)%3]
					show_puzzle("specimen"))
			button(menus,"提交归档",Rect2(660,780,600,65),func():
				if game.state.stage>=3: toast("归档已完成，通行卡已领取")
				elif game.state.solve_specimens(): solved("归档完成 · 获得地下通行卡。西翼的灯忽然熄灭了。")
				else: puzzle_feedback.text="组织类型不匹配 · 请核对尸检与标本索引。",true)
		"terminal":
			header("RAINROT / TERMINATION","培养循环控制台","终止循环后，隔离门将进入疏散模式。")
			paragraph(menus,"[color=#9caf8f]项目 09  /  当前状态：运行中[/color]\n\n地下约束装置与培养循环共用电源。\n终止程序将解除后院封锁，同时停止约束装置供电。\n\n记录匣将随终止程序一并释放。\n请记住来时的路。",Rect2(480,320,1000,380),29)
			button(menus,"查看终止记录",Rect2(480,740,430,75),func(): game.read_note("lab"))
			button(menus,"终止循环 · 带走记录匣",Rect2(940,740,500,75),func():
				if game.state.stage==3:
					game.save_game()
					game.state.terminate()
					solved("隔离解除。它醒了。沿绿色出口灯，立即离开！")
				elif game.state.stage==4: close(),true)
		_: close(); return
	puzzle_feedback = text(menus,"",Vector2(380,884),22,Color(.78,.54,.36))
	puzzle_feedback.size = Vector2(1160,45)
	puzzle_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func enter_digit(value: String) -> void:
	if puzzle_digits.length()<3: puzzle_digits+=value
	code_label.text = "  ".join(puzzle_digits.split(""))

func submit_code() -> void:
	if game.state.stage>=2:
		toast("药柜已打开，冷库钥匙在你的背包中")
		return
	if game.state.solve_cabinet(puzzle_digits): solved("药柜打开了 · 获得冷库钥匙")
	else:
		puzzle_feedback.text = "密码错误 · 按处置顺序读取床号末位。"
		puzzle_digits = ""
		code_label.text = "_  _  _"

func solved(message: String) -> void:
	hint_level = 0
	game.advance_stage()
	close()
	toast(message,7)

func show_death() -> void:
	clear_modal("death")
	rect(menus,Rect2(0,0,1920,1080),Color(.017,.008,.008,.88))
	text(menus,"你留在了雨里",Vector2(688,366),58,Color(.64,.5,.43))
	text(menus,"THE WARD REMEMBERS",Vector2(762,473),21,MUTED)
	button(menus,"从最近记录醒来",Rect2(710,640,500,70),func(): game.load_game(),true)
	button(menus,"返回主菜单",Rect2(710,733,500,60),func(): game.return_to_menu())

func show_ending() -> void:
	clear_modal("ending")
	rect(menus,Rect2(0,0,1920,1080),Color(.009,.025,.027,.87))
	text(menus,"C H A P T E R   C O M P L E T E",Vector2(684,195),23,ACCENT)
	text(menus,"雨还在下",Vector2(765,290),70,INK)
	paragraph(menus,"你带着记录匣走出了疗养院。\n\n周宁的声音停在了磁带里。\n山下的灯光还亮着。\n\n但排水沟里的水，正缓慢地流向那里。",Rect2(660,420,680,300),29)
	text(menus,"调查用时  %02d:%02d    /    档案  %d / %d    /    发射  %d 发"%[int(game.state.seconds)/60,int(game.state.seconds)%60,game.state.notes.size(),WardContent.NOTES.size(),game.state.shots],Vector2(595,780),23,MUTED)
	button(menus,"回到雨夜",Rect2(710,878,500,65),func(): game.return_to_menu(),true)

func toast(value: String, duration: float=4.5) -> void:
	notification.text = value
	notice_time = duration

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"): game.toggle_fullscreen()
	if event.is_action_pressed("pause"):
		if modal in ["death","ending","menu"]: return
		if modal=="": show_pause()
		else: close()
		get_viewport().set_input_as_handled()
	if game.started and event.is_action_pressed("inventory"):
		if modal=="": show_inventory()
		elif modal=="inventory": close()
		get_viewport().set_input_as_handled()
	if game.started and event.is_action_pressed("journal"):
		if modal=="": show_journal()
		elif modal=="journal": close()
		get_viewport().set_input_as_handled()
	if modal=="puzzle_cabinet" and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_0 and event.keycode<=KEY_9: enter_digit(str(event.keycode-KEY_0))
		if event.keycode==KEY_ENTER: submit_code()
		if event.keycode==KEY_BACKSPACE:
			puzzle_digits = puzzle_digits.left(maxi(0,puzzle_digits.length()-1))
			code_label.text = "  ".join(puzzle_digits.split("")) if puzzle_digits else "_  _  _"

func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	notice_time = maxf(0,notice_time-delta)
	notification.modulate.a = minf(1,notice_time)
	hit_confirm = maxf(0,hit_confirm-delta)
	post.material.set_shader_parameter("hurt",minf(1,game.player.hurt_left*.8+(1-game.state.health/100)*.4))
	post.material.set_shader_parameter("brightness",game.settings.brightness)
	if modal=="" and game.started:
		room_label.text = WardContent.room_at(game.player.global_position)
		objective_label.text = WardContent.OBJECTIVES[game.state.stage]
		prompt_label.text = "[ E ]   "+game.player.target.prompt() if is_instance_valid(game.player.target) else ""
		crosshair.text = "×" if hit_confirm>0 else ("◇" if is_instance_valid(game.player.target) else "·")
		health_label.text = "%03d   %s"%[int(game.state.health),"稳定" if game.state.health>60 else ("受伤" if game.state.health>30 else "危险")]
		health_label.modulate = Color(.9,.47,.35) if game.state.health<35 else Color.WHITE
		ammo_label.text = "%02d   /   %02d"%[game.state.magazine,game.state.reserve()] if game.player.reload_left<=0 else "装填中…"
		stamina_bar.size.x = 267*game.player.stamina/100
