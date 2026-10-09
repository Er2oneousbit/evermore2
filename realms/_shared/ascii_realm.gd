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
#   any key of SHOPS_BY_CHAR       a shop's keeper stands there (systems/shops/shop.gd)
#   any key of EXITS               a way out on the map's edge (see MAP EXITS)
#
# MAP EXITS (systems/travel/, autoload/travel.gd): exit cells sit on the
#   map's outer edge, in place of the fence there:
#     const EXITS := {">": {"to": "res://realms/big_yard/yard_hd.tscn", "entry": "from_street"}}
#     const ENTRIES := {"from_yard": {"cell": Vector2i(34, 12), "facing": Vector2.LEFT}}
#   Walking the leader into an exit cell travels to `to` and puts the party
#   on that scene's ENTRIES[entry]: the leader on `cell`, facing `facing`
#   (into the map), the partner one tile behind him (or on "partner").
#   Keep entries a few tiles inside: validation rejects one next to an exit.
#   The exit's ground ("terrain", default Dirt) runs on out through the apron
#   as a path with no trees on it, and an invisible wall past the edge keeps
#   anyone from walking off the map. SIGNS put a signpost by the road:
#     const SIGNS := [{"cell": Vector2i(35, 13), "place": "realm_test_yard", "dir": Vector2.RIGHT}]
#
# HIDDEN ITEMS sit on top of the layout (a bush cell can hide something), so
#   they're a list, not characters:
#     const HIDDEN_ITEMS := [{"cell": Vector2i(9, 6), "kind": "buried", "item": "old_key"}, ...]
#   kind: "buried" (open ground; the dog digs it up), "tucked" (a prop cell:
#   under that bush or rock), "secret" (lying in a nook). "count" defaults to
#   1. Found ones never come back (GameState flag "<realm>.hidden.<x>_<y>"),
#   and hidden_counts() gives found / total for the HUD and pause menu.
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
	## Or music that follows the time of day (autoload/audio.gd MUSIC_SETS);
	## wins over MUSIC. "" = use MUSIC.
	"MUSIC_SET": "",
	## Background sound (autoload/audio.gd AMBIENCE_SETS): "outdoor" = birds by
	## day, crickets at night. "" = none.
	"AMBIENCE": "outdoor",
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
	## char -> enemy id (data/enemies/<id>.tres), or {"id": "rat", "clock": "follow_clock"}
	## to override ENEMY_CLOCK for that spawner.
	"ENEMIES_BY_CHAR": {},
	## The game clock here (autoload/clock.gd): "free" (keeps running from
	## whatever time it is), "set" (starts at the Atmosphere's start_time and
	## runs) or "hold" (frozen at start_time; the scene moves it with @time).
	"CLOCK_MODE": "free",
	## Do this realm's enemies follow the clock ("follow_clock") or ignore it
	## ("unchanged")? Follow_clock enemies are run by a DayNightDirector
	## (systems/enemies/day_night.gd): each enemy type's EnemyData `active`,
	## `leaves_by` and `arrives_by` say when it is out and how it comes and
	## goes. A spawner can override it, see ENEMIES_BY_CHAR.
	"ENEMY_CLOCK": "unchanged",
	## Tree cells where roosting enemies (bats) hang by day:
	## [{"enemy": "bat", "cell": Vector2i(2, 2)}]. The cell should hold an oak.
	"ENEMY_ROOSTS": [],
	## Where enemies leave the map: [{"cell": Vector2i(x, y), "kind": "burrow"}]
	## (a hole) or {"kind": "edge", "out": Vector2.RIGHT} (a gap they walk out
	## through). The spawners' own cells are burrows already.
	"ENEMY_EXITS": [],
	## char -> shop spec (systems/shops/shop.gd): {"id": "corner_store",
	## "keeper": "GROCER", "rule": "follow_clock", "item": "apple", "greet": "shop_a",
	## "again": "shop_a_again", "closed": "shop_a_closed"}. The char's cell is
	## where the keeper stands; the stall prop is its own char.
	"SHOPS_BY_CHAR": {},
	## Prop characters never mirrored (stalls with signs on them).
	"NO_FLIP_CHARS": "",
	## [{"cell": Vector2i, "kind": "buried"/"tucked"/"secret", "item": id, "count": n}]
	"HIDDEN_ITEMS": [],
	## Demo maps: items handed to the party the first time the map loads in a
	## run (item id -> count), e.g. a kit of gear to try in the ring menu.
	"START_ITEMS": {},
	## Demo maps: formulas the kid knows from the start (ids).
	"START_FORMULAS": [],
	## Demo maps sharing one kit: the flag that says it was handed out (""
	## = "<realm>.start_items"), so walking between them doesn't double it.
	"START_ITEMS_FLAG": "",
	## Ways out (see MAP EXITS above): char -> {"to": scene, "entry": id,
	## "terrain": "Dirt"}. The char goes on the map's edge.
	"EXITS": {},
	## Where arrivals stand: id -> {"cell": Vector2i, "facing": Vector2,
	## "partner": Vector2i (optional, default one tile behind)}.
	"ENTRIES": {},
	## How far an exit's path runs out into the apron, in tiles.
	"EXIT_PATH_TILES": 14,
	## Signposts by the roads: [{"cell": Vector2i, "place": names key, "dir": Vector2}].
	"SIGNS": [],
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
var _day_night: DayNightDirector
## This realm's exits (built from EXITS); null if it has none.
var exits: MapExits
var _counts := {"props": 0, "decals": 0, "solids": 0, "npcs": 0, "triggers": 0, "enemies": 0, "hidden": 0}


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
	_build_exits()
	_build_signs()
	_build_roosts_and_exits()
	_build_hidden()
	_grant_start_items()
	_dress_pond()
	_build_apron()
	_set_camera_limits()
	var key: String = cfg("REALM_NAME_KEY")
	if not key.is_empty():
		GameState.current_realm = key
	if cfg("MUSIC_SET") != "":
		# Crossfades from whatever played before (the last map's track): no
		# silence between maps.
		Audio.set_music_set(cfg("MUSIC_SET"))
	else:
		Audio.play_music(cfg("MUSIC"), 1.5)
	Audio.set_ambience(cfg("AMBIENCE"))
	# Last: everything is built, so an arrival can stand on its entry.
	Travel.realm_ready(self)
	Debug.log_info("%s loaded (%dx%d tiles, %d props, %d decals, %d NPCs, %d enemies, %d hidden items, %d solid shapes). Run with -- --help for options."
			% [Names.text(key) if not key.is_empty() else name, layout[0].length(), layout.size(),
			_counts["props"], _counts["decals"], _counts["npcs"], _counts["enemies"], _counts["hidden"], _counts["solids"]])


