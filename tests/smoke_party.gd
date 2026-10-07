# =============================================================================
# smoke_party.gd  -  Headless checks for the duo (combat phase B)
# -----------------------------------------------------------------------------
# WHAT:  1. Switching control: Tab hands the stick to the dog, the 2D camera
#           moves over and glides, the kid follows the dog; and back
#        2. Stay put: the partner holds his spot; it stays on through a switch
#           (split puzzles); pressing again calls him back
#        3. Knockouts: you can't switch to a downed member; if the one you
#           drive goes down, control jumps to the other
#        4. Stances: the dog on Offensive bites an awake rat near the kid, on
#           Search he leaves it alone; the kid on Offensive goes after a rat,
#           on Defensive he stays put and only swings at one within reach
#        5. The dog's bite when you drive him
#        6. HUD: "> " marks the one you drive, the partner shows his stance and
#           "Stay"; an arrow points at an off-screen partner
#        7. Talking belongs to the kid: nothing is in reach while driving the
#           dog, and a conversation hands control back to him
#        8. HD-2D: the 3D camera follows whoever you drive
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_party.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA := "res://realms/test/combat_arena.tscn"
const ARENA_HD := "res://realms/test/combat_arena_hd.tscn"
const RAT := preload("res://data/enemies/rat.tres")
const BITE := preload("res://data/weapons/dog_bite.tres")

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_switching()
	await _test_stay_put()
	await _test_knockouts()
	await _test_stances()
	await _test_bite()
	await _test_hud()
	await _test_talking()
	await _test_hd()
	GameState.kid_stance = "offensive"
	GameState.dog_stance = "offensive"
	if _failures.is_empty():
		print("[TEST] PASS  smoke_party")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_switching() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	_check(Party.leader == kid and kid.controlled and not dog.controlled, "a scene starts with the kid in charge")

	_tap("switch_control")
	await _frames(2)
	_check(Party.leader == dog and dog.controlled and not kid.controlled, "Tab hands control to the dog")
	var cam := dog.get_node_or_null("Camera2D") as Camera2D
	_check(cam != null, "the 2D camera moves over to the dog")
	_check(cam != null and cam.position.length() > 1.0, "and glides there instead of cutting (offset %s)" % (cam.position if cam else Vector2.ZERO))
	await _wait(0.6)
	_check(cam != null and cam.position.length() < 0.5, "the glide settles on the dog")

	var kid_start := kid.global_position
	var dog_start := dog.global_position
	Input.action_press("move_right")
	await _wait(1.0)
	Input.action_release("move_right")
	_check(dog.global_position.x - dog_start.x > 80.0, "the stick drives the dog now (moved %.0f px)" % (dog.global_position.x - dog_start.x))
	await _wait(1.5)
	_check(kid.global_position.distance_to(kid_start) > 40.0, "the kid follows the dog")
	var gap := kid.global_position.distance_to(dog.global_position)
	_check(gap <= kid.follow_distance + kid.resume_margin + 4.0, "and catches up with him (gap %.0f px)" % gap)

	_tap("switch_control")
	await _frames(2)
	_check(Party.leader == kid and kid.controlled, "Tab again hands control back to the kid")
	_check(kid.get_node_or_null("Camera2D") != null, "and the camera returns to him")
	arena.queue_free()
	await _frames(2)


func _test_stay_put() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	_tap("partner_stay")
	await _frames(2)
	_check(Party.staying and dog.state == Dog.State.STAY, "Q tells the partner to Stay put")
	var dog_spot := dog.global_position
	Input.action_press("move_left")
	await _wait(1.0)
	Input.action_release("move_left")
	await _wait(0.5)
	_check(dog.global_position.distance_to(dog_spot) < 4.0, "a staying dog holds his spot (moved %.1f px)" % dog.global_position.distance_to(dog_spot))

	# Split puzzle: switch to the dog; the kid you just left stays put.
	_tap("switch_control")
	await _frames(2)
	_check(Party.staying and Party.is_staying(kid), "Stay put stays on through a switch, now for the kid")
	var kid_spot := kid.global_position
	Input.action_press("move_up")
	await _wait(0.8)
	Input.action_release("move_up")
	await _wait(0.5)
	_check(kid.global_position.distance_to(kid_spot) < 4.0, "the kid holds his spot while you walk the dog (moved %.1f px)" % kid.global_position.distance_to(kid_spot))

	_tap("partner_stay")
	await _wait(2.5)
	_check(not Party.staying, "Q again calls the partner back")
	var gap := kid.global_position.distance_to(dog.global_position)
	_check(gap <= kid.follow_distance + kid.resume_margin + 4.0, "a called-back kid comes to the dog (gap %.0f px)" % gap)
	arena.queue_free()
	await _frames(2)


