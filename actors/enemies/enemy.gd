# =============================================================================
# enemy.gd  -  A generic enemy driven by an EnemyData resource
# -----------------------------------------------------------------------------
# WHAT:  States:
#          IDLE     at home, waiting; wakes when the kid or dog comes within
#                   aggro_radius (distance only, never "on screen")
#          CHASE    runs at the nearest party member who isn't down
#          WINDUP   stops and flashes: the telegraph you can react to
#          ATTACK   lunges; the hit lands on attack_hit_frame
#          RECOVER  rests for attack_cooldown
#          HURT     knocked back and staggered after a hit
#          RETURN   lost its target past leash_radius: walks home, heals up
#          DEAD     plays the death animation, blinks, and is removed
#          ENTER    a visible entrance (out of the canopy, rise from the ground,
#                   squeeze out of a hole, fade in); can't be hit meanwhile
#          LEAVE    its time of day is over: scurries/flies to an exit (a hole,
#                   its tree, past the edge). The DayNightDirector removes it
#                   once it is out of the camera's view, never in plain sight
#          ROOST    up in its tree's leaves (bats, by day): not drawn at all, no
#                   aggro; at dusk it flies out of the canopy (a shower of
#                   leaves), at dawn it flies back in and vanishes among them
#        Stats come from the EnemyData scaled by Difficulty (Hard: more HP and
#        armor, harder hits).
# PLACE: Enemy.create(data, position), or an AsciiRealm's ENEMIES_BY_CHAR.
# HD-2D: in group "hd_actor" (the flash and blink mirror through modulate).
# NIGHT: while you drive the dog at night his nose picks enemies out: `scent`
#        fades to 1 and they glow softly (a ScentGlow under them in 2D; HdView
#        passes `scent` to hd_actor.gdshader). No stat changes (owner: "dog
#        doesn't change other than baddies might be a bit brighter").
# CLOCK: with clock_rule "follow_clock" the realm's DayNightDirector
#        (systems/enemies/day_night.gd) spawns, retires and recalls it; see
#        EnemyData "Day and night". A flyer (data.flies) hovers `height` px up,
#        ignores walls and flutters while idle. In a fight it circles its
#        target at `orbit_radius` (smooth steering, a slow radius wobble),
#        telegraphs (WINDUP: hovers low, squeak, orange pulse), dives at the
#        spot the target stood when the telegraph began (ATTACK, locked: stand
#        still and it bites, sidestep and it misses), then climbs away and
#        circles for attack_cooldown (RECOVER). Hittable all through.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)
## A visible entrance finished (see begin_entrance).
signal entered(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, HURT, RETURN, DEAD, ENTER, LEAVE, ROOST }

const ACCEL := 900.0
## The telegraph: an orange warning pulse (the hit flash is red). Kept at or
## below 1.0 on purpose: brighter-than-white sprites trip HD-2D's bloom under a
## strong sun and halo everything nearby, the kid included.
const FLASH := Color(1.0, 0.68, 0.22)
## The scent glow: warm, soft, and how fast it fades in or out (per second).
const SCENT_COLOR := Color(1.0, 0.86, 0.5)
const SCENT_FADE := 2.5
const GLOW_DOT := preload("res://assets/fx/glow_dot.tres")
## Seconds an enemy counts as "in combat" after it was hit or woke on someone:
## the director never retires it meanwhile.
const COMBAT_MEMORY := 6.0
## How long each entrance takes (seconds).
const ENTER_SECONDS := {"drop": 0.8, "rise": 1.2, "burrow": 1.0, "fade": 0.9}
const ARRIVE_PX := 18.0
const SINK_SECONDS := 0.5
## Climb/fall speed for flyers' height changes (px/s).
const HEIGHT_SPEED := 70.0
## Flyer steering: gentle acceleration (px/s^2) and how fast it circles (rad/s).
const FLY_ACCEL := 240.0
const ORBIT_SPEED := 0.9
## Seconds a flyer circles before its first swoop, and how far out it retreats
## after one (x orbit_radius).
const FIRST_SWOOP_DELAY := 1.2
const RETREAT_FACTOR := 1.5

