class_name UiKit
## Shared UI helpers: CJK font, candy-style widgets, palette.

const CREAM := Color(0.99, 0.95, 0.92)
const PINK := Color(0.98, 0.72, 0.78)
const PINK_DARK := Color(0.90, 0.55, 0.62)
const MINT := Color(0.65, 0.90, 0.78)
const MINT_DARK := Color(0.45, 0.78, 0.62)
const LAV := Color(0.78, 0.72, 0.95)
const LAV_DARK := Color(0.60, 0.52, 0.82)
const BUTTER := Color(1.0, 0.90, 0.55)
const INK := Color(0.28, 0.22, 0.30)
const PAPER := Color(1.0, 0.99, 0.96)
const ROLE_COLORS := {
	"S": Color(0.95, 0.55, 0.60),
	"V": Color(0.45, 0.70, 0.95),
	"O": Color(0.55, 0.75, 0.50),
	"Attr": Color(0.85, 0.60, 0.90),
	"Adv": Color(0.95, 0.72, 0.40),
	"Clause": Color(0.45, 0.75, 0.80),
}

static var _font: Font


static func font() -> Font:
	if _font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Micro Hei",
			"Microsoft YaHei", "PingFang SC", "sans-serif",
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


static func candy_button(text: String, size := 30, bg := PINK, fg := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_stylebox_override("normal", _btn_style(bg))
	b.add_theme_stylebox_override("hover", _btn_style(bg.lightened(0.08)))
	b.add_theme_stylebox_override("pressed", _btn_style(bg.darkened(0.08)))
	b.add_theme_stylebox_override("focus", _btn_style(bg.lightened(0.05)))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(0.8, 0.8, 0.8)))
	b.custom_minimum_size = Vector2(0, size * 2.2)
	return b


static func _btn_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(18)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func panel(color := PAPER, radius := 24, border := Color(0, 0, 0, 0.06)) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(2)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", s)
	return p


## A "paper sticker" label: white rounded card with a colored role tag dot.
static func sticker(text: String, role: String, font_size := 26) -> PanelContainer:
	var p := panel(PAPER, 14, ROLE_COLORS.get(role, INK))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	var dp := Panel.new()
	dp.custom_minimum_size = Vector2(14, 14)
	dp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ds := StyleBoxFlat.new()
	ds.bg_color = ROLE_COLORS.get(role, INK)
	ds.set_corner_radius_all(7)
	dp.add_theme_stylebox_override("panel", ds)
	hb.add_child(dp)
	var l := label(text, font_size, INK)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(l)
	p.add_child(hb)
	return p