## A setting: the realm's constant if it declared one, else the default.
func cfg(key: String) -> Variant:
	return _cfg.get(key, DEFAULTS.get(key))


## A realm setting read straight from a node's script, before (or without)
## its _ready: the node's constant, else DEFAULTS if it's a realm, else
## `fallback`. Children (Atmosphere) use it: their _ready runs first.
static func const_of(node: Node, key: String, fallback: Variant) -> Variant:
	if node == null or node.get_script() == null:
		return fallback
	var consts: Dictionary = node.get_script().get_script_constant_map()
	if consts.has(key):
		return consts[key]
	return DEFAULTS.get(key, fallback) if node is AsciiRealm else fallback


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


## Hidden items in this realm: x = found so far, y = how many there are.
func hidden_counts() -> Vector2i:
	var items: Array = cfg("HIDDEN_ITEMS")
	var found := 0
	for spec: Dictionary in items:
		if GameState.get_flag(hidden_key(spec["cell"])):
			found += 1
	return Vector2i(found, items.size())


## The found flag of the hidden item at a cell.
func hidden_key(cell: Vector2i) -> String:
	return "%s.hidden.%d_%d" % [realm_id(), cell.x, cell.y]


## The prefix of this realm's flags: its name key, or the node name.
func realm_id() -> String:
	var realm: String = cfg("REALM_NAME_KEY")
	return realm if not realm.is_empty() else String(name)


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
	# Exit cells get their ground from their spec (a dirt path by default),
	# so terrain painting and footsteps treat them like any other ground.
	var exit_specs: Dictionary = _cfg.get("EXITS", {})
	if not exit_specs.is_empty():
		var terrain: Dictionary = (_cfg.get("TERRAIN_BY_CHAR", DEFAULTS["TERRAIN_BY_CHAR"]) as Dictionary).duplicate()
		for ch: String in exit_specs:
			if not terrain.has(ch):
				terrain[ch] = exit_specs[ch].get("terrain", "Dirt")
		_cfg["TERRAIN_BY_CHAR"] = terrain
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
			+ "".join(cfg("TRIGGERS_BY_CHAR").keys()) + "".join(cfg("ENEMIES_BY_CHAR").keys()) 			+ "".join(cfg("SHOPS_BY_CHAR").keys()) + "".join(cfg("EXITS").keys())
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
	ok = _validate_hidden() and ok
	ok = _validate_exits() and ok
	if not cfg("NPCS_BY_CHAR").is_empty() or not cfg("TRIGGERS_BY_CHAR").is_empty() 			or not cfg("SHOPS_BY_CHAR").is_empty():
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
	var paths := _exit_path_cells()
	var cells := []
	for y in h:
		var row := []
		for x in w:
			var mx := x - apron
			var my := y - apron
			var t := "Grass"
			if mx >= 0 and my >= 0 and my < layout.size() and mx < layout[0].length():
				t = terrain_by_char.get(layout[my][mx], "Grass")
			elif paths.has(Vector2i(mx, my)):
				t = paths[Vector2i(mx, my)]
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
	var shops: Dictionary = cfg("SHOPS_BY_CHAR")
	var no_flip: String = cfg("NO_FLIP_CHARS")
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
			elif shops.has(ch):
				_spawn_shop(shops[ch], cell_base)
			elif ch == ".":
				if not decals.is_empty() and float(h % 1000) / 1000.0 < density:
					_place(decals[(h >> 10) % decals.size()], cell_base + _jitter(h), (h >> 3) & 1 == 1)
					_counts["decals"] += 1
			elif props.has(ch):
				var options: Array = props[ch]
				var at := cell_base if big.contains(ch) else cell_base + _jitter(h)
				_place(options[(h >> 8) % options.size()], at, (h >> 2) & 1 == 1 and not no_flip.contains(ch))


