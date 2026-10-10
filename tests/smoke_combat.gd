# =============================================================================
# smoke_combat.gd  -  Headless checks for combat (phase A)
# -----------------------------------------------------------------------------
# WHAT:  1. ChargeMeter: fills by itself (no button), stops at the weapon's
#           level, x1/x2/x4 at levels 1/2/3, a hurried swing still does some
#           damage, spending starts it over
#        2. Health: armor math, invulnerability window, death signal, revive
#        3. Difficulty: Hard scales enemy HP, armor, damage and prices
#        4. The kid's swing: hits a rat in front, never one behind, damage =
#           weapon x charge, knockback pushes it away, a level-3 swing does 4x
#        5. Enemies: wake by distance (not by screen), chase, telegraph, hit the
#           kid, and die (removed from play); hits never hurt their own team
#        5b. Bats (owner: "fly around crazy, never attacked"): a bat circles a
#           still kid smoothly at a distance, telegraphs (WINDUP) before it
#           dives, the dive bites for 3, it climbs away and rests, then comes
#           again; moving away during the telegraph dodges it; the kid's swing
#           and the dog's leap reach a bat at the bottom of its dive, a bat
#           circling high is out of reach and the AI partner ignores it
#           until it dives
#        6. Talking wins over attacking on the shared button
#        7. HD-2D: rats are mirrored in 3D, and effects land at the same screen
#           spot in both views
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_combat.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA := "res://realms/test/combat_arena.tscn"
const ARENA_HD := "res://realms/test/combat_arena_hd.tscn"
const RAT := preload("res://data/enemies/rat.tres")
const STICK := preload("res://data/weapons/stick.tres")
const BAT := preload("res://data/enemies/bat.tres")
const SKELETON := preload("res://data/enemies/skeleton.tres")

## Circling bats may accelerate this fast at most (px/s^2); the old weave
## piled velocity on every frame (thousands).
const FLY_ACCEL_LIMIT := 400.0

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_charge_meter()
	_test_health()
	_test_difficulty()
	await _test_swing()
	await _test_enemy_behavior()
	await _test_skeleton()
	await _test_bat()
	await _test_talk_beats_attack()
	await _test_hd()
	GameState.difficulty = "normal"
	if _failures.is_empty():
		print("[TEST] PASS  smoke_combat")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_charge_meter() -> void:
	var m := ChargeMeter.new(3, 1.0)
	_check(m.level() == 1 and is_equal_approx(m.multiplier(), 1.0), "a fresh meter starts full at level 1")
	var spent := m.spend()
	_check(is_equal_approx(spent[0], 1.0) and spent[1] == 1, "spending a full meter: x1 at level 1, got %s" % [spent])
	_check(m.value == 0.0, "spending starts the meter over")
	_check(is_equal_approx(m.multiplier(), 0.25), "an instant second swing still does 25%%, got %.2f" % m.multiplier())
	m.tick(0.5)
	_check(m.level() == 0 and is_equal_approx(m.multiplier(), 0.625), "half-charged: 62.5%%, got %.3f" % m.multiplier())
	m.tick(0.5)
	_check(m.level() == 1, "fills to level 1 by itself in seconds_per_level")
	m.tick(1.0)
	_check(m.level() == 2 and is_equal_approx(m.multiplier(), 2.0), "level 2 = x2, got %.1f" % m.multiplier())
	m.tick(1.0)
	_check(m.level() == 3 and is_equal_approx(m.multiplier(), 4.0), "level 3 = x4, got %.1f" % m.multiplier())
	m.tick(10.0)
	_check(m.level() == 3, "never fills past the weapon's max level")
	var low := ChargeMeter.new(1, 1.0)
	low.tick(10.0)
	_check(low.level() == 1, "a level-1 weapon stops at level 1")


