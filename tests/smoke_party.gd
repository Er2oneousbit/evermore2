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
#        9. Running: walk by default (free), hold Run to run (faster, the run
#           cycle) and it drains the attack charge instead of filling it; run
#           it to 0% and he's winded (walks even holding Run, the charge bar
#           blinks) until it refills partway; the toggle setting; the dog pays
#           a quarter as much; the AI partner pays nothing and keeps up
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
	await _test_leap()
	await _test_hud()
	await _test_talking()
	await _test_hd()
	await _test_running()
	await _test_idle()
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


## The bite is a leap (owner's playtest 2026-10-09): crouch, spring at the enemy,
## bite on contact, spring back. No slash arc; walls stop the leap.
func _test_leap() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	kid.set_physics_process(false)
	Party.switch_control()
	var base_y: float = dog.get_node("Sprite").offset.y
	# A rat 80 px ahead: he leaps at it and bites it, with no arc effect.
	var rat := _add_rat(arena, dog.global_position + Vector2(80, 0))
	await _frames(2)
	rat.set_physics_process(false)
	dog.facing = Vector2.RIGHT
	dog.charge.value = 1.0
	var start := dog.global_position
	var hp := rat.health.hp
	var effects := Fx.live_effects
	var max_effects := 0
	var peak := 0.0
	var hit_x := INF
	var phases := {}
	_tap("attack")
	for i in 90:
		await get_tree().physics_frame
		phases[dog._atk] = true
		max_effects = maxi(max_effects, Fx.live_effects)
		peak = maxf(peak, base_y - dog.get_node("Sprite").offset.y)
		if hit_x == INF and rat.health.hp < hp:
			hit_x = dog.global_position.x - start.x
	_check(phases.has(Dog.Atk.WINDUP) and phases.has(Dog.Atk.LEAP) and phases.has(Dog.Atk.RECOIL), "the bite has a crouch, a leap and a recoil")
	_check(hit_x != INF and hit_x > 40.0, "he moved toward the rat before the bite landed (%.0f px)" % hit_x)
	_check(hp - rat.health.hp == roundi(BITE.damage), "the bite damages on contact (%d)" % (hp - rat.health.hp))
	_check(max_effects == effects, "no slash arc effect for the dog (%d live effects)" % max_effects)
	_check(peak > dog.hop_height * 0.6, "the leap hops in height (%.1f px up)" % peak)
	_check(is_equal_approx(dog.get_node("Sprite").offset.y, base_y), "and he lands back on the ground")
	_check(start.distance_to(dog.global_position) < dog.leap_range, "a leap is a few tiles at most (%.0f px)" % start.distance_to(dog.global_position))
	_check(not dog.is_attacking(), "the attack ends")
	rat.queue_free()
	# Nothing in front: a short hop, nobody hurt.
	await _frames(2)
	dog.charge.value = 1.0
	var p0 := dog.global_position
	_tap("attack")
	await _wait(0.8)
	_check(dog.global_position.distance_to(p0) > 10.0 and dog.global_position.distance_to(p0) < 60.0, "with nothing there he hops a little (%.0f px)" % dog.global_position.distance_to(p0))
	# A fence in between: he can't leap through it, the rat behind is untouched.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 120)
	shape.shape = rect
	wall.add_child(shape)
	arena.get_node("World").add_child(wall)
	dog.global_position = Vector2(kid.global_position.x, kid.global_position.y + 90)
	dog.velocity = Vector2.ZERO
	wall.global_position = dog.global_position + Vector2(36, 0)
	var rat2 := _add_rat(arena, dog.global_position + Vector2(80, 0))
	await _frames(2)
	rat2.set_physics_process(false)
	var hp2 := rat2.health.hp
	dog.facing = Vector2.RIGHT
	dog.charge.value = 1.0
	var wall_x := wall.global_position.x - 3.0
	var max_x := -INF
	_tap("attack")
	for i in 60:
		await get_tree().physics_frame
		max_x = maxf(max_x, dog.global_position.x)
	_check(max_x < wall_x + 1.0, "he doesn't leap through a fence (got to x %.0f, fence at %.0f)" % [max_x, wall_x])
	_check(rat2.health.hp == hp2, "the rat behind the fence isn't bitten")
	arena.queue_free()
	await _frames(2)


