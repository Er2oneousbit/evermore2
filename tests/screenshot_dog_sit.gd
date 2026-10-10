# =============================================================================
# screenshot_dog_sit.gd  -  A screenshot of the dog sitting next to the kid
# -----------------------------------------------------------------------------
# WHAT:  Loads the test yard in HD-2D, lets the kid and dog stand still until
#        the dog sits, and saves dog_sit.png (full frame) plus dog_sit_crop.png
#        (a 400x400 crop around him). Needs a real display.
# RUN:   EVERMORE_SHOT_DIR=<dir> godot --path . --resolution 2560x1440 res://tests/screenshot_dog_sit.tscn
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node


func _ready() -> void:
	var dir := OS.get_environment("EVERMORE_SHOT_DIR")
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		print("[SHOT] needs EVERMORE_SHOT_DIR and a real display")
		get_tree().quit(0)
		return
	_run.call_deferred(dir)


func _run(dir: String) -> void:
	var scene: Node = load("res://realms/big_yard/yard_hd.tscn").instantiate()
	add_child(scene)
	var dog: Dog = scene.get_node("Yard/World/Dog")
	await get_tree().create_timer(5.0).timeout
	print("[SHOT] dog sitting: ", dog.idle.sitting())
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/dog_sit.png" % dir)
	var hd: HdView = scene.get_node("HdView")
	var p := hd.camera().unproject_position(HdView.to3(dog.global_position) + Vector3(0, 0.5, 0))
	var scale := float(img.get_width()) / get_viewport().get_visible_rect().size.x
	var c := p * scale
	var r := Rect2i(Vector2i(c) - Vector2i(200, 250), Vector2i(400, 400)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(r).save_png("%s/dog_sit_crop.png" % dir)
	print("[SHOT] saved ", dir)
	get_tree().quit(0)
