# =============================================================================
# prototype_yard.gd  -  Test map for The Big Yard (real LPC Revised art)
# -----------------------------------------------------------------------------
# WHAT:  Builds a playable backyard from the ASCII LAYOUT below:
#          - ground: grass / dirt / pond, autotiled from the LPC Revised
#            summer tileset (shores and path edges picked automatically)
#          - water: its own layer with animated tiles + a shimmer shader
#          - fences: Y-sorted fence tiles, thin collision at the posts/rails
#          - props: trees, bushes, roses, rocks... (data/props/big_yard/*.tres)
#          - decals: wildflowers and grass tufts scattered over plain grass
#          - apron: woods beyond the fence, so ultrawide screens see world
#        Mood (time of day, color grade, particles) comes from the Atmosphere
#        node in the scene. F2 cycles day / golden hour / night.
#
# WHY ASCII: anyone can redesign the test map in a text editor in a minute,
#        and diffs are readable. Real realms will be painted in the editor
#        with the same tileset and PropData; this builder is scaffolding.
#
# LEGEND (one character = one 32x32 tile)
#   .  grass               :  dirt (paths, flowerbeds)   ~  pond (solid)
#   #  wood fence (solid)  K  kid spawn                  D  dog spawn
#   T  oak                 t  light-green oak            B  round bush (solid)
#   s  shrub               l  leafy plant                v  tall grass
#   R  big rock (solid)    r  small rock (solid)         *  rose bush (on dirt)
#   f  flower              m  mushrooms                  w  wildflower patch
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node2D

const TILE := 32

const LAYOUT: Array[String] = [
	"########################################",
	"#...vv....w...t.................vv.....#",
	"#.T.................wr..~~~~~~~....T...#",
	"#v...............m.....~~~~~~~~~~......#",
	"#......w....s......T..~~~~~~~~~~~~.....#",
	"#..K............w......~~~~~~~~~~..BB..#",
	"#...D....................~~~~~~........#",
	"#....::::::::::::::::.......w..........#",
	"#B..vv.:..ll....B...:...w......l.....t.#",
	"#......:............:.....vvT..........#",
	"#######:.##########.:.T.......w...s.r..#",
	"#..........#......#.:..................#",
	"#...l......#...t..#.:.....::::::::::::.#",
	"#.t........#..w...#.:v....:*:*:*:*:*::.#",
	"#.................#.:.....::::::::::::v#",
	"##############....#.:..t..:*:*:*:*:*::.#",
	"#.................#.:.....::::::::::::.#",
	"#....s......r.....#.:...............w..#",
	"#..w................:.....f..f..f..f...#",
	"#.......vv..........:................t.#",
	"#.....m..T.....r..#.:::::::......T.....#",
	"#..R.........s....#......B..vv.w.......#",
	"#.........w.......#...........m...vv...#",
	"########################################",
]

const WANG_JSON := "res://data/tilesets/lpc_summer_wang.json"
const PROP_DIR := "res://data/props/big_yard/"
const TERRAIN_SET := "Summer Terrain"
## Terrain under each character; anything not listed is grass.
const TERRAIN_BY_CHAR := {":": "Dirt", "*": "Dirt", "~": "Shallow Water"}
## Weakest -> strongest. A vertex shared by different terrains takes the
## strongest, so ponds and paths spread half a tile into their neighbors.
const TERRAIN_PRIORITY := ["Grass", "Dirt", "Shallow Water"]
## Characters that are solid at the tile level (props bring their own collision).
const SOLID_CHARS := "~"
## Water is drawn half a tile (16 px) past its cells; collision reaches this far.
const WATER_EDGE_PX := 11
const FENCE_CHAR := "#"

