class_name UiTheme
extends RefCounted
## 게임 전체에서 쓰는 색상 팔레트와 Theme 리소스를 코드로 만든다.
## (에디터에서 고치고 싶다면 build()로 만든 Theme을 ResourceSaver로 저장해 .tres로 써도 된다.)

const BG := Color("161935")
const PANEL := Color(0.075, 0.08, 0.19, 0.88)
const PANEL_SOFT := Color(1, 1, 1, 0.06)
const PANEL_DEEP := Color(0, 0, 0, 0.28)
const LINE := Color(1, 1, 1, 0.09)
const GOLD := Color("ffc93c")
const GOLD_HOVER := Color("ffd966")
const GOLD_DARK := Color("d99a00")
const INK := Color("2a1f45")
const TEXT := Color("f5f3ff")
const MUTED := Color("a9abd0")
const GOOD := Color("4ade80")
const BAD := Color("ff6b6b")
const SKY := Color("7dd3fc")
const VIOLET := Color("a78bfa")

const FONT_PATH := "res://assets/fonts/Jua-Regular.ttf"
const ICON_DIR := "res://assets/icons/"


static func font() -> Font:
	return load(FONT_PATH)


static func icon(icon_name: String) -> Texture2D:
	return load(ICON_DIR + icon_name + ".svg")


