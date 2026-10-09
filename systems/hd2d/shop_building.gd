# =============================================================================
# shop_building.gd  -  A real 3D shop for the HD-2D view
# -----------------------------------------------------------------------------
# WHAT:  Builds one shop out of 3D boxes: back wall, two side walls, a gable
#        roof of shingles with an overhang, a gable front with the sign, a
#        slanted striped awning over a counter, and (while the shop is closed)
#        a shutter panel over the counter opening. The keeper (a 2D Npc that
#        HdView mirrors as a sprite) stands inside, behind the counter.
# WHY:   The stalls were flat sprite quads; the owner said the shops looked
#        cheesy and should have depth even if the rest doesn't. Real walls get
#        real parallax from the tilted camera and real sun shadows, like the
#        3D fences.
# HOW:   HdView builds one per "stall_*" prop (skipping that prop's quad) and
#        calls setup(). Coordinates are meters from the stall's base point:
#        +x east, +z toward the camera, y up. Textures are 32x32 tiles from
#        the LPC buildings tileset (tools/art/build_art.py `shops` step),
#        triplanar in WORLD space at 1 tile per meter with nearest filtering,
#        so a texel is 1/32 m exactly like the sprites. Gameplay stays in 2D:
#        the stall prop's solid footprint (96x54 px) covers this building,
#        counter included. Night: a warm lamp and lit gable windows while the shop
#        is open; closed shops stay dark.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ShopBuilding3D
extends Node3D

const TEX_DIR := "res://assets/textures/hd/"
const RAIL := preload("res://assets/textures/hd/wood_rail.png")
const POST := preload("res://assets/textures/hd/wood_post.png")
const SHUTTER_TEX := preload("res://assets/props/shops/shop_closed.png")

## Style per stall prop: texture tag (a = corner store, b = all-night stand).
const STYLES := {"stall_corner": "a", "stall_allnight": "b"}

const HALF_W := 1.5       ## the building is 3 m wide (the stall's 96 px)
const WALL_H := 2.4
const GABLE_H := 1.0
const BACK_Z := -0.2
const FRONT_Z := 1.6
const SHUTTER_Y := 1.6    ## center height of the shutter panel

var shop: Shop
var shutter: MeshInstance3D
var lamp: OmniLight3D
var _window_mat: StandardMaterial3D