## Which props each character can place (picked deterministically per cell).
const PROPS_BY_CHAR := {
	"T": ["oak_a", "oak_b"],
	"t": ["oak_light"],
	"B": ["bush_round_a", "bush_round_b"],
	"s": ["shrub_a", "shrub_b", "shrub_c"],
	"l": ["leafy_a", "leafy_b", "leafy_c", "leafy_d"],
	"v": ["tall_grass_a", "tall_grass_b", "tall_grass_c", "tall_grass_d", "grass_clump_a", "grass_clump_b"],
	"R": ["rock_big"],
	"r": ["rock_small_a", "rock_small_b", "rock_wide"],
	"*": ["rose_red", "rose_pink", "rose_white", "rose_yellow", "rose_purple", "rose_peach"],
	"f": ["flower_red", "flower_yellow", "flower_blue", "flower_white", "flower_orange", "flower_purple", "flower_pink"],
	"m": ["mushroom_red", "mushroom_cluster_a", "mushroom_cluster_b", "mushroom_brown"],
	"w": ["wildflowers_00", "wildflowers_01", "wildflowers_04", "wildflowers_05", "wildflowers_06",
			"wildflowers_08", "wildflowers_12", "wildflowers_13", "wildflowers_16", "wildflowers_17"],
}
## Big props sit centered in their cell; small ones get a little random nudge
## so rows of plants don't look stamped.
const JITTER_PX := 5
## Fraction of plain grass cells that get a free decorative decal.
const DECAL_DENSITY := 0.22
const DECALS := ["tuft_a", "tuft_b", "tuft_c", "tuft_d", "tuft_e", "tuft_f",
		"wildflowers_02", "wildflowers_03", "wildflowers_09", "wildflowers_10", "wildflowers_14", "wildflowers_18"]

## Pond dressing (see _dress_pond).
const LILIES := ["lily_big", "lily_small", "lily_mid", "lily_mid", "lily_flower"]
const REEDS := ["reeds_a", "reeds_b", "reeds_c"]
const LILY_DENSITY := 0.3
const REED_DENSITY := 0.4

## Tiles of decorative world beyond the fence on every side. Must cover at
## least (widest view - map width) / 2. Widest sane view is 1920 px (48:9),
## map is 1280 px -> 320 px = 10 tiles. 14 leaves margin.
const APRON_TILES := 14
## Apron depth above/below the map (tiles). Small: the camera clamps vertically.
const APRON_ROWS := 4
## Apron trees keep this far from the map (canopies are ~95 px wide, ~100 tall).
const TREE_CLEARANCE_SIDE := 52
const TREE_CLEARANCE_BELOW := 112
## Fence tile Y-sort origin: where the posts meet the ground, from tile center.
const FENCE_SORT_ORIGIN := 13

@onready var _ground: TileMapLayer = $Ground
@onready var _water: TileMapLayer = $Water
@onready var _solids: StaticBody2D = $Solids
@onready var _occluders: Node2D = $Occluders
@onready var _world: Node2D = $World
@onready var _fences: TileMapLayer = $World/Fences
@onready var _kid: Kid = $World/Kid
@onready var _dog: Dog = $World/Dog

var _tiler: WangAutotiler
var _prop_cache: Dictionary = {}
var _counts := {"props": 0, "decals": 0, "solids": 0}


func _ready() -> void:
	if not _validate_layout():
		return
	_tiler = WangAutotiler.load_json(WANG_JSON)
	if _tiler == null:
		return
	_build_terrain()
	_build_fences()
	_build_cells()
	_dress_pond()
	_build_apron()
	_set_camera_limits()
	Debug.log_info("%s prototype loaded (%dx%d tiles, %d props, %d decals, %d solid shapes). Run with -- --help for options."
			% [Names.text("realm_big_yard"), LAYOUT[0].length(), LAYOUT.size(), _counts["props"], _counts["decals"], _counts["solids"]])


## The playable map area in world pixels.
func map_rect() -> Rect2:
	return Rect2(0, 0, LAYOUT[0].length() * TILE, LAYOUT.size() * TILE)


# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------
## Catches typos in LAYOUT before they become confusing in-game bugs.
func _validate_layout() -> bool:
	var width := LAYOUT[0].length()
	var ok := true
	var known := ".#~:KD" + "".join(PROPS_BY_CHAR.keys())
	for y in LAYOUT.size():
		if LAYOUT[y].length() != width:
			Debug.log_error("LAYOUT row %d is %d chars wide, expected %d" % [y, LAYOUT[y].length(), width])
			ok = false
		for x in LAYOUT[y].length():
			if not known.contains(LAYOUT[y][x]):
				Debug.log_error("LAYOUT (%d,%d): unknown character '%s'" % [x, y, LAYOUT[y][x]])
				ok = false
	var joined := "".join(LAYOUT)
	for spawn in ["K", "D"]:
		if joined.count(spawn) != 1:
			Debug.log_error("LAYOUT needs exactly one %s, found %d" % [spawn, joined.count(spawn)])
			ok = false
	return ok