@export var data: EnemyData

var state: State = State.IDLE
var home := Vector2.ZERO
var target: Node2D
var health: Health
## Does this enemy follow the game clock? "unchanged" or "follow_clock"
## (AsciiRealm ENEMY_CLOCK, per spawner). Follow_clock enemies are managed by
## the realm's DayNightDirector (see EnemyData "Day and night").
var clock_rule := "unchanged"
## Flyers: px above the ground (drawn through the sprite's offset).
var height := 0.0
## Counts down from COMBAT_MEMORY after a hit or an aggro.
var combat_timer := 0.0
## Which entrance is playing (ENTER), and where the exit is (LEAVE).
var entrance := ""
var leave_kind := ""
var leave_point := Vector2.ZERO
## LEAVE: reached a hole and sunk into it (burrow), or faded out (fade).
var leave_done := false
## LEAVE: made no progress toward the exit for a while (the director tries
## another exit or gives up).
var leave_failed := false
## 0..1: how strongly the dog smells it (night + the dog driven). Both views
## draw it; tests read it.
var scent := 0.0
var _scent_glow: Sprite2D

var _sprite: AnimalSprite
var _timer := 0.0
var _attack_dir := Vector2.DOWN
var _landed := false
var _base_offset := Vector2.ZERO
var _age := 0.0
var _enter_t := 0.0
var _sink_t := 0.0
var _flutter_to := Vector2.ZERO
var _flutter_t := 0.0
var _twitch_t := 3.0
var _stuck_t := 0.0
var _stuck_best := INF
## Flyers: where it circles (angle around the target, direction) and the spot
## the current dive is aimed at.
var _orbit_angle := 0.0
var _orbit_dir := 1.0
var _dive_to := Vector2.ZERO


## Convenience constructor for level builders.
static func create(enemy_data: EnemyData, at: Vector2) -> Enemy:
	var e := Enemy.new()
	e.data = enemy_data
	e.position = at
	return e


func _ready() -> void:
	# Readable name (HdView names its 3D sprite after it); auto names start with @.
	if String(name).begins_with("@"):
		name = "Enemy"
	add_to_group("enemy")
	add_to_group("hd_actor")
	home = global_position
	collision_layer = 8  # layer 4 "enemies"
	collision_mask = 1 | 2 | 4 | 8  # world, kid, dog, other enemies
	if data.flies:
		collision_mask = 0  # flies over fences, props and the party
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build()
	_base_offset = _sprite.offset
	_sprite.play(&"idle", Vector2.DOWN)
	if data.flies:
		height = data.fly_height
		_apply_height()


func _build() -> void:
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = data.body_size
	col.shape = shape
	col.position = Vector2(0, -data.body_size.y * 0.5)
	add_child(col)

	health = Health.new()
	health.name = "Health"
	health.max_hp = Difficulty.enemy_hp(data.hp)
	health.armor = Difficulty.enemy_armor(data.armor)
	health.invuln_seconds = 0.15
	add_child(health)
	health.died.connect(_on_died)

	var hb := Hurtbox.new()
	hb.name = "Hurtbox"
	hb.team = "enemy"
	hb.radius = data.hurt_radius
	hb.position = Vector2(0, -data.paws_y * 0.25)
	add_child(hb)

	_sprite = AnimalSprite.new()
	_sprite.name = "Sprite"
	_sprite.texture = data.sheet
	_sprite.shadow_texture = data.shadow_sheet
	_sprite.frame_px = data.frame_px
	_sprite.paws_y = data.paws_y
	_sprite.anims_override = data.anims
	_sprite.autoplay = &""
	add_child(_sprite)
	_sprite.animation_finished.connect(_on_animation_finished)

	# Behind the body, additive: a soft warm halo the dog "smells" at night.
	_scent_glow = Sprite2D.new()
	_scent_glow.name = "ScentGlow"
	_scent_glow.texture = GLOW_DOT
	_scent_glow.scale = Vector2(5.0, 3.0)
	_scent_glow.position = Vector2(0, -data.paws_y * 0.2)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_scent_glow.material = add
	_scent_glow.visible = false
	add_child(_scent_glow)
	move_child(_scent_glow, _sprite.get_index())  # drawn before (under) the body


