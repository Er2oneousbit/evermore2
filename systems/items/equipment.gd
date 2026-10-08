# =============================================================================
# equipment.gd  -  Who wears what (the rules; GameState holds the state)
# -----------------------------------------------------------------------------
# WHAT:  The slots each of the duo has, what he could put in each (owned
#        EquipmentData for that slot and wearer), putting things on and off,
#        and what it adds up to (armor, the weapon). Changing anything emits
#        EventBus.equipment_changed(who); the Kid and Dog re-apply on it.
#
#          Equipment.options("kid", "head")       [null, <Bike helmet>]
#          Equipment.equip("kid", "head", helmet) true
#          Equipment.defense("kid")               8.0
#
# RULES: the weapon slot can't be empty (no bare-handed kid). A piece must be
#   owned, fit the slot and fit the wearer.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Equipment
extends RefCounted

## Slots in ring order (the ring menu shows them clockwise from the top).
const SLOTS := {
	"kid": ["weapon", "head", "body", "arms", "hands", "legs", "boots"],
	"dog": ["collar"],
}
const SLOT_NAMES := {"weapon": "Weapon", "head": "Head", "body": "Body", "arms": "Arms",
		"hands": "Hands", "legs": "Legs", "boots": "Boots", "collar": "Collar"}
## Slots that always hold something.
const REQUIRED := ["weapon"]


## "kid" or "dog" for a party member.
static func who_of(member: Node) -> String:
	return "dog" if member is Dog else "kid"


## What's in a slot (null = nothing).
static func equipped(who: String, slot: String) -> EquipmentData:
	var id: String = GameState.equipped.get(who, {}).get(slot, "")
	if id.is_empty():
		return null
	return ItemData.find(id) as EquipmentData


## Everything that could go in a slot, in a stable order: null (nothing) first
## unless the slot is required, then owned pieces by name.
static func options(who: String, slot: String) -> Array:
	var out := [] if REQUIRED.has(slot) else [null]
	var pieces := []
	for id: String in GameState.inventory:
		if GameState.item_count(id) <= 0:
			continue
		var e := ItemData.find(id) as EquipmentData
		if e and e.wearer == who and e.slot == slot:
			pieces.append(e)
	pieces.sort_custom(func(a: EquipmentData, b: EquipmentData) -> bool: return a.display_name < b.display_name)
	out.append_array(pieces)
	return out


## Put a piece on (null takes the slot's piece off). False if it isn't allowed.
static func equip(who: String, slot: String, piece: EquipmentData) -> bool:
	if not SLOTS.has(who) or not SLOTS[who].has(slot):
		return false
	if piece == null:
		if REQUIRED.has(slot):
			return false
	elif piece.wearer != who or piece.slot != slot or GameState.item_count(piece.id) <= 0:
		return false
	if not GameState.equipped.has(who):
		GameState.equipped[who] = {}
	var id := piece.id if piece else ""
	if GameState.equipped[who].get(slot, "") == id:
		return true
	GameState.equipped[who][slot] = id
	EventBus.equipment_changed.emit(who)
	return true


## Armor from everything he wears.
static func defense(who: String) -> float:
	var total := 0.0
	for slot: String in SLOTS.get(who, []):
		var e := equipped(who, slot)
		if e:
			total += e.defense
	return total


## The equipped weapon's WeaponData (null if none: the dog bites with his own).
static func weapon(who: String) -> WeaponData:
	var e := equipped(who, "weapon")
	return e.weapon if e else null