func _spawn_npc(spec: Dictionary, at: Vector2) -> void:
	var npc: Npc = NPC_SCENE.instantiate()
	npc.character_id = spec.get("id", "")
	npc.dialogue_file = cfg("DIALOGUE")
	npc.start_node = spec.get("start", "")
	npc.idle_facing = spec.get("facing", Vector2.DOWN)
	npc.position = at
	_world.add_child(npc)
	_counts["npcs"] += 1


func _spawn_enemy(spec: Variant, at: Vector2) -> void:
	var id: String = spec["id"] if spec is Dictionary else String(spec)
	var data := load("res://data/enemies/%s.tres" % id) as EnemyData
	if data == null:
		Debug.log_error("Missing enemy data/enemies/%s.tres" % id)
		return
	var rule: String = spec.get("clock", cfg("ENEMY_CLOCK")) if spec is Dictionary else cfg("ENEMY_CLOCK")
	_counts["enemies"] += 1
	if rule == "follow_clock":
		# The director owns its spawning, leaving and respawning.
		_director().register({"id": id, "data": data, "home": at})
		return
	var e := Enemy.create(data, at)
	e.clock_rule = rule
	e.name = "%s_%d" % [id.capitalize(), _counts["enemies"]]
	_world.add_child(e)


## The realm's DayNightDirector, made on first use.
func _director() -> DayNightDirector:
	if _day_night == null:
		_day_night = DayNightDirector.new()
		_day_night.name = "DayNight"
		_day_night.world = _world
		add_child(_day_night)
	return _day_night


