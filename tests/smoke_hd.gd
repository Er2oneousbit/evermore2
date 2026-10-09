# =============================================================================
# smoke_hd.gd  -  Headless checks for the HD-2D view (systems/hd2d/hd_view.gd)
# -----------------------------------------------------------------------------
# WHAT:  Loads realms/big_yard/yard_hd.tscn and checks the 3D view really
#        mirrors the 2D game underneath:
#          1. every 2D prop (except flat decals baked into the ground) has a
#             3D sprite, and every fence cell has a 3D post
#          2. kid and dog 3D sprites follow their 2D bodies as they move, and
#             same-row depth ties are broken kid > dog > props (no z-fighting)
#          3. the camera stays over the map
#          4. F6 swaps HD-2D <-> classic 2D cleanly (visibility, 3D camera,
#             ScreenScaler mode, 2D mood layers)
#          5. time of day (Atmosphere) reaches the 3D lights
#          6. the camera keeps the kid on screen, clear of the HUD, at the
#             map's bottom and top rows, in both views and on a short map
#             (the arena); at the bottom he once walked right off screen
#          1b. each shop is a real 3D building (walls, roof, counter,
#              sign) casting shadows; the shutter panel shows only while it's
#              closed; the kid stops at the counter and can still talk
#        It can't judge how things LOOK: that's what the screenshot tour is for.
#
# RUN:   godot --headless --path . --fixed-fps 60 res://tests/smoke_hd.tscn
#        Exit code 0 = PASS, 1 = FAIL.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

const HD_SCENE := preload("res://realms/big_yard/yard_hd.tscn")
const YardScript := preload("res://realms/big_yard/prototype_yard.gd")

