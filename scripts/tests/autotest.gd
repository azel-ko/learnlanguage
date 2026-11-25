extends Control
## Automated acceptance test: dual-resolution assertions + screenshots.
## Run: godot --path <proj> res://tests/autotest.tscn -- --out=/tmp/shots
## This scene manually instantiates screens (never uses change_scene_to_file,
## so the test runner itself is not freed).

var _out := "/tmp/grammar_snake_shots"
var _failures: Array[String] = []
var _passes := 0
var _screen: Node = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _assert(cond: bool, name: String) -> void:
	if cond:
		_passes += 1
		print("PASS  ", name)
	else:
		_failures.append(name)
		print("FAIL  ", name)


func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	var err := img.save_png(path)
	print("SHOT  %s -> %s (%s)" % [name, path, error_string(err)])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _win_size(w: int, h: int) -> void:
	get_window().size = Vector2i(w, h)
	await _wait(0.4)


func _load(path: String) -> Node:
	if _screen != null:
		_screen.queue_free()
		await get_tree().process_frame
	_screen = load(path).instantiate()
	add_child(_screen)
	await _wait(0.5)
	return _screen


func _run() -> void:
	print("=== Grammar Snake autotest ===")
	print("sentences loaded: %d" % GameData.sentences.size())
	_assert(GameData.sentences.size() == 10, "10 sentences in JSON")
	for s in GameData.sentences:
		_assert(s.get("chunks", []).size() >= 3, "sentence %d has >=3 chunks" % s.get("ls", -1))

	# ---- desktop 1440x900 ----
	await _win_size(1440, 900)
	var menu := await _load("res://scenes/main_menu.tscn")
	_assert(menu != null and menu.get_script() != null, "menu scene loads")
	await _shot("01_menu_desktop")

	await _load("res://scenes/prepare.tscn")
	await _shot("02_prepare_desktop")

	var game: Node = await _load("res://scenes/game.tscn")
	_assert(game != null and game.has_method("hook_stats"), "game scene loads with hooks")
	await _shot("03_game_countdown")

	game.hook_start()
	await _wait(0.3)
	var st: Dictionary = game.hook_stats()
	_assert(st["state"] == "PLAY", "hook_start enters PLAY")
	_assert(st["snake_len"] >= 3, "snake initial length >= 3")
	var chunk_n: int = GameData.sentence().get("chunks", []).size()
	_assert(st["foods"] == chunk_n, "all %d chunk cupcakes placed on board" % chunk_n)
	await _shot("04_game_play")

	# real movement: snake must advance on its own via _process/_step
	var head_before: Vector2i = game.snake[0]
	await _wait(1.2)
	_assert(game.snake[0] != head_before and game.hook_state() == "PLAY", "snake auto-moves without input, no instant death (%s -> %s, %s)" % [head_before, game.snake[0], game.hook_state()])
	await _shot("04b_game_moved")

	# steering: queue direction changes (must not crash / must not 180°)
	game.hook_set_dir(Vector2i.DOWN)
	await _wait(0.5)
	game.hook_set_dir(Vector2i.LEFT)
	await _wait(0.5)

	# eat all chunks via hook — freeze real movement first so the live snake
	# can't eat foods / hit walls and make the test flaky
	game.move_interval = 999.0
	var chunks: int = GameData.sentence().get("chunks", []).size()
	for i in chunks:
		game.hook_eat_next()
		await _wait(0.12)
	st = game.hook_stats()
	_assert(st["next_idx"] == chunks, "all %d chunks eaten via hook" % chunks)
	_assert(st["eaten"] == chunks, "eaten counter == chunks")
	_assert(st["snake_len"] >= 3 + chunks, "snake grew to %d" % st["snake_len"])
	_assert(st["score"] > 0, "score accumulated: %d" % st["score"])
	_assert(st["state"] == "COMPLETE", "sentence complete state")
	await _shot("05_game_complete")

	# wrong-eat in challenge mode costs a life
	GameData.practice_mode = false
	game = await _load("res://scenes/game.tscn")
	game.hook_start()
	await _wait(0.2)
	var lives_before: int = game.hook_stats()["lives"]
	game.hook_wrong()
	await _wait(0.2)
	st = game.hook_stats()
	_assert(st["lives"] == lives_before - 1, "challenge: wrong eat costs life (%d->%d)" % [lives_before, st["lives"]])
	_assert(st["wrong"] == 1, "wrong counter incremented")
	await _shot("06_game_wrong_challenge")
	GameData.practice_mode = true

	# structure screen
	await _load("res://scenes/structure.tscn")
	await _shot("07_structure_desktop")

	# ---- mobile portrait 390x844 ----
	await _win_size(390, 844)
	game = await _load("res://scenes/game.tscn")
	game.hook_start()
	await _wait(0.4)
	await _shot("08_game_portrait")
	game.hook_eat_next()
	await _wait(0.3)
	await _shot("09_game_portrait_eat")

	# back to desktop for a final menu shot
	await _win_size(1440, 900)
	await _load("res://scenes/main_menu.tscn")
	await _shot("10_menu_final")

	print("=== RESULT: %d passed, %d failed ===" % [_passes, _failures.size()])
	for f in _failures:
		print("FAILED: ", f)
	get_tree().quit(0 if _failures.is_empty() else 1)
