# =============================================================================
# smoke_items.gd  -  Headless checks for hidden items and the dog's nose
# -----------------------------------------------------------------------------
# WHAT:  1. The test yard places its HIDDEN_ITEMS: buried and tucked ones as
#           HiddenItems, the secret one lying in plain sight; 0/5 found
#        2. A buried item is invisible to the kid: nothing to interact with
#        3. The dog on Search finds a buried item by himself: walks over,
#           barks, digs; it hops out toward the kid; the dog doesn't grab it;
#           the kid does: inventory, found flag, "Found Old key  1/5 here"
#        4. On Offensive, or with the kid far away (leash), he leaves it alone
#        5. Tucked: the kid searches the bush (prompt "Search"); the dog on
#           Search points at it but never digs it up
#        6. Driving the dog: no dig before he's smelled the spot; sniff (C)
#           shows scent trails to the nearest few (an item among them), then
#           E digs it up; it lands past the hole and he grabs it on touch
#        7. The secret item: walk over it
#        8. Found items stay found: reloading the yard doesn't bring them back;
#           the pause menu shows "Hidden items: 5 / 5"
#        9. HD-2D: a popped item gets a 3D sprite in the same frame, and its hop
#           (the sprite offset) reaches the 3D sprite
#       10. Interruptions: a stance change mid-dig doesn't leave his nose
#           stuck; nothing is dug up or picked up mid-conversation
#       11. HIDDEN_ITEMS mistakes (unknown item, on a fence, tucked with no
#           prop) fail loudly
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_items.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const RAT := preload("res://data/enemies/rat.tres")
const YARD_HD := "res://realms/big_yard/yard_hd.tscn"
const TILE := 32
## The yard's hidden items (realms/big_yard/prototype_yard.gd HIDDEN_ITEMS).
const KEY_CELL := Vector2i(9, 3)  # buried old_key
const STONE_CELL := Vector2i(16, 8)  # tucked shiny_stone (under a bush)
const POUCH_CELL := Vector2i(10, 11)  # secret coin_pouch
const MAP_CELL := Vector2i(36, 10)  # tucked torn_map (under a rock)
const CARROT_CELL := Vector2i(30, 14)  # buried wild_carrot x2

var _failures: PackedStringArray = []
var _sounds: Array[String] = []
var _sniffed: Array = []


func _ready() -> void:
	Audio.played.connect(func(s: String) -> void: _sounds.append(s))
	EventBus.dog_sniffed.connect(func(t: Array) -> void: _sniffed = t)
	_run.call_deferred()


func _run() -> void:
	await _test_placement_and_ai_dig()
	await _test_stance_and_leash()
	await _test_tucked()
	await _test_driving_the_dog()
	await _test_secret_and_persistence()
	await _test_interruptions()
	await _test_idle_yields_to_a_find()
	await _test_validation()
	GameState.dog_stance = "offensive"
	if _failures.is_empty():
		print("[TEST] PASS  smoke_items")
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


