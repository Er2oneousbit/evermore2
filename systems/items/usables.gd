# =============================================================================
# usables.gd  -  Using items, casting formulas, and the quick slots
# -----------------------------------------------------------------------------
# WHAT:  The rules the ring menu and the quick slots share:
#          Usables.use_item("apple", kid)       eat an apple: heal, one fewer
#          Usables.cast("heal", dog)            the kid casts Heal on the dog
#          Usables.fire_slot(0, Party.leader)   whatever is in quick slot 1
#        Each returns "" when it worked, or why it didn't ("Not enough wild
#        carrot", "Already at full health"), which the menu and HUD show.
#
# ALCHEMY (owner, 2026-10-08): every cast uses up its ingredients and earns
#   the formula 1 experience; enough casts level it up and it gets stronger
#   (FormulaData.XP_TO_LEVEL, power_per_level). Only the kid casts, so a
#   knocked-out kid can't.
#
# QUICK SLOTS: GameState.quick_slots holds four entries, "item:<id>" or
#   "formula:<id>" ("" = empty). Keys 1-4 / the gamepad D-pad use them on
#   whoever you drive; in the ring menu the same keys assign them.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Usables
extends RefCounted

const SLOTS := 4


## Use an item on a party member. "" = done.
static func use_item(item_id: String, target: Node) -> String:
	var item := ItemData.find(item_id)
	if item == null or GameState.item_count(item_id) <= 0:
		return "None left"
	if item.use_effect.is_empty():
		return "Can't use that"
	var why := _apply(item.use_effect, item.use_power, target)
	if not why.is_empty():
		return why
	GameState.add_item(item_id, -1)
	EventBus.item_used.emit(item, target)
	return ""


## The kid casts a formula on a party member. "" = done.
static func cast(formula_id: String, target: Node) -> String:
	var f := FormulaData.find(formula_id)
	if f == null or not GameState.formulas.has(formula_id):
		return "Not learned"
	var kid := Party.kid
	if not is_instance_valid(kid) or Party.is_down(kid):
		return "%s can't cast right now" % GameState.get_kid_name()
	var missing := missing_ingredients(f)
	if not missing.is_empty():
		return missing
	var why := _apply(f.effect, f.power_at(level_of(formula_id)), target)
	if not why.is_empty():
		return why
	for id: String in f.costs:
		GameState.add_item(id, -int(f.costs[id]))
	var leveled := _gain_xp(formula_id)
	EventBus.formula_cast.emit(f, target, leveled)
	return ""


## "" if the ingredients are there, else what's short ("Not enough wild carrot").
static func missing_ingredients(f: FormulaData) -> String:
	for id: String in f.costs:
		if GameState.item_count(id) < int(f.costs[id]):
			var item := ItemData.find(id)
			return "Not enough %s" % (item.display_name.to_lower() if item else id)
	return ""


static func level_of(formula_id: String) -> int:
	return int(GameState.formulas.get(formula_id, {}).get("level", 1))


static func xp_of(formula_id: String) -> int:
	return int(GameState.formulas.get(formula_id, {}).get("xp", 0))


## Casts still needed for the next level (0 at the top).
static func xp_needed(formula_id: String) -> int:
	var lvl := level_of(formula_id)
	if lvl >= FormulaData.MAX_LEVEL:
		return 0
	return FormulaData.XP_TO_LEVEL[lvl] - xp_of(formula_id)


## Learn a formula (level 1).
static func learn(formula_id: String) -> void:
	if not GameState.formulas.has(formula_id):
		GameState.formulas[formula_id] = {"level": 1, "xp": 0}


# --- Quick slots -----------------------------------------------------------------
static func assign_slot(slot: int, entry: String) -> void:
	if slot < 0 or slot >= SLOTS:
		return
	# One entry lives in one slot: assigning it elsewhere moves it.
	for i in SLOTS:
		if GameState.quick_slots[i] == entry:
			GameState.quick_slots[i] = ""
	GameState.quick_slots[slot] = entry
	EventBus.quick_slots_changed.emit()


## Use quick slot `slot` on `target`. "" = done.
static func fire_slot(slot: int, target: Node) -> String:
	if slot < 0 or slot >= SLOTS:
		return "No such slot"
	var entry: String = GameState.quick_slots[slot]
	if entry.begins_with("item:"):
		return use_item(entry.substr(5), target)
	if entry.begins_with("formula:"):
		return cast(entry.substr(8), target)
	return "Slot %d is empty" % (slot + 1)


# -----------------------------------------------------------------------------
static func _apply(effect: String, power: int, target: Node) -> String:
	var h: Health = target.get_node_or_null("Health") if is_instance_valid(target) else null
	match effect:
		"heal":
			if h == null or h.is_dead():
				return "Can't heal someone who's knocked out"
			if h.hp >= h.max_hp:
				return "Already at full health"
			var before := h.hp
			h.heal(power)
			Fx.damage_number((target as Node2D).global_position + Vector2(0, -30), h.hp - before, "heal")
			Audio.play("pickup")
			return ""
	return "Nothing happens"


## One more cast: maybe a level. Returns true if it leveled up.
static func _gain_xp(formula_id: String) -> bool:
	var st: Dictionary = GameState.formulas[formula_id]
	if int(st["level"]) >= FormulaData.MAX_LEVEL:
		return false
	st["xp"] = int(st["xp"]) + 1
	if int(st["xp"]) >= FormulaData.XP_TO_LEVEL[int(st["level"])]:
		st["level"] = int(st["level"]) + 1
		st["xp"] = 0
		return true
	return false