var _failures: PackedStringArray = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := HD_SCENE.instantiate()
	add_child(scene)
	var yard: Node2D = scene.get_node("Yard")
	var hd: HdView = scene.get_node("HdView")
	var kid: Kid = yard.get_node("World/Kid")
	var dog: Dog = yard.get_node("World/Dog")
	var atmo: Atmosphere = yard.get_node("Atmosphere")
	await _frames(10)
	_check(hd.enabled, "HD view didn't finish building / enable itself")

	# --- 1. Everything got mirrored --------------------------------------------
	var expected_props := 0
	var stalls: Array[Prop] = []
	for p in yard.get_node("World").get_children():
		if p is Prop and p.data and ShopBuilding3D.STYLES.has(p.data.resource_path.get_file().get_basename()):
			stalls.append(p)  # real 3D buildings, checked in section 1b
		elif p is Prop and p.data and not (p.data.ground_decal and p.data.frames == 1):
			expected_props += 1
	var got_props := hd.get_node("Props").get_child_count()
	_check(got_props == expected_props, "3D props %d, expected %d (one per non-decal 2D prop)" % [got_props, expected_props])
	var fence_cells := "".join(YardScript.LAYOUT).count(YardScript.FENCE_CHAR)
	var posts := 0
	for m in hd.get_node("Fences").get_children():
		if (m as MeshInstance3D).mesh is BoxMesh and ((m as MeshInstance3D).mesh as BoxMesh).size.y > 0.5:
			posts += 1
	_check(posts == fence_cells, "3D fence posts %d, expected %d (one per fence cell)" % [posts, fence_cells])

	# --- 1b. Shops are real 3D buildings (not sprite quads) ----------------------
	await _check_shops(hd, kid, stalls)
	await _check_texel_aa(hd)

	# --- 2. Actors follow their 2D bodies --------------------------------------
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	await _frames(20)
	var kid3d: Sprite3D = hd.get_node("Kid")
	var dog3d: Sprite3D = hd.get_node("Dog")
	# (within the few-cm depth tie-breakers, see HdView.KID_DEPTH_BIAS)
	_check(kid3d.position.distance_to(HdView.to3(kid.global_position)) < 0.05, "kid 3D sprite not at the 2D kid's position")
	_check(dog3d.position.distance_to(HdView.to3(dog.global_position)) < 0.05, "dog 3D sprite not at the 2D dog's position")
	_check(kid3d.frame_coords == (kid.get_node("Sprite") as Sprite2D).frame_coords, "kid 3D frame differs from the 2D animation frame")
	# The 2D World is hidden in HD mode; the 3D actors must still show.
	_check(kid3d.visible and dog3d.visible, "kid/dog 3D sprites must be visible in HD mode (kid %s, dog %s)" % [kid3d.visible, dog3d.visible])
	# Same-row tie: the kid must be in front of a prop standing on his row,
	# and in front of the dog (otherwise they z-fight into stripes).
	_check(HdView.KID_DEPTH_BIAS > HdView.DOG_DEPTH_BIAS and HdView.DOG_DEPTH_BIAS > HdView.PROP_DEPTH_BIAS,
			"depth tie-breakers must order kid > dog > props")

	# --- 3. Camera stays over the map ------------------------------------------
	var cam: Camera3D = hd.get_node("Camera")
	_check(cam.current, "HD camera isn't the current camera")
	var map := Rect2(Vector2.ZERO, Vector2(YardScript.LAYOUT[0].length(), YardScript.LAYOUT.size()))
	var look := Vector2(cam.position.x, cam.position.z - cam.position.y / tan(deg_to_rad(hd.camera_pitch_deg)))
	_check(map.grow(0.5).has_point(look), "camera looks at %s, outside the map %s" % [look, map])

	# --- 4. F6 toggles views ------------------------------------------------------
	_tap("debug_toggle_view")
	await _frames(2)
	_check(not hd.enabled and not hd.visible, "F6 didn't switch the HD view off")
	_check(yard.get_node("World").visible, "2D world still hidden after switching to 2D")
	_check(not ScreenScaler.native_3d, "ScreenScaler still in native 3D mode in 2D view")
	_check(atmo.render_2d, "2D mood layers still off in 2D view")
	_check(not cam.current, "HD camera still current in 2D view")
	_tap("debug_toggle_view")
	await _frames(2)
	_check(hd.enabled and not yard.get_node("World").visible and ScreenScaler.native_3d, "F6 didn't switch back to HD")

	# --- 4b. Nothing piles up over time (a leak once added 5 lights a second) ---
	var lights_before := hd.find_children("*", "Light3D", true, false).size()
	var nodes_before := hd.get_child_count()
	await _wait(1.5)
	var lights_after := hd.find_children("*", "Light3D", true, false).size()
	_check(lights_after == lights_before, "3D lights must not pile up (%d -> %d)" % [lights_before, lights_after])
	_check(hd.get_child_count() == nodes_before, "HdView children must not grow by themselves (%d -> %d)" % [nodes_before, hd.get_child_count()])

	# --- 5. Time of day reaches the 3D lights ------------------------------------
	atmo.set_time("night", 0.0)
	await _wait(1.0)
	var sun: DirectionalLight3D = hd.get_node("Sun")
	var want: float = HdView.PRESETS["night"]["sun_energy"]
	_check(absf(sun.light_energy - want) < 0.01, "night sun energy %.2f, expected %.2f" % [sun.light_energy, want])
	var flies: GPUParticles3D = hd.get_node("Fireflies")
	_check(flies.emitting, "fireflies should be on at night")

	# --- 6. The kid stays on screen at the map's edges ---------------------------
	atmo.set_time("day", 0.0)
	await _check_edges(yard, kid, "yard, HD-2D")
	_tap("debug_toggle_view")
	await _frames(2)
	await _check_edges(yard, kid, "yard, classic 2D")
	_tap("debug_toggle_view")
	await _frames(2)
	scene.queue_free()
	await _frames(2)
	var arena: Node = load("res://realms/test/combat_arena_hd.tscn").instantiate()
	add_child(arena)
	await _frames(10)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	var arena_kid: Kid = arena.get_node("Yard/World/Kid")
	await _check_edges(arena.get_node("Yard"), arena_kid, "arena (short map), HD-2D")
	arena.queue_free()
	await _frames(2)

	if _failures.is_empty():
		print("[TEST] PASS  smoke_hd  (%d 3D props, %d fence posts)" % [got_props, posts])
		get_tree().quit(0)
	else:
		for f in _failures:
			printerr("[TEST] FAIL  ", f)
		get_tree().quit(1)


