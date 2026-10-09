# =============================================================================
# screenshot_feel.gd  -  Screenshots of the club mid-swing and the dog's leap
# -----------------------------------------------------------------------------
# WHAT:  Loads the HD-2D yard, makes the kid swing (facing down, right and left)
#        and the dog leap at a rat, and saves a picture on the frames that
#        matter (the club's lowest frames; the dog at the top of his hop).
# WHY:   The club's tip once vanished into the ground plane in HD-2D, and the
#        dog's hop must show height with the shadow staying put. Neither is
#        visible to a headless test, so look at the pictures.
# USAGE: EVERMORE_SHOT_DIR=<dir> godot --path . --resolution 1280x720 res://tests/screenshot_feel.tscn
#        (needs a real display; EVERMORE_FEEL_WHAT=club or dog limits it)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const HD_SCENE := preload("res://realms/big_yard/yard_hd.tscn")
const RAT := preload("res://data/enemies/rat.tres")

var _dir := OS.get_environment("EVERMORE_SHOT_DIR")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if _dir.is_empty() or DisplayServer.get_name() == "headless":
		printerr("[FEEL] needs EVERMORE_SHOT_DIR and a real display (not --headless)")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	var what := OS.get_environment("EVERMORE_FEEL_WHAT")
	var scene := HD_SCENE.instantiate()
	add_child(scene)
	var yard: Node = scene.get_node("Yard")
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = yard.get_node("World/Kid")
	var dog: Dog = yard.get_node("World/Dog")
	var atmosphere: Atmosphere = yard.get_node("Atmosphere")
	var cam: GameCamera = kid.get_node("Camera2D")
	await _frames(20)
	atmosphere.set_time("day", 0.0)
	kid.global_position = Vector2(6 * 32 + 16, 5 * 32 + 28)
	dog.set_physics_process(false)
	dog.global_position = kid.global_position + Vector2(-90, -60)
	cam.reset_smoothing()
	await _frames(1)
	hd.snap_camera()
	await _frames(10)
	if what != "dog":
		# Every frame of the swing, three facings: a contact sheet of crops
		# around the kid (a lone frame can hide where the club gets cut).
		var crops: Array[Image] = []
		for face: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.LEFT]:
			kid.facing = face
			kid.charge.value = 1.0
			kid.attack()
			var last := -1
			var guard := 0
			while kid.is_attacking() and guard < 200:
				await _frames(1)
				guard += 1
				var fi: int = kid._sprite.frame_index()
				if fi != last and kid.is_attacking():
					last = fi
					await RenderingServer.frame_post_draw
					var img := get_viewport().get_texture().get_image()
					var crop := img.get_region(Rect2i(360, 190, 170, 170))
					crop.convert(Image.FORMAT_RGBA8)
					crops.append(crop)
			while crops.size() % 6 != 0:
				crops.append(Image.create(170, 170, false, Image.FORMAT_RGBA8))
			await _frames(10)
		var sheet := Image.create(170 * 6, 170 * 3, false, Image.FORMAT_RGBA8)
		for i in crops.size():
			sheet.blit_rect(crops[i], Rect2i(0, 0, 170, 170), Vector2i((i % 6) * 170, (i / 6) * 170))
		sheet.save_png(_dir.path_join("club_sheet.png"))
		print("[FEEL] club_sheet.png")
	if what != "club":
		dog.set_physics_process(true)
		dog.global_position = kid.global_position + Vector2(-40, 40)
		var rat := Enemy.create(RAT, dog.global_position + Vector2(80, 0))
		yard.get_node("World").add_child(rat)
		rat.set_physics_process(false)
		rat.state = Enemy.State.RECOVER
		dog.set_physics_process(false)
		dog.facing = Vector2.RIGHT
		dog.charge.value = 2.0
		dog.attack()
		dog.set_physics_process(true)
		var guard := 0
		while guard < 240:
			await _frames(1)
			guard += 1
			if dog._atk == Dog.Atk.LEAP and dog._leap_left < dog._leap_total * 0.5:
				break
		await _shot("dog_leap")
	print("[FEEL] done")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	if img.save_png(path) == OK:
		print("[FEEL] ", path)
	else:
		printerr("[FEEL] failed to save ", path)
