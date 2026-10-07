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
#        Stats come from the EnemyData scaled by Difficulty (Hard: more HP and
#        armor, harder hits).
# PLACE: Enemy.create(data, position), or an AsciiRealm's ENEMIES_BY_CHAR.
# HD-2D: in group "hd_actor" (the flash and blink mirror through modulate).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, HURT, RETURN, DEAD }

const ACCEL := 900.0
## The telegraph: an orange warning pulse (the hit flash is red). Kept at or
## below 1.0 on purpose: brighter-than-white sprites trip HD-2D's bloom under a
## strong sun and halo everything nearby, the kid included.
const FLASH := Color(1.0, 0.68, 0.22)

@export var data: EnemyData

var state: State = State.IDLE
var home := Vector2.ZERO
var target: Node2D
var health: Health

var _sprite: AnimalSprite
var _timer := 0.0
var _attack_dir := Vector2.DOWN
var _landed := false


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
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_build()
	_sprite.play(&"idle", Vector2.DOWN)


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


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_timer -= delta
	match state:
		State.IDLE:
			_brake(delta)
			target = _nearest_target(data.aggro_radius)
			if target:
				state = State.CHASE
		State.CHASE:
			if not _valid_target() or home.distance_to(target.global_position) > data.leash_radius:
				state = State.RETURN
			elif global_position.distance_to(target.global_position) <= data.attack_range and _timer <= 0.0:
				_start_windup()
			else:
				_move_toward(target.global_position, data.chase_speed, delta)
				_sprite.play(&"walk", velocity)
		State.WINDUP:
			_brake(delta)
			# Telegraph: pulse bright so the player can see it coming.
			_sprite.modulate = FLASH if int(_timer * 12.0) % 2 == 0 else Color.WHITE
			if _timer <= 0.0:
				_start_attack()
		State.ATTACK:
			velocity = velocity.move_toward(Vector2.ZERO, ACCEL * 0.5 * delta)
			if not _landed and _sprite.frame_index() >= data.attack_hit_frame:
				_land_attack()
		State.RECOVER:
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
	_sprite.modulate = Color(1.0, 0.5, 0.5)
	create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.2)
	if info.source is Node2D and not health.is_dead():
		target = info.source  # whoever hit it gets its attention
	state = State.HURT
	_timer = maxf(info.stagger, 0.12)


func is_active() -> bool:
	return state != State.IDLE and state != State.DEAD


func _start_windup() -> void:
	state = State.WINDUP
	_timer = data.windup_seconds
	_attack_dir = global_position.direction_to(target.global_position)
	_sprite.play(&"idle", _attack_dir)


func _start_attack() -> void:
	state = State.ATTACK
	_landed = false
	_sprite.modulate = Color.WHITE
	if _valid_target():
		_attack_dir = global_position.direction_to(target.global_position)
	velocity = _attack_dir * data.chase_speed * 1.6  # the lunge
	_sprite.play(&"attack", _attack_dir, true)


func _land_attack() -> void:
	_landed = true
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
			if state == State.ATTACK:
				state = State.RECOVER
				_timer = data.attack_cooldown
		&"die":
			_vanish()


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	$Hurtbox.remove_from_group("hurtbox")
	_sprite.modulate = Color.WHITE
	_sprite.play(&"die", Vector2.ZERO, true)
	died.emit(self)


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


func _move_toward(p: Vector2, speed: float, delta: float) -> void:
	velocity = velocity.move_toward(global_position.direction_to(p) * speed, ACCEL * delta)


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, ACCEL * delta)