# -----------------------------------------------------------------------------
func _test_placement_and_ai_dig() -> void:
	var s := await _load()
	var realm: AsciiRealm = s.get_node("Yard")
	var kid: Kid = s.get_node("Yard/World/Kid")
	var dog: Dog = s.get_node("Yard/World/Dog")
	var hd: HdView = s.get_node("HdView")

	var buried := 0
	var tucked := 0
	for h: HiddenItem in get_tree().get_nodes_in_group("hidden_item"):
		buried += 1 if h.kind == "buried" else 0
		tucked += 1 if h.kind == "tucked" else 0
	_check(buried == 2 and tucked == 2, "the yard hides 2 buried and 2 tucked items (got %d, %d)" % [buried, tucked])
	_check(get_tree().get_nodes_in_group("item_pickup").size() == 1, "and one secret item lies in a nook")
	_check(realm.hidden_counts() == Vector2i(0, 5), "0/5 found to start (%s)" % realm.hidden_counts())

	# The kid stands on the buried key: nothing to find without the dog.
	var key := _hidden_at(KEY_CELL)
	GameState.dog_stance = "offensive"
	_place(kid, key.global_position + Vector2(0, 2), Vector2.UP)
	_place(dog, key.global_position + Vector2(-90, 30))
	await _frames(3)
	_check(Interaction.current_target() != key, "a buried item can't be found by the kid")

	# Search stance: the dog finds it by himself.
	_place(kid, key.global_position + Vector2(0, 40), Vector2.UP)
	_place(dog, key.global_position + Vector2(-90, 30))
	dog.warp_to_target()
	_place(dog, key.global_position + Vector2(-90, 30))
	_sounds.clear()
	var hole := key.global_position
	GameState.dog_stance = "search"
	var went := false
	var dug := false
	var dsprite: AnimalSprite = dog.get_node("Sprite")
	var rest_offset := dsprite.offset
	var wrong_anim := 0
	var dig_frames := {}     # sheet columns the 2D sprite showed while digging
	var hd_cols := {}        # columns the HD Sprite3D copy showed
	var offsets := {}        # body positions (the scrape)
	var hd_offsets := {}
	for i in 360:
		await _frames(1)
		went = went or dog.nose.mode == Nose.Mode.GO
		dug = dug or dog.is_digging()
		if dog.is_digging():
			if dsprite.current != &"dig":
				wrong_anim += 1
			dig_frames[dsprite.frame_coords.x] = true
			offsets[dsprite.offset] = true
			var d3: Sprite3D = hd._mirrored.get(dog.get_instance_id())
			if d3:
				hd_cols[d3.frame_coords.x] = true
				hd_offsets[d3.offset] = true
		if not is_instance_valid(key):
			break
	_check(went, "on Search the dog goes for the buried item")
	_check(_sounds.has("dog_bark"), "he barks when he gets there")
	_check(dug and _sounds.has("dig"), "and digs it up")
	# The dig reads as digging (owner: "there is no dog digging animation"):
	# the dig animation plays the whole time, in head-low frames only, the body
	# rocks into the hole, and the HD-2D sprite copy shows the same.
	_check(wrong_anim == 0 and not dig_frames.is_empty(), "the dog plays 'dig' the whole time he digs (%d frames off)" % wrong_anim)
	_check(dig_frames.size() >= 3 and dig_frames.keys().all(func(c: int) -> bool: return c >= 5), "dig cycles 3+ head-low frames: %s" % [dig_frames.keys()])
	_check(offsets.size() >= 3, "the body rocks while digging (%d positions)" % offsets.size())
	_check(hd_cols.size() >= 3 and hd_cols.keys().all(func(c: int) -> bool: return c >= 5), "HD-2D copy shows the dig frames: %s" % [hd_cols.keys()])
	_check(hd_offsets.size() >= 3, "HD-2D copy shows the rocking body (%d positions)" % hd_offsets.size())
	_check(dsprite.offset == rest_offset, "the body settles back after the dig (%s vs %s)" % [dsprite.offset, rest_offset])
	_check(not is_instance_valid(key), "the hidden item is gone once dug up")
	var pickup := _pickup_of("old_key")
	_check(pickup != null, "the key pops out as a pickup")
	if pickup == null:
		s.queue_free()
		await _frames(2)
		return
	# HD-2D: mirrored at once, and the hop reaches the 3D sprite.
	var s3: Sprite3D = hd._mirrored.get(pickup.get_instance_id())
	_check(s3 != null, "HD-2D: the popped item has a 3D sprite")
	await _frames(15)  # mid-hop
	if s3:
		_check(s3.offset.y > -ItemPickup.REST_OFFSET.y + 8.0, "HD-2D: the 3D sprite hops with it (offset %.1f)" % s3.offset.y)
	await _wait(0.6)
	_check(is_instance_valid(pickup), "nobody grabs it while it lands (the dog is right there)")
	if not is_instance_valid(pickup):
		s.queue_free()
		await _frames(2)
		return
	var gap_before := hole.distance_to(kid.global_position)
	var gap := pickup.global_position.distance_to(kid.global_position)
	_check(gap < gap_before - 10.0 and gap > ItemPickup.GRAB_RADIUS,
			"it lands toward the kid, short of him (%.0f px from him, the hole was %.0f)" % [gap, gap_before])
	# The dog standing on it doesn't take it: it's yours to pick up.
	GameState.dog_stance = "offensive"
	dog.set_physics_process(false)
	dog.global_position = pickup.global_position
	await _wait(0.3)
	_check(is_instance_valid(pickup), "the AI dog doesn't grab what he dug up")
	dog.set_physics_process(true)
	_place(kid, pickup.global_position + Vector2(0, 4), Vector2.UP)
	await _frames(3)
	_check(not is_instance_valid(pickup), "the kid picks it up by walking over it")
	_check(GameState.item_count("old_key") == 1, "it's in the inventory")
	_check(GameState.get_flag(realm.hidden_key(KEY_CELL)), "its found flag is set")
	_check(_sounds.has("pickup"), "with the pickup sound")
	var toast: String = s.get_node("Yard/HUD").toast_text()
	_check(toast.begins_with("Found Old key") and toast.ends_with("1/5 here"), "the HUD says what was found and how many here ('%s')" % toast)
	s.queue_free()
	await _frames(2)


