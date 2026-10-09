# =============================================================================
# shop_building.gd  -  A real 3D shop for the HD-2D view
# -----------------------------------------------------------------------------
# WHAT:  Builds one shop out of 3D boxes: back wall, two side walls, corner
#        posts and a base board, a low gable roof of fine shingles with fascia
#        boards and a ridge cap, a gable front with the sign, a striped
#        scalloped awning over a low counter with goods on it, a crate and a
#        barrel beside the stall, a hanging lantern, and (while the shop is
#        closed) a slatted shutter over the counter opening. The keeper (a 2D
#        Npc that HdView mirrors as a sprite) stands inside, behind the counter,
#        visible from the waist up.
# WHY:   The stalls were flat sprite quads; the owner said the shops looked
#        cheesy and should have depth even if the rest doesn't. Real walls get
#        real parallax from the tilted camera and real sun shadows, like the
#        3D fences. The polish pass (owner: "not sure these are any better")
#        shrank the roof, added trim, goods and a lantern so it reads as a
#        village stall instead of a toy box.
# HOW:   HdView builds one per "stall_*" prop (skipping that prop's quad) and
#        calls setup(). Coordinates are meters from the stall's base point:
#        +x east, +z toward the camera, y up. Textures are 32x32 tiles
#        (tools/art/build_art.py `shops` step: LPC siding plus generated
#        shingles, trim, awning cloth and shutter slats), triplanar in WORLD
#        space at 1 tile per meter with nearest filtering, so a texel is about
#        1/32 m like the sprites. Gameplay stays in 2D: the stall prop's solid
#        footprint (96x54 px) covers this building, counter included; the crate
#        and barrel stand outside it (decoration only). Night: the lantern's
#        warm light while the shop is open; closed shops stay dark.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ShopBuilding3D
extends Node3D

const TEX_DIR := "res://assets/textures/hd/"
const RAIL := preload("res://assets/textures/hd/wood_rail.png")

## Style per stall prop: texture tag (a = corner store, b = all-night stand).
const STYLES := {"stall_corner": "a", "stall_allnight": "b"}

const HALF_W := 1.5       ## the building is 3 m wide (the stall's 96 px)
const WALL_H := 2.4
const GABLE_H := 0.7      ## low pitch: the roof is under a quarter of the height
const BACK_Z := -0.2
const FRONT_Z := 1.6
const COUNTER_H := 0.62   ## low enough to show the keeper from the waist up
const LANTERN_ON := 2.6   ## light energy of the lit lantern

var shop: Shop
var shutter: MeshInstance3D
var lantern: Node3D
var lantern_light: OmniLight3D
var _flame_mat: StandardMaterial3D


