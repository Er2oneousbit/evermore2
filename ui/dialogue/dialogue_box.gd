# =============================================================================
# dialogue_box.gd  -  The SNES-style text box: portrait, name, typed text, choices
# -----------------------------------------------------------------------------
# WHAT:  Draws whatever the Dialogue autoload hands it:
#          show_line(name, text, portrait, color)   typed letter by letter
#          show_choices(["Why?", "Okay."])          a menu above the box
#        Interact (E / Enter / gamepad A) or attack (Space) finishes the
#        typing, turns the page, then asks for the next beat. Up/down move
#        through choices. Built in code, so there's no node tree to keep in sync.
#
# SIZE FOLLOWS THE TEXT: the box is as wide as its widest line (at least
#        MIN_WIDTH, at most the safe frame) and centered at the bottom; it's
#        one line tall up to MAX_LINES (never shorter than the portrait when
#        there is one). Longer text is split into pages automatically, and a
#        line that spans pages keeps one width so the box doesn't jump. The wrapping is done
#        here, word by word with the label's own font, and the label gets the
#        lines ready-made (its own autowrap is off), so what we measure is
#        exactly what's drawn: nothing can spill out of the box.
#
# ANY SCREEN: everything sits inside its own SafeFrame (centered 16:9), so on
#        a 32:9 monitor the box stays in the middle of your view.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DialogueBox
extends CanvasLayer

signal advance_requested
signal choice_made(index: int)

## Letters per second while typing at the Normal text speed (the player's
## Text speed setting scales it).
@export var chars_per_second := 48.0
## The Normal text speed in Settings, which chars_per_second is tuned for.
const DEFAULT_CPS := 48.0
## Input is ignored this long after the box opens (game time), so the press
## that started the conversation can't also skip its first line.
@export var open_guard_seconds := 0.15

## Most lines shown at once; more text turns into pages.
const MAX_LINES := 4
## Narrowest the box gets, so a one-word line still reads as a box.
const MIN_WIDTH := 160.0
## Slack added to measured text so the label never clips its last letter.
const TEXT_SLACK := 2.0
const MARGIN := 8
const PAD := 6
const PORTRAIT_PX := 64
const PORTRAIT_GAP := 8
## Room kept clear at the right edge for the blinking "more" arrow.
const ARROW_ROOM := 14
const FONT_SIZE := 11
const LINE_GAP := 2
const BG := Color(0.06, 0.05, 0.1, 0.9)
const BORDER := Color(0.95, 0.85, 0.6)

var _frame: SafeFrame
var _box: PanelContainer
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name_tab: PanelContainer
var _name: Label
var _text: RichTextLabel
var _arrow: Label
var _choices_panel: PanelContainer
var _choices_list: VBoxContainer

var _full_text := ""
var _pages: Array[String] = []
var _page := 0
var _typing := false
var _char_time := 0.0
var _options: PackedStringArray = []
var _selected := 0
## Seconds (game time) since the box opened; see open_guard_seconds.
var _since_open := 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## Show one line. portrait may be null (narration, unknown speaker).
func show_line(speaker: String, text: String, portrait: Texture2D, color := Color.WHITE) -> void:
	_open()
	_hide_choices()
	_name_tab.visible = not speaker.is_empty()
	_name.text = speaker
	_name.add_theme_color_override("font_color", color)
	_portrait_frame.visible = portrait != null
	_portrait.texture = portrait
	_full_text = text
	_pages = paginate(text, _text_width())
	_show_page(0)


## Show a menu. The current line stays visible underneath.
func show_choices(options: PackedStringArray) -> void:
	_open()
	_typing = false
	_text.visible_characters = -1
	_arrow.visible = false
	_options = options
	_selected = 0
	for c in _choices_list.get_children():
		c.queue_free()
	for i in options.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", FONT_SIZE)
		_choices_list.add_child(l)
	_choices_panel.visible = true
	_refresh_choices()
	_layout()


func hide_box() -> void:
	visible = false
	_typing = false
	_hide_choices()


func is_typing() -> bool:
	return _typing


func is_showing_choices() -> bool:
	return _choices_panel.visible


## The whole line being shown, across all its pages (tests read it).
func current_text() -> String:
	return _full_text