func _test_health() -> void:
	var h := Health.new()
	h.max_hp = 30
	h.armor = 100.0
	h.invuln_seconds = 0.5
	add_child(h)
	var died := [false]
	h.died.connect(func() -> void: died[0] = true)
	var info := HitInfo.new()
	info.damage = 10.0
	info.team = "enemy"
	_check(h.take_hit(info) == 5, "100 armor halves damage (10 -> 5)")
	_check(h.take_hit(info) == 0, "invulnerable right after a hit")
	h._invuln = 0.0
	info.damage = 0.4
	_check(h.take_hit(info) == 1, "a hit always does at least 1")
	h._invuln = 0.0
	info.damage = 999.0
	h.take_hit(info)
	_check(h.is_dead() and died[0], "dies at 0 HP and says so")
	h.revive(0.3)
	_check(h.hp == 9 and not h.is_dead(), "revive with 30%% (9 of 30), got %d" % h.hp)
	h.queue_free()


func _test_difficulty() -> void:
	GameState.difficulty = "normal"
	var hp_n := Difficulty.enemy_hp(20)
	var dmg_n := Difficulty.enemy_damage(5.0)
	var price_n := Difficulty.price(100)
	GameState.difficulty = "hard"
	_check(Difficulty.enemy_hp(20) > hp_n, "Hard: more enemy HP (%d vs %d)" % [Difficulty.enemy_hp(20), hp_n])
	_check(Difficulty.enemy_damage(5.0) > dmg_n, "Hard: enemies hit harder")
	_check(Difficulty.enemy_armor(10.0) > 10.0, "Hard: more enemy armor")
	_check(Difficulty.price(100) > price_n, "Hard: things cost more (%d vs %d)" % [Difficulty.price(100), price_n])
	GameState.difficulty = "normal"


# -----------------------------------------------------------------------------
func _test_swing() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	# Only the kid's swing here: the dog (Offensive) would join in.
	arena.get_node("World/Dog").set_physics_process(false)
	_clear_enemies()
	var front := _add_rat(arena, kid.global_position + Vector2(0, 24))
	var behind := _add_rat(arena, kid.global_position + Vector2(0, -26))
	await _frames(2)
	front.set_physics_process(false)
	behind.set_physics_process(false)
	kid.facing = Vector2.DOWN
	kid.charge.value = 1.0
	var hp_front := front.health.hp
	var hp_behind := behind.health.hp
	var front_pos := front.global_position
	_check(kid.attack(), "the kid should be able to swing")
	await _wait(0.6)
	var dealt := hp_front - front.health.hp
	_check(dealt == roundi(STICK.damage), "a level-1 swing does the stick's damage (%d), did %d" % [roundi(STICK.damage), dealt])
	_check(behind.health.hp == hp_behind, "a rat behind the kid must not be hit")
	front.move_and_slide()
	_check(front.velocity.y > 0.0 or front.global_position.y > front_pos.y, "knockback should push the rat away from the kid")
	_check(Engine.time_scale == 1.0, "hit-stop must end (time scale %.2f)" % Engine.time_scale)

	# A full level-3 swing does 4x.
	front.health.reset(100)
	front.health._invuln = 0.0
	kid.charge.value = 3.0
	await _frames(2)
	kid.attack()
	await _wait(0.6)
	_check(100 - front.health.hp == roundi(STICK.damage * 4.0), "a level-3 swing does 4x (%d), did %d" % [roundi(STICK.damage * 4.0), 100 - front.health.hp])
	arena.queue_free()
	await _frames(2)


func _test_enemy_behavior() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	# Far away: stays asleep, even though a wide screen could show it.
	var far := _add_rat(arena, kid.global_position + Vector2(RAT.aggro_radius + 120, 0))
	var near := _add_rat(arena, kid.global_position + Vector2(RAT.aggro_radius - 30, 0))
	dog.global_position = kid.global_position + Vector2(-60, 0)
	dog.set_physics_process(false)
	kid.set_physics_process(false)
	await _wait(0.3)
	_check(far.state == Enemy.State.IDLE, "a rat beyond aggro range stays asleep (state %s)" % far.state)
	_check(near.is_active(), "a rat within aggro range wakes up")
	var kid_hp := kid.health.hp
	var saw_windup := [false]
	for i in 240:
		await get_tree().physics_frame
		if near.state == Enemy.State.WINDUP:
			saw_windup[0] = true
		if kid.health.hp < kid_hp:
			break
	_check(saw_windup[0], "the rat should telegraph (WINDUP) before it bites")
	_check(kid.health.hp < kid_hp, "the rat should reach and bite the kid")
	_check(kid.health.hp >= kid_hp - roundi(RAT.damage), "one bite = the rat's damage at most")

	# Enemies never hurt each other.
	var hp_far := far.health.hp
	var info := HitInfo.make(50.0, near.global_position, far.global_position, 0.0, "enemy", near)
	far.get_node("Hurtbox").receive(info)
	_check(far.health.hp == hp_far, "an enemy hit must not hurt another enemy")

	# Death: removed from play.
	var hurt := HitInfo.make(999.0, kid.global_position, near.global_position, 0.0, "player", kid)
	near.get_node("Hurtbox").receive(hurt)
	_check(near.state == Enemy.State.DEAD, "a rat at 0 HP dies")
	await _wait(2.0)
	_check(not is_instance_valid(near), "a dead rat is removed after its death animation")
	arena.queue_free()
	await _frames(2)


