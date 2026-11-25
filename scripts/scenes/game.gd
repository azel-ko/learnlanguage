extends Control
## Screen 3 · 游戏: snake eats grammar chunks in sentence order.
## Candy/toy-vinyl skin: dark board, cupcake food, sticker labels.
## Test hooks: hook_start / hook_set_dir / hook_eat_next / hook_wrong / hook_stats.

const COLS := 24
const ROWS := 16
const BASE_INTERVAL := 0.26
const MIN_INTERVAL := 0.11
const SPEED_STEP := 0.014
const START_LIVES := 3

enum State { COUNTDOWN, PLAY, PAUSE, OVER, COMPLETE }

var state := State.COUNTDOWN
var grid := Vector2i(COLS, ROWS)
var cell_px := 40.0
var board_rect := Rect2()

var snake: Array[Vector2i] = []
var dir := Vector2i.RIGHT
var dir_queue: Array[Vector2i] = []
var foods := {}            # Vector2i cell -> chunk index (ALL chunks placed at start)
var next_idx := 0          # target chunk index = next to eat
var eaten := 0
var score := 0
var combo := 0
var lives := START_LIVES
var wrong_count := 0
var elapsed := 0.0
var move_acc := 0.0
var move_interval := BASE_INTERVAL
var stun_t := 0.0
var invuln_t := 0.0
var count_t := 0.0
var ripples: Array = []     # {pos, t}
var popups: Array = []      # {text,pos,t,color}
var snake_labels: Array[int] = []

var _board: Control
var _hud_chips := {}
var _zh_panel: PanelContainer
var _zh_text: Label
var _countdown: Control
var _count_label: Label
var _great: Control
var _great_label: Label
var _warn: PanelContainer
var _warn_text: Label
var _warn_cb := Callable()
var _pause_veil: Control
var _touch_pad: GridContainer
var _foot: PanelContainer
var _result_panel: PanelContainer
var _pause_btn: Button
var _menu_btn: Button
var _touch_start := Vector2.ZERO

# cached styleboxes for board drawing
var _sb_seg_a: StyleBoxFlat
var _sb_seg_b: StyleBoxFlat
var _sb_head: StyleBoxFlat
var _sb_sticker: StyleBoxFlat


func _ready() -> void:
	_build_ui()
	_start_sentence()
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


# ------------------------------------------------------------------ styles

func _seg_style(a: Color, b: Color, radius_ratio := 0.30) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = a
	s.set_corner_radius_all(int(cell_px * radius_ratio))
	s.border_color = b
	s.set_border_width_all(2)
	return s


func _make_cached_styles() -> void:
	_sb_seg_a = _seg_style(UiKit.MINT.lightened(0.15), UiKit.MINT.darkened(0.2))
	_sb_seg_b = _seg_style(Color("6fc79a"), Color("4d9a76"))
	_sb_head = _seg_style(UiKit.GREEN, UiKit.GREEN.darkened(0.25), 0.34)
	_sb_sticker = StyleBoxFlat.new()
	_sb_sticker.bg_color = Color.WHITE
	_sb_sticker.set_corner_radius_all(8)
	_sb_sticker.shadow_color = Color(0, 0, 0, 0.35)
	_sb_sticker.shadow_size = 4
	_sb_sticker.shadow_offset = Vector2(0, 3)


# ------------------------------------------------------------------ UI build

func _build_ui() -> void:
	# dark game background
	var bg := ColorRect.new()
	bg.color = UiKit.BOARD
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_build_hud()
	_build_board()
	_build_zh_panel()
	_build_overlays()
	_build_touch_pad()
	_build_foot()

	gui_input.connect(_on_gui_input)
	_make_cached_styles()


func _build_hud() -> void:
	var hud := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = UiKit.HUD_BG
	hs.border_width_bottom = 3
	hs.border_color = Color("232733")
	hs.content_margin_left = 16
	hs.content_margin_right = 16
	hs.content_margin_top = 8
	hs.content_margin_bottom = 8
	hud.add_theme_stylebox_override("panel", hs)
	hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud.offset_bottom = 66
	add_child(hud)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hud.add_child(hb)

	_hud_chips["mode"] = _chip_node("练习", UiKit.CHIP_BG, UiKit.CHIP_TEXT)
	_hud_chips["prog"] = _chip_node("0 / 0", UiKit.CHIP_BG, UiKit.CHIP_TEXT)
	_hud_chips["score"] = _chip_node("0 分", UiKit.YELLOW, Color("4a3800"))
	_hud_chips["time"] = _chip_node("00:00", UiKit.CHIP_BG, UiKit.CHIP_TEXT)
	_hud_chips["lives"] = _chip_node("", UiKit.CHIP_BG, UiKit.CHIP_TEXT)
	for k in ["mode", "prog", "score", "time", "lives"]:
		hb.add_child(_hud_chips[k])

	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)

	_pause_btn = _hud_button("Ⅱ")
	_pause_btn.pressed.connect(_toggle_pause)
	hb.add_child(_pause_btn)
	_menu_btn = _hud_button("☰")
	_menu_btn.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	hb.add_child(_menu_btn)


