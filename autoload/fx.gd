# =============================================================================
# fx.gd  (autoload: Fx)
# -----------------------------------------------------------------------------
# WHAT:  Combat feedback, callable from anywhere:
#          Fx.damage_number(world_pos, 12, "enemy", level)   numbers that pop up
#          Fx.slash(world_pos, dir, reach, arc_deg, level)    a swing trail
#          Fx.hit_stop(0.06)                                  a tiny freeze on impact
#          Fx.shake(3.0, 0.12)                                camera shake
#        and the world's little tells (hidden items, the dog's nose):
#          Fx.glint(world_pos, height_px, color)              a sparkle
#          Fx.scent_puff(world_pos, color)                    a wisp rising
#          Fx.dirt(world_pos)                                 dirt kicked up
#          Fx.scent_trail(from_node, to, color, seconds)      flowing wisps
#
# BOTH VIEWS: effects live on a screen layer (CanvasLayer 5: above the color
#        grade, below the HUD) and re-project their world position every frame,
#        through the 2D camera or, in HD-2D, the 3D camera (world_to_screen).
#        The 2D world is hidden in HD-2D, so nothing can live there.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const LAYER := 5
const NUMBER_COLORS := {"enemy": Color(1.0, 0.97, 0.85), "player": Color(1.0, 0.4, 0.38), "heal": Color(0.5, 1.0, 0.55)}
const LEVEL_TINTS := [Color(0.85, 0.85, 0.85), Color(1, 1, 1), Color(0.55, 0.9, 1.0), Color(1.0, 0.82, 0.35)]

var _layer: CanvasLayer
## Seconds of hit-stop left, counted in UNSCALED frame time (see _process).
var _stop_left := 0.0
## How many numbers/slashes are alive (tests read it).
var live_effects := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.name = "CombatFx"
	_layer.layer = LAYER
	add_child(_layer)


## Where a world point (2D game coordinates) is on screen, in the canvas
## coordinates CanvasLayers use. height_px lifts it (e.g. above a head).
func world_to_screen(p: Vector2, height_px := 0.0) -> Vector2:
	var hd := get_tree().get_first_node_in_group("hd_view") as HdView
	if hd and hd.enabled and hd.camera():
		# unproject_position already answers in the viewport's canvas
		# coordinates (the 640x360-based view), the same space CanvasLayers
		# use, even though 3D renders at full window resolution.
		return hd.camera().unproject_position(HdView.to3(p, height_px * HdView.PX))
	return get_viewport().get_canvas_transform() * (p + Vector2(0, -height_px))


func damage_number(world_pos: Vector2, amount: int, kind := "enemy", level := 1) -> void:
	if not Settings.get_value("damage_numbers"):
		return
	var l := Label.new()
	l.text = str(amount)
	var big := kind == "enemy" and level >= 2
	l.add_theme_font_size_override("font_size", 12 if big else 10)
	l.add_theme_color_override("font_color", NUMBER_COLORS.get(kind, Color.WHITE) * (LEVEL_TINTS[clampi(level, 0, 3)] if kind == "enemy" else Color.WHITE))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_layer.add_child(l)
	live_effects += 1
	var jitter := Vector2(randf_range(-6, 6), 0)
	var life := 0.75
	var t := 0.0
	l.pivot_offset = l.size * 0.5
	while t < life and is_instance_valid(l):
		var k := t / life
		var rise := 18.0 * (1.0 - pow(1.0 - k, 2.0))
		l.position = world_to_screen(world_pos) - l.size * 0.5 + jitter + Vector2(0, -rise)
		l.scale = Vector2.ONE * (1.0 + 0.5 * maxf(0.0, 1.0 - k * 6.0))
		l.modulate.a = 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
		await get_tree().process_frame
		t += get_process_delta_time()  # pauses during hit-stop, which reads well
	if is_instance_valid(l):
		l.queue_free()
	live_effects -= 1