## ENEMY_ROOSTS (bats hanging in oaks) and ENEMY_EXITS (holes, gaps) for the
## director. Only realms with follow_clock enemies need either.
func _build_roosts_and_exits() -> void:
	for r: Dictionary in cfg("ENEMY_ROOSTS"):
		var id: String = r["enemy"]
		var data := load("res://data/enemies/%s.tres" % id) as EnemyData
		if data == null:
			Debug.log_error("Missing enemy data/enemies/%s.tres" % id)
			continue
		var cell: Vector2i = r["cell"]
		var rule: String = r.get("clock", cfg("ENEMY_CLOCK"))
		if rule != "follow_clock":
			continue
		_counts["enemies"] += 1
		_director().register({"id": id, "data": data, "roost": true,
				"home": Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE - 4)})
	if _day_night == null:
		return
	for x: Dictionary in cfg("ENEMY_EXITS"):
		var c: Vector2i = x["cell"]
		_day_night.add_exit(Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE - 4), x.get("kind", "burrow"),
				x.get("out", Vector2.ZERO))


func _spawn_shop(spec: Dictionary, at: Vector2) -> void:
	var shop := Shop.create(spec, cfg("DIALOGUE"), at)
	_world.add_child(shop)
	_counts["npcs"] += 1


func _add_trigger(spec: Dictionary, cell: Vector2i) -> void:
	var t := DialogueTrigger.new()
	t.dialogue_file = cfg("DIALOGUE")
	t.start_node = spec.get("start", "")
	t.once = spec.get("once", true)
	t.position = Vector2(cell * TILE) + Vector2(TILE, TILE) * 0.5
	t.size = Vector2(TILE, TILE)
	add_child(t)
	_counts["triggers"] += 1


## START_ITEMS, once per run (a flag remembers).
func _grant_start_items() -> void:
	var items: Dictionary = cfg("START_ITEMS")
	for id: String in cfg("START_FORMULAS"):
		if FormulaData.find(id):
			Usables.learn(id)
	if items.is_empty():
		return
	var flag: String = cfg("START_ITEMS_FLAG")
	if flag.is_empty():
		flag = realm_id() + ".start_items"
	if GameState.get_flag(flag):
		return
	GameState.set_flag(flag, true)
	for id: String in items:
		if ItemData.find(id):
			GameState.add_item(id, items[id])


## Hidden items not found yet: a HiddenItem (buried, tucked) or a pickup
## lying in plain sight (secret).
func _build_hidden() -> void:
	var big: String = cfg("BIG_PROP_CHARS")
	for spec: Dictionary in cfg("HIDDEN_ITEMS"):
		var cell: Vector2i = spec["cell"]
		var key := hidden_key(cell)
		if GameState.get_flag(key):
			continue
		var item := ItemData.find(spec["item"])
		if item == null:
			continue
		var at := Vector2(cell.x * TILE + TILE * 0.5, cell.y * TILE + TILE - 4)
		var kind: String = spec["kind"]
		var ch: String = layout[cell.y][cell.x]
		if kind == "tucked" and not big.contains(ch):
			at += _jitter(_hash(cell.x, cell.y))  # right where the prop stands
		elif kind != "tucked":
			at.y -= 8  # mid-cell: feet stand there, not on the edge below
		var n: int = spec.get("count", 1)
		if kind == "secret":
			_world.add_child(ItemPickup.create(item, n, key, at))
		else:
			_world.add_child(HiddenItem.create(item, n, kind, key, at))
		_counts["hidden"] += 1


