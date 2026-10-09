# =============================================================================
# hd_view.gd  -  HD-2D presentation of a 2D realm (Octopath-style look)
# -----------------------------------------------------------------------------
# WHAT:  Draws a 2D realm as an "HD-2D" scene: pixel-art sprites standing in a
#        lit 3D world with real sun shadows, depth-of-field blur, bloom,
#        volumetric light shafts, reflective water and drifting clouds.
#
# HOW (the important part): GAMEPLAY STAYS 2D. The realm still builds its
#        normal 2D world (tiles, props, kid, dog, collision, AI), which keeps
#        every system and test working unchanged. This node is a VIEW of it:
#          - ground  : the 2D ground + decals are rendered ONCE into a texture
#                      (pixel-perfect autotiling) and laid on a 3D plane
#          - water   : a glossy plane over the water pixels (reflections)
#          - props   : every 2D Prop becomes an upright sprite quad (or a flat
#                      one for lily pads) that casts sun shadows
#          - fences  : real 3D posts and rails (wood cut from the LPC tileset)
#          - actors  : every node in group "hd_actor" (kid, dog, NPCs) gets a
#                      sprite that copies its 2D sprite's frame and position
#                      every frame
#          - mood    : sun/moon, sky, fog, glow, DoF per time of day, driven by
#                      the realm's Atmosphere (F2 still cycles it)
#        2D pixels -> 3D meters: 32 px = 1 m. 2D (x, y) -> 3D (x, 0, y).
#
# DEBUG: F6 flips between this HD-2D view and the classic 2D view.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name HdView
extends Node3D

## Meters per 2D pixel (32 px tiles = 1 m tiles).
const PX := 1.0 / 32.0

## Render layers (bit values): contact-shadow decals only project onto the
## ground layer. On upright sprites a decal smears into stripes.
const GROUND_LAYER := 1
const ACTOR_LAYER := 2
const PROP_LAYER := 4

## Depth tie-breakers (meters). In 2D, Y-sort settles "same row" ties by
## draw order. In 3D, two upright sprites on the same row sit at the same
## depth and z-fight (flickering stripes). So props stand a hair behind
## their base point and actors a hair in front, kid in front of the dog.
## Far too small to see, big enough to always break the tie.
const PROP_DEPTH_BIAS := -0.03
const KID_DEPTH_BIAS := 0.02
const NPC_DEPTH_BIAS := 0.015
const DOG_DEPTH_BIAS := 0.01

const SPRITE_SHADER := preload("res://assets/shaders/hd_sprite.gdshader")
const ACTOR_SHADER := preload("res://assets/shaders/hd_actor.gdshader")
## For layers that reach below the feet (the weapon): see that file.
const ACTOR_GROUND_SHADER := preload("res://assets/shaders/hd_actor_ground.gdshader")
const WATER_SHADER := preload("res://assets/shaders/hd_water.gdshader")
const CLOUD_SHADER := preload("res://assets/shaders/hd_cloud_shadow.gdshader")
const RIPPLE_NOISE := preload("res://assets/shaders/ripple_noise.tres")
const CLOUD_NOISE := preload("res://assets/shaders/cloud_noise.tres")
const GLOW_DOT := preload("res://assets/fx/glow_dot.tres")
const SOFT_SHADOW := preload("res://assets/fx/soft_shadow.tres")
const WOOD_RAIL := preload("res://assets/textures/hd/wood_rail.png")
const WOOD_POST := preload("res://assets/textures/hd/wood_post.png")