## Should enemies glow for the dog's nose right now? At night, while the
## player drives the dog. Off by day and while driving the kid.
static func scent_wanted() -> bool:
	return Clock.is_night() and Party.leader is Dog


func _update_scent(delta: float) -> void:
	var want := 1.0 if scent_wanted() and state != State.DEAD and state != State.ROOST else 0.0
	scent = move_toward(scent, want, SCENT_FADE * delta)
	_scent_glow.visible = scent > 0.0
	_scent_glow.modulate = Color(SCENT_COLOR, 0.7 * scent)


func _physics_process(delta: float) -> void:
	_update_scent(delta)
	_age += delta
	combat_timer = maxf(combat_timer - delta, 0.0)
	_update_height(delta)
	if state == State.DEAD:
		return
	_timer -= delta
	match state:
		State.ENTER:
			_process_enter(delta)
			return
		State.LEAVE:
			_process_leave(delta)
			move_and_slide()
			return
		State.ROOST:
			_process_roost(delta)
			return
		State.IDLE:
			if data.flies:
				_flutter(delta)
			else:
				_brake(delta)
			target = _nearest_target(data.aggro_radius)
			if target:
				state = State.CHASE
				combat_timer = COMBAT_MEMORY
				if data.flies:
					_begin_circling()
		State.CHASE:
			if not _valid_target() or home.distance_to(target.global_position) > data.leash_radius:
				state = State.RETURN
			elif data.flies:
				_fly_chase(delta)
			elif global_position.distance_to(target.global_position) <= data.attack_range and _timer <= 0.0:
				_start_windup()
			else:
				_move_toward(target.global_position, data.chase_speed, delta)
				_sprite.play(&"walk", velocity)
				combat_timer = maxf(combat_timer, 1.0)
		State.WINDUP:
			_brake(delta)
			# Telegraph: pulse bright so the player can see it coming.
			_sprite.modulate = FLASH if int(_timer * 12.0) % 2 == 0 else Color.WHITE
			if _timer <= 0.0:
				_start_attack()
		State.ATTACK:
			if data.flies:
				_dive(delta)
				move_and_slide()
				return
			velocity = velocity.move_toward(Vector2.ZERO, ACCEL * 0.5 * delta)
			if not _landed and _sprite.frame_index() >= data.attack_hit_frame:
				_land_attack()
		State.RECOVER:
			if data.flies and _valid_target():
				_orbit(delta, RETREAT_FACTOR)  # climbs away, then circles
			else:
				_brake(delta)
			if _timer <= 0.0:
				state = State.CHASE if _valid_target() else State.IDLE
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
			if _timer <= 0.0:
				state = State.CHASE if _valid_target() else State.IDLE
		State.RETURN:
			target = null
			if global_position.distance_to(home) < 6.0:
				health.heal(health.max_hp)
				state = State.IDLE
				_sprite.play(&"idle", Vector2.ZERO)
			else:
				_move_toward(home, data.walk_speed, delta)
				_sprite.play(&"walk", velocity)
	move_and_slide()


## Called by its Hurtbox when a hit lands.
func on_hit(info: HitInfo, _dealt: int) -> void:
	if state == State.DEAD:
		return
	velocity = info.knockback * data.knockback_taken
	combat_timer = COMBAT_MEMORY
	_sprite.modulate = Color(1.0, 0.5, 0.5)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	if info.source is Node2D and not health.is_dead():
		target = info.source  # whoever hit it gets its attention
		_sound(data.sound_hurt)
	if data.flies:
		_timer = maxf(_timer, 0.8)  # a hit bat backs off a moment before it dives again
	state = State.HURT
	_timer = maxf(info.stagger, 0.12)


