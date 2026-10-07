# =============================================================================
# menu_theme.gd  -  The look shared by every menu (pause, settings)
# -----------------------------------------------------------------------------
# WHAT:  Builds one Theme in code: the dialogue box's dark panel and gold
#        border, buttons that light up gold when focused (so a gamepad player
#        always sees where they are), and one small font size that stays crisp
#        on the 640x360 base view.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name MenuTheme
extends RefCounted

const BG := Color(0.06, 0.05, 0.1, 0.94)
const BORDER := Color(0.95, 0.85, 0.6)
const TEXT := Color(0.9, 0.9, 0.95)
const DIM := Color(0.62, 0.62, 0.72)
const FOCUS_BG := Color(0.95, 0.85, 0.6, 0.18)
const FONT_SIZE := 10
const TITLE_SIZE := 14

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = FONT_SIZE
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER, 2, 8))
	t.set_stylebox("panel", "Panel", box(BG, BORDER, 2, 8))
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1, 3))
	t.set_stylebox("hover", "Button", box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 1, 3))
	t.set_stylebox("pressed", "Button", box(FOCUS_BG, BORDER, 1, 3))
	t.set_stylebox("focus", "Button", box(FOCUS_BG, BORDER, 1, 3))
	t.set_stylebox("disabled", "Button", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1, 3))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", BORDER)
	t.set_color("font_pressed_color", "Button", BORDER)
	t.set_color("font_disabled_color", "Button", DIM)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_theme = t
	return t


static func box(bg: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(pad)
	s.content_margin_top = maxf(pad - 2, 1)
	s.content_margin_bottom = maxf(pad - 2, 1)
	return s
