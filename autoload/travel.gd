# =============================================================================
# travel.gd  (autoload: Travel)
# -----------------------------------------------------------------------------
# WHAT:  Walking from one map to another. A realm's exits (EXITS, built into a
#        MapExits node by AsciiRealm) call Travel.go(scene, entry) when the
#        one you drive walks into them. Then:
#          1. input freezes (every event is swallowed, the duo stands still)
#          2. fade to black (FADE_SECONDS of game time)
#          3. the scene changes; the new realm calls Travel.realm_ready(self)
#             from its _ready, which puts the kid and the dog on the entry
#             (ENTRIES), facing into the map, and hands back what they carried:
#             HP, the attack charge, who you drive, Stay put
#          4. both cameras snap to the leader (no slide across the map)
#          5. fade in, input back
#        Inventory, gear, stances, flags and the clock live in autoloads
#        already (GameState, Clock), so they come along by themselves. Each
#        map's own setup (CLOCK_MODE, MUSIC, AMBIENCE) takes over on arrival;
#        music crossfades from the old map's track.
#
# WHY AN AUTOLOAD: the swap outlives the scene that started it. The fade has
#        to stay on screen while the old scene is freed and the new one built,
#        and the snapshot of HP and charge has to be somewhere when the new
#        kid's _ready runs. A node inside either scene would be freed mid-swap.
#
# USAGE: Travel.go("res://realms/big_yard/yard_hd.tscn", "from_street")
#        Travel.busy        true from the first frame of the fade-out to the
#                           last frame of the fade-in (kid/dog stand still)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## The new map is in place and the party stands on the entry (tests, HUD).
signal arrived(entry: String)
## The fade-in finished: you're in control again.
signal finished

## Seconds of each half of the fade (game time).
const FADE_SECONDS := 0.5
## Above the HUD (10), a scene's own overlay (15) and the text box (20); under
## the pause menu (50).
const LAYER := 40
## A member who was knocked out when he left gets up with this much HP.
const REVIVE_FRACTION := 0.3

## A swap is running: input is swallowed and the duo stands still.
var busy := false
## The entry the next realm should put the party on ("" = its K/D spawns).
var pending_entry := ""
## Entry of the last arrival (tests, debug overlay).
var last_entry := ""
## What the party carried on the last swap (snapshot() as they left).
var last_carry: Dictionary = {}

var _carry: Dictionary = {}
var _overlay: CanvasLayer
var _black: ColorRect


func _ready() -> void:
	# Swallowing input must work even if something paused the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = CanvasLayer.new()
	_overlay.name = "TravelFade"
	_overlay.layer = LAYER
	add_child(_overlay)
	_black = ColorRect.new()
	_black.color = Color(0.02, 0.02, 0.04)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.modulate.a = 0.0
	_black.visible = false
	_overlay.add_child(_black)


## Mid-swap, nothing reaches the game: no pause menu over a half-built scene,
## no ring menu, no swing or switch while the screen is black.
func _input(event: InputEvent) -> void:
	if busy:
		get_viewport().set_input_as_handled()


## Leave for `scene_path`, arriving on its entry `entry`. False if a swap is
## already running or the scene doesn't exist.
func go(scene_path: String, entry := "") -> bool:
	if busy:
		return false
	if not ResourceLoader.exists(scene_path):
		Debug.log_error("Travel: no scene %s" % scene_path)
		return false
	busy = true
	_carry = snapshot()
	last_carry = _carry.duplicate()
	pending_entry = entry
	Debug.log_info("Travel: leaving for %s (entry '%s')" % [scene_path.get_file(), entry])
	await _fade(1.0)
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		Debug.log_error("Travel: couldn't load %s (error %d)" % [scene_path, err])
		pending_entry = ""
		_carry = {}
		await _fade(0.0)
		busy = false
		return false
	await get_tree().scene_changed
	# Two frames: HdView's _process mirrors the sprites at their new spots,
	# then the snap lands on the leader's real position.
	await get_tree().process_frame
	await get_tree().process_frame
	_snap_cameras()
	await _fade(0.0)
	busy = false
	finished.emit()
	return true


## What the duo carries from map to map. Also what tests compare.
func snapshot() -> Dictionary:
	var out := {}
	for key in ["kid", "dog"]:
		var m: Node2D = Party.get(key)
		if not is_instance_valid(m):
			continue
		var h: Health = m.get_node_or_null("Health")
		if h:
			out[key + "_hp"] = h.hp
		var c: ChargeMeter = m.get("charge")
		if c:
			out[key + "_charge"] = c.value
	out["leader"] = "dog" if is_instance_valid(Party.dog) and Party.leader == Party.dog else "kid"
	out["staying"] = Party.staying
	return out


## Called by every AsciiRealm at the end of its _ready. After a Travel.go it
## places the party on the entry and gives back what they carried; on a plain
## load (F5, --yard, a restart after a wipe) it does nothing.
func realm_ready(realm: AsciiRealm) -> void:
	if pending_entry.is_empty() and _carry.is_empty():
		return
	var entry_id := pending_entry
	pending_entry = ""
	var spot := realm.entry_spot(entry_id, _carry.get("leader", "kid") == "dog")
	if spot.is_empty():
		Debug.log_warn("Travel: %s has no entry '%s'; using its spawn" % [realm.name, entry_id])
	else:
		for key in ["kid", "dog"]:
			var m: Node2D = Party.get(key)
			if is_instance_valid(m):
				m.global_position = spot[key]
				m.set("facing", spot["facing"])
				if m is CharacterBody2D:
					(m as CharacterBody2D).velocity = Vector2.ZERO
	_restore(_carry)
	_carry = {}
	last_entry = entry_id
	arrived.emit(entry_id)


func _restore(c: Dictionary) -> void:
	for key in ["kid", "dog"]:
		var m: Node2D = Party.get(key)
		if not is_instance_valid(m):
			continue
		var h: Health = m.get_node_or_null("Health")
		if h and c.has(key + "_hp"):
			var hp: int = c[key + "_hp"]
			# Knocked out on the way out: he gets up on the way in.
			h.set_hp(hp if hp > 0 else maxi(1, roundi(h.max_hp * REVIVE_FRACTION)))
		var meter: ChargeMeter = m.get("charge")
		if meter and c.has(key + "_charge"):
			meter.value = clampf(c[key + "_charge"], 0.0, float(meter.max_level))
	var lead: Node2D = Party.dog if c.get("leader", "kid") == "dog" else Party.kid
	Party.place(lead, c.get("staying", false))


## The 2D camera rides on the leader; the HD camera follows his 3D sprite.
## Both jump straight to him.
func _snap_cameras() -> void:
	var lead := Party.leader
	if is_instance_valid(lead):
		var cam := lead.get_node_or_null("Camera2D") as Camera2D
		if cam:
			cam.reset_smoothing()
	var hd := get_tree().get_first_node_in_group("hd_view")
	if hd and hd.has_method("snap_camera"):
		hd.snap_camera()


func _fade(to_alpha: float) -> void:
	_black.visible = true
	var t := create_tween()
	t.tween_property(_black, "modulate:a", to_alpha, FADE_SECONDS)
	await t.finished
	_black.visible = to_alpha > 0.0


## How dark the fade is now (0 clear, 1 black). Tests read it.
func fade_alpha() -> float:
	return _black.modulate.a if _black.visible else 0.0