## Each stall is a 3D building: walls, roof, counter, sign, casting
## shadows; its shutter shows only while the shop is closed; and the kid can
## still reach the counter (the 2D footprint) and talk to keeper or shutter.
func _check_shops(hd: HdView, kid: Kid, stalls: Array[Prop]) -> void:
	var buildings := hd.get_tree().get_nodes_in_group("shop_building")
	_check(stalls.size() == 2 and buildings.size() == stalls.size(),
			"%d stalls but %d 3D shop buildings" % [stalls.size(), buildings.size()])
	var shops_node := hd.get_node("Shops")
	for b: ShopBuilding3D in buildings:
		_check(b.get_parent() == shops_node, "shop building outside the Shops holder")
		for part in ["BackWall", "SideWallL", "SideWallR", "RoofL", "RoofR", "FasciaL", "FasciaR", "RidgeCap", "PostL", "PostR", "Counter", "Sign", "Shutter"]:
			var mi := b.get_node_or_null(part) as MeshInstance3D
			_check(mi != null, "%s lacks a 3D %s" % [b.name, part])
			if mi == null:
				continue
			if part != "Sign":
				_check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "%s %s casts no shadow" % [b.name, part])
			_check(_is_texel_aa(mi.material_override), "%s %s must use the texel-AA shader with a texture" % [b.name, part])
		# Polish pass: goods on the counter, a crate and a barrel, a lantern.
		for part in ["Good0", "Good1", "Good2", "Good3", "Crate", "Barrel", "Sack"]:
			_check(b.find_child(part, true, false) is MeshInstance3D, "%s lacks %s" % [b.name, part])
		var lt := b.get_node_or_null("Lantern/Light") as OmniLight3D
		_check(lt != null and not lt.shadow_enabled and lt.omni_range <= 6.0, "%s: lantern light missing, casts shadows or is too wide" % b.name)
		_check(b.roof_height_share() < 0.3, "%s roof is %.2f of the height (should stay low)" % [b.name, b.roof_height_share()])
		_check(b.shop != null, "%s isn't tied to its Shop" % b.name)
		_check_no_coplanar(b)
	# Kid walking up from the street stops at the counter, in reach of both.
	for st in stalls:
		var shop: Shop = null
		for s: Shop in hd.get_tree().get_nodes_in_group("shop"):
			if s.global_position.distance_to(st.global_position - Shop.STALL_OFFSET) < 24.0:
				shop = s
		_check(shop != null, "no Shop at stall %s" % st.name)
		if shop == null:
			continue
		var building: ShopBuilding3D = null
		for b: ShopBuilding3D in buildings:
			if b.shop == shop:
				building = b
		_check(building != null, "no building for shop %s" % shop.shop_id)
		if building == null:
			continue
		for state in ["day", "night"]:
			Clock.hold(state, 0.0)
			await _frames(3)
			_check(building.get_node("Shutter").visible == not shop.is_open(),
					"%s at %s: shutter panel visible=%s but open=%s" % [shop.shop_id, state,
					building.get_node("Shutter").visible, shop.is_open()])
			_check((building.get_node("Goods") as Node3D).visible == shop.is_open(), "%s at %s: goods visible=%s but open=%s" % [shop.shop_id, state, building.get_node("Goods").visible, shop.is_open()])
			var lit := (building.get_node("Lantern/Light") as OmniLight3D).light_energy > 0.0
			_check(lit == (state == "night" and shop.is_open()), "%s at %s: lantern lit=%s, open=%s" % [shop.shop_id, state, lit, shop.is_open()])
			kid.global_position = st.global_position + Vector2(0, 90)
			kid.velocity = Vector2.ZERO
			kid.facing = Vector2.UP
			await _frames(5)
			Input.action_press("move_up")
			await _frames(70)
			Input.action_release("move_up")
			await _frames(5)
			var reach := kid.global_position.y - st.global_position.y
			_check(reach >= 50.0 and reach < 80.0, "%s: kid stopped %.0f px south of the stall base (the 3D counter should stop him at 50+)" % [shop.shop_id, reach])
			var target := Interaction.current_target()
			var want: Node2D = shop.keeper if shop.is_open() else shop.shutter
			_check(target == want, "%s at %s: talk target is %s, expected %s" % [shop.shop_id, state, target, want])
	Clock.hold("day", 0.0)


