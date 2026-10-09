# =============================================================================
# title_screen.gd  (main scene: ui/title/title_screen.tscn)
# -----------------------------------------------------------------------------
# WHAT:  The screen the game opens on. A live HD-2D backdrop (the Ruffleberg
#        lot's iron gate at night: fireflies, fog, a slow camera drift, the
#        crickets, the title theme), the logo fading in, a pulsing "Press any
#        key" (keyboard, gamepad or mouse), then the menu:
#          New Game   boy or girl, name the kid, name the dog, then the
#                     prologue from its very beginning (NewGameFlow)
#          Continue   greyed out and skipped by the cursor: there are no saves
#                     yet (ROADMAP, Later: save system)
#          Settings   the settings screen
#          Debug      the tech-demo start menu (ui/debug_menu), a visible item
#                     while the game is a tech demo
#          Quit
#        The pause menu's "Quit to title" and the end of the prologue slice
#        come back here (Travel.go(TitleScreen.SCENE)).
# HOW:   The backdrop is built in code after the --yard / --arena check (those
#        skip straight to their map, as with the debug menu). The kid and dog
#        every realm holds are hidden and frozen; HdView.focus_override drifts
#        the camera. PauseMenu is blocked here (Esc means "back"). The title
#        fonts are Cinzel (SIL OFL, credits/fonts); the logo's glow is a second
#        label behind with a wide gold outline that breathes.
#        start_new_game() is static: tests call it too.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name TitleScreen
extends Control

const SCENE := "res://ui/title/title_screen.tscn"
const BACKDROP := "res://realms/title/title_lot_hd.tscn"
const FONT_FILE := preload("res://assets/fonts/Cinzel.ttf")
## Where the camera rests (meters; the gate's gap is at column 19, row 7).
const FOCUS_BASE := Vector3(19.5, 0.0, 9.6)
## Seconds before the logo starts to fade in, how long it takes, and when
## "Press any key" shows up.
const LOGO_DELAY := 0.6
const LOGO_FADE := 2.4
const PROMPT_AT := 3.4
const GOLD := Color(0.95, 0.85, 0.6)

enum Phase { LOGO, MENU, SUB }

## The menu entries, in order.
const ITEMS := [
	{"id": "new_game", "label": "New Game"},
	{"id": "continue", "label": "Continue", "disabled": true},
	{"id": "settings", "label": "Settings"},
	{"id": "debug", "label": "Debug"},
	{"id": "quit", "label": "Quit"},
]

var phase := Phase.LOGO
var menu_buttons := {}
var logo_label: Label
var subtitle_label: Label
var prompt_label: Label

var _hd: HdView
var _t := 0.0
var _age := 0.0
var _layout: Control
var _ui: Control
var _frame: SafeFrame
var _menu_box: VBoxContainer
var _flow: NewGameFlow
var _settings: SettingsMenu
var _building := true
var _tweens: Array[Tween] = []
var _blocked_pause := false


func _ready() -> void:
	# --yard / --arena: Debug is already on its way there.
	if not Debug.start_scene_for(OS.get_cmdline_user_args()).is_empty():
		return
	PauseMenu.blocked = true
	_blocked_pause = true
	theme = title_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_backdrop()
	_build()
	get_viewport().gui_focus_changed.connect(func(_c: Control) -> void:
		if not _building:
			Audio.play("ui_move"))
	_building = false
	_start_intro()


func _exit_tree() -> void:
	if _blocked_pause:
		PauseMenu.blocked = false


func _process(delta: float) -> void:
	_age += delta
	_t += delta
	if is_instance_valid(_hd):
		# A slow, wide drift: a few meters side to side, a little in depth.
		_hd.focus_override = FOCUS_BASE + Vector3(sin(_t * 0.11) * 3.2, 0.0, cos(_t * 0.08) * 0.6)


# -----------------------------------------------------------------------------
# Theme and fonts
# -----------------------------------------------------------------------------
static func title_theme() -> Theme:
	var t: Theme = MenuTheme.get_theme().duplicate()
	t.default_font = heading_font(500)
	return t


static func heading_font(weight: int) -> Font:
	var f := FontVariation.new()
	f.base_font = FONT_FILE
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("weight")
	f.variation_opentype = {tag: weight}
	return f


# -----------------------------------------------------------------------------
# Backdrop
# -----------------------------------------------------------------------------
func _add_backdrop() -> void:
	var scene := load(BACKDROP) as PackedScene
	var back := scene.instantiate()
	back.name = "Backdrop"
	add_child(back)
	move_child(back, 0)
	var realm := back.get_node("Yard")
	# Every realm holds the kid and dog; here they're only furniture.
	for path in ["World/Kid", "World/Dog"]:
		var a := realm.get_node(path) as Node2D
		a.visible = false
		a.process_mode = Node.PROCESS_MODE_DISABLED
	(realm.get_node("World/Kid") as Kid).light_on = false
	_hd = back.get_node("HdView") as HdView
	_hd.focus_override = FOCUS_BASE
	_hd.snap_camera()


