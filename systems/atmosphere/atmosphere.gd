# =============================================================================
# atmosphere.gd  -  Per-realm mood: time of day, color grade, ambient life
# -----------------------------------------------------------------------------
# WHAT:  One node that owns everything about how a realm FEELS, per time of
#        day ("morning", "day", "golden", "night"):
#          - CanvasModulate tint of the world (lights add on top, so the
#            flashlight matters at night)
#          - full-screen color grade (assets/shaders/color_grade.gdshader):
#            saturation, contrast, split toning, light shafts, vignette
#          - ambient particles: pollen/fluff drifting in the light, fireflies
#            at night
#          - drifting cloud shadows over the ground (day / golden hour)
#        Switching time of day tweens all of it together. F2 cycles it.
#
# TIME COMES FROM THE CLOCK (autoload/clock.gd): this node follows
#        Clock.phase_changed and fades over the blend the clock asks for (a
#        long one when the clock moves on by itself). On load it hands the
#        realm's CLOCK_MODE and `start_time` to the clock. set_time() (F2, a
#        dialogue's @time) is a Clock.jump: a held clock stays held.
#
# HOW TO USE IN A REALM: add an Atmosphere node to the realm scene and pick
#        `start_time`. That's it. To give a realm its own mood, duplicate
#        PRESETS into a realm-specific script, or change `presets` at runtime.
#
# LAYERS (CanvasLayer index): world = 0, ambient particles = 3,
#        color grade = 4, combat FX = 5, HUD = 10, debug overlay = 100.
#        Only the world and particles are graded; HUD/debug stay readable.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Atmosphere
extends Node

## Mood per time of day. Colors are Godot Color(r, g, b[, a]).
##   tint            world multiply (CanvasModulate)
##   shadow_tint     added to dark areas, a = strength (split toning)
##   highlight_tint  multiplied into bright areas, a = strength
##   shafts          0..1 light-shaft strength; vignette 0..1
##   pollen/fireflies 0..1 ambient particle visibility
##   clouds          0..1 drifting cloud-shadow darkness
const PRESETS := {
	# Morning: soft and cool, a little mist (the grade's cloud shadows), low
	# pale shafts; brighter than golden so it reads at a glance.
	"morning": {
		"tint": Color(0.9, 0.94, 1.0), "saturation": 0.98, "contrast": 1.0,
		"shadow_tint": Color(0.2, 0.28, 0.5, 0.3), "highlight_tint": Color(0.92, 0.96, 1.0, 0.3),
		"shafts": 0.35, "shaft_color": Color(0.88, 0.94, 1.0), "vignette": 0.26,
		"vignette_color": Color(0.06, 0.08, 0.16), "pollen": 0.3, "fireflies": 0.0, "clouds": 0.18,
	},
	"day": {
		"tint": Color(1.0, 1.0, 1.0), "saturation": 1.08, "contrast": 1.03,
		"shadow_tint": Color(0.12, 0.16, 0.38, 0.22), "highlight_tint": Color(1.0, 0.98, 0.9, 0.25),
		"shafts": 0.18, "shaft_color": Color(1.0, 0.97, 0.85), "vignette": 0.22,
		"vignette_color": Color(0.05, 0.06, 0.12), "pollen": 0.5, "fireflies": 0.0, "clouds": 0.28,
	},
	"golden": {
		"tint": Color(1.0, 0.84, 0.66), "saturation": 1.12, "contrast": 1.08,
		"shadow_tint": Color(0.42, 0.12, 0.52, 0.42), "highlight_tint": Color(1.0, 0.76, 0.48, 0.62),
		"shafts": 0.95, "shaft_color": Color(1.0, 0.74, 0.4), "vignette": 0.48,
		"vignette_color": Color(0.22, 0.05, 0.12), "pollen": 1.0, "fireflies": 0.0, "clouds": 0.22,
	},
	"night": {
		"tint": Color(0.24, 0.27, 0.48), "saturation": 0.85, "contrast": 1.06,
		"shadow_tint": Color(0.04, 0.08, 0.3, 0.4), "highlight_tint": Color(0.82, 0.9, 1.0, 0.3),
		"shafts": 0.0, "shaft_color": Color(0.6, 0.7, 1.0), "vignette": 0.58,
		"vignette_color": Color(0.0, 0.01, 0.06), "pollen": 0.0, "fireflies": 1.0, "clouds": 0.0,
	},
}
## Same order as the clock: morning, day, golden, night, morning...
const TIME_ORDER: Array[String] = ["morning", "day", "golden", "night"]

const GRADE_SHADER := preload("res://assets/shaders/color_grade.gdshader")
const CLOUD_NOISE := preload("res://assets/shaders/cloud_noise.tres")
const GLOW_DOT := preload("res://assets/fx/glow_dot.tres")

## Time of day when the realm loads.
@export_enum("morning", "day", "golden", "night") var start_time := "golden"
## Seconds to blend when F2 skips to the next time of day (the clock's own
## changes use Clock.FADE_SECONDS).
@export var blend_seconds := 0.8
## Pollen motes per 640x360 of visible area (ultrawide gets proportionally more).
@export var pollen_density := 60
## Fireflies per 640x360 of visible area.
@export var firefly_density := 26

