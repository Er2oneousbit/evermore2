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

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_charge_meter()
	_test_health()
	_test_difficulty()
	await _test_swing()
	await _test_enemy_behavior()
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
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	var hd: HdView = scene.get_node("HdView")
	var rats := get_tree().get_nodes_in_group("enemy")
	_check(rats.size() == 5, "the arena has 5 rats, found %d" % rats.size())
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
