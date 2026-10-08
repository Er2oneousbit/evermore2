# =============================================================================
# weapon_data.gd  -  One weapon's numbers (a .tres in data/weapons/)
# -----------------------------------------------------------------------------
# WHAT:  Damage, reach and swing shape, which LPC animation it uses, and how
#        its charge works. max_level is how far the auto-charge can climb
#        (1-3): level 2 and 3 do x2 and x4 damage, like the original, but the
#        meter climbs on its own; nobody holds a button (owner's call).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name WeaponData
extends Resource

## names.json key for the weapon's name.
@export var name_key := ""
## Damage at charge level 1, before armor and difficulty.
@export var damage := 6.0
## How far the swing reaches from the wielder's feet (px).
@export var reach := 34.0
## Width of the swing (degrees). 360 = all around.
@export_range(10.0, 360.0) var arc_deg := 120.0
## LPC animation for the swing: slash, halfslash, backslash or thrust.
@export var swing_anim: StringName = &"slash"
## Which frame of that animation the blow lands on (0-based).
@export var hit_frame := 3
## Swing animation speed multiplier (higher = faster weapon).
@export var swing_speed := 1.0
## Highest charge level this weapon can reach (1-3). Grows with mastery later.
@export_range(1, 3) var max_level := 3
## Seconds for the meter to fill one level. Level 1 refills in this long.
@export var seconds_per_level := 0.9
## Push on hit (px/s).
@export var knockback := 160.0
## Seconds an enemy can't act after being hit.
@export var stagger := 0.25

@export_group("In hand")
## The weapon drawn in his hand while he swings (assets/weapons/, from the LPC
## generator): a front layer over him and a back layer behind him. Rows: up,
## left, down, right; one column per frame of swing_anim, in play order.
@export var overlay_fg: Texture2D
@export var overlay_bg: Texture2D
## Cell size of those layers (px). LPC weapon cells are bigger than the 64 px
## body frame (128 or 192) and share its center.
@export var overlay_frame := 128