func _test_hud() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	_clear_enemies()
	var kid_label: MemberCard = arena.get_node("HUD/SafeFrame/KidCard")
	var dog_label: MemberCard = arena.get_node("HUD/SafeFrame/DogCard")
	var arrow: PartnerArrow = arena.get_node("HUD/SafeFrame/PartnerArrow")
	Party.set_stance(dog, "search")
	Party.set_staying(true)
	await _frames(2)
	_check(kid_label.summary().begins_with("> "), "the kid's card is marked as driven: '%s'" % kid_label.summary())
	_check(dog_label.summary().contains("Search") and dog_label.summary().contains("Stay"),
			"the partner's card shows his stance and Stay: '%s'" % dog_label.summary())
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
	_check(dog_label.summary().begins_with("> ") and not kid_label.summary().begins_with("> "), "the marker moves with a switch")
	Party.switch_control()
	await _frames(2)
	# The health bar: a hit leaves a ghost of what it took, which drains away.
	var hud := arena.get_node("HUD")
	kid.get_node("Hurtbox").receive(HitInfo.make(10.0, kid.global_position, kid.global_position, 0.0, "enemy", null))
	await _frames(3)
	var live := float(kid.health.hp) / kid.health.max_hp
	_check(kid_label.ghost_fraction() > live + 0.05, "a hit leaves a ghost of the lost health (%.2f over %.2f)" % [kid_label.ghost_fraction(), live])
	await _wait(MemberCard.GHOST_HOLD + 1.5)
	_check(absf(kid_label.ghost_fraction() - live) < 0.01, "then it drains away (%.2f)" % kid_label.ghost_fraction())
	# Knocked out: KO and the revive countdown.
	_ko(dog)
	await _frames(3)
	_check(dog_label.summary().contains("KO") and Party.revive_left(dog) > 0.0, "a knocked-out partner's card says KO, with a countdown (%.1f s)" % Party.revive_left(dog))
	# The cards sit in the frame's bottom corners, apart.
	var frame: Rect2 = hud.get_safe_frame().get_global_rect()
	_check(frame.encloses(kid_label.get_global_rect()) and frame.encloses(dog_label.get_global_rect()), "both cards are inside the HUD frame")
	_check(not kid_label.get_global_rect().intersects(dog_label.get_global_rect()), "and don't overlap")
	_check(kid_label.get_global_rect().position.x < dog_label.get_global_rect().position.x, "the kid on the left, the dog on the right")
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