func _test_stance_and_leash() -> void:
	var s := await _load()
	var kid: Kid = s.get_node("Yard/World/Kid")
	var dog: Dog = s.get_node("Yard/World/Dog")
	var carrot := _hidden_at(CARROT_CELL)
	# Offensive, calm: he notices it too (owner 2026-10-09: any stance), but
	# not while a rat is awake and about.
	GameState.dog_stance = "offensive"
	_place(kid, carrot.global_position + Vector2(-20, 40), Vector2.UP)
	_place(dog, carrot.global_position + Vector2(-60, 40))
	var rat := Enemy.create(RAT, kid.global_position + Vector2(0, -190))
	s.get_node("Yard/World").add_child(rat)
	rat.set_physics_process(false)
	rat.state = Enemy.State.RECOVER  # awake and holding still
	var busy := false
	for i in 120:
		await _frames(1)
		busy = busy or dog.nose.busy()
	_check(not busy and is_instance_valid(carrot), "Offensive with a rat awake nearby: the dog leaves hidden items alone")
	rat.queue_free()
	var pointed := false
	var barked := _sounds.size()
	for i in 240:
		await _frames(1)
		pointed = pointed or dog.nose.mode == Nose.Mode.POINT
		if not is_instance_valid(carrot):
			break
	_check(pointed and _sounds.slice(barked).has("dog_bark"), "Offensive and calm: he trots over, points and barks")
	_check(dog.nose.mode == Nose.Mode.NONE or dog.is_digging() or not is_instance_valid(carrot), "and digs it up")
	s.queue_free()
	await _frames(2)
	s = await _load()
	kid = s.get_node("Yard/World/Kid")
	dog = s.get_node("Yard/World/Dog")
	carrot = _hidden_at(CARROT_CELL)
	# Calm Offensive reaches less far than Search: 170 px from the dog is out
	# of his notice, in range of Search's.
	dog.set_physics_process(false)  # drive his nose by hand: he'd walk closer
	_place(kid, carrot.global_position + Vector2(-20, 40), Vector2.UP)
	_place(dog, carrot.global_position + Vector2(-170, 0))
	dog.nose.think(1.0, kid, false)
	_check(dog.nose.mode == Nose.Mode.NONE, "calm, any stance: he notices items only near him (%d px), not 170 away" % int(Nose.NOTICE_RADIUS))
	dog.nose.think(1.0, kid, true)
	_check(dog.nose.mode == Nose.Mode.GO, "Search reaches farther (%d px): the same item gets noticed" % int(Nose.NOTICE_RADIUS_SEARCH))
	s.queue_free()
	await _frames(2)
	s = await _load()
	kid = s.get_node("Yard/World/Kid")
	dog = s.get_node("Yard/World/Dog")
	carrot = _hidden_at(CARROT_CELL)
	# Search, but the kid is far off: the leash wins.
	GameState.dog_stance = "search"
	_place(kid, carrot.global_position + Vector2(-260, 40), Vector2.UP)
	_place(dog, carrot.global_position + Vector2(-110, 40))
	dog.warp_to_target()
	_place(dog, carrot.global_position + Vector2(-110, 40))
	busy = false
	for i in 120:
		await _frames(1)
		busy = busy or dog.nose.busy()
	_check(not busy, "on Search he leaves items far from the kid alone (leash)")
	GameState.dog_stance = "offensive"
	s.queue_free()
	await _frames(2)


