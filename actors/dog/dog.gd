# =============================================================================
# dog.gd  -  The dog: the kid's partner, or yours to drive after a switch
# -----------------------------------------------------------------------------
# WHAT:  Two ways to move, picked by Party:
#          controlled  the player drives him (Tab / gamepad Back switches);
#                      attack (J / Space / A) is his bite
#          AI partner  a PartnerBrain plays him by his stance: Offensive
#                      bites awake enemies near the kid, Search keeps out of
#                      fights and sniffs around. Following uses the shared
#                      breadcrumb Follower (systems/party/follower.gd explains
#                      the trail, the shortcuts and the anti-stutter rules).
#        Stay put (Q / gamepad X, via Party) makes him hold his spot.
#
# THE BITE: like the kid's swing, it runs on WeaponData (data/weapons/
#   dog_bite.tres) and an auto-filling ChargeMeter. He lunges forward and the
#   bite lands on the animation's hit frame, in a short arc in front of him.
#
# SAFETY NET: lost far behind and off-screen, he warps to the leader (the
#   Follower decides). F4 forces a warp.
#
# ART:   $Sprite is an AnimalSprite showing assets/characters/dog/dog_lpc.png
#   (an LPC shiba recolored into a brown brindle mutt by tools/art/build_art.py).
#   walk / run by speed, idle facing the leader, sniff, bite.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Dog
extends CharacterBody2D

## The follow states (IDLE, FOLLOW, CATCH_UP, STAY) live on the Follower.
const State = Follower.State

# --- Follow tuning (the Follower reads these; see follower.gd) ----------------
## Fallback for whom to follow before Party says (the "kid" group otherwise).
@export var target_path: NodePath
## He stops when he is this close to the leader (px).
@export var follow_distance := 36.0
## Once IDLE, the leader must get this much farther than follow_distance
## before he gets up again. This dead zone (hysteresis) stops stop-go stutter.
@export var resume_margin := 22.0
## Within this distance past follow_distance he eases off his speed, so he
## settles into a smooth trail behind a walking leader.
@export var slowdown_range := 44.0
## Beyond this distance he sprints.
@export var catch_up_distance := 150.0
## Sprinting continues until the gap closes to catch_up_distance minus this.
@export var catch_up_margin := 32.0
## Beyond this distance he warps to the leader, but ONLY while off-screen.
## On ultrawide monitors he can be visible 900+ px away; teleporting in
## plain sight looks broken, so a visible dog sprints instead.
@export var warp_distance := 480.0
## Beyond this distance he warps even if visible (truly lost/stuck).
@export var hard_warp_distance := 3200.0
@export var walk_speed := 124.0
@export var sprint_speed := 210.0
@export var acceleration := 2200.0
## Distance the leader must move before a new crumb is dropped (px).
@export var crumb_spacing := 10.0
## Hard cap on trail length so memory never grows unbounded.
@export var max_crumbs := 120
## How close he must get to a crumb before moving to the next one.
@export var crumb_reached_radius := 6.0
## How often (seconds) he looks for a straight-line shortcut along the trail.
@export var shortcut_interval := 0.1
## Physics layers his body can't pass through (layer 1 = "world").
@export_flags_2d_physics var blocking_mask := 1

# --- Driven by the player ------------------------------------------------------
## Top speed when the player drives him (a little quicker than the kid).
@export var move_speed := 140.0
## His bite (data/weapons/*.tres).
@export var weapon: WeaponData = preload("res://data/weapons/dog_bite.tres")
## Forward burst at the start of a bite (px/s).
@export var lunge_speed := 150.0
## Movement speed (px/s) that matches the walk cycle at 1x playback; raise it
## if the paws look like they slide, lower it if they moonwalk.
@export var walk_anim_speed := 70.0

## True while the player drives him (Party sets it).
var controlled := false
## Knocked out: lies down until Party revives him.
var downed := false
var facing := Vector2.RIGHT
## The auto-filling bite charge (HUD reads it).
var charge := ChargeMeter.new()
var follower: Follower
var brain: PartnerBrain

## Follow state (Follower), kept here for the overlay and tests.
var state: State:
	get:
		return follower.state if follower else State.IDLE
## How many times the safety-net warp fired (F3 overlay).
var warp_count: int:
	get:
		return follower.warp_count if follower else 0

var _attacking := false
var _swing_mult := 1.0
var _swing_level := 1
var _swing_landed := false
## Seconds he's stood still in Search stance (he sniffs around after a bit).
var _idle_time := 0.0

@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _on_screen: VisibleOnScreenNotifier2D = $OnScreen
@onready var _sprite: AnimalSprite = $Sprite
@onready var health: Health = $Health

## Search stance: sniff after standing still this long, then every SNIFF_EVERY.
const SNIFF_AFTER := 1.2
const SNIFF_EVERY := 2.5

# Debug trail colors (F3 overlay).
const COLOR_TRAIL := Color(1, 0.55, 0.1, 0.8)
const COLOR_TRAIL_NEXT := Color(1, 1, 0.2, 1)


func _ready() -> void:
	add_to_group("dog")
	add_to_group("hd_actor")
	follower = Follower.new(self, _collision, blocking_mask)
	follower.state_changed.connect(func(s: String) -> void:
		EventBus.dog_state_changed.emit(s)
		Debug.log_verbose("Dog state -> %s" % s))
	brain = PartnerBrain.new(self)
	charge = ChargeMeter.new(weapon.max_level, weapon.seconds_per_level)
	health.died.connect(_on_died)
	_sprite.animation_finished.connect(_on_animation_finished)
	_resolve_target()
	Party.register(self)


