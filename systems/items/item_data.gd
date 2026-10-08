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


## The item with this id, or null (logged) if there's no such file.
static func find(item_id: String) -> ItemData:
	var path := "res://data/items/%s.tres" % item_id
	var d := load(path) as ItemData if ResourceLoader.exists(path) else null
	if d == null:
		Debug.log_error("Missing item data/items/%s.tres" % item_id)
	return d
