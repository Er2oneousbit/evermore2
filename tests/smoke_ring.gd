# =============================================================================
# smoke_ring.gd  -  Headless checks for the ring menu and equipment
# -----------------------------------------------------------------------------
# WHAT:  1. Data: every EquipmentData fits its wearer's slots, weapons have a
#           WeaponData, icons sit on the item sheet
#        2. A new run: the kid holds the stick, no armor; a demo map hands out
#           its kit once (reloading doesn't hand it out again)
#        3. Equipment rules: only owned pieces that fit; the weapon slot can't
#           be emptied; armor adds up and reaches Health (and cuts damage);
#           a new weapon changes the swing and the charge meter
#        4. The menu: I opens it on whoever you drive and pauses the game;
#           the Equipment tab shows; right turns, a held direction keeps
#           spinning and wraps around; down changes the piece right away and
#           the panel shows it and the change to the total; Tab flips to the
#           dog's gear without changing who you drive; Esc closes and doesn't
#           open the pause menu; it won't open mid-conversation
#        5. Driving the dog, it opens on the dog's gear
#        6. HD-2D: the ring sits on screen around the character
#        7. Swapping weapons doesn't refill the charge; a weapon changed
#           mid-swing waits for the swing to end; an old save that kept
#           gamepad Y on the flashlight gives it up to the ring menu
#        8. The weapon in his hand: hidden until he swings, then on the
#           swing's frame and facing, front and back layers; a new weapon
#           brings its own art; HD-2D mirrors both layers and the swap
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_ring.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA := "res://realms/test/combat_arena.tscn"
const ARENA_HD := "res://realms/test/combat_arena_hd.tscn"

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_data()
	await _test_new_run_and_kit()
	await _test_rules()
	await _test_menu()
	await _test_dog_driven()
	await _test_hd()
	await _test_review_fixes()
	await _test_weapon_in_hand()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_ring")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_data() -> void:
	var count := 0
	for f in DirAccess.get_files_at("res://data/items/"):
		if not f.ends_with(".tres"):
			continue
		var e := load("res://data/items/" + f) as EquipmentData
		if e == null:
			continue
		count += 1
		_check(e.id + ".tres" == f, "%s: id matches the file name" % f)
		_check(Equipment.SLOTS.has(e.wearer) and Equipment.SLOTS[e.wearer].has(e.slot), "%s: slot '%s' fits a %s" % [f, e.slot, e.wearer])
		_check((e.slot == "weapon") == (e.weapon != null), "%s: weapons (and only weapons) have a WeaponData" % f)
		_check(e.icon_cell.x >= 0 and e.icon_cell.y >= 0 and e.icon_cell.x < ItemData.ICON_GRID.x and e.icon_cell.y < ItemData.ICON_GRID.y,
				"%s: icon on the item sheet" % f)
	_check(count >= 7, "the equipment data loads (%d pieces)" % count)


func _test_new_run_and_kit() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	_check(Equipment.equipped("kid", "weapon") != null and Equipment.equipped("kid", "weapon").id == "stick", "a new run: the kid holds the stick")
	_check(kid.weapon == ItemData.find("stick").weapon, "and swings it")
	_check(GameState.item_count("bike_helmet") == 1 and GameState.item_count("studded_collar") == 1, "the arena hands out its demo kit")
	_check(kid.health.armor == 0.0, "nothing worn yet: no armor")
	arena.queue_free()
	await _frames(2)
	arena = await _load(ARENA)
	_check(GameState.item_count("bike_helmet") == 1, "reloading doesn't hand the kit out again (%d)" % GameState.item_count("bike_helmet"))
	arena.queue_free()
	await _frames(2)


