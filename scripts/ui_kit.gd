class_name UiKit
## Shared UI helpers matching the candy/toy-vinyl design (cream + ink + candy dots).
## Palette mirrors the web reference: cream #fff6e6, ink #242a38, candy accents.

# ---- light screens (menu / prepare / structure) ----
const CREAM := Color("fff6e6")
const CREAM_2 := Color("fdefd6")
const INK := Color("242a38")
const INK_SOFT := Color("5b6072")
const MINT := Color("8fd9b6")
const GREEN := Color("7ed36b")
const PINK := Color("ff9ec4")
const YELLOW := Color("ffd86b")
const BLUE := Color("8ecae6")
const PURPLE := Color("b9a7e8")
const ORANGE := Color("ffb27a")
const TEAL := Color("7fd8cf")
const PAPER := Color("ffffff")
const CHUNK_COLORS := [MINT, PINK, YELLOW, BLUE, PURPLE, ORANGE, TEAL]

# ---- game screen (dark board) ----
const BOARD := Color("2b2f3a")
const BOARD_GRID := Color(1, 1, 1, 0.022)
const HUD_BG := Color("2b2f3a")
const CHIP_BG := Color("3d4354")
const CHIP_TEXT := Color("e9edf5")
const FOOT_BG := Color("232733")

const ROLE_COLORS := {
	"S": MINT,
	"V": PINK,
	"O": YELLOW,
	"Attr": PURPLE,
	"Adv": ORANGE,
	"Clause": TEAL,
}

static var _font: Font


static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"Noto Sans CJK SC", "PingFang SC", "Microsoft YaHei",
			"WenQuanYi Micro Hei", "sans-serif",
		])
		_font = sf
	return _font


static func label(text: String, size := 28, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func candy_button(text: String, size := 30, bg := PAPER, fg := INK) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_stylebox_override("normal", _btn_box(bg))
	b.add_theme_stylebox_override("hover", _btn_box(bg.lightened(0.06)))
	b.add_theme_stylebox_override("pressed", _btn_box(bg.darkened(0.06)))
	b.add_theme_stylebox_override("focus", _btn_box(bg.lightened(0.06)))
	b.add_theme_stylebox_override("disabled", _btn_box(Color(0.75, 0.75, 0.78)))
	b.custom_minimum_size = Vector2(0, size * 2.1)
	return b


static func _btn_box(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(16)
	s.shadow_color = Color(0.09, 0.11, 0.16, 0.18)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 5)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func panel(color := PAPER, radius := 24) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0.09, 0.11, 0.16, 0.14)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 10)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", s)
	return p


## rounded chip (HUD style) — dark or light
static func chip(text: String, size := 24, bg := CHIP_BG, fg := CHIP_TEXT) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(999)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, fg, HORIZONTAL_ALIGNMENT_CENTER)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(l)
	return p


## pill badge (topbar)
static func pill(text: String, bg: Color, fg := Color.WHITE, size := 24) -> PanelContainer:
	var p := chip(text, size, bg, fg)
	return p


## chunk pill for prepare screen / sticker-like label with role dot
static func chunk_pill(order: int, text: String, role: String, en_mode := true) -> PanelContainer:
	var role_col: Color = ROLE_COLORS.get(role, INK)
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = role_col
	s.set_corner_radius_all(999)
	s.content_margin_left = 8
	s.content_margin_right = 16
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	# role badge circle
	var rb := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(1, 1, 1, 0.8)
	rs.set_corner_radius_all(999)
	rs.content_margin_left = 8
	rs.content_margin_right = 8
	rs.content_margin_top = 2
	rs.content_margin_bottom = 2
	rb.add_theme_stylebox_override("panel", rs)
	rb.add_child(label(role, 20, INK, HORIZONTAL_ALIGNMENT_CENTER))
	hb.add_child(rb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", -4)
	var t := label("%d. %s" % [order, text] if en_mode else text, 24, INK)
	body.add_child(t)
	hb.add_child(body)
	p.add_child(hb)
	return p


## sentence card for menu grid
static func sentence_card(index: int, total: int, en: String, zh: String, color: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 150)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 18
	vb.offset_top = 12
	vb.offset_right = -14
	vb.offset_bottom = -12
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(label("SENTENCE %02d" % (index + 1), 18, color))
	var en_l := label(en, 20, INK)
	en_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(en_l)
	var zh_l := label(zh, 17, INK_SOFT)
	zh_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(zh_l)
	vb.add_child(label("▶", 26, color, HORIZONTAL_ALIGNMENT_RIGHT))
	b.add_child(vb)
	# white card + colored left bar + soft shadow
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.set_corner_radius_all(18)
	s.border_width_left = 8
	s.border_color = color
	s.shadow_color = Color(0.09, 0.11, 0.16, 0.10)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 6)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", _hover_card(s, color))
	b.add_theme_stylebox_override("pressed", s)
	b.add_theme_stylebox_override("focus", s)
	return b


static func _hover_card(base: StyleBoxFlat, color: Color) -> StyleBoxFlat:
	var s := base.duplicate()
	s.bg_color = Color(1, 1, 1)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 10)
	return s
