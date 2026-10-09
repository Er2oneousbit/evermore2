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
#        He walks; hold Run (Shift / gamepad LB) to run, which drains his
#        attack charge (systems/party/running.gd). A partly tilted stick
#        walks slower. Walk or run cycle by speed; animation speed follows movement
#        speed so the feet don't "skate".
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
## Walking speed when you drive him (px/s).
@export var move_speed := 93.5
## Running speed (holding Run, while his charge lasts). 154 = 4.8 tiles/s.
@export var run_speed := 154.0
## Attack charge running costs, in levels per second (0.5 = 100% in 2 s).
@export var run_charge_drain := 0.5
## How fast the kid reaches top speed. Higher = snappier.
@export var acceleration := 1500.0
## How fast the kid stops when input is released. Higher = less sliding.
@export var friction := 2000.0
## How fast his heading swings toward the stick (deg/s). A turn bends the
## velocity round instead of slowing to a crawl and speeding up again.
@export var turn_rate_deg := 720.0
## Pushing against his motion (more than REVERSE_DEG off) brakes at this rate
## (px/s^2): a reversal takes a few frames, not one, but stays responsive.
@export var brake := 1300.0
## Facing keeps its side/front axis until the other axis wins by this factor
## (a diagonal doesn't flicker between up and right).
@export var facing_bias := 1.35
## Movement speed (px/s) that matches the run cycle at 1x playback. Tweak this
## if the feet look like they slide (raise it) or moonwalk (lower it).
@export var run_anim_speed := 104.5
## Same for the walk cycle.
@export var walk_anim_speed := 70.4
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
@export var walk_speed := 132.0
@export var sprint_speed := 181.5
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
## A push this far from his current motion is a reversal (brake first).
const REVERSE_DEG := 120.0

## Last non-zero movement direction. Other systems (attacks, interaction,
## the flashlight) read this to know which way the kid is looking.
var facing := Vector2.DOWN
var light_on := true
## True while the player drives the kid (Party switches it).
var controlled := true
## The auto-filling attack charge (HUD reads it).
var charge := ChargeMeter.new()
## Running and its cost (HUD reads `winded`). Only used while you drive him.
var run: Running
## True while he's running this frame.
var running := false
var downed := false
## Following and fighting while the player drives the dog.
var follower: Follower
var brain: PartnerBrain

## Ground covered between footstep sounds (px), and what's left until the next.
const STEP_PX := 26.0
var _step_left := 0.0

var _attacking := false
## A weapon put on mid-swing, equipped when the swing ends.
var _pending_weapon: WeaponData
## The weapon in his hand while he swings: behind him and in front of him
## (WeaponData.overlay_*). HdView mirrors both (meta "hd_layers").
var _weapon_back: Sprite2D
var _weapon_front: Sprite2D
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
	_build_weapon_layers()
	equip(weapon)
	_apply_equipment("kid")
	EventBus.equipment_changed.connect(_apply_equipment)
	_sprite.animation_finished.connect(_on_animation_finished)
	_sprite.dir_bias = facing_bias
	health.died.connect(_on_died)
	_on_screen = VisibleOnScreenNotifier2D.new()
	_on_screen.name = "OnScreen"
	_on_screen.rect = Rect2(-16, -48, 32, 50)
	add_child(_on_screen)
	follower = Follower.new(self, $CollisionShape2D, blocking_mask)
	brain = PartnerBrain.new(self)
	Party.register(self)


## Two layers around his body sprite: the back one drawn before it, the front
## one after. Same center as the 64 px body frame (LPC weapon cells share it).
func _build_weapon_layers() -> void:
	_weapon_back = Sprite2D.new()
	_weapon_back.name = "WeaponBack"
	_weapon_front = Sprite2D.new()
	_weapon_front.name = "WeaponFront"
	for layer in [_weapon_back, _weapon_front]:
		layer.offset = _sprite.offset
		layer.visible = false
		add_child(layer)
	move_child(_weapon_back, _sprite.get_index())
	move_child(_weapon_front, _sprite.get_index() + 1)
	set_meta("hd_layers", {"WeaponBack": -0.004, "WeaponFront": 0.004})
	# The body animates in its own _process, after his physics: follow its
	# frame changes directly, or the weapon trails the body by one frame.
	_sprite.frame_changed.connect(_update_weapon_layers)


## Show the weapon in his hand on the swing's current frame.
func _update_weapon_layers() -> void:
	var show := _attacking and _sprite.current == weapon.swing_anim and weapon.overlay_fg != null
	for layer in [_weapon_back, _weapon_front]:
		layer.visible = show and layer.texture != null
		if layer.visible:
			layer.frame_coords = Vector2i(clampi(_sprite.frame_index(), 0, layer.hframes - 1), int(_sprite.dir))


