# =============================================================================
# ascii_realm.gd  -  Builds a playable map from an ASCII layout (base class)
# -----------------------------------------------------------------------------
# WHAT:  Turns a LAYOUT of characters into a map: autotiled ground and water
#        (WangAutotiler + an LPC Revised tileset), fences, props, NPCs,
#        dialogue triggers, scattered decals, and an apron of scenery past the
#        edges for wide screens. Each realm is a small subclass that declares
#        CONSTANTS; anything it leaves out uses DEFAULTS below.
#
#          extends AsciiRealm
#          const LAYOUT: Array[String] = ["####", "#K.#", ...]
#          const PROPS_BY_CHAR := {"T": ["oak_a"]}
#
# WHY CONSTANTS: a realm reads like a data file, the test yard and the
#        prologue share every line of builder code, and tests/HdView can read
#        a realm's LAYOUT without instancing it.
#
# LEGEND (shared by every realm; a realm can add more through its tables):
#   .  grass (sometimes a decal)   K  kid spawn     D  dog spawn
#   any key of TERRAIN_BY_CHAR     ground of that terrain (":" dirt, "~" water)
#   any key of FENCES              a fence of that kind ("#" wood by default)
#   any key of PROPS_BY_CHAR       one of those props (picked per cell)
#   any key of NPCS_BY_CHAR        an NPC who stands there
#   any key of TRIGGERS_BY_CHAR    walking onto it starts a conversation
#   any key of ENEMIES_BY_CHAR     an enemy (data/enemies/<id>.tres) waits there
#
# SCENE: the realm's .tscn needs Ground, Water (TileMapLayers), Solids
#        (StaticBody2D), Occluders (Node2D), World (y_sort) with World/Fences,
#        World/Kid and World/Dog, plus Atmosphere and HUD.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name AsciiRealm
extends Node2D

const TILE := 32
const NPC_SCENE := preload("res://actors/npc/npc.tscn")

## Settings a realm doesn't declare. Keys match the constant names.
const DEFAULTS := {
	"WANG_JSON": "res://data/tilesets/lpc_summer_wang.json",
	"PROP_DIR": "res://data/props/big_yard/",
	"TERRAIN_SET": "Summer Terrain",
	"TERRAIN_BY_CHAR": {":": "Dirt", "~": "Shallow Water"},
	## Music track for this map (autoload/audio.gd MUSIC). "" = silence.
	"MUSIC": "",
	"TERRAIN_PRIORITY": ["Grass", "Dirt", "Shallow Water"],
	"SOLID_CHARS": "~",
	"WATER_EDGE_PX": 11,
	## Fence character -> terrain name in the tileset's "Fences" edge set.
	"FENCES": {"#": "Wood Fence"},
	## Fence terrain -> how HdView builds it in 3D ("wood" or "iron").
	"HD_FENCE_STYLES": {"Wood Fence": "wood", "Metal Fence": "iron"},
	"FENCE_SORT_ORIGIN": 13,
	"PROPS_BY_CHAR": {},
	## Props placed exactly on their cell (big ones); others get a small nudge.
	"BIG_PROP_CHARS": "TtR",
	"JITTER_PX": 5,
	"DECAL_DENSITY": 0.22,
	"DECALS": ["tuft_a", "tuft_b", "tuft_c", "tuft_d", "tuft_e", "tuft_f",
			"wildflowers_02", "wildflowers_03", "wildflowers_09", "wildflowers_10", "wildflowers_14", "wildflowers_18"],
	"LILIES": ["lily_big", "lily_small", "lily_mid", "lily_mid", "lily_flower"],
	"REEDS": ["reeds_a", "reeds_b", "reeds_c"],
	"LILY_DENSITY": 0.3,
	"REED_DENSITY": 0.4,
	## Scenery past the edges. Must cover (widest view - map width) / 2:
	## the widest sane view is 1920 px (48:9).
	"APRON_TILES": 14,
	"APRON_ROWS": 4,
	"APRON_TREES": ["oak_a", "oak_b", "oak_a", "oak_light", "bush_round_a", "shrub_b"],
	"APRON_SHRUBS": ["bush_round_a", "bush_round_b", "shrub_a", "shrub_c"],
	## Apron trees keep this far from the map (canopies are ~95 px wide, ~100 tall).
	"TREE_CLEARANCE_SIDE": 52,
	"TREE_CLEARANCE_BELOW": 112,
	## char -> {"id": "MAYA", "start": "maya", "facing": Vector2.DOWN}
	"NPCS_BY_CHAR": {},
	## char -> {"start": "gate", "once": true}
	"TRIGGERS_BY_CHAR": {},
	## char -> enemy id (data/enemies/<id>.tres)
	"ENEMIES_BY_CHAR": {},
	## The .dlg file NPCs and triggers in this realm talk from.
	"DIALOGUE": "",
	## names.json key of the realm's display name (log line, debug overlay).
	"REALM_NAME_KEY": "",
}

