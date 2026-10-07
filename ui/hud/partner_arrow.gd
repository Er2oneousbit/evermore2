# =============================================================================
# partner_arrow.gd  -  Points at the partner when he's off-screen
# -----------------------------------------------------------------------------
# WHAT:  An arrow at the edge of the HUD frame, aimed at the partner (the one
#        the AI plays) whenever he's out of view: left on Stay put across the
#        map, or lagging behind. Hidden while he's on screen; it flashes red
#        while he's being hit.
# WHERE: fills the SafeFrame, so on ultrawide it hugs the 16:9 middle like the
#        rest of the HUD. Screen positions come from Fx.world_to_screen, which
#        works in both the 2D and the HD-2D view.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name PartnerArrow
extends Control

## How far inside the frame edge the arrow sits.
const INSET := 12.0
## Height above the feet to aim at (about the chest).
const AIM_HEIGHT := 14.0
const SIZE := 8.0
const COLOR := Color(1.0, 0.85, 0.35)
const HURT_COLOR := Color(1.0, 0.25, 0.2)
const OUTLINE := Color(0, 0, 0, 0.85)

## Where the arrow points from/to, in this control's coordinates (tests read).
var tip := Vector2.ZERO
var _dir := Vector2.RIGHT
## True while the partner was just hit (tests read).
var hurt := false
var _blink := 0.0  # game time, for the red flash


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(delta: float) -> void:
	_blink += delta
	var p := Party.partner()
	# No layout yet (first frames, headless): nothing to clamp into.
	if p == null or Dialogue.is_active() or size.x <= INSET * 4.0 or size.y <= INSET * 4.0:
		visible = false
		return
	var screen := Fx.world_to_screen(p.global_position, AIM_HEIGHT)
	var local := screen - global_position
	var inner := Rect2(Vector2.ZERO, size).grow(-INSET)
	if inner.has_point(local):
		visible = false
		return
	var center := size * 0.5
	_dir = center.direction_to(local)
	tip = Vector2(clampf(local.x, inner.position.x, inner.end.x),
			clampf(local.y, inner.position.y, inner.end.y))
	var h: Health = p.get_node_or_null("Health")
	hurt = h != null and h.is_invulnerable() and not h.is_dead()
	visible = true
	queue_redraw()


func _draw() -> void:
	var side := _dir.orthogonal() * SIZE * 0.6
	var back := tip - _dir * SIZE
	var tri := PackedVector2Array([tip, back + side, back - side])
	var flash := hurt and int(_blink * 8.0) % 2 == 0
	draw_colored_polygon(tri, HURT_COLOR if flash else COLOR)
	draw_polyline(PackedVector2Array([tip, back + side, back - side, tip]), OUTLINE, 1.0)
