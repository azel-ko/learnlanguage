extends Control
## Screen 4 · 结构: grammar tree of the current sentence (attach relations).

var _canvas: Control


func _ready() -> void:
	_build()
	_canvas.queue_redraw()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 40
	vb.offset_top = 30
	vb.offset_right = -40
	vb.offset_bottom = -30
	vb.add_theme_constant_override("separation", 14)
	add_child(vb)

	vb.add_child(UiKit.label("语法树 · 第 %d 句" % (GameData.current_index + 1), 48, UiKit.PINK))
	vb.add_child(UiKit.label(GameData.sentence().get("en", ""), 26, UiKit.INK))

	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.draw.connect(_draw_tree)
	vb.add_child(_canvas)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	for role in ["S", "V", "O", "Attr", "Adv", "Clause"]:
		var l := UiKit.label("● %s" % role, 22, UiKit.ROLE_COLORS.get(role, UiKit.INK))
		legend.add_child(l)
	vb.add_child(legend)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var back := UiKit.candy_button("◀ 返回游戏", 28, UiKit.PAPER, UiKit.INK)
	back.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/game.tscn"))
	row.add_child(back)
	var replay := UiKit.candy_button("再玩一次", 28, UiKit.MINT, UiKit.INK)
	replay.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/game.tscn"))
	row.add_child(replay)
	vb.add_child(row)


func _chunk_rects() -> Array:
	## Lay chunks left→right in sentence order, wrap into rows if needed.
	var chunks: Array = GameData.sentence().get("chunks", [])
	var w := _canvas.size.x
	var rects: Array = []
	var x := 20.0
	var y := 20.0
	var row_h := 0.0
	for c in chunks:
		var txt: String = c.get("en", "")
		var fs := 24
		var f := UiKit.font()
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 44
		var th := 64.0
		if x + tw > w - 20 and x > 30:
			x = 20.0
			y += row_h + 90
			row_h = 0
		rects.append(Rect2(x, y, tw, th))
		x += tw + 30
		row_h = maxf(row_h, th)
	return rects


func _draw_tree() -> void:
	var chunks: Array = GameData.sentence().get("chunks", [])
	var rects := _chunk_rects()
	var f := UiKit.font()

	# edges first (attach -> child)
	for i in chunks.size():
		var att: int = chunks[i].get("attach", -1)
		if att < 0 or att >= rects.size() or i >= rects.size():
			continue
		var a: Rect2 = rects[att]
		var b: Rect2 = rects[i]
		var p0 := a.get_center()
		var p1 := Vector2(b.position.x, b.get_center().y)
		_canvas.draw_line(p0, p1, Color(0.5, 0.45, 0.55, 0.6), 3.0)
		_canvas.draw_circle(p1, 6, UiKit.ROLE_COLORS.get(chunks[i].get("role", ""), UiKit.INK))

	# nodes
	for i in chunks.size():
		var c: Dictionary = chunks[i]
		var r: Rect2 = rects[i]
		var role: String = c.get("role", "S")
		var col: Color = UiKit.ROLE_COLORS.get(role, UiKit.INK)
		_canvas.draw_rect(r, UiKit.PAPER, true)
		_canvas.draw_rect(r, col, false, 4.0)
		_canvas.draw_rect(Rect2(r.position, Vector2(12, r.size.y)), col, true)
		_canvas.draw_string(f, r.position + Vector2(26, r.size.y * 0.5 + 9), c.get("en", ""), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, 24, UiKit.INK)
		_canvas.draw_string(f, Vector2(r.position.x + 14, r.end.y + 26), "%s · %s" % [c.get("role", ""), c.get("zh", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.45, 0.4, 0.5))
