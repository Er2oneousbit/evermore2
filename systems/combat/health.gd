# =============================================================================
# health.gd  -  Hit points, armor and invulnerability frames for anything
# -----------------------------------------------------------------------------
# WHAT:  A child node that owns HP. Damage goes through take_hit(HitInfo):
#          final = damage * 100 / (100 + armor), at least 1
#        then a short invulnerability window so one swing can't hit twice and
#        the player gets a breather after being hit.
# WHO:   the kid, the dog, every enemy. HUD bars read hp/max_hp and listen to
#        `changed`; actors listen to `damaged` (flinch, knockback) and `died`.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Health
extends Node

signal changed(hp: int, max_hp: int)
signal damaged(amount: int, info: HitInfo)
signal healed(amount: int)
signal died

@export var max_hp := 20
## Damage reduction: 100 armor halves incoming damage, 300 quarters it.
@export var armor := 0.0
## Seconds of invulnerability after taking a hit.
@export var invuln_seconds := 0.5

var hp := 0
var _invuln := 0.0


func _ready() -> void:
	hp = max_hp


func _process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta


func is_dead() -> bool:
	return hp <= 0


func is_invulnerable() -> bool:
	return _invuln > 0.0


## The damage a hit of `raw` would do after armor (no side effects).
func mitigated(raw: float) -> int:
	return maxi(1, roundi(raw * 100.0 / (100.0 + maxf(armor, 0.0))))


## Apply a hit. Returns the damage dealt (0 if it didn't land).
func take_hit(info: HitInfo) -> int:
	if is_dead() or is_invulnerable():
		return 0
	var amount := mitigated(info.damage)
	hp = maxi(0, hp - amount)
	_invuln = invuln_seconds
	damaged.emit(amount, info)
	changed.emit(hp, max_hp)
	if hp == 0:
		died.emit()
	return amount


func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp != before:
		healed.emit(hp - before)
		changed.emit(hp, max_hp)


## Back from being downed, with a fraction of max HP.
func revive(fraction := 0.3) -> void:
	hp = maxi(1, roundi(max_hp * fraction))
	_invuln = 1.0
	changed.emit(hp, max_hp)


## Set new maximum (difficulty, armor upgrades) and refill.
func reset(new_max: int) -> void:
	max_hp = maxi(1, new_max)
	hp = max_hp
	changed.emit(hp, max_hp)
