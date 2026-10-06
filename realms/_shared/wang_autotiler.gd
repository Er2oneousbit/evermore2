# =============================================================================
# wang_autotiler.gd  -  Autotile TileMapLayers from Tiled terrain ("wang") data
# -----------------------------------------------------------------------------
# WHAT:  Reads a lookup made by tools/tiled/tsx_wang_to_json.py and paints
#        TileMapLayers with the right transition tiles: grass->water shores,
#        dirt paths, fence corners. It also builds the Godot TileSet on the
#        fly (only the tiles actually used), including tile animations
#        (rippling water) and Y-sort origins for tall tiles (fences).
#
# TWO KINDS OF TERRAIN (that's how the LPC Revised tilesets are made):
#   CORNER sets (grass/dirt/water): each tile is chosen by the terrain at its
#     4 CORNERS. paint_corners() takes a VERTEX grid, (w+1) x (h+1) names.
#     Use vertices_from_cells() to get one from a per-cell map: a vertex takes
#     the highest-PRIORITY terrain of the cells touching it, so water/dirt
#     spread half a tile into neighbors and banks land between cells.
#   EDGE sets (fences): each tile is chosen by which of its 4 EDGES connect to
#     a neighbor of the same terrain. paint_edges() takes a set of cells.
#
# MISSING TILES: LPC has no "checkerboard" corner tiles (A,B,A,B). The vertex
#   grid is fixed up so they never happen (the higher-priority terrain wins).
#   Any other missing combo falls back to a full tile of the strongest
#   terrain and logs a warning once, so map mistakes are visible, not silent.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name WangAutotiler
extends RefCounted

var tile_set: TileSet
var source_id := 0
var tile_size := 32

var _atlas: TileSetAtlasSource
var _columns := 64
var _corner_sets: Dictionary = {}
var _edge_sets: Dictionary = {}
var _animations: Dictionary = {}
var _warned: Dictionary = {}
## Extra per-tile setup applied when a tile is first created: id -> Callable.
var _tile_setup: Dictionary = {}


