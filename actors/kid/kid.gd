# =============================================================================
# kid.gd  -  The player-controlled kid
# -----------------------------------------------------------------------------
# WHAT:  8-direction top-down movement with acceleration/friction, a facing
#        direction, the LPC sprite animations, and the phone flashlight
#        (PointLight2D) that points where the kid faces.
#
# ART:   $Sprite is an LpcSprite showing assets/characters/kid/kid_lpc.png,
#        built with the Universal LPC generator (tools/lpc/README.md explains
#        how to rebuild it with a different outfit).
#        Full stick tilt = run cycle, partial tilt = walk cycle. Animation
#        speed follows movement speed so the feet don't "skate".
#
# ORIGIN CONVENTION: the node's origin is at the kid's FEET. Everything is
#        drawn upward from (0, 0). This is what makes Y-sorting look right
#        (walking "behind" a tree means your feet are above its trunk base).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Kid
extends CharacterBody2D

# --- Tuning (pixels are base-resolution pixels: 640x360 screen, 32 px tiles) --
## Top running speed in px/sec. 120 = 3.75 tiles/sec, crosses the screen in ~5 s.
@export var move_speed := 120.0
## How fast the kid reaches top speed. Higher = snappier.
@export var acceleration := 1500.0
## How fast the kid stops when input is released. Higher = less sliding.
@export var friction := 2000.0
## Below this fraction of move_speed the kid walks instead of running
## (analog sticks; keyboards are always full speed).
@export_range(0.0, 1.0) var walk_threshold := 0.6
## Movement speed (px/s) that matches the run cycle at 1x playback. Tweak this
## if the feet look like they slide (raise it) or moonwalk (lower it).
@export var run_anim_speed := 95.0
## Same for the walk cycle.
@export var walk_anim_speed := 48.0
## How far in front of the kid the flashlight's center sits.
@export var light_offset := 30.0

## Flashlight brightness per time of day. A phone light is invisible at noon,
## so in daylight it would only wash out the scene. Unknown names use night.
const LIGHT_ENERGY_BY_TIME := {"day": 0.0, "golden": 0.35, "night": 1.3}
## Seconds to fade the flashlight when the time of day changes.
const LIGHT_FADE := 0.6
## Chest height of the flashlight (phone held up in front).
const LIGHT_HEIGHT := -26.0

## Last non-zero movement direction. Other systems (attacks, interaction,
## the flashlight) read this to know which way the kid is looking.
var facing := Vector2.DOWN
var light_on := true

@onready var _flashlight: PointLight2D = $Flashlight
@onready var _sprite: LpcSprite = $Sprite


func _ready() -> void:
	add_to_group("kid")
	_flashlight.enabled = light_on
	EventBus.time_of_day_changed.connect(_on_time_of_day_changed)


func _on_time_of_day_changed(time_name: String) -> void:
	var energy: float = LIGHT_ENERGY_BY_TIME.get(time_name, LIGHT_ENERGY_BY_TIME["night"])
	create_tween().tween_property(_flashlight, "energy", energy, LIGHT_FADE)


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation(input_dir)

	# Flashlight sits slightly ahead of the kid, at chest height.
	_flashlight.position = facing * light_offset + Vector2(0, LIGHT_HEIGHT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_light"):
		light_on = not light_on
		_flashlight.enabled = light_on
		EventBus.light_toggled.emit(light_on)
		Debug.log_verbose("Flashlight %s" % ("on" if light_on else "off"))


## Picks idle / walk / run from the actual speed, and keeps playback speed in
## step with movement so feet plant on the ground instead of sliding.
func _update_animation(input_dir: Vector2) -> void:
	var speed := velocity.length()
	if speed < 6.0:
		_sprite.speed_scale = 1.0
		_sprite.play(&"idle", facing)
	elif input_dir.length() < walk_threshold and speed < move_speed * walk_threshold:
		_sprite.speed_scale = speed / walk_anim_speed
		_sprite.play(&"walk", facing)
	else:
		_sprite.speed_scale = speed / run_anim_speed
		_sprite.play(&"run", facing)