## Mood per time of day. Angles in degrees. sun_yaw 0 = light from the
## camera's side, shadows falling straight up the screen (north). The owner
## wants them pointing north (2026-10-08): shadows fall back, behind things,
## and faces are lit. Don't lean them.
## Readability lesson (owner, 2026-10-08: "They make things hard to see"):
## shadows are a hint of depth, not a dark patch to lose the kid in. Keep
## shadow_opacity around half, the sun high (short shadows) and cloud
## shadows faint.
## Tuning lesson: tint the SUN warm and keep the AMBIENT cool, keep fog thin.
## Warm sun + warm fog + warm ambient turns everything into orange soup.
## Readability lesson (golden hour, 2026-10-07): a low sun into thick fog
## scattered toward the camera washed the whole screen yellow and drained the
## sprites. Keep the sun above ~30 degrees, fog near the day value, shadows lifted.
const PRESETS := {
	"day": {
		"sun_color": Color(1.0, 0.97, 0.92), "sun_energy": 1.45, "sun_elev": 68.0, "sun_yaw": 0.0, "shadow_opacity": 0.45,
		"ambient": Color(0.62, 0.7, 0.88), "ambient_energy": 0.75,
		"sky_top": Color(0.32, 0.55, 0.92), "sky_horizon": Color(0.78, 0.87, 0.96),
		"fog_density": 0.0025, "fog_albedo": Color(0.92, 0.95, 1.0),
		"exposure": 1.0, "saturation": 1.08, "contrast": 1.04, "glow": 0.3,
		"flashlight": 0.0, "pollen": 0.4, "fireflies": 0.0, "clouds": 0.12, "dof": 0.06,
		"water_glow": 0.3, "phone_glow": 0.0, "actor_lift": 0.08,
	},
	"golden": {
		"sun_color": Color(1.0, 0.76, 0.52), "sun_energy": 1.75, "sun_elev": 42.0, "sun_yaw": 0.0, "shadow_opacity": 0.5,
		"ambient": Color(0.56, 0.56, 0.78), "ambient_energy": 0.82,
		"sky_top": Color(0.34, 0.4, 0.76), "sky_horizon": Color(1.0, 0.66, 0.42),
		"fog_density": 0.003, "fog_albedo": Color(1.0, 0.86, 0.7),
		"exposure": 1.0, "saturation": 1.1, "contrast": 1.1, "glow": 0.3,
		"flashlight": 0.4, "pollen": 1.0, "fireflies": 0.0, "clouds": 0.08, "dof": 0.08,
		"water_glow": 0.24, "phone_glow": 0.0, "actor_lift": 0.12,
	},
	"night": {
		"sun_color": Color(0.58, 0.68, 1.0), "sun_energy": 0.28, "sun_elev": 52.0, "sun_yaw": 0.0, "shadow_opacity": 0.6,
		"ambient": Color(0.18, 0.22, 0.42), "ambient_energy": 0.7,
		"sky_top": Color(0.02, 0.03, 0.09), "sky_horizon": Color(0.06, 0.09, 0.18),
		"fog_density": 0.008, "fog_albedo": Color(0.5, 0.6, 0.95),
		"exposure": 1.0, "saturation": 0.92, "contrast": 1.06, "glow": 0.8,
		"flashlight": 7.0, "pollen": 0.0, "fireflies": 1.0, "clouds": 0.0, "dof": 0.08,
		"water_glow": 0.05, "phone_glow": 0.9, "actor_lift": 0.06,
	},
}

## The 2D realm this view draws (needs Ground, Water, World, World/Kid,
## World/Dog and Atmosphere children, like realms/big_yard/prototype_yard).
@export var realm_path: NodePath
## Camera look-down angle. 35-45 is the classic HD-2D range.
@export_range(15.0, 70.0) var camera_pitch_deg := 40.0
## Vertical field of view. Narrow = flatter, more "diorama".
@export_range(10.0, 60.0) var camera_fov := 28.0
## Camera distance from the kid (meters). Sets how much of the yard you see.
@export var camera_distance := 21.0
## Higher = camera catches up faster.
@export var camera_smoothing := 5.0
## Stretch upright sprites by 1/cos(pitch) so the tilted camera doesn't
## squash them (HD-2D games do the same).
@export var correct_foreshortening := true
## Wind for the cloud shadows (meters per second).
@export var wind := Vector2(0.6, 0.25)

var enabled := false

var _realm: Node2D
var _world2d: Node2D
var _kid2d: Kid
var _dog2d: Dog
var _atmo: Atmosphere
var _cam: Camera3D
var _target := Vector3.ZERO
var _sun: DirectionalLight3D
var _flash: SpotLight3D
var _phone: OmniLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _kid3d: Sprite3D
var _dog3d: Sprite3D
## [2D actor, its Sprite3D, depth bias] for every mirrored actor.
var _actors: Array = []
## Actors already mirrored (instance id -> true), so late arrivals are found.
var _mirrored: Dictionary = {}  # instance id -> its Sprite3D
var _actor_materials: Dictionary = {}  # texture id -> ShaderMaterial
## The time of day's exposure, before the player's brightness.
var _exposure := 1.0
## Settings that change how this view draws.
const GRAPHICS_KEYS := ["shadows", "light_shafts", "reflections", "ambient_occlusion",
		"tilt_shift", "bloom", "particles", "clouds", "brightness"]
## Seconds until the next look for actors that arrived after load.
var _scan_timer := 0.0
const SCAN_SECONDS := 0.2
## The HUD's height at the bottom of the screen (canvas px): the camera keeps
## the map's south edge above it. From the cards themselves, so a taller HUD
## can't quietly cover the bottom row again (it did once: 26 px vs 37).
const HUD_CLEAR_PX := MemberCard.SIZE.y + 8.0
var _ground: MeshInstance3D
var _water: MeshInstance3D
var _clouds: MeshInstance3D
var _cloud_mat: ShaderMaterial
var _pollen: GPUParticles3D
var _fireflies: GPUParticles3D
var _y_scale := 1.0
var _map_m := Rect2()
var _materials: Dictionary = {}
var _quads: Dictionary = {}
var _from: Dictionary = {}
var _to: Dictionary = {}
var _tween: Tween
var _prop_count := 0


var _shake := 0.0
var _shake_time := 0.0
var _shake_left := 0.0


