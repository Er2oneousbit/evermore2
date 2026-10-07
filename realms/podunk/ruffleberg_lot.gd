# =============================================================================
# ruffleberg_lot.gd  -  Prologue: dinner, then the dare at the Ruffleberg place
# -----------------------------------------------------------------------------
# WHAT:  The first playable scene of the story (design-bible.md section 5):
#          1. title card, then dinner with Dad as a conversation over black
#          2. fade in on the street outside the overgrown Ruffleberg lot at
#             dusk; Maya and Dex are waiting by the iron fence
#          3. Dex's dare sets the sun (@time night); the gate ends the slice
#        The map is an AsciiRealm (realms/_shared/ascii_realm.gd); the lines are
#        in data/dialogue/prologue.dlg.
#
# LEGEND (one character = one 32x32 tile)
#   .  grass      :  dirt (the road, the old path)   %  iron fence (the lot)
#   #  wood fence (the neighbors')   K kid   D dog   M Maya   X Dex
#   G  the gate: walking up to it starts the "gate" conversation
#   T  oak   v  tall grass   B  bush   s  shrub   l  leafy plant
#   w  wildflowers   f  a flower
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends AsciiRealm

## Tests set this before adding the scene, to start straight on the street.
@export var skip_intro := false

const LAYOUT: Array[String] = [
	"vvTvvv.vvvTvvvv.vvvvTvvv.vvvTvvvvv.vTv",
	"vvvvvvTvvvvvvvTvvvvvvvvTvvvvvvvTvvvvvv",
	".vTvvvvvvTvvvvvvvvvvvvvvvvvTvvvvvvTvv.",
	"vvvvvTvvvvvvvTvvvvvvvvvvTvvvvvvTvvvvvv",
	"vTvvvvvvTvvvvvvvvvv:vvvvvvvvvvTvvvvvTv",
	"vvvvBvvvvvvvBvvvvvv:vvvvvvvBvvvvvvvvvv",
	"vvBvvvvvBvvvvvvvvvv:vvvvvvvvvvBvvvvBvv",
	"%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%",
	"#..................G.................#",
	"#....s......M.......X......f.....s...#",
	"#.w......................w...........#",
	"#::::::::::::::::::::::::::::::::::::#",
	"#::::::::::::::::::::::::::::::::::::#",
	"#...K.D.........w............w.......#",
	"#..B.....l.....T........B.......T....#",
	"#.......w...........................B#",
	"#..T..........B.......w......T.......#",
	"######################################",
]

const REALM_NAME_KEY := "place_ruffleberg_lot"
const DIALOGUE := "res://data/dialogue/prologue.dlg"
const TERRAIN_BY_CHAR := {":": "Dirt"}
const FENCES := {"#": "Wood Fence", "%": "Metal Fence"}
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "tall_grass_d", "grass_clump_a", "grass_clump_b"],
	"B": ["bush_round_a", "bush_round_b"],
	"s": ["shrub_a", "shrub_b", "shrub_c"],
	"l": ["leafy_a", "leafy_b", "leafy_c", "leafy_d"],
	"w": ["wildflowers_00", "wildflowers_04", "wildflowers_08", "wildflowers_12", "wildflowers_16"],
	"f": ["flower_white", "flower_yellow", "flower_orange"],
}
const NPCS_BY_CHAR := {
	"M": {"id": "MAYA", "start": "maya", "facing": Vector2.DOWN},
	"X": {"id": "DEX", "start": "dex", "facing": Vector2.LEFT},
}
const TRIGGERS_BY_CHAR := {"G": {"start": "gate", "once": false}}

## Layer for the title cards and fades: above the HUD (10), below the text
## box (20), so dinner can play as a conversation over black.
const OVERLAY_LAYER := 15

var _overlay: CanvasLayer
var _black: ColorRect
var _card: Label


func _ready() -> void:
	super()
	_build_overlay()
	Dialogue.command.connect(_on_command)
	if skip_intro:
		_black.visible = false
	else:
		_play_intro.call_deferred()


## Title card, dinner over black, then fade in on the street.
func _play_intro() -> void:
	_kid.set_physics_process(false)
	await _show_card(Names.text("town") + ".  October 2025.", 2.5)
	Dialogue.start(DIALOGUE, "dinner")
	await Dialogue.ended
	await _show_card("Later that night.", 1.8)
	var fade := create_tween()
	fade.tween_property(_black, "modulate:a", 0.0, 1.5)
	await fade.finished
	_black.visible = false
	_kid.set_physics_process(true)
	Dialogue.start(DIALOGUE, "lot_arrive")


## Scene commands from prologue.dlg.
func _on_command(command_name: String, args: PackedStringArray) -> void:
	match command_name:
		"time":
			var seconds := float(args[1]) if args.size() > 1 else 1.0
			($Atmosphere as Atmosphere).set_time(args[0] if args.size() > 0 else "night", seconds)
		"end_slice":
			GameState.set_flag("prologue.slice_done")
			_end_slice.call_deferred()
		_:
			Debug.log_warn("ruffleberg_lot: unknown dialogue command @%s" % command_name)


func _end_slice() -> void:
	if Dialogue.is_active():
		await Dialogue.ended
	_kid.set_physics_process(false)
	_black.visible = true
	_black.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_black, "modulate:a", 1.0, 2.0)
	await fade.finished
	_card.text = "To be continued: the mansion."
	_card.modulate.a = 1.0
	_card.visible = true


func _show_card(text: String, seconds: float) -> void:
	_black.visible = true
	_black.modulate.a = 1.0
	_card.text = text
	_card.visible = true
	_card.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 0.6)
	t.tween_interval(seconds)
	t.tween_property(_card, "modulate:a", 0.0, 0.6)
	await t.finished
	_card.visible = false


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.name = "Overlay"
	_overlay.layer = OVERLAY_LAYER
	add_child(_overlay)
	_black = ColorRect.new()
	_black.color = Color(0.02, 0.02, 0.04)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_black)
	_card = Label.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.add_theme_font_size_override("font_size", 16)
	_card.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	_card.visible = false
	_overlay.add_child(_card)
