extends Control
## Screen 1 · 菜单: pick a sentence, pick 练习/挑战 mode, start.

var _sent_lbl: Label
var _mode_btns: Array[Button] = []


func _ready() -> void:
	GameData.sentences_loaded.connect(_refresh)
	_build()
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := UiKit.panel(UiKit.PAPER, 32)
	card.custom_minimum_size = Vector2(860, 0)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	vb.custom_minimum_size = Vector2(820, 0)
	card.add_child(vb)

	vb.add_child(UiKit.label("长句组块贪吃蛇", 64, UiKit.PINK_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UiKit.label("Grammar Snake · 托福衔接班语法练习", 26, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UiKit.label("蛇按句子顺序吃语法词块,吃对变长加分,吃错要看模式!", 22, Color(0.45, 0.4, 0.45), HORIZONTAL_ALIGNMENT_CENTER))

	# sentence picker
	var pick := HBoxContainer.new()
	pick.alignment = BoxContainer.ALIGNMENT_CENTER
	pick.add_theme_constant_override("separation", 16)
	var prev := UiKit.candy_button("◀ 上一句", 26, UiKit.LAV, UiKit.INK)
	prev.pressed.connect(func(): GameData.current_index = wrapi(GameData.current_index - 1, 0, GameData.sentences.size()); _refresh())
	pick.add_child(prev)
	_sent_lbl = UiKit.label("", 30, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	_sent_lbl.custom_minimum_size = Vector2(430, 0)
	pick.add_child(_sent_lbl)
	var next := UiKit.candy_button("下一句 ▶", 26, UiKit.LAV, UiKit.INK)
	next.pressed.connect(func(): GameData.current_index = wrapi(GameData.current_index + 1, 0, GameData.sentences.size()); _refresh())
	pick.add_child(next)
	vb.add_child(pick)

	# mode toggle
	var mode_row := HBoxContainer.new()
	mode_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_row.add_theme_constant_override("separation", 20)
	for m in [true, false]:
		var b := UiKit.candy_button("练习模式" if m else "挑战模式", 28)
		b.toggle_mode = true
		b.pressed.connect(func(): _set_mode(m))
		_mode_btns.append(b)
		mode_row.add_child(b)
	vb.add_child(mode_row)
	_mode_btns[0].button_pressed = true
	_mode_btns[0].toggled.emit(true)

	var start := UiKit.candy_button("开始游戏 ▶", 36, UiKit.PINK_DARK)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/prepare.tscn"))
	vb.add_child(start)

	vb.add_child(UiKit.label("桌面 1440×900 / 手机竖屏 390×844 自动适配 · 数据即 data/sentences.json", 18, Color(0.55, 0.5, 0.55), HORIZONTAL_ALIGNMENT_CENTER))


func _set_mode(practice: bool) -> void:
	GameData.practice_mode = practice
	for i in _mode_btns.size():
		_mode_btns[i].button_pressed = (i == 0) == practice


func _refresh() -> void:
	var s := GameData.sentence()
	if s.is_empty():
		_sent_lbl.text = "(无句子数据)"
		return
	_sent_lbl.text = "第 %d / %d 句 · %s" % [GameData.current_index + 1, GameData.sentences.size(), s.get("zh", "")]
