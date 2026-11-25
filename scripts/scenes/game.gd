extends Control
## Screen 3 · 游戏: snake eats grammar chunks in sentence order.
## Test hooks: hook_start / hook_set_dir / hook_eat_next / hook_wrong.

const COLS := 22
const ROWS := 14
const BASE_INTERVAL := 0.38
const MIN_INTERVAL := 0.13
const START_LIVES := 3

enum State { COUNTDOWN, PLAY, PAUSE, OVER, COMPLETE }

var state := State.COUNTDOWN
var grid := Vector2i(COLS, ROWS)
var cell_px := 40.0
var board_rect := Rect2()

var snake: Array[Vector2i] = []
var dir := Vector2i.RIGHT
var dir_queue: Array[Vector2i] = []
var blocks := {}            # Vector2i cell -> chunk index (decoys)
var target_cell := Vector2i(-1, -1)
var next_idx := 0           # next chunk index to eat
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
var ripples: Array = []     # {pos:Vector2, t:float}
var popups: Array = []      # {text:String, pos:Vector2, t:float, color:Color}
var snake_labels: Array[int] = []  # chunk index per segment, -1 = plain
var start_time := 0.0

var _board: Control
var _hud: HBoxContainer
var _zh_panel: PanelContainer
var _overlay: Control
var _overlay_label: Label
var _result_panel: PanelContainer
var _pause_btn: Button
var _hud_labels := {}
var _touch_start := Vector2.ZERO
var _touch_dir := Vector2i.ZERO


func _ready() -> void:
	_build_ui()
	_start_sentence()
	get_viewport().size_changed.connect(_layout)
	_layout.call_deferred()


