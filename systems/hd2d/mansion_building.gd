# =============================================================================
# mansion_building.gd  -  The Ruffleberg mansion, far away on its hill (title)
# -----------------------------------------------------------------------------
# WHAT:  Builds the mansion out of 3D boxes, prisms and cylinders: a main hall
#        with a steep front gable, a lower wing, a round tower with a leaning
#        cone roof, chimneys, rows of dark windows, a hill under it with dead
#        trees around, and a dark apron of ground in front of the hill. One
#        window in the front gable glows a sickly green and flickers (the lab,
#        where Carltron sleeps); a small tower window now and then lights warm
#        and goes dark again.
# WHY:   The title screen is a foreshadowing (owner, 2026-10-09: "where is the
#        mansion and where is the creepy music"). The house stands against the
#        moon (set in the sky shader), mostly a silhouette with a rim light
#        (assets/shaders/mansion.gdshader), and the one lit window draws the eye.
# HOW:   TitleScreen adds one to the HdView and places it. Coordinates are
#        meters from the middle of the hall's ground (the hill's top): +x east,
#        +z toward the camera, y up. The light levels are pure functions of
#        time and a seed (lab_level / attic_level), so tests can sample them;
#        _process only feeds game time into the materials. Every box, prism
#        and quad that is a direct child avoids faces within 1 cm of another
#        facing the same way (they z-fight as the camera moves); smoke_title
#        checks it, like smoke_hd does for the shops.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name MansionBuilding3D
extends Node3D

const SHADER := preload("res://assets/shaders/mansion.gdshader")
const WALL_TEX := preload("res://assets/textures/hd/shop_wall_a.png")
const ROOF_TEX := preload("res://assets/textures/hd/shop_roof_a.png")

const LAB_COLOR := Color(0.35, 1.0, 0.55)
const LAB_ENERGY := 2.2
const ATTIC_COLOR := Color(1.0, 0.68, 0.32)
const ATTIC_ENERGY := 1.6
## The hill: top radius (flat), foot radius, height; centered this far behind
## the hall (z).
const HILL_TOP_R := 17.0
const HILL_FOOT_R := 28.0
const HILL_H := 3.5
const HILL_Z := -3.0
const TOWER_X := -8.6

## Seeds the flicker (same seed, same flicker, every run).
@export var light_seed := 1995

var lab_window: MeshInstance3D
var attic_window: MeshInstance3D
var lab_light: OmniLight3D

var _t := 0.0
var _lab_mat: StandardMaterial3D
var _attic_mat: StandardMaterial3D
var _wall: ShaderMaterial
var _roof: ShaderMaterial
var _dark: ShaderMaterial
var _glass: StandardMaterial3D
var _lab_now := 1.0
var _attic_now := 0.0


func _ready() -> void:
	build()


## Build the meshes (once; _ready calls it, and tests may call it early).
func build() -> void:
	if get_child_count() > 0:
		return
	_wall = _mat(WALL_TEX, Color(0.2, 0.22, 0.32))
	_roof = _mat(ROOF_TEX, Color(0.08, 0.09, 0.15))
	_roof.set_shader_parameter("rim_strength", 0.45)
	_dark = _mat(null, Color(0.07, 0.07, 0.11))
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.01, 0.015, 0.03)
	_glass.emission_enabled = true
	_glass.emission = Color(0.12, 0.16, 0.28)
	_glass.emission_energy_multiplier = 0.35
	_build_ground()
	_build_hall()
	_build_wing()
	_build_tower()
	_build_chimneys()
	_build_windows()
	_build_lab_window()
	_build_attic_window()
	_build_trees()
	set_process(true)
	_apply(0.0)


func _process(delta: float) -> void:
	_t += delta
	_apply(_t)


## Feed the light functions at time `t` into the materials and the light.
func _apply(t: float) -> void:
	_lab_now = lab_level(t, light_seed)
	_attic_now = attic_level(t, light_seed)
	_lab_mat.emission_energy_multiplier = LAB_ENERGY * _lab_now
	lab_light.light_energy = 0.9 * _lab_now
	_attic_mat.emission_energy_multiplier = ATTIC_ENERGY * _attic_now
	# A dark window is a black pane, not a hole of light.
	_attic_mat.albedo_color = Color(0.01, 0.01, 0.015).lerp(ATTIC_COLOR * 0.4, _attic_now)


## The lab window's brightness (0 to 1) at time `t`: a slow unsteady glow,
## stutters of a sixth of a second, and a brief blackout every 11 seconds.
static func lab_level(t: float, seed_: int) -> float:
	var v := 0.8 + 0.12 * sin(t * 2.3) + 0.08 * sin(t * 5.1 + 1.0)
	var h := _hash(floori(t * 6.0), seed_)
	if h < 0.1:
		v *= 0.15
	elif h < 0.2:
		v *= 0.55
	if fmod(t + float(seed_ % 5), 11.0) < 0.5:
		v *= 0.05
	return clampf(v, 0.0, 1.0)