## Awake and fighting (the AI partner only goes after these). Hanging, entering
## and leaving enemies are not part of a fight.
func is_active() -> bool:
	return not (state in [State.IDLE, State.DEAD, State.ENTER, State.LEAVE, State.ROOST])


## Fighting, or was a moment ago: the day/night swap leaves it alone.
func in_combat() -> bool:
	if state == State.DEAD:
		return false
	return combat_timer > 0.0 or state in [State.CHASE, State.WINDUP, State.ATTACK, State.RECOVER, State.HURT]


# -----------------------------------------------------------------------------
# Day and night: entrances, exits, roosting (driven by DayNightDirector)
# -----------------------------------------------------------------------------
## A visible entrance: "drop" (from the tree), "rise" (out of the ground, dirt
## flying), "burrow" (squeezes out of the hole), "fade" (poof, magic types).
## It can't be hit until it has finished.
func begin_entrance(how: String) -> void:
	entrance = how
	state = State.ENTER
	_enter_t = 0.0
	_set_hittable(false)
	velocity = Vector2.ZERO
	match how:
		"drop":
			height = data.hang_height if data.roosts else 70.0
			_sprite.play(&"walk", Vector2.DOWN)
			if data.roosts:
				# Out of the canopy: it shows up inside the leaves, which shake.
				_sprite.visible = true
				Fx.leaves(global_position, data.hang_height)
				var out := Vector2.from_angle(randf() * TAU)
				velocity = out * data.walk_speed
				_sprite.play(&"walk", out)
		"rise":
			Fx.dirt(global_position, 10)
			if data.anims.has(&"rise"):
				_sprite.play(&"rise", Vector2.DOWN, true)  # pushed up out of the ground, frame by frame
			else:
				_sprite.play(&"idle", Vector2.DOWN)
		"burrow":
			Fx.dirt(global_position + Vector2(0, 2))
			_sprite.play(&"walk", Vector2.DOWN)
		_:
			_sprite.play(&"idle", Vector2.DOWN)
	_set_entrance_look(0.0)


func _set_entrance_look(k: float) -> void:
	var up := Vector2.ZERO
	var a := 1.0
	match entrance:
		"rise":
			if not data.anims.has(&"rise"):
				up.y = (1.0 - k) * 16.0  # starts buried
				a = clampf(k * 2.5, 0.0, 1.0)  # (a sheet with a rise anim draws it itself)
		"drop":
			if data.roosts:
				a = clampf(k * 5.0, 0.0, 1.0)  # fades in among the leaves
		"burrow":
			up.y = (1.0 - k) * 10.0
			a = clampf(k * 3.0, 0.0, 1.0)
		"fade":
			a = k
	_sprite.offset = _base_offset + up + Vector2(0, -height)
	_sprite.modulate = Color(1, 1, 1, a)


func _process_enter(delta: float) -> void:
	_enter_t += delta
	var dur: float = ENTER_SECONDS.get(entrance, 0.8)
	var k := clampf(_enter_t / dur, 0.0, 1.0)
	if entrance == "drop":
		# Falls (fast at first, then catches itself with a flap).
		var to_h := data.fly_height if data.flies else 0.0
		var start_h := data.hang_height if data.roosts else 70.0
		height = lerpf(start_h, to_h, 1.0 - pow(1.0 - k, 2.0))
		if data.roosts:
			velocity = velocity.move_toward(Vector2.ZERO, 30.0 * delta)
			move_and_slide()  # drifts out from the tree as it falls and catches itself
	elif entrance == "burrow":
		velocity = Vector2(0, 12.0 * (1.0 - k))  # slips out toward the viewer
		move_and_slide()
	elif entrance == "rise" and _enter_t - delta < dur * 0.5 and _enter_t >= dur * 0.5:
		Fx.dirt(global_position, 6)  # a second shower as the shoulders clear
	_set_entrance_look(k)
	if k >= 1.0:
		entrance = ""
		_sprite.modulate = Color.WHITE
		_set_hittable(true)
		state = State.IDLE
		home = global_position
		_sprite.offset = _base_offset + Vector2(0, -height)
		entered.emit(self)


