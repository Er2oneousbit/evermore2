# =============================================================================
# shop.gd  -  A stall with a keeper who opens and closes with the clock
# -----------------------------------------------------------------------------
# WHAT:  One shop: a keeper (an Npc) who stands at the shop's spot while it's
#        open, and a closed shutter over the stall's counter while it isn't.
#        Talking to the keeper plays a greeting and hands over one item (once
#        per phase of the game clock: there's no money in the game yet).
#        Talking to the shutter says when it opens.
#
# OPEN RULE (per shop, `rule`): "follow_clock" (open in OPEN_PHASES, closed at
#        night), "always_open" (an all-night stand) or "always_closed". A scene
#        can override it any time with set_rule() (a story beat closing every
#        shop, say).
#
# PLACE: an AsciiRealm's SHOPS_BY_CHAR (the char's cell is where the keeper
#        stands; the stall itself is a prop one cell north, so the shutter
#        sits STALL_OFFSET from the keeper):
#          "1": {"id": "corner_store", "keeper": "GROCER", "rule": "follow_clock",
#                "item": "apple", "greet": "shop_corner", "again": "shop_corner_again",
#                "closed": "shop_corner_closed"}
#        Dialogue nodes come from the realm's DIALOGUE file.
# HD-2D: the keeper is an "hd_actor" mirrored as a sprite. The stall itself is
#        a real 3D building (systems/hd2d/shop_building.gd) whose shutter
#        panel follows `state_changed`; the 2D ShopShutter stays for talking
#        only (meta "hd_skip": no sprite quad in HD).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name Shop
extends Node2D

const RULES: Array[String] = ["follow_clock", "always_open", "always_closed"]
## When a "follow_clock" shop is open.
const OPEN_PHASES: Array[String] = ["morning", "day", "golden"]
const NPC_SCENE := preload("res://actors/npc/npc.tscn")
const SHUTTER_TEXTURE := preload("res://assets/props/shops/shop_closed.png")
## From the keeper's feet to the stall's base (the stall prop one cell north),
## nudged a pixel toward the camera so the shutter draws over the stall.
const STALL_OFFSET := Vector2(0, -31)

## Emitted whenever the shop shows open or closed again (the HD-2D building
## listens: shutter panel, night lamp).
signal state_changed

var shop_id := ""
var keeper_id := ""
var rule := "follow_clock"
var item := ""
var item_count := 1
var dialogue_file := ""
var greet_node := ""
var again_node := ""
var closed_node := ""

var keeper: Npc
var shutter: ShopShutter
## Clock.phase_count when the item was last handed over (-1 = never).
var _given_at := -1


## Build a shop from an AsciiRealm SHOPS_BY_CHAR spec, keeper standing at `at`.
static func create(spec: Dictionary, dialogue: String, at: Vector2) -> Shop:
	var s := Shop.new()
	s.shop_id = spec.get("id", "shop")
	s.keeper_id = spec.get("keeper", "")
	s.rule = spec.get("rule", "follow_clock")
	s.item = spec.get("item", "")
	s.item_count = spec.get("count", 1)
	s.dialogue_file = dialogue
	s.greet_node = spec.get("greet", "")
	s.again_node = spec.get("again", s.greet_node)
	s.closed_node = spec.get("closed", "")
	s.position = at
	return s


func _ready() -> void:
	name = "Shop_" + shop_id
	add_to_group("shop")
	if not RULES.has(rule):
		Debug.log_warn("Shop %s: unknown rule '%s', using follow_clock" % [shop_id, rule])
		rule = "follow_clock"
	keeper = NPC_SCENE.instantiate()
	keeper.character_id = keeper_id
	keeper.dialogue_file = dialogue_file
	keeper.start_node = greet_node
	add_child(keeper)
	shutter = ShopShutter.new()
	shutter.name = "Shutter"
	shutter.position = STALL_OFFSET
	shutter.shop = self
	add_child(shutter)
	Clock.phase_changed.connect(func(_p: String, _b: float) -> void: refresh())
	Dialogue.ended.connect(_on_dialogue_ended)
	refresh()


## Open right now? By the rule, and for "follow_clock" by the clock's phase.
func is_open() -> bool:
	match rule:
		"always_open":
			return true
		"always_closed":
			return false
	return OPEN_PHASES.has(Clock.phase)


## Change the open rule (a scene overriding the clock), and show it.
func set_rule(new_rule: String) -> void:
	if not RULES.has(new_rule):
		Debug.log_warn("Shop %s: unknown rule '%s'" % [shop_id, new_rule])
		return
	rule = new_rule
	refresh()


## Show open or closed: the keeper there or gone (not even solid), the
## shutter down or up. Picks the greeting for the next talk.
func refresh() -> void:
	var open := is_open()
	keeper.visible = open
	keeper.process_mode = Node.PROCESS_MODE_INHERIT if open else Node.PROCESS_MODE_DISABLED
	shutter.visible = not open
	keeper.start_node = greet_node if _given_at != Clock.phase_count else again_node
	state_changed.emit()


## Has the keeper handed over this phase's item already?
func gave_this_phase() -> bool:
	return _given_at == Clock.phase_count


func _on_dialogue_ended(node_name: String) -> void:
	if node_name != greet_node or not is_open() or gave_this_phase() or item.is_empty():
		return
	_given_at = Clock.phase_count
	GameState.add_item(item, item_count)
	var data := ItemData.find(item)
	EventBus.notice.emit("Got %s%s" % [data.display_name if data else item,
			" x%d" % item_count if item_count > 1 else ""])
	keeper.start_node = again_node
	Debug.log_verbose("Shop %s gave %s" % [shop_id, item])