## Hidden items must sit where they make sense: tucked ones on a prop (the
## bush or rock they're under), the others on open, walkable ground.
func _validate_hidden() -> bool:
	var ok := true
	var props: Dictionary = cfg("PROPS_BY_CHAR")
	var blocked: String = cfg("SOLID_CHARS") + "".join(cfg("FENCES").keys()) + "".join(props.keys()) 			+ "".join(cfg("NPCS_BY_CHAR").keys())
	var seen := {}
	for spec in cfg("HIDDEN_ITEMS"):
		if not (spec is Dictionary and spec.get("cell") is Vector2i and spec.get("item") is String):
			Debug.log_error("HIDDEN_ITEMS: needs a Vector2i cell and an item id: %s" % [spec])
			ok = false
			continue
		var cell: Vector2i = spec["cell"]
		var kind: String = spec.get("kind", "")
		# A typo here would count toward the total but never spawn: a 5/5 you
		# could never reach.
		if not ResourceLoader.exists("res://data/items/%s.tres" % spec["item"]):
			Debug.log_error("HIDDEN_ITEMS %s: no item data/items/%s.tres" % [cell, spec["item"]])
			ok = false
		if cell.y < 0 or cell.y >= layout.size() or cell.x < 0 or cell.x >= layout[0].length():
			Debug.log_error("HIDDEN_ITEMS %s: outside the map" % cell)
			ok = false
			continue
		if seen.has(cell):
			Debug.log_error("HIDDEN_ITEMS %s: two items on one cell" % cell)
			ok = false
		seen[cell] = true
		var ch: String = layout[cell.y][cell.x]
		if kind == "tucked":
			if not props.has(ch):
				Debug.log_error("HIDDEN_ITEMS %s: tucked needs a prop (bush, rock) there, found '%s'" % [cell, ch])
				ok = false
		elif kind == "buried" or kind == "secret":
			if blocked.contains(ch):
				Debug.log_error("HIDDEN_ITEMS %s: %s needs open ground, found '%s'" % [cell, kind, ch])
				ok = false
		else:
			Debug.log_error("HIDDEN_ITEMS %s: kind must be buried, tucked or secret, not '%s'" % [cell, kind])
			ok = false
	return ok


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


# -----------------------------------------------------------------------------
# Map exits (systems/travel/map_exits.gd, autoload/travel.gd)
# -----------------------------------------------------------------------------
## Which way an exit cell leaves the map (the edge it sits on), or ZERO if
## it isn't on the edge.
func exit_out(cell: Vector2i) -> Vector2:
	if cell.x == 0:
		return Vector2.LEFT
	if cell.x == layout[0].length() - 1:
		return Vector2.RIGHT
	if cell.y == 0:
		return Vector2.UP
	if cell.y == layout.size() - 1:
		return Vector2.DOWN
	return Vector2.ZERO


## Every exit cell -> its char.
func exit_cells() -> Dictionary:
	var specs: Dictionary = cfg("EXITS")
	var out := {}
	if specs.is_empty():
		return out
	for y in layout.size():
		for x in layout[y].length():
			if specs.has(layout[y][x]):
				out[Vector2i(x, y)] = layout[y][x]
	return out


## Apron cells the exits' paths run over -> terrain.
func _exit_path_cells() -> Dictionary:
	var out := {}
	var specs: Dictionary = cfg("EXITS")
	var cells := exit_cells()
	for c: Vector2i in cells:
		var d := Vector2i(exit_out(c))
		for k in range(1, int(cfg("EXIT_PATH_TILES")) + 1):
			out[c + d * k] = specs[cells[c]].get("terrain", "Dirt")
	return out