## Its time is over: go to `point` the way `kind` says ("burrow", "edge",
## "roost" or "fade"). The director removes it once out of view.
func begin_leave(kind: String, point: Vector2) -> void:
	state = State.LEAVE
	leave_kind = kind
	leave_point = point
	leave_done = false
	leave_failed = false
	target = null
	_sink_t = 0.0
	_stuck_t = 0.0
	_stuck_best = INF
	_set_hittable(true)
	_sprite.modulate = Color.WHITE
	if kind == "fade":
		_sprite.play(&"idle", Vector2.ZERO)
	elif kind == "sink":
		# Back into the ground where it stands (the rise played backwards).
		velocity = Vector2.ZERO
		_set_hittable(false)
		Fx.dirt(global_position, 8)
		_sprite.play(&"sink" if data.anims.has(&"sink") else &"idle", Vector2.DOWN, true)


## Its time came back before it got away: carry on as usual.
func cancel_leave() -> void:
	if state != State.LEAVE:
		return
	state = State.IDLE
	if leave_kind == "sink":
		_set_hittable(true)
		_sprite.play(&"idle", Vector2.DOWN, true)
	leave_kind = ""
	_sprite.modulate = Color.WHITE
	_sprite.offset = _base_offset + Vector2(0, -height)


func is_leaving() -> bool:
	return state == State.LEAVE


func _process_leave(delta: float) -> void:
	if leave_kind == "fade":
		_brake(delta)
		_sink_t += delta
		_sprite.modulate = Color(1, 1, 1, clampf(1.0 - _sink_t / 0.9, 0.0, 1.0))
		leave_done = _sink_t >= 0.9
		return
	if leave_kind == "sink":
		_brake(delta)
		_sink_t += delta
		leave_done = _sink_t >= ENTER_SECONDS["rise"]
		return
	var to := leave_point - global_position
	var arrived := to.length() < ARRIVE_PX
	if arrived and leave_kind == "burrow":
		_brake(delta)
		_sink_t += delta
		var k := clampf(_sink_t / SINK_SECONDS, 0.0, 1.0)
		_sprite.offset = _base_offset + Vector2(0, k * 12.0)
		_sprite.modulate = Color(1, 1, 1, 1.0 - k)
		leave_done = k >= 1.0
		return
	if arrived and leave_kind == "roost":
		_enter_roost()
		return
	var speed := (data.chase_speed * 0.7) if data.flies else (data.walk_speed * 1.8)
	_move_toward(leave_point, speed, delta)
	_sprite.play(&"walk", velocity)
	if leave_kind == "roost":
		# Flies into the leaves and is gone: fades out over the last stretch.
		_sprite.modulate = Color(1, 1, 1, clampf((to.length() - 6.0) / 50.0, 0.0, 1.0))
	# Stuck behind a wall? Report it instead of pushing forever.
	_stuck_t += delta
	if _stuck_t >= 2.5:
		var d := to.length()
		leave_failed = d > _stuck_best - 6.0 and not arrived
		_stuck_best = d
		_stuck_t = 0.0


## Hang upside down in the tree (a bat by day).
func _enter_roost() -> void:
	state = State.ROOST
	velocity = Vector2.ZERO
	_set_hittable(false)
	combat_timer = 0.0
	target = null
	_twitch_t = randf_range(3.0, 8.0)
	_sprite.modulate = Color.WHITE
	# By day a bat is not seen at all: it is up in the leaves (owner, 2026-10-09).
	if _sprite.visible:
		Fx.leaves(global_position, data.hang_height)
	_sprite.visible = false