func _test_skeleton() -> void:
	# The night enemy: slower and tougher than a rat, a longer telegraph, a swing
	# (slash anim) that lands on its hit frame, and a crumble when it dies.
	_check(SKELETON.hp > RAT.hp and SKELETON.chase_speed < RAT.chase_speed and SKELETON.windup_seconds > RAT.windup_seconds,
			"a skeleton is slower, tougher and telegraphs longer than a rat")
	_check(SKELETON.active == "night" and SKELETON.arrives_by == "rise" and SKELETON.leaves_by == "sink",
			"it comes out at night, rising from the ground and sinking back")
	for a in [&"idle", &"walk", &"attack", &"die", &"rise", &"sink"]:
		_check(SKELETON.anims.has(a), "the skeleton has a '%s' animation" % a)
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	dog.global_position = kid.global_position + Vector2(-60, 0)
	dog.set_physics_process(false)
	kid.set_physics_process(false)
	var sk := Enemy.create(SKELETON, kid.global_position + Vector2(SKELETON.aggro_radius - 30, 0))
	arena.get_node("World").add_child(sk)
	await _wait(0.3)
	_check(sk.is_active(), "a skeleton within aggro range wakes up")
	var kid_hp := kid.health.hp
	var saw_windup := false
	var saw_swing := false
	for i in 60 * 6:
		await get_tree().physics_frame
		saw_windup = saw_windup or sk.state == Enemy.State.WINDUP
		saw_swing = saw_swing or (sk.state == Enemy.State.ATTACK and sk._sprite.current == &"attack")
		if kid.health.hp < kid_hp:
			break
	_check(saw_windup, "the skeleton telegraphs (WINDUP) before its swing")
	_check(saw_swing, "its swing plays the attack animation")
	_check(kid.health.hp < kid_hp and kid.health.hp >= kid_hp - roundi(SKELETON.damage), "the swing hurts the kid for its damage at most")
	sk.get_node("Hurtbox").receive(HitInfo.make(999.0, kid.global_position, sk.global_position, 0.0, "player", kid))
	_check(sk.state == Enemy.State.DEAD and sk._sprite.current == &"die", "a skeleton at 0 HP crumbles (die animation)")
	await _wait(2.5)
	_check(not is_instance_valid(sk), "and is removed afterwards")
	arena.queue_free()
	await _frames(2)


