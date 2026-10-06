# =============================================================================
# prop.gd  -  A world prop (tree, bush, rock, gnome...) built from PropData
# -----------------------------------------------------------------------------
# WHAT:  Reads a PropData resource and builds: the sprite (origin at its base
#        for Y-sorting), optional soft shadow, optional solid footprint on the
#        "world" physics layer, optional wind-sway shader, and an optional
#        LightOccluder2D so the night flashlight casts shadows off it.
# USAGE: in code  ->  Prop.create(data, position)  then add_child() it under
#        a node with y_sort_enabled. In the editor: add a Node2D, attach
#        prop.gd, assign `data`.
# FLIP:  `flip_h` mirrors the art (cheap variety for trees and bushes).
# DRAW ORDER (z_index, shared by every realm; see docs/architecture.md):
#        GROUND_Z  -20  terrain tiles        DECAL_Z  -15  flat ground decals
#        SHADOW_Z  -10  all drop shadows     0             Y-sorted world
#        Shadows sit on their own layer so a tree's shadow never draws over
#        the kid when he walks behind the tree.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Prop
extends Node2D

const SWAY_SHADER := preload("res://assets/shaders/wind_sway.gdshader")
const SHADOW_TEXTURE := preload("res://assets/fx/soft_shadow.tres")

## One sway material per PropData, shared by every copy of that prop, so a
## forest of identical trees batches into a few draw calls.
static var _sway_materials: Dictionary = {}

const GROUND_Z := -20
const DECAL_Z := -15
const SHADOW_Z := -10

@export var data: PropData
@export var flip_h := false
## Scenery nobody can reach (beyond the map edge): skip collision and light
## occluders. Saves hundreds of physics bodies in a realm's apron.
@export var decor_only := false

var sprite: Sprite2D

var _anim_time := 0.0


## Convenience constructor for level builders.
static func create(prop_data: PropData, at: Vector2, flipped := false) -> Prop:
	var p := Prop.new()
	p.data = prop_data
	p.position = at
	p.flip_h = flipped
	return p


func _ready() -> void:
	if data == null or data.texture == null:
		Debug.log_warn("Prop at %s has no PropData/texture" % global_position)
		return
	_build_shadow()
	_build_sprite()
	if not decor_only:
		_build_footprint()
		_build_occluder()


func _build_shadow() -> void:
	var s := Sprite2D.new()
	if data.shadow_texture:
		s.texture = data.shadow_texture
		s.position = Vector2(-data.shadow_offset.x if flip_h else data.shadow_offset.x, data.shadow_offset.y)
		s.flip_h = flip_h
	elif data.shadow_size != Vector2.ZERO:
		s.texture = SHADOW_TEXTURE
		s.scale = data.shadow_size / Vector2(SHADOW_TEXTURE.get_width(), SHADOW_TEXTURE.get_height())
	else:
		s.free()
		return
	s.modulate.a = data.shadow_alpha
	s.z_index = SHADOW_Z
	add_child(s)


func _build_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.texture = data.texture
	sprite.centered = false
	var size := data.texture.get_size()
	if data.region.size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = data.region
		size = data.region.size
	if data.frames > 1:
		sprite.hframes = data.frames
		size.x /= data.frames
		# Start each copy at a different point in the loop so a pond full of
		# lily pads doesn't bob in perfect sync.
		_anim_time = fposmod(global_position.x * 0.37 + global_position.y * 0.11, float(data.frames))
	set_process(data.frames > 1)
	sprite.flip_h = flip_h
	if data.ground_decal:
		sprite.z_index = DECAL_Z
	# Put the base point at the node origin (mirrored if flipped).
	var base_x := (size.x - data.base.x) if flip_h else data.base.x
	sprite.offset = -Vector2(base_x, data.base.y)
	if data.sway_strength > 0.0:
		sprite.material = _sway_material(data)
	add_child(sprite)


static func _sway_material(d: PropData) -> ShaderMaterial:
	var key := d.get_instance_id()
	if not _sway_materials.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = SWAY_SHADER
		mat.set_shader_parameter("strength", d.sway_strength)
		mat.set_shader_parameter("speed", d.sway_speed)
		mat.set_shader_parameter("height", d.base.y)
		mat.set_shader_parameter("rooted", d.sway_rooted)
		# The sprite's region inside its texture, in UV, so swaying rows never
		# pull in a neighbor's pixels from the same atlas.
		var tex_size := d.texture.get_size()
		var r := d.region if d.region.size != Vector2.ZERO else Rect2(Vector2.ZERO, tex_size)
		mat.set_shader_parameter("uv_rect", Vector4(r.position.x / tex_size.x, r.position.y / tex_size.y,
				r.size.x / tex_size.x, r.size.y / tex_size.y))
		_sway_materials[key] = mat
	return _sway_materials[key]


func _process(delta: float) -> void:
	_anim_time = fposmod(_anim_time + delta * data.frame_fps, float(data.frames))
	sprite.frame = int(_anim_time)


func _build_footprint() -> void:
	if data.footprint == Vector2.ZERO:
		return
	var body := StaticBody2D.new()  # layer 1 = "world" by default
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = data.footprint
	col.shape = shape
	col.position = data.footprint_offset
	body.add_child(col)
	add_child(body)


func _build_occluder() -> void:
	if data.occluder_size == Vector2.ZERO:
		return
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var h := data.occluder_size * 0.5
	var c := data.footprint_offset
	poly.polygon = PackedVector2Array([c + Vector2(-h.x, -h.y), c + Vector2(h.x, -h.y), c + Vector2(h.x, h.y), c + Vector2(-h.x, h.y)])
	occ.occluder = poly
	add_child(occ)