func _test_knockouts() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	_ko(dog)
	await _frames(2)
	_check(dog.downed, "the dog is knocked out")
	_check(not Party.switch_control() and Party.leader == kid, "you can't switch to a knocked-out dog")
	dog.revive(1.0)
	await _frames(2)
	_ko(kid)
	await _frames(2)
	_check(Party.leader == dog and dog.controlled, "the kid goes down: control jumps to the dog")
	kid.revive(1.0)
	await _frames(2)
	arena.queue_free()
	await _frames(2)


func _test_stances() -> void:
	# The dog on Offensive bites an awake rat near the kid.
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	kid.set_physics_process(false)
	Party.set_stance(dog, "offensive")
	var rat := _awake_rat(arena, kid.global_position + Vector2(-50, 10))
	var hp := rat.health.hp
	await _wait(3.0)
	_check(rat.health.hp < hp, "the dog on Offensive bites an awake rat near the kid")

	# On Search he leaves it alone.
	Party.set_stance(dog, "search")
	rat.queue_free()
	var rat2 := _awake_rat(arena, kid.global_position + Vector2(-50, 10))
	var hp2 := rat2.health.hp
	await _wait(3.0)
	_check(rat2.health.hp == hp2, "the dog on Search keeps out of the fight")
	# ...unless it's after him: then he bites back.
	rat2.global_position = dog.global_position + Vector2(-20, 0)
	rat2.target = dog
	await _wait(2.0)
	_check(rat2.health.hp < hp2, "the dog on Search bites back at a rat that's after him")
	arena.queue_free()
	await _frames(2)

	# The kid as partner: Offensive goes after a rat 70 px away.
	arena = await _load(ARENA)
	kid = arena.get_node("World/Kid")
	dog = arena.get_node("World/Dog")
	_clear_enemies()
	Party.switch_control()
	dog.set_physics_process(false)
	Party.set_stance(kid, "offensive")
	var rat3 := _awake_rat(arena, kid.global_position + Vector2(0, -70))
	var hp3 := rat3.health.hp
	await _wait(3.0)
	_check(rat3.health.hp < hp3, "the kid on Offensive goes after the rat")
	rat3.queue_free()

	# Defensive: a rat out of reach is left alone, and he doesn't chase it...
	Party.set_stance(kid, "defensive")
	await _wait(1.5)  # let him walk back to the dog first
	var spot := kid.global_position
	var rat4 := _awake_rat(arena, kid.global_position + Vector2(0, -70))
	var hp4 := rat4.health.hp
	await _wait(2.0)
	_check(rat4.health.hp == hp4, "the kid on Defensive leaves a rat out of reach alone")
	_check(kid.global_position.distance_to(spot) < 12.0, "and doesn't chase it (moved %.0f px)" % kid.global_position.distance_to(spot))
	rat4.queue_free()
	# ...but one within reach gets a full-power swing.
	var rat5 := _awake_rat(arena, kid.global_position + Vector2(0, -22))
	rat5.health.reset(200)
	await _wait(3.5)
	var dealt := 200 - rat5.health.hp
	_check(dealt > 0, "the kid on Defensive swings at a rat within reach")
	_check(dealt >= roundi(kid.weapon.damage * 4.0), "with a full charge (x4 = %d), did %d" % [roundi(kid.weapon.damage * 4.0), dealt])

	# R cycles the partner's stance.
	_tap("partner_stance")
	await _frames(2)
	_check(Party.stance_of(kid) == "offensive", "R cycles the partner's stance")
	arena.queue_free()
	await _frames(2)


