# =============================================================================
# dialogue_box.gd  -  The SNES-style text box: portrait, name, typed text, choices
# -----------------------------------------------------------------------------
# WHAT:  Draws whatever the Dialogue autoload hands it:
#          show_line(name, text, portrait, color)   typed letter by letter
#          show_choices(["Why?", "Okay."])          a menu above the box
#        Interact (E / Enter / gamepad A) or attack (Space) finishes the
#        typing, then asks for the next beat. Up/down move through choices.
#        Built in code, so there's no fiddly node tree to keep in sync.
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

## Letters per second while typing.
@export var chars_per_second := 48.0
## Input is ignored this long after the box opens, so the press that started
## the conversation can't also skip its first line.
@export var open_guard_seconds := 0.15

const BOX_HEIGHT := 78
const MARGIN := 8
const PORTRAIT_PX := 64
const FONT_SIZE := 11
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
	_text.text = text
	_text.visible_characters = 0
	_typing = true
	_char_time = 0.0
	_arrow.visible = false


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


func hide_box() -> void:
	visible = false
	_typing = false
	_hide_choices()


func is_typing() -> bool:
	return _typing


func is_showing_choices() -> bool:
	return _choices_panel.visible


## The line currently on screen (tests read it).
func current_text() -> String:
	return _text.text


func _process(delta: float) -> void:
	if not visible:
		return
	_since_open += delta
	if not _typing:
		return
	_char_time += delta * chars_per_second
	var total := _text.get_total_character_count()
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
		else:
			advance_requested.emit()


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
# Building the nodes
# -----------------------------------------------------------------------------
func _build() -> void:
	_frame = SafeFrame.new()
	_frame.name = "SafeFrame"
	add_child(_frame)

	_box = PanelContainer.new()
	_box.name = "Box"
	_box.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, 6))
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = MARGIN
	_box.offset_right = -MARGIN
	_box.offset_top = -BOX_HEIGHT - MARGIN
	_box.offset_bottom = -MARGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.15, 0.13, 0.2), BORDER.darkened(0.3), 1, 0))
	_portrait_frame.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text.add_theme_color_override("default_color", Color(0.95, 0.95, 0.97))
	_text.add_theme_constant_override("line_separation", 2)
	row.add_child(_text)

	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.add_theme_font_size_override("font_size", FONT_SIZE)
	_arrow.add_theme_color_override("font_color", BORDER)
	_arrow.anchor_left = 1.0
	_arrow.anchor_right = 1.0
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = -MARGIN - 16
	_arrow.offset_top = -MARGIN - 18
	_frame.add_child(_arrow)
	var blink := create_tween().set_loops()
	blink.tween_property(_arrow, "modulate:a", 0.2, 0.4)
	blink.tween_property(_arrow, "modulate:a", 1.0, 0.4)

	_name_tab = PanelContainer.new()
	_name_tab.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, 4))
	_name_tab.anchor_top = 1.0
	_name_tab.anchor_bottom = 1.0
	_name_tab.offset_left = MARGIN + 6
	_name_tab.offset_top = -BOX_HEIGHT - MARGIN - 16
	_name_tab.offset_bottom = -BOX_HEIGHT - MARGIN + 2
	_frame.add_child(_name_tab)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", FONT_SIZE)
	_name_tab.add_child(_name)

	_choices_panel = PanelContainer.new()
	_choices_panel.add_theme_stylebox_override("panel", _style(BG, BORDER, 2, 6))
	_choices_panel.anchor_left = 1.0
	_choices_panel.anchor_right = 1.0
	_choices_panel.anchor_top = 1.0
	_choices_panel.anchor_bottom = 1.0
	_choices_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_choices_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices_panel.offset_right = -MARGIN
	_choices_panel.offset_bottom = -BOX_HEIGHT - MARGIN - 4
	_frame.add_child(_choices_panel)
	_choices_list = VBoxContainer.new()
	_choices_panel.add_child(_choices_list)
	_choices_panel.visible = false


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