## Idle like the original: the dog sits after standing still, stands when the
## kid moves, sniffs and strolls now and then (seeded) without ever pointing,
## barking or digging, sits on Stay put, and sits when you drive him and stop.
func _test_idle() -> void:
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	_clear_enemies()
	GameState.dog_stance = "offensive"
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var dog: Dog = scene.get_node("Yard/World/Dog")
	var sprite: AnimalSprite = dog.get_node("Sprite")
	var barks: Array = []
	var on_sound := func(s: String) -> void:
		if s == "dog_bark" or s == "dig":
			barks.append(s)
	Audio.played.connect(on_sound)
	dog.idle.rng.seed = 11
	dog.idle.sniff_gap = Vector2(1.0, 1.5)
	dog.global_position = kid.global_position + Vector2(30, 0)
	await _wait(1.0)
	_check(not dog.idle.sitting(), "he doesn't sit the moment he stops (%s)" % dog.idle.mode)
	await _wait(DogIdle.SIT_AFTER + 0.4)
	_check(dog.idle.sitting() and sprite.current == &"sit", "after a couple of seconds still, he sits")
	var d3: Sprite3D = hd._mirrored.get(dog.get_instance_id())
	_check(d3 != null and d3.frame_coords.x == 8, "the HD-2D copy shows the sitting frame (column %s)" % (d3.frame_coords.x if d3 else -1))
	# The kid walks off: he stands and follows.
	Input.action_press("move_right")
	await _wait(1.2)
	_check(not dog.idle.sitting() and sprite.current != &"sit", "he stands up when the kid moves")
	Input.action_release("move_right")
	# Ambient sniff and stroll (sniff gap 1-1.5 s): never points, barks or digs.
	var waited := 0.0
	var max_from_kid := 0.0
	var nose_busy := false
	while waited < 20.0 and (dog.idle.sniffs < 2 or dog.idle.strolls < 1):
		await _frames(1)
		waited += 1.0 / 60.0
		nose_busy = nose_busy or dog.nose.mode != Nose.Mode.NONE
		max_from_kid = maxf(max_from_kid, dog.global_position.distance_to(kid.global_position))
	_check(dog.idle.sniffs >= 2 and dog.idle.strolls >= 1, "he sniffs and strolls on his own (%d sniffs, %d strolls, %.0f s)" % [dog.idle.sniffs, dog.idle.strolls, waited])
	_check(not nose_busy and barks.is_empty(), "with nothing to find he never points, barks or digs")
	_check(max_from_kid <= DogIdle.MAX_FROM_LEADER + 40.0, "and stays near the kid (%.0f px at most)" % max_from_kid)
	await _wait(6.0)
	_check(dog.idle.sitting() or dog.idle.ambient(), "he settles down again afterwards (%s)" % dog.idle.mode)
	# Stay put: he sits there and never wanders.
	dog.idle.sniff_gap = Vector2(30.0, 40.0)
	_tap("partner_stay")
	await _frames(2)
	_check(Party.staying, "(setup) Stay put")
	for i in 80:
		await _frames(10)
		if dog.idle.sitting():
			break
	_check(dog.idle.sitting(), "he sits while staying (%s, state %s, kid v %s, target %s)" % [dog.idle.mode, dog.get_state_name(), kid.velocity, dog.brain.target])
	_tap("partner_stay")
	# Driving the dog: he sits after a while without input, stands on input.
	dog.idle.interrupt()
	Party.switch_control()
	await _frames(2)
	_check(dog.controlled, "(setup) driving the dog")
	await _wait(DogIdle.DRIVEN_SIT_AFTER + 0.6)
	_check(dog.idle.sitting() and sprite.current == &"sit", "a driven dog sits after a while without input")
	Input.action_press("move_down")
	await _wait(0.3)
	Input.action_release("move_down")
	_check(not dog.idle.sitting(), "and stands when you move him")
	Audio.played.disconnect(on_sound)
	Party.switch_control()
	scene.queue_free()
	await _frames(2)