func _test_rules() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	var helmet := ItemData.find("bike_helmet") as EquipmentData
	var hoodie := ItemData.find("hoodie") as EquipmentData
	var collar := ItemData.find("studded_collar") as EquipmentData
	var sword := ItemData.find("rusty_sword") as EquipmentData
	_check(not Equipment.equip("kid", "body", helmet), "a helmet doesn't go on the body")
	_check(not Equipment.equip("kid", "collar", collar), "the kid has no collar slot")
	_check(not Equipment.equip("kid", "weapon", null), "the weapon slot can't be emptied")
	_check(not Equipment.options("kid", "weapon").has(null), "and the menu never offers 'nothing' there")
	GameState.inventory["bike_helmet"] = 0
	_check(not Equipment.equip("kid", "head", helmet), "a piece you don't own can't be worn")
	GameState.inventory["bike_helmet"] = 1
	var changed := []
	var on_change := func(w: String) -> void: changed.append(w)
	EventBus.equipment_changed.connect(on_change)
	_check(Equipment.equip("kid", "head", helmet) and Equipment.equip("kid", "body", hoodie), "pieces that fit go on")
	_check(changed == ["kid", "kid"], "each change is announced (%s)" % [changed])
	_check(kid.health.armor == helmet.defense + hoodie.defense, "armor adds up on the kid (%.0f)" % kid.health.armor)
	var info := HitInfo.make(10.0, Vector2.ZERO, Vector2.ZERO, 0.0, "enemy", null)
	_check(kid.health.mitigated(info.damage) < 10, "and cuts the damage he takes (10 -> %d)" % kid.health.mitigated(10.0))
	Equipment.equip("dog", "collar", collar)
	_check(dog.health.armor == collar.defense, "the collar is the dog's armor (%.0f)" % dog.health.armor)
	Equipment.equip("kid", "weapon", sword)
	_check(kid.weapon == sword.weapon, "a new weapon is the one he swings")
	_check(kid.charge.max_level == sword.weapon.max_level, "and the charge meter takes its levels (%d)" % kid.charge.max_level)
	_check(kid.run.charge == kid.charge, "running still spends the new meter")
	EventBus.equipment_changed.disconnect(on_change)
	# Back to a plain kid for the menu test.
	Equipment.equip("kid", "weapon", ItemData.find("stick") as EquipmentData)
	Equipment.equip("kid", "head", null)
	Equipment.equip("kid", "body", null)
	Equipment.equip("dog", "collar", null)
	arena.queue_free()
	await _frames(2)


func _test_menu() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	_clear_enemies()
	_tap("ring_menu")
	await _frames(2)
	_check(RingMenu.is_open(), "I opens the ring menu")
	_check(get_tree().paused, "and pauses the game")
	_check(RingMenu.who == "kid" and RingMenu.selected_slot() == "weapon", "on the kid's gear, weapon first")
	var tabs: Node = RingMenu.get_node("Root/Tabs")
	_check(tabs.get_child_count() == RingMenu.RINGS.size() and (tabs.get_child(0) as Label).text == "Equipment", "the rings show as tabs (Equipment)")

	# Turn: one step per push.
	Input.action_press("move_right")
	await _frames(3)
	_check(RingMenu.selected_slot() == "head", "right turns to the next slot (%s)" % RingMenu.selected_slot())
	await _frames(6)
	_check(RingMenu.selected_slot() == "head", "one push is one step")
	# Hold: it keeps spinning, and wraps around.
	await _wait(RingMenu.REPEAT_DELAY + RingMenu.REPEAT_EVERY * 7.5)
	Input.action_release("move_right")
	await _frames(2)
	var n: int = Equipment.SLOTS["kid"].size()
	var at: int = posmod(RingMenu._sel_now(), n)
	_check(RingMenu._sel_now() >= n, "held, it keeps spinning, all the way around (%d steps)" % RingMenu._sel_now())
	# Find the head slot again from wherever it stopped.
	var head_i: int = Equipment.SLOTS["kid"].find("head")
	RingMenu.turn(posmod(head_i - at, n))
	_check(RingMenu.selected_slot() == "head", "(back on the head slot)")

	# Change: down puts the next piece on, right away.
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	await _frames(2)
	var helmet := ItemData.find("bike_helmet") as EquipmentData
	_check(Equipment.equipped("kid", "head") == helmet, "down puts the helmet on, no confirm step")
	_check(kid.health.armor == helmet.defense, "and it counts at once (armor %.0f)" % kid.health.armor)
	var text := RingMenu.info_text()
	_check(text.contains("Bike helmet") and text.contains("Defense 8") and text.contains("(+8)"),
			"the panel shows the piece and the change to the total:\n%s" % text)
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	await _frames(2)
	_check(Equipment.equipped("kid", "head") == null and kid.health.armor == 0.0, "down again takes it off (nothing is an option)")

	# Tab: the dog's gear, still driving the kid.
	_tap("switch_control")
	await _frames(2)
	_check(RingMenu.who == "dog" and RingMenu.selected_slot() == "collar", "Tab shows the dog's gear")
	_check(Party.leader == kid, "without switching who you drive")
	_check(RingMenu.info_text().contains("gear") and RingMenu.info_text().contains(GameState.get_dog_name()), "the panel says whose gear it is")
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	await _frames(2)
	_check(Equipment.equipped("dog", "collar") != null, "and his collar goes on the same way")

	# Esc closes; it doesn't open the pause menu.
	_tap("pause")
	await _frames(2)
	_check(not RingMenu.is_open() and not get_tree().paused, "Esc closes it and the game goes on")
	_check(not PauseMenu.is_open(), "without opening the pause menu")
	_tap("ring_menu")
	await _frames(2)
	_check(RingMenu.who == "kid" and RingMenu.selected_slot() == "head", "it reopens where you left the kid's ring")
	_tap("ring_menu")
	await _frames(2)
	_check(not RingMenu.is_open(), "I closes it too")

	# Not mid-conversation.
	Dialogue.start("res://data/dialogue/prologue.dlg", "dinner_okay")
	_tap("ring_menu")
	await _frames(2)
	_check(not RingMenu.is_open(), "it doesn't open while people talk")
	Dialogue._finish()
	await _frames(2)
	Equipment.equip("dog", "collar", null)
	arena.queue_free()
	await _frames(2)