## Build the meshes for the style of `prop_name` ("stall_corner"), tied to
## `shop_` (may be null: then it never shows the shutter or the lamp).
func setup(prop_name: String, shop_: Shop) -> void:
	shop = shop_
	var tag: String = STYLES.get(prop_name, "a")
	var wall := _tiled(TEX_DIR + "shop_wall_%s.png" % tag)
	var roof := _tiled(TEX_DIR + "shop_roof_%s.png" % tag)
	var counter_mat := _tiled(TEX_DIR + "shop_counter_%s.png" % tag)
	var wood := _tiled_tex(RAIL)
	var post_mat := _tiled_tex(POST)

	_box("BackWall", Vector3(2 * HALF_W - 0.3, WALL_H, 0.15), Vector3(0, WALL_H * 0.5, BACK_Z + 0.075), wall)
	for side in [-1, 1]:
		_box("SideWall" + ("L" if side < 0 else "R"), Vector3(0.15, WALL_H, FRONT_Z - BACK_Z),
				Vector3(side * (HALF_W - 0.075), WALL_H * 0.5, (FRONT_Z + BACK_Z) * 0.5), wall)
		_box("Post" + ("L" if side < 0 else "R"), Vector3(0.14, WALL_H - 0.15, 0.14),
				Vector3(side * (HALF_W - 0.1), (WALL_H - 0.15) * 0.5, FRONT_Z - 0.05), post_mat)
	_box("Lintel", Vector3(2 * HALF_W, 0.15, 0.14), Vector3(0, WALL_H - 0.075, FRONT_Z - 0.05), post_mat)

	# Gable ends (triangles) closing the roof at the front and back.
	for z: float in [FRONT_Z - 0.06, BACK_Z + 0.06]:
		var prism := PrismMesh.new()
		prism.size = Vector3(2 * HALF_W, GABLE_H, 0.12)
		_mesh("Gable" + ("Front" if z > 0.0 else "Back"), prism, Vector3(0, WALL_H + GABLE_H * 0.5, z), wall)

	# Roof: two shingle planes meeting at the ridge, 0.25 m of overhang on every
	# side but the ridge. Slope length along the pitch, rotated about z.
	var pitch := atan2(GABLE_H, HALF_W)
	var plane_len := sqrt(HALF_W * HALF_W + GABLE_H * GABLE_H) + 0.25
	var roof_depth := (FRONT_Z - BACK_Z) + 0.5
	for side in [-1, 1]:
		var dir := Vector3(side * cos(pitch), -sin(pitch), 0.0)
		var up := Vector3(side * sin(pitch), cos(pitch), 0.0)
		var ridge := Vector3(0, WALL_H + GABLE_H, 0)
		var mi := _box("Roof" + ("L" if side < 0 else "R"), Vector3(plane_len, 0.1, roof_depth),
				ridge + dir * (plane_len * 0.5) + up * 0.05 + Vector3(0, 0, (FRONT_Z + BACK_Z) * 0.5), roof)
		mi.rotation.z = -side * pitch

	# Counter in front of the keeper (who stands about 0.97 m from the base).
	_box("Counter", Vector3(2 * HALF_W - 0.4, 0.95, 0.3), Vector3(0, 0.475, 1.3), counter_mat)
	_box("CounterTop", Vector3(2 * HALF_W - 0.3, 0.06, 0.46), Vector3(0, 0.98, 1.3), wood)

	# Awning: slants down and out from the lintel over the counter.
	var awn := StandardMaterial3D.new()
	awn.albedo_texture = load(TEX_DIR + "shop_awning_%s.png" % tag)
	awn.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	awn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	awn.cull_mode = BaseMaterial3D.CULL_DISABLED
	awn.uv1_scale = Vector3(2 * HALF_W + 0.2, 1, 1)
	awn.roughness = 0.9
	var drop := 0.5
	var out := 0.85
	var awning := _box("Awning", Vector3(2 * HALF_W + 0.2, 0.04, sqrt(drop * drop + out * out)),
			Vector3(0, WALL_H - 0.1 - drop * 0.5, FRONT_Z + out * 0.5), awn)
	awning.rotation.x = atan2(drop, out)

	# Sign on the front gable.
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_texture = load(TEX_DIR + "shop_sign_%s.png" % tag)
	sign_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sign_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sign_mat.roughness = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	_mesh("Sign", quad, Vector3(0, WALL_H + 0.45, FRONT_Z + 0.005), sign_mat)

	# Two small windows on the front gable and a lamp: lit only at night while open.
	_window_mat = StandardMaterial3D.new()
	_window_mat.albedo_color = Color(0.1, 0.12, 0.16)
	_window_mat.emission = Color(1.0, 0.75, 0.4)
	_window_mat.emission_enabled = false
	var pane := QuadMesh.new()
	pane.size = Vector2(0.3, 0.26)
	for side in [-1, 1]:
		_mesh("Window" + ("L" if side < 0 else "R"), pane,
				Vector3(side * 0.62, WALL_H + 0.3, FRONT_Z + 0.005), _window_mat)
	lamp = OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Color(1.0, 0.78, 0.45)
	lamp.omni_range = 4.5
	lamp.omni_attenuation = 1.4
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	lamp.position = Vector3(0, 2.0, 0.9)
	add_child(lamp)

	# Shutter: the slatted panel from the 2D game, a thin box over the opening.
	var sh_mat := StandardMaterial3D.new()
	sh_mat.albedo_texture = SHUTTER_TEX
	sh_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sh_mat.roughness = 0.9
	shutter = _box("Shutter", Vector3(2 * HALF_W - 0.4, 1.3, 0.06), Vector3(0, SHUTTER_Y, 1.3), sh_mat)

	add_to_group("shop_building")
	if shop:
		shop.state_changed.connect(refresh)
	refresh()


## Shutter and night glow follow the shop: closed = shutter down, no light.
func refresh() -> void:
	var open := shop == null or shop.is_open()
	shutter.visible = not open
	var glow := open and Clock.phase == "night"
	_window_mat.emission_enabled = glow
	_window_mat.emission_energy_multiplier = 2.0
	lamp.light_energy = 2.4 if glow else 0.0


func _box(node_name: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(node_name, m, at, mat)


func _mesh(node_name: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.layers = HdView.PROP_LAYER
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)
	return mi


func _tiled(path: String) -> StandardMaterial3D:
	return _tiled_tex(load(path))


## World-space triplanar at 1 tile per meter, nearest: crisp and aligned.
func _tiled_tex(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE
	m.roughness = 0.9
	return m