@onready var _ground: TileMapLayer = $Ground
@onready var _water: TileMapLayer = $Water
@onready var _solids: StaticBody2D = $Solids
@onready var _occluders: Node2D = $Occluders
@onready var _world: Node2D = $World
@onready var _fences: TileMapLayer = $World/Fences
@onready var _kid: Kid = $World/Kid
@onready var _dog: Dog = $World/Dog

var layout: Array = []
var _cfg: Dictionary = {}
var _tiler: WangAutotiler
var _prop_cache: Dictionary = {}
var _counts := {"props": 0, "decals": 0, "solids": 0, "npcs": 0, "triggers": 0, "enemies": 0}


func _ready() -> void:
	add_to_group("ascii_realm")
	_load_config()
	if not _validate_layout():
		return
	_tiler = WangAutotiler.load_json(cfg("WANG_JSON"))
	if _tiler == null:
		return
	_build_terrain()
	_build_fences()
	_build_cells()
	_dress_pond()
	_build_apron()
	_set_camera_limits()
	var key: String = cfg("REALM_NAME_KEY")
	if not key.is_empty():
		GameState.current_realm = key
	Audio.play_music(cfg("MUSIC"), 1.5)
	Debug.log_info("%s loaded (%dx%d tiles, %d props, %d decals, %d NPCs, %d enemies, %d solid shapes). Run with -- --help for options."
			% [Names.text(key) if not key.is_empty() else name, layout[0].length(), layout.size(),
			_counts["props"], _counts["decals"], _counts["npcs"], _counts["enemies"], _counts["solids"]])


## A setting: the realm's constant if it declared one, else the default.
func cfg(key: String) -> Variant:
	return _cfg.get(key, DEFAULTS.get(key))


## The playable map area in world pixels.
## What kind of ground is at a world position: "grass" or "stone" (dirt,
## paths and anything hard), for footstep sounds. Outside any realm: grass.
static func surface_at(tree: SceneTree, world_pos: Vector2) -> String:
	var realm := tree.get_first_node_in_group("ascii_realm") as AsciiRealm
	if realm == null:
		return "grass"
	var cell := Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))
	if cell.y < 0 or cell.y >= realm.layout.size() or cell.x < 0 or cell.x >= realm.layout[0].length():
		return "grass"
	var terrain: String = realm.cfg("TERRAIN_BY_CHAR").get(realm.layout[cell.y][cell.x], "Grass")
	return "grass" if terrain == "Grass" else "stone"


func map_rect() -> Rect2:
	return Rect2(0, 0, layout[0].length() * TILE, layout.size() * TILE)


## Every fence cell and its fence terrain ("Wood Fence", ...). HdView uses it.
func fence_cells() -> Dictionary:
	var fences: Dictionary = cfg("FENCES")
	var out := {}
	for y in layout.size():
		for x in layout[y].length():
			var ch: String = layout[y][x]
			if fences.has(ch):
				out[Vector2i(x, y)] = fences[ch]
	return out


func _load_config() -> void:
	_cfg = DEFAULTS.duplicate()
	var consts: Dictionary = get_script().get_script_constant_map()
	for key: String in consts:
		if DEFAULTS.has(key) or key == "LAYOUT":
			_cfg[key] = consts[key]
	# Older realms name a single fence character.
	if consts.has("FENCE_CHAR") and not consts.has("FENCES"):
		_cfg["FENCES"] = {consts["FENCE_CHAR"]: "Wood Fence"}
	layout = _cfg.get("LAYOUT", [])


# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
## Catches typos in LAYOUT before they become confusing in-game bugs.
func _validate_layout() -> bool:
	if layout.is_empty():
		Debug.log_error("%s: no LAYOUT constant" % name)
		return false
	var width: int = layout[0].length()
	var ok := true
	var known := ".KD" + "".join(cfg("TERRAIN_BY_CHAR").keys()) + "".join(cfg("FENCES").keys()) \
			+ "".join(cfg("PROPS_BY_CHAR").keys()) + "".join(cfg("NPCS_BY_CHAR").keys()) \
			+ "".join(cfg("TRIGGERS_BY_CHAR").keys()) + "".join(cfg("ENEMIES_BY_CHAR").keys())
	for y in layout.size():
		if layout[y].length() != width:
			Debug.log_error("LAYOUT row %d is %d chars wide, expected %d" % [y, layout[y].length(), width])
			ok = false
		for x in layout[y].length():
			if not known.contains(layout[y][x]):
				Debug.log_error("LAYOUT (%d,%d): unknown character '%s'" % [x, y, layout[y][x]])
				ok = false
	var joined := "".join(layout)
	for spawn in ["K", "D"]:
		if joined.count(spawn) != 1:
			Debug.log_error("LAYOUT needs exactly one %s, found %d" % [spawn, joined.count(spawn)])
			ok = false
	if not cfg("NPCS_BY_CHAR").is_empty() or not cfg("TRIGGERS_BY_CHAR").is_empty():
		if String(cfg("DIALOGUE")).is_empty():
			Debug.log_error("%s has NPCs or triggers but no DIALOGUE file" % name)
			ok = false
	return ok


# -----------------------------------------------------------------------------
# Terrain (ground + water layers)
# -----------------------------------------------------------------------------
func _build_terrain() -> void:
	var apron: int = cfg("APRON_TILES")
	var terrain_by_char: Dictionary = cfg("TERRAIN_BY_CHAR")
	# Per-cell terrain for the map plus the apron (apron = plain grass).
	var w: int = layout[0].length() + apron * 2
	var h: int = layout.size() + apron * 2
	var cells := []
	for y in h:
		var row := []
		for x in w:
			var mx := x - apron
			var my := y - apron
			var t := "Grass"
			if mx >= 0 and my >= 0 and my < layout.size() and mx < layout[0].length():
				t = terrain_by_char.get(layout[my][mx], "Grass")
			row.append(t)
		cells.append(row)
	var priority := PackedStringArray(cfg("TERRAIN_PRIORITY"))
	var verts := WangAutotiler.vertices_from_cells(cells, priority)
	var has_water := func(c: PackedStringArray) -> bool: return c.has("Shallow Water")
	var no_water := func(c: PackedStringArray) -> bool: return not c.has("Shallow Water")
	var set_name: String = cfg("TERRAIN_SET")
	_tiler.paint_corners(_ground, set_name, verts, priority, no_water)
	_tiler.paint_corners(_water, set_name, verts, priority, has_water)
	# Both layers were painted from (0,0) = top-left of the apron.
	var offset := Vector2(-apron * TILE, -apron * TILE)
	_ground.position = offset
	_water.position = offset
	# Solid ground (the pond): each horizontal run of solid cells becomes one
	# box, grown to where the water is DRAWN (the art spreads half a tile into
	# the bank), minus a few px so feet can touch the waterline.
	var solid_chars: String = cfg("SOLID_CHARS")
	var edge: int = cfg("WATER_EDGE_PX")
	for y in layout.size():
		var run_start := -1
		for x in layout[y].length() + 1:
			var solid: bool = x < layout[y].length() and solid_chars.contains(layout[y][x])
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				var r := Rect2(run_start * TILE, y * TILE, (x - run_start) * TILE, TILE)
				_add_solid(r.grow(edge))
				run_start = -1


