# =============================================================================
# dog_idle.gd  -  What the dog does when there is nothing to do
# -----------------------------------------------------------------------------
# WHAT:  The original game's dog sits when you stop, and now and then gets up,
#        sniffs the ground, wanders a few steps and sits again (even when
#        there is nothing to find). This is that, purely cosmetic:
#          STAND  waiting; after SIT_AFTER seconds of standing still while the
#                 kid is still too, he sits
#          SIT    holds the sit animation. Every 6-15 s (seeded RNG) he may get
#                 up for an ambient sniff
#          SNIFF  nose down on the spot for a moment
#          WALK   a slow stroll 1-3 tiles away (collision-checked, inside a
#                 leash around the kid), then another sniff, then back to
#                 STAND, where the normal Follower walks him back to the kid
#        Stay put: he sits and sniffs in place but never wanders off.
#        Driven by the player: he sits after DRIVEN_SIT_AFTER seconds of no input.
# WHY:   It must never fight the real behaviour. The Dog calls interrupt()
#        whenever a fight, a hidden item (Nose), a dialogue, a hit, a bite or a
#        dig is going on, so the real thing always wins; this class only ever
#        replaces the velocity while he is truly idle.
# HOW:   Dog owns one DogIdle (idle). Tests set `rng.seed` and the timing vars.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DogIdle
extends RefCounted

enum Mode { STAND, SIT, SNIFF, WALK }

## Standing still this long (s) before he sits.
const SIT_AFTER := 2.5
## Seconds between ambient sniffs while sitting (random in this range).
const SNIFF_GAP := Vector2(6.0, 15.0)
## How long a sniff lasts (s).
const SNIFF_TIME := Vector2(1.1, 1.8)
## How far one stroll goes (px; 32 px = 1 tile).
const WANDER_PX := Vector2(32.0, 96.0)
## He never strolls to a point farther than this from the kid.
const MAX_FROM_LEADER := 120.0
## A stroll is slow: this fraction of his walk speed.
const STROLL_SPEED := 0.5
## Driven by the player: sits after this long without input (s).
const DRIVEN_SIT_AFTER := 4.0

var mode := Mode.STAND
var sit_after := SIT_AFTER
var sniff_gap := SNIFF_GAP
var driven_sit_after := DRIVEN_SIT_AFTER
var rng := RandomNumberGenerator.new()
## Ambient sniffs started and strolls finished (tests read these).
var sniffs := 0
var strolls := 0

var _dog: CharacterBody2D
var _still := 0.0
var _gap := 0.0
var _t := 0.0
var _legs_left := 0
var _dest := Vector2.ZERO
var _driven := 0.0


func _init(member: CharacterBody2D) -> void:
	_dog = member
	rng.randomize()


func sitting() -> bool:
	return mode == Mode.SIT


func sniffing() -> bool:
	return mode == Mode.SNIFF


## True during an ambient sniff or stroll.
func ambient() -> bool:
	return mode == Mode.SNIFF or mode == Mode.WALK


## Something real happened: stand up, start the wait again.
func interrupt() -> void:
	mode = Mode.STAND
	_still = 0.0
	_driven = 0.0


## The AI partner's velocity for this frame. `want` is what the Follower wants;
## it comes back unchanged unless he is sitting or doing an ambient sniff.
func think(delta: float, want: Vector2, can_wander: bool) -> Vector2:
	var leader := _dog.follower.target as Node2D
	var leader_moving := false
	if is_instance_valid(leader):
		var v: Variant = leader.get("velocity")
		leader_moving = v is Vector2 and (v as Vector2).length() > 10.0
	match mode:
		Mode.STAND:
			if want.length() < 1.0 and _dog.velocity.length() < 8.0 and not leader_moving:
				_still += delta
				if _still >= sit_after:
					mode = Mode.SIT
					_gap = rng.randf_range(sniff_gap.x, sniff_gap.y)
			else:
				_still = 0.0
			return want
		Mode.SIT:
			if want.length() >= 1.0 or leader_moving:
				interrupt()
				return want
			_gap -= delta
			if _gap <= 0.0:
				_legs_left = 1 if can_wander else 0
				_start_sniff()
			return Vector2.ZERO
		Mode.SNIFF:
			if leader_moving:
				interrupt()
				return want
			_t -= delta
			if _t <= 0.0:
				if _legs_left > 0 and _pick_destination(leader):
					_legs_left -= 1
					mode = Mode.WALK
					_t = (_dest - _dog.global_position).length() / (_dog.walk_speed * STROLL_SPEED) * 1.6 + 0.5
				else:
					_finish()
					return want
			return Vector2.ZERO
		Mode.WALK:
			var to := _dest - _dog.global_position
			_t -= delta
			if leader_moving:
				interrupt()
				return want
			if to.length() < 4.0 or _t <= 0.0:
				strolls += 1
				_start_sniff()
				return Vector2.ZERO
			return to.normalized() * _dog.walk_speed * STROLL_SPEED
	return want


## Player-driven dog: `still` = no movement input and nothing else going on.
func think_driven(delta: float, still: bool) -> void:
	if ambient():
		interrupt()
	if not still:
		_driven = 0.0
		if mode == Mode.SIT:
			mode = Mode.STAND
		return
	_driven += delta
	if _driven >= driven_sit_after:
		mode = Mode.SIT


func _start_sniff() -> void:
	mode = Mode.SNIFF
	sniffs += 1
	_t = rng.randf_range(SNIFF_TIME.x, SNIFF_TIME.y)


func _finish() -> void:
	mode = Mode.STAND
	_still = 0.0


## A free spot 1-3 tiles away: the straight path is clear and it is still
## close to the kid. False if none turned up (he just sniffs and goes back).
func _pick_destination(leader: Node2D) -> bool:
	for i in 6:
		var dir := Vector2.from_angle(rng.randf() * TAU)
		var dist := rng.randf_range(WANDER_PX.x, WANDER_PX.y)
		var p := _dog.global_position + dir * dist
		if is_instance_valid(leader) and p.distance_to(leader.global_position) > MAX_FROM_LEADER:
			continue
		if _dog.test_move(_dog.global_transform, dir * dist):
			continue
		_dest = p
		return true
	return false