## Is an apron point on (or right beside) an exit's path? Trees stay off it.
func _on_exit_path(p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
	for c: Vector2i in _exit_path_set():
		if absi(c.x - cell.x) <= 1 and absi(c.y - cell.y) <= 1:
			return true
	return false


var _path_set_cache: Dictionary = {}


func _exit_path_set() -> Dictionary:
	if _path_set_cache.is_empty():
		_path_set_cache = _exit_path_cells()
	return _path_set_cache


## Leader and partner spots of an entry: {"kid": Vector2, "dog": Vector2,
## "facing": Vector2}, or {} if there's no such entry. `dog_leads`: the dog
## is driven, so he stands on the entry and the kid behind him.
func entry_spot(entry_id: String, dog_leads := false) -> Dictionary:
	var entries: Dictionary = cfg("ENTRIES")
	if not entries.has(entry_id):
		return {}
	var e: Dictionary = entries[entry_id]
	var facing: Vector2 = e.get("facing", Vector2.DOWN)
	var lead_cell: Vector2i = e["cell"]
	var partner_cell: Vector2i = e.get("partner", lead_cell - Vector2i(facing.round()))
	var lead := _cell_base(lead_cell)
	var partner := _cell_base(partner_cell)
	return {"kid": partner if dog_leads else lead, "dog": lead if dog_leads else partner, "facing": facing}


func _cell_base(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE - 4)


## One MapExits node with an area per exit cell (the cell plus a tile past
## the edge), and a wall one tile out so nobody walks off into the apron
## (it reaches a tile further along the edge than the gap: no slipping
## round the fence post beside it).
func _build_exits() -> void:
	var specs: Dictionary = cfg("EXITS")
	var cells := exit_cells()
	if cells.is_empty():
		return
	exits = MapExits.new()
	exits.name = "Exits"
	add_child(exits)
	for c: Vector2i in cells:
		var spec: Dictionary = specs[cells[c]]
		var out := exit_out(c)
		var r := Rect2(c * TILE, Vector2(TILE, TILE))
		exits.add(c, r.merge(Rect2(r.position + out * TILE, r.size)), spec.get("to", ""), spec.get("entry", ""), out)
		var side := Vector2(absf(out.y), absf(out.x)) * TILE
		var wall := Rect2(r.position + out * TILE - side, r.size + side * 2.0)
		_add_solid(wall, "exit_wall")


## Signposts: the prop plus the readable part (Signpost).
func _build_signs() -> void:
	for spec: Dictionary in cfg("SIGNS"):
		var cell: Vector2i = spec["cell"]
		var at := _cell_base(cell)
		# The art's arrow points right: mirrored for left, its own board for up.
		var dir: Vector2 = spec.get("dir", Vector2.RIGHT)
		_place("signpost_up" if dir == Vector2.UP else "signpost", at, dir == Vector2.LEFT)
		var s := Signpost.new()
		s.name = "Sign_%d_%d" % [cell.x, cell.y]
		s.place_key = spec.get("place", "")
		s.dir = spec.get("dir", Vector2.RIGHT)
		s.position = at
		_world.add_child(s)


## Exits on the edge, pointing at a scene; entries on open ground a little
## inside, never next to an exit (or you'd arrive and leave again).
func _validate_exits() -> bool:
	var ok := true
	var specs: Dictionary = cfg("EXITS")
	var cells := exit_cells()
	for c: Vector2i in cells:
		if exit_out(c) == Vector2.ZERO:
			Debug.log_error("EXITS %s: an exit must sit on the map's edge" % c)
			ok = false
	for ch: String in specs:
		var to: String = specs[ch].get("to", "")
		if not ResourceLoader.exists(to):
			Debug.log_error("EXITS '%s': no scene '%s'" % [ch, to])
			ok = false
	var blocked: String = cfg("SOLID_CHARS") + "".join(cfg("FENCES").keys()) + "".join(cfg("PROPS_BY_CHAR").keys()) \
			+ "".join(cfg("NPCS_BY_CHAR").keys()) + "".join(specs.keys())
	var entries: Dictionary = cfg("ENTRIES")
	for id: String in entries:
		var e: Dictionary = entries[id]
		var lead: Vector2i = e.get("cell", Vector2i(-1, -1))
		var facing: Vector2 = e.get("facing", Vector2.DOWN)
		for c: Vector2i in [lead, e.get("partner", lead - Vector2i(facing.round()))]:
			if c.y < 0 or c.y >= layout.size() or c.x < 0 or c.x >= layout[0].length():
				Debug.log_error("ENTRIES %s: %s is outside the map" % [id, c])
				ok = false
				continue
			if blocked.contains(layout[c.y][c.x]):
				Debug.log_error("ENTRIES %s: %s needs open ground, found '%s'" % [id, c, layout[c.y][c.x]])
				ok = false
			for x: Vector2i in cells:
				if absi(x.x - c.x) <= 1 and absi(x.y - c.y) <= 1:
					Debug.log_error("ENTRIES %s: %s is next to the exit at %s" % [id, c, x])
					ok = false
	return ok


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
			if not map.grow(18).has_point(p) and not _on_exit_path(p):
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
	# A little past the bottom edge (the apron has trees there): the HUD cards
	# cover the bottom of the screen, and the last row must stay above them.
	cam.set_world_bounds(map_rect().grow_individual(0, 0, 0, HdView.HUD_CLEAR_PX))