func _ready() -> void:
	add_to_group("hd_view")
	EventBus.camera_shake.connect(func(s: float, t: float) -> void:
		_shake = maxf(_shake, s)
		_shake_time = maxf(t, 0.01)
		_shake_left = maxf(_shake_left, t))
	_realm = get_node_or_null(realm_path) as Node2D
	if _realm == null:
		Debug.log_error("HdView: realm_path doesn't point at a 2D realm")
		return
	_world2d = _realm.get_node("World")
	_kid2d = _realm.get_node("World/Kid")
	_dog2d = _realm.get_node("World/Dog")
	_atmo = _realm.get_node("Atmosphere")
	_y_scale = 1.0 / cos(deg_to_rad(camera_pitch_deg)) if correct_foreshortening else 1.0
	if _realm.has_method("map_rect"):
		var r: Rect2 = _realm.map_rect()
		_map_m = Rect2(r.position * PX, r.size * PX)

	_build_environment()
	_build_camera()
	_build_props()
	_build_fences()
	_build_actors()
	_build_particles()
	_build_clouds()
	await _build_ground()

	EventBus.time_of_day_changed.connect(func(t: String) -> void: _apply_time(t, 0.8))
	_apply_time(_atmo.time_name, 0.0)
	_apply_graphics()
	Settings.changed.connect(_on_setting_changed)
	set_enabled(Settings.get_value("view") == "hd2d")
	Debug.log_info("HD-2D view ready (%d sprite props). F6 toggles the classic 2D view." % _prop_count)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle_view"):
		# Same as the View option in the settings menu (and remembered like it).
		Settings.set_value("view", "classic" if enabled else "hd2d")


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "view":
		set_enabled(value == "hd2d")
	elif key in GRAPHICS_KEYS:
		_apply_graphics()


## The player's graphics options (Settings), on top of what the renderer can
## do at all (renderer_caps). Called at build and whenever one changes.
func _apply_graphics() -> void:
	var caps := renderer_caps()
	_env.volumetric_fog_enabled = caps["volumetric_fog"] and Settings.get_value("light_shafts")
	if _env.volumetric_fog_enabled and not _to.is_empty():
		_env.volumetric_fog_density = _to["fog_density"]
		_env.volumetric_fog_albedo = _to["fog_albedo"]
	_env.ssr_enabled = caps["ssr"] and Settings.get_value("reflections")
	_env.ssao_enabled = caps["ssao"] and Settings.get_value("ambient_occlusion")
	_env.glow_enabled = Settings.get_value("bloom")
	var attrs := _cam.attributes as CameraAttributesPractical
	var dof: bool = caps["dof"] and Settings.get_value("tilt_shift")
	attrs.dof_blur_far_enabled = dof
	attrs.dof_blur_near_enabled = dof
	var shadows: String = Settings.get_value("shadows")
	_sun.shadow_enabled = shadows != "off"
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if shadows == "low" \
			else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	RenderingServer.directional_shadow_atlas_set_size(2048 if shadows == "low" else 4096, true)
	_pollen.visible = Settings.get_value("particles")
	_fireflies.visible = Settings.get_value("particles")
	_clouds.visible = Settings.get_value("clouds")
	_env.tonemap_exposure = _exposure * Settings.get_value("brightness")


## Show the HD-2D view (true) or the classic 2D one (false).
func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	_cam.current = on
	_world2d.visible = not on
	for layer_name in ["Ground", "Water"]:
		var layer := _realm.get_node_or_null(layer_name) as CanvasItem
		if layer:
			layer.visible = not on
	_atmo.render_2d = not on
	ScreenScaler.native_3d = on
	Debug.log_verbose("HD-2D view %s" % ("on" if on else "off"))


## The HD-2D camera (Fx projects effects through it).
func camera() -> Camera3D:
	return _cam


## 2D pixel position -> 3D meters on the ground plane.
static func to3(p: Vector2, height := 0.0) -> Vector3:
	return Vector3(p.x * PX, height, p.y * PX)


## Which renderer is running decides which effects to switch on (asking a
## lower renderer for Forward+ effects only fills the log with warnings).
static func renderer_caps() -> Dictionary:
	var rm := RenderingServer.get_current_rendering_method()
	var full := rm == "forward_plus"
	return {"volumetric_fog": full, "ssr": full, "ssao": full, "dof": rm != "gl_compatibility"}


func _process(delta: float) -> void:
	if not enabled or not is_instance_valid(_kid2d):
		return
	# Enemies spawned mid-fight, NPCs walking in: mirror anything new.
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = SCAN_SECONDS
		_add_new_actors()
	for a: Array in _actors:
		var s3 := a[1] as Sprite3D
		# Check before casting: enemies are freed when they die.
		if not is_instance_valid(a[0]):
			s3.visible = false
			continue
		var actor := a[0] as Node2D
		# The actor's OWN visibility: in HD mode the whole 2D World is hidden on
		# purpose, so is_visible_in_tree() would hide every actor here too.
		var s2 := actor.get_node(a[3]) as Sprite2D
		s3.visible = actor.visible and s2.visible
		_sync_actor(s3, s2, actor.global_position, a[2])
	_follow_camera(delta)
	_aim_flashlight()
	# Particles live in world space; keep their spawn boxes over the view.
	var center := Vector3(_target.x, 0.0, _target.z)
	_pollen.global_position = center + Vector3(0, 1.4, 0)
	_fireflies.global_position = center + Vector3(0, 0.7, 0)
	# Clouds drift with the wind and wrap around (their noise is seamless).
	var c := _clouds.position + Vector3(wind.x, 0.0, wind.y) * delta
	c.x = wrapf(c.x, center.x - 40.0, center.x + 40.0)
	c.z = wrapf(c.z, center.z - 40.0, center.z + 40.0)
	_clouds.position = c