func _test_bat() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	Clock.hold("night", 0.0)
	dog.set_physics_process(false)
	kid.set_physics_process(false)
	dog.global_position = kid.global_position + Vector2(-300, 0)
	kid.health.max_hp = 999
	kid.health.hp = 999
	var bat := Enemy.create(BAT, kid.global_position + Vector2(100, -30))
	arena.get_node("World").add_child(bat)

	# A still kid: circle, telegraph, dive, bite, retreat, again.
	var hp0: int = kid.health.hp
	var order: Array = []
	var t_bite := -1.0
	var t_windup := -1.0
	var h_circle := 0.0
	var h_bite := 99.0
	var max_dv := 0.0
	var prev_v := Vector2.ZERO
	var d_after := 0.0
	var swing_ok := false
	var swing_high_ok := true
	var dog_ok := false
	var second_bite := false
	var last_state := -1
	for i in 60 * 9:
		await get_tree().physics_frame
		var t := i / 60.0
		if bat.state != last_state:
			order.append(bat.state)
			last_state = bat.state
		if bat.state == Enemy.State.CHASE:
			max_dv = maxf(max_dv, (bat.velocity - prev_v).length() * 60.0)
			h_circle = maxf(h_circle, bat.height)
			# hovering at its circle distance, a stick can't reach it
			var origin := kid.global_position + Vector2(0, -6)
			var dir := (bat.global_position - kid.global_position).normalized()
			if bat.global_position.distance_to(kid.global_position) > 55.0:
				if Combat.hits_in_arc(get_tree(), origin, dir, STICK.reach, STICK.arc_deg, "player").has(bat.get_node("Hurtbox")):
					swing_high_ok = false
		prev_v = bat.velocity
		if bat.state == Enemy.State.WINDUP and t_windup < 0.0:
			t_windup = t
		if bat.state == Enemy.State.ATTACK and not swing_ok:
			# the bottom of the dive: right on the kid, low
			if bat.global_position.distance_to(kid.global_position) < 24.0:
				var origin := kid.global_position + Vector2(0, -6)
				var dir := (bat.global_position - kid.global_position).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.DOWN
				swing_ok = Combat.hits_in_arc(get_tree(), origin, dir, STICK.reach, STICK.arc_deg, "player").has(bat.get_node("Hurtbox"))
				# the dog, standing a step off, leaps and his teeth reach it
				dog.global_position = bat.global_position + Vector2(-34, 0)
				dog.facing = Vector2.RIGHT
				var leap := dog._pick_leap_target()
				var jaws := dog.global_position + Vector2(0, -6) + dog.facing * (leap + dog.jaw_reach)
				dog_ok = Combat.hits_in_arc(get_tree(), jaws, dog.facing, dog.weapon.reach * 0.5, 360.0, "player").has(bat.get_node("Hurtbox"))
				dog.global_position = kid.global_position + Vector2(-300, 0)
		if kid.health.hp < hp0:
			if t_bite < 0.0:
				t_bite = t
				h_bite = bat.height
				_check(hp0 - kid.health.hp == roundi(BAT.damage), "one bite = 3, took %d" % (hp0 - kid.health.hp))
				d_after = 0.0
			else:
				second_bite = true
			hp0 = kid.health.hp
		if t_bite >= 0.0 and not second_bite:
			d_after = maxf(d_after, bat.global_position.distance_to(kid.global_position))
	_check(t_bite > 0.0 and t_bite < 6.0, "a still kid gets bitten within 6 s (first bite at %.1f s)" % t_bite)
	_check(t_windup > 0.0 and t_windup < t_bite, "the bat telegraphs (WINDUP at %.1f s) before the bite (%.1f s)" % [t_windup, t_bite])
	var wi := order.find(Enemy.State.WINDUP)
	_check(wi > 0 and order.slice(wi, wi + 3) == [Enemy.State.WINDUP, Enemy.State.ATTACK, Enemy.State.RECOVER],
			"the sequence is telegraph, dive, retreat: %s" % [order])
	_check(d_after > 70.0, "after the bite it pulls away (reached %.0f px)" % d_after)
	_check(second_bite, "and comes back for another dive")
	_check(h_circle > 14.0 and h_bite < 8.0, "high while circling (%.1f), low at the bite (%.1f)" % [h_circle, h_bite])
	_check(max_dv < FLY_ACCEL_LIMIT, "circling is smooth: peak acceleration %.0f px/s^2" % max_dv)
	_check(swing_ok, "the kid's swing reaches a bat at the bottom of its dive")
	_check(swing_high_ok, "a bat circling out at height is beyond the kid's swing")
	_check(dog_ok, "the dog's leap reaches a bat at the bottom of its dive")

	# Moving away during the telegraph dodges the dive.
	bat.queue_free()
	await _frames(3)
	kid.global_position = arena.get_node("World/Kid").global_position
	var b2 := Enemy.create(BAT, kid.global_position + Vector2(90, 0))
	arena.get_node("World").add_child(b2)
	hp0 = kid.health.hp
	var home := kid.global_position
	var dodged := false
	var landed := false
	for i in 60 * 6:
		await get_tree().physics_frame
		if b2.state == Enemy.State.WINDUP and not dodged:
			kid.global_position = home + Vector2(0, 70)  # a sidestep (walking 0.8 s)
			dodged = true
		if dodged and b2.state == Enemy.State.RECOVER:
			landed = kid.health.hp < hp0
			break
	_check(dodged and not landed, "a kid who sidesteps the telegraphed dive is not bitten")
	kid.global_position = home

	# The AI partner: leaves a high-circling bat alone, fights it in its dive.
	var brain := PartnerBrain.new(kid)
	dog.global_position = kid.global_position + Vector2(30, 0)
	b2.global_position = kid.global_position + Vector2(-70, -10)
	b2.height = 18.0
	_check(brain._pick_target("offensive", false, dog) == null, "the partner doesn't chase a bat circling high")
	b2.height = 4.0
	_check(brain._pick_target("offensive", false, dog) == b2, "the partner goes for a bat in its swoop")
	b2.queue_free()
	Clock.hold("day", 0.0)


