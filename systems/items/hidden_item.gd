# =============================================================================
# hidden_item.gd  -  An item hidden in the world, waiting to be found
# -----------------------------------------------------------------------------
# WHAT:  Two kinds live here (the third, "secret", is just an ItemPickup lying
#        in a nook off the path, found by looking):
#          buried  only the dog finds it: his nose (Search stance, or the
#                  sniff button when you drive him) picks up the scent, then
#                  he digs it up. Until he's smelled it there's nothing to see.
#          tucked  under a bush or rock. A glint now and then is the tell; the
#                  kid searches it (interact). The dog on Search walks over
#                  and points at it, and then it glints more often.
#        Found, it pops out as an ItemPickup, and the party grabs it.
#
# PLACE: from an AsciiRealm's HIDDEN_ITEMS (the realm also counts them for the
#        "found 2/5 here" line), or HiddenItem.create() in code.
# INTERACTABLE: Interaction asks can_interact(who): buried is the dog's (once
#        sniffed), tucked is the kid's.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name HiddenItem
extends Node2D

## How often a tucked item glints (s), and once the dog has pointed at it.
const GLINT_EVERY := 3.2
const GLINT_EVERY_POINTED := 1.1
## How often a sniffed buried spot puffs scent (s).
const SCENT_EVERY := 0.9
const GLINT_COLOR := Color(1.0, 0.97, 0.8)
const SCENT_COLOR := Color(1.0, 0.82, 0.35)

@export var item: ItemData
@export var count := 1
## "buried" or "tucked".
@export_enum("buried", "tucked") var kind := "buried"
## Its found flag (GameState), unique per realm: "<realm>.hidden.<x>_<y>".
@export var key := ""

## The dog has smelled it: a buried spot can be dug and puffs scent.
var sniffed := false
## The dog (on Search) has pointed it out.
var pointed := false
## Interact reach (px): a tucked item sits under a solid bush, so it reaches
## farther than the dig spot of a buried one.
var interact_range: float:
	get:
		return 44.0 if kind == "tucked" else 22.0

var _tell := 0.0


static func create(item_data: ItemData, item_count: int, item_kind: String, found_key: String, at: Vector2) -> HiddenItem:
	var h := HiddenItem.new()
	h.item = item_data
	h.count = item_count
	h.kind = item_kind
	h.key = found_key
	h.position = at
	return h


func _ready() -> void:
	add_to_group("hidden_item")
	add_to_group("interactable")
	# A different phase per item, so a yard full of them doesn't glint in sync.
	_tell = fposmod(position.x * 0.013 + position.y * 0.007, GLINT_EVERY)


func _process(delta: float) -> void:
	_tell -= delta
	if _tell > 0.0:
		return
	if kind == "tucked":
		_tell = GLINT_EVERY_POINTED if pointed else GLINT_EVERY
		Fx.glint(global_position + Vector2(randf_range(-6, 6), 0), randf_range(4.0, 12.0), GLINT_COLOR)
	elif sniffed:
		_tell = SCENT_EVERY
		Fx.scent_puff(global_position, SCENT_COLOR)
	else:
		_tell = 0.5


## The scent color for the dog's trails.
func scent_kind() -> String:
	return item.kind if item else "item"


func can_interact(who: Node2D) -> bool:
	if kind == "tucked":
		return who is Kid
	return who is Dog and sniffed


func interact_label() -> String:
	return "Search" if kind == "tucked" else "Dig"


func interact() -> void:
	if kind == "tucked":
		var kid := get_tree().get_first_node_in_group("kid") as Node2D
		reveal(kid.global_position if kid else global_position + Vector2(0, 20))
	else:
		var dog := get_tree().get_first_node_in_group("dog") as Dog
		if dog:
			dog.dig(self)


## Pop the item out (toward `toward`, so it lands by whoever found it). Once.
func reveal(toward: Vector2) -> ItemPickup:
	if is_queued_for_deletion():
		return null
	remove_from_group("hidden_item")
	remove_from_group("interactable")
	var p := ItemPickup.create(item, count, key, global_position)
	get_parent().add_child(p)
	p.pop(toward)
	queue_free()
	return p