## Already hanging (a realm that loads by day).
func start_roosting() -> void:
	_sprite.visible = false  # a scene that loads by day shows no hanging bat
	height = data.hang_height
	_enter_roost()
	_apply_height()


func _process_roost(delta: float) -> void:
	velocity = Vector2.ZERO
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(4.0, 9.0)
		twitch()  # unseen: only a faint rustle, now and then


## A small shiver of the wings (hanging bats now and then, and as the cue
## that dusk is waking them).
func twitch() -> void:
	if state == State.ROOST and data.roosts:
		Fx.leaves(global_position, data.hang_height)  # the canopy shivers, nothing shows
	elif state == State.ROOST and data.anims.has(&"twitch"):
		_sprite.play(&"twitch", Vector2.ZERO, true)


## The warning a second before a visible entrance or an exit from the tree.
func play_cue() -> void:
	_sound(data.sound_cue)
	twitch()


## Wake from the roost: the same drop as an arriving bat.
func drop_from_roost() -> void:
	if state == State.ROOST:
		begin_entrance("drop")


func _set_hittable(on: bool) -> void:
	var hb := get_node_or_null("Hurtbox")
	if hb == null:
		return
	if on and not hb.is_in_group("hurtbox"):
		hb.add_to_group("hurtbox")
	elif not on and hb.is_in_group("hurtbox"):
		hb.remove_from_group("hurtbox")


## Flyers settle toward their flying height (hanging when roosting, 0 when
## dead, low in a swoop). Everything else has height 0.
func _update_height(delta: float) -> void:
	if not data.flies or state == State.ENTER:
		return
	if state == State.LEAVE and leave_kind == "burrow":
		return
	var want := data.fly_height + sin(_age * 3.0) * 2.5
	match state:
		State.ROOST:
			want = data.hang_height
		State.DEAD:
			want = 0.0
		State.ATTACK, State.WINDUP:
			want = 4.0
		State.LEAVE:
			if leave_kind == "roost" and global_position.distance_to(leave_point) < 60.0:
				want = data.hang_height
	height = move_toward(height, want, HEIGHT_SPEED * delta)
	_apply_height()


func _apply_height() -> void:
	if _sprite == null:
		return
	_sprite.offset = _base_offset + Vector2(0, -height)
	var hb := get_node_or_null("Hurtbox") as Node2D
	if hb:
		hb.position = Vector2(0, -data.paws_y * 0.25 - height * 0.6)


## Idle flight: drifts between random spots near home.
func _flutter(delta: float) -> void:
	_flutter_t -= delta
	if _flutter_t <= 0.0 or global_position.distance_to(_flutter_to) < 6.0:
		_flutter_t = randf_range(0.8, 2.0)
		_flutter_to = home + Vector2(randf_range(-80, 80), randf_range(-50, 50))
	_move_toward(_flutter_to, data.walk_speed, delta, FLY_ACCEL)
	_sprite.play(&"walk", velocity)


## A flyer that just noticed someone: starts circling where it is, the first
## swoop a moment away. Each bat circles its own way round.
func _begin_circling() -> void:
	_orbit_angle = (global_position - target.global_position).angle()
	_orbit_dir = 1.0 if get_instance_id() % 2 == 0 else -1.0
	_timer = FIRST_SWOOP_DELAY


## Circle the target at orbit_radius (a slow wobble in the radius, not a
## jitter): steer toward a point that moves round the target, easing off as it
## nears it.
func _orbit(delta: float, radius_factor := 1.0) -> void:
	_orbit_angle += _orbit_dir * ORBIT_SPEED * delta
	var wobble := sin(_age * 1.3 + float(get_instance_id() % 7)) * 8.0
	var r := data.orbit_radius * radius_factor + wobble
	var want := target.global_position + Vector2.from_angle(_orbit_angle) * r
	var speed := minf(data.chase_speed, global_position.distance_to(want) * 3.0 + 20.0)
	_move_toward(want, speed, delta, FLY_ACCEL)
	_sprite.play(&"walk", velocity)


