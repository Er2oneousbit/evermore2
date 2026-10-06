# =============================================================================
# prototype_yard.gd  -  Prototype 0 test map ("The Big Yard", placeholder)
# -----------------------------------------------------------------------------
# WHAT:  Builds a small test level from the ASCII LAYOUT below: draws the
#        ground, adds collision for fences/water, spawns Y-sorted trees, and
#        places the kid and dog. Also owns the time-of-day tint (F2).
#
# WHY ASCII: zero art needed, and anyone can redesign the test map in a text
#        editor in 30 seconds. Real realms will use TileMapLayer painted in the
#        Godot editor with real tilesets; this file is throwaway scaffolding.
#
# LEGEND (one character = one 16x16 tile):
#   #  fence (solid)          ~  pond (solid)        .  grass
#   ,  flowerbed (walkable)   T  tree (Y-sorted, trunk is solid)
#   K  kid spawn              D  dog spawn
#
# WHAT TO TEST HERE:
#   - Walk behind/in front of trees: Y-sorting (feet decide draw order).
#   - Run through the fenced maze: the dog should follow your exact path.
#   - Press E to make the dog stay, walk away, press E again.
#   - F2 to night, F to toggle the phone flashlight.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node2D

const TILE := 16

const LAYOUT: Array[String] = [
	"########################################",
	"#......................................#",
	"#..T.......,,,,,,.........T.........T..#",
	"#..........,,,,,,......................#",
	"#.....T................~~~~~~..........#",
	"#.....................~~~~~~~~.....T...#",
	"#..K.D.................~~~~~~..........#",
	"#......................................#",
	"#########.#########....................#",
	"#.......#.........#.......T............#",
	"#..T....#.........#..................T.#",
	"#.......#....T....#....................#",
	"#.......#.........#.........,,,,,......#",
	"#.................#.........,,,,,......#",
	"#.......#.........#....................#",
	"#########.........#######.#######......#",
	"#...............................T......#",
	"#..T.....................T.............#",
	"#.....,,,,,,.................######....#",
	"#.....,,,,,,.................#....#....#",
	"#............T...............#....#..T.#",
	"#..........................T.#....#....#",
	"#............................######....#",
	"########################################",
]

## Time-of-day tints applied through CanvasModulate. Lights (the flashlight)
## add on top of this, which is why night makes the flashlight matter.
const TIME_TINTS := {
	"day": Color(1.0, 1.0, 1.0),
	"golden": Color(1.0, 0.85, 0.66),
	"night": Color(0.2, 0.22, 0.4),
}
const TIME_ORDER: Array[String] = ["day", "golden", "night"]
## Seconds to blend between tints.
const TIME_BLEND := 0.6

# Placeholder ground palette (golden-hour backyard).
const COLOR_GRASS_A := Color("5f9e3a")
const COLOR_GRASS_B := Color("58953a")
const COLOR_FENCE := Color("8a5a32")
const COLOR_FENCE_DARK := Color("5e3b20")
const COLOR_WATER := Color("2f6f9f")
const COLOR_WATER_LIGHT := Color("5aa0cf")
const COLOR_DIRT := Color("6b4a2f")
const COLOR_FLOWERS: Array[Color] = [Color("ff6b8a"), Color("ffd84a"), Color("f2f2f2")]

## Start in golden hour: that's the Big Yard's identity.
var _time_index := 1

@onready var _tint: CanvasModulate = $CanvasModulate
@onready var _solids: StaticBody2D = $Solids
@onready var _world: Node2D = $World
@onready var _kid: Kid = $World/Kid
@onready var _dog: Dog = $World/Dog


func _ready() -> void:
	if not _validate_layout():
		return
	_build_from_layout()
	_set_camera_limits()
	_tint.color = TIME_TINTS[TIME_ORDER[_time_index]]
	# Announce the starting time so listeners (e.g. the kid's flashlight) sync up.
	EventBus.time_of_day_changed.emit(TIME_ORDER[_time_index])
	queue_redraw()
	Debug.log_info("%s prototype loaded (%dx%d tiles). Run with -- --help for options."
			% [Names.text("realm_big_yard"), LAYOUT[0].length(), LAYOUT.size()])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_cycle_time"):
		_time_index = (_time_index + 1) % TIME_ORDER.size()
		var time_name := TIME_ORDER[_time_index]
		create_tween().tween_property(_tint, "color", TIME_TINTS[time_name], TIME_BLEND)
		EventBus.time_of_day_changed.emit(time_name)
		Debug.log_verbose("Time of day -> %s" % time_name)