## Build the meshes for the style of `prop_name` ("stall_corner"), tied to
## `shop_` (may be null: then it never shows the shutter or the lantern light).
func setup(prop_name: String, shop_: Shop) -> void:
	shop = shop_
	var tag: String = STYLES.get(prop_name, "a")
	var wall := _tiled(TEX_DIR + "shop_wall_%s.png" % tag)
	var roof := _tiled(TEX_DIR + "shop_roof_%s.png" % tag)
	var counter_mat := _tiled(TEX_DIR + "shop_counter_%s.png" % tag)
	var trim := _tiled(TEX_DIR + "shop_trim_%s.png" % tag)
	var wood := _tiled_tex(RAIL)
	var depth := FRONT_Z - BACK_Z
	var mid_z := (FRONT_Z + BACK_Z) * 0.5

	_box("BackWall", Vector3(2 * HALF_W - 0.3, WALL_H, 0.15), Vector3(0, WALL_H * 0.5, BACK_Z + 0.075), wall)
	for side in [-1, 1]:
		var n := "L" if side < 0 else "R"
		_box("SideWall" + n, Vector3(0.15, WALL_H, depth), Vector3(side * (HALF_W - 0.075), WALL_H * 0.5, mid_z), wall)
		# Corner posts (front and back) in the light trim wood so walls don't merge.
		_box("Post" + n, Vector3(0.2, WALL_H, 0.2), Vector3(side * (HALF_W - 0.1), WALL_H * 0.5, FRONT_Z - 0.1), trim)
		_box("PostBack" + n, Vector3(0.2, WALL_H, 0.2), Vector3(side * (HALF_W - 0.1), WALL_H * 0.5, BACK_Z + 0.1), trim)
		# Base board along the foot of the side wall.
		_box("Base" + n, Vector3(0.2, 0.16, depth), Vector3(side * (HALF_W - 0.1), 0.08, mid_z), trim)
	_box("BaseBack", Vector3(2 * HALF_W - 0.3, 0.16, 0.2), Vector3(0, 0.08, BACK_Z + 0.1), trim)
	_box("Lintel", Vector3(2 * HALF_W, 0.2, 0.2), Vector3(0, WALL_H - 0.1, FRONT_Z - 0.1), trim)

	# Gable ends (triangles) closing the roof at the front and back.
	for z: float in [FRONT_Z - 0.06, BACK_Z + 0.06]:
		var prism := PrismMesh.new()
		prism.size = Vector3(2 * HALF_W, GABLE_H, 0.12)
		_mesh("Gable" + ("Front" if z > 0.0 else "Back"), prism, Vector3(0, WALL_H + GABLE_H * 0.5, z), wall)

	# Roof: two shingle planes meeting at the ridge, a short overhang, fascia
	# boards on the eave and gable edges, and a ridge cap.
	var pitch := atan2(GABLE_H, HALF_W)
	var plane_len := sqrt(HALF_W * HALF_W + GABLE_H * GABLE_H) + 0.2
	var roof_depth := depth + 0.4
	for side in [-1, 1]:
		var n := "L" if side < 0 else "R"
		var dir := Vector3(side * cos(pitch), -sin(pitch), 0.0)
		var up := Vector3(side * sin(pitch), cos(pitch), 0.0)
		var ridge := Vector3(0, WALL_H + GABLE_H, 0)
		var center := ridge + dir * (plane_len * 0.5) + up * 0.04 + Vector3(0, 0, mid_z)
		var mi := _box("Roof" + n, Vector3(plane_len, 0.08, roof_depth), center, roof)
		mi.rotation.z = -side * pitch
		# Eave fascia: a board standing on edge at the low end of the plane.
		var eave := ridge + dir * plane_len + Vector3(0, 0, mid_z)
		var fe := _box("Fascia" + n, Vector3(0.05, 0.16, roof_depth + 0.04), eave, trim)
		fe.rotation.z = -side * pitch
		# Gable-edge boards (rakes), front and back, along the slope.
		for z: float in [FRONT_Z + 0.2, BACK_Z - 0.2]:
			var rk := _box("Rake" + n + ("F" if z > 0.0 else "B"), Vector3(plane_len + 0.04, 0.14, 0.05),
					center + Vector3(0, 0, z - mid_z), trim)
			rk.rotation.z = -side * pitch
	var cap := _box("RidgeCap", Vector3(0.18, 0.18, roof_depth + 0.04), Vector3(0, WALL_H + GABLE_H + 0.06, mid_z), trim)
	cap.rotation.z = PI * 0.25

	# Counter: planked front on a base board, a wood top, goods on it.
	_box("Counter", Vector3(2 * HALF_W - 0.4, COUNTER_H, 0.3), Vector3(0, COUNTER_H * 0.5, 1.3), counter_mat)
	_box("CounterBase", Vector3(2 * HALF_W - 0.34, 0.1, 0.34), Vector3(0, 0.05, 1.3), trim)
	_box("CounterTop", Vector3(2 * HALF_W - 0.3, 0.06, 0.46), Vector3(0, COUNTER_H + 0.03, 1.3), wood)
	_build_goods(tag)
	_build_beside()

	# Awning: striped cloth hanging from the lintel, slanting down and out, with
	# a scalloped front edge (cut by alpha). The quad hangs from its top edge.
	var awn := StandardMaterial3D.new()
	awn.albedo_texture = load(TEX_DIR + "shop_awning_%s.png" % tag)
	awn.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	awn.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	awn.cull_mode = BaseMaterial3D.CULL_DISABLED
	awn.uv1_scale = Vector3(2 * HALF_W + 0.2, 1, 1)
	awn.roughness = 0.9
	var drop := 0.15
	var out := 0.4
	var cloth_len := sqrt(drop * drop + out * out)
	var cloth := QuadMesh.new()
	cloth.size = Vector2(2 * HALF_W + 0.2, cloth_len)
	cloth.center_offset = Vector3(0, -cloth_len * 0.5, 0)
	var awning := _mesh("Awning", cloth, Vector3(0, WALL_H - 0.05, FRONT_Z), awn)
	awning.rotation.x = -atan2(out, drop)

	# Sign on the front gable.
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_texture = load(TEX_DIR + "shop_sign_%s.png" % tag)
	sign_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sign_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	sign_mat.roughness = 0.9
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.42)
	_mesh("Sign", quad, Vector3(0, WALL_H + 0.27, FRONT_Z + 0.005), sign_mat)

	_build_lantern(trim)

	# Shutter: wooden slats over the counter opening, shown only while closed.
	var sh_mat := _tiled(TEX_DIR + "shop_shutter_%s.png" % tag)
	shutter = _box("Shutter", Vector3(2 * HALF_W - 0.4, 1.3, 0.06), Vector3(0, COUNTER_H + 0.65, 1.3), sh_mat)

	add_to_group("shop_building")
	if shop:
		shop.state_changed.connect(refresh)
	refresh()