# -----------------------------------------------------------------------------
# Fences
# -----------------------------------------------------------------------------
func _build_fences() -> void:
	var all := fence_cells()
	if all.is_empty():
		return
	# Every fence tile sorts by where its posts touch the ground.
	var origin: int = cfg("FENCE_SORT_ORIGIN")
	var set_origin := func(td: TileData) -> void: td.y_sort_origin = origin
	for tiles: Array in _fence_tile_variants():
		for v: Array in tiles:
			_tiler.on_tile_created(int(v[0]), set_origin)
	# Paint each fence kind on its own: posts only join their own kind.
	var by_kind := {}
	for c: Vector2i in all:
		if not by_kind.has(all[c]):
			by_kind[all[c]] = {}
		by_kind[all[c]][c] = true
	for kind: String in by_kind:
		_tiler.paint_edges(_fences, "Fences", kind, by_kind[kind])
	# Collision hugs the art: a post in each cell plus rails toward neighbors,
	# so you can walk right up to a fence instead of bumping a 32px block.
	for c: Vector2i in all:
		var post := Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE - 6)
		_add_solid(Rect2(post - Vector2(5, 5), Vector2(10, 10)), "fence")
		if all.has(c + Vector2i.RIGHT):
			_add_solid(Rect2(post.x, post.y - 4, TILE, 8), "fence")
		if all.has(c + Vector2i.DOWN):
			_add_solid(Rect2(post.x - 4, post.y, 8, TILE), "fence")
	# The same rails cast flashlight shadows at night.
	for col: CollisionShape2D in _solids.get_children():
		if col.has_meta("fence"):
			_add_occluder(Rect2(col.position - col.shape.size * 0.5, col.shape.size))


func _fence_tile_variants() -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cfg("WANG_JSON")))
	return d["edge_sets"]["Fences"]["tiles"].values()


# -----------------------------------------------------------------------------
# Props, spawns, NPCs, triggers, decals
# -----------------------------------------------------------------------------
func _build_cells() -> void:
	var props: Dictionary = cfg("PROPS_BY_CHAR")
	var npcs: Dictionary = cfg("NPCS_BY_CHAR")
	var triggers: Dictionary = cfg("TRIGGERS_BY_CHAR")
	var enemies: Dictionary = cfg("ENEMIES_BY_CHAR")
	var decals: Array = cfg("DECALS")
	var big: String = cfg("BIG_PROP_CHARS")
	var density: float = cfg("DECAL_DENSITY")
	for y in layout.size():
		for x in layout[y].length():
			var ch: String = layout[y][x]
			var cell_base := Vector2(x * TILE + TILE * 0.5, y * TILE + TILE - 4)
			var h := _hash(x, y)
			if ch == "K":
				_kid.global_position = cell_base
			elif ch == "D":
				_dog.global_position = cell_base
			elif npcs.has(ch):
				_spawn_npc(npcs[ch], cell_base)
			elif triggers.has(ch):
				_add_trigger(triggers[ch], Vector2i(x, y))
			elif enemies.has(ch):
				_spawn_enemy(enemies[ch], cell_base)
			elif ch == ".":
				if not decals.is_empty() and float(h % 1000) / 1000.0 < density:
					_place(decals[(h >> 10) % decals.size()], cell_base + _jitter(h), (h >> 3) & 1 == 1)
					_counts["decals"] += 1
			elif props.has(ch):
				var options: Array = props[ch]
				var at := cell_base if big.contains(ch) else cell_base + _jitter(h)
				_place(options[(h >> 8) % options.size()], at, (h >> 2) & 1 == 1)


func _spawn_npc(spec: Dictionary, at: Vector2) -> void:
	var npc: Npc = NPC_SCENE.instantiate()
	npc.character_id = spec.get("id", "")
	npc.dialogue_file = cfg("DIALOGUE")
	npc.start_node = spec.get("start", "")
	npc.idle_facing = spec.get("facing", Vector2.DOWN)
	npc.position = at
	_world.add_child(npc)
	_counts["npcs"] += 1


func _spawn_enemy(id: String, at: Vector2) -> void:
	var data := load("res://data/enemies/%s.tres" % id) as EnemyData
	if data == null:
		Debug.log_error("Missing enemy data/enemies/%s.tres" % id)
		return
	var e := Enemy.create(data, at)
	_counts["enemies"] += 1
	e.name = "%s_%d" % [id.capitalize(), _counts["enemies"]]
	_world.add_child(e)


func _add_trigger(spec: Dictionary, cell: Vector2i) -> void:
	var t := DialogueTrigger.new()
	t.dialogue_file = cfg("DIALOGUE")
	t.start_node = spec.get("start", "")
	t.once = spec.get("once", true)
	t.position = Vector2(cell * TILE) + Vector2(TILE, TILE) * 0.5
	t.size = Vector2(TILE, TILE)
	add_child(t)
	_counts["triggers"] += 1