func page_count() -> int:
	return _pages.size()


func current_page() -> int:
	return _page


## The box's height in base pixels right now (tests read it).
func box_height() -> float:
	return -_box.offset_top - MARGIN


## The box's width in base pixels right now (tests read it).
func box_width() -> float:
	return _box.offset_right - _box.offset_left


## Widest the box may get: the safe frame minus its margins.
func max_box_width() -> float:
	return _frame.size.x - MARGIN * 2


## Split text into pages of at most MAX_LINES lines, each at most `width`
## pixels wide in the box font. Words longer than a whole line are broken.
## Each page comes back with its lines joined by "\n".
func paginate(text: String, width: float) -> Array[String]:
	var font := _font()
	var lines: PackedStringArray = []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if _width_of(font, candidate) <= width:
				line = candidate
				continue
			if not line.is_empty():
				lines.append(line)
				line = ""
			# A single word wider than the box: break it by characters.
			var rest := word
			while _width_of(font, rest) > width and rest.length() > 1:
				var cut := rest.length() - 1
				while cut > 1 and _width_of(font, rest.substr(0, cut)) > width:
					cut -= 1
				lines.append(rest.substr(0, cut))
				rest = rest.substr(cut)
			line = rest
		lines.append(line)
	var pages: Array[String] = []
	for i in range(0, lines.size(), MAX_LINES):
		pages.append("\n".join(lines.slice(i, i + MAX_LINES)))
	if pages.is_empty():
		pages.append("")
	return pages


func _process(delta: float) -> void:
	if not visible:
		return
	_since_open += delta
	if not _typing:
		return
	var total := _text.get_total_character_count()
	# The player's text speed (Settings); 0 = whole pages at once.
	var cps: float = Settings.get_value("text_speed")
	if cps <= 0.0:
		_char_time = total
	else:
		_char_time += delta * cps * chars_per_second / DEFAULT_CPS
	_text.visible_characters = mini(int(_char_time), total)
	if _text.visible_characters >= total:
		_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var confirm := event.is_action_pressed("interact") or event.is_action_pressed("attack")
	if is_showing_choices():
		if event.is_action_pressed("move_up"):
			_selected = wrapi(_selected - 1, 0, _options.size())
			_refresh_choices()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_down"):
			_selected = wrapi(_selected + 1, 0, _options.size())
			_refresh_choices()
			get_viewport().set_input_as_handled()
		elif confirm and _guard_passed():
			get_viewport().set_input_as_handled()
			var picked := _selected
			_hide_choices()
			choice_made.emit(picked)
		return
	if confirm:
		get_viewport().set_input_as_handled()
		if not _guard_passed():
			return
		if _typing:
			_finish_typing()
		elif _page + 1 < _pages.size():
			_show_page(_page + 1)
		else:
			advance_requested.emit()


func _show_page(i: int) -> void:
	_page = i
	_text.text = _pages[i]
	_text.visible_characters = 0
	_typing = true
	_char_time = 0.0
	_arrow.visible = false
	_layout()


## Game time, not the wall clock: the guard has to behave the same at any
## frame rate, including headless tests that run faster than real time.
func _guard_passed() -> bool:
	return _since_open >= open_guard_seconds


func _open() -> void:
	if not visible:
		_since_open = 0.0
	visible = true


func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_arrow.visible = true


func _hide_choices() -> void:
	_choices_panel.visible = false
	_options = []


func _refresh_choices() -> void:
	for i in _choices_list.get_child_count():
		var l := _choices_list.get_child(i) as Label
		var on := i == _selected
		l.text = ("> " if on else "  ") + _options[i]
		l.add_theme_color_override("font_color", BORDER if on else Color(0.85, 0.85, 0.9))


# -----------------------------------------------------------------------------
# Sizing
# -----------------------------------------------------------------------------
func _font() -> Font:
	return _text.get_theme_font("normal_font")


func _width_of(font: Font, s: String) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


func _line_height() -> float:
	return _font().get_height(FONT_SIZE) + LINE_GAP


