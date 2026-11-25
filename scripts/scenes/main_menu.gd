extends Control
## Screen 1 · 菜单: candy-style sentence grid + practice/challenge segmented switch.

var _grid: GridContainer
var _seg_panel: PanelContainer
var _seg_box: HBoxContainer


func _ready() -> void:
	GameData.sentences_loaded.connect(_build_grid)
	_build()
	_build_grid()


func _build() -> void:
	# cream background with soft radial feel (two layered rects)
	var bg := ColorRect.new()
	bg.color = UiKit.CREAM_2
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var bg2 := ColorRect.new()
	bg2.color = Color(1, 1, 1, 0.35)
	bg2.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg2.anchor_right = 0.7
	bg2.anchor_bottom = 0.6
	add_child(bg2)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_left", 48)
	wrap.add_theme_constant_override("margin_right", 48)
	wrap.add_theme_constant_override("margin_top", 28)
	wrap.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(wrap)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	wrap.add_child(vb)

	# topbar pills
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UiKit.pill("Junn杰俊 · 语法学习", UiKit.INK, Color.WHITE, 22))
	top.add_child(UiKit.pill("Godot 4 · 糖果风", UiKit.MINT, UiKit.INK, 22))
	vb.add_child(top)

	# big title
	vb.add_child(UiKit.label("长句组块贪吃蛇", 84, UiKit.INK))
	vb.add_child(UiKit.label("按语法成分切块的句子,按顺序吃掉每一块 —— 吃对长身体,吃错要重来。", 26, UiKit.INK_SOFT))

	# mode row: label + segmented control
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 18)
	mode_row.add_child(UiKit.label("选择模式", 26, UiKit.INK))
	_seg_panel = _segmented()
	mode_row.add_child(_seg_panel)
	vb.add_child(mode_row)

	# sentence grid header
	var head := HBoxContainer.new()
	head.add_child(UiKit.label("选一句开始", 30, UiKit.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UiKit.label("%d 句 · 英汉双语 · 点卡片即玩" % GameData.sentences.size(), 20, Color("9a9fae")))
	vb.add_child(head)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	vb.add_child(_grid)

	# foot
	var foot := HBoxContainer.new()
	foot.add_child(UiKit.label("桌面 1440×900 · 手机竖屏 390×844 自动适配", 20, Color("a2a6b3")))
	vb.add_child(foot)


func _segmented() -> Control:
	var seg := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = UiKit.PAPER
	s.set_corner_radius_all(16)
	s.shadow_color = Color(0.09, 0.11, 0.16, 0.14)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	seg.add_theme_stylebox_override("panel", s)
	_seg_box = HBoxContainer.new()
	_seg_box.add_theme_constant_override("separation", 4)
	seg.add_child(_seg_box)
	_fill_seg()
	return seg


func _fill_seg() -> void:
	for c in _seg_box.get_children():
		c.queue_free()
	for i in 2:
		var practice := i == 0
		var active := GameData.practice_mode == practice
		var b := Button.new()
		b.custom_minimum_size = Vector2(190, 76)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(UiKit.label("练习模式" if practice else "挑战模式", 26, Color.WHITE if active else UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
		vb.add_child(UiKit.label("答错提醒" if practice else "答错扣命", 18, UiKit.MINT if active else UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(vb)
		b.add_theme_stylebox_override("normal", _seg_box_style(active))
		b.add_theme_stylebox_override("hover", _seg_box_style(active))
		b.add_theme_stylebox_override("pressed", _seg_box_style(active))
		b.add_theme_stylebox_override("focus", _seg_box_style(active))
		var p := practice
		b.pressed.connect(func(): _set_mode(p))
		_seg_box.add_child(b)


func _seg_box_style(active: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = UiKit.INK if active else Color(0, 0, 0, 0)
	st.set_corner_radius_all(12)
	return st


func _set_mode(practice: bool) -> void:
	GameData.practice_mode = practice
	Sfx.click()
	_fill_seg()


func _build_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var colors: Array = [UiKit.MINT, UiKit.PINK, UiKit.YELLOW, UiKit.BLUE, UiKit.PURPLE, UiKit.ORANGE, UiKit.TEAL, UiKit.GREEN, UiKit.MINT, UiKit.PINK]
	for i in GameData.sentences.size():
		var s: Dictionary = GameData.sentences[i]
		var card := UiKit.sentence_card(i, GameData.sentences.size(), s.get("en", ""), s.get("zh", ""), colors[i % colors.size()])
		var idx := i
		card.pressed.connect(func():
			Sfx.click()
			GameData.current_index = idx
			get_tree().change_scene_to_file("res://scenes/prepare.tscn"))
		_grid.add_child(card)
