# =============================================================================
# equipment_data.gd  -  An item you can wear or wield (data/items/<id>.tres)
# -----------------------------------------------------------------------------
# WHAT:  An ItemData with a slot and what it does there:
#          weapon               `weapon` (a WeaponData: damage, reach, charge)
#          head body legs boots hands arms   (the kid)
#          collar                            (the dog)
#        `defense` adds to the wearer's armor (Health: 100 halves damage).
#        Owned pieces sit in GameState.inventory like any item; Equipment
#        (systems/items/equipment.gd) puts them on, the ring menu shows them.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name EquipmentData
extends ItemData

## "kid" or "dog".
@export_enum("kid", "dog") var wearer := "kid"
## One of Equipment.SLOTS[wearer].
@export var slot := "body"
## Armor it adds while worn.
@export var defense := 0.0
## The weapon slot only: what swinging it does.
@export var weapon: WeaponData
## One small perk, as text for now (resist cold, quieter paws...). Perks that
## do something come later.
@export var perk := ""