## What he wears (Equipment): the weapon, and armor from every piece. A
## weapon changed mid-swing (the ring menu pauses a swing halfway) waits for
## the swing to end: the blow lands with the weapon it started with.
func _apply_equipment(who: String) -> void:
	if who != "kid":
		return
	var w := Equipment.weapon("kid")
	if w and w != weapon:
		if _attacking:
			_pending_weapon = w
		else:
			equip(w)
	health.armor = Equipment.defense("kid")


## Equip a weapon: the charge meter takes its levels and speed, and keeps
## what's built up (capped to the new weapon): swapping weapons must not
## refill an empty meter.
func equip(w: WeaponData) -> void:
	weapon = w
	_pending_weapon = null
	var built := charge.value if charge else 1.0
	charge = ChargeMeter.new(w.max_level, w.seconds_per_level)
	charge.value = minf(built, float(w.max_level))
	for pair in [[_weapon_back, w.overlay_bg], [_weapon_front, w.overlay_fg]]:
		var layer: Sprite2D = pair[0]
		var tex: Texture2D = pair[1]
		if layer == null:
			continue
		layer.texture = tex
		if tex:
			layer.hframes = maxi(1, tex.get_width() / w.overlay_frame)
			layer.vframes = 4
		layer.visible = false
	if run:
		run.charge = charge  # same legs, new weapon
	else:
		run = Running.new(charge, run_charge_drain)


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
	run.reset()
	_sprite.play(&"idle", facing, true)


func _on_died() -> void:
	downed = true
	_attacking = false
	_sprite.speed_scale = 1.0
	_sprite.play(&"hurt", Vector2.ZERO, true)  # LPC "hurt" is falling down
	if _pending_weapon:
		equip(_pending_weapon)


func _on_animation_finished(anim: StringName) -> void:
	if anim == weapon.swing_anim:
		_attacking = false
		if _pending_weapon:
			equip(_pending_weapon)


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
	# Where he wants to go, in px/s.
	var want := Vector2.ZERO
	# Stand still while talking (the stick moves the dialogue choices instead)
	# and while staggered.
	var can_act := not Dialogue.is_active() and _stagger <= 0.0
	if can_act and controlled:
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# A swing pauses the run without cancelling a toggled one.
		var want_run := run.wants_run(input_dir != Vector2.ZERO, delta)
		var moving := input_dir != Vector2.ZERO and not _attacking
		running = run.tick(delta, want_run, moving)
		want = input_dir * (run_speed if running else move_speed)
	else:
		running = false
		run.tick(delta, false, false)
		if can_act and not _attacking and is_instance_valid(follower.target):
			# The AI plays him: its wanted velocity (running costs him nothing:
			# he has to keep up).
			want = brain.think(delta, Party.stance_of(self), Party.is_staying(self), _on_screen.is_on_screen())
			input_dir = want / move_speed
	if _attacking:
		# Mostly planted during a swing; the blow lands on the weapon's frame.
		velocity = velocity.move_toward(want * swing_move_factor, friction * delta)
		move_and_slide()
		if not _swing_landed and _sprite.frame_index() >= weapon.hit_frame:
			_land_swing()
		_update_weapon_layers()
		return

	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = _steer(want, delta)
	elif not controlled:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
	_update_animation(input_dir != Vector2.ZERO)
	_footsteps(delta)
	_update_weapon_layers()

	# Flashlight sits slightly ahead of the kid, at chest height.
	_flashlight.position = facing * light_offset + Vector2(0, LIGHT_HEIGHT)


## Velocity toward `want` (px/s): speed ramps by `acceleration`; a change of
## heading rotates the velocity at `turn_rate_deg` (keeping his speed through a
## corner); a reversal brakes first, then accelerates the other way.
func _steer(want: Vector2, delta: float) -> Vector2:
	var v := velocity
	if v.length() > 12.0:
		var ang := v.angle_to(want)
		if absf(ang) > deg_to_rad(REVERSE_DEG):
			return v.move_toward(Vector2.ZERO, brake * delta)
		var step := deg_to_rad(turn_rate_deg) * delta
		v = v.rotated(clampf(ang, -step, step))
	return v.move_toward(want, acceleration * delta)


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


## Picks idle / walk / run from the actual speed (anything past a walk is the
## run cycle: running, or the AI hurrying to keep up), and keeps playback
## speed in step with movement so feet plant instead of sliding.
func _update_animation(pushing := false) -> void:
	var speed := velocity.length()
	if speed < 6.0 and pushing and (_sprite.current == &"walk" or _sprite.current == &"run"):
		# Turning round (or starting off a wall): stay in the walk cycle
		# instead of blinking to idle and restarting the stride.
		_sprite.speed_scale = 0.5
		_sprite.play(_sprite.current, facing)
		return
	if speed < 6.0:
		_sprite.speed_scale = 1.0
		_sprite.play(&"idle", facing)
	elif speed <= move_speed * 1.1:
		_sprite.speed_scale = speed / walk_anim_speed
		_sprite.play(&"walk", facing)
	else:
		_sprite.speed_scale = speed / run_anim_speed
		_sprite.play(&"run", facing)