func _test_tucked() -> void:
	var s := await _load()
	var kid: Kid = s.get_node("Yard/World/Kid")
	var dog: Dog = s.get_node("Yard/World/Dog")
	# The dog on Search points at the torn map under the rock; never digs.
	var map := _hidden_at(MAP_CELL)
	GameState.dog_stance = "search"
	_place(kid, map.global_position + Vector2(-70, 40), Vector2.RIGHT)
	_place(dog, map.global_position + Vector2(-100, 30))
	dog.warp_to_target()
	_place(dog, map.global_position + Vector2(-100, 30))
	var dug := false
	for i in 240:
		await _frames(1)
		dug = dug or dog.is_digging()
		if map.pointed:
			break
	_check(map.pointed, "the dog on Search points out a tucked item")
	_check(not dug and is_instance_valid(map), "but doesn't dig it out from under the rock")
	GameState.dog_stance = "offensive"

	# The kid searches the bush.
	var stone := _hidden_at(STONE_CELL)
	_place(kid, stone.global_position + Vector2(0, 26), Vector2.UP)
	await _frames(3)
	_check(Interaction.current_target() == stone, "next to the bush, the kid can search it")
	_check(stone.interact_label() == "Search", "the prompt says Search")
	_check(not stone.can_interact(dog), "the dog can't dig under a bush")
	_tap("interact")
	await _wait(0.8)
	_check(not is_instance_valid(stone), "searching finds the item")
	_check(GameState.item_count("shiny_stone") == 1, "it hops out to the kid, who grabs it")
	s.queue_free()
	await _frames(2)


func _test_driving_the_dog() -> void:
	var s := await _load()
	var kid: Kid = s.get_node("Yard/World/Kid")
	var dog: Dog = s.get_node("Yard/World/Dog")
	var carrot := _hidden_at(CARROT_CELL)
	kid.set_physics_process(false)  # just you and the dog
	Party.switch_control()
	await _frames(2)
	_place(dog, carrot.global_position + Vector2(-8, 4), Vector2.RIGHT)
	await _frames(3)
	_check(Interaction.current_target() == null, "driving the dog: no digging before he's smelled the spot")
	_sniffed = []
	var carrots_before := GameState.item_count("wild_carrot")  # the demo kit has some
	_tap("sniff")
	await _frames(3)
	var trails := Fx.scent_trails().size()
	_check(trails > 0 and trails <= Nose.TRAILS, "sniff shows scent trails to the nearest few (%d)" % trails)
	_check(_sniffed.has(carrot), "one of them leads to the buried carrot")
	_check(carrot.sniffed, "and he's smelled it now")
	_check(not dog.is_digging() and is_instance_valid(carrot), "sniffing doesn't dig")
	await _wait(Dog.SNIFF_SECONDS + 0.1)
	await _frames(2)
	_check(Interaction.current_target() == carrot, "now he can dig there")
	_tap("interact")
	await _frames(2)
	_check(dog.is_digging(), "E digs")
	await _wait(Dog.DIG_SECONDS + 0.2)
	var pickup := _pickup_of("wild_carrot")
	_check(pickup != null, "the carrot comes up")
	if pickup:
		await _wait(0.6)
		var d := pickup.global_position.distance_to(dog.global_position)
		_check(is_instance_valid(pickup) and d > ItemPickup.GRAB_RADIUS, "it lands past the hole where you can see it (%.0f px)" % d)
		_place(dog, pickup.global_position)
		await _frames(3)
		_check(not is_instance_valid(pickup), "the dog you drive grabs it")
	_check(GameState.item_count("wild_carrot") == carrots_before + 2, "two more carrots in the bag (%d, was %d)" % [GameState.item_count("wild_carrot"), carrots_before])
	await _wait(Nose.TRAIL_SECONDS)
	_check(Fx.scent_trails().is_empty(), "the trails fade after a while")
	Party.switch_control()
	s.queue_free()
	await _frames(2)


