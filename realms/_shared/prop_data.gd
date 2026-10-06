# =============================================================================
# prop_data.gd  -  Everything needed to place one kind of world prop
# -----------------------------------------------------------------------------
# WHAT:  A Resource (.tres) describing a prop: which part of which texture to
#        draw, where its BASE is (the point that touches the ground, used for
#        Y-sorting), how big its solid footprint is, and optional extras:
#        drop shadow, wind sway, and a light occluder so the flashlight casts
#        shadows off it at night.
# WHY:   Adding a new tree/bush/rock is "make a .tres in the inspector", no
#        code. The Prop node (prop.gd) reads one of these and builds itself.
# MAKE ONE: FileSystem dock > right-click > New Resource > PropData, set the
#        texture + region, then set `base` to the pixel (inside the region)
#        where the prop touches the ground, usually bottom-center of the trunk.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name PropData
extends Resource

## The sprite sheet / atlas.
@export var texture: Texture2D
## Part of the texture to draw (pixels). Zero size = the whole texture.
@export var region := Rect2()
## Ground point INSIDE the region (pixels from the region's top-left). This
## becomes the prop's origin, so Y-sorting compares this point with actors' feet.
@export var base := Vector2.ZERO
## Flat ground art (scattered wildflowers, pebbles, grass tufts): drawn on the
## ground layer under everything instead of Y-sorted with actors.
@export var ground_decal := false

@export_group("Animation")
## Frames laid side by side in the texture/region (lily pads, reeds...).
## base, footprint and shadow are measured on ONE frame.
@export_range(1, 16) var frames := 1
@export var frame_fps := 2.0

@export_group("Collision")
## Solid footprint centered on the base (pixels). Zero = walk-through (flowers).
@export var footprint := Vector2.ZERO
## Footprint offset from the base (e.g. push it up a little into the trunk).
@export var footprint_offset := Vector2.ZERO

@export_group("Shadow")
## Painted shadow sprite (e.g. a tree canopy's shadow). Takes priority over
## the soft ellipse below. Drawn on the shadow layer, centered at base + offset.
@export var shadow_texture: Texture2D
@export var shadow_offset := Vector2.ZERO
## Soft drop-shadow ellipse size (pixels), used when there's no shadow_texture.
## Zero = no shadow.
@export var shadow_size := Vector2.ZERO
@export_range(0.0, 1.0) var shadow_alpha := 0.45

@export_group("Wind")
## Max sway at the top in pixels. Zero = no sway (rocks, fences).
@export var sway_strength := 0.0
@export var sway_speed := 0.5
## Bottom fraction that never moves (trunks).
@export_range(0.0, 1.0) var sway_rooted := 0.4

@export_group("Night light")
## Casts flashlight shadows: a box this size around the footprint (pixels).
## Zero = no occluder (small plants shouldn't block light).
@export var occluder_size := Vector2.ZERO