## Current time of day ("morning", "day", "golden", "night").
var time_name := ""

## Draw the 2D mood layers (tint, grade, particles). The HD-2D view turns
## this off and does its own lighting, but still relies on this node for
## the time of day (F2) and the EventBus announcements.
var render_2d := true:
	set(value):
		render_2d = value
		if is_instance_valid(_modulate):
			_modulate.visible = value
			_grade.get_parent().visible = value
			_particle_layer.visible = value

var presets: Dictionary = PRESETS
var _modulate: CanvasModulate
var _grade: ColorRect
var _grade_mat: ShaderMaterial
var _particle_layer: CanvasLayer
var _pollen: CPUParticles2D
var _fireflies: CPUParticles2D
var _tween: Tween
## The look at the clock's hour (_to), what is on screen (_applied) and, during
## a jump crossfade only, where it started (_from) and how far along (_xf).
var _to: Dictionary = {}
var _from: Dictionary = {}
var _applied: Dictionary = {}
var _xf := 1.0
var _look_hour := -1.0
const LOOK_STEP_HOURS := 0.004


func _ready() -> void:
	_modulate = CanvasModulate.new()
	_modulate.name = "WorldTint"
	add_child(_modulate)
	_build_grade()
	_build_particles()
	ScreenScaler.view_changed.connect(_on_view_changed)
	_on_view_changed(ScreenScaler.view_size, ScreenScaler.scale)
	# The realm (our parent) picks how the clock behaves here. Read straight
	# from its script: its _ready (and config) runs after ours.
	Clock.enter_realm(AsciiRealm.const_of(get_parent(), "CLOCK_MODE", "set"), start_time)
	Clock.phase_changed.connect(_apply)
	_apply(Clock.phase, 0.0)
	Settings.changed.connect(func(key: String, _v: Variant) -> void:
		if key == "brightness" and not _applied.is_empty():
			_modulate.color = _bright(_applied["tint"]))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_cycle_time"):
		cycle_time()


func _process(_delta: float) -> void:
	_update_look()
	# Particles live in world space; keep their spawn box centered on the view.
	var cam := get_viewport().get_camera_2d()
	if cam:
		var center := cam.get_screen_center_position()
		_pollen.global_position = center
		_fireflies.global_position = center
		# Cloud shadows are world-anchored: tell the shader where the view is.
		_grade_mat.set_shader_parameter("cam_px", (center - Vector2(ScreenScaler.view_size) * 0.5).floor())


## Next time of day in TIME_ORDER (what F2 does), with a short fade.
func cycle_time() -> void:
	var i := TIME_ORDER.find(time_name)
	set_time(TIME_ORDER[(i + 1) % TIME_ORDER.size()], blend_seconds)


## Switch to a time of day, blending over `seconds` (0 = instantly). This
## moves the game clock (Clock.jump, mode unchanged); the look follows it.
func set_time(new_time: String, seconds := 0.8) -> void:
	if not presets.has(new_time):
		Debug.log_warn("Atmosphere: unknown time of day '%s'" % new_time)
		return
	Clock.jump(new_time, seconds)


## The clock moved on to a new PHASE: announce it (music, ambience, shops and
## the like key on the names). The look itself follows the hour continuously
## (_update_look), so nothing fades here; a jump is crossfaded there.
func _apply(new_time: String, _seconds: float) -> void:
	if not presets.has(new_time):
		Debug.log_warn("Atmosphere: no preset for time of day '%s'" % new_time)
		return
	time_name = new_time
	_update_look(_look_hour < 0.0)
	EventBus.time_of_day_changed.emit(new_time)
	Debug.log_verbose("Atmosphere: time of day -> %s" % new_time)


## Re-sample the mood at the clock's hour (DayLight blends the presets between
## keyframes). A big hour gap is a jump (F2, @time): crossfade from what is on
## screen over the jump's blend instead of popping.
func _update_look(force := false) -> void:
	var h := Clock.hour()
	var gap := DayLight.hour_gap(_look_hour, h) if _look_hour >= 0.0 else 0.0
	if not force and absf(gap) < LOOK_STEP_HOURS:
		return
	var jumped := _look_hour >= 0.0 and absf(gap) > DayLight.JUMP_HOURS and Clock.last_blend > 0.0
	if jumped:
		_from = _applied.duplicate()
	_look_hour = h
	_to = DayLight.sample(presets, h)
	if jumped:
		if _tween:
			_tween.kill()
		_xf = 0.0
		var secs := minf(Clock.last_blend, blend_seconds)
		_tween = create_tween().set_trans(Tween.TRANS_SINE)
		_tween.tween_method(_set_xf, 0.0, 1.0, maxf(secs, 0.05))
	elif _tween != null and _tween.is_running():
		_blend(_xf)
	else:
		_xf = 1.0
		_from = {}
		_blend(1.0)


func _set_xf(t: float) -> void:
	_xf = t
	_blend(t)
	if t >= 1.0:
		_from = {}


