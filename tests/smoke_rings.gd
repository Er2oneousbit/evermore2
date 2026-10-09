# =============================================================================
# smoke_rings.gd  -  Headless checks for the Items, Alchemy and Party rings and
#                    the quick slots
# -----------------------------------------------------------------------------
# WHAT:  1. Rings as tabs: Z / X (LB / RB) go to the previous / next ring
#        2. Items: usable things first, ingredients, key items; confirm uses
#           one on whoever is shown (heals, one fewer); not at full health;
#           key items can't be used or slotted
#        3. Alchemy: Heal costs a wild carrot and heals the one shown (the
#           dog too); casts earn experience and level it up (stronger); not
#           without ingredients (nothing used up); not with the kid knocked out
#        4. Party: up / down change both stances and Stay put
#        5. Quick slots: assigned from the ring with 1-4; outside the menu the
#           same key uses it on whoever you drive (the dog when you drive
#           him); an entry lives in one slot; an empty slot or a failure says
#           why on the HUD; nothing fires mid-conversation; the HUD bar shows
#           them
#        6. Controls: the D-pad left movement for the quick slots; an old save
#           with the D-pad on movement gives it up; dialogue choices take the
#           menu keys
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_rings.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const ARENA := "res://realms/test/combat_arena.tscn"

var _failures: PackedStringArray = []
var _notices: Array[String] = []


func _ready() -> void:
	EventBus.notice.connect(func(t: String) -> void: _notices.append(t))
	_run.call_deferred()


func _run() -> void:
	var arena := await _load(ARENA)
	await _test_tabs()
	await _test_items(arena)
	await _test_alchemy(arena)
	await _test_party(arena)
	await _test_quick_slots(arena)
	arena.queue_free()
	await _frames(2)
	await _test_controls()
	if _failures.is_empty():
		print("[TEST] PASS  smoke_rings")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_tabs() -> void:
	_tap("ring_menu")
	await _frames(2)
	_check(RingMenu.ring_id() == "equipment", "it opens on the Equipment ring")
	_tap("ring_next")
	await _frames(2)
	_check(RingMenu.ring_id() == "items", "X / RB: the next ring (%s)" % RingMenu.ring_id())
	_tap("ring_prev")
	_tap("ring_prev")
	await _frames(2)
	_check(RingMenu.ring_id() == "party", "Z / LB: the previous ring, wrapping around (%s)" % RingMenu.ring_id())
	var tabs: Node = RingMenu.get_node("Root/Tabs")
	var labels := []
	for t in tabs.get_children():
		labels.append((t as Label).text)
	_check(labels == ["Equipment", "Items", "Alchemy", "Party"], "all four rings show as tabs (%s)" % [labels])
	_tap("ring_menu")
	await _frames(2)


func _test_items(arena: Node) -> void:
	var kid: Kid = arena.get_node("World/Kid")
	GameState.add_item("old_key", 1)
	RingMenu.open()
	RingMenu.set_ring(1)
	await _frames(2)
	var keys := RingMenu.entries().map(func(e: Dictionary) -> String: return e["key"])
	_check(keys.find("apple") < keys.find("wild_carrot") and keys.find("wild_carrot") < keys.find("old_key"),
			"usable things first, then ingredients, then key items (%s)" % [keys])
	_check(not keys.has("bike_helmet"), "equipment lives in its own ring")
	_select("apple")
	var apples := GameState.item_count("apple")
	_tap("interact")
	await _frames(2)
	_check(GameState.item_count("apple") == apples and RingMenu.info_text().contains("full health"),
			"at full health an apple isn't wasted:\n%s" % RingMenu.info_text())
	kid.health.hp = 10
	_tap("interact")
	await _frames(2)
	_check(kid.health.hp == 10 + ItemData.find("apple").use_power, "confirm uses the apple on him (HP %d)" % kid.health.hp)
	var card: MemberCard = arena.get_node("HUD/SafeFrame/KidCard")
	_check(card.can_process(), "his HUD card keeps updating while the menu pauses the game (the heal shows at once)")
	_check(GameState.item_count("apple") == apples - 1, "one fewer apple (%d)" % GameState.item_count("apple"))
	_select("old_key")
	_tap("interact")
	await _frames(2)
	_tap("quick_1")
	await _frames(2)
	_check(GameState.quick_slots[0] != "item:old_key", "key items can't be used or put in a quick slot")
	# Using up the last of something: the selection moves to the next entry,
	# not one further along.
	GameState.inventory["soda"] = 1
	var list := RingMenu.entries().map(func(e: Dictionary) -> String: return e["key"])
	var soda_i := list.find("soda")
	var next_key: String = list[soda_i + 1]
	_select("soda")
	RingMenu._sel[RingMenu._key()] += list.size() * 2  # a spun-around (unwrapped) selection
	kid.health.hp = 1
	_tap("interact")
	await _frames(2)
	_check(GameState.item_count("soda") == 0 and RingMenu.selected().get("key") == next_key,
			"after the last soda the selection is on the next item (%s, expected %s)" % [RingMenu.selected().get("key"), next_key])
	kid.health.hp = kid.health.max_hp
	RingMenu.close()
	await _frames(2)