func _test_running() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	var bar: ChargeBar = arena.get_node("HUD/SafeFrame/KidCard/ChargeBar")
	_clear_enemies()
	dog.set_physics_process(false)  # only the kid's pace is measured first
	var sprite: DirectionalSprite = kid.get_node("Sprite")
	var full := float(kid.charge.max_level)

	# Walking: the default, and it costs nothing.
	kid.global_position = Vector2(60, 200)
	await _wait(kid.weapon.seconds_per_level * full)  # charge all the way up
	Input.action_press("move_right")
	await _wait(0.4)
	var x0 := kid.global_position.x
	await _wait(1.0)
	var walked := kid.global_position.x - x0
	_check(absf(walked - kid.move_speed) < 8.0, "he walks by default (%.0f px/s, walk speed %.0f)" % [walked, kid.move_speed])
	_check(sprite.current == &"walk", "with the walk cycle (%s)" % sprite.current)
	_check(kid.charge.value == full, "walking leaves the attack charge alone (%.2f of %.0f)" % [kid.charge.value, full])

	# Running: hold Run. It drains the charge instead of letting it fill.
	Input.action_press("run")
	await _wait(0.3)
	x0 = kid.global_position.x
	var c0 := kid.charge.value
	await _wait(1.0)
	var ran := kid.global_position.x - x0
	var drained := c0 - kid.charge.value
	_check(absf(ran - kid.run_speed) < 8.0, "holding Run runs (%.0f px/s, run speed %.0f)" % [ran, kid.run_speed])
	_check(sprite.current == &"run", "with the run cycle (%s)" % sprite.current)
	_check(absf(drained - kid.run_charge_drain) < 0.05, "running drains the attack charge (%.2f levels in 1 s, drain %.2f)" % [drained, kid.run_charge_drain])

	# Run it dry: winded, back to a walk even holding Run.
	for i in ceili((kid.charge.value / kid.run_charge_drain + 1.0) * 60.0):
		await _frames(1)
		if kid.run.winded:
			break
	_check(kid.run.winded and kid.charge.value == 0.0, "running the charge to 0% winds him")
	_check(bar.shows_winded(), "the charge bar shows it")
	await _wait(0.1)
	_check(absf(kid.velocity.length() - kid.move_speed) < 4.0 and not kid.running,
			"winded, he walks even holding Run (%.0f px/s)" % kid.velocity.length())
	Input.action_release("run")
	Input.action_release("move_right")
	await _wait(kid.weapon.seconds_per_level * Running.RECOVER_AT + 0.1)
	_check(not kid.run.winded and not bar.shows_winded(), "he gets his breath back as the charge refills")
	_check(kid.charge.level() < 1, "and his next swing is still a weak one (charge %.2f)" % kid.charge.value)

	# Toggle mode: press once, run without holding.
	await _wait(1.0)
	Settings.set_value("run_mode", "toggle")
	Input.action_press("move_left")
	_tap("run")
	await _wait(0.4)
	_check(kid.running, "toggle: one press of Run and he runs")
	# Turning around on a keyboard: a frame or two with no key held.
	Input.action_release("move_left")
	await _frames(2)
	Input.action_press("move_right")
	await _wait(0.2)
	_check(kid.running, "toggle: a quick turn-around keeps the run")
	kid.attack()
	await _wait(0.6)
	_check(kid.running, "toggle: a swing doesn't cancel it")
	Input.action_release("move_right")
	await _wait(Running.TOGGLE_STILL + 0.15)
	Input.action_press("move_right")
	await _wait(0.3)
	_check(not kid.running, "toggle: standing still a moment ends the run")
	Input.action_release("move_right")
	await _wait(0.2)
	_tap("run")
	await _wait(0.4)
	Input.action_press("move_left")
	await _wait(0.2)
	_check(kid.running, "toggle: pressed while standing, it's ready for the next move")
	Input.action_release("move_left")
	await _wait(0.5)
	Settings.set_value("run_mode", "hold")

	# The dog: zoomies, a quarter of the kid's cost. The AI kid pays nothing.
	dog.set_physics_process(true)
	kid.global_position = Vector2(700, 200)
	dog.global_position = Vector2(740, 200)
	_tap("switch_control")
	await _frames(2)
	await _wait(kid.weapon.seconds_per_level * full)
	var kid_full := kid.charge.value
	Input.action_press("move_left")
	Input.action_press("run")
	await _wait(0.3)
	x0 = dog.global_position.x
	c0 = dog.charge.value
	await _wait(1.0)
	var dog_ran := x0 - dog.global_position.x
	var dog_drained := c0 - dog.charge.value
	_check(absf(dog_ran - dog.run_speed) < 10.0, "the dog runs when you drive him (%.0f px/s, run speed %.0f)" % [dog_ran, dog.run_speed])
	_check(absf(dog_drained - kid.run_charge_drain / 4.0) < 0.03,
			"at a quarter of the kid's cost (%.3f levels/s vs the kid's %.2f)" % [dog_drained, kid.run_charge_drain])
	await _wait(1.0)
	Input.action_release("run")
	Input.action_release("move_left")
	_check(kid.charge.value >= kid_full, "the AI kid keeps up without spending his charge")
	await _wait(1.5)
	var gap := kid.global_position.distance_to(dog.global_position)
	_check(gap < 80.0, "and keeps up with a running dog (gap %.0f px)" % gap)
	_tap("switch_control")
	await _frames(2)
	arena.queue_free()
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