func slash(world_pos: Vector2, dir: Vector2, reach: float, arc_deg: float, level := 1) -> void:
	var s := _Slash.new()
	s.world_pos = world_pos
	s.dir = dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	s.reach = reach
	s.arc = deg_to_rad(arc_deg)
	s.color = LEVEL_TINTS[clampi(level, 0, 3)]
	s.width = 2.0 + level
	_layer.add_child(s)
	live_effects += 1
	await s.tree_exited
	live_effects -= 1


## A quick four-point sparkle (a hidden item's tell).
func glint(world_pos: Vector2, height_px: float, color: Color) -> void:
	var g := _Glint.new()
	g.world_pos = world_pos
	g.height = height_px
	g.color = color
	_add_world_fx(g)


## A wisp of scent rising off the ground (a spot the dog has smelled).
func scent_puff(world_pos: Vector2, color: Color) -> void:
	var p := _Puff.new()
	p.world_pos = world_pos + Vector2(randf_range(-4, 4), 0)
	p.color = color
	_add_world_fx(p)


## Clods of dirt flying up (the dog digging).
func dirt(world_pos: Vector2) -> void:
	var d := _Dirt.new()
	d.world_pos = world_pos
	for i in 6:
		d.bits.append(Vector3(randf_range(-40, 40), randf_range(-70, -35), randf_range(1.0, 2.0)))
	_add_world_fx(d)


## Wisps flowing from `from` (a node: they follow it) to `to` (a node or a
## Vector2), for `seconds`: the dog's scent trails. Returns the effect.
func scent_trail(from: Node2D, to: Variant, color: Color, seconds: float) -> Node2D:
	var t := _Trail.new()
	t.from = from
	t.to = to
	t.color = color
	t.life = seconds
	_add_world_fx(t)
	return t


## The scent trails showing now (tests read them).
func scent_trails() -> Array:
	return _layer.get_children().filter(func(n: Node) -> bool: return n is _Trail and not n.is_queued_for_deletion())


## World effects stop while the game is paused (Fx itself always runs, for
## the hit-stop).
func _add_world_fx(n: Node2D) -> void:
	n.process_mode = Node.PROCESS_MODE_PAUSABLE
	_layer.add_child(n)


## Freeze the game for a moment on impact (it sells the hit). Overlapping
## calls extend the freeze rather than stacking it.
func hit_stop(seconds: float) -> void:
	_stop_left = maxf(_stop_left, seconds)
	Engine.time_scale = 0.05


## Counts the hit-stop down in frame time with the slow-down taken back out,
## never the wall clock: it lasts the same at any frame rate, and in headless
## tests that run faster than real time it still ends.
func _process(delta: float) -> void:
	if _stop_left <= 0.0:
		return
	_stop_left -= delta / maxf(Engine.time_scale, 0.0001)
	if _stop_left <= 0.0:
		_stop_left = 0.0
		Engine.time_scale = 1.0


func is_hit_stopped() -> bool:
	return _stop_left > 0.0


func shake(strength: float, seconds: float) -> void:
	var k: float = Settings.get_value("screen_shake")  # the player's comfort setting
	if k > 0.0:
		EventBus.camera_shake.emit(strength * k, seconds)


## A swing trail: a fading arc drawn in screen space around the attacker,
## re-projected every frame so it sits right in both views.
class _Slash extends Node2D:
	var world_pos := Vector2.ZERO
	var dir := Vector2.DOWN
	var reach := 32.0
	var arc := PI * 0.66
	var color := Color.WHITE
	var width := 3.0
	var life := 0.16
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var center := Fx.world_to_screen(world_pos, 14.0)
		var tip := Fx.world_to_screen(world_pos + dir * reach, 14.0)
		var r := center.distance_to(tip)
		var ang := (tip - center).angle()
		var k := age / life
		# The arc sweeps across, its tail fading behind it.
		var sweep := arc * minf(1.0, k * 2.5)
		var start := ang - arc * 0.5
		for i in 4:
			var a := 1.0 - k - i * 0.18
			if a <= 0.0:
				continue
			var c := color
			c.a = a
			draw_arc(center, r - i * 2.0, start, start + sweep, 18, c, width - i * 0.5, true)


