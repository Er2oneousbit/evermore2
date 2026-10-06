# =============================================================================
# kid.gd  -  The player-controlled kid
# -----------------------------------------------------------------------------
# WHAT:  8-direction top-down movement with acceleration/friction, a facing
#        direction, and the phone flashlight (PointLight2D) that points where
#        the kid faces.
# PROTOTYPE NOTE: the body is drawn with _draw() shapes as placeholder art.
#        When real sprites exist: add an AnimatedSprite2D, delete _draw(),
#        and drive animations from `facing` + `velocity`.
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

# --- Tuning (pixels are base-resolution pixels: 384x216 screen) --------------
## Top walking speed in px/sec. 80 crosses the screen in about 5 seconds.
@export var move_speed := 80.0
## How fast the kid reaches top speed. Higher = snappier.
@export var acceleration := 900.0
## How fast the kid stops when input is released. Higher = less sliding.
@export var friction := 1200.0
## How far in front of the kid the flashlight's center sits.
@export var light_offset := 18.0

## Flashlight brightness per time of day. A phone light is invisible at noon,
## so in daylight it would only wash out the scene. Unknown names use night.
const LIGHT_ENERGY_BY_TIME := {"day": 0.0, "golden": 0.35, "night": 1.2}
## Seconds to fade the flashlight when the time of day changes.
const LIGHT_FADE := 0.6

## Last non-zero movement direction. Other systems (attacks, interaction,
## the flashlight) read this to know which way the kid is looking.
var facing := Vector2.DOWN
var light_on := true

# Placeholder palette (swap for sprites later).
const COLOR_SHADOW := Color(0, 0, 0, 0.35)
const COLOR_HOODIE := Color("3b6ea5")
const COLOR_JEANS := Color("2e3a59")
const COLOR_SKIN := Color("e8b48a")
const COLOR_HAIR := Color("4a2f1d")

@onready var _flashlight: PointLight2D = $Flashlight


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

	# Flashlight sits slightly ahead of the kid, at chest height.
	_flashlight.position = facing * light_offset + Vector2(0, -10)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_light"):
		light_on = not light_on
		_flashlight.enabled = light_on
		EventBus.light_toggled.emit(light_on)
		Debug.log_verbose("Flashlight %s" % ("on" if light_on else "off"))


# -----------------------------------------------------------------------------
# Placeholder art: ~10x22 px kid, drawn upward from the feet.
# -----------------------------------------------------------------------------
func _draw() -> void:
	# Ground shadow (squashed circle).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 6.0, COLOR_SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_rect(Rect2(-4, -7, 8, 7), COLOR_JEANS)      # legs
	draw_rect(Rect2(-5, -15, 10, 9), COLOR_HOODIE)   # hoodie
	draw_circle(Vector2(0, -19), 4.0, COLOR_SKIN)    # head
	draw_rect(Rect2(-4, -23, 8, 3), COLOR_HAIR)      # hair

	# Facing marker: a little "nose" pixel so you can read direction at a glance.
	var nose := Vector2(0, -19) + facing * 3.0
	draw_rect(Rect2(nose - Vector2(1, 1), Vector2(2, 2)), COLOR_HAIR)