# -----------------------------------------------------------------------------
# Ground: render the 2D ground (tiles + decals) once into a texture
# -----------------------------------------------------------------------------
func _build_ground() -> void:
	var ground2d := _realm.get_node("Ground") as TileMapLayer
	var water2d := _realm.get_node("Water") as TileMapLayer
	var tile := float(ground2d.tile_set.tile_size.x) if ground2d.tile_set else 32.0
	var used := ground2d.get_used_rect().merge(water2d.get_used_rect())
	var rect := Rect2(ground2d.position + Vector2(used.position) * tile, Vector2(used.size) * tile)

	var vp := SubViewport.new()
	vp.size = Vector2i(rect.size)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var root := Node2D.new()
	root.position = -rect.position
	for layer: TileMapLayer in [ground2d, water2d]:
		var copy := layer.duplicate() as TileMapLayer
		copy.material = null  # the 3D water does its own shimmer
		copy.visible = true
		root.add_child(copy)
	# Flat decals (wildflowers, tufts) become part of the ground texture.
	for p in _world2d.get_children():
		if p is Prop and p.data and p.data.ground_decal and p.data.frames == 1 and p.sprite:
			var s := p.sprite.duplicate() as Sprite2D
			s.position = p.global_position
			s.z_index = 1
			root.add_child(s)
	vp.add_child(root)
	add_child(vp)
	var img: Image = null
	# The headless (dummy) renderer never draws, so don't wait for a frame there.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		img = vp.get_texture().get_image()
	var tex: Texture2D
	if img == null or img.is_empty():
		# Headless / dummy renderer: nothing to bake. Plain green keeps it valid.
		Debug.log_verbose("HdView: ground bake unavailable (headless?), using a flat color")
		var fallback := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		fallback.fill(Color(0.36, 0.6, 0.25))
		tex = ImageTexture.create_from_image(fallback)
	else:
		tex = ImageTexture.create_from_image(img)
	vp.queue_free()

	var plane := PlaneMesh.new()
	plane.size = rect.size * PX
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 1.0
	mat.metallic_specular = 0.25
	_ground = MeshInstance3D.new()
	_ground.name = "Ground"
	_ground.mesh = plane
	_ground.material_override = mat
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground.layers = GROUND_LAYER
	_ground.position = to3(rect.get_center())
	add_child(_ground)

	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	wmat.set_shader_parameter("ground_tex", tex)
	wmat.set_shader_parameter("ripple_noise", RIPPLE_NOISE)
	_water = MeshInstance3D.new()
	_water.name = "Water"
	_water.mesh = plane
	_water.material_override = wmat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.layers = GROUND_LAYER
	_water.position = _ground.position + Vector3(0, 0.004, 0)
	add_child(_water)
	if not _to.is_empty():
		_water.material_override.set_shader_parameter("self_glow", _to["water_glow"])