func _test_secret_and_persistence() -> void:
	var s := await _load()
	var realm: AsciiRealm = s.get_node("Yard")
	var kid: Kid = s.get_node("Yard/World/Kid")
	_check(realm.hidden_counts() == Vector2i(3, 5), "found items stay found: 3/5 (%s)" % realm.hidden_counts())
	_check(_hidden_at(KEY_CELL) == null and _hidden_at(STONE_CELL) == null and _hidden_at(CARROT_CELL) == null,
			"and don't come back when the yard reloads")
	var map := _hidden_at(MAP_CELL)
	_check(map != null and not map.pointed, "the unfound ones are back as they were")
	var pouch := _pickup_of("coin_pouch")
	_check(pouch != null, "the secret pouch lies in its nook")
	if pouch:
		_place(kid, pouch.global_position + Vector2(0, 3), Vector2.UP)
		await _frames(3)
		_check(GameState.item_count("coin_pouch") == 1, "walk over it to take it")
	if map:
		# HD-2D: a revealed item is in the 3D view in the same frame, not at
		# HdView's next scan (which would miss the start of the hop).
		var hd: HdView = s.get_node("HdView")
		var popped := map.reveal(kid.global_position)
		_check(popped != null and hd._mirrored.has(popped.get_instance_id()), "HD-2D: a revealed item gets its 3D sprite in the same frame")
		await _wait(0.7)
		var p := _pickup_of("torn_map")
		if p:
			p.collect()
	await _frames(2)
	_check(realm.hidden_counts() == Vector2i(5, 5), "all found: 5/5 (%s)" % realm.hidden_counts())
	PauseMenu.open()
	await get_tree().process_frame
	_check(PauseMenu.found_text() == "Hidden items: 5 / 5", "the pause menu shows the count ('%s')" % PauseMenu.found_text())
	PauseMenu.close()
	s.queue_free()
	await _frames(2)


## Things that cut a find short: a stance change mid-dig, a conversation.
func _test_interruptions() -> void:
	GameState._flags.clear()
	var s := await _load()
	var kid: Kid = s.get_node("Yard/World/Kid")
	var dog: Dog = s.get_node("Yard/World/Dog")
	var key := _hidden_at(KEY_CELL)
	_place(kid, key.global_position + Vector2(0, 40), Vector2.UP)
	_place(dog, key.global_position + Vector2(-60, 30))
	dog.warp_to_target()
	_place(dog, key.global_position + Vector2(-60, 30))
	GameState.dog_stance = "search"
	for i in 300:
		await _frames(1)
		if dog.is_digging():
			break
	_check(dog.is_digging(), "(setup) the dog starts digging")
	GameState.dog_stance = "offensive"
	await _wait(Dog.DIG_SECONDS + 0.5)
	_check(_pickup_of("old_key") != null, "a dig under way finishes when his stance changes")
	_check(not dog.nose.busy(), "and his nose lets go afterwards (not stuck digging)")
	s.queue_free()
	await _frames(2)

	# A conversation: the dog doesn't wander off to dig, nobody picks up.
	GameState._flags.clear()
	s = await _load()
	kid = s.get_node("Yard/World/Kid")
	dog = s.get_node("Yard/World/Dog")
	key = _hidden_at(KEY_CELL)
	_place(kid, key.global_position + Vector2(0, 40), Vector2.UP)
	_place(dog, key.global_position + Vector2(-60, 30))
	dog.warp_to_target()
	_place(dog, key.global_position + Vector2(-60, 30))
	GameState.dog_stance = "search"
	var started := Dialogue.start("res://data/dialogue/prologue.dlg", "dinner_okay")
	_check(started, "(setup) a conversation starts")
	var busy := false
	for i in 150:
		await _frames(1)
		busy = busy or dog.nose.busy() or dog.is_digging()
	_check(not busy and is_instance_valid(key), "the dog doesn't go digging mid-conversation")
	var p := ItemPickup.create(ItemData.find("torn_map"), 1, "", kid.global_position)
	s.get_node("Yard/World").add_child(p)
	await _frames(3)
	_check(is_instance_valid(p), "nothing is picked up mid-conversation")
	Dialogue._finish()
	await _frames(3)
	_check(not is_instance_valid(p), "it's picked up once the talking ends")
	GameState.dog_stance = "offensive"
	s.queue_free()
	await _frames(2)