func _chip_node(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var l := UiKit.label(text, 24, fg, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "T"
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	return p


func _chip_set(key: String, text: String) -> void:
	var p: PanelContainer = _hud_chips[key]
	(p.get_node("T") as Label).text = text


func _hud_button(glyph: String) -> Button:
	var b := Button.new()
	b.text = glyph
	b.custom_minimum_size = Vector2(38, 38)
	b.add_theme_font_override("font", UiKit.font())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _hud_btn_style(UiKit.CHIP_BG))
	b.add_theme_stylebox_override("hover", _hud_btn_style(UiKit.CHIP_BG.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", _hud_btn_style(UiKit.CHIP_BG.darkened(0.1)))
	b.add_theme_stylebox_override("focus", _hud_btn_style(UiKit.CHIP_BG))
	return b


func _hud_btn_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(11)
	return s


func _build_board() -> void:
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.offset_top = 66
	_board.offset_bottom = -28
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	add_child(_board)


func _build_zh_panel() -> void:
	_zh_panel = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.12, 0.17, 0.82)
	s.set_corner_radius_all(14)
	s.border_color = Color(1, 1, 1, 0.12)
	s.set_border_width_all(2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 5)
	_zh_panel.add_theme_stylebox_override("panel", s)
	_zh_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_zh_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_zh_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	_zh_panel.add_child(vb)
	vb.add_child(UiKit.label("句 意", 18, UiKit.YELLOW))
	_zh_text = UiKit.label("", 24, Color("eef2fa"))
	_zh_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zh_text.custom_minimum_size = Vector2(280, 0)
	vb.add_child(_zh_text)


func _build_overlays() -> void:
	# countdown
	_countdown = Control.new()
	_countdown.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown.offset_top = 66
	_countdown.offset_bottom = -28
	_countdown.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.09, 0.13, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown.add_child(dim)
	_count_label = UiKit.label("3", 150, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_count_label.set_anchors_preset(Control.PRESET_CENTER)
	_count_label.offset_left = -120
	_count_label.offset_top = -110
	_count_label.offset_right = 120
	_count_label.offset_bottom = 110
	# yellow underline shadow via a second label offset
	var shadow := UiKit.label("", 150, UiKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	shadow.set_anchors_preset(Control.PRESET_CENTER)
	shadow.offset_left = -120
	shadow.offset_top = -100
	shadow.offset_right = 120
	shadow.offset_bottom = 120
	shadow.name = "Shadow"
	_countdown.add_child(shadow)
	_countdown.add_child(_count_label)
	add_child(_countdown)

	# Great!
	_great = Control.new()
	_great.set_anchors_preset(Control.PRESET_FULL_RECT)
	_great.offset_top = 66
	_great.offset_bottom = -28
	_great.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_great.visible = false
	var gv := VBoxContainer.new()
	gv.set_anchors_preset(Control.PRESET_CENTER)
	gv.offset_left = -200
	gv.offset_top = -90
	gv.offset_right = 200
	gv.offset_bottom = 90
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	_great.add_child(gv)
	_great_label = UiKit.label("Great!", 84, UiKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER)
	gv.add_child(_great_label)
	gv.add_child(UiKit.label("吃对啦", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_great)

	# warn modal (practice mode wrong eat)
	var wdim := ColorRect.new()
	wdim.color = Color(0.08, 0.09, 0.13, 0.55)
	wdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	wdim.offset_top = 66
	wdim.offset_bottom = -28
	wdim.visible = false
	wdim.name = "WarnDim"
	add_child(wdim)
	_warn = UiKit.panel(UiKit.CREAM, 22)
	_warn.set_anchors_preset(Control.PRESET_CENTER)
	_warn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warn.grow_vertical = Control.GROW_DIRECTION_BOTH
	_warn.offset_left = -190
	_warn.offset_top = -120
	_warn.offset_right = 190
	_warn.offset_bottom = 120
	_warn.visible = false
	add_child(_warn)
	var wvb := VBoxContainer.new()
	wvb.alignment = BoxContainer.ALIGNMENT_CENTER
	wvb.add_theme_constant_override("separation", 12)
	_warn.add_child(wvb)
	var bang := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = UiKit.PINK
	bs.set_corner_radius_all(999)
	bs.content_margin_left = 20
	bs.content_margin_right = 20
	bs.content_margin_top = 8
	bs.content_margin_bottom = 8
	bang.add_theme_stylebox_override("panel", bs)
	bang.add_child(UiKit.label("!", 44, Color("8a2b51"), HORIZONTAL_ALIGNMENT_CENTER))
	wvb.add_child(bang)
	wvb.add_child(UiKit.label("顺序不对", 40, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	_warn_text = UiKit.label("", 24, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	_warn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wvb.add_child(_warn_text)
	var ok := UiKit.candy_button("知道了", 26, UiKit.YELLOW, UiKit.INK)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(_hide_warn)
	wvb.add_child(ok)

	# pause veil
	_pause_veil = Control.new()
	_pause_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_veil.offset_top = 66
	_pause_veil.offset_bottom = -28
	_pause_veil.visible = false
	var pdim := ColorRect.new()
	pdim.color = Color(0.08, 0.09, 0.13, 0.6)
	pdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_veil.add_child(pdim)
	var pv := VBoxContainer.new()
	pv.set_anchors_preset(Control.PRESET_CENTER)
	pv.offset_left = -200
	pv.offset_top = -80
	pv.offset_right = 200
	pv.offset_bottom = 80
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_veil.add_child(pv)
	pv.add_child(UiKit.label("已暂停", 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	pv.add_child(UiKit.label("按 P / Esc 或点击按钮继续", 24, Color("b9c0d0"), HORIZONTAL_ALIGNMENT_CENTER))
	add_child(_pause_veil)


func _build_touch_pad() -> void:
	_touch_pad = GridContainer.new()
	_touch_pad.columns = 3
	_touch_pad.add_theme_constant_override("h_separation", 6)
	_touch_pad.add_theme_constant_override("v_separation", 6)
	_touch_pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_touch_pad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_touch_pad.offset_right = -16
	_touch_pad.offset_bottom = -44
	_touch_pad.visible = false
	# layout: row1 [_,up,_], row2 [left,_,right], row3 [_,down,_]
	var cells := [
		["", null], ["▲", Vector2i.UP], ["", null],
		["◀", Vector2i.LEFT], ["", null], ["▶", Vector2i.RIGHT],
		["", null], ["▼", Vector2i.DOWN], ["", null],
	]
	for c in cells:
		var glyph: String = c[0]
		var d = c[1]
		if glyph == "":
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(46, 46)
			_touch_pad.add_child(sp)
			continue
		var b := Button.new()
		b.text = glyph
		b.custom_minimum_size = Vector2(46, 46)
		b.add_theme_font_override("font", UiKit.font())
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_stylebox_override("normal", _touch_btn_style(Color(1, 1, 1, 0.16)))
		b.add_theme_stylebox_override("hover", _touch_btn_style(Color(1, 1, 1, 0.25)))
		b.add_theme_stylebox_override("pressed", _touch_btn_style(UiKit.YELLOW))
		b.add_theme_color_override("font_pressed_color", UiKit.INK)
		var dd: Vector2i = d
		b.pressed.connect(func(): _input_dir(dd))
		_touch_pad.add_child(b)
	add_child(_touch_pad)


func _touch_btn_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(12)
	return s


func _build_foot() -> void:
	_foot = PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = UiKit.FOOT_BG
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	_foot.add_theme_stylebox_override("panel", s)
	_foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_foot.offset_top = -28
	add_child(_foot)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_foot.add_child(hb)
	hb.add_child(UiKit.label("方向键 / WASD / 滑动 / 方向按钮 控制蛇", 18, Color("8e96a8")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(UiKit.label("P / Esc 暂停", 18, Color("8e96a8")))


func _layout() -> void:
	if _board == null or _zh_panel == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var avail := Rect2(0, 66, vs.x, vs.y - 66 - 28)
	# keep meaning panel from covering board bottom-left when computing cell size
	var cell := minf(avail.size.x / COLS, avail.size.y / ROWS)
	var gw := cell * COLS
	var gh := cell * ROWS
	board_rect = Rect2(
		avail.position + (avail.size - Vector2(gw, gh)) * 0.5,
		Vector2(gw, gh))
	cell_px = cell
	_zh_panel.position = Vector2(16, vs.y - 28 - _zh_panel.size.y - 16)
	_zh_panel.reset_size()
	# touch pad only on narrow screens
	_touch_pad.visible = vs.x < 700
	_board.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


# ------------------------------------------------------------- game setup

func _start_sentence() -> void:
	var s := GameData.sentence()
	if s.is_empty():
		push_error("no sentence data")
		return
	snake.clear()
	snake_labels.clear()
	foods.clear()
	next_idx = 0
	eaten = 0
	score = 0
	combo = 0
	wrong_count = 0
	elapsed = 0.0
	move_acc = 0.0
	move_interval = BASE_INTERVAL
	stun_t = 0.0
	invuln_t = 0.0
	ripples.clear()
	popups.clear()
	lives = START_LIVES
	state = State.COUNTDOWN
	count_t = 3.0
	dir = Vector2i.RIGHT
	dir_queue.clear()

	# snake[0] is the HEAD; dir == RIGHT so head is the RIGHTMOST cell.
	var cy := grid.y / 2
	var cx := grid.x / 4
	for i in 3:
		snake.push_back(Vector2i(cx - i, cy))
		snake_labels.push_back(-1)

	_place_foods()

	_chip_set("mode", "练习" if GameData.practice_mode else "挑战")
	_chip_set("score", "0 分")
	_chip_set("time", "00:00")
	_chip_set("lives", "")
	_zh_text.text = s.get("zh", "")
	_result_panel_setup_hide()
	_hide_warn()
	_pause_veil.visible = false
	_show_countdown()
	_update_hud()


func _result_panel_setup_hide() -> void:
	if _result_panel != null:
		_result_panel.visible = false


## Place ALL chunk cupcakes on the board once (like the web reference):
## random free cells, excluding the snake, duplicates, and the bottom-left
## zone reserved for the meaning panel.
func _place_foods() -> void:
	foods.clear()
	var chunks: Array = GameData.sentence().get("chunks", [])
	var occupied := {}
	for p in snake:
		occupied[p] = true
	for ci in chunks.size():
		var cell := Vector2i(-1, -1)
		for _try in 500:
			var c := Vector2i(randi() % grid.x, randi() % grid.y)
			# reserved: bottom-left meaning-panel area
			if c.x < grid.x * 0.45 and c.y >= grid.y - 4:
				continue
			if occupied.has(c) or foods.has(c):
				continue
			cell = c
			break
		if cell.x < 0:
			# fallback: scan for any free cell
			for y in grid.y:
				for x in grid.x:
					var c := Vector2i(x, y)
					if not occupied.has(c) and not foods.has(c) and not (c.x < grid.x * 0.45 and c.y >= grid.y - 4):
						cell = c
						break
				if cell.x >= 0:
					break
		if cell.x < 0:
			cell = Vector2i(grid.x - 1, 0)
		foods[cell] = ci
		occupied[cell] = true


## cell currently holding the next target chunk (-1 if none)
func _target_cell() -> Vector2i:
	for cell in foods.keys():
		if foods[cell] == next_idx:
			return cell
	return Vector2i(-1, -1)


func _cell_blocked(c: Vector2i) -> bool:
	return snake.has(c) or c.x < 0 or c.y < 0 or c.x >= grid.x or c.y >= grid.y


func _cell_reachable(c: Vector2i) -> bool:
	var seen := {}
	var q := [snake[0]]
	seen[snake[0]] = true
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur == c:
			return true
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = cur + d
			if n.x < 0 or n.y < 0 or n.x >= grid.x or n.y >= grid.y:
				continue
			if seen.has(n) or snake.has(n):
				continue
			seen[n] = true
			q.append(n)
	return false


# ------------------------------------------------------------------ input

func _input_dir(d: Vector2i) -> void:
	if d == Vector2i.ZERO or state != State.PLAY:
		return
	var last: Vector2i = dir_queue.back() if not dir_queue.is_empty() else dir
	if d == -last or d == last:
		return
	dir_queue.append(d)
	if dir_queue.size() > 3:
		dir_queue.pop_front()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if state != State.PLAY:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("a"):
		_input_dir(Vector2i.LEFT)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("d"):
		_input_dir(Vector2i.RIGHT)
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("w"):
		_input_dir(Vector2i.UP)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("s"):
		_input_dir(Vector2i.DOWN)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			var delta: Vector2 = event.position - _touch_start
			if delta.length() > 30:
				if absf(delta.x) > absf(delta.y):
					_input_dir(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
				else:
					_input_dir(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)
	elif event is InputEventScreenDrag:
		var delta: Vector2 = event.position - _touch_start
		if absf(delta.x) > absf(delta.y) and absf(delta.x) > 30:
			_input_dir(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
			_touch_start = event.position
		elif absf(delta.y) >= absf(delta.x) and absf(delta.y) > 30:
			_input_dir(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)
			_touch_start = event.position


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			count_t -= delta
			if count_t <= 0.0:
				state = State.PLAY
				_countdown.visible = false
				_update_hud()
			else:
				_update_countdown()
		State.PLAY:
			# warn modal pauses the snake (like the web reference)
			if _warn.visible:
				_update_popups(delta)
				_update_hud()
				_state_redraw()
				return
			elapsed += delta
			if stun_t > 0.0:
				stun_t -= delta
			else:
				move_acc += delta
				while move_acc >= move_interval and state == State.PLAY:
					move_acc -= move_interval
					_step()
			if invuln_t > 0.0:
				invuln_t -= delta
			_update_popups(delta)
			_update_hud()
	_state_redraw()


func _show_countdown() -> void:
	_countdown.visible = true
	_update_countdown()


func _update_countdown() -> void:
	var n := int(ceil(count_t))
	_count_label.text = str(maxi(1, n)) if count_t > 0.6 else "GO!"
	var sh: Label = _countdown.get_node("Shadow")
	sh.text = _count_label.text
	# pop scale animation
	_count_label.pivot_offset = _count_label.size * 0.5
	_count_label.scale = Vector2.ONE * (1.15 if count_t < 1.0 else 1.0)


func _step() -> void:
	if not dir_queue.is_empty():
		var nd: Vector2i = dir_queue.pop_front()
		if nd != -dir:
			dir = nd
	var head: Vector2i = snake[0] + dir
	if head.x < 0 or head.y < 0 or head.x >= grid.x or head.y >= grid.y:
		_game_over("撞墙了,再试一次!")
		return
	var body := snake.duplicate()
	body.resize(body.size() - 1)
	if body.has(head):
		_game_over("撞到自己了,再来一局!")
		return
	snake.push_front(head)
	snake_labels.push_front(-1)

	var hit: int = foods.get(head, -1)
	if hit >= 0:
		foods.erase(head)
		if hit == next_idx:
			_eat_target()
		else:
			_wrong_eat(hit)
		return
	snake.pop_back()
	snake_labels.pop_back()


# ------------------------------------------------------------- eat / wrong

func _eat_target() -> void:
	var chunks: Array = GameData.sentence().get("chunks", [])
	if next_idx >= chunks.size():
		return
	var ci := next_idx
	next_idx += 1
	eaten += 1
	combo += 1
	# score: 100 + time bonus like the web reference (max 20s bonus)
	var gain := 100 + maxi(0, 20 - int(elapsed))
	score += gain
	move_interval = maxf(MIN_INTERVAL, BASE_INTERVAL - eaten * SPEED_STEP)
	snake_labels[0] = ci
	ripples.append({ "pos": _cell_center(snake[0]), "t": 0.0 })
	_popups_add("+%d" % gain, _cell_center(snake[0]) + Vector2(0, -34), UiKit.YELLOW)
	_flash_great()
	Sfx.eat()
	if combo % 5 == 0:
		Sfx.great()
	if next_idx >= chunks.size():
		_sentence_complete()
	_update_hud()


func _flash_great() -> void:
	_great.visible = true
	_great.modulate.a = 1.0
	_great.scale = Vector2.ONE * 0.6
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_great, "scale", Vector2.ONE * 1.05, 0.15)
	tw.tween_property(_great, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(func(): _great.visible = false)


func _popups_add(text: String, pos: Vector2, color: Color) -> void:
	popups.append({ "text": text, "pos": pos, "t": 0.0, "color": color })


func _wrong_eat(ci: int) -> void:
	wrong_count += 1
	combo = 0
	stun_t = 0.0
	var head_pos := _cell_center(snake[0])
	_popups_add("顺序不对!先吃第 %d 块" % (next_idx + 1), head_pos + Vector2(0, -40), Color("ff9ec4"))
	if GameData.practice_mode:
		_show_warn("这一块还不是现在要吃的,先找带白色光环的那一块。", Callable())
		Sfx.wrong()
	else:
		lives -= 1
		invuln_t = 1.0
		Sfx.wrong()
		if lives <= 0:
			_game_over("挑战失败:生命用尽")
			return
		_show_warn("顺序不对!扣掉一条命,还剩 %d 条。先找带光环的那一块。" % lives, Callable())
	snake.pop_back()
	snake_labels.pop_back()
	_update_hud()


func _show_warn(text: String, cb: Callable) -> void:
	_warn_text.text = text
	_warn_cb = cb
	_warn.visible = true
	(get_node("WarnDim") as ColorRect).visible = true


func _hide_warn() -> void:
	_warn.visible = false
	(get_node("WarnDim") as ColorRect).visible = false
	var cb := _warn_cb
	_warn_cb = Callable()
	if cb.is_valid():
		cb.call()


func _sentence_complete() -> void:
	state = State.COMPLETE
	Sfx.great()
	_show_result(true)


func _game_over(reason := "") -> void:
	state = State.OVER
	Sfx.over()
	_hide_warn()
	# reference behavior: warn modal with reason, OK returns to menu
	_show_warn("游戏结束:%s" % (reason if reason != "" else "再试一次!"),
		func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))


func _toggle_pause() -> void:
	match state:
		State.PLAY:
			state = State.PAUSE
			_pause_veil.visible = true
		State.PAUSE:
			state = State.PLAY
			_pause_veil.visible = false
		State.OVER, State.COMPLETE:
			_pause_veil.visible = false
		_:
			pass


func _show_result(completed: bool) -> void:
	if _result_panel == null:
		_result_panel = _build_result_panel()
		add_child(_result_panel)
	_result_panel.visible = true
	for c in _result_panel.get_child(0).get_children():
		c.queue_free()
	var vb: VBoxContainer = _result_panel.get_child(0)
	vb.add_child(UiKit.label("过关!" if completed else "游戏结束", 56, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var stars := _calc_stars(completed)
	vb.add_child(UiKit.label("★".repeat(stars) + "☆".repeat(3 - stars), 60, UiKit.YELLOW, HORIZONTAL_ALIGNMENT_CENTER))
	vb.add_child(UiKit.label("得分 %d · 用时 %.1fs · 吃错 %d 次" % [score, elapsed, wrong_count], 26, UiKit.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var replay := UiKit.candy_button("再玩一次", 28, UiKit.PAPER, UiKit.INK)
	replay.pressed.connect(func(): Sfx.click(); _start_sentence())
	row.add_child(replay)
	var tree := UiKit.candy_button("语法树", 28, UiKit.MINT, UiKit.INK)
	tree.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/structure.tscn"))
	row.add_child(tree)
	var menu := UiKit.candy_button("回菜单", 28, Color("8e96a8"), Color.WHITE)
	menu.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)
	vb.add_child(row)


func _build_result_panel() -> PanelContainer:
	var p := UiKit.panel(UiKit.CREAM, 28)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.offset_left = -260
	p.offset_top = -170
	p.offset_right = 260
	p.offset_bottom = 170
	p.visible = false
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	p.add_child(vb)
	return p


func _calc_stars(completed: bool) -> int:
	if not completed:
		return 1
	if wrong_count == 0 and elapsed < 60.0:
		return 3
	if wrong_count <= 2:
		return 2
	return 1


# ------------------------------------------------------------------ HUD

func _update_hud() -> void:
	var chunks: Array = GameData.sentence().get("chunks", [])
	_chip_set("prog", "%d / %d" % [mini(next_idx, chunks.size()), chunks.size()])
	_chip_set("score", "%d 分" % score)
	var t := int(elapsed)
	_chip_set("time", "%02d:%02d" % [t / 60, t % 60])
	if not GameData.practice_mode:
		_chip_set("lives", "♥".repeat(lives) + "♡".repeat(START_LIVES - lives))
	else:
		_chip_set("lives", "")


func _update_popups(delta: float) -> void:
	for p in popups:
		p["t"] += delta
		p["pos"] = p["pos"] + Vector2(0, -36 * delta)
	for r in ripples:
		r["t"] += delta
	popups = popups.filter(func(p): return p["t"] < 1.0)
	ripples = ripples.filter(func(r): return r["t"] < 0.6)


# ---------------------------------------------------------------- drawing

func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(board_rect.position + Vector2(c) * cell_px, Vector2(cell_px, cell_px))


func _cell_center(c: Vector2i) -> Vector2:
	return board_rect.position + Vector2(c) * cell_px + Vector2(cell_px, cell_px) * 0.5


func _state_redraw() -> void:
	_board.queue_redraw()


func _draw_board() -> void:
	var r := board_rect
	# dark board + faint grid
	_board.draw_rect(r, UiKit.BOARD, true)
	_board.draw_rect(r, Color(1, 1, 1, 0.03), false, 2.0)
	# grid lines every cell
	for x in range(1, grid.x):
		var px: float = r.position.x + x * cell_px
		_board.draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), UiKit.BOARD_GRID, 1.0)
	for y in range(1, grid.y):
		var py: float = r.position.y + y * cell_px
		_board.draw_line(Vector2(r.position.x, py), Vector2(r.end.x, py), UiKit.BOARD_GRID, 1.0)
	# soft radial glow center
	_board.draw_circle(r.get_center(), cell_px * 6.0, Color(1, 1, 1, 0.02))

	var chunks: Array = GameData.sentence().get("chunks", [])
	var now := Time.get_ticks_msec() / 1000.0
	# all chunk cupcakes on the board; the next target gets the glow ring
	for cell in foods.keys():
		_draw_cupcake(cell, foods[cell], chunks, foods[cell] == next_idx, now)

	_draw_snake()

	# ripples
	for rp in ripples:
		var t: float = rp["t"] / 0.6
		var rad := cell_px * (0.5 + t * 1.8)
		_board.draw_arc(rp["pos"], rad, 0, TAU, 40, Color(1, 1, 1, 0.85 * (1 - t)), 4.0)

	# popups
	for p in popups:
		var t: float = p["t"]
		_board.draw_string(UiKit.font(), p["pos"], p["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 30, Color(p["color"], 1.0 - t))


func _draw_cupcake(cell: Vector2i, ci: int, chunks: Array, is_target: bool, now: float) -> void:
	var c: Dictionary = chunks[ci] if ci < chunks.size() else {}
	var role: String = c.get("role", "S")
	var col: Color = UiKit.ROLE_COLORS.get(role, UiKit.PINK)
	var r := _cell_rect(cell)
	var s := cell_px
	var bob := sin(now * 2.4 + cell.x * 0.7 + cell.y) * s * 0.05
	var top := r.position + Vector2(0, bob)

	# target: white glow halo + rotating dashed ring
	if is_target:
		var pulse := 0.5 + 0.5 * sin(now * 4.0)
		_board.draw_circle(r.get_center() + Vector2(0, bob), s * 0.62, Color(1, 1, 1, 0.10 + 0.08 * pulse))
		var rot := now * 1.2
		for k in 10:
			var a0 := rot + k * TAU / 10.0
			var a1 := a0 + TAU / 20.0
			_board.draw_arc(r.get_center() + Vector2(0, bob), s * 0.58, a0, a1, 6, Color(1, 1, 1, 0.75), 3.0)

	# sparkle stars
	if is_target:
		var sparkle_offs: Array[Vector2] = [Vector2(-s * 0.55, -s * 0.3), Vector2(s * 0.55, -s * 0.1)]
		for off in sparkle_offs:
			var tw := 0.5 + 0.5 * sin(now * 5.0 + off.x)
			var sp: Vector2 = r.get_center() + Vector2(0, bob) + off
			_board.draw_line(sp + Vector2(-4, 0), sp + Vector2(4, 0), Color(1, 1, 1, 0.9 * tw), 2.0)
			_board.draw_line(sp + Vector2(0, -4), sp + Vector2(0, 4), Color(1, 1, 1, 0.9 * tw), 2.0)

	# --- cupcake body (inset slightly) ---
	var pad := s * 0.08
	var cake := Rect2(top + Vector2(pad, pad), Vector2(s - pad * 2, s - pad * 2))
	var cx := cake.get_center().x

	# wrapper: trapezoid, bottom ~42%
	var w_top := cake.position.y + cake.size.y * 0.55
	var w_bot := cake.end.y - s * 0.04
	var wl := cx - cake.size.x * 0.20
	var wr := cx + cake.size.x * 0.20
	var wbl := cx - cake.size.x * 0.30
	var wbr := cx + cake.size.x * 0.30
	var wrapper := PackedVector2Array([
		Vector2(wl, w_top), Vector2(wr, w_top), Vector2(wbr, w_bot), Vector2(wbl, w_bot)])
	_board.draw_colored_polygon(wrapper, UiKit.PINK)
	# wrapper stripes (white diagonal hints)
	for i in 3:
		var fx := lerpf(wl, wr, 0.2 + i * 0.3)
		var bx := lerpf(wbl, wbr, 0.2 + i * 0.3)
		_board.draw_line(Vector2(fx, w_top + 4), Vector2(bx, w_bot - 4), Color(1, 1, 1, 0.45), 3.0)
	# wrapper top rim
	_board.draw_line(Vector2(wl, w_top), Vector2(wr, w_top), Color(1, 1, 1, 0.5), 3.0)

	# cream: big soft blob on top
	var cream_r := cake.size.x * 0.34
	var cream_c := Vector2(cx, cake.position.y + cake.size.y * 0.34 + bob * 0.3)
	_board.draw_circle(cream_c, cream_r, Color("fff3e0"))
	_board.draw_circle(cream_c + Vector2(-cream_r * 0.25, -cream_r * 0.3), cream_r * 0.55, Color(1, 1, 1, 0.85))
	_board.draw_circle(cream_c + Vector2(cream_r * 0.2, cream_r * 0.15), cream_r * 0.5, Color("f6d3b4"))
	# side cream swirls
	_board.draw_circle(Vector2(cx - cream_r * 0.95, cream_c.y + cream_r * 0.15), cream_r * 0.42, Color("fff3e0"))
	_board.draw_circle(Vector2(cx + cream_r * 0.95, cream_c.y + cream_r * 0.15), cream_r * 0.42, Color("fff3e0"))

	# cherry + stem
	var cherry := Vector2(cx, cake.position.y + cake.size.y * 0.13)
	_board.draw_line(cherry + Vector2(0, -s * 0.05), cherry + Vector2(s * 0.05, -s * 0.14), Color("5f9e54"), 3.0)
	_board.draw_circle(cherry, s * 0.075, Color("ef4257"))
	_board.draw_circle(cherry + Vector2(-s * 0.02, -s * 0.02), s * 0.025, Color(1, 1, 1, 0.6))

	# sticker label under the cake — always horizontal, at bottom area
	var txt: String = c.get("en", "?")
	var fs := 14
	var f := UiKit.font()
	var maxw := s * 1.7
	while f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw and fs > 8:
		fs -= 1
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var st_h := fs + 12
	var st_w := minf(tw + 18, s * 2.0)
	var st_rect := Rect2(cx - st_w * 0.5, cake.end.y - st_h - 2, st_w, st_h)
	var st_style := _sb_sticker.duplicate()
	st_style.bg_color = col
	_board.draw_style_box(st_style, st_rect)
	_board.draw_string(f, st_rect.position + Vector2(9, st_h * 0.72), txt, HORIZONTAL_ALIGNMENT_LEFT, st_w - 12, fs, UiKit.INK)


func _draw_snake() -> void:
	# accumulated white glow grows with progress
	var progress := float(eaten) / maxf(1.0, GameData.chunk_count())
	var glow_a := progress * 0.45
	var n := snake.size()
	for i in range(n - 1, -1, -1):
		var cell: Vector2i = snake[i]
		var r := _cell_rect(cell).grow(-2 if i > 0 else -1)
		var is_head := i == 0
		var ci: int = snake_labels[i] if i < snake_labels.size() else -1
		var base := _sb_seg_a if i % 2 == 0 else _sb_seg_b
		if ci >= 0:
			var role: String = GameData.sentence().get("chunks", [])[ci].get("role", "S")
			var rc: Color = UiKit.ROLE_COLORS.get(role, UiKit.MINT)
			var cs := StyleBoxFlat.new()
			cs.bg_color = rc
			cs.set_corner_radius_all(int(cell_px * 0.30))
			cs.border_color = rc.darkened(0.2)
			cs.set_border_width_all(2)
			base = cs
		# soft drop shadow
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(0, 0, 0, 0.28)
		sh.set_corner_radius_all(int(cell_px * 0.30))
		var shadow_rect := r.grow(1)
		shadow_rect.position += Vector2(0, 4)
		_board.draw_style_box(sh, shadow_rect)
		# glow halo (accumulated with progress)
		if glow_a > 0.02:
			var gl := StyleBoxFlat.new()
			gl.bg_color = Color(1, 1, 1, glow_a * (0.5 if is_head else 0.3))
			gl.set_corner_radius_all(int(cell_px * 0.42))
			_board.draw_style_box(gl, r.grow(cell_px * 0.10))
		_board.draw_style_box(base, r)
		# gloss: top highlight strip
		var gloss := Rect2(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.10), Vector2(r.size.x * 0.76, r.size.y * 0.30))
		_board.draw_rect(gloss, Color(1, 1, 1, 0.35), true)
		if is_head:
			_draw_eyes(r, ci)
		elif ci >= 0:
			# chunk label on the segment
			var chunks: Array = GameData.sentence().get("chunks", [])
			var txt: String = chunks[ci].get("en", "")
			var f := UiKit.font()
			var fs := 11
			while f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 8 and fs > 7:
				fs -= 1
			_board.draw_string(f, r.position + Vector2(4, r.size.y * 0.62), txt.left(8), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, fs, Color(1, 1, 1, 0.92))


func _draw_eyes(r: Rect2, ci: int) -> void:
	var c := r.get_center()
	var d := Vector2(dir)
	var side := Vector2(-dir.y, dir.x)
	var eye_r := cell_px * 0.10
	for sgn in [-1, 1]:
		var ep: Vector2 = c + d * cell_px * 0.14 + side * cell_px * 0.20 * sgn
		_board.draw_circle(ep, eye_r, Color.WHITE)
		_board.draw_circle(ep + d * eye_r * 0.4, eye_r * 0.5, UiKit.INK)


# ---------------------------------------------------------------- test API

func hook_start() -> void:
	state = State.PLAY
	_countdown.visible = false
	_update_hud()


func hook_set_dir(d: Vector2i) -> void:
	_input_dir(d)


func hook_eat_next() -> void:
	var tc := _target_cell()
	if tc.x < 0:
		return
	foods.erase(tc)
	snake.push_front(tc)
	snake_labels.push_front(-1)
	_eat_target()


func hook_wrong() -> void:
	_wrong_eat(-1)


func hook_state() -> String:
	return State.keys()[state]


func hook_stats() -> Dictionary:
	return {
		"score": score, "next_idx": next_idx, "eaten": eaten,
		"lives": lives, "wrong": wrong_count, "state": hook_state(),
		"snake_len": snake.size(), "foods": foods.size(),
		"elapsed": elapsed,
	}