func _test_alchemy(arena: Node) -> void:
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	var heal := FormulaData.find("heal")
	_check(GameState.formulas.has("heal"), "the demo map teaches Heal")
	GameState.inventory["wild_carrot"] = 5
	RingMenu.open()
	RingMenu.set_ring(2)
	RingMenu.flip()  # cast on the dog
	await _frames(2)
	_check(RingMenu.who == "dog" and RingMenu.selected().get("key") == "heal", "the Alchemy ring, on the dog")
	dog.health.hp = 5
	_tap("interact")
	await _frames(2)
	_check(dog.health.hp == 5 + heal.power_at(1), "Heal heals the dog (HP %d)" % dog.health.hp)
	_check(GameState.item_count("wild_carrot") == 4, "and uses up a wild carrot (%d left)" % GameState.item_count("wild_carrot"))
	_check(Usables.xp_of("heal") == 1, "casting earns experience (%d)" % Usables.xp_of("heal"))
	for i in 2:
		dog.health.hp = 5
		_tap("interact")
		await _frames(2)
	_check(Usables.level_of("heal") == 2, "three casts: Heal reaches level 2 (Lv %d)" % Usables.level_of("heal"))
	dog.health.hp = 5
	_tap("interact")
	await _frames(2)
	_check(dog.health.hp == 5 + heal.power_at(2) and heal.power_at(2) > heal.power_at(1), "and heals more (HP %d)" % dog.health.hp)
	GameState.inventory["wild_carrot"] = 0
	dog.health.hp = 5
	_tap("interact")
	await _frames(2)
	_check(dog.health.hp == 5 and RingMenu.info_text().contains("Not enough wild carrot"),
			"no carrots, no Heal, and it says why:\n%s" % RingMenu.info_text())
	RingMenu.close()
	await _frames(2)
	GameState.inventory["wild_carrot"] = 2
	kid.health.hp = 0
	kid.downed = true
	_check(Usables.cast("heal", dog) != "", "a knocked-out kid can't cast")
	_check(GameState.item_count("wild_carrot") == 2, "and nothing is used up")
	kid.downed = false
	kid.health.revive(1.0)
	dog.health.hp = dog.health.max_hp


func _test_party(_arena: Node) -> void:
	GameState.dog_stance = "offensive"
	RingMenu.open()
	RingMenu.set_ring(3)
	await _frames(2)
	_select("dog_stance")
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	await _frames(2)
	_check(GameState.dog_stance == "search", "down changes the dog's stance (%s)" % GameState.dog_stance)
	_select("kid_stance")
	Input.action_press("move_down")
	await _frames(3)
	Input.action_release("move_down")
	await _frames(2)
	_check(GameState.kid_stance == "defensive", "and the kid's (%s)" % GameState.kid_stance)
	_select("stay")
	Input.action_press("move_up")
	await _frames(3)
	Input.action_release("move_up")
	await _frames(2)
	_check(Party.staying, "and Stay put")
	RingMenu.cycle(1)
	_check(not Party.staying, "(off again)")
	RingMenu.close()
	GameState.dog_stance = "offensive"
	GameState.kid_stance = "offensive"
	await _frames(2)


