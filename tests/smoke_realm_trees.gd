# =============================================================================
# smoke_realm_trees.gd  -  No tree on or beside a path, in every realm
# -----------------------------------------------------------------------------
# WHAT:  Owner, 2026-10-09: "no trees on paths/roads". For the street, the yard
#        and the arena, builds the realm and checks that every tree prop
#        (PropData.tree: the oaks), in the map AND in the apron woods, keeps
#        clear of every path cell (dirt, and the roads exits run over beyond
#        the edge): none on one, none within AsciiRealm.TREE_PATH_SIDE cells
#        beside it, TREE_PATH_NORTH above (where the canopy hangs) or
#        TREE_PATH_SOUTH below. Also fails if the realm had to drop a LAYOUT
#        tree for it (fix the layout instead of relying on the drop).
# HOW:   Independent of AsciiRealm.tree_blocked: rebuilds the path set from the
#        raw LAYOUT and the road cells, and measures from each placed tree.
#
# RUN:   godot --headless --path . --audio-driver Dummy --fixed-fps 60 res://tests/smoke_realm_trees.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const REALMS := [
	"res://realms/podunk/ruffleberg_lot.tscn",
	"res://realms/big_yard/prototype_yard.tscn",
	"res://realms/test/combat_arena.tscn",
]

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var total := 0
	for path: String in REALMS:
		var scene: Node = (load(path) as PackedScene).instantiate()
		if "skip_intro" in scene:
			scene.skip_intro = true
		add_child(scene)
		for i in 3:
			await get_tree().process_frame
		var realm := get_tree().get_first_node_in_group("ascii_realm") as AsciiRealm
		if realm == null:
			_failures.append("%s: no AsciiRealm" % path)
			scene.queue_free()
			continue
		total += _check_realm(realm, path)
		scene.queue_free()
		await get_tree().process_frame
	if _failures.is_empty():
		print("[TEST] PASS  smoke_realm_trees  (%d trees in %d realms)" % [total, REALMS.size()])
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


func _check_realm(realm: AsciiRealm, label: String) -> int:
	# The path set, from the raw layout (not from the realm's own cache).
	var terrain: Dictionary = realm.cfg("TERRAIN_BY_CHAR")
	var paths := {}
	for y in realm.layout.size():
		for x in realm.layout[y].length():
			if terrain.get(realm.layout[y][x], "") == "Dirt":
				paths[Vector2i(x, y)] = true
	for c: Vector2i in realm._exit_path_cells():
		paths[c] = true
	_check(paths.size() > 0, "%s: found no path cells (test is blind)" % label)
	var trees := 0
	var bad := 0
	for p: Prop in realm.find_children("*", "Prop", true, false):
		if p.data == null or not p.data.tree:
			continue
		trees += 1
		var cell := Vector2i(floori(p.global_position.x / AsciiRealm.TILE), floori(p.global_position.y / AsciiRealm.TILE))
		var hit := false
		for dy in range(-AsciiRealm.TREE_PATH_NORTH, AsciiRealm.TREE_PATH_SOUTH + 1):
			for dx in range(-AsciiRealm.TREE_PATH_SIDE, AsciiRealm.TREE_PATH_SIDE + 1):
				hit = hit or paths.has(cell + Vector2i(dx, dy))
		if hit:
			bad += 1
			if bad <= 5:
				_failures.append("%s: tree %s at cell %s is on or beside a path" % [label, p.data.resource_path.get_file(), cell])
	_check(trees > 20, "%s: only %d trees (apron woods missing?)" % [label, trees])
	_check(bad == 0, "%s: %d trees on or beside a path" % [label, bad])
	_check(int(realm._counts.get("trees_dropped", 0)) == 0,
			"%s: %d LAYOUT trees were dropped for being near a path, move them in the layout" % [label, realm._counts.get("trees_dropped", 0)])
	return trees


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