func _blend(t: float) -> void:
	var p: Dictionary = _to if t >= 1.0 or _from.is_empty() else DayLight.mix(_from, _to, t)
	_applied = p
	_modulate.color = _bright(p["tint"])
	_grade_mat.set_shader_parameter("saturation", p["saturation"])
	_grade_mat.set_shader_parameter("contrast", p["contrast"])
	_grade_mat.set_shader_parameter("shadow_tint", p["shadow_tint"])
	_grade_mat.set_shader_parameter("highlight_tint", p["highlight_tint"])
	_grade_mat.set_shader_parameter("shaft_strength", p["shafts"])
	_grade_mat.set_shader_parameter("shaft_color", p["shaft_color"])
	_grade_mat.set_shader_parameter("vignette_strength", p["vignette"])
	_grade_mat.set_shader_parameter("vignette_color", p["vignette_color"])
	_grade_mat.set_shader_parameter("cloud_strength", p.get("clouds", 0.0))
	_pollen.modulate.a = p["pollen"]
	_fireflies.modulate.a = p["fireflies"]
	_pollen.emitting = p["pollen"] > 0.0
	_fireflies.emitting = p["fireflies"] > 0.0


## The world tint with the player's brightness (Settings) applied.
func _bright(tint: Color) -> Color:
	var b: float = Settings.get_value("brightness")
	return Color(tint.r * b, tint.g * b, tint.b * b, tint.a)


# -----------------------------------------------------------------------------
# Building
# -----------------------------------------------------------------------------
func _build_grade() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ColorGrade"
	layer.layer = 4
	add_child(layer)
	_grade = ColorRect.new()
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade_mat = ShaderMaterial.new()
	_grade_mat.shader = GRADE_SHADER
	_grade_mat.set_shader_parameter("cloud_noise", CLOUD_NOISE)
	_grade.material = _grade_mat
	layer.add_child(_grade)


func _build_particles() -> void:
	# A CanvasLayer that follows the camera like the world does, but is NOT
	# tinted by the world's CanvasModulate, so fireflies stay bright at night.
	_particle_layer = CanvasLayer.new()
	_particle_layer.name = "AmbientParticles"
	_particle_layer.layer = 3
	_particle_layer.follow_viewport_enabled = true
	add_child(_particle_layer)

	_pollen = _make_emitter("Pollen")
	_pollen.lifetime = 9.0
	_pollen.direction = Vector2(1.0, -0.35)
	_pollen.spread = 35.0
	_pollen.initial_velocity_min = 5.0
	_pollen.initial_velocity_max = 13.0
	_pollen.gravity = Vector2(0.0, -1.5)
	_pollen.tangential_accel_min = -3.0
	_pollen.tangential_accel_max = 3.0
	_pollen.scale_amount_min = 1.0
	_pollen.scale_amount_max = 2.0
	_pollen.color = Color(1.0, 0.95, 0.75)
	_pollen.color_ramp = _ramp([0.0, 0.2, 0.8, 1.0], [0.0, 0.85, 0.85, 0.0])

	_fireflies = _make_emitter("Fireflies")
	_fireflies.texture = GLOW_DOT
	_fireflies.lifetime = 6.0
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 3.0
	_fireflies.initial_velocity_max = 9.0
	_fireflies.gravity = Vector2.ZERO
	_fireflies.tangential_accel_min = -12.0
	_fireflies.tangential_accel_max = 12.0
	_fireflies.scale_amount_min = 0.7
	_fireflies.scale_amount_max = 1.0
	_fireflies.color = Color(0.85, 1.0, 0.45)
	# Blink: fade in, pulse, fade out.
	_fireflies.color_ramp = _ramp([0.0, 0.15, 0.35, 0.5, 0.7, 1.0], [0.0, 1.0, 0.25, 1.0, 0.9, 0.0])
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fireflies.material = add


func _make_emitter(emitter_name: String) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.name = emitter_name
	e.local_coords = false
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.preprocess = 8.0  # start already populated instead of fading in on load
	e.amount = 16
	_particle_layer.add_child(e)
	return e


## Alpha-only gradient for particle fade in/out (color comes from .color).
func _ramp(offsets: Array, alphas: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	var colors := PackedColorArray()
	for a: float in alphas:
		colors.append(Color(1, 1, 1, a))
	g.colors = colors
	return g


func _on_view_changed(view: Vector2i, _scale: int) -> void:
	_grade_mat.set_shader_parameter("view_px", Vector2(view))
	# Spawn box covers the whole view plus a margin, and the particle count
	# grows with visible area so ultrawide doesn't look sparse.
	var area_factor := float(view.x * view.y) / float(ScreenScaler.BASE_SIZE.x * ScreenScaler.BASE_SIZE.y)
	var extents := Vector2(view) * 0.5 + Vector2(48, 48)
	for e: CPUParticles2D in [_pollen, _fireflies]:
		e.emission_rect_extents = extents
	_pollen.amount = maxi(1, roundi(pollen_density * area_factor))
	_fireflies.amount = maxi(1, roundi(firefly_density * area_factor))