# -----------------------------------------------------------------------------
# Props: every 2D Prop becomes a sprite quad
# -----------------------------------------------------------------------------
func _build_props() -> void:
	var holder := Node3D.new()
	holder.name = "Props"
	add_child(holder)
	for p in _world2d.get_children():
		if not (p is Prop) or p.data == null or p.data.texture == null:
			continue
		var d: PropData = p.data
		var lying := d.ground_decal
		if lying and d.frames == 1:
			continue  # baked into the ground texture
		var mi := MeshInstance3D.new()
		mi.mesh = _quad_for(d)
		mi.material_override = _material_for(d, lying)
		var flip := -1.0 if p.flip_h else 1.0
		if lying:
			# Lily pads: lie flat, just above the water surface.
			mi.position = to3(p.global_position, 0.02)
			mi.rotation.x = -PI * 0.5
			mi.scale = Vector3(flip, 1.0, 1.0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		else:
			mi.position = to3(p.global_position) + Vector3(0.0, 0.0, PROP_DEPTH_BIAS)
			mi.scale = Vector3(flip, _y_scale, 1.0)
		mi.layers = PROP_LAYER
		holder.add_child(mi)
		_prop_count += 1


## One quad per prop type, offset so the prop's base point sits at the origin.
func _quad_for(d: PropData) -> QuadMesh:
	var key := d.get_instance_id()
	if not _quads.has(key):
		var size := d.region.size if d.region.size != Vector2.ZERO else d.texture.get_size()
		size.x /= d.frames
		var q := QuadMesh.new()
		q.size = size * PX
		q.center_offset = Vector3((size.x * 0.5 - d.base.x) * PX, (d.base.y - size.y * 0.5) * PX, 0.0)
		_quads[key] = q
	return _quads[key]


func _material_for(d: PropData, lying: bool) -> ShaderMaterial:
	var key := d.get_instance_id()
	if not _materials.has(key):
		var tex_size := d.texture.get_size()
		var region := d.region if d.region.size != Vector2.ZERO else Rect2(Vector2.ZERO, tex_size)
		var m := ShaderMaterial.new()
		m.shader = SPRITE_SHADER
		m.set_shader_parameter("tex", d.texture)
		m.set_shader_parameter("frame_rect", Vector4(region.position.x / tex_size.x, region.position.y / tex_size.y,
				region.size.x / d.frames / tex_size.x, region.size.y / tex_size.y))
		m.set_shader_parameter("texel", Vector2(1.0, 1.0) / tex_size)
		m.set_shader_parameter("frames", float(d.frames))
		m.set_shader_parameter("fps", d.frame_fps)
		m.set_shader_parameter("sway_strength", d.sway_strength)
		m.set_shader_parameter("sway_speed", d.sway_speed)
		m.set_shader_parameter("rooted", d.sway_rooted)
		m.set_shader_parameter("lying_flat", lying)
		_materials[key] = m
	return _materials[key]


# -----------------------------------------------------------------------------
# Fences: real 3D posts and rails
# -----------------------------------------------------------------------------
func _build_fences() -> void:
	var holder := Node3D.new()
	holder.name = "Fences"
	add_child(holder)
	if not _realm.has_method("fence_cells"):
		return
	var cells: Dictionary = _realm.fence_cells()
	var styles: Dictionary = _realm.cfg("HD_FENCE_STYLES")
	var kit := {
		"wood": {"post": _box_mesh(Vector3(0.17, 1.0, 0.17)), "rail": _box_mesh(Vector3(1.0, 0.11, 0.07)),
				"post_mat": _wood_material(WOOD_POST), "rail_mat": _wood_material(WOOD_RAIL),
				"rails": [0.38, 0.72], "bars": 0},
		"iron": {"post": _box_mesh(Vector3(0.09, 1.25, 0.09)), "rail": _box_mesh(Vector3(1.0, 0.05, 0.04)),
				"bar": _box_mesh(Vector3(0.035, 1.12, 0.035)),
				"post_mat": _iron_material(), "rail_mat": _iron_material(),
				"rails": [0.12, 1.02], "bars": 4},
	}
	# Same post spot as the 2D collision: tile center, 6 px above its bottom edge.
	var post_off := Vector3(0.5, 0.0, 1.0 - 6.0 * PX)
	for c: Vector2i in cells:
		var k: Dictionary = kit.get(styles.get(cells[c], "wood"), kit["wood"])
		var base := Vector3(c.x, 0.0, c.y) + post_off
		var post_h: float = (k["post"] as BoxMesh).size.y
		_add_box(holder, k["post"], k["post_mat"], base + Vector3(0, post_h * 0.5, 0), Vector3.ZERO)
		for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			# Only join posts of the same kind (iron doesn't run into wood).
			if not cells.has(c + dir) or cells[c + dir] != cells[c]:
				continue
			var rot := Vector3.ZERO if dir == Vector2i.RIGHT else Vector3(0, PI * 0.5, 0)
			var along := Vector3(dir.x, 0, dir.y)
			for rail_h: float in k["rails"]:
				_add_box(holder, k["rail"], k["rail_mat"], base + along * 0.5 + Vector3(0, rail_h, 0), rot)
			for b in k["bars"]:
				var t := float(b + 1) / float(k["bars"] + 1)
				var bar_h: float = (k["bar"] as BoxMesh).size.y
				_add_box(holder, k["bar"], k["post_mat"], base + along * t + Vector3(0, bar_h * 0.5, 0), Vector3.ZERO)


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Old wrought iron: dark, a little shiny, a hint of rust in the color.
func _iron_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.1, 0.11)
	m.metallic = 0.55
	m.roughness = 0.55
	return m