func _fly_chase(delta: float) -> void:
	combat_timer = maxf(combat_timer, 1.0)
	_orbit(delta)
	if _timer <= 0.0 and global_position.distance_to(target.global_position) <= data.orbit_radius * 1.6:
		_start_windup()


## The dive: straight at the locked spot, the bite lands when it gets there
## (or flies past it), then it retreats.
func _dive(_delta: float) -> void:
	velocity = _attack_dir * data.swoop_speed
	var to := _dive_to - global_position
	if to.length() <= data.attack_reach * 0.6 or to.dot(_attack_dir) <= 0.0:
		_land_attack()
		state = State.RECOVER
		_timer = data.attack_cooldown
		if _valid_target():
			_orbit_angle = (global_position - target.global_position).angle()
		_sprite.play(&"walk", -_attack_dir)


func _start_windup() -> void:
	state = State.WINDUP
	_sound(data.sound_windup)
	_timer = data.windup_seconds
	_attack_dir = global_position.direction_to(target.global_position)
	_dive_to = target.global_position  # flyers: aimed now, so moving away dodges it
	_sprite.play(&"idle", _attack_dir)


func _start_attack() -> void:
	state = State.ATTACK
	_landed = false
	_sprite.modulate = Color.WHITE
	if data.flies:
		_attack_dir = global_position.direction_to(_dive_to)
	elif _valid_target():
		_attack_dir = global_position.direction_to(target.global_position)
	velocity = _attack_dir * (data.swoop_speed if data.flies else data.chase_speed * 1.6)  # the lunge
	_sprite.play(&"attack", _attack_dir, true)


func _land_attack() -> void:
	_landed = true
	_sound(data.sound_attack)
	var dmg := Difficulty.enemy_damage(data.damage)
	Combat.strike(get_tree(), global_position + Vector2(0, -6), _attack_dir, data.attack_reach,
			data.attack_arc, "enemy", func(hb: Hurtbox) -> HitInfo: return _make_hit(hb, dmg), 1)


func _make_hit(hb: Hurtbox, dmg: float) -> HitInfo:
	var info := HitInfo.make(dmg, global_position, hb.global_position, data.knockback_dealt, "enemy", self)
	info.stagger = data.stagger_dealt
	return info


func _on_animation_finished(anim: StringName) -> void:
	match anim:
		&"attack":
			if state == State.ATTACK and not data.flies:  # a dive ends on arrival
				state = State.RECOVER
				_timer = data.attack_cooldown
		&"die":
			_vanish()


func _on_died() -> void:
	state = State.DEAD
	_sound(data.sound_death)
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	$Hurtbox.remove_from_group("hurtbox")
	_sprite.modulate = Color.WHITE
	_sprite.play(&"die", Vector2.ZERO, true)
	died.emit(self)


func _sound(sound_name: String) -> void:
	if sound_name != "":
		Audio.play_at(sound_name, global_position)


## Blink a few times, then go.
func _vanish() -> void:
	for i in 6:
		_sprite.visible = i % 2 == 1
		await get_tree().create_timer(0.08).timeout
	queue_free()


func _nearest_target(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d := radius
	for m in Party.members():
		if Party.is_down(m):
			continue
		var d := global_position.distance_to(m.global_position)
		if d <= best_d:
			best_d = d
			best = m
	return best


func _valid_target() -> bool:
	return is_instance_valid(target) and not Party.is_down(target)


func _move_toward(p: Vector2, speed: float, delta: float, accel := ACCEL) -> void:
	velocity = velocity.move_toward(global_position.direction_to(p) * speed, accel * delta)


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