# -----------------------------------------------------------------------------
# Terrain (ground + water layers)
# -----------------------------------------------------------------------------
func _build_terrain() -> void:
	# Per-cell terrain for the map plus the apron (apron = plain grass).
	var w := LAYOUT[0].length() + APRON_TILES * 2
	var h := LAYOUT.size() + APRON_TILES * 2
	var cells := []
	for y in h:
		var row := []
		for x in w:
			var mx := x - APRON_TILES
			var my := y - APRON_TILES
			var t := "Grass"
			if mx >= 0 and my >= 0 and my < LAYOUT.size() and mx < LAYOUT[0].length():
				t = TERRAIN_BY_CHAR.get(LAYOUT[my][mx], "Grass")
			row.append(t)
		cells.append(row)
	var priority := PackedStringArray(TERRAIN_PRIORITY)
	var verts := WangAutotiler.vertices_from_cells(cells, priority)
	var has_water := func(c: PackedStringArray) -> bool: return c.has("Shallow Water")
	var no_water := func(c: PackedStringArray) -> bool: return not c.has("Shallow Water")
	_tiler.paint_corners(_ground, TERRAIN_SET, verts, priority, no_water)
	_tiler.paint_corners(_water, TERRAIN_SET, verts, priority, has_water)
	# Both layers were painted from (0,0) = top-left of the apron.
	var offset := Vector2(-APRON_TILES * TILE, -APRON_TILES * TILE)
	_ground.position = offset
	_water.position = offset
	# Pond collision: each horizontal run of ~ cells becomes one box, grown to
	# where the water is DRAWN (the art spreads half a tile into the bank, see
	# vertices_from_cells), minus a few px so feet can touch the waterline.
	for y in LAYOUT.size():
		var run_start := -1
		for x in LAYOUT[y].length() + 1:
			var solid := x < LAYOUT[y].length() and SOLID_CHARS.contains(LAYOUT[y][x])
			if solid and run_start < 0:
				run_start = x
			elif not solid and run_start >= 0:
				var r := Rect2(run_start * TILE, y * TILE, (x - run_start) * TILE, TILE)
				_add_solid(r.grow(WATER_EDGE_PX))
				run_start = -1


# -----------------------------------------------------------------------------
# Fences
# -----------------------------------------------------------------------------
func _build_fences() -> void:
	var cells := {}
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			if LAYOUT[y][x] == FENCE_CHAR:
				cells[Vector2i(x, y)] = true
	# Every fence tile sorts by where its posts touch the ground.
	var set_origin := func(td: TileData) -> void: td.y_sort_origin = FENCE_SORT_ORIGIN
	for tiles: Array in _fence_tile_variants():
		for v: Array in tiles:
			_tiler.on_tile_created(int(v[0]), set_origin)
	_tiler.paint_edges(_fences, "Fences", "Wood Fence", cells)
	# Collision hugs the art: a post in each cell plus rails toward neighbors,
	# so you can walk right up to a fence instead of bumping a 32px block.
	for c: Vector2i in cells:
		var post := Vector2(c.x * TILE + TILE * 0.5, c.y * TILE + TILE - 6)
		_add_solid(Rect2(post - Vector2(5, 5), Vector2(10, 10)), "fence")
		if cells.has(c + Vector2i.RIGHT):
			_add_solid(Rect2(post.x, post.y - 4, TILE, 8), "fence")
		if cells.has(c + Vector2i.DOWN):
			_add_solid(Rect2(post.x - 4, post.y, 8, TILE), "fence")
	# The same rails cast flashlight shadows at night.
	for col: CollisionShape2D in _solids.get_children():
		if col.has_meta("fence"):
			_add_occluder(Rect2(col.position - col.shape.size * 0.5, col.shape.size))