## Everything in the box that isn't text: padding, arrow room, portrait.
func _chrome_width() -> float:
	var w := (PAD + 2) * 2 + ARROW_ROOM + TEXT_SLACK
	if _portrait_frame.visible:
		w += PORTRAIT_PX + PORTRAIT_GAP
	return w


## Widest a line of text may be (the box at its widest, minus the chrome).
func _text_width() -> float:
	return maxf(max_box_width() - _chrome_width(), 40.0)


## Widest line across all pages of the current text.
func _widest_line() -> float:
	var font := _font()
	var widest := 0.0
	for p in _pages:
		for l in p.split("\n"):
			widest = maxf(widest, _width_of(font, l))
	return widest


## Fit the box to the current page, then hang the name tab and the choices
## off its top edge.
func _layout() -> void:
	# Height: this page's lines (or the portrait, if taller).
	var lines := _text.text.count("\n") + 1
	var text_h := lines * _line_height()
	var inner := maxf(text_h, PORTRAIT_PX if _portrait_frame.visible else 0.0)
	var height := ceilf(inner + PAD * 2)
	_box.offset_top = -MARGIN - height
	# Width: the widest line of the whole text, centered.
	var width := clampf(ceilf(_widest_line() + _chrome_width()), MIN_WIDTH, max_box_width())
	_box.offset_left = -floorf(width * 0.5)
	_box.offset_right = _box.offset_left + width
	var top := _box.offset_top
	_name_tab.offset_top = top - 16
	_name_tab.offset_bottom = top + 2
	_name_tab.offset_left = _box.offset_left + 6
	# Hug the name: both edges are set, or the tab stretches to the anchor.
	_name_tab.offset_right = _name_tab.offset_left + _name_tab.get_combined_minimum_size().x
	_arrow.offset_left = _box.offset_right - 16
	_arrow.offset_right = _box.offset_right - 4
	_choices_panel.offset_bottom = top - 4
	_choices_panel.offset_right = _box.offset_right


# -----------------------------------------------------------------------------
# Building the nodes
# -----------------------------------------------------------------------------
func _build() -> void:
	_frame = SafeFrame.new()
	_frame.name = "SafeFrame"
	add_child(_frame)

	_box = PanelContainer.new()
	_box.name = "Box"
	_box.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, PAD))
	_box.anchor_left = 0.5
	_box.anchor_right = 0.5
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_bottom = -MARGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PORTRAIT_GAP)
	_box.add_child(row)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.15, 0.13, 0.2), BORDER.darkened(0.3), 1, 0))
	_portrait_frame.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	_portrait_frame.add_child(_portrait)

	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = false
	_text.scroll_active = false
	# Lines arrive pre-wrapped (see paginate), so the label must not rewrap.
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_color_override("default_color", Color(0.95, 0.95, 0.97))
	_text.add_theme_constant_override("line_separation", LINE_GAP)
	row.add_child(_text)

	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	_arrow.add_theme_color_override("font_color", BORDER)
	_arrow.anchor_left = 0.5
	_arrow.anchor_right = 0.5
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_top = -MARGIN - 18
	_frame.add_child(_arrow)
	var blink := create_tween().set_loops()
	blink.tween_property(_arrow, "modulate:a", 0.2, 0.4)
	blink.tween_property(_arrow, "modulate:a", 1.0, 0.4)

	_name_tab = PanelContainer.new()
	_name_tab.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, 4))
	_name_tab.anchor_left = 0.5
	_name_tab.anchor_right = 0.5
	_name_tab.anchor_top = 1.0
	_name_tab.anchor_bottom = 1.0
	_frame.add_child(_name_tab)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_tab.add_child(_name)

	_choices_panel = PanelContainer.new()
	_choices_panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, 6))
	_choices_panel.anchor_left = 0.5
	_choices_panel.anchor_right = 0.5
	_choices_panel.anchor_top = 1.0
	_choices_panel.anchor_bottom = 1.0
	_choices_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_frame.add_child(_choices_panel)
	_choices_list = VBoxContainer.new()
	_choices_panel.add_child(_choices_list)
	_choices_panel.visible = false
	_layout()


func _style(bg: Color, border: Color, border_px: int, pad: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_px)
	s.set_corner_radius_all(3)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = pad
	s.content_margin_bottom = pad
	return s
