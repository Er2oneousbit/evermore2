# =============================================================================
# smoke_visuals.gd  -  Headless checks for the art/mood plumbing
# -----------------------------------------------------------------------------
# WHAT:  Fast logic checks (no screenshots, no display needed) for:
#          1. LpcSprite: direction mapping, sheet rows/columns per animation,
#             one-shot animations finishing on time
#          2. Atmosphere: every preset applies, F2 order, particles on/off per
#             time of day, particle counts scale with ultrawide view area
#          3. Prop: base point lands on the origin (also when flipped),
#             footprint/occluder/sway get built only when asked for
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_visuals.tscn
#        Exit code 0 = PASS, 1 = FAIL ([TEST] FAIL lines say why).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const KID_SHEET := preload("res://assets/characters/kid/kid_lpc.png")

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_lpc_sprite()
	await _test_atmosphere()
	await _test_prop()
	_test_rigid_sway()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_visuals")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_lpc_sprite() -> void:
	# Direction mapping: horizontal wins ties (diagonals show the side view).
	var cases := [
		[Vector2.UP, LpcSprite.Dir.UP], [Vector2.DOWN, LpcSprite.Dir.DOWN],
		[Vector2.LEFT, LpcSprite.Dir.LEFT], [Vector2.RIGHT, LpcSprite.Dir.RIGHT],
		[Vector2(1, 1), LpcSprite.Dir.RIGHT], [Vector2(-1, -1), LpcSprite.Dir.LEFT],
		[Vector2(0.3, -0.9), LpcSprite.Dir.UP],
	]
	for c: Array in cases:
		_check(LpcSprite.facing_to_dir(c[0]) == c[1], "facing_to_dir(%s) != %s" % [c[0], c[1]])

	var s := LpcSprite.new()
	s.texture = KID_SHEET
	s.autoplay = &""
	add_child(s)
	_check(s.hframes == 13 and s.vframes == 54, "LpcSprite grid %dx%d, expected 13x54" % [s.hframes, s.vframes])
	_check(s.offset == Vector2(0, -30), "feet offset %s, expected (0, -30)" % s.offset)

	s.play(&"walk", Vector2.RIGHT)
	_check(s.frame_coords == Vector2i(1, 8 + LpcSprite.Dir.RIGHT), "walk right starts at %s" % s.frame_coords)
	s.play(&"walk", Vector2.UP)
	_check(s.frame_coords.y == 8, "walk up row %d, expected 8" % s.frame_coords.y)
	s.play(&"hurt", Vector2.LEFT)
	_check(s.frame_coords.y == 20, "hurt is one row (20) for every direction, got %d" % s.frame_coords.y)

	# One-shot: slash finishes after its duration and holds the last frame.
	var finished := [false]
	s.animation_finished.connect(func(_a: StringName) -> void: finished[0] = true)
	s.play(&"slash", Vector2.DOWN, true)
	var need := LpcSprite.duration(&"slash")
	await _wait(need + 0.1)
	_check(finished[0], "slash never emitted animation_finished (duration %.2fs)" % need)
	_check(s.frame_coords == Vector2i(5, 12 + LpcSprite.Dir.DOWN), "slash should hold its last frame, at %s" % s.frame_coords)
	_check(not s.is_playing_once(), "is_playing_once() still true after finishing")
	s.queue_free()