## Kid on the first and last walkable rows (inside the fence): his feet
## must be above the HUD and his head below the top of the screen.
func _check_edges(realm: AsciiRealm, kid: Kid, label: String) -> void:
	var r := realm.map_rect()
	var vis := get_viewport().get_visible_rect().size
	for row in [1, r.size.y / AsciiRealm.TILE - 2]:
		kid.global_position = Vector2(r.get_center().x, row * AsciiRealm.TILE + AsciiRealm.TILE - 4)
		kid.velocity = Vector2.ZERO
		await _wait(2.5)  # the camera eases over
		var feet := Fx.world_to_screen(kid.global_position)
		var head := Fx.world_to_screen(kid.global_position, 46.0)
		# Measured against the cards' real top edge, not HdView's own margin.
		var hud_top := vis.y - MemberCard.SIZE.y - 4.0
		_check(feet.y <= hud_top and head.y >= 0.0,
				"%s: the kid on row %d must be on screen above the HUD cards (feet at y=%.0f, cards from %.0f, head %.0f)"
				% [label, row, feet.y, hud_top, head.y])


func _tap(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait(seconds: float) -> void:
	await _frames(ceili(seconds * Engine.physics_ticks_per_second))


## A material that samples pixel art with the sharp-bilinear lookup and a
## LINEAR sampler (plain NEAREST shimmers when the camera moves by sub-pixels).
func _is_texel_aa(mat: Material) -> bool:
	var sm := mat as ShaderMaterial
	if sm == null or sm.shader == null or sm.get_shader_parameter("tex") == null:
		return false
	var code := sm.shader.code
	return code.contains("texel_aa_uv") and code.contains("filter_linear") and not code.contains("filter_nearest")


## Shops, props, fences, ground and the actors all use the texel-AA shaders,
## and MSAA follows the quality preset (off / off / 2x / 4x).
func _check_texel_aa(hd: HdView) -> void:
	for sh: Shader in [TexelMaterial.SHADER, HdView.SPRITE_SHADER]:
		_check(sh.code.contains("texel_aa_uv") and sh.code.contains("filter_linear") and not sh.code.contains("filter_nearest"),
				"%s must use texel_aa_uv with filter_linear" % sh.resource_path.get_file())
	_check(_is_texel_aa(hd.get_node("Ground").material_override), "the ground plane must use the texel-AA shader")
	var fenced := 0
	for m in hd.get_node("Fences").get_children():
		var mat := (m as MeshInstance3D).material_override
		if mat is ShaderMaterial:
			fenced += 1
			_check(_is_texel_aa(mat), "a fence part isn't texel-AA")
	_check(fenced > 0, "no fence part uses a texel-AA material")
	var props := 0
	for p in hd.get_node("Props").get_children():
		var mat := ((p as GeometryInstance3D).material_override) as ShaderMaterial
		if mat and mat.shader == HdView.SPRITE_SHADER:
			props += 1
			_check(_is_texel_aa(mat), "a prop isn't texel-AA")
	_check(props > 0, "no prop uses hd_sprite")
	for q in [["low", Viewport.MSAA_DISABLED], ["medium", Viewport.MSAA_DISABLED],
			["high", Viewport.MSAA_2X], ["ultra", Viewport.MSAA_4X]]:
		Settings.set_value("quality", q[0])
		await _frames(2)
		_check(hd.get_viewport().msaa_3d == q[1], "quality %s: msaa_3d is %d, expected %d" % [q[0], hd.get_viewport().msaa_3d, q[1]])
	Settings.set_value("quality", "ultra")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


## Z-fighting guard (owner: "shops still have tearing"): no two faces of a
## shop's boxes (and its sign) may face the same way, lie within 1 cm of each
## other and overlap. Flush trim and walls flickered while the camera moved.
## Faces are rebuilt from each mesh's transform, so rotated roof boards count.
func _no_coplanar_faces(b: ShopBuilding3D) -> PackedStringArray:
	var faces: Array = []   # [name, normal, center, u, v, hu, hv]
	for mi: MeshInstance3D in b.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D):
		var basis := mi.transform.basis.orthonormalized()
		if mi.mesh is BoxMesh:
			var size := (mi.mesh as BoxMesh).size * mi.scale
			for axis in 3:
				for sgn in [-1.0, 1.0]:
					var n: Vector3 = basis[axis] * sgn
					if n.y < -0.99 and absf(mi.position.y - size.y * 0.5) < 1e-4:
						continue  # bottoms standing on the ground are under it, never seen
					var u: Vector3 = basis[(axis + 1) % 3]
					var v: Vector3 = basis[(axis + 2) % 3]
					faces.append([mi.name, n, mi.position + n * size[axis] * 0.5, u, v,
							size[(axis + 1) % 3] * 0.5, size[(axis + 2) % 3] * 0.5])
		elif mi.mesh is PrismMesh:
			# Gable: the two triangular ends (apex up, centered on the box).
			var ps := (mi.mesh as PrismMesh).size
			for sgn in [-1.0, 1.0]:
				var n: Vector3 = basis[2] * sgn
				faces.append([mi.name, n, mi.position + n * ps.z * 0.5, basis[0], basis[1], ps.x * 0.5, ps.y * 0.5, true])
		elif mi.mesh is QuadMesh and mi.name == &"Sign":
			var q := (mi.mesh as QuadMesh).size
			faces.append([mi.name, basis[2], mi.position, basis[0], basis[1], q.x * 0.5, q.y * 0.5])
	var bad := PackedStringArray()
	for i in faces.size():
		for j in range(i + 1, faces.size()):
			var fa: Array = faces[i]
			var fb: Array = faces[j]
			if (fa[1] as Vector3).dot(fb[1]) < 0.9998:
				continue
			if absf((fa[1] as Vector3).dot((fb[2] as Vector3) - (fa[2] as Vector3))) >= 0.01:
				continue
			if _face_overlap(fa, fb) or _face_overlap(fb, fa):
				bad.append("%s/%s" % [fa[0], fb[0]])
	return bad


## Does any interior sample point of face `a` land inside face `b`?
func _face_overlap(a: Array, b: Array) -> bool:
	for i in 15:
		for j in 15:
			var p: Vector3 = (a[2] as Vector3) + (a[3] as Vector3) * (a[5] * (2.0 * (i + 0.5) / 15.0 - 1.0)) \
					+ (a[4] as Vector3) * (a[6] * (2.0 * (j + 0.5) / 15.0 - 1.0))
			var d: Vector3 = p - (b[2] as Vector3)
			var half_u: float = b[5]
			if b.size() > 7:  # a triangle: narrows to the apex
				half_u *= 1.0 - (d.dot(b[4]) + b[6]) / (2.0 * b[6])
			if absf(d.dot(b[3])) < half_u - 1e-4 and absf(d.dot(b[4])) < b[6] - 1e-4:
				return true
	return false


func _check_no_coplanar(b: ShopBuilding3D) -> void:
	var bad := _no_coplanar_faces(b)
	_check(bad.is_empty(), "%s: coplanar faces within 1 cm (z-fight): %s" % [b.name, ", ".join(bad)])