func _test_quick_slots(arena: Node) -> void:
	var kid: Kid = arena.get_node("World/Kid")
	var dog: Dog = arena.get_node("World/Dog")
	var hud := arena.get_node("HUD")
	GameState.quick_slots.assign(["", "", "", ""])
	GameState.inventory["apple"] = 3
	GameState.inventory["wild_carrot"] = 3
	# Assign from the ring.
	RingMenu.open()
	RingMenu.set_ring(1)
	_select("apple")
	_tap("quick_1")
	await _frames(2)
	RingMenu.set_ring(2)
	_select("heal")
	_tap("quick_2")
	await _frames(2)
	_check(GameState.quick_slots[0] == "item:apple" and GameState.quick_slots[1] == "formula:heal",
			"1 and 2 in the ring put the apple and Heal in quick slots (%s)" % [GameState.quick_slots])
	_tap("quick_3")
	await _frames(2)
	_check(GameState.quick_slots[1] == "" and GameState.quick_slots[2] == "formula:heal", "an entry lives in one slot: assigning it again moves it")
	RingMenu.close()
	await _frames(2)
	var bar: QuickBar = hud.get_node("SafeFrame/QuickBar")
	_check(QuickBar.slot_view(0)[1] == 3 and QuickBar.slot_view(1).is_empty(), "the HUD bar shows the apple (3) and an empty slot")
	_check(bar.visible, "the bar is on the HUD")
	# Fire them.
	kid.health.hp = 10
	_tap("quick_1")
	await _frames(2)
	_check(kid.health.hp == 22 and GameState.item_count("apple") == 2, "1 eats an apple, outside the menu (HP %d)" % kid.health.hp)
	_tap("quick_3")
	await _frames(2)
	_check(kid.health.hp > 22 and GameState.item_count("wild_carrot") == 2, "3 casts Heal on him (HP %d)" % kid.health.hp)
	_notices.clear()
	_tap("quick_2")
	await _frames(2)
	_check(_notices.size() == 1 and _notices[0].contains("empty"), "an empty slot says so (%s)" % [_notices])
	_check(String(hud.notice_text()).contains("empty"), "on the HUD, on its own line ('%s')" % hud.notice_text())
	# Driving the dog: the slot is used on him.
	_tap("switch_control")
	await _frames(2)
	dog.health.hp = 5
	_tap("quick_1")
	await _frames(2)
	_check(dog.health.hp == 17, "driving the dog, the slot heals him (HP %d)" % dog.health.hp)
	_tap("switch_control")
	await _frames(2)
	# Not mid-conversation.
	kid.health.hp = 10
	Dialogue.start("res://data/dialogue/prologue.dlg", "dinner_okay")
	_tap("quick_1")
	await _frames(2)
	_check(kid.health.hp == 10, "nothing fires mid-conversation")
	Dialogue._finish()
	await _frames(2)
	kid.health.hp = kid.health.max_hp
	dog.health.hp = dog.health.max_hp


func _test_controls() -> void:
	for dir in ["up", "down", "left", "right"]:
		_check(InputSetup.bindings_of("move_" + dir)["buttons"].is_empty(), "the D-pad doesn't move any more (move_%s)" % dir)
	_check(InputSetup.bindings_of("quick_1")["buttons"] == [JOY_BUTTON_DPAD_UP], "D-pad up is quick slot 1")
	# An old save with the D-pad still on movement.
	Settings._controls["move_up"] = {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_DPAD_UP]}
	Settings._apply_all()
	_check(not InputSetup.bindings_of("move_up")["buttons"].has(JOY_BUTTON_DPAD_UP), "an old save's movement gives the D-pad up")
	_check(InputSetup.bindings_of("quick_1")["buttons"] == [JOY_BUTTON_DPAD_UP], "to the quick slot")
	Settings._controls.erase("move_up")
	InputSetup.set_bindings("move_up", {"keys": [KEY_W, KEY_UP], "buttons": []})
	# Dialogue choices take the menu keys (the D-pad's ui_down).
	var box: DialogueBox = Dialogue.get_box()
	box.show_line("Dad", "Pick one.", null)
	box.show_choices(PackedStringArray(["Why?", "Okay."]))
	await _frames(1)
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	box._unhandled_input(down)
	_check(box._selected == 1, "dialogue choices move with the menu keys")
	box.hide_box()
	await _frames(2)


# -----------------------------------------------------------------------------
## Turn the open ring to the entry with this key.
func _select(key: String) -> void:
	var list := RingMenu.entries()
	for i in list.size():
		if list[i]["key"] == key:
			RingMenu._sel[RingMenu._key()] = i
			RingMenu._refresh()
			return
	_failures.append("(no '%s' in the %s ring)" % [key, RingMenu.ring_id()])


func _load(path: String) -> Node:
	var scene: Node = load(path).instantiate()
	add_child(scene)
	await _frames(8)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	return scene


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)


## Process frames: physics stops while the menu pauses the game.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