# -----------------------------------------------------------------------------
# Building the screen
# -----------------------------------------------------------------------------
func _build() -> void:
	# Own canvas layer: the realm's Camera2D moves the default canvas (it
	# shifted the whole UI up by 144 px), a CanvasLayer ignores it.
	var layer := CanvasLayer.new()
	layer.name = "UiLayer"
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.name = "Ui"
	_ui.theme = title_theme()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	# Soft darkening top and bottom so the text reads on any part of the picture.
	_ui.add_child(_shade(true))
	_ui.add_child(_shade(false))
	_frame = SafeFrame.new()
	_frame.name = "Frame"
	_ui.add_child(_frame)
	_layout = Control.new()
	_layout.name = "Layout"
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_layout)

	var parts := Names.text("game_title").split(": ", false, 1)
	var logo_box := VBoxContainer.new()
	logo_box.name = "Logo"
	logo_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	logo_box.offset_top = 34
	logo_box.add_theme_constant_override("separation", 2)
	_layout.add_child(logo_box)
	logo_label = _logo_text(parts[0], 34, 700)
	logo_label.name = "Title"
	logo_box.add_child(logo_label)
	if parts.size() > 1:
		subtitle_label = _logo_text(parts[1], 15, 500)
		subtitle_label.name = "Subtitle"
		subtitle_label.add_theme_color_override("font_color", Color(0.78, 0.84, 1.0))
		logo_box.add_child(subtitle_label)

	var bottom := Control.new()
	bottom.name = "Bottom"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -170
	bottom.offset_bottom = -30
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(bottom)

	prompt_label = Label.new()
	prompt_label.name = "Prompt"
	prompt_label.text = "Press any key"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.92, 0.92, 1.0))
	prompt_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08))
	prompt_label.add_theme_constant_override("outline_size", 4)
	prompt_label.modulate.a = 0.0
	bottom.add_child(prompt_label)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(center)
	_menu_box = VBoxContainer.new()
	_menu_box.name = "Menu"
	_menu_box.add_theme_constant_override("separation", 2)
	_menu_box.custom_minimum_size = Vector2(150, 0)
	_menu_box.modulate.a = 0.0
	_menu_box.visible = false
	center.add_child(_menu_box)
	for item: Dictionary in ITEMS:
		_menu_box.add_child(_menu_button(item))

	var ver := Label.new()
	ver.name = "Version"
	ver.text = "v%s  tech demo" % ProjectSettings.get_setting("application/config/version", "?")
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 8
	ver.offset_top = -14
	ver.offset_bottom = -2
	ver.add_theme_font_size_override("font_size", 8)
	ver.add_theme_color_override("font_color", Color(0.7, 0.72, 0.85, 0.7))
	_layout.add_child(ver)


func _shade(top: bool) -> TextureRect:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0.04, 0.0 if top else 0.82), Color(0, 0, 0.04, 0.55 if top else 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_LINEAR
	# Color 0 sits at the bottom edge, color 1 at the top edge, for both.
	gt.fill_from = Vector2(0, 1)
	gt.fill_to = Vector2(0, 0)
	gt.width = 4
	gt.height = 64
	var r := TextureRect.new()
	r.name = "ShadeTop" if top else "ShadeBottom"
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		r.offset_bottom = 150
	else:
		r.offset_top = -190
	return r


## Logo text: outline and shadow for body, a second label behind with a wide
## faint gold outline for the glow.
func _logo_text(text: String, size: int, weight: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", heading_font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.98, 0.93, 0.78))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.12))
	l.add_theme_constant_override("outline_size", maxi(2, size / 7))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(1, size / 14))
	l.modulate.a = 0.0
	var glow := Label.new()
	glow.name = "Glow"
	glow.text = text
	glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.show_behind_parent = true
	glow.add_theme_font_override("font", heading_font(weight))
	glow.add_theme_font_size_override("font_size", size)
	glow.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	glow.add_theme_color_override("font_outline_color", Color(1.0, 0.82, 0.45, 0.22))
	glow.add_theme_constant_override("outline_size", maxi(6, size / 2))
	l.add_child(glow)
	return l


func _menu_button(item: Dictionary) -> Button:
	var b := Button.new()
	b.name = String(item["label"]).replace(" ", "")
	b.text = item["label"]
	b.focus_mode = Control.FOCUS_NONE if item.get("disabled", false) else Control.FOCUS_ALL
	b.disabled = item.get("disabled", false)
	if b.disabled:
		b.tooltip_text = "No saves yet."
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.08))
	b.add_theme_constant_override("outline_size", 3)
	var id: String = item["id"]
	b.pressed.connect(func() -> void:
		Audio.play("ui_confirm")
		activate(id))
	menu_buttons[id] = b
	return b


