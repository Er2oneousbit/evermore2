# =============================================================================
# item_data.gd  -  One kind of item (data/items/<id>.tres)
# -----------------------------------------------------------------------------
# WHAT:  What an item is: its name, a line about it, whether it's a plain item
#        or an alchemy ingredient (the dog's scent trails color them apart),
#        and its icon on the LPC item sheet (assets/items/lpc_items.png, a
#        16x16 grid of 32 px icons). The ring menu, shops and alchemy read
#        these later; for now hidden items hand them out.
#
#          var key := ItemData.find("old_key")
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ItemData
extends Resource

const ICONS := preload("res://assets/items/lpc_items.png")
## The icon sheet's grid (columns, rows).
const ICON_GRID := Vector2i(16, 16)

## Matches the file name: data/items/<id>.tres.
@export var id := ""
@export var display_name := ""
@export_multiline var description := ""
## "item" or "ingredient" (alchemy). Scent trails use a color per kind.
@export_enum("item", "ingredient") var kind := "item"
## Column and row of the icon on the item sheet.
@export var icon_cell := Vector2i.ZERO
## Using it (the Items ring, a quick slot): "" = can't be used (a key item,
## an ingredient), "heal" = restores use_power HP to the one it's used on.
@export var use_effect := ""
@export var use_power := 0


static var _cache := {}


## The item with this id, or null (logged once) if there's no such file.
## Cached: the ring menu and the quick bar ask every frame.
static func find(item_id: String) -> ItemData:
	if _cache.has(item_id):
		return _cache[item_id]
	var path := "res://data/items/%s.tres" % item_id
	var d := load(path) as ItemData if ResourceLoader.exists(path) else null
	if d == null:
		Debug.log_error("Missing item data/items/%s.tres" % item_id)
	_cache[item_id] = d
	return d
