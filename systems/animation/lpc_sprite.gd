# =============================================================================
# lpc_sprite.gd  -  Plays animations from a Universal LPC character sheet
# -----------------------------------------------------------------------------
# WHAT:  A DirectionalSprite that knows the standard "Universal LPC Spritesheet" layout
#        (832x3456: 13 columns x 54 rows of 64x64 frames) and plays named
#        animations facing one of 4 directions:
#            sprite.play(&"walk", facing_vector)
#        Any character exported from the LPC generator works with zero setup:
#        drop the PNG in `texture`, done. (tools/lpc/README.md shows how to
#        make one.)
#
# WHY NOT AnimatedSprite2D + SpriteFrames? A full LPC sheet has 15 animations
#        x 4 directions x up to 13 frames. Clicking ~500 frames into the
#        SpriteFrames editor per character is miserable and error-prone. The
#        layout is a standard, so we describe it ONCE in ANIMS below.
#
# ORIGIN: feet. LPC feet sit at y = 62 inside each 64x64 frame, so `offset`
#        shifts the art up and the node's origin lands between the feet.
#        That keeps Y-sorting correct (see README "Origins at the feet").
#
# DIRECTIONS: LPC rows go up, left, down, right. facing_to_dir() maps any
#        vector (8-way or analog) to the nearest of those 4. Horizontal wins
#        ties, so walking diagonally shows the side view, like SNES RPGs.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name LpcSprite
extends DirectionalSprite

const FRAME := 64
const COLUMNS := 13
const ROWS := 54
## Where the feet are inside a frame (measured from the generator's output).
const FEET_Y := 62

## The universal sheet layout. row = first row (the UP row); 4-direction
## animations use row + Dir. `frames` lists the columns to play, in order.
## `one_dir` = the sheet only has one row for it (hurt, climb).
const ANIMS := {
	# Breathing is a 1 px bob of the whole sprite (`bob`: y px per frame). The
	# sheet's own breathing frame (column 1) lifts the shirt off the trousers
	# and shows a strip of belly on every character, so it is never played.
	&"idle":       {"row": 22, "frames": [0, 0], "bob": [0, -1], "fps": 1.25, "loop": true},
	&"walk":       {"row": 8,  "frames": [1, 2, 3, 4, 5, 6, 7, 8], "fps": 10.0, "loop": true},
	&"run":        {"row": 38, "frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 12.0, "loop": true},
	&"combat_idle": {"row": 42, "frames": [0, 0], "bob": [0, -1], "fps": 1.5, "loop": true},
	&"slash":      {"row": 12, "frames": [0, 1, 2, 3, 4, 5], "fps": 14.0, "loop": false},
	# The slash played backwards: a backhand. The LPC club is drawn for it.
	&"slash_reverse": {"row": 12, "frames": [5, 4, 3, 2, 1, 0], "fps": 14.0, "loop": false},
	&"backslash":  {"row": 46, "frames": [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12], "fps": 20.0, "loop": false},
	&"halfslash":  {"row": 50, "frames": [0, 1, 2, 3, 4, 5], "fps": 14.0, "loop": false},
	&"thrust":     {"row": 4,  "frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 14.0, "loop": false},
	&"spellcast":  {"row": 0,  "frames": [0, 1, 2, 3, 4, 5, 6], "fps": 12.0, "loop": false},
	&"shoot":      {"row": 16, "frames": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], "fps": 16.0, "loop": false},
	&"jump":       {"row": 26, "frames": [0, 1, 2, 3, 4, 1], "fps": 10.0, "loop": false},
	&"sit":        {"row": 30, "frames": [0, 1, 2], "fps": 4.0, "loop": false},
	&"emote":      {"row": 34, "frames": [0, 1, 2], "fps": 4.0, "loop": false},
	&"hurt":       {"row": 20, "frames": [0, 1, 2, 3, 4, 5], "fps": 10.0, "loop": false, "one_dir": true},
	&"climb":      {"row": 21, "frames": [0, 1, 2, 3, 4, 5], "fps": 8.0, "loop": true, "one_dir": true},
}


func _init() -> void:
	frame_size = Vector2i(FRAME, FRAME)
	sheet_grid = Vector2i(COLUMNS, ROWS)
	feet_y = FEET_Y
	dir_rows = [0, 1, 2, 3]  # LPC rows: up, left, down, right
	anims = ANIMS
	phase_groups = [[&"walk", &"run"]]  # both are 8-frame cycles


## How long one full pass of `anim` takes at the given speed scale (s).
static func duration(anim: StringName, scale := 1.0) -> float:
	var a: Dictionary = ANIMS.get(anim, {})
	if a.is_empty():
		return 0.0
	return a["frames"].size() / (a["fps"] * maxf(scale, 0.01))
