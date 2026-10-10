# =============================================================================
# screenshot_skeleton.gd  -  Pictures of the skeleton and of the clock-driven light
# -----------------------------------------------------------------------------
# WHAT:  Loads the HD-2D combat arena and saves
#          skel_swing.png      a skeleton mid-swing (a zoomed crop around the kid)
#          skel_rise.png       one rising out of the ground (zoomed crop)
#          hour_07/12/18/21    the whole screen at those hours: the sky dial and
#                              the world's light must agree
# WHY:   Neither the light nor the art is visible to a headless test; look.
# USAGE: EVERMORE_SHOT_DIR=<dir> godot --path . --resolution 2560x1440 res://tests/screenshot_skeleton.tscn
#        (needs a real display; EVERMORE_SKEL_WHAT=swing|rise|hours limits it)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA_HD := preload("res://realms/test/combat_arena_hd.tscn")
const SKELETON := preload("res://data/enemies/skeleton.tres")

var _dir := OS.get_environment("EVERMORE_SHOT_DIR")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if _dir.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[SKEL] needs EVERMORE_SHOT_DIR and a real display (not --headless)")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	var what := OS.get_environment("EVERMORE_SKEL_WHAT")
	var scene := ARENA_HD.instantiate()
	add_child(scene)
	var yard: Node = scene.get_node("Yard")
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = yard.get_node("World/Kid")
	var dog: Dog = yard.get_node("World/Dog")
	var cam: GameCamera = kid.get_node("Camera2D")
	await _frames(20)
	# Keep the director's own cast away from the shot: we place ours.
	(yard.get_node("DayNight") as DayNightDirector).enabled = false
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	dog.set_physics_process(false)
	dog.global_position = kid.global_position + Vector2(-70, 20)
	_set_hour(21.0)
	await _frames(30)
	cam.reset_smoothing()
	hd.snap_camera()
	await _frames(10)

	if what == "" or what == "swing":
		var sk := Enemy.create(SKELETON, kid.global_position + Vector2(58, -4))
		yard.get_node("World").add_child(sk)
		kid.health.max_hp = 9999
		kid.health.hp = 9999
		kid.set_physics_process(false)
		var guard := 0
		while guard < 600:
			await _frames(1)
			guard += 1
			if sk.state == Enemy.State.ATTACK and sk._sprite.frame_index() >= SKELETON.attack_hit_frame:
				break
		await _crop("skel_swing", sk.global_position, 3)
		sk.queue_free()
		kid.set_physics_process(true)
		await _frames(5)

	if what == "" or what == "rise":
		var sk2 := Enemy.create(SKELETON, kid.global_position + Vector2(70, 18))
		yard.get_node("World").add_child(sk2)
		sk2.set_physics_process(false)
		sk2.begin_entrance("rise")
		sk2.set_physics_process(true)
		var guard2 := 0
		while guard2 < 200 and sk2._enter_t < 0.55:
			await _frames(1)
			guard2 += 1
		await _crop("skel_rise", sk2.global_position, 3)
		sk2.queue_free()

	if what == "" or what == "hours":
		for h in [7.0, 12.0, 18.0, 21.0]:
			_set_hour(h)
			await _frames(40)
			await _shot("hour_%02d" % int(h))
	print("[SKEL] done")
	get_tree().quit(0)


## Pin the clock at an hour of the day (hold, then move within the phase).
func _set_hour(h: float) -> void:
	var best := "night"
	for p: String in Clock.PHASES:
		var start: float = Clock.PHASE_START[p]
		var best_start: float = Clock.PHASE_START[best]
		if fposmod(h - start, 24.0) < fposmod(h - best_start, 24.0):
			best = p
	Clock.hold(best, 0.0)
	Clock.elapsed = fposmod(h - float(Clock.PHASE_START[best]), 24.0) * Clock.hour_seconds()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	if img.save_png(path) == OK:
		print("[SKEL] ", path)


## A crop around a world point, scaled up (nearest) so the pixels read.
func _crop(shot_name: String, world_pos: Vector2, zoom: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	# world_to_screen gives canvas units; the window is bigger (canvas scale).
	var k := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var c := Fx.world_to_screen(world_pos + Vector2(0, -26), 0.0) * k
	var r := Rect2i(int(c.x) - 150, int(c.y) - 130, 300, 260)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(r)
	crop.resize(crop.get_width() * zoom, crop.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	var path := _dir.path_join(shot_name + ".png")
	if crop.save_png(path) == OK:
		print("[SKEL] ", path)
