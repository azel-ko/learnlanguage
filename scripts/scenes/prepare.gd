extends Control
## Screen 2 · 准备: section-head + prepare card + chunk pills.


func _ready() -> void:
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		wrap.add_theme_constant_override("margin_" + side, 56)
	wrap.add_theme_constant_override("margin_top", 30)
	wrap.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(wrap)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 18)
	wrap.add_child(vb)

	var s := GameData.sentence()

	# section head: step badge + title + EN label
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = UiKit.GREEN
	bs.set_corner_radius_all(14)
	bs.shadow_color = Color(0, 0, 0, 0.12)
	bs.shadow_size = 6
	bs.shadow_offset = Vector2(0, 4)
	bs.content_margin_left = 18
	bs.content_margin_right = 18
	bs.content_margin_top = 8
	bs.content_margin_bottom = 8
	badge.add_theme_stylebox_override("panel", bs)
	badge.add_child(UiKit.label("1", 40, Color("1f5a26"), HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(badge)
	var ht := VBoxContainer.new()
	ht.add_child(UiKit.label("准备 · 记住词块顺序", 40, UiKit.INK))
	ht.add_child(UiKit.label("蛇会按这个顺序吃块,吃对一块长一节。", 22, UiKit.INK_SOFT))
	head.add_child(ht)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UiKit.label("SETUP", 22, Color("b6bac7")))
	vb.add_child(head)

	# prepare card
	var card := UiKit.panel(UiKit.PAPER, 24)
	vb.add_child(card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 18)
	card.add_child(cv)

	# sentence block with yellow left tag
	var sent := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0)
	sent.add_theme_stylebox_override("panel", ss)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sent.add_child(sv)
	var tag := UiKit.pill("原句", UiKit.YELLOW, UiKit.INK, 20)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sv.add_child(tag)
	sv.add_child(UiKit.label(s.get("en", ""), 34, UiKit.INK))
	sv.add_child(UiKit.label(s.get("zh", ""), 24, UiKit.INK_SOFT))
	# yellow left border via a thin ColorRect behind
	var sent_wrap := PanelContainer.new()
	var sws := StyleBoxFlat.new()
	sws.bg_color = UiKit.PAPER
	sws.border_width_left = 8
	sws.border_color = UiKit.YELLOW
	sws.content_margin_left = 20
	sws.content_margin_top = 4
	sws.content_margin_bottom = 4
	sent_wrap.add_theme_stylebox_override("panel", sws)
	sent_wrap.add_child(sent)
	cv.add_child(sent_wrap)

	cv.add_child(UiKit.label("按顺序吃的词块(共 %d 块):" % s.get("chunks", []).size(), 26, UiKit.INK))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	cv.add_child(flow)
	var chunks: Array = s.get("chunks", [])
	for i in chunks.size():
		var c: Dictionary = chunks[i]
		var pill := UiKit.chunk_pill(i + 1, c.get("en", ""), c.get("role", "S"))
		pill.tooltip_text = "%s" % c.get("zh", "")
		flow.add_child(pill)

	cv.add_child(UiKit.label("提示:蛋糕上的贴纸永远水平可读;一块一词,先认清顺序再开局。", 20, Color("a2a6b3")))

	# buttons
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	var back := UiKit.candy_button("← 返回菜单", 28, UiKit.PAPER, UiKit.INK)
	back.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(back)
	var go := UiKit.candy_button("开始游戏 →", 30, UiKit.YELLOW, UiKit.INK)
	go.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/game.tscn"))
	row.add_child(go)
	vb.add_child(row)