func _test_bite() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	kid.set_physics_process(false)
	Party.switch_control()
	var rat := _add_rat(arena, dog.global_position + Vector2(24, 0))
	await _frames(2)
	rat.set_physics_process(false)
	dog.facing = Vector2.RIGHT
	dog.charge.value = 1.0
	var hp := rat.health.hp
	_tap("attack")
	await _wait(0.5)
	var dealt := hp - rat.health.hp
	_check(dealt == roundi(BITE.damage), "attack is the dog's bite when you drive him (%d), did %d" % [roundi(BITE.damage), dealt])
	arena.queue_free()
	await _frames(2)


func _test_hud() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	var kid_label: Label = arena.get_node("HUD/SafeFrame/KidStatus")
	var dog_label: Label = arena.get_node("HUD/SafeFrame/DogStatus")
	var arrow: PartnerArrow = arena.get_node("HUD/SafeFrame/PartnerArrow")
	Party.set_stance(dog, "search")
	Party.set_staying(true)
	await _frames(2)
	_check(kid_label.text.begins_with("> "), "the kid's label is marked as driven: '%s'" % kid_label.text)
	_check(dog_label.text.contains("Search") and dog_label.text.contains("Stay"),
			"the partner's label shows his stance and Stay: '%s'" % dog_label.text)
	_check(not arrow.visible, "no arrow while the partner is on screen")
	dog.global_position = kid.global_position + Vector2(600, 0)
	await _frames(3)
	_check(arrow.visible, "an arrow points at an off-screen partner")
	_check(arrow.tip.x > arrow.size.x * 0.5, "on the side he's on")
	_check(not arrow.hurt, "the arrow is calm while he's fine")
	dog.get_node("Hurtbox").receive(HitInfo.make(1.0, dog.global_position, dog.global_position, 0.0, "enemy", null))
	await _frames(2)
	_check(arrow.hurt, "the arrow flashes red while he's being hit")
	Party.set_staying(false)
	Party.switch_control()
	await _frames(2)
	_check(dog_label.text.begins_with("> ") and not kid_label.text.begins_with("> "), "the marker moves with a switch")
	arena.queue_free()
	await _frames(2)


func _test_talking() -> void:
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
	_check(Interaction.current_target() == maya, "next to Maya, she's in reach")
	Party.switch_control()
	kid.set_physics_process(false)
	await _frames(3)
	_check(Interaction.current_target() == null, "nothing is in reach while you drive the dog")
	Dialogue.start("res://data/dialogue/prologue.dlg", "maya")
	await _frames(2)
	_check(Party.leader == kid, "a conversation hands control back to the kid")
	Dialogue._finish()
	lot.queue_free()
	await _frames(2)


func _test_hd() -> void:
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	_clear_enemies()
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var dog: Dog = scene.get_node("Yard/World/Dog")
	Party.switch_control()
	kid.set_physics_process(false)
	Input.action_press("move_right")
	await _wait(1.5)
	Input.action_release("move_right")
	await _wait(1.0)
	var t := hd._target
	var to_dog := absf(t.x - HdView.to3(dog.global_position).x)
	var to_kid := absf(t.x - HdView.to3(kid.global_position).x)
	_check(to_dog < to_kid, "the HD-2D camera follows the dog after a switch (%.2f m from him, %.2f m from the kid)" % [to_dog, to_kid])
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


## A rat that counts as in the fight (awake) but holds still and never bites,
## so only the party's behavior is measured.
func _awake_rat(arena: Node, at: Vector2) -> Enemy:
	var e := _add_rat(arena, at)
	e.set_physics_process(false)
	e.state = Enemy.State.RECOVER
	return e


func _ko(member: Node2D) -> void:
	var info := HitInfo.make(9999.0, member.global_position, member.global_position, 0.0, "enemy", null)
	member.get_node("Hurtbox").receive(info)


## Simulate a single button press so _unhandled_input handlers fire.
func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