func _fence_tile_variants() -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WANG_JSON))
	return d["edge_sets"]["Fences"]["tiles"].values()


# -----------------------------------------------------------------------------
# Props, spawns, decals
# -----------------------------------------------------------------------------
func _build_cells() -> void:
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			var ch := LAYOUT[y][x]
			var cell_base := Vector2(x * TILE + TILE * 0.5, y * TILE + TILE - 4)
			var h := _hash(x, y)
			match ch:
				"K":
					_kid.global_position = cell_base
				"D":
					_dog.global_position = cell_base
				".":
					if float(h % 1000) / 1000.0 < DECAL_DENSITY:
						_place(DECALS[(h >> 10) % DECALS.size()], cell_base + _jitter(h), (h >> 3) & 1 == 1)
						_counts["decals"] += 1
				_:
					if PROPS_BY_CHAR.has(ch):
						var options: Array = PROPS_BY_CHAR[ch]
						var big := ch in ["T", "t", "R"]
						var at := cell_base if big else cell_base + _jitter(h)
						_place(options[(h >> 8) % options.size()], at, (h >> 2) & 1 == 1)


## Lily pads on open water, reeds along the water's edge. Automatic, so
## redesigning the pond in LAYOUT re-dresses it for free.
func _dress_pond() -> void:
	for y in LAYOUT.size():
		for x in LAYOUT[y].length():
			if LAYOUT[y][x] != "~":
				continue
			var open_water := true
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if ny < 0 or ny >= LAYOUT.size() or nx < 0 or nx >= LAYOUT[ny].length() or LAYOUT[ny][nx] != "~":
						open_water = false
			var h := _hash(x * 3 + 1, y * 5 + 2)
			var roll := float(h % 1000) / 1000.0
			var at := Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.6) + _jitter(h) * 1.5
			if open_water and roll < LILY_DENSITY:
				_place(LILIES[(h >> 9) % LILIES.size()], at, (h >> 5) & 1 == 1, true)
			elif not open_water and roll < REED_DENSITY:
				_place(REEDS[(h >> 9) % REEDS.size()], at, (h >> 5) & 1 == 1, true)


## Woods and bushes beyond the fence. Decor only (no collision): nobody can
## get out there, and it saves hundreds of physics bodies. Trees only go where
## some screen shape can actually see them: wide on the sides (48:9 sees
## 320 px past each side), a thin band above/below (the camera stops at the
## map's top and bottom edges).
func _build_apron() -> void:
	var map := map_rect()
	var outer := map.grow_individual(APRON_TILES * TILE, APRON_ROWS * TILE, APRON_TILES * TILE, APRON_ROWS * TILE)
	var step := 56
	var y := outer.position.y + 40.0
	var row := 0
	while y < outer.end.y + 80.0:
		var x := outer.position.x + (28.0 if row % 2 == 1 else 0.0)
		while x < outer.end.x + 60.0:
			var p := Vector2(x, y)
			var h := _hash(int(x), int(y))
			# Clear strip right outside the fence. Then a band where only short
			# plants go: a tree there would hang its canopy over the playable
			# map (Y-sorted after the kid, so it would hide him).
			if not map.grow(18).has_point(p):
				var options := ["oak_a", "oak_b", "oak_a", "oak_light", "bush_round_a", "shrub_b"]
				if map.grow_individual(TREE_CLEARANCE_SIDE, 0, TREE_CLEARANCE_SIDE, TREE_CLEARANCE_BELOW).has_point(p):
					options = ["bush_round_a", "bush_round_b", "shrub_a", "shrub_c"]
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
		var path := PROP_DIR + prop_name + ".tres"
		var data := load(path) as PropData
		if data == null:
			Debug.log_error("Missing prop %s (rebuild with tools/art/build_art.py?)" % path)
		_prop_cache[prop_name] = data
	return _prop_cache[prop_name]


func _jitter(h: int) -> Vector2:
	return Vector2(float((h >> 12) % (JITTER_PX * 2 + 1) - JITTER_PX), float((h >> 16) % 5 - 2))


## Stable pseudo-random number per cell: the yard looks the same every run.
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
