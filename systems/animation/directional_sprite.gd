# =============================================================================
# directional_sprite.gd  -  Base for 4-direction sprite-sheet animation
# -----------------------------------------------------------------------------
# WHAT:  A Sprite2D that plays named animations from a sprite sheet where each
#        animation has one row per facing direction:
#            sprite.play(&"walk", facing_vector)
#        Subclasses only describe their sheet layout (see LpcSprite for
#        Universal LPC characters, AnimalSprite for LPC animal sheets).
#
# LAYOUT (set by subclasses in _init):
#   frame_size   pixel size of one frame
#   sheet_grid   columns x rows of frames in the sheet
#   feet_y       y of the feet INSIDE a frame; the node origin lands there,
#                which keeps Y-sorting correct ("Origins at the feet" rule)
#   dir_rows     row offset for each Dir (UP, LEFT, DOWN, RIGHT)
#   anims        name -> {row, frames[], fps, loop, one_dir?}
#
# DIRECTIONS: facing_to_dir() maps any vector (8-way or analog) to the nearest
#        of 4. Horizontal wins ties, so diagonals show the side view.
#
# SHADOW: set `shadow_texture` to a sheet with the same layout (frame-aligned
#        shadows) and a child sprite mirrors every frame on the shadow layer.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DirectionalSprite
extends Sprite2D

## Emitted when a non-looping animation reaches its last frame.
signal animation_finished(anim: StringName)

enum Dir { UP, LEFT, DOWN, RIGHT }

## Shared draw layer for drop shadows (see Prop.SHADOW_Z).
const SHADOW_Z := -10

## Multiplies every animation's fps (e.g. walk faster when moving faster).
@export var speed_scale := 1.0
## Animation to start with.
@export var autoplay: StringName = &"idle"
## Optional frame-aligned shadow sheet (same layout as `texture`).
@export var shadow_texture: Texture2D
@export_range(0.0, 1.0) var shadow_alpha := 0.5

var current: StringName = &""
var dir: Dir = Dir.DOWN

# --- Layout: subclasses fill these in _init() --------------------------------
var frame_size := Vector2i(64, 64)
var sheet_grid := Vector2i(1, 1)
var feet_y := 60
var dir_rows: Array[int] = [0, 1, 2, 3]
var anims: Dictionary = {}

var _frame_index := 0
var _time := 0.0
var _finished := false
var _shadow: Sprite2D


func _ready() -> void:
	hframes = sheet_grid.x
	vframes = sheet_grid.y
	centered = true
	# Frame center -> feet: move the art up so the feet sit on the origin.
	offset = Vector2(0, -(feet_y - frame_size.y * 0.5))
	if texture and Vector2i(texture.get_size()) != frame_size * sheet_grid:
		Debug.log_warn("%s: %s is %s, expected %s" % [get_script().get_global_name(), texture.resource_path,
				Vector2i(texture.get_size()), frame_size * sheet_grid])
	if shadow_texture:
		_shadow = Sprite2D.new()
		_shadow.name = "Shadow"
		_shadow.texture = shadow_texture
		_shadow.hframes = hframes
		_shadow.vframes = vframes
		_shadow.offset = offset
		_shadow.z_index = SHADOW_Z
		_shadow.modulate.a = shadow_alpha
		add_child(_shadow)
	if autoplay != &"":
		play(autoplay)


## Play `anim` facing `facing` (any vector; zero keeps the current direction).
## Calling it again with the same animation keeps it running smoothly, so
## it's safe to call every frame.
func play(anim: StringName, facing := Vector2.ZERO, restart := false) -> void:
	if not anims.has(anim):
		Debug.log_warn("%s: unknown animation '%s'" % [get_script().get_global_name(), anim])
		return
	if facing != Vector2.ZERO:
		dir = facing_to_dir(facing)
	if anim != current or restart:
		current = anim
		_frame_index = 0
		_time = 0.0
		_finished = false
	_apply_frame()


## True while a non-looping animation still has frames left to show.
func is_playing_once() -> bool:
	return not anims.get(current, {}).get("loop", true) and not _finished


static func facing_to_dir(v: Vector2) -> Dir:
	if absf(v.x) >= absf(v.y):
		return Dir.RIGHT if v.x > 0.0 else Dir.LEFT
	return Dir.DOWN if v.y > 0.0 else Dir.UP


func _process(delta: float) -> void:
	if current == &"" or _finished:
		return
	var a: Dictionary = anims[current]
	var frames: Array = a["frames"]
	_time += delta * a["fps"] * speed_scale
	while _time >= 1.0:
		_time -= 1.0
		_frame_index += 1
		if _frame_index >= frames.size():
			if a["loop"]:
				_frame_index = 0
			else:
				_frame_index = frames.size() - 1
				_finished = true
				animation_finished.emit(current)
				break
	_apply_frame()


func _apply_frame() -> void:
	var a: Dictionary = anims[current]
	var row: int = a["row"] + (0 if a.get("one_dir", false) else dir_rows[int(dir)])
	frame_coords = Vector2i(a["frames"][_frame_index], row)
	if _shadow:
		_shadow.frame_coords = frame_coords
