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
# COMBAT: attack (J / Space / gamepad A) swings the equipped WeaponData. The
#        charge meter fills by itself (ChargeMeter): a swing uses whatever level
#        it reached (x1/x2/x4 at levels 1/2/3). If someone is in reach to talk,
#        the button talks instead. Hits knock him back and flash him; at 0 HP
#        he's downed and Party decides what happens next.
#
# AI PARTNER: after a switch (Tab / gamepad Back) the player drives the dog and
#        a PartnerBrain plays the kid by his stance: Offensive goes after awake
#        enemies near the dog, Defensive stays close and only swings at what
#        comes within reach. He follows with the same breadcrumb Follower the
#        dog uses (the follow tuning exports below).
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
## The equipped weapon (data/weapons/*.tres).
@export var weapon: WeaponData = preload("res://data/weapons/stick.tres")
## Movement speed kept while swinging (fraction of normal).
@export_range(0.0, 1.0) var swing_move_factor := 0.15

@export_group("Following (AI partner)")
## Same meanings as on the dog (systems/party/follower.gd reads them).
@export var follow_distance := 34.0
@export var resume_margin := 22.0
@export var slowdown_range := 44.0
@export var catch_up_distance := 150.0
@export var catch_up_margin := 32.0
@export var warp_distance := 480.0
@export var hard_warp_distance := 3200.0
## Following the dog: he walks at his own top speed and sprints a little past
## it (the dog is quicker), so he can keep up.
@export var walk_speed := 120.0
@export var sprint_speed := 165.0
@export var crumb_spacing := 10.0
@export var max_crumbs := 120
@export var crumb_reached_radius := 6.0
@export var shortcut_interval := 0.1
@export_flags_2d_physics var blocking_mask := 1
@export_group("")

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
## True while the player drives the kid (Party switches it).
var controlled := true
## The auto-filling attack charge (HUD reads it).
var charge := ChargeMeter.new()
var downed := false
## Following and fighting while the player drives the dog.
var follower: Follower
var brain: PartnerBrain

## Ground covered between footstep sounds (px), and what's left until the next.
const STEP_PX := 26.0
var _step_left := 0.0

var _attacking := false
var _swing_mult := 1.0
var _swing_level := 1
var _swing_landed := false
var _stagger := 0.0

@onready var _flashlight: PointLight2D = $Flashlight
@onready var _sprite: LpcSprite = $Sprite
@onready var health: Health = $Health
## Built in code: tells the Follower whether a warp would be seen.
var _on_screen: VisibleOnScreenNotifier2D


func _ready() -> void:
	add_to_group("kid")
	add_to_group("hd_actor")
	_flashlight.enabled = light_on
	EventBus.time_of_day_changed.connect(_on_time_of_day_changed)
	equip(weapon)
	_sprite.animation_finished.connect(_on_animation_finished)
	health.died.connect(_on_died)
	_on_screen = VisibleOnScreenNotifier2D.new()
	_on_screen.name = "OnScreen"
	_on_screen.rect = Rect2(-16, -48, 32, 50)
	add_child(_on_screen)
	follower = Follower.new(self, $CollisionShape2D, blocking_mask)
	brain = PartnerBrain.new(self)
	Party.register(self)


## Equip a weapon: the charge meter takes its levels and speed.
func equip(w: WeaponData) -> void:
	weapon = w
	charge = ChargeMeter.new(w.max_level, w.seconds_per_level)


## Swing the weapon now, with whatever charge has built up. Returns false if
## he can't (already swinging, downed, staggered, talking).
func attack() -> bool:
	if _attacking or downed or _stagger > 0.0 or Dialogue.is_active():
		return false
	var spent := charge.spend()
	_swing_mult = spent[0]
	_swing_level = spent[1]
	_swing_landed = false
	_attacking = true
	_sprite.speed_scale = weapon.swing_speed
	_sprite.play(weapon.swing_anim, facing, true)
	# A charged swing whooshes a little deeper.
	Audio.play_at("swing", global_position, 1.0 - 0.06 * (_swing_level - 1))
	return true