# -----------------------------------------------------------------------------
# The intro and the menu
# -----------------------------------------------------------------------------
func _start_intro() -> void:
	var t := create_tween()
	_tweens.append(t)
	t.tween_interval(LOGO_DELAY)
	t.tween_property(logo_label, "modulate:a", 1.0, LOGO_FADE)
	if subtitle_label:
		t.tween_property(subtitle_label, "modulate:a", 1.0, 1.4)
	t.tween_interval(maxf(0.0, PROMPT_AT - LOGO_DELAY - LOGO_FADE - 1.4))
	t.tween_property(prompt_label, "modulate:a", 1.0, 0.8)
	t.tween_callback(_pulse_prompt)
	# The glows breathe for as long as the screen is up.
	for l: Label in [logo_label, subtitle_label]:
		if l == null:
			continue
		var g := l.get_node("Glow") as Label
		var gt := create_tween().set_loops()
		gt.tween_property(g, "modulate:a", 0.35, 2.2).set_trans(Tween.TRANS_SINE)
		gt.tween_property(g, "modulate:a", 1.0, 2.2).set_trans(Tween.TRANS_SINE)


func _pulse_prompt() -> void:
	if phase != Phase.LOGO:
		return
	var p := create_tween().set_loops()
	_tweens.append(p)
	p.tween_property(prompt_label, "modulate:a", 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	p.tween_property(prompt_label, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if phase != Phase.LOGO or _age < 0.3 or Travel.busy:
		return
	var any := false
	if event is InputEventKey:
		any = event.pressed and not event.echo
	elif event is InputEventJoypadButton or event is InputEventMouseButton:
		any = event.pressed
	if any:
		reveal_menu()
		get_viewport().set_input_as_handled()


## Any key was pressed: logo and prompt give way to the menu.
func reveal_menu() -> void:
	if phase != Phase.LOGO:
		return
	phase = Phase.MENU
	for t in _tweens:
		t.kill()
	_tweens.clear()
	Audio.play("ui_confirm")
	# Whatever the logo had reached, finish it.
	var fin := create_tween().set_parallel(true)
	fin.tween_property(logo_label, "modulate:a", 1.0, 0.4)
	if subtitle_label:
		fin.tween_property(subtitle_label, "modulate:a", 1.0, 0.4)
	fin.tween_property(prompt_label, "modulate:a", 0.0, 0.3)
	_menu_box.visible = true
	fin.tween_property(_menu_box, "modulate:a", 1.0, 0.7)
	_building = true
	(menu_buttons["new_game"] as Button).grab_focus()
	_building = false


## The menu items that can be picked (ids, in order): Continue isn't one.
func selectable_ids() -> Array[String]:
	var out: Array[String] = []
	for item: Dictionary in ITEMS:
		if not item.get("disabled", false):
			out.append(item["id"])
	return out


func activate(id: String) -> void:
	if phase != Phase.MENU or Travel.busy:
		return
	match id:
		"new_game":
			_open_new_game()
		"settings":
			_open_settings()
		"debug":
			Travel.go(DebugMenu.SCENE, "", false)
		"quit":
			get_tree().quit()


func _enter_sub(on: bool) -> void:
	phase = Phase.SUB if on else Phase.MENU
	_layout.visible = not on


func _leave_sub(focus: String) -> void:
	_enter_sub(false)
	Audio.play("ui_back")
	_building = true
	(menu_buttons[focus] as Button).grab_focus.call_deferred()
	_building = false


func _open_new_game() -> void:
	_enter_sub(true)
	_flow = NewGameFlow.new()
	_flow.name = "NewGame"
	_flow.cancelled.connect(func() -> void:
		_flow.queue_free()
		_flow = null
		_leave_sub("new_game"))
	_flow.finished.connect(func(kid: String, dog: String, gender: String) -> void:
		start_new_game(kid, dog, gender))
	_frame.add_child(_flow)


func _open_settings() -> void:
	_enter_sub(true)
	_settings = SettingsMenu.new()
	_settings.name = "Settings"
	_settings.closed.connect(func() -> void:
		_settings.queue_free()
		_settings = null
		_leave_sub("settings"))
	_ui.add_child(_settings)


## Begin a fresh run: the starting kit, the chosen names and gender, and the
## prologue from its first card (same as the debug menu's "Prologue (from the
## start)", which clears the prologue's flags). False if Travel refused.
static func start_new_game(kid: String, dog: String, gender: String) -> bool:
	GameState.new_game()
	GameState.kid_name = kid
	GameState.dog_name = dog
	return await DebugMenu.begin("prologue", "day", GameState.difficulty, gender)