## Base for the small world effects below: ages, redraws, frees itself.
class _WorldFx extends Node2D:
	var world_pos := Vector2.ZERO
	var color := Color.WHITE
	var life := 0.5
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		queue_redraw()


class _Glint extends _WorldFx:
	var height := 8.0

	func _init() -> void:
		life = 0.45

	func _draw() -> void:
		var c := Fx.world_to_screen(world_pos, height)
		var k := age / life
		var r := 5.0 * sin(k * PI)  # grows, then shrinks away
		var col := color
		col.a = 0.95
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), col, 1.0)
		draw_line(c - Vector2(0, r * 1.4), c + Vector2(0, r * 1.4), col, 1.0)
		draw_circle(c, maxf(r * 0.3, 0.6), Color(1, 1, 1, 0.9))


class _Puff extends _WorldFx:
	func _init() -> void:
		life = 1.1

	func _draw() -> void:
		var k := age / life
		var c := Fx.world_to_screen(world_pos, 2.0 + 16.0 * k) + Vector2(sin(k * 7.0) * 2.0, 0)
		var col := color
		col.a = 0.7 * sin(k * PI)
		draw_circle(c, 1.5 + k * 2.0, col)


class _Dirt extends _WorldFx:
	## x, y velocity (px/s, screen), size.
	var bits: Array[Vector3] = []

	func _init() -> void:
		life = 0.45

	func _draw() -> void:
		var c := Fx.world_to_screen(world_pos, 2.0)
		var col := Color(0.42, 0.29, 0.17, 1.0 - age / life)
		for b in bits:
			var p := c + Vector2(b.x, b.y) * age + Vector2(0, 260.0 * age * age)
			draw_rect(Rect2(p, Vector2(b.z, b.z)), col)


## Wisps drift along the line from the dog to what he smells, wobbling side
## to side, brightest in the middle, fading in and out with the trail's life.
class _Trail extends _WorldFx:
	const SPACING := 16.0  # world px between wisps
	const SPEED := 0.35  # how fast they flow toward the target (trail lengths/s)
	var from: Node2D
	var to: Variant  # Node2D or Vector2

	## typeof, not `is`: `is` on a freed object is an error.
	func target_pos() -> Vector2:
		if typeof(to) == TYPE_OBJECT:
			return (to as Node2D).global_position if is_instance_valid(to) else world_pos
		return to

	func _process(delta: float) -> void:
		if is_instance_valid(from):
			world_pos = from.global_position
		if typeof(to) == TYPE_OBJECT and not is_instance_valid(to):
			queue_free()  # found and picked up meanwhile
			return
		super(delta)

	func _draw() -> void:
		var a := world_pos
		var b := target_pos()
		var length := a.distance_to(b)
		if length < 8.0:
			return
		var side := (b - a).orthogonal().normalized()
		var n := clampi(int(length / SPACING), 3, 24)
		var fade := minf(1.0, minf(age / 0.4, (life - age) / 0.8))
		for i in n:
			var u := fposmod(float(i) / n + age * SPEED, 1.0)
			var wobble := sin(u * 12.0 + age * 3.0 + i) * 5.0
			var p := Fx.world_to_screen(a.lerp(b, u) + side * wobble, 6.0)
			var k := fade * sin(u * PI)
			# A soft halo, the colored wisp, a bright core: reads on grass,
			# where a plain dot looked like one more flower.
			draw_circle(p, 5.0, Color(color, 0.22 * k))
			draw_circle(p, 3.0, Color(color, 0.85 * k))
			draw_circle(p, 1.3, Color(1, 1, 1, 0.8 * k))
