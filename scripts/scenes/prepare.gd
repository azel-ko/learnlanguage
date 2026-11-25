extends Control
## Screen 2 · 准备: preview the chunk order and the Chinese meaning before playing.


func _ready() -> void:
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var s := GameData.sentence()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := UiKit.panel(UiKit.PAPER, 32)
	card.custom_minimum_size = Vector2(920, 0)
	center.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.custom_minimum_size = Vector2(880, 0)
	card.add_child(vb)

	vb.add_child(UiKit.label("准备 · 记住词块顺序", 44, UiKit.PINK_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UiKit.label(s.get("en", ""), 30, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))

	var zh_panel := UiKit.panel(UiKit.BUTTER, 18)
	zh_panel.add_child(UiKit.label("中文句意:%s" % s.get("zh", ""), 26, UiKit.INK))
	vb.add_child(zh_panel)

	vb.add_child(UiKit.label("按顺序吃的词块(共 %d 块):" % s.get("chunks", []).size(), 26, UiKit.INK))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	vb.add_child(flow)
	var chunks: Array = s.get("chunks", [])
	for i in chunks.size():
		var c: Dictionary = chunks[i]
		var st := UiKit.sticker("%d. %s" % [i + 1, c.get("en", "")], c.get("role", "S"), 24)
		st.tooltip_text = "%s — %s" % [c.get("zh", ""), c.get("role", "")]
		flow.add_child(st)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	var back := UiKit.candy_button("◀ 返回菜单", 28, UiKit.LAV, UiKit.INK)
	back.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	btn_row.add_child(back)
	var go := UiKit.candy_button("进入游戏 ▶", 32, UiKit.PINK_DARK)
	go.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/game.tscn"))
	btn_row.add_child(go)
	vb.add_child(btn_row)