func is_attacking() -> bool:
	return _attacking


## Called by his Hurtbox when a hit lands.
func on_hit(info: HitInfo, _dealt: int) -> void:
	Audio.play_at("hurt", global_position)
	velocity += info.knockback
	_stagger = maxf(_stagger, info.stagger)
	var t := create_tween()
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	t.tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func revive(fraction := 0.3) -> void:
	downed = false
	health.revive(fraction)
	_sprite.play(&"idle", facing, true)


func _on_died() -> void:
	downed = true
	_attacking = false
	_sprite.speed_scale = 1.0
	_sprite.play(&"hurt", Vector2.ZERO, true)  # LPC "hurt" is falling down


func _on_animation_finished(anim: StringName) -> void:
	if anim == weapon.swing_anim:
		_attacking = false


func _land_swing() -> void:
	_swing_landed = true
	var origin := global_position + Vector2(0, -6)
	Fx.slash(global_position, facing, weapon.reach, weapon.arc_deg, _swing_level)
	Combat.strike(get_tree(), origin, facing, weapon.reach, weapon.arc_deg, "player",
			_make_hit, _swing_level)


## One HitInfo per target for the current swing.
func _make_hit(hb: Hurtbox) -> HitInfo:
	var info := HitInfo.make(weapon.damage * _swing_mult, global_position, hb.global_position,
			weapon.knockback, "player", self)
	info.stagger = weapon.stagger
	info.level = _swing_level
	return info


func _on_time_of_day_changed(time_name: String) -> void:
	var energy: float = LIGHT_ENERGY_BY_TIME.get(time_name, LIGHT_ENERGY_BY_TIME["night"])
	create_tween().tween_property(_flashlight, "energy", energy, LIGHT_FADE)


func _physics_process(delta: float) -> void:
	follower.record_crumb()
	if downed:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	charge.tick(delta)
	_stagger = maxf(0.0, _stagger - delta)
	var input_dir := Vector2.ZERO
	# Stand still while talking (the stick moves the dialogue choices instead)
	# and while staggered.
	var can_act := not Dialogue.is_active() and _stagger <= 0.0
	if can_act and controlled:
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	elif can_act and not _attacking and is_instance_valid(follower.target):
		# The AI plays him: its wanted velocity, as if it were stick input.
		var want := brain.think(delta, Party.stance_of(self), Party.is_staying(self), _on_screen.is_on_screen())
		input_dir = want / move_speed
	if _attacking:
		# Mostly planted during a swing; the blow lands on the weapon's frame.
		velocity = velocity.move_toward(input_dir * move_speed * swing_move_factor, friction * delta)
		move_and_slide()
		if not _swing_landed and _sprite.frame_index() >= weapon.hit_frame:
			_land_swing()
		return

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	elif not controlled:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation(input_dir)
	_footsteps(delta)

	# Flashlight sits slightly ahead of the kid, at chest height.
	_flashlight.position = facing * light_offset + Vector2(0, LIGHT_HEIGHT)


func _unhandled_input(event: InputEvent) -> void:
	if Dialogue.is_active():
		return
	if not controlled:
		return
	# Interact and attack share gamepad A: talking wins when someone's in reach.
	if event.is_action_pressed("interact") and Interaction.try_interact():
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("attack"):
		if attack():
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_light"):
		light_on = not light_on
		_flashlight.enabled = light_on
		EventBus.light_toggled.emit(light_on)
		Debug.log_verbose("Flashlight %s" % ("on" if light_on else "off"))


## A step sound every STEP_PX of ground covered, on whatever he's standing on.
func _footsteps(delta: float) -> void:
	var moved := get_real_velocity().length() * delta
	if moved < 0.05:
		_step_left = STEP_PX * 0.5  # the first step lands soon after starting
		return
	_step_left -= moved
	if _step_left <= 0.0:
		_step_left += STEP_PX
		Audio.play_at("step_" + AsciiRealm.surface_at(get_tree(), global_position), global_position)


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