# -----------------------------------------------------------------------------
# Building
# -----------------------------------------------------------------------------
## Catches typos in LAYOUT before they become confusing in-game bugs.
func _validate_layout() -> bool:
	var width := LAYOUT[0].length()
	var ok := true
	for y in LAYOUT.size():
		if LAYOUT[y].length() != width:
			Debug.log_error("LAYOUT row %d is %d chars wide, expected %d" % [y, LAYOUT[y].length(), width])
			ok = false
	var joined := "".join(LAYOUT)
	if joined.count("K") != 1:
		Debug.log_error("LAYOUT needs exactly one K (kid spawn), found %d" % joined.count("K"))
		ok = false
	if joined.count("D") != 1:
		Debug.log_error("LAYOUT needs exactly one D (dog spawn), found %d" % joined.count("D"))
		ok = false
	return ok


func _build_from_layout() -> void:
	var tree_count := 0
	for y in LAYOUT.size():
		var row := LAYOUT[y]
		for x in row.length():
			var center := Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
			match row[x]:
				"#", "~":
					_add_solid_tile(center)
				"T":
					_add_tree(center + Vector2(0, TILE * 0.25))
					tree_count += 1
				"K":
					_kid.global_position = center
				"D":
					_dog.global_position = center
	Debug.log_verbose("Built yard: %d solid shapes, %d trees" % [_solids.get_child_count(), tree_count])


func _add_solid_tile(center: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = center
	_solids.add_child(col)


func _add_tree(base: Vector2) -> void:
	var tree := PlaceholderTree.new()
	tree.position = base
	_world.add_child(tree)  # World has y_sort_enabled, so trees sort with actors.


func _set_camera_limits() -> void:
	var cam := _kid.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		Debug.log_warn("Kid has no Camera2D child; camera limits not set")
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = LAYOUT[0].length() * TILE
	cam.limit_bottom = LAYOUT.size() * TILE


# -----------------------------------------------------------------------------
# Ground drawing (drawn by this node, so it renders under everything in World)
# -----------------------------------------------------------------------------
func _draw() -> void:
	for y in LAYOUT.size():
		var row := LAYOUT[y]
		for x in row.length():
			var r := Rect2(x * TILE, y * TILE, TILE, TILE)
			# Grass everywhere first (checker for a little texture).
			draw_rect(r, COLOR_GRASS_A if (x + y) % 2 == 0 else COLOR_GRASS_B)
			match row[x]:
				"#":
					_draw_fence(r)
				"~":
					_draw_water(r, x, y)
				",":
					_draw_flowerbed(r, x, y)


func _draw_fence(r: Rect2) -> void:
	draw_rect(r, COLOR_FENCE)
	# Plank lines every 4 px.
	for i in range(1, 4):
		var px := r.position.x + i * 4
		draw_line(Vector2(px, r.position.y), Vector2(px, r.end.y), COLOR_FENCE_DARK)
	draw_rect(Rect2(r.position.x, r.end.y - 3, r.size.x, 3), COLOR_FENCE_DARK)


func _draw_water(r: Rect2, x: int, y: int) -> void:
	draw_rect(r, COLOR_WATER)
	# Deterministic "ripple" pixels so the pond doesn't look flat.
	var ox := 3 + (x * 7 + y * 3) % 8
	var oy := 4 + (x * 5 + y * 11) % 7
	draw_rect(Rect2(r.position + Vector2(ox, oy), Vector2(4, 1)), COLOR_WATER_LIGHT)


func _draw_flowerbed(r: Rect2, x: int, y: int) -> void:
	draw_rect(r, COLOR_DIRT)
	for i in 3:
		var fx := 2 + ((x * 13 + y * 7 + i * 5) % 12)
		var fy := 2 + ((x * 3 + y * 17 + i * 9) % 12)
		var c := COLOR_FLOWERS[(x + y + i) % COLOR_FLOWERS.size()]
		draw_rect(Rect2(r.position + Vector2(fx, fy), Vector2(2, 2)), c)
