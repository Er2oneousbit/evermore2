# =============================================================================
# formula_data.gd  -  One alchemy formula (data/formulas/<id>.tres)
# -----------------------------------------------------------------------------
# WHAT:  What a formula costs and does, and how it grows. Like the original,
#        every cast uses up ingredients, and a formula gets stronger the more
#        it's used (owner, 2026-10-08): each cast is worth 1 experience, and
#        XP_TO_LEVEL[level] casts take it to the next level.
#        The kid casts; Alchemy (systems/items/alchemy.gd) does the casting.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name FormulaData
extends Resource

## Casts needed to leave each level (index = level; level 1 needs 3 casts).
const XP_TO_LEVEL := [0, 3, 5, 8, 12, 16, 20, 25, 30]
const MAX_LEVEL := 9

## Matches the file name: data/formulas/<id>.tres.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
## Ingredients used up by one cast: item id -> count.
@export var costs: Dictionary = {}
## What it does: "heal" (restores HP to the target).
@export_enum("heal") var effect := "heal"
## Strength at level 1, and what each level adds.
@export var power := 12
@export var power_per_level := 4
## Icon on the item sheet (assets/items/lpc_items.png).
@export var icon_cell := Vector2i.ZERO


## Strength at a level.
func power_at(level: int) -> int:
	return power + power_per_level * (clampi(level, 1, MAX_LEVEL) - 1)


static var _cache := {}


## The formula with this id, or null (logged once). Cached.
static func find(formula_id: String) -> FormulaData:
	if _cache.has(formula_id):
		return _cache[formula_id]
	var path := "res://data/formulas/%s.tres" % formula_id
	var f := load(path) as FormulaData if ResourceLoader.exists(path) else null
	if f == null:
		Debug.log_error("Missing formula data/formulas/%s.tres" % formula_id)
	_cache[formula_id] = f
	return f
