# =============================================================================
# smoke_hd.gd  -  Headless checks for the HD-2D view (systems/hd2d/hd_view.gd)
# -----------------------------------------------------------------------------
# WHAT:  Loads realms/big_yard/yard_hd.tscn and checks the 3D view really
#        mirrors the 2D game underneath:
#          1. every 2D prop (except flat decals baked into the ground) has a
#             3D sprite, and every fence cell has a 3D post
#          2. kid and dog 3D sprites follow their 2D bodies as they move, and
#             same-row depth ties are broken kid > dog > props (no z-fighting)
#          3. the camera stays over the map
#          4. F6 swaps HD-2D <-> classic 2D cleanly (visibility, 3D camera,
#             ScreenScaler mode, 2D mood layers)
#          5. time of day (Atmosphere) reaches the 3D lights
#          6. the camera keeps the kid on screen, clear of the HUD, at the
#             map's bottom and top rows, in both views and on a short map
#             (the arena); at the bottom he once walked right off screen
#        It can't judge how things LOOK: that's what the screenshot tour is for.
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_hd.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const HD_SCENE := preload("res://realms/big_yard/yard_hd.tscn")
const YardScript := preload("res://realms/big_yard/prototype_yard.gd")

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := HD_SCENE.instantiate()
	add_child(scene)
	var yard: Node2D = scene.get_node("Yard")
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = yard.get_node("World/Kid")
	var dog: Dog = yard.get_node("World/Dog")
	var atmo: Atmosphere = yard.get_node("Atmosphere")
	await _frames(10)
	_check(hd.enabled, "HD view didn't finish building / enable itself")

	# --- 1. Everything got mirrored --------------------------------------------
	var expected_props := 0
	for p in yard.get_node("World").get_children():
		if p is Prop and p.data and not (p.data.ground_decal and p.data.frames == 1):
			expected_props += 1
	var got_props := hd.get_node("Props").get_child_count()
	_check(got_props == expected_props, "3D props %d, expected %d (one per non-decal 2D prop)" % [got_props, expected_props])
	var fence_cells := "".join(YardScript.LAYOUT).count(YardScript.FENCE_CHAR)
	var posts := 0
	for m in hd.get_node("Fences").get_children():
		if (m as MeshInstance3D).mesh is BoxMesh and ((m as MeshInstance3D).mesh as BoxMesh).size.y > 0.5:
			posts += 1
	_check(posts == fence_cells, "3D fence posts %d, expected %d (one per fence cell)" % [posts, fence_cells])

	# --- 2. Actors follow their 2D bodies --------------------------------------
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(20)
	var kid3d: Sprite3D = hd.get_node("Kid")
	var dog3d: Sprite3D = hd.get_node("Dog")
	# (within the few-cm depth tie-breakers, see HdView.KID_DEPTH_BIAS)
	_check(kid3d.position.distance_to(HdView.to3(kid.global_position)) < 0.05, "kid 3D sprite not at the 2D kid's position")
	_check(dog3d.position.distance_to(HdView.to3(dog.global_position)) < 0.05, "dog 3D sprite not at the 2D dog's position")
	_check(kid3d.frame_coords == (kid.get_node("Sprite") as Sprite2D).frame_coords, "kid 3D frame differs from the 2D animation frame")
	# The 2D World is hidden in HD mode; the 3D actors must still show.
	_check(kid3d.visible and dog3d.visible, "kid/dog 3D sprites must be visible in HD mode (kid %s, dog %s)" % [kid3d.visible, dog3d.visible])
	# Same-row tie: the kid must be in front of a prop standing on his row,
	# and in front of the dog (otherwise they z-fight into stripes).
	_check(HdView.KID_DEPTH_BIAS > HdView.DOG_DEPTH_BIAS and HdView.DOG_DEPTH_BIAS > HdView.PROP_DEPTH_BIAS,
			"depth tie-breakers must order kid > dog > props")

	# --- 3. Camera stays over the map ------------------------------------------
	var cam: Camera3D = hd.get_node("Camera")
	_check(cam.current, "HD camera isn't the current camera")
	var map := Rect2(Vector2.ZERO, Vector2(YardScript.LAYOUT[0].length(), YardScript.LAYOUT.size()))
	var look := Vector2(cam.position.x, cam.position.z - cam.position.y / tan(deg_to_rad(hd.camera_pitch_deg)))
	_check(map.grow(0.5).has_point(look), "camera looks at %s, outside the map %s" % [look, map])

	# --- 4. F6 toggles views ------------------------------------------------------
	_tap("debug_toggle_view")
	await _frames(2)
	_check(not hd.enabled and not hd.visible, "F6 didn't switch the HD view off")
	_check(yard.get_node("World").visible, "2D world still hidden after switching to 2D")
	_check(not ScreenScaler.native_3d, "ScreenScaler still in native 3D mode in 2D view")
	_check(atmo.render_2d, "2D mood layers still off in 2D view")
	_check(not cam.current, "HD camera still current in 2D view")
	_tap("debug_toggle_view")
	await _frames(2)
	_check(hd.enabled and not yard.get_node("World").visible and ScreenScaler.native_3d, "F6 didn't switch back to HD")

	# --- 4b. Nothing piles up over time (a leak once added 5 lights a second) ---
	var lights_before := hd.find_children("*", "Light3D", true, false).size()
	var nodes_before := hd.get_child_count()
	await _wait(1.5)
	var lights_after := hd.find_children("*", "Light3D", true, false).size()
	_check(lights_after == lights_before, "3D lights must not pile up (%d -> %d)" % [lights_before, lights_after])
	_check(hd.get_child_count() == nodes_before, "HdView children must not grow by themselves (%d -> %d)" % [nodes_before, hd.get_child_count()])

	# --- 5. Time of day reaches the 3D lights ------------------------------------
	atmo.set_time("night", 0.0)
	await _wait(1.0)
	var sun: DirectionalLight3D = hd.get_node("Sun")
	var want: float = HdView.PRESETS["night"]["sun_energy"]
	_check(absf(sun.light_energy - want) < 0.01, "night sun energy %.2f, expected %.2f" % [sun.light_energy, want])
	var flies: GPUParticles3D = hd.get_node("Fireflies")
	_check(flies.emitting, "fireflies should be on at night")

	# --- 6. The kid stays on screen at the map's edges ---------------------------
	atmo.set_time("day", 0.0)
	await _check_edges(yard, kid, "yard, HD-2D")
	_tap("debug_toggle_view")
	await _frames(2)
	await _check_edges(yard, kid, "yard, classic 2D")
	_tap("debug_toggle_view")
	await _frames(2)
	scene.queue_free()
	await _frames(2)
	var arena: Node = load("res://realms/test/combat_arena_hd.tscn").instantiate()
	add_child(arena)
	await _frames(10)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	var arena_kid: Kid = arena.get_node("Yard/World/Kid")
	await _check_edges(arena.get_node("Yard"), arena_kid, "arena (short map), HD-2D")
	arena.queue_free()
	await _frames(2)

	if _failures.is_empty():
		print("[TEST] PASS  smoke_hd  (%d 3D props, %d fence posts)" % [got_props, posts])
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


## Kid on the first and last walkable rows (inside the fence): his feet
## must be above the HUD and his head below the top of the screen.
func _check_edges(realm: AsciiRealm, kid: Kid, label: String) -> void:
	var r := realm.map_rect()
	var vis := get_viewport().get_visible_rect().size
	for row in [1, r.size.y / AsciiRealm.TILE - 2]:
		kid.global_position = Vector2(r.get_center().x, row * AsciiRealm.TILE + AsciiRealm.TILE - 4)
		kid.velocity = Vector2.ZERO
		await _wait(2.5)  # the camera eases over
		var feet := Fx.world_to_screen(kid.global_position)
		var head := Fx.world_to_screen(kid.global_position, 46.0)
		_check(feet.y <= vis.y - HdView.HUD_CLEAR_PX and head.y >= 0.0,
				"%s: the kid on row %d must be on screen above the HUD (feet at y=%.0f, head %.0f, screen %.0f tall)"
				% [label, row, feet.y, head.y, vis.y])


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