func _test_dog_driven() -> void:
	var arena := await _load(ARENA)
	_clear_enemies()
	_tap("switch_control")
	await _frames(2)
	_tap("ring_menu")
	await _frames(2)
	_check(RingMenu.is_open() and RingMenu.who == "dog", "driving the dog, it opens on his gear")
	_tap("ring_menu")
	await _frames(2)
	_tap("switch_control")
	await _frames(2)
	arena.queue_free()
	await _frames(2)


func _test_hd() -> void:
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	_clear_enemies()
	RingMenu.open()
	await _frames(2)
	var c: Vector2 = RingMenu.ring_center()
	var size: Vector2 = RingMenu.get_node("Root").get_viewport_rect().size
	_check(Rect2(Vector2.ZERO, size).grow(-RingMenu.RADIUS).has_point(c), "HD-2D: the ring sits on screen (center %s in %s)" % [c, size])
	RingMenu.close()
	scene.queue_free()
	await _frames(2)


func _test_review_fixes() -> void:
	var arena := await _load(ARENA)
	var kid: Kid = arena.get_node("World/Kid")
	_clear_enemies()
	var stick := ItemData.find("stick") as EquipmentData
	var sword := ItemData.find("rusty_sword") as EquipmentData
	# Swap twice right after a swing: still empty.
	kid.charge.value = 0.0
	Equipment.equip("kid", "weapon", sword)
	Equipment.equip("kid", "weapon", stick)
	_check(kid.charge.value < 0.05, "swapping weapons doesn't refill the charge (%.2f)" % kid.charge.value)
	kid.charge.value = 3.0
	Equipment.equip("kid", "weapon", sword)
	_check(kid.charge.value == float(sword.weapon.max_level), "and a big charge is capped to the new weapon (%.1f)" % kid.charge.value)
	Equipment.equip("kid", "weapon", stick)
	# Mid-swing: the blow belongs to the weapon it started with.
	await _frames(2)
	kid.charge.value = 3.0
	kid.attack()
	await get_tree().physics_frame
	Equipment.equip("kid", "weapon", sword)
	_check(kid.weapon == stick.weapon, "a weapon changed mid-swing waits (still the stick)")
	for i in 120:
		await get_tree().physics_frame
		if not kid.is_attacking():
			break
	await get_tree().physics_frame
	_check(kid.weapon == sword.weapon, "and goes on when the swing ends")
	Equipment.equip("kid", "weapon", stick)
	arena.queue_free()
	await _frames(2)
	# An old save: the flashlight rebound to L but still holding gamepad Y.
	var old := {"keys": [KEY_L], "buttons": [JOY_BUTTON_Y]}
	Settings._controls["toggle_light"] = old
	Settings._apply_all()
	_check(InputSetup.bindings_of("ring_menu")["buttons"].has(JOY_BUTTON_Y), "the ring menu keeps gamepad Y")
	_check(not InputSetup.bindings_of("toggle_light")["buttons"].has(JOY_BUTTON_Y), "an old save's flashlight gives Y up")
	_check(InputSetup.bindings_of("toggle_light")["keys"] == [KEY_L], "and keeps its own key (L)")
	Settings._controls.erase("toggle_light")
	InputSetup.set_bindings("toggle_light", {"keys": [KEY_F], "buttons": [JOY_BUTTON_LEFT_STICK]})


