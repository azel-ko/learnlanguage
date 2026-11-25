extends Node
## GameData autoload: loads sentence JSON, exposes current selection, helpers.

const SENTENCES_PATH := "res://data/sentences.json"

var sentences: Array = []
var current_index := 0
var practice_mode := true  # true=练习模式(吃错警告) false=挑战模式(扣命)

signal sentences_loaded


func _ready() -> void:
	var f := FileAccess.open(SENTENCES_PATH, FileAccess.READ)
	if f == null:
		push_error("cannot open " + SENTENCES_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("bad JSON in sentences.json")
		return
	sentences = parsed.get("sentences", [])
	sentences_loaded.emit()


func sentence(i: int = -1) -> Dictionary:
	var idx := current_index if i < 0 else i
	if sentences.is_empty():
		return {}
	return sentences[clampi(idx, 0, sentences.size() - 1)]


func chunk_count() -> int:
	return sentence().get("chunks", []).size()
