# =============================================================================
# new_game_flow.gd  -  New Game: boy or girl, name the kid, name the dog, go
# -----------------------------------------------------------------------------
# WHAT:  The screens after "New Game" on the title screen:
#          1. Boy or girl: both sprites facing the camera, the one under the
#             cursor lit and the other dimmed (left / right, Enter)
#          2. the kid's name (NameEntry), pre-filled per gender with a neutral
#             default (names.json kid_default_boy / kid_default_girl)
#          3. the dog's name, pre-filled with names.json dog_default
#          4. a summary: Begin, or Back to change something
#        Esc / gamepad B steps back one screen; from the first it leaves the
#        flow. It only collects the answers: `finished(kid, dog, gender)` is
#        emitted on Begin and TitleScreen starts the game with them.
# WHY:   The original let you name both the kid and the dog; the gender is
#        this game's own choice (design bible: kid-choice). Nothing here
#        touches GameState until Begin.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name NewGameFlow
extends Control

signal finished(kid_name: String, dog_name: String, gender: String)
signal cancelled

enum Step { GENDER, KID, DOG, CONFIRM }

## LPC idle, facing the camera (down is the third row of its set of four).
const FACING_ROW := 22 + 2

var step := Step.GENDER
var gender := "boy"
var kid_name := ""
var dog_name := ""

var gender_buttons := {}
var begin_button: Button
var back_button: Button

var _holder: CenterContainer
var _entry: NameEntry
var _kid_typed := false
var _dog_typed := false
var _age := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	gender = GameState.kid_gender
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_holder = CenterContainer.new()
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	_show(Step.GENDER)


func _process(delta: float) -> void:
	_age += delta


func _unhandled_input(event: InputEvent) -> void:
	if _age < 0.15 or not (step == Step.GENDER or step == Step.CONFIRM):
		return
	if event.is_action_pressed("ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


## One screen back; from the first, out of the flow.
func go_back() -> void:
	Audio.play("ui_back")
	match step:
		Step.GENDER:
			cancelled.emit()
		Step.KID:
			_show(Step.GENDER)
		Step.DOG:
			_show(Step.KID)
		Step.CONFIRM:
			_show(Step.DOG)


func default_kid_name() -> String:
	return Names.text("kid_default_" + gender)


func default_dog_name() -> String:
	return Names.text("dog_default")


## The current name screen (null on the other screens).
func entry() -> NameEntry:
	return _entry


# -----------------------------------------------------------------------------
func _show(to: Step) -> void:
	step = to
	if _entry:
		# It centres itself over the whole screen, so it lives beside the holder.
		remove_child(_entry)
		_entry.queue_free()
	_entry = null
	gender_buttons.clear()
	begin_button = null
	back_button = null
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()
	match to:
		Step.GENDER:
			_build_gender()
		Step.KID:
			if not _kid_typed:
				kid_name = default_kid_name()
			_build_entry("What is the kid's name?", kid_name, func(n: String) -> void:
				kid_name = n
				_kid_typed = true
				_show(Step.DOG))
		Step.DOG:
			if not _dog_typed:
				dog_name = default_dog_name()
			_build_entry("And what is the dog's name?", dog_name, func(n: String) -> void:
				dog_name = n
				_dog_typed = true
				_show(Step.CONFIRM))
		Step.CONFIRM:
			_build_confirm()


func _build_gender() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	_holder.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Boy or girl?"
	title.name = "Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", MenuTheme.BORDER)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for g: String in GenderedText.GENDERS:
		var b := _gender_button(g)
		gender_buttons[g] = b
		row.add_child(b)
	var hint := Label.new()
	hint.text = "Left / Right: choose.  Enter: pick.  Esc / B: back."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", MenuTheme.DIM)
	box.add_child(hint)
	(gender_buttons[gender] as Button).grab_focus.call_deferred()


func _gender_button(g: String) -> Button:
	var b := Button.new()
	b.name = g.capitalize()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(110, 150)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var tex := TextureRect.new()
	tex.name = "Sprite"
	var atlas := AtlasTexture.new()
	atlas.atlas = Kid.SHEETS[g]
	atlas.region = Rect2(0, FACING_ROW * LpcSprite.FRAME, LpcSprite.FRAME, LpcSprite.FRAME)
	tex.texture = atlas
	tex.custom_minimum_size = Vector2(LpcSprite.FRAME * 2, LpcSprite.FRAME * 2)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tex)
	var l := Label.new()
	l.text = g.capitalize()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 14)
	v.add_child(l)
	# The one under the cursor is lit, the other dimmed.
	var light := func(on: bool) -> void:
		tex.modulate = Color.WHITE if on else Color(0.45, 0.45, 0.55)
		if on:
			gender = g
	light.call(g == gender)
	b.focus_entered.connect(func() -> void: light.call(true))
	b.focus_exited.connect(func() -> void: light.call(false))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.pressed.connect(func() -> void:
		Audio.play("ui_confirm")
		choose_gender(g))
	return b


## Pick the gender and go on to the kid's name.
func choose_gender(g: String) -> void:
	gender = g
	_show(Step.KID)


func _build_entry(heading: String, default: String, done: Callable) -> void:
	_entry = NameEntry.new()
	_entry.name = "NameEntry"
	_entry.heading = heading
	_entry.text = default
	_entry.accepted.connect(func(n: String) -> void:
		Audio.play("ui_confirm")
		done.call(n))
	_entry.cancelled.connect(go_back)
	add_child(_entry)


func _build_confirm() -> void:
	var panel := PanelContainer.new()
	panel.name = "Panel"
	_holder.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Ready?"
	title.name = "Heading"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", MenuTheme.BORDER)
	box.add_child(title)
	var sum := Label.new()
	sum.name = "Summary"
	sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sum.custom_minimum_size = Vector2(190, 0)
	sum.text = "%s, a %s\nand %s, the dog" % [kid_name, gender, dog_name]
	box.add_child(sum)
	begin_button = Button.new()
	begin_button.name = "Begin"
	begin_button.text = "Begin"
	begin_button.focus_mode = Control.FOCUS_ALL
	begin_button.pressed.connect(begin)
	box.add_child(begin_button)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Back"
	back_button.focus_mode = Control.FOCUS_ALL
	back_button.pressed.connect(go_back)
	box.add_child(back_button)
	begin_button.grab_focus.call_deferred()


func begin() -> void:
	Audio.play("ui_confirm")
	finished.emit(kid_name, dog_name, gender)
