# =============================================================================
# screenshot_title.gd  -  Screenshots of the title screen and the name screen
# -----------------------------------------------------------------------------
# WHAT:  Opens the title screen, waits for the logo, presses a key and saves
#        title_menu.png; then walks New Game to the kid's name and saves
#        title_name.png (and the gender pick as title_gender.png). Needs a
#        real display (the headless renderer draws nothing).
# RUN:   EVERMORE_SHOT_DIR=<dir> godot --path . --resolution 2560x1440 res://tests/screenshot_title.tscn
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

var _dir := ""


func _ready() -> void:
	_dir = OS.get_environment("EVERMORE_SHOT_DIR")
	if _dir.is_empty() or DisplayServer.get_name() == "headless":
		print("[SHOT] needs EVERMORE_SHOT_DIR and a real display")
		get_tree().quit(0)
		return
	_run.call_deferred()


func _run() -> void:
	var holder := Node.new()
	get_tree().root.add_child(holder)
	get_tree().current_scene = holder
	get_tree().change_scene_to_file(TitleScreen.SCENE)
	await get_tree().scene_changed
	# The first visit plays the ~10 s scroll: frames along the way.
	var played := 0.0
	for at: float in [0.5, 3.0, 5.0, 7.5, 9.5, 12.5]:
		await _secs(at - played)
		played = at
		await _shot("intro_%04.1f" % at)
	var title := get_tree().current_scene as TitleScreen
	title.reveal_menu()
	await _secs(1.5)
	await _shot("title_menu")
	title.activate("new_game")
	await _secs(0.6)
	await _shot("title_gender")
	var flow := title._flow
	flow.choose_gender("girl")
	await _secs(0.6)
	flow.entry().type_char("A")
	await _shot("title_name")
	get_tree().quit(0)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, name]
	if img.save_png(path) == OK:
		print("[SHOT] ", path, " ", img.get_size())