func _add_box(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.layers = PROP_LAYER
	parent.add_child(mi)


## Pixel-art wood on 3D boxes: world-space triplanar mapping at 32 px per
## meter, so the wood's pixels match the sprites' pixel size exactly.
func _wood_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE
	m.roughness = 0.9
	return m


# -----------------------------------------------------------------------------
# Actors: sprites that mirror the 2D kid and dog
# -----------------------------------------------------------------------------
func _build_actors() -> void:
	_kid3d = _add_actor(_kid2d, KID_DEPTH_BIAS)
	_dog3d = _add_actor(_dog2d, DOG_DEPTH_BIAS)
	_add_new_actors()
	_flash = SpotLight3D.new()
	_flash.name = "Flashlight"
	_flash.light_color = Color(1.0, 0.93, 0.8)
	_flash.spot_range = 11.0
	_flash.spot_angle = 30.0
	_flash.spot_angle_attenuation = 2.2
	_flash.shadow_enabled = true
	_flash.light_volumetric_fog_energy = 0.6
	add_child(_flash)
	# The phone screen's own soft glow: keeps the kid (and the dog at his
	# heels) readable at night even when the flashlight points away.
	_phone = OmniLight3D.new()
	_phone.name = "PhoneGlow"
	_phone.light_color = Color(0.75, 0.85, 1.0)
	_phone.omni_range = 2.6
	_phone.omni_attenuation = 1.6
	_phone.shadow_enabled = false
	add_child(_phone)


## Mirror every "hd_actor" that doesn't have a 3D sprite yet. Runs every
## SCAN_SECONDS, so it must only ever ADD SPRITES (lights and other one-time
## setup belong in _build_actors: they once leaked in here and piled up five
## lights a second on the kid).
func _add_new_actors() -> void:
	for n in get_tree().get_nodes_in_group("hd_actor"):
		if not _mirrored.has(n.get_instance_id()) and n is Node2D and n.has_node("Sprite"):
			_add_actor(n, NPC_DEPTH_BIAS)


## Mirror new actors now instead of at the next scan (an item popping out of
## the ground would miss the start of its hop).
func mirror_new_actors() -> void:
	if enabled:
		_add_new_actors()


func _add_actor(actor: Node2D, depth_bias: float) -> Sprite3D:
	var s3 := _make_actor_sprite(actor.get_node("Sprite") as Sprite2D, actor.name)
	_actors.append([actor, s3, depth_bias, "Sprite"])
	_mirrored[actor.get_instance_id()] = s3
	# Extra layers drawn with the body (the kid's weapon while he swings):
	# meta "hd_layers" = {child Sprite2D name: depth bias next to the body}.
	var layers: Dictionary = actor.get_meta("hd_layers", {})
	for layer_name: String in layers:
		var l2 := actor.get_node_or_null(layer_name) as Sprite2D
		if l2:
			var l3 := _make_actor_sprite(l2, actor.name + layer_name, true)
			_actors.append([actor, l3, depth_bias + float(layers[layer_name]), layer_name])
	# Drop the 3D sprites when their actor leaves for good.
	actor.tree_exiting.connect(func() -> void: _forget_actor(actor), CONNECT_ONE_SHOT)
	return s3


func _forget_actor(actor: Node2D) -> void:
	_mirrored.erase(actor.get_instance_id())
	for a: Array in _actors:
		if a[0] == actor and is_instance_valid(a[1]):
			(a[1] as Sprite3D).queue_free()
	_actors = _actors.filter(func(a: Array) -> bool: return a[0] != actor)


## `ground_clamp`: a layer whose art reaches below the feet (a swung club) gets
## the ground-clamped material, or its low end sinks into the ground plane.
func _make_actor_sprite(src: Sprite2D, actor_name: String, ground_clamp := false) -> Sprite3D:
	var s := Sprite3D.new()
	s.name = actor_name
	s.texture = src.texture
	s.hframes = src.hframes
	s.vframes = src.vframes
	s.pixel_size = PX
	s.centered = true
	# Same feet-on-origin offset as the 2D sprite (3D y points up, so it flips).
	s.offset = Vector2(src.offset.x, -src.offset.y)
	s.shaded = true
	s.double_sided = true
	# Lit like the ground it stands on, never backlit (see hd_actor.gdshader).
	s.material_override = _actor_material(src.texture, ground_clamp)
	s.set_meta("ground_clamp", ground_clamp)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if ground_clamp else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	s.scale = Vector3(1.0, _y_scale, 1.0)
	s.layers = ACTOR_LAYER
	add_child(s)
	# Soft contact shadow under the feet (reads well at night, when the moon's
	# shadow is faint). Decals are Forward+/Mobile only; harmless elsewhere.
	var blob := Decal.new()
	blob.texture_albedo = SOFT_SHADOW
	blob.size = Vector3(0.95, 0.6, 0.42)
	blob.modulate = Color(1, 1, 1, 0.55)
	blob.position = Vector3(0, 0.25, 0)
	blob.scale = Vector3(1.0, 1.0 / _y_scale, 1.0)  # undo the sprite's stretch
	blob.cull_mask = GROUND_LAYER  # only the ground, never the sprites
	s.add_child(blob)
	return s


## One character material per sprite sheet.
func _actor_material(tex: Texture2D, ground_clamp := false) -> ShaderMaterial:
	var key := "%d%s" % [tex.get_instance_id() if tex else 0, "c" if ground_clamp else ""]
	if not _actor_materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = ACTOR_GROUND_SHADER if ground_clamp else ACTOR_SHADER
		m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("lift", _to.get("actor_lift", 0.08) if not _to.is_empty() else 0.08)
		_actor_materials[key] = m
	return _actor_materials[key]


func _sync_actor(s3: Sprite3D, s2: Sprite2D, pos: Vector2, depth_bias: float) -> void:
	if s3.texture != s2.texture:  # a new weapon in hand
		s3.texture = s2.texture
		s3.hframes = s2.hframes
		s3.vframes = s2.vframes
		s3.material_override = _actor_material(s2.texture, bool(s3.get_meta("ground_clamp", false)))
	s3.position = to3(pos) + Vector3(0.0, 0.0, depth_bias)
	s3.frame_coords = s2.frame_coords
	s3.offset = Vector2(s2.offset.x, -s2.offset.y)  # hops (item pickups)
	s3.flip_h = s2.flip_h
	s3.modulate = s2.modulate  # hit flashes, attack telegraphs


func _aim_flashlight() -> void:
	var face := Vector3(_kid2d.facing.x, 0.0, _kid2d.facing.y).normalized()
	if face == Vector3.ZERO:
		face = Vector3.BACK
	var origin := _kid3d.position + Vector3(0, 1.05, 0) + face * 0.25
	_flash.position = origin
	_flash.look_at(origin + face * 4.0 + Vector3(0, -1.6, 0), Vector3.UP)
	_flash.visible = _kid2d.light_on
	_phone.position = _kid3d.position + Vector3(0, 0.9, 0.35) + face * 0.2
	_phone.visible = _kid2d.light_on


# -----------------------------------------------------------------------------
# Camera
# -----------------------------------------------------------------------------
func _build_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.fov = camera_fov
	_cam.near = 1.0
	_cam.far = 200.0
	_cam.rotation = Vector3(-deg_to_rad(camera_pitch_deg), 0.0, 0.0)
	var attrs := CameraAttributesPractical.new()
	var dof: bool = renderer_caps()["dof"]
	# Tilt-shift: the far (top of screen) and near (bottom) edges go soft.
	attrs.dof_blur_far_enabled = dof
	attrs.dof_blur_far_distance = camera_distance + 3.0
	attrs.dof_blur_far_transition = 9.0
	attrs.dof_blur_near_enabled = dof
	attrs.dof_blur_near_distance = camera_distance - 4.0
	attrs.dof_blur_near_transition = 3.0
	attrs.dof_blur_amount = 0.08
	_cam.attributes = attrs
	add_child(_cam)
	_target = to3(_kid2d.global_position)
	_place_camera()


## Jump the camera straight to the leader (after a teleport, a scene load...).
func snap_camera() -> void:
	_target = _clamp_to_map(_leader3d().position)
	_place_camera()


## The 3D sprite of whoever the player drives (Party), so the camera follows
## the dog after a switch. The kid until Party knows better.
func _leader3d() -> Sprite3D:
	var l := Party.leader
	if is_instance_valid(l):
		var s3 = _mirrored.get(l.get_instance_id())
		if is_instance_valid(s3):
			return s3
	return _kid3d


func _follow_camera(delta: float) -> void:
	var want := _clamp_to_map(_leader3d().position)
	_target = _target.lerp(want, 1.0 - exp(-camera_smoothing * delta))
	_place_camera()


## Keep the view over the map (the apron fills the rest on wide screens);
## center on an axis where the map is smaller than the view.
## North-south it's perspective, not a flat window: the ground near the
## camera (the bottom of the screen) fills more of the picture, so less of
## it shows below the center than above. The bottom stop is measured from
## the camera's real angle (_ground_offset), up to the HUD's top edge: the
## old flat estimate stopped the camera ~2.7 m early and the kid walked off
## the bottom of the screen (owner, 2026-10-08).
func _clamp_to_map(p: Vector3) -> Vector3:
	if _map_m.size == Vector2.ZERO:
		return p
	var vis := get_viewport().get_visible_rect().size
	var aspect := vis.x / maxf(1.0, vis.y)
	var half_h := camera_distance * tan(deg_to_rad(camera_fov * 0.5))
	var half_w := half_h * aspect
	var half_d := half_h / sin(deg_to_rad(camera_pitch_deg))
	var out := p
	if _map_m.size.x > half_w * 2.0:
		out.x = clampf(p.x, _map_m.position.x + half_w, _map_m.end.x - half_w)
	else:
		out.x = _map_m.get_center().x
	# The map's south edge sits at the HUD's top edge at most; north, the
	# apron trees may show past the fence (as before).
	var south := _ground_offset(1.0 - 2.0 * HUD_CLEAR_PX / maxf(1.0, vis.y))
	var z_max := _map_m.end.y - south
	var z_min := _map_m.position.y + half_d * 0.8
	# A short map fits: line its south edge up and let the top show apron.
	out.z = clampf(p.z, z_min, z_max) if z_min <= z_max else z_max
	return out


## How far south of the camera's target (m) the ground is at a screen height
## (-1 = top edge, 0 = center, 1 = bottom edge). Camera3D's fov is vertical.
func _ground_offset(screen_v: float) -> float:
	var pitch := deg_to_rad(camera_pitch_deg)
	var down := pitch + atan(tan(deg_to_rad(camera_fov * 0.5)) * screen_v)  # below horizontal
	return camera_distance * cos(pitch) - camera_distance * sin(pitch) / tan(down)


func _place_camera() -> void:
	var pitch := deg_to_rad(camera_pitch_deg)
	_cam.position = _target + Vector3(0.0, sin(pitch), cos(pitch)) * camera_distance
	if _shake_left > 0.0:
		_shake_left -= get_process_delta_time()
		var k := maxf(_shake_left / _shake_time, 0.0)
		_cam.h_offset = randf_range(-1, 1) * _shake * k * PX
		_cam.v_offset = randf_range(-1, 1) * _shake * k * PX
	elif _cam.h_offset != 0.0 or _cam.v_offset != 0.0:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0


# -----------------------------------------------------------------------------
# Light, sky, fog, glow
# -----------------------------------------------------------------------------
func _build_environment() -> void:
	var caps := renderer_caps()
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_white = 4.0
	_env.glow_enabled = true
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.0
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.ssao_enabled = caps["ssao"]
	_env.ssao_radius = 0.6
	_env.ssao_intensity = 1.6
	_env.ssr_enabled = caps["ssr"]
	_env.ssr_max_steps = 48
	_env.ssr_fade_in = 0.1
	_env.ssr_fade_out = 1.5
	_env.ssr_depth_tolerance = 0.4
	_env.volumetric_fog_enabled = caps["volumetric_fog"]
	_env.volumetric_fog_anisotropy = 0.55
	_env.volumetric_fog_length = 48.0
	_env.volumetric_fog_detail_spread = 2.0
	_env.volumetric_fog_sky_affect = 0.0
	_env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 70.0
	_sun.shadow_blur = 1.2
	_sun.light_angular_distance = 0.8
	_sun.light_volumetric_fog_energy = 1.0
	add_child(_sun)


func _build_particles() -> void:
	_pollen = _make_particles("Pollen", 160, 9.0, Vector3(16, 2.2, 10), 0.03, GLOW_DOT, 1.3)
	(_pollen.process_material as ParticleProcessMaterial).gravity = Vector3(0.05, 0.02, 0.0)
	_fireflies = _make_particles("Fireflies", 55, 6.0, Vector3(16, 0.8, 10), 0.07, GLOW_DOT, 3.0,
			Color(0.75, 1.0, 0.35))


func _make_particles(pname: String, amount: int, life: float, box: Vector3, size: float,
		tex: Texture2D, glow: float, tint := Color(1.0, 0.95, 0.8)) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = Vector3(1, 0.2, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	# Colors above 1.0 feed the glow (bloom) pass.
	mat.albedo_color = Color(tint.r * glow, tint.g * glow, tint.b * glow)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var gp := GPUParticles3D.new()
	gp.name = pname
	gp.amount = amount
	gp.lifetime = life
	gp.preprocess = life
	gp.local_coords = false
	gp.process_material = pm
	gp.draw_pass_1 = quad
	gp.visibility_aabb = AABB(-box * 2.0, box * 4.0)
	gp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(gp)
	return gp


func _build_clouds() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = CLOUD_SHADER
	_cloud_mat.set_shader_parameter("noise", CLOUD_NOISE)
	_clouds = MeshInstance3D.new()
	_clouds.name = "CloudShadows"
	_clouds.mesh = plane
	_clouds.material_override = _cloud_mat
	_clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_clouds.position = Vector3(_map_m.get_center().x, 30.0, _map_m.get_center().y)
	add_child(_clouds)


# -----------------------------------------------------------------------------
# Time of day
# -----------------------------------------------------------------------------
func _apply_time(time_name: String, seconds: float) -> void:
	if not PRESETS.has(time_name):
		return
	_from = _to.duplicate()
	_to = PRESETS[time_name]
	if _tween:
		_tween.kill()
	if seconds <= 0.0 or _from.is_empty():
		_blend(1.0)
	else:
		_tween = create_tween()
		_tween.tween_method(_blend, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	_pollen.emitting = _to["pollen"] > 0.0
	_fireflies.emitting = _to["fireflies"] > 0.0


## t = 0..1 between the previous mood (_from) and the new one (_to).
func _blend(t: float) -> void:
	var v := {}
	for k: String in _to:
		var a: Variant = _from.get(k, _to[k])
		var b: Variant = _to[k]
		v[k] = a.lerp(b, t) if a is Color else lerpf(a, b, t)
	_sun.light_color = v["sun_color"]
	_sun.light_energy = v["sun_energy"]
	_sun.rotation = Vector3(-deg_to_rad(v["sun_elev"]), deg_to_rad(v["sun_yaw"]), 0.0)
	_sun.shadow_opacity = v["shadow_opacity"]
	_env.ambient_light_color = v["ambient"]
	_env.ambient_light_energy = v["ambient_energy"]
	_sky_mat.sky_top_color = v["sky_top"]
	_sky_mat.sky_horizon_color = v["sky_horizon"]
	_sky_mat.ground_horizon_color = v["sky_horizon"]
	if _env.volumetric_fog_enabled:
		_env.volumetric_fog_density = v["fog_density"]
		_env.volumetric_fog_albedo = v["fog_albedo"]
	_exposure = v["exposure"]
	_env.tonemap_exposure = _exposure * Settings.get_value("brightness")
	_env.adjustment_saturation = v["saturation"]
	_env.adjustment_contrast = v["contrast"]
	_env.glow_intensity = v["glow"]
	_flash.light_energy = v["flashlight"]
	_phone.light_energy = v["phone_glow"]
	if _water:
		(_water.material_override as ShaderMaterial).set_shader_parameter("self_glow", v["water_glow"])
	if renderer_caps()["dof"]:
		(_cam.attributes as CameraAttributesPractical).dof_blur_amount = v["dof"]
	_cloud_mat.set_shader_parameter("coverage", v["clouds"])
	_pollen.transparency = 1.0 - v["pollen"]
	_fireflies.transparency = 1.0 - v["fireflies"]
	for m: ShaderMaterial in _actor_materials.values():
		m.set_shader_parameter("lift", v["actor_lift"])