## Four goods standing on the counter top (an atlas strip, one quad each),
## tilted back a little so the sun lights them like the characters.
func _build_goods(tag: String) -> void:
	var goods := Node3D.new()
	goods.name = "Goods"
	add_child(goods)
	var tex: Texture2D = load(TEX_DIR + "shop_goods_%s.png" % tag)
	for i in 4:
		var m := _sprite_mat(tex)
		m.uv1_scale = Vector3(0.25, 1, 1)
		m.uv1_offset = Vector3(0.25 * i, 0, 0)
		var q := QuadMesh.new()
		q.size = Vector2(0.65, 0.65)
		q.center_offset = Vector3(0, 0.325, 0)
		var mi := _mesh("Good%d" % i, q, Vector3(-0.9 + 0.6 * i, COUNTER_H + 0.06, 1.42), m)
		mi.rotation.x = -0.35
		mi.reparent(goods, false)


## A crate (with a sack on it) and a barrel standing against the side walls.
func _build_beside() -> void:
	var beside := Node3D.new()
	beside.name = "Beside"
	add_child(beside)
	var crate_mat := StandardMaterial3D.new()
	crate_mat.albedo_texture = load(TEX_DIR + "shop_crate.png")
	crate_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	crate_mat.roughness = 0.9
	var crate := _box("Crate", Vector3(0.6, 0.55, 0.6), Vector3(-HALF_W - 0.45, 0.275, 1.05), crate_mat)
	crate.rotation.y = 0.2
	crate.reparent(beside, false)
	var extras: Texture2D = load(TEX_DIR + "shop_extras.png")
	for spec in [["Barrel", 0, Vector3(HALF_W + 0.5, 0.0, 1.0), 1.0],
			["Sack", 1, Vector3(-HALF_W - 0.45, 0.55, 1.05), 0.55]]:
		var m := _sprite_mat(extras)
		m.uv1_scale = Vector3(0.5, 1, 1)
		m.uv1_offset = Vector3(0.5 * spec[1], 0, 0)
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0) * spec[3]
		q.center_offset = Vector3(0, 0.5 * spec[3], 0)
		var mi := _mesh(spec[0], q, spec[2], m)
		mi.rotation.x = -0.25
		mi.reparent(beside, false)


## Hanging lantern on an arm at the front-left corner: dark when unlit (closed
## shop, daytime), glowing with a small shadowless light at night while open.
func _build_lantern(trim: Material) -> void:
	var arm_x := -HALF_W - 0.3
	_box("LanternArm", Vector3(0.35, 0.05, 0.05), Vector3(-HALF_W - 0.075, 2.15, FRONT_Z - 0.1), trim)
	lantern = Node3D.new()
	lantern.name = "Lantern"
	lantern.position = Vector3(arm_x, 1.95, FRONT_Z - 0.1)
	add_child(lantern)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.2, 0.17, 0.15)
	_box("Chain", Vector3(0.02, 0.2, 0.02), Vector3(0, 0.1, 0), iron).reparent(lantern, false)
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.albedo_color = Color(0.55, 0.45, 0.3)
	_flame_mat.emission = Color(1.0, 0.72, 0.35)
	_flame_mat.emission_enabled = false
	_box("Body", Vector3(0.16, 0.22, 0.16), Vector3(0, -0.11, 0), _flame_mat).reparent(lantern, false)
	_box("Cap", Vector3(0.22, 0.05, 0.22), Vector3(0, 0.03, 0), iron).reparent(lantern, false)
	lantern_light = OmniLight3D.new()
	lantern_light.name = "Light"
	lantern_light.light_color = Color(1.0, 0.76, 0.42)
	lantern_light.omni_range = 4.2
	lantern_light.omni_attenuation = 1.3
	lantern_light.light_energy = 0.0
	lantern_light.shadow_enabled = false
	lantern_light.position = Vector3(0.25, -0.2, 0.3)
	lantern.add_child(lantern_light)


## Share of the building's height (to the ridge) that the roof takes.
func roof_height_share() -> float:
	return GABLE_H / (WALL_H + GABLE_H)


## Shutter and night glow follow the shop: closed = shutter down, no light.
func refresh() -> void:
	var open := shop == null or shop.is_open()
	shutter.visible = not open
	get_node("Goods").visible = open   # closed shops put their goods away
	var glow := open and Clock.phase == "night"
	_flame_mat.emission_enabled = glow
	_flame_mat.emission_energy_multiplier = 3.0
	lantern_light.light_energy = LANTERN_ON if glow else 0.0


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


## A cut-out sprite material (nearest, alpha scissor) for goods and extras.
func _sprite_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	return m


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