## Load a lookup JSON. Returns null (and logs why) if it can't.
static func load_json(path: String) -> WangAutotiler:
	if not FileAccess.file_exists(path):
		Debug.log_error("WangAutotiler: %s not found" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		Debug.log_error("WangAutotiler: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	var d: Dictionary = json.data
	var texture := load(d["image"]) as Texture2D
	if texture == null:
		Debug.log_error("WangAutotiler: can't load tileset image %s" % d["image"])
		return null
	var w := WangAutotiler.new()
	w.tile_size = int(d["tile_size"])
	w._columns = int(d["columns"])
	w._corner_sets = d["corner_sets"]
	w._edge_sets = d["edge_sets"]
	w._animations = d.get("animations", {})
	w.tile_set = TileSet.new()
	w.tile_set.tile_size = Vector2i(w.tile_size, w.tile_size)
	w._atlas = TileSetAtlasSource.new()
	w._atlas.texture = texture
	w._atlas.texture_region_size = Vector2i(w.tile_size, w.tile_size)
	w.source_id = w.tile_set.add_source(w._atlas)
	return w


## Run `setup.call(tile_data)` on a tile when it gets created (e.g. to set
## a fence tile's y_sort_origin). Register before painting.
func on_tile_created(tile_id: int, setup: Callable) -> void:
	_tile_setup[tile_id] = setup


## Highest-priority terrain wins at each vertex. `cells[y][x]` is a terrain
## name; `priority` lists names weakest -> strongest.
static func vertices_from_cells(cells: Array, priority: PackedStringArray) -> Array:
	var h := cells.size()
	var w: int = cells[0].size()
	var verts := []
	for vy in h + 1:
		var row := []
		for vx in w + 1:
			var best := ""
			var best_rank := -1
			for c: Vector2i in [Vector2i(vx - 1, vy - 1), Vector2i(vx, vy - 1), Vector2i(vx - 1, vy), Vector2i(vx, vy)]:
				if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
					continue
				var t: String = cells[c.y][c.x]
				var r := priority.find(t)
				if r > best_rank:
					best_rank = r
					best = t
			row.append(best)
		verts.append(row)
	_fix_checkerboards(verts, priority)
	return verts


## LPC has no A,B,A,B corner tiles. Promote the weaker diagonal pair until
## none are left (each pass can only raise terrain, so this always ends).
static func _fix_checkerboards(verts: Array, priority: PackedStringArray) -> void:
	var h := verts.size() - 1
	var w: int = verts[0].size() - 1
	for _pass in 8:
		var changed := false
		for y in h:
			for x in w:
				var tl: String = verts[y][x]
				var tr: String = verts[y][x + 1]
				var br: String = verts[y + 1][x + 1]
				var bl: String = verts[y + 1][x]
				if tl == br and tr == bl and tl != tr:
					var strong := tl if priority.find(tl) > priority.find(tr) else tr
					verts[y][x] = strong
					verts[y][x + 1] = strong
					verts[y + 1][x + 1] = strong
					verts[y + 1][x] = strong
					changed = true
		if not changed:
			return


## Paint a corner-based terrain set. `verts` from vertices_from_cells().
## `only_if` (optional) decides per cell whether to paint it on this layer:
## func(corners: PackedStringArray) -> bool. Lets water go on its own layer.
func paint_corners(layer: TileMapLayer, set_name: String, verts: Array, priority: PackedStringArray,
		only_if := Callable()) -> void:
	if not _corner_sets.has(set_name):
		Debug.log_error("WangAutotiler: no corner set '%s'" % set_name)
		return
	var tiles: Dictionary = _corner_sets[set_name]["tiles"]
	layer.tile_set = tile_set
	for y in verts.size() - 1:
		for x in verts[0].size() - 1:
			var corners := PackedStringArray([verts[y][x], verts[y][x + 1], verts[y + 1][x + 1], verts[y + 1][x]])
			if only_if.is_valid() and not only_if.call(corners):
				continue
			var key := ",".join(corners)
			if not tiles.has(key):
				key = _fallback_key(corners, priority, tiles)
			if key.is_empty():
				continue
			_place(layer, Vector2i(x, y), tiles[key], x * 7919 + y * 104729)


## Paint an edge-based set (fences) on every cell in `cells` (Vector2i -> true).
func paint_edges(layer: TileMapLayer, set_name: String, terrain: String, cells: Dictionary) -> void:
	if not _edge_sets.has(set_name):
		Debug.log_error("WangAutotiler: no edge set '%s'" % set_name)
		return
	var tiles: Dictionary = _edge_sets[set_name]["tiles"]
	layer.tile_set = tile_set
	for c: Vector2i in cells:
		var t := terrain if cells.has(c + Vector2i.UP) else ""
		var r := terrain if cells.has(c + Vector2i.RIGHT) else ""
		var b := terrain if cells.has(c + Vector2i.DOWN) else ""
		var l := terrain if cells.has(c + Vector2i.LEFT) else ""
		var key := ",".join([t, r, b, l])
		if not tiles.has(key):
			# A lone post (no neighbors) has no tile; use a straight piece.
			key = ",".join(["", terrain, "", terrain])
			if not tiles.has(key):
				_warn_once("edge:" + key, "WangAutotiler: no '%s' tile for edges %s" % [set_name, key])
				continue
		_place(layer, c, tiles[key], c.x * 7919 + c.y * 104729)


func atlas_coords(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % _columns, tile_id / _columns)


# -----------------------------------------------------------------------------
func _place(layer: TileMapLayer, cell: Vector2i, variants: Array, seed_value: int) -> void:
	var tile_id := _pick(variants, seed_value)
	_ensure_tile(tile_id)
	layer.set_cell(cell, source_id, atlas_coords(tile_id))


## Weighted, deterministic variant choice (same map = same look every run).
func _pick(variants: Array, seed_value: int) -> int:
	if variants.size() == 1:
		return int(variants[0][0])
	var total := 0.0
	for v: Array in variants:
		total += float(v[1])
	var r := float(absi(seed_value * 2654435761) % 10000) / 10000.0 * total
	for v: Array in variants:
		r -= float(v[1])
		if r <= 0.0:
			return int(v[0])
	return int(variants[-1][0])


func _ensure_tile(tile_id: int) -> void:
	var coords := atlas_coords(tile_id)
	if _atlas.has_tile(coords):
		return
	_atlas.create_tile(coords)
	var anim: Dictionary = _animations.get(str(tile_id), {})
	if not anim.is_empty():
		_atlas.set_tile_animation_columns(coords, 0)
		_atlas.set_tile_animation_separation(coords, Vector2i(int(anim["step"]) - 1, 0))
		_atlas.set_tile_animation_frames_count(coords, int(anim["frames"]))
		for i in int(anim["frames"]):
			_atlas.set_tile_animation_frame_duration(coords, i, float(anim["ms"][i]) / 1000.0)
	if _tile_setup.has(tile_id):
		_tile_setup[tile_id].call(_atlas.get_tile_data(coords, 0))


## Missing combo: replace the weakest terrain with the next one up until a
## tile exists. Ends at a full tile of the strongest terrain present.
func _fallback_key(corners: PackedStringArray, priority: PackedStringArray, tiles: Dictionary) -> String:
	var c := corners.duplicate()
	for _i in 4:
		var present: Array[String] = []
		for t in c:
			if not present.has(t):
				present.append(t)
		if present.size() <= 1:
			break
		present.sort_custom(func(a: String, b: String) -> bool: return priority.find(a) < priority.find(b))
		var weakest := present[0]
		var next := present[1]
		for i in c.size():
			if c[i] == weakest:
				c[i] = next
		var key := ",".join(c)
		if tiles.has(key):
			_warn_once("corner:" + ",".join(corners),
					"WangAutotiler: no tile for corners %s, used %s (avoid this terrain mix in the map)" % [",".join(corners), key])
			return key
	_warn_once("corner:" + ",".join(corners), "WangAutotiler: no tile at all for corners %s" % ",".join(corners))
	return ""


func _warn_once(key: String, msg: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		Debug.log_warn(msg)