## The tower window (0 to 1): dark, except for about 2 seconds every 19, when
## a candle-warm light comes up, wavers and goes out.
static func attic_level(t: float, seed_: int) -> float:
	var ph := fmod(t + float(seed_ % 7), 19.0)
	if ph < 12.0 or ph > 14.0:
		return 0.0
	var rise := smoothstep(12.0, 12.4, ph)
	var fall := 1.0 - smoothstep(13.4, 14.0, ph)
	return rise * fall * (0.75 + 0.25 * sin(t * 9.0))


## The hill's height (m, relative to the hall's ground) at a spot.
static func hill_y(x: float, z: float) -> float:
	var r := Vector2(x, z - HILL_Z).length()
	return -clampf((r - HILL_TOP_R) / (HILL_FOOT_R - HILL_TOP_R), 0.0, 1.0) * HILL_H


## What the lab window shows right now (0 to 1), for tests.
func lab_glow() -> float:
	return _lab_now


func attic_glow() -> float:
	return _attic_now


static func _hash(k: int, seed_: int) -> float:
	return float(((k * 73856093) ^ (seed_ * 19349663)) & 0x7fffffff) / 2147483647.0


# -----------------------------------------------------------------------------
# Parts
# -----------------------------------------------------------------------------
func _build_ground() -> void:
	# The hill, and a wide dark apron from the lot's north edge back to it
	# (the map's ground stops at z = 0, which is 28 m in front of the hall
	# at the title's placement; the plane ends half a meter over the map's
	# edge and sits 10 cm below its ground so the two never fight).
	var cyl := CylinderMesh.new()
	cyl.top_radius = HILL_TOP_R
	cyl.bottom_radius = HILL_FOOT_R
	cyl.height = HILL_H
	cyl.radial_segments = 20
	cyl.rings = 1
	var grass := _mat(null, Color(0.05, 0.09, 0.08))
	grass.set_shader_parameter("rim_strength", 0.0)
	grass.set_shader_parameter("roof_sheen", 0.0)
	var hill := _mesh("Hill", cyl, Vector3(0, -HILL_H * 0.5, HILL_Z), grass)
	hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(260, 108.5)
	var apron := _mesh("Apron", plane, Vector3(0, -HILL_H - 0.1, -25.75), grass)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_hall() -> void:
	_box("Hall", Vector3(12, 5, 8), Vector3(0, 2.5, 0), _wall)
	# Steep front gable: sunk 10 cm into the hall, 40 cm proud of its front
	# wall and 80 cm over the sides (eaves), so no face shares a plane with it.
	var prism := PrismMesh.new()
	prism.size = Vector3(12.8, 4.2, 8.8)
	_mesh("HallRoof", prism, Vector3(0, 4.9 + 2.1, 0), _roof)
	# A small dormer gable high on the roof, off center (crooked on purpose).
	var dorm := PrismMesh.new()
	dorm.size = Vector3(2.2, 1.6, 1.4)
	_mesh("Dormer", dorm, Vector3(-3.4, 6.2, 4.1), _roof).rotation.z = 0.05


func _build_wing() -> void:
	_box("Wing", Vector3(6.5, 3.8, 6), Vector3(8.95, 1.9, -1.2), _wall)
	var prism := PrismMesh.new()
	prism.size = Vector3(7.3, 3.0, 6.8)
	var roof := _mesh("WingRoof", prism, Vector3(8.95, 3.7 + 1.5, -1.2), _roof)
	roof.rotation.z = -0.035


func _build_tower() -> void:
	# Ten sides, turned 18 degrees so a flat face looks at the camera (the
	# window sits on it).
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.35
	cyl.height = 8.5
	cyl.radial_segments = 10
	cyl.rings = 1
	var tower := _mesh("Tower", cyl, Vector3(TOWER_X, 4.25, 0.5), _wall)
	tower.rotation.y = PI / 10.0
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 3.1
	cone.height = 3.8
	cone.radial_segments = 10
	cone.rings = 1
	var roof := _mesh("TowerRoof", cone, Vector3(TOWER_X, 8.4 + 1.9, 0.5), _roof)
	roof.rotation.z = 0.045
	# A spike on top.
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.1
	spike.height = 1.6
	spike.radial_segments = 4
	spike.rings = 1
	_mesh("Spike", spike, Vector3(TOWER_X - 0.045 * 1.9, 12.7, 0.5), _dark)


func _build_chimneys() -> void:
	_box("ChimneyA", Vector3(0.9, 3.0, 0.9), Vector3(3.4, 7.7, -0.6), _wall)
	_box("ChimneyB", Vector3(0.9, 2.8, 0.9), Vector3(-1.9, 8.6, -1.6), _wall).rotation.z = 0.04
	_box("ChimneyC", Vector3(0.8, 2.4, 0.8), Vector3(10.8, 5.6, -2.6), _wall)


## Dark panes in rows on the hall's front, some missing (boarded, dark).
func _build_windows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = light_seed
	var n := 0
	for row in [1.7, 3.6]:
		for x in [-4.5, -1.5, 1.5, 4.5]:
			n += 1
			if rng.randf() < 0.2:
				continue
			_quad("Pane%d" % n, Vector2(0.9, 1.5), Vector3(x, row, 4.03), _glass)
	# The wing's front (its front face is at z = 1.8).
	for x in [7.6, 10.3]:
		n += 1
		_quad("Pane%d" % n, Vector2(0.8, 1.3), Vector3(x, 2.2, 1.83), _glass)