## Lily pads on open water, reeds along the water's edge. Automatic, so
## redesigning a pond in LAYOUT re-dresses it for free.
func _dress_pond() -> void:
	var lilies: Array = cfg("LILIES")
	var reeds: Array = cfg("REEDS")
	for y in layout.size():
		for x in layout[y].length():
			if layout[y][x] != "~":
				continue
			var open_water := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if ny < 0 or ny >= layout.size() or nx < 0 or nx >= layout[ny].length() or layout[ny][nx] != "~":
						open_water = false
			var h := _hash(x * 3 + 1, y * 5 + 2)
			var roll := float(h % 1000) / 1000.0
			var at := Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.6) + _jitter(h) * 1.5
			if open_water and roll < cfg("LILY_DENSITY"):
				_place(lilies[(h >> 9) % lilies.size()], at, (h >> 5) & 1 == 1, true)
			elif not open_water and roll < cfg("REED_DENSITY"):
				_place(reeds[(h >> 9) % reeds.size()], at, (h >> 5) & 1 == 1, true)


## Woods and bushes beyond the edges. Decor only (no collision): nobody can
## get out there, and it saves hundreds of physics bodies. Trees only go where
## some screen shape can actually see them: wide on the sides (48:9 sees
## 320 px past each side), a thin band above/below (the camera stops at the
## map's top and bottom edges).
func _build_apron() -> void:
	var map := map_rect()
	var tiles: int = cfg("APRON_TILES")
	var rows: int = cfg("APRON_ROWS")
	var outer := map.grow_individual(tiles * TILE, rows * TILE, tiles * TILE, rows * TILE)
	var trees: Array = cfg("APRON_TREES")
	var shrubs: Array = cfg("APRON_SHRUBS")
	var near := map.grow_individual(cfg("TREE_CLEARANCE_SIDE"), 0, cfg("TREE_CLEARANCE_SIDE"), cfg("TREE_CLEARANCE_BELOW"))
	var step := 56
	var y := outer.position.y + 40.0
	var row := 0
	while y < outer.end.y + 80.0:
		var x := outer.position.x + (28.0 if row % 2 == 1 else 0.0)
		while x < outer.end.x + 60.0:
			var p := Vector2(x, y)
			var h := _hash(int(x), int(y))
			# Clear strip right outside the edge. Then a band where only short
			# plants go: a tree there would hang its canopy over the playable
			# map (Y-sorted after the kid, so it would hide him).
			if not map.grow(18).has_point(p):
				var options := shrubs if near.has_point(p) else trees
				_place(options[h % options.size()], p + _jitter(h) * 2.0, (h >> 4) & 1 == 1, true)
			x += step
		y += 44.0
		row += 1


func _place(prop_name: String, at: Vector2, flipped: bool, decor_only := false) -> void:
	var data := _prop(prop_name)
	if data == null:
		return
	var p := Prop.create(data, at, flipped)
	p.decor_only = decor_only
	_world.add_child(p)
	_counts["props"] += 1


func _prop(prop_name: String) -> PropData:
	if not _prop_cache.has(prop_name):
		var path: String = cfg("PROP_DIR") + prop_name + ".tres"
		var data := load(path) as PropData
		if data == null:
			Debug.log_error("Missing prop %s (rebuild with tools/art/build_art.py?)" % path)
		_prop_cache[prop_name] = data
	return _prop_cache[prop_name]


func _jitter(h: int) -> Vector2:
	var j: int = cfg("JITTER_PX")
	return Vector2(float((h >> 12) % (j * 2 + 1) - j), float((h >> 16) % 5 - 2))


## Stable pseudo-random number per cell: a realm looks the same every run.
func _hash(x: int, y: int) -> int:
	var h := (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _add_solid(r: Rect2, tag := "") -> void:
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = r.get_center()
	if not tag.is_empty():
		col.set_meta(tag, true)
	_solids.add_child(col)
	_counts["solids"] += 1


func _add_occluder(r: Rect2) -> void:
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	_occluders.add_child(occ)


func _set_camera_limits() -> void:
	var cam := _kid.get_node_or_null("Camera2D") as GameCamera
	if cam == null:
		Debug.log_warn("Kid has no GameCamera child; camera bounds not set")
		return
	cam.set_world_bounds(map_rect())
