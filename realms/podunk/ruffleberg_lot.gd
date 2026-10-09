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
#   >  the road east, off the map: to the test yard (EXITS)
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
	"#::::::::::::::::::::::::::::::::::::>",
	"#::::::::::::::::::::::::::::::::::::>",
	"#...K.D.........w............w.......#",
	"#..B.....l.....s........B.......s....#",
	"#.......w...........................B#",
	"#..T..........B.......w......T.......#",
	"######################################",
]

const REALM_NAME_KEY := "place_ruffleberg_lot"
## The dare (dinner plays "home" over black first, see _play_intro).
const MUSIC := "lot"
## The story picks the time here: golden hour on the street, night at the
## dare (@time night). The clock never moves on by itself.
const CLOCK_MODE := "hold"
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
## The road runs on east to the test yard (a tech demo path, owner
## 2026-10-09: "a good way to test scene swapping").
const EXITS := {">": {"to": "res://realms/big_yard/yard_hd.tscn", "entry": "from_street"}}
const ENTRIES := {"from_yard": {"cell": Vector2i(34, 11), "facing": Vector2.LEFT}}
const SIGNS := [{"cell": Vector2i(35, 13), "place": "realm_test_yard", "dir": Vector2.RIGHT}]
## Set once the street has faded in after dinner: coming back from another
## map never replays the title card, dinner or the arrival talk.
const INTRO_FLAG := "prologue.intro_done"

## Layer for the title cards and fades: above the HUD (10), below the text
## box (20), so dinner can play as a conversation over black.
const OVERLAY_LAYER := 15

## How long "To be continued" stays up before the game goes back to the debug
## menu (game time; tests shorten it).
var end_card_seconds := 10.0

var _overlay: CanvasLayer
var _black: ColorRect
var _card: Label


func _ready() -> void:
	super()
	_build_overlay()
	Dialogue.command.connect(_on_command)
	if skip_intro or GameState.get_flag(INTRO_FLAG):
		_black.visible = false
	else:
		_play_intro.call_deferred()


## Title card, dinner over black, then fade in on the street.
func _play_intro() -> void:
	_kid.set_physics_process(false)
	Audio.play_music("home", 0.0)
	Audio.set_ambience("")  # dinner is indoors
	await _show_card(Names.text("town") + ".  October 2025.", 2.5)
	Dialogue.start(DIALOGUE, "dinner")
	await Dialogue.ended
	Audio.stop_music(1.5)
	await _show_card("Later that night.", 1.8)
	Audio.set_music_set("outdoor", 2.5)  # follows the time of day; starts at golden hour
	Audio.set_ambience("outdoor")
	var fade := create_tween()
	fade.tween_property(_black, "modulate:a", 0.0, 1.5)
	await fade.finished
	_black.visible = false
	_kid.set_physics_process(true)
	GameState.set_flag(INTRO_FLAG)
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
	Audio.stop_music(3.0)
	Audio.set_ambience("")
	await fade.finished
	_card.text = "To be continued: the mansion."
	_card.modulate.a = 1.0
	_card.visible = true
	await get_tree().create_timer(end_card_seconds).timeout
	Travel.go(DebugMenu.SCENE, "", false)


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