func _build_lab_window() -> void:
	# On the gable's front face (z = 4.4): a dark frame, the glowing pane, and
	# a cross of bars in front of it.
	_box("LabFrame", Vector3(1.3, 2.0, 0.06), Vector3(0, 6.2, 4.43), _dark)
	_lab_mat = StandardMaterial3D.new()
	_lab_mat.albedo_color = Color(0.02, 0.05, 0.03)
	_lab_mat.emission_enabled = true
	_lab_mat.emission = LAB_COLOR
	_lab_mat.emission_energy_multiplier = LAB_ENERGY
	lab_window = _quad("LabWindow", Vector2(0.95, 1.65), Vector3(0, 6.2, 4.49), _lab_mat)
	_box("LabBarV", Vector3(0.07, 1.65, 0.04), Vector3(0, 6.2, 4.5), _dark)
	_box("LabBarH", Vector3(0.95, 0.07, 0.04), Vector3(0, 6.45, 4.52), _dark)
	lab_light = OmniLight3D.new()
	lab_light.name = "LabLight"
	lab_light.light_color = LAB_COLOR
	lab_light.omni_range = 7.0
	lab_light.omni_attenuation = 1.4
	lab_light.shadow_enabled = false
	lab_light.position = Vector3(0, 6.2, 6.0)
	add_child(lab_light)


func _build_attic_window() -> void:
	# On the tower's front face (apothem 2.2 * cos 18 deg from its axis).
	var face_z := 0.5 + 2.2 * cos(PI / 10.0)
	_box("AtticFrame", Vector3(0.9, 1.4, 0.06), Vector3(TOWER_X, 6.6, face_z + 0.03), _dark)
	_attic_mat = StandardMaterial3D.new()
	_attic_mat.albedo_color = Color(0.01, 0.01, 0.015)
	_attic_mat.emission_enabled = true
	_attic_mat.emission = ATTIC_COLOR
	_attic_mat.emission_energy_multiplier = 0.0
	attic_window = _quad("AtticWindow", Vector2(0.6, 1.1), Vector3(TOWER_X, 6.6, face_z + 0.09), _attic_mat)


## A few bare trees on and around the hill: a trunk, then forking boughs.
func _build_trees() -> void:
	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)
	var rng := RandomNumberGenerator.new()
	rng.seed = light_seed + 3
	for spec in [[-15.5, 9.0, 9.5], [16.0, 7.5, 8.5], [-6.0, 14.0, 5.5], [8.0, 16.5, 6.0],
			[-21.0, 3.0, 8.0], [22.0, 2.0, 7.0], [3.0, 12.0, 4.5]]:
		var x: float = spec[0]
		var z: float = spec[1]
		_dead_tree(trees, Vector3(x, hill_y(x, z) - 0.1, z), spec[2], rng)


func _dead_tree(parent: Node3D, at: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "DeadTree"
	root.position = at
	root.rotation.z = rng.randf_range(-0.07, 0.07)
	parent.add_child(root)
	_limb(root, Vector3.ZERO, 0.0, h * 0.62, 0.5, 0.2)
	var tip := Vector3(0, h * 0.62, 0)
	for i in 5:
		var side := -1.0 if i % 2 == 0 else 1.0
		var at_y := h * rng.randf_range(0.38, 0.95)
		var len := h * rng.randf_range(0.28, 0.5) * (1.2 - at_y / h * 0.6)
		var tilt := side * rng.randf_range(0.6, 1.1)
		var base := Vector3(0, at_y, 0)
		_limb(root, base, tilt, len, 0.2, 0.05)
		# One fork off each bough.
		var end := base + Vector3(-sin(tilt), cos(tilt), 0) * len
		_limb(root, base.lerp(end, 0.65), tilt - side * rng.randf_range(0.5, 0.9), len * 0.5, 0.1, 0.03)
	var crown := rng.randf_range(-0.25, 0.25)
	_limb(root, tip, crown, h * 0.3, 0.15, 0.03)


## A tapering limb from `from`, leaning `tilt` radians from vertical (about z).
func _limb(parent: Node3D, from: Vector3, tilt: float, length: float, r0: float, r1: float) -> void:
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = r0
	cyl.top_radius = r1
	cyl.height = length
	cyl.radial_segments = 5
	cyl.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = _dark
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = HdView.PROP_LAYER
	mi.rotation.z = tilt
	mi.position = from + Vector3(-sin(tilt), cos(tilt), 0) * length * 0.5
	parent.add_child(mi)


# -----------------------------------------------------------------------------
func _mat(tex: Texture2D, tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("textured", tex != null)
	if tex != null:
		m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", tint)
	return m


func _box(node_name: String, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _mesh(node_name, m, at, mat)


func _quad(node_name: String, size: Vector2, at: Vector3, mat: Material) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := _mesh(node_name, q, at, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _mesh(node_name: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.layers = HdView.PROP_LAYER
	add_child(mi)
	return mi