## The dog's cosmetic sitting and ambient sniffing never beat the real thing:
## sat down mid-sniff next to a buried key, he still goes, points, barks, digs.
func _test_idle_yields_to_a_find() -> void:
	GameState._flags.clear()
	var s := await _load()
	var kid: Kid = s.get_node("Yard/World/Kid")
	var dog: Dog = s.get_node("Yard/World/Dog")
	var key := _hidden_at(KEY_CELL)
	_place(kid, key.global_position + Vector2(0, 40), Vector2.UP)
	_place(dog, key.global_position + Vector2(-60, 30))
	dog.warp_to_target()
	_place(dog, key.global_position + Vector2(-60, 30))
	GameState.dog_stance = "offensive"
	dog.idle.mode = DogIdle.Mode.SIT
	_sounds.clear()
	var went := false
	for i in 400:
		await _frames(1)
		went = went or dog.nose.mode == Nose.Mode.GO
		if dog.is_digging():
			break
	_check(went and dog.is_digging(), "a sitting dog still goes for a real hidden item and digs it")
	_check(not dog.idle.sitting() and _sounds.has("dog_bark"), "he got up for it and barked")
	s.queue_free()
	await _frames(2)


## A HIDDEN_ITEMS entry naming an item that doesn't exist fails loudly.
func _test_validation() -> void:
	var s := await _load()
	var realm: AsciiRealm = s.get_node("Yard")
	_check(realm._validate_hidden(), "the yard's own list is valid")
	realm._cfg["HIDDEN_ITEMS"] = [{"cell": KEY_CELL, "kind": "buried", "item": "no_such_item"}]
	_check(not realm._validate_hidden(), "an unknown item id is an error, not a 0/1 you can't finish")
	realm._cfg["HIDDEN_ITEMS"] = [{"cell": Vector2i(0, 0), "kind": "buried", "item": "old_key"}]
	_check(not realm._validate_hidden(), "a buried item on a fence is an error")
	realm._cfg["HIDDEN_ITEMS"] = [{"cell": KEY_CELL, "kind": "tucked", "item": "old_key"}]
	_check(not realm._validate_hidden(), "a tucked item with no prop is an error")
	s.queue_free()
	await _frames(2)


# -----------------------------------------------------------------------------
func _load() -> Node:
	var scene: Node = load(YARD_HD).instantiate()
	add_child(scene)
	await _frames(10)
	return scene


func _hidden_at(cell: Vector2i) -> HiddenItem:
	var center := Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE * 0.5)
	for h: HiddenItem in get_tree().get_nodes_in_group("hidden_item"):
		if h.global_position.distance_to(center) < 20.0:
			return h
	return null


func _pickup_of(item_id: String) -> ItemPickup:
	for p: ItemPickup in get_tree().get_nodes_in_group("item_pickup"):
		if p.item and p.item.id == item_id and not p.is_queued_for_deletion():
			return p
	return null


func _place(who: Node2D, at: Vector2, facing := Vector2.ZERO) -> void:
	who.global_position = at
	who.velocity = Vector2.ZERO
	if facing != Vector2.ZERO:
		who.facing = facing


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