func _physics_process(delta: float) -> void:
	if not controlled and not is_instance_valid(follower.target):
		_resolve_target()
	follower.record_crumb()

	if downed:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return
	charge.tick(delta)

	if _attacking:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * 0.25 * delta)
		move_and_slide()
		if not _swing_landed and _sprite.frame_index() >= weapon.hit_frame:
			_land_bite()
		return

	var want := Vector2.ZERO
	if controlled:
		if not Dialogue.is_active():
			want = Input.get_vector("move_left", "move_right", "move_up", "move_down") * move_speed
	elif is_instance_valid(follower.target):
		want = brain.think(delta, Party.stance_of(self), Party.is_staying(self), _on_screen.is_on_screen())
	if want != Vector2.ZERO and not _attacking:
		facing = want.normalized()
	if not _attacking:  # think() may have just started a bite
		velocity = velocity.move_toward(want, acceleration * delta)
	move_and_slide()
	_update_animation(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_warp_dog") and not controlled:
		warp_to_target()
		return
	if not controlled or Dialogue.is_active():
		return
	if event.is_action_pressed("attack") and attack():
		get_viewport().set_input_as_handled()


## Bite now, with whatever charge has built up. False if he can't.
func attack() -> bool:
	if _attacking or downed or Dialogue.is_active():
		return false
	var spent := charge.spend()
	_swing_mult = spent[0]
	_swing_level = spent[1]
	_swing_landed = false
	_attacking = true
	velocity = facing * lunge_speed
	_sprite.speed_scale = weapon.swing_speed
	_sprite.play(weapon.swing_anim, facing, true)
	return true


func is_attacking() -> bool:
	return _attacking


## Called by his Hurtbox when a hit lands.
func on_hit(info: HitInfo, _dealt: int) -> void:
	velocity += info.knockback
	_sprite.modulate = Color(1.0, 0.45, 0.45)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.25)


func revive(fraction := 0.3) -> void:
	downed = false
	health.revive(fraction)
	follower.clear_trail()
	if follower.state != State.STAY:
		follower.set_state(State.IDLE)


func _on_died() -> void:
	downed = true
	_attacking = false
	_sprite.speed_scale = 1.0
	# Head down on the ground: the last frame of the sniff row, held.
	_sprite.play(&"sniff", facing, true)


func _on_animation_finished(anim: StringName) -> void:
	if anim == weapon.swing_anim:
		_attacking = false


func _land_bite() -> void:
	_swing_landed = true
	Fx.slash(global_position, facing, weapon.reach, weapon.arc_deg, _swing_level)
	Combat.strike(get_tree(), global_position + Vector2(0, -6), facing, weapon.reach,
			weapon.arc_deg, "player", _make_hit, _swing_level)


func _make_hit(hb: Hurtbox) -> HitInfo:
	var info := HitInfo.make(weapon.damage * _swing_mult, global_position, hb.global_position,
			weapon.knockback, "player", self)
	info.stagger = weapon.stagger
	info.level = _swing_level
	return info


## Teleport next to the leader and reset the trail. Safe to call any time.
func warp_to_target() -> void:
	follower.warp()


## Follow state name as text, for the debug overlay and EventBus.
func get_state_name() -> String:
	return follower.state_name()


## Trail length, for debugging/tests.
func get_trail_size() -> int:
	return follower.trail().size()


# -----------------------------------------------------------------------------
# Internals
# -----------------------------------------------------------------------------
func _resolve_target() -> void:
	var t: Node2D = null
	if not target_path.is_empty():
		t = get_node_or_null(target_path) as Node2D
	if not is_instance_valid(t):
		t = get_tree().get_first_node_in_group("kid") as Node2D
	follower.target = t
	if not is_instance_valid(t) and not has_meta("warned_no_target"):
		set_meta("warned_no_target", true)
		Debug.log_warn("Dog: no target found (target_path empty and no node in group 'kid')")


## Walk or run by speed, idle facing the leader, sniff now and then in Search.
## Playback speed follows actual speed so the paws plant instead of skating.
func _update_animation(delta: float) -> void:
	if downed or _attacking:
		return
	var speed := velocity.length()
	if speed < 8.0:
		_sprite.speed_scale = 1.0
		if not controlled and Party.stance_of(self) == "search":
			_idle_time += delta
			if _idle_time >= SNIFF_AFTER:
				_idle_time = SNIFF_AFTER - SNIFF_EVERY
				_sprite.play(&"sniff", facing, true)
			if _sprite.current == &"sniff" and _sprite.is_playing_once():
				return
		# Idle faces the leader, so a waiting dog looks like it's paying attention.
		var look := facing
		if not controlled and is_instance_valid(follower.target):
			look = global_position.direction_to(follower.target.global_position)
		_sprite.play(&"idle", look)
		return
	_idle_time = 0.0
	if speed > walk_speed * 1.05 or follower.state == State.CATCH_UP:
		_sprite.speed_scale = speed / sprint_speed
		_sprite.play(&"run", facing)
	else:
		_sprite.speed_scale = speed / walk_anim_speed
		_sprite.play(&"walk", facing)


# -----------------------------------------------------------------------------
# Debug drawing: the breadcrumb trail (only while the F3 overlay is on)
# -----------------------------------------------------------------------------
func _draw() -> void:
	var trail := follower.trail() if follower else ([] as Array[Vector2])
	if not Debug.overlay_visible or trail.is_empty():
		return
	for i in trail.size():
		var p := to_local(trail[i])
		var c := COLOR_TRAIL_NEXT if i == 0 else COLOR_TRAIL
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), c)
