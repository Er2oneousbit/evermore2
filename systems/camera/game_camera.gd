# =============================================================================
# game_camera.gd  -  Camera2D that behaves on any screen width
# -----------------------------------------------------------------------------
# WHAT:  A Camera2D with "world bounds". Normally it clamps to the bounds so
#        you never see past the edge of the map. When the SCREEN IS WIDER (or
#        taller) THAN THE MAP, which happens a lot on 32:9 / 48:9 monitors and
#        in small rooms, it pins that axis to the map's center instead.
#
# WHY:   Small rooms and ultrawide screens both produce "map narrower than
#        the view". Godot 4.7's Camera2D happens to center in that case too
#        (tests/smoke_aspect confirmed it), but that isn't clearly documented,
#        so we pin explicitly to stay stable across engine upgrades. The realm's
#        "apron" art (decor outside the playable area) fills the sides; WITHOUT
#        an apron you see the grey void. Camera math can't fix missing art.
#
# USAGE: the level calls  camera.set_world_bounds(Rect2(...))  once it knows
#        its size. Zero-size bounds = no limits at all.
#        Recalculates automatically when the window/view size changes.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name GameCamera
extends Camera2D

## Playable area in world pixels. Size zero = unlimited camera.
@export var world_bounds := Rect2():
	set(value):
		world_bounds = value
		if is_inside_tree():
			_apply_limits()

const NO_LIMIT := 10000000


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_limits)
	ScreenScaler.view_changed.connect(func(_view: Vector2i, _scale: int) -> void: _apply_limits())
	_apply_limits()


func set_world_bounds(bounds: Rect2) -> void:
	world_bounds = bounds


## True on an axis where the map is smaller than the screen (camera centered).
func is_centered_x() -> bool:
	return world_bounds.size.x > 0.0 and world_bounds.size.x < _view_size().x


func is_centered_y() -> bool:
	return world_bounds.size.y > 0.0 and world_bounds.size.y < _view_size().y


func _view_size() -> Vector2:
	return get_viewport().get_visible_rect().size / zoom


func _apply_limits() -> void:
	if world_bounds.size == Vector2.ZERO:
		limit_left = -NO_LIMIT
		limit_top = -NO_LIMIT
		limit_right = NO_LIMIT
		limit_bottom = NO_LIMIT
		return

	var view := _view_size()
	var center := world_bounds.get_center()

	if world_bounds.size.x >= view.x:
		limit_left = floori(world_bounds.position.x)
		limit_right = ceili(world_bounds.end.x)
	else:
		# Limits exactly one screen wide, centered on the map = camera pinned.
		limit_left = floori(center.x - view.x * 0.5)
		limit_right = limit_left + ceili(view.x)

	if world_bounds.size.y >= view.y:
		limit_top = floori(world_bounds.position.y)
		limit_bottom = ceili(world_bounds.end.y)
	else:
		limit_top = floori(center.y - view.y * 0.5)
		limit_bottom = limit_top + ceili(view.y)

	# Skip the smoothing slide after a resize so the view snaps into place.
	reset_smoothing()
	Debug.log_verbose("GameCamera: view %s, bounds %s, centered x=%s y=%s"
			% [view, world_bounds, is_centered_x(), is_centered_y()])