# ---------------------------------------------------------------- UI build

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = UiKit.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# HUD top bar
	var hud_wrap := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = UiKit.PINK
	hs.set_corner_radius_all(0)
	hs.content_margin_left = 18
	hs.content_margin_right = 18
	hs.content_margin_top = 6
	hs.content_margin_bottom = 6
	hud_wrap.add_theme_stylebox_override("panel", hs)
	hud_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hud_wrap.offset_bottom = 64
	add_child(hud_wrap)
	_hud = HBoxContainer.new()
	_hud.add_theme_constant_override("separation", 28)
	_hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud_wrap.add_child(_hud)
	_hud_labels["mode"] = _hud_add(UiKit.label("练习模式", 24, Color.WHITE))
	_hud_labels["prog"] = _hud_add(UiKit.label("", 24, Color.WHITE))
	_hud_labels["score"] = _hud_add(UiKit.label("分数 0", 24, Color.WHITE))
	_hud_labels["time"] = _hud_add(UiKit.label("0.0s", 24, Color.WHITE))
	_hud_labels["lives"] = _hud_add(UiKit.label("", 24, Color.WHITE))
	_hud.add_child(_spacer())
	_pause_btn = UiKit.candy_button("⏸", 24, Color(1, 1, 1, 0.25), Color.WHITE)
	_pause_btn.custom_minimum_size = Vector2(56, 44)
	_pause_btn.pressed.connect(_toggle_pause)
	_hud.add_child(_pause_btn)

	# board (drawn)
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.draw.connect(_draw_board)
	add_child(_board)

	# Chinese meaning panel bottom-left
	_zh_panel = UiKit.panel(Color(1, 1, 1, 0.85), 16)
	_zh_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_zh_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_zh_panel)
	_zh_panel.add_child(UiKit.label("中文句意", 20, UiKit.PINK_DARK))
	_zh_panel.add_child(UiKit.label("", 24, UiKit.INK))
	(_zh_panel.get_child(1) as Label).name = "ZhText"

	# overlay for countdown / pause / game over
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)
	_overlay_label = UiKit.label("", 120, UiKit.PINK_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_label.set_anchors_preset(Control.PRESET_CENTER)
	_overlay_label.offset_left = -300
	_overlay_label.offset_top = -80
	_overlay_label.offset_right = 300
	_overlay_label.offset_bottom = 80
	_overlay.add_child(_overlay_label)

	# result panel
	_result_panel = UiKit.panel(UiKit.PAPER, 28)
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_result_panel.visible = false
	add_child(_result_panel)

	# touch input on whole control
	gui_input.connect(_on_gui_input)


func _hud_add(l: Label) -> Label:
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hud.add_child(l)
	return l


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


func _layout() -> void:
	if _board == null or _zh_panel == null:
		return
	var vs := get_viewport().get_visible_rect().size
	# board area: below HUD(64), above zh panel(~110). Center horizontally.
	var avail := Rect2(0, 64, vs.x, vs.y - 64 - 120)
	var cell := minf(avail.size.x / COLS, avail.size.y / ROWS)
	var gw := cell * COLS
	var gh := cell * ROWS
	board_rect = Rect2(
		avail.position + (avail.size - Vector2(gw, gh)) * 0.5,
		Vector2(gw, gh))
	cell_px = cell
	_zh_panel.position = Vector2(16, vs.y - _zh_panel.size.y - 16) if _zh_panel.size.y > 0 else Vector2(16, vs.y - 120)
	_zh_panel.reset_size()
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
	blocks.clear()
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

	# snake starts center-left, length 3
	var cy := grid.y / 2
	var cx := grid.x / 4
	for i in 3:
		snake.push_front(Vector2i(cx - i, cy))
		snake_labels.push_front(-1)

	_spawn_target()
	_spawn_decoys(2)

	(_hud_labels["mode"] as Label).text = "练习模式" if GameData.practice_mode else "挑战模式"
	_update_hud()
	_result_panel.visible = false
	_overlay.visible = true
	_show_count()


func _spawn_target() -> void:
	var chunks: Array = GameData.sentence().get("chunks", [])
	if next_idx >= chunks.size():
		target_cell = Vector2i(-1, -1)
		return
	target_cell = _free_cell_far_from(snake[0], 6)


func _spawn_decoys(n: int) -> void:
	var chunks: Array = GameData.sentence().get("chunks", [])
	var candidates: Array[int] = []
	for i in chunks.size():
		if i != next_idx and not _is_eaten_idx(i):
			candidates.append(i)
	candidates.shuffle()
	var spawned := 0
	for ci in candidates:
		if spawned >= n:
			break
		var cell := _free_cell_far_from(snake[0], 4)
		if cell.x < 0:
			break
		blocks[cell] = ci
		spawned += 1


func _is_eaten_idx(i: int) -> bool:
	for l in snake_labels:
		if l == i:
			return true
	return false


func _free_cell_far_from(from: Vector2i, min_dist: int) -> Vector2i:
	var tries := 0
	while tries < 200:
		tries += 1
		var c := Vector2i(randi() % grid.x, randi() % grid.y)
		if _cell_blocked(c):
			continue
		if c == target_cell or blocks.has(c):
			continue
		if (c - from).length() >= min_dist or tries > 120:
			return c
	return Vector2i(-1, -1)


func _cell_blocked(c: Vector2i) -> bool:
	return snake.has(c) or c.x < 0 or c.y < 0 or c.x >= grid.x or c.y >= grid.y


func _cell_reachable(c: Vector2i) -> bool:
	# BFS from head over non-snake cells
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
	if state == State.PAUSE:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			_toggle_pause()
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if state == State.PLAY:
			_toggle_pause()
		get_viewport().set_input_as_handled()
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
			_touch_dir = Vector2i.ZERO
		else:
			var delta: Vector2 = event.position - _touch_start
			if delta.length() > 30:
				if absf(delta.x) > absf(delta.y):
					_input_dir(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
				else:
					_input_dir(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)
	elif event is InputEventScreenDrag:
		var delta: Vector2 = event.position - _touch_start
		if absf(delta.x) > absf(delta.y) and absf(delta.x) > 30 and _touch_dir != Vector2i.RIGHT and _touch_dir != Vector2i.LEFT:
			_input_dir(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
			_touch_dir = Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT
			_touch_start = event.position
		elif absf(delta.y) >= absf(delta.x) and absf(delta.y) > 30 and _touch_dir != Vector2i.UP and _touch_dir != Vector2i.DOWN:
			_input_dir(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)
			_touch_dir = Vector2i.DOWN if delta.y > 0 else Vector2i.UP
			_touch_start = event.position


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	match state:
		State.COUNTDOWN:
			count_t -= delta
			var n := int(ceil(count_t))
			if count_t <= 0.0:
				state = State.PLAY
				start_time = Time.get_ticks_msec()
				_overlay.visible = false
				_overlay_label.text = ""
			else:
				_show_count()
			if int(ceil(count_t + delta)) != n:
				Sfx.count_tick(count_t <= 1.0)
		State.PLAY:
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


func _show_count() -> void:
	_overlay_label.text = str(maxi(1, int(ceil(count_t)))) if count_t > 0.6 else "GO!"


func _step() -> void:
	if not dir_queue.is_empty():
		var nd: Vector2i = dir_queue.pop_front()
		if nd != -dir:
			dir = nd
	var head: Vector2i = snake[0] + dir
	# wall collision
	if head.x < 0 or head.y < 0 or head.x >= grid.x or head.y >= grid.y:
		_game_over()
		return
	# self collision (tail cell frees up unless growing this tick — keep simple: check all but last)
	var body := snake.duplicate()
	body.resize(body.size() - 1)
	if body.has(head):
		_game_over()
		return
	snake.push_front(head)
	snake_labels.push_front(-1)

	# eat target?
	if head == target_cell:
		_eat_target()
		return
	# eat decoy?
	if blocks.has(head):
		var ci: int = blocks[head]
		blocks.erase(head)
		_wrong_eat(ci)
		return
	# normal move: pop tail
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
	var gain := 100 + mini(combo - 1, 10) * 20
	score += gain
	move_interval = maxf(MIN_INTERVAL, move_interval * 0.97)
	snake_labels[0] = ci
	# growth: _step already push_front'ed the head, so NOT popping the tail
	# grows the snake by one segment (old tail stays as new segment).
	var head: Vector2i = snake[0]
	ripples.append({ "pos": _cell_center(head), "t": 0.0 })
	popups.append({ "text": "Great!", "pos": _cell_center(head) + Vector2(0, -30), "t": 0.0, "color": UiKit.MINT_DARK })
	Sfx.eat()
	if combo % 5 == 0:
		Sfx.great()
	# clear decoys occasionally and respawn
	if blocks.size() < 2 and next_idx < chunks.size():
		_spawn_decoys(1)
	if next_idx >= chunks.size():
		_sentence_complete()
	else:
		_spawn_target()
	_update_hud()


func _wrong_eat(ci: int) -> void:
	wrong_count += 1
	combo = 0
	stun_t = 0.6
	popups.append({
		"text": "顺序不对!先吃第 %d 块" % (next_idx + 1),
		"pos": _cell_center(snake[0]) + Vector2(0, -40),
		"t": 0.0,
		"color": UiKit.PINK_DARK,
	})
	if GameData.practice_mode:
		Sfx.wrong()
	else:
		lives -= 1
		invuln_t = 1.0
		Sfx.wrong()
		if lives <= 0:
			_game_over()
			return
	# remove tail growth compensation: snake already advanced; pop tail normally
	snake.pop_back()
	snake_labels.pop_back()
	_update_hud()


func _sentence_complete() -> void:
	state = State.COMPLETE
	Sfx.great()
	_show_result(true)


func _game_over() -> void:
	state = State.OVER
	Sfx.over()
	_show_result(false)


func _toggle_pause() -> void:
	if state == State.PLAY:
		state = State.PAUSE
		_overlay.visible = true
		_overlay_label.text = "已暂停\n\n按 P / Esc 继续"
	elif state == State.PAUSE:
		state = State.PLAY
		_overlay.visible = false
	elif state == State.OVER or state == State.COMPLETE:
		_overlay.visible = false


func _show_result(completed: bool) -> void:
	_result_panel.visible = true
	for c in _result_panel.get_children():
		c.queue_free()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_result_panel.add_child(vb)
	vb.add_child(UiKit.label("过关!" if completed else "游戏结束", 52, UiKit.PINK_DARK, HORIZONTAL_ALIGNMENT_CENTER))
	# stars
	var stars := _calc_stars(completed)
	var star_lbl := UiKit.label("★".repeat(stars) + "☆".repeat(3 - stars), 56, UiKit.BUTTER, HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(star_lbl)
	vb.add_child(UiKit.label("得分 %d · 用时 %.1fs · 吃错 %d 次" % [score, elapsed, wrong_count], 26, UiKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var replay := UiKit.candy_button("再玩一次", 28, UiKit.LAV, UiKit.INK)
	replay.pressed.connect(func(): Sfx.click(); _start_sentence())
	row.add_child(replay)
	var tree := UiKit.candy_button("语法树", 28, UiKit.MINT_DARK)
	tree.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/structure.tscn"))
	row.add_child(tree)
	var menu := UiKit.candy_button("回菜单", 28, Color(0.7, 0.7, 0.75), Color.WHITE)
	menu.pressed.connect(func(): Sfx.click(); get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	row.add_child(menu)
	vb.add_child(row)


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
	(_hud_labels["prog"] as Label).text = "第 %d/%d 块" % [mini(next_idx, chunks.size()), chunks.size()]
	(_hud_labels["score"] as Label).text = "分数 %d" % score
	(_hud_labels["time"] as Label).text = "%.1fs" % elapsed
	(_hud_labels["lives"] as Label).text = ("♥".repeat(lives) + "♡".repeat(START_LIVES - lives)) if not GameData.practice_mode else ""
	var zh := (_zh_panel.get_child(1) as Label)
	zh.text = GameData.sentence().get("zh", "")


func _update_popups(delta: float) -> void:
	for p in popups:
		p["t"] += delta
		p["pos"] = p["pos"] + Vector2(0, -30 * delta)
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
	# background
	_board.draw_rect(board_rect.grow(14), Color(0.93, 0.85, 0.88), true)
	_board.draw_rect(board_rect, Color(0.99, 0.96, 0.93), true)
	# grid dots
	for y in grid.y:
		for x in grid.x:
			var p := board_rect.position + Vector2(x + 0.5, y + 0.5) * cell_px
			_board.draw_circle(p, 2.0, Color(0.85, 0.78, 0.80, 0.5))

	# blocks (sticker labels are drawn as rounded rects with role color)
	var chunks: Array = GameData.sentence().get("chunks", [])
	for cell in blocks.keys():
		_draw_block(cell, blocks[cell], chunks)
	if target_cell.x >= 0:
		_draw_block(target_cell, next_idx, chunks, true)

	# snake
	_draw_snake()

	# ripples
	for r in ripples:
		var t: float = r["t"] / 0.6
		_board.draw_arc(r["pos"], cell_px * (0.6 + t * 1.6), 0, TAU, 32, Color(UiKit.MINT, 0.7 * (1 - t)), 4.0)

	# popups
	for p in popups:
		var t: float = p["t"]
		var a := 1.0 - t
		_board.draw_string(UiKit.font(), p["pos"], p["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 34, Color(p["color"], a))


func _draw_block(cell: Vector2i, ci: int, chunks: Array, is_target := false) -> void:
	var c: Dictionary = chunks[ci] if ci < chunks.size() else {}
	var r := _cell_rect(cell).grow(-3)
	var role: String = c.get("role", "S")
	var col: Color = UiKit.ROLE_COLORS.get(role, UiKit.INK)
	# paper sticker
	_board.draw_rect(r, UiKit.PAPER, true)
	_board.draw_rect(r, col if is_target else Color(0.55, 0.5, 0.55, 0.8), false, 3.0 if is_target else 2.0)
	# role tag
	_board.draw_rect(Rect2(r.position, Vector2(10, r.size.y)), col, true)
	# text (truncate to fit)
	var txt: String = c.get("en", "?")
	var fs := 15
	var f := UiKit.font()
	while f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 26 and fs > 9:
		fs -= 1
	var pos := r.position + Vector2(20, r.size.y * 0.5 + fs * 0.35)
	_board.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 26, fs, UiKit.INK)
	if is_target:
		# gentle bobbing highlight ring
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
		_board.draw_rect(r.grow(3), Color(col, 0.4 + 0.3 * pulse), false, 3.0)


func _draw_snake() -> void:
	var n := snake.size()
	for i in range(n - 1, -1, -1):
		var cell: Vector2i = snake[i]
		var r := _cell_rect(cell).grow(-2 if i > 0 else -1)
		var is_head := i == 0
		var ci: int = snake_labels[i] if i < snake_labels.size() else -1
		var base := UiKit.MINT if i % 2 == 0 else Color(0.55, 0.85, 0.72)
		if ci >= 0:
			var role: String = GameData.sentence().get("chunks", [])[ci].get("role", "S")
			base = UiKit.ROLE_COLORS.get(role, base)
		# body link with gloss
		_board.draw_rect(r, base, true)
		_board.draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.45)), Color(1, 1, 1, 0.25), true)
		_board.draw_rect(r, base.darkened(0.15), false, 2.0)
		if is_head:
			# eyes
			var c := _cell_center(cell)
			var side := Vector2(-dir.y, dir.x)
			for s in [-1, 1]:
				var ep: Vector2 = c + Vector2(dir) * cell_px * 0.12 + side * cell_px * 0.18 * s
				_board.draw_circle(ep, cell_px * 0.09, Color.WHITE)
				_board.draw_circle(ep + Vector2(dir) * cell_px * 0.03, cell_px * 0.05, UiKit.INK)
		elif ci >= 0:
			# label the chunk on the segment (first letters)
			var chunks: Array = GameData.sentence().get("chunks", [])
			var txt: String = chunks[ci].get("en", "")
			var f := UiKit.font()
			var fs := 11
			while f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 8 and fs > 7:
				fs -= 1
			_board.draw_string(f, r.position + Vector2(4, r.size.y * 0.6), txt.left(8), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 8, fs, Color(1, 1, 1, 0.9))


# ---------------------------------------------------------------- test API

func hook_start() -> void:
	state = State.PLAY
	_overlay.visible = false
	start_time = Time.get_ticks_msec()


func hook_set_dir(d: Vector2i) -> void:
	_input_dir(d)


func hook_eat_next() -> void:
	## Simulate the head moving onto the target and eating it (test hook).
	if target_cell.x < 0:
		return
	snake.push_front(target_cell)
	snake_labels.push_front(-1)
	_eat_target()


func hook_wrong() -> void:
	## Simulate eating a wrong chunk (test hook).
	_wrong_eat(-1)


func hook_state() -> String:
	return State.keys()[state]


func hook_stats() -> Dictionary:
	return {
		"score": score, "next_idx": next_idx, "eaten": eaten,
		"lives": lives, "wrong": wrong_count, "state": hook_state(),
		"snake_len": snake.size(), "blocks": blocks.size(),
		"elapsed": elapsed,
	}
