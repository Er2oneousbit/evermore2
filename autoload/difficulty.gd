# =============================================================================
# difficulty.gd  (autoload: Difficulty)
# -----------------------------------------------------------------------------
# WHAT:  Every difficulty lever in ONE table. Normal and Hard playthroughs
#        (owner's call, 2026-10-07): on Hard, things cost more and enemies have
#        more HP and armor and hit harder. Gameplay code never checks "is this
#        Hard?"; it asks for a number:
#          health.max_hp = Difficulty.enemy_hp(data.hp)
#          price = Difficulty.price(base_price)
# WHY ONE TABLE: tuning is a one-file job, and adding a third difficulty later
#        is one more row.
#
# CHOOSING: GameState.difficulty ("normal" or "hard"). For testing, start with
#        godot --path . -- --difficulty hard
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Multipliers per difficulty. Draft numbers; tune by playtesting.
const TABLE := {
	"normal": {"enemy_hp": 1.0, "enemy_armor": 1.0, "enemy_damage": 1.0, "prices": 1.0},
	"hard": {"enemy_hp": 1.6, "enemy_armor": 1.5, "enemy_damage": 1.5, "prices": 1.5},
}
const DEFAULT := "normal"


func current() -> String:
	return GameState.difficulty if TABLE.has(GameState.difficulty) else DEFAULT


func lever(name: String) -> float:
	return TABLE[current()].get(name, 1.0)


func enemy_hp(base: float) -> int:
	return maxi(1, roundi(base * lever("enemy_hp")))


func enemy_armor(base: float) -> float:
	return base * lever("enemy_armor")


func enemy_damage(base: float) -> float:
	return base * lever("enemy_damage")


func price(base: int) -> int:
	return maxi(0, roundi(base * lever("prices")))