func _test_talk_beats_attack() -> void:
	var lot: Node = load("res://realms/podunk/ruffleberg_lot.tscn").instantiate()
	lot.skip_intro = true
	add_child(lot)
	await _frames(10)
	var kid: Kid = lot.get_node("World/Kid")
	var maya: Npc = null
	for n in get_tree().get_nodes_in_group("npc"):
		if n.character_id == "MAYA":
			maya = n
	kid.global_position = maya.global_position + Vector2(30, 0)
	kid.facing = Vector2.LEFT
	await _frames(3)
	# Gamepad A fires interact AND attack; talking must win.
	var ev := InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_A
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventJoypadButton.new()
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
	_check(Dialogue.is_active(), "gamepad A next to Maya should talk")
	_check(not kid.is_attacking(), "and must not swing at the same time")
	Dialogue._finish()
	lot.queue_free()
	await _frames(2)


func _test_hd() -> void:
	Clock.hold("day", 0.0)  # rats are the day enemies: pin it (the clock is global and free elsewhere)
	# An arena an earlier section left standing keeps its own night shift going.
	for c in get_children():
		if String(c.name).begins_with("CombatArena"):
			c.queue_free()
	await _frames(3)
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	var hd: HdView = scene.get_node("HdView")
	var rats := get_tree().get_nodes_in_group("enemy")
	var yard: Node = scene.get_node("Yard")
	var kinds := {}
	for e in rats:
		var id: String = (e as Enemy).data.resource_path.get_file().get_basename()
		kinds[id] = int(kinds.get(id, 0)) + 1
	var n_enemies: int = "".join(yard.layout).count("x") + yard.cfg("ENEMY_ROOSTS").size()
	_check(n_enemies >= 25 and rats.size() == n_enemies, "the big arena has %d enemies (day rats + oak bats), found %d %s" % [n_enemies, rats.size(), kinds])
	_check(not kinds.has("skeleton") or Clock.is_night(), "skeletons only at night")
	var mirrored := 0
	for r in rats:
		if scene.get_node_or_null("HdView/" + String(r.name)) != null:
			mirrored += 1
	_check(mirrored == rats.size(), "every rat is drawn in 3D (%d of %d)" % [mirrored, rats.size()])
	# One that arrives after the view is built must show up too (spawners, waves).
	var late := Enemy.create(RAT, Vector2(200, 200))
	late.name = "LateRat"
	scene.get_node("Yard/World").add_child(late)
	await _frames(20)
	var late3d := scene.get_node_or_null("HdView/LateRat") as Sprite3D
	_check(late3d != null and late3d.visible, "an enemy spawned after load must be drawn in 3D")
	late.queue_free()
	await _frames(3)
	_check(scene.get_node_or_null("HdView/LateRat") == null, "its 3D sprite goes away with it")
	# In headless the 3D camera can't project meaningfully, so check the 2D path
	# instead: an effect at the kid's feet lands where the kid is on screen.
	hd.set_enabled(false)
	await _frames(2)
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var expect := get_viewport().get_canvas_transform() * kid.global_position
	_check(Fx.world_to_screen(kid.global_position).distance_to(expect) < 0.5, "2D effects project through the 2D camera")
	scene.queue_free()
	await _frames(2)


# -----------------------------------------------------------------------------
func _load(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _frames(8)
	return scene


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()


func _add_rat(arena: Node, at: Vector2) -> Enemy:
	var e := Enemy.create(RAT, at)
	arena.get_node("World").add_child(e)
	return e


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