func _test_weapon_in_hand() -> void:
	var scene: Node = load(ARENA_HD).instantiate()
	add_child(scene)
	await _frames(12)
	_clear_enemies()
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = scene.get_node("Yard/World/Kid")
	var front: Sprite2D = kid.get_node("WeaponFront")
	var back: Sprite2D = kid.get_node("WeaponBack")
	var body: LpcSprite = kid.get_node("Sprite")
	var stick := ItemData.find("stick") as EquipmentData
	var sword := ItemData.find("rusty_sword") as EquipmentData
	_check(front.texture == stick.weapon.overlay_fg and back.texture == stick.weapon.overlay_bg, "the stick's art is in his hand layers")
	_check(back.get_index() < body.get_index() and front.get_index() > body.get_index(), "one layer behind his body, one in front")
	_check(not front.visible and not back.visible, "no weapon showing while he walks around")
	var f3 := _layer3d(hd, kid, "WeaponFront")
	var b3 := _layer3d(hd, kid, "WeaponBack")
	_check(f3 != null and b3 != null, "HD-2D mirrors both weapon layers")
	kid.facing = Vector2.LEFT
	kid.charge.value = 1.0
	kid.attack()
	var seen := false
	var columns := {}
	for i in 40:
		await get_tree().physics_frame
		if front.visible:
			seen = true
			columns[front.frame_coords.x] = true
			_check(front.frame_coords == Vector2i(body.frame_index(), int(body.dir)),
					"the weapon frame follows the swing (%s vs frame %d, dir %d)" % [front.frame_coords, body.frame_index(), body.dir])
			if body.frame_index() >= 3:
				break
	_check(seen and back.visible, "swinging shows the weapon in his hand")
	_check(columns.size() >= 3, "through the frames of the swing (%d seen)" % columns.size())
	await _frames(2)
	if f3:
		_check(f3.visible and f3.frame_coords == front.frame_coords, "and in HD-2D too")
	for i in 60:
		await get_tree().physics_frame
		if not kid.is_attacking():
			break
	await get_tree().physics_frame
	_check(not front.visible, "it's put away when the swing ends")
	Equipment.equip("kid", "weapon", sword)
	_check(front.texture == sword.weapon.overlay_fg and front.hframes == sword.weapon.overlay_fg.get_width() / sword.weapon.overlay_frame,
			"a new weapon brings its own art and frame size")
	await _frames(2)
	if f3:
		_check(f3.texture == sword.weapon.overlay_fg and f3.hframes == front.hframes, "HD-2D swaps it too")
	Equipment.equip("kid", "weapon", stick)
	scene.queue_free()
	await _frames(2)


func _layer3d(hd: HdView, actor: Node, layer: String) -> Sprite3D:
	for a: Array in hd._actors:
		if a[0] == actor and a[3] == layer:
			return a[1]
	return null


# -----------------------------------------------------------------------------
func _load(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _frames(8)
	return scene


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Waits on process frames: physics stops while the menu pauses the game.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * 60.0))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
