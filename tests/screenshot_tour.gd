# =============================================================================
# screenshot_tour.gd  -  Renders the yard from fixed viewpoints, every mood
# -----------------------------------------------------------------------------
# WHAT:  Loads the prototype yard, walks the kid to a list of viewpoints, and
#        saves a screenshot at each for the requested times of day. Used to
#        (re)generate docs/screenshots and to eyeball art changes quickly.
#        Pixel art is saved at 2x with nearest-neighbor, so it stays crisp in
#        browsers and on GitHub.
#
# RUN (needs a display; on Linux CI use xvfb-run):
#   EVERMORE_SHOT_DIR=/tmp/shots godot --path . --resolution 1280x720 res://tests/screenshot_tour.tscn
#   optional: EVERMORE_TOUR_TIMES="golden,night"   (default: day,golden,night;
#                                                   morning works too)
#             EVERMORE_TOUR_SPOTS="start,pond"      (default: all spots)
#             EVERMORE_TOUR_VIEW="2d"               (default: hd = the HD-2D view)
#             EVERMORE_TOUR_MAP="street"            (default: yard; street = the
#                                                   prologue road, HD only, STREET_SPOTS;
#                                                   arena = the big combat arena, ARENA_SPOTS)
#             EVERMORE_TOUR_WAIT=9                  (seconds to wait before each shot,
#                                                   default 0.5; the day/night enemy swap takes ~10)
#   Windows PowerShell: $env:EVERMORE_SHOT_DIR="C:\temp\shots" before running.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD_SCENE := preload("res://realms/big_yard/prototype_yard.tscn")
const HD_SCENE := preload("res://realms/big_yard/yard_hd.tscn")
const STREET_SCENE := preload("res://realms/podunk/ruffleberg_lot_hd.tscn")
const ARENA_SCENE := preload("res://realms/test/combat_arena_hd.tscn")

## name -> [kid tile, direction the kid walks into the shot]
const SPOTS := {
	"start":  [Vector2i(6, 5), Vector2.RIGHT],
	"pond":   [Vector2i(25, 8), Vector2.RIGHT],
	"pen":    [Vector2i(9, 13), Vector2.DOWN],
	"garden": [Vector2i(31, 17), Vector2.LEFT],
	"shops":  [Vector2i(47, 9), Vector2.UP],  # the street: both stalls in view
	"entrance": [Vector2i(4, 7), Vector2.LEFT],  # the path in from the prologue street
}
## The prologue street (EVERMORE_TOUR_MAP=street).
const STREET_SPOTS := {
	"road": [Vector2i(33, 12), Vector2.RIGHT],  # the road east to the test yard, its sign
}

## The big combat arena (EVERMORE_TOUR_MAP=arena). The lone kid is far smaller
## than the map: these show how much lies beyond the screen edges.
const ARENA_SPOTS := {
	"plaza":  [Vector2i(49, 45), Vector2.UP],  # the road in from the yard
	"cross":  [Vector2i(49, 36), Vector2.UP],  # the crossroads, hedge and fence lanes
	"pond":   [Vector2i(27, 29), Vector2.UP],  # the south shore of the big pond
	"grove":  [Vector2i(58, 34), Vector2.UP],  # oaks with a bat roost (58, 30)
}

var _dir := OS.get_environment("EVERMORE_SHOT_DIR")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if _dir.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[TOUR] needs EVERMORE_SHOT_DIR and a real display (not --headless)")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	var street := OS.get_environment("EVERMORE_TOUR_MAP") == "street"
	var arena := OS.get_environment("EVERMORE_TOUR_MAP") == "arena"
	var hd_mode := street or arena or OS.get_environment("EVERMORE_TOUR_VIEW") != "2d"
	var scene := (STREET_SCENE if street else ARENA_SCENE if arena else HD_SCENE if hd_mode else YARD_SCENE).instantiate()
	if street:
		scene.get_node("Yard").skip_intro = true
	add_child(scene)
	var yard: Node = scene.get_node("Yard") if hd_mode else scene
	var hd: HdView = scene.get_node("HdView") if hd_mode else null
	var kid: Kid = yard.get_node("World/Kid")
	var dog: Dog = yard.get_node("World/Dog")
	var atmosphere: Atmosphere = yard.get_node("Atmosphere")
	var cam: GameCamera = kid.get_node("Camera2D")
	var times := _list("EVERMORE_TOUR_TIMES", ["day", "golden", "night"])
	var table: Dictionary = STREET_SPOTS if street else ARENA_SPOTS if arena else SPOTS
	var spots := _list("EVERMORE_TOUR_SPOTS", table.keys())
	var wait := float(OS.get_environment("EVERMORE_TOUR_WAIT")) if OS.has_environment("EVERMORE_TOUR_WAIT") else 0.5
	await _frames(20 if hd_mode else 10)
	for spot: String in spots:
		var info: Array = table[spot]
		var tile: Vector2i = info[0]
		var walk: Vector2 = info[1]
		for t: String in times:
			atmosphere.set_time(t, 0.0)
			# Start a little behind the spot and walk in, so the kid is caught
			# mid-stride and the dog trots behind him.
			kid.global_position = Vector2(tile * 32 + Vector2i(16, 28)) - walk * 48.0
			kid.facing = walk
			dog.warp_to_target()
			cam.reset_smoothing()
			if hd:
				await _frames(1)
				hd.snap_camera()
			_hold(walk)
			await _frames(int(wait * 60.0))
			await _frames(1)
			await _shot("%s_%s" % [spot, t])
			_release()
			await _frames(5)
	print("[TOUR] done")
	get_tree().quit(0)


func _list(env: String, fallback: Array) -> Array:
	var v := OS.get_environment(env)
	return fallback if v.is_empty() else Array(v.split(","))


func _hold(dir: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if dir.x > 0.0: Input.action_press("move_right")
	if dir.x < 0.0: Input.action_press("move_left")
	if dir.y > 0.0: Input.action_press("move_down")
	if dir.y < 0.0: Input.action_press("move_up")


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	print("[TOUR] fps ", Engine.get_frames_per_second(), " (", shot_name, ")")
	var img := get_viewport().get_texture().get_image()
	# 2D view renders at 640x360: blow it up 2x with crisp pixels. The HD-2D
	# view already renders at the window's full resolution.
	if img.get_width() <= 640:
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path := _dir.path_join(shot_name + ".png")
	if img.save_png(path) == OK:
		print("[TOUR] ", path)
	else:
		printerr("[TOUR] failed to save ", path)