static func box(color: Color, radius: int = 16, margin: float = 12.0,
		border: int = 0, border_color: Color = Color.TRANSPARENT,
		shadow: int = 0, shadow_offset: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10
	sb.set_content_margin_all(margin)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if shadow > 0:
		sb.shadow_size = shadow
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_offset = shadow_offset
	sb.anti_aliasing = true
	return sb


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22

	# ── Label ─────────────────────────────────────────────
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.0))

	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", 82)
	t.set_color("font_color", "TitleLabel", GOLD)
	t.set_color("font_outline_color", "TitleLabel", INK)
	t.set_constant("outline_size", "TitleLabel", 18)
	t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "TitleLabel", 0)
	t.set_constant("shadow_offset_y", "TitleLabel", 8)

	t.set_type_variation("HeadingLabel", "Label")
	t.set_font_size("font_size", "HeadingLabel", 28)
	t.set_color("font_color", "HeadingLabel", TEXT)

	t.set_type_variation("MutedLabel", "Label")
	t.set_font_size("font_size", "MutedLabel", 18)
	t.set_color("font_color", "MutedLabel", MUTED)

	t.set_type_variation("BigLabel", "Label")
	t.set_font_size("font_size", "BigLabel", 44)
	t.set_color("font_outline_color", "BigLabel", INK)
	t.set_constant("outline_size", "BigLabel", 10)

	t.set_type_variation("ChipLabel", "Label")
	t.set_font_size("font_size", "ChipLabel", 16)
	t.set_color("font_color", "ChipLabel", INK)
	t.set_stylebox("normal", "ChipLabel", box(GOLD, 999, 4.0))

	# ── Panel ─────────────────────────────────────────────
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 24, 22.0, 1, LINE, 18, Vector2(0, 8)))
	t.set_stylebox("panel", "Panel", box(PANEL, 24, 0.0, 1, LINE))
	t.set_type_variation("SoftPanel", "PanelContainer")
	t.set_stylebox("panel", "SoftPanel", box(PANEL_DEEP, 16, 14.0))
	t.set_type_variation("GlassPanel", "PanelContainer")
	t.set_stylebox("panel", "GlassPanel", box(Color(0.075, 0.08, 0.19, 0.62), 20, 14.0, 1, LINE))

	# ── Button ────────────────────────────────────────────
	var btn_normal := box(PANEL_SOFT, 14, 12.0, 1, LINE)
	var btn_hover := box(Color(1, 1, 1, 0.12), 14, 12.0, 1, Color(GOLD, 0.6))
	var btn_pressed := box(Color(0, 0, 0, 0.25), 14, 12.0, 1, Color(GOLD, 0.8))
	var btn_disabled := box(Color(1, 1, 1, 0.03), 14, 12.0)
	var focus := box(Color.TRANSPARENT, 14, 12.0, 2, Color(GOLD, 0.9))
	focus.draw_center = false
	for type_name in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type_name, btn_normal)
		t.set_stylebox("hover", type_name, btn_hover)
		t.set_stylebox("pressed", type_name, btn_pressed)
		t.set_stylebox("hover_pressed", type_name, btn_pressed)
		t.set_stylebox("disabled", type_name, btn_disabled)
		t.set_stylebox("focus", type_name, focus)
		t.set_color("font_color", type_name, TEXT)
		t.set_color("font_hover_color", type_name, GOLD_HOVER)
		t.set_color("font_pressed_color", type_name, GOLD)
		t.set_color("font_focus_color", type_name, TEXT)
		t.set_color("font_disabled_color", type_name, Color(MUTED, 0.5))
		t.set_color("icon_normal_color", type_name, TEXT)
		t.set_color("icon_hover_color", type_name, GOLD_HOVER)
		t.set_color("icon_pressed_color", type_name, GOLD)
		t.set_color("icon_focus_color", type_name, TEXT)
		t.set_constant("h_separation", type_name, 10)
		t.set_constant("icon_max_width", type_name, 28)

	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(GOLD, 18, 16.0, 0, Color.TRANSPARENT, 10, Vector2(0, 6)))
	t.set_stylebox("hover", "PrimaryButton", box(GOLD_HOVER, 18, 16.0, 0, Color.TRANSPARENT, 14, Vector2(0, 8)))
	var primary_pressed := box(GOLD_DARK, 18, 16.0, 0, Color.TRANSPARENT, 4, Vector2(0, 2))
	primary_pressed.content_margin_top = 19
	primary_pressed.content_margin_bottom = 13
	t.set_stylebox("pressed", "PrimaryButton", primary_pressed)
	t.set_stylebox("hover_pressed", "PrimaryButton", primary_pressed)
	t.set_stylebox("disabled", "PrimaryButton", box(Color(GOLD, 0.35), 18, 16.0))
	var primary_focus := box(Color.TRANSPARENT, 18, 16.0, 3, Color.WHITE)
	primary_focus.draw_center = false
	t.set_stylebox("focus", "PrimaryButton", primary_focus)
	t.set_font_size("font_size", "PrimaryButton", 30)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		t.set_color(c, "PrimaryButton", INK)
	t.set_constant("icon_max_width", "PrimaryButton", 36)

	t.set_type_variation("IconButton", "Button")
	t.set_stylebox("normal", "IconButton", box(PANEL_SOFT, 999, 8.0))
	t.set_stylebox("hover", "IconButton", box(Color(1, 1, 1, 0.14), 999, 8.0))
	t.set_stylebox("pressed", "IconButton", box(Color(0, 0, 0, 0.3), 999, 8.0))
	t.set_constant("icon_max_width", "IconButton", 24)

	# ── 체크 버튼 (스위치) ────────────────────────────────
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", GOLD_HOVER)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", GOLD_HOVER)
	t.set_color("font_focus_color", "CheckButton", TEXT)
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(s, "CheckButton", empty)

	# ── 목록 ──────────────────────────────────────────────
	t.set_stylebox("panel", "ItemList", box(PANEL_DEEP, 16, 8.0))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(GOLD, 12, 8.0))
	t.set_stylebox("selected_focus", "ItemList", box(GOLD, 12, 8.0))
	t.set_stylebox("hovered", "ItemList", box(Color(1, 1, 1, 0.07), 12, 8.0))
	t.set_stylebox("hovered_selected", "ItemList", box(GOLD_HOVER, 12, 8.0))
	t.set_stylebox("hovered_selected_focus", "ItemList", box(GOLD_HOVER, 12, 8.0))
	t.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_hovered_color", "ItemList", GOLD_HOVER)
	t.set_color("font_selected_color", "ItemList", INK)
	t.set_color("font_hovered_selected_color", "ItemList", INK)
	t.set_constant("v_separation", "ItemList", 8)
	t.set_constant("h_separation", "ItemList", 12)
	t.set_constant("icon_margin", "ItemList", 10)

	# ── 입력 ──────────────────────────────────────────────
	t.set_stylebox("normal", "LineEdit", box(PANEL_DEEP, 12, 10.0, 1, LINE))
	t.set_stylebox("focus", "LineEdit", box(Color.TRANSPARENT, 12, 10.0, 2, GOLD))
	t.set_stylebox("read_only", "LineEdit", box(PANEL_DEEP, 12, 10.0))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.35))

	t.set_stylebox("panel", "PopupMenu", box(Color("20244a"), 14, 8.0, 1, LINE, 16, Vector2(0, 6)))
	t.set_stylebox("hover", "PopupMenu", box(GOLD, 10, 6.0))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_constant("item_start_padding", "PopupMenu", 12)

	t.set_stylebox("panel", "TooltipPanel", box(Color("20244a"), 10, 10.0, 1, LINE))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 18)

	# ── 슬라이더 · 진행 막대 ─────────────────────────────
	var track := box(PANEL_DEEP, 6, 0.0)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(GOLD, 6, 0.0))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD_HOVER, 6, 0.0))

	t.set_stylebox("background", "ProgressBar", box(PANEL_DEEP, 999, 0.0))
	t.set_stylebox("fill", "ProgressBar", box(GOLD, 999, 0.0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_type_variation("LevelBar", "ProgressBar")
	t.set_stylebox("fill", "LevelBar", box(GOOD, 999, 0.0))

	# ── 스크롤바 ──────────────────────────────────────────
	t.set_stylebox("scroll", "VScrollBar", box(Color.TRANSPARENT, 6, 2.0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(1, 1, 1, 0.18), 6, 4.0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(Color(1, 1, 1, 0.3), 6, 4.0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(GOLD, 6, 4.0))

	return t
