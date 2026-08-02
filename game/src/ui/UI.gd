class_name UI
extends Object
## Small helpers for building the pixel UI consistently from code.

const BG        := Color8(16, 20, 34)
const PANEL     := Color8(30, 39, 64)
const PANEL_DK  := Color8(20, 25, 42)
const EDGE      := Color8(90, 122, 176)
const EDGE_HI   := Color8(138, 168, 224)
const TEXT      := Color8(232, 238, 250)
const TEXT_DIM  := Color8(150, 165, 200)
const GOLD      := Color8(232, 194, 70)
const RED       := Color8(200, 64, 80)
const GREEN     := Color8(80, 190, 130)
const BLUE      := Color8(88, 168, 224)

const FS_S := 8
const FS_M := 10
const FS_L := 14
const FS_XL := 20


static func label(text: String, size: int = FS_M, color: Color = TEXT,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func rich(text: String, size: int = FS_M, color: Color = TEXT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = text
	r.fit_content = true
	r.scroll_active = false
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_color_override("default_color", color)
	return r


static func panel_style(fill: Color = PANEL, edge: Color = EDGE,
		width: int = 1, radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 4
	s.content_margin_right = 4
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s


static func panel(rect: Rect2, fill: Color = PANEL, edge: Color = EDGE) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", panel_style(fill, edge))
	return p


static func rect(r: Rect2, color: Color) -> ColorRect:
	var c := ColorRect.new()
	c.position = r.position
	c.size = r.size
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func button(text: String, size: int = FS_M) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_focus_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_stylebox_override("normal", panel_style(PANEL, EDGE))
	b.add_theme_stylebox_override("hover", panel_style(PANEL.lightened(0.12), EDGE_HI))
	b.add_theme_stylebox_override("pressed", panel_style(PANEL_DK, EDGE_HI))
	b.add_theme_stylebox_override("focus", panel_style(PANEL.lightened(0.08), GOLD))
	b.add_theme_stylebox_override("disabled", panel_style(PANEL_DK, EDGE.darkened(0.4)))
	return b


static func texture(tex: Texture2D, pos: Vector2, scale: float = 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.position = pos
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tex:
		t.size = tex.get_size() * scale
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Full-screen backdrop with a soft vertical gradient.
static func backdrop(top: Color = Color8(14, 18, 32),
		bottom: Color = Color8(34, 24, 52)) -> Control:
	var g := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, top)
	grad.set_color(1, bottom)
	g.gradient = grad
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.width = 8
	g.height = 64
	var t := TextureRect.new()
	t.texture = g
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## A framed dialogue / info box.
static func box(rect_: Rect2, title: String = "") -> Control:
	var root := Control.new()
	root.position = rect_.position
	root.size = rect_.size
	var p := Panel.new()
	p.size = rect_.size
	p.add_theme_stylebox_override("panel", panel_style(Color8(20, 26, 44), EDGE_HI))
	root.add_child(p)
	if title != "":
		var bar := ColorRect.new()
		bar.size = Vector2(rect_.size.x - 8, 11)
		bar.position = Vector2(4, 3)
		bar.color = Color8(42, 56, 92)
		root.add_child(bar)
		var l := label(title, FS_S, GOLD)
		l.position = Vector2(8, 3)
		l.size = Vector2(rect_.size.x - 16, 11)
		root.add_child(l)
	return root
