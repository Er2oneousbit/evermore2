# =============================================================================
# animal_sprite.gd  -  Animations for "[LPC] Bears, deer, lions and more" sheets
# -----------------------------------------------------------------------------
# WHAT:  DirectionalSprite layout for the LPC Spring 2022 animal pack (the
#        dog, fox, deer...): one row per direction in the order DOWN, LEFT,
#        RIGHT, UP; frames 0-3 walk, 4-7 "eat" (head down: perfect for the
#        dog's sniffing later). Frame size and feet height are exports because
#        they differ per animal (dog 48x48, fox 64x64...).
# USAGE: the dog scene sets texture = dog_lpc.png, shadow_texture =
#        dog_lpc_shadow.png, frame 48x48, feet_y 42.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name AnimalSprite
extends DirectionalSprite

## One frame's size in the sheet.
@export var frame_px := Vector2i(48, 48)
## Where the paws touch the ground inside a frame.
@export var paws_y := 42
## A different animation table (enemies: idle/walk/attack/die). Empty = the
## dog's table below.
@export var anims_override: Dictionary = {}

const ANIMS := {
	&"idle":  {"row": 0, "frames": [0], "fps": 1.0, "loop": true},
	&"walk":  {"row": 0, "frames": [0, 1, 2, 3], "fps": 8.0, "loop": true},
	&"run":   {"row": 0, "frames": [0, 1, 2, 3], "fps": 13.0, "loop": true},
	&"sniff": {"row": 0, "frames": [4, 5, 6, 7], "fps": 6.0, "loop": false},
	# The dog's bite: head low, then a stretched lunge (frame 1) where it lands.
	&"bite":  {"row": 0, "frames": [4, 1, 1, 0], "fps": 14.0, "loop": false},
}


func _init() -> void:
	anims = ANIMS
	dir_rows = [3, 1, 0, 2]  # UP, LEFT, DOWN, RIGHT -> sheet rows (down, left, right, up)


func _ready() -> void:
	if not anims_override.is_empty():
		anims = anims_override
	frame_size = frame_px
	feet_y = paws_y
	if texture:
		sheet_grid = Vector2i(texture.get_size()) / frame_px
	super()