# -----------------------------------------------------------------------------
func _test_atmosphere() -> void:
	var times: Array[String] = []
	var on_time := func(t: String) -> void: times.append(t)
	EventBus.time_of_day_changed.connect(on_time)

	var atm := Atmosphere.new()
	atm.start_time = "golden"
	add_child(atm)
	await get_tree().process_frame
	_check(atm.time_name == "golden", "start_time not applied (%s)" % atm.time_name)
	_check(times == ["golden"], "start should announce golden once, got %s" % [times])

	for t: String in Atmosphere.TIME_ORDER:
		atm.set_time(t, 0.0)
		var p: Dictionary = Atmosphere.PRESETS[t]
		var tint: CanvasModulate = atm.get_node("WorldTint")
		_check(tint.color.is_equal_approx(p["tint"]), "%s: tint %s != %s" % [t, tint.color, p["tint"]])
		var pollen: CPUParticles2D = atm.get_node("AmbientParticles/Pollen")
		var flies: CPUParticles2D = atm.get_node("AmbientParticles/Fireflies")
		_check(pollen.emitting == (p["pollen"] > 0.0), "%s: pollen emitting=%s" % [t, pollen.emitting])
		_check(flies.emitting == (p["fireflies"] > 0.0), "%s: fireflies emitting=%s" % [t, flies.emitting])

	# F2 order wraps: night -> morning -> day -> golden.
	atm.set_time("night", 0.0)
	atm.cycle_time()
	_check(atm.time_name == "morning", "cycle after night should be morning, got %s" % atm.time_name)
	atm.cycle_time()
	_check(atm.time_name == "day", "cycle after morning should be day, got %s" % atm.time_name)
	atm.cycle_time()
	_check(atm.time_name == "golden", "cycle after day should be golden, got %s" % atm.time_name)

	# Ultrawide sees 3x the area at 1920x360, so it gets 3x the pollen.
	atm._on_view_changed(Vector2i(1920, 360), 4)
	var pollen2: CPUParticles2D = atm.get_node("AmbientParticles/Pollen")
	_check(pollen2.amount == atm.pollen_density * 3, "pollen at 48:9 = %d, expected %d" % [pollen2.amount, atm.pollen_density * 3])
	atm._on_view_changed(ScreenScaler.view_size, ScreenScaler.scale)

	EventBus.time_of_day_changed.disconnect(on_time)
	atm.queue_free()
	await get_tree().process_frame


# -----------------------------------------------------------------------------
func _test_prop() -> void:
	var data := PropData.new()
	data.texture = KID_SHEET
	data.region = Rect2(64, 128, 64, 64)
	data.base = Vector2(40, 60)
	data.footprint = Vector2(10, 6)
	data.sway_strength = 1.0
	data.occluder_size = Vector2(10, 6)

	var p := Prop.create(data, Vector2(100, 100))
	add_child(p)
	_check(p.sprite.offset == -Vector2(40, 60), "prop offset %s, expected (-40, -60)" % p.sprite.offset)
	_check(p.get_children().any(func(n: Node) -> bool: return n is StaticBody2D), "footprint body missing")
	_check(p.get_children().any(func(n: Node) -> bool: return n is LightOccluder2D), "occluder missing")
	var mat := p.sprite.material as ShaderMaterial
	_check(mat != null, "sway material missing")
	if mat:
		var uv: Vector4 = mat.get_shader_parameter("uv_rect")
		var want := Vector4(64.0 / 832.0, 128.0 / 3456.0, 64.0 / 832.0, 64.0 / 3456.0)
		_check(uv.is_equal_approx(want), "uv_rect %s, expected %s" % [uv, want])

	# Flipped: the base mirrors inside the region (64 - 40 = 24).
	var f := Prop.create(data, Vector2.ZERO, true)
	add_child(f)
	_check(f.sprite.offset == -Vector2(24, 60), "flipped prop offset %s, expected (-24, -60)" % f.sprite.offset)

	# Bare prop: no extras.
	var bare_data := PropData.new()
	bare_data.texture = KID_SHEET
	var bare := Prop.create(bare_data, Vector2.ZERO)
	add_child(bare)
	_check(bare.get_child_count() == 1, "bare prop should only have its sprite, has %d children" % bare.get_child_count())
	for n: Node in [p, f, bare]:
		n.queue_free()
	await get_tree().process_frame


# -----------------------------------------------------------------------------
func _wait(seconds: float) -> void:
	var frames := ceili(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Wind sway moves everything above the roots as ONE block. A shift scaled by
## height rounds to whole texels at a row that slides up and down as the wind
## changes, which read as a glitchy wipe across the tree tops (owner). The
## renderer can't be read back headless, so this checks the shader math.
func _test_rigid_sway() -> void:
	for path in ["res://assets/shaders/hd_sprite.gdshader", "res://assets/shaders/wind_sway.gdshader"]:
		var code := (load(path) as Shader).code
		var line := ""
		for l in code.split("
"):
			if l.strip_edges().begins_with("float shift"):
				line = l
		_check(line.contains("step(0.001, h)"), "%s: sway shift must not scale with height (%s)" % [path, line.strip_edges()])

