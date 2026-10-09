# =============================================================================
# combat.gd  -  Shared combat math (static helpers, no state)
# -----------------------------------------------------------------------------
# WHAT:  hits_in_arc(): which hurtboxes a swing reaches (a pie slice in front
#        of the attacker), and strike(): deliver one HitInfo to each of them
#        with the usual hit-stop, shake and damage numbers.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Combat
extends RefCounted


## Every hurtbox of the other team whose circle touches the slice:
## center `origin`, facing `dir`, `reach` px long, `arc_deg` wide.
static func hits_in_arc(tree: SceneTree, origin: Vector2, dir: Vector2, reach: float,
		arc_deg: float, attacker_team: String) -> Array[Hurtbox]:
	var out: Array[Hurtbox] = []
	var facing := dir.normalized() if dir != Vector2.ZERO else Vector2.DOWN
	var half := deg_to_rad(arc_deg) * 0.5
	for n in tree.get_nodes_in_group("hurtbox"):
		var hb := n as Hurtbox
		if hb == null or hb.team == attacker_team or not hb.is_inside_tree():
			continue
		if hb.health and hb.health.is_dead():
			continue
		var to := hb.global_position - origin
		var dist := to.length()
		if dist > reach + hb.radius:
			continue
		# Inside the slice, or close enough that the body overlaps the swing.
		if dist > hb.radius and absf(facing.angle_to(to)) > half:
			continue
		out.append(hb)
	return out


## Hit everything in the slice once. Returns the total damage dealt.
## `make_info` builds a fresh HitInfo for each target: func(hb: Hurtbox) -> HitInfo.
## It may return null: that target was missed (the kid at night, outside his
## flashlight beam), so it's skipped.
## `level` (the swing's charge level) scales the hit-stop and shake.
static func strike(tree: SceneTree, origin: Vector2, dir: Vector2, reach: float, arc_deg: float,
		attacker_team: String, make_info: Callable, level := 1) -> int:
	var total := 0
	for hb in hits_in_arc(tree, origin, dir, reach, arc_deg, attacker_team):
		var info: HitInfo = make_info.call(hb)
		if info == null:
			continue
		var dealt := hb.receive(info)
		if dealt > 0:
			total += dealt
			# Bigger swings land lower and add the stick's crack.
			Audio.play_at("hit", hb.global_position, 1.0 - 0.06 * (level - 1))
			if level >= 2 and hb.team == "enemy":
				Audio.play_at("thwack", hb.global_position, 1.0 - 0.05 * (level - 2))
			Fx.damage_number(hb.global_position + Vector2(0, -28), dealt,
					"enemy" if hb.team == "enemy" else "player", info.level)
	if total > 0:
		# Bigger swings stop time a little longer and shake a little more.
		Fx.hit_stop(0.045 + 0.02 * level)
		Fx.shake(1.5 + 1.0 * level, 0.12)
	return total
