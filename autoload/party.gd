# =============================================================================
# party.gd  (autoload: Party)
# -----------------------------------------------------------------------------
# WHAT:  The kid and the dog as a team:
#          * who you drive (the LEADER) and who the AI plays (the PARTNER).
#            switch_control (Tab / gamepad Back) swaps them; the camera glides
#            over. If the leader is knocked out, control jumps to the partner.
#          * Stay put (Q / gamepad X): the partner holds his spot until called
#            back (press again). It stays on through a switch, so the one you
#            just left stands still: that's how split puzzles work (leave the
#            dog on a plate, switch, walk the kid on).
#          * stances (R / gamepad RB cycles the partner's): the kid Offensive /
#            Defensive, the dog Offensive / Search (PartnerBrain reads them).
#          * knockouts: one member down gets back up after REVIVE_SECONDS with a
#            fraction of his HP; both down restarts the scene.
#        Conversations always belong to the kid: when one starts, control goes
#        back to him.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Emitted when everyone is down (the scene restarts shortly after).
signal wiped

const REVIVE_SECONDS := 8.0
const REVIVE_FRACTION := 0.3
const WIPE_RESTART_SECONDS := 2.5
## Seconds for the 2D camera to glide to the new leader after a switch.
const CAMERA_GLIDE := 0.35
## The stances each one can take, in cycling order.
const STANCES := {
	"kid": ["offensive", "defensive"],
	"dog": ["offensive", "search"],
}

var kid: Node2D
var dog: Node2D
## The one the player drives.
var leader: Node2D
## Stay put is on for the partner.
var staying := false


func _ready() -> void:
	EventBus.dialogue_started.connect(func(_n: String) -> void:
		if is_instance_valid(kid) and leader != kid and not is_down(kid):
			_set_leader(kid))


func register(member: Node2D) -> void:
	if member.is_in_group("kid"):
		kid = member
		# A fresh scene starts with the kid in charge and nobody staying.
		leader = kid
		staying = false
	elif member.is_in_group("dog"):
		dog = member
	var h: Health = member.get_node_or_null("Health")
	if h:
		h.died.connect(_on_member_died.bind(member))
	_apply_roles()


func members() -> Array[Node2D]:
	var out: Array[Node2D] = []
	for m in [kid, dog]:
		if is_instance_valid(m):
			out.append(m)
	return out


## The one the AI plays (null if he's alone).
func partner() -> Node2D:
	for m in members():
		if m != leader:
			return m
	return null


func is_down(member: Node2D) -> bool:
	return is_instance_valid(member) and member.get("downed") == true


# -----------------------------------------------------------------------------
# Switching control
# -----------------------------------------------------------------------------
## Drive the other one. False if there's nobody to switch to (alone, knocked
## out, or a conversation is running).
func switch_control() -> bool:
	var p := partner()
	if p == null or is_down(p) or Dialogue.is_active():
		return false
	_set_leader(p)
	return true


func _set_leader(member: Node2D) -> void:
	if member == leader:
		return
	var old := leader
	leader = member
	_apply_roles()
	_move_camera(old, member)
	Audio.play("switch")
	EventBus.control_changed.emit(member)
	Debug.log_verbose("Party: now driving %s" % member.name)


## Tell each member whether he's driven, and who the partner follows.
func _apply_roles() -> void:
	if not is_instance_valid(leader):
		leader = kid if is_instance_valid(kid) else dog
	for m in members():
		var is_leader := m == leader
		m.controlled = is_leader
		var r: Running = m.get("run")
		if r:
			r.drop_toggle()
		var f: Follower = m.get("follower")
		if f == null:
			continue
		f.target = null if is_leader else leader
		f.clear_trail()
		f.set_state(Follower.State.STAY if staying and not is_leader else Follower.State.IDLE)


## The 2D camera rides on the leader; move it over and let it glide.
func _move_camera(from: Node2D, to: Node2D) -> void:
	var cam: Camera2D = null
	for m in [from, to]:
		if is_instance_valid(m) and m.get_node_or_null("Camera2D") is Camera2D:
			cam = m.get_node("Camera2D")
	if cam == null or cam.get_parent() == to:
		return
	cam.reparent(to)  # keeps its screen position: now an offset from the new leader
	var t := cam.create_tween()
	t.tween_property(cam, "position", Vector2.ZERO, CAMERA_GLIDE) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# -----------------------------------------------------------------------------
# Stay put
# -----------------------------------------------------------------------------
func set_staying(on: bool) -> void:
	staying = on
	var p := partner()
	if p and p.get("follower"):
		var f: Follower = p.follower
		if on:
			f.set_state(Follower.State.STAY)
			f.clear_trail()
		else:
			f.set_state(Follower.State.FOLLOW)  # called back: come find the leader
	_stay_sound(p, on)
	EventBus.partner_stay_changed.emit(on)
	Debug.log_verbose("Party: stay put %s" % ("on" if on else "off"))


## The dog answers with a bark; calling him back, the kid whistles first.
## (The kid has no voice yet: a menu tick confirms it.)
func _stay_sound(p: Node2D, on: bool) -> void:
	if p == null:
		return
	if p != dog:
		Audio.play("ui_confirm")
		return
	if not on and is_instance_valid(kid):
		Audio.play_at("whistle", kid.global_position)
		await get_tree().create_timer(0.45, false).timeout
	if is_instance_valid(p) and p.has_method("bark"):
		p.bark()


## True if `member` is the partner and told to Stay put.
func is_staying(member: Node2D) -> bool:
	return staying and member == partner()


# -----------------------------------------------------------------------------
# Stances
# -----------------------------------------------------------------------------
func stance_of(member: Node2D) -> String:
	if member == dog:
		return GameState.dog_stance
	return GameState.kid_stance


func set_stance(member: Node2D, stance: String) -> void:
	var key := "dog" if member == dog else "kid"
	if not STANCES[key].has(stance):
		Debug.log_warn("Party: %s can't take the '%s' stance" % [key, stance])
		return
	if key == "dog":
		GameState.dog_stance = stance
	else:
		GameState.kid_stance = stance
	Audio.play("ui_move")
	EventBus.stance_changed.emit(member, stance)


## Next stance in the list for `member` (wraps around).
func cycle_stance(member: Node2D) -> void:
	var key := "dog" if member == dog else "kid"
	var list: Array = STANCES[key]
	set_stance(member, list[(list.find(stance_of(member)) + 1) % list.size()])


# -----------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if Dialogue.is_active() or members().is_empty():
		return
	if event.is_action_pressed("switch_control"):
		switch_control()
	elif event.is_action_pressed("partner_stay"):
		if partner():
			set_staying(not staying)
	elif event.is_action_pressed("partner_stance"):
		if partner():
			cycle_stance(partner())
	else:
		return
	get_viewport().set_input_as_handled()


func _on_member_died(member: Node2D) -> void:
	if _all_down():
		_wipe()
		return
	# The one you were driving went down: carry on with the other.
	if member == leader:
		_set_leader(partner())
	await get_tree().create_timer(REVIVE_SECONDS, false).timeout
	if is_instance_valid(member) and is_down(member) and not _all_down():
		member.revive(REVIVE_FRACTION)


func _all_down() -> bool:
	for m in members():
		if not is_down(m):
			return false
	return true


func _wipe() -> void:
	wiped.emit()
	Debug.log_info("Party knocked out; restarting the scene")
	await get_tree().create_timer(WIPE_RESTART_SECONDS, false).timeout
	if _all_down():
		get_tree().reload_current_scene()
