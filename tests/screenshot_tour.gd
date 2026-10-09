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
#   Windows PowerShell: $env:EVERMORE_SHOT_DIR="C:\temp\shots" before running.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const YARD_SCENE := preload("res://realms/big_yard/prototype_yard.tscn")
const HD_SCENE := preload("res://realms/big_yard/yard_hd.tscn")

## name -> [kid tile, direction the kid walks into the shot]
const SPOTS := {
	"start":  [Vector2i(6, 5), Vector2.RIGHT],
	"pond":   [Vector2i(25, 8), Vector2.RIGHT],
	"pen":    [Vector2i(9, 13), Vector2.DOWN],
	"garden": [Vector2i(31, 17), Vector2.LEFT],
	"shops":  [Vector2i(47, 9), Vector2.UP],  # the street: both stalls in view
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
	var hd_mode := OS.get_environment("EVERMORE_TOUR_VIEW") != "2d"
	var scene := (HD_SCENE if hd_mode else YARD_SCENE).instantiate()
	add_child(scene)
	var yard: Node = scene.get_node("Yard") if hd_mode else scene
	var hd: HdView = scene.get_node("HdView") if hd_mode else null
	var kid: Kid = yard.get_node("World/Kid")
	var dog: Dog = yard.get_node("World/Dog")
	var atmosphere: Atmosphere = yard.get_node("Atmosphere")
	var cam: GameCamera = kid.get_node("Camera2D")
	var times := _list("EVERMORE_TOUR_TIMES", ["day", "golden", "night"])
	var spots := _list("EVERMORE_TOUR_SPOTS", SPOTS.keys())
	await _frames(20 if hd_mode else 10)
	for spot: String in spots:
		var info: Array = SPOTS[spot]
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
			await _frames(30)
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
