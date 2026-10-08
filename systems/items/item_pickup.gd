# =============================================================================
# item_pickup.gd  -  An item lying on the ground; the party grabs it on touch
# -----------------------------------------------------------------------------
# WHAT:  Shows the item's icon (assets/items/lpc_items.png) at its spot.
#        Walk over it with whoever you're driving (Party.leader) to pick it
#        up. The AI partner never grabs it: the dog digging something up must
#        not snatch it before you've even seen it. It goes into
#        GameState.inventory, its found flag is set (so it never comes back)
#        and EventBus.item_found tells the HUD.
#        A hidden item that's found pops one out with a little hop (pop()); a
#        "secret" item is one lying in a nook from the start.
#
# HD-2D: in group "hd_actor" with a "Sprite" child, so HdView mirrors it (the
#        hop moves the sprite's offset, which HdView copies every frame; the
#        node itself stays on the ground, and so does its 3D shadow).
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name ItemPickup
extends Node2D

## Touch distance (px) from a party member's feet.
const GRAB_RADIUS := 16.0
## The hop out of the ground: height (px), time (s), and how far it travels.
const POP_HEIGHT := 26.0
const POP_SECONDS := 0.55
const POP_DISTANCE := 20.0
## Lying items glint now and then, so a sharp eye spots one in a nook.
const GLINT_EVERY := 2.6
## The icon's resting height: feet (bottom of the 32 px cell) at the origin,
## lifted a little so it sits on the grass instead of in it.
const REST_OFFSET := Vector2(0, -14)

@export var item: ItemData
@export var count := 1
## Its found flag (GameState).
@export var key := ""

var sprite: Sprite2D
## False while it's still in the air: it can't be grabbed mid-hop.
var grabbable := true

var _bob := 0.0
var _glint := 0.0


static func create(item_data: ItemData, item_count: int, found_key: String, at: Vector2) -> ItemPickup:
	var p := ItemPickup.new()
	p.item = item_data
	p.count = item_count
	p.key = found_key
	p.position = at
	return p


func _ready() -> void:
	add_to_group("item_pickup")
	add_to_group("hd_actor")
	sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = ItemData.ICONS
	sprite.hframes = ItemData.ICON_GRID.x
	sprite.vframes = ItemData.ICON_GRID.y
	sprite.frame_coords = item.icon_cell if item else Vector2i.ZERO
	sprite.offset = REST_OFFSET
	add_child(sprite)
	_bob = fposmod(position.x * 0.05, TAU)
	_glint = fposmod(position.y * 0.03, GLINT_EVERY)
	# Show up in the 3D view now, not at HdView's next scan (mid-hop).
	var hd := get_tree().get_first_node_in_group("hd_view") as HdView
	if hd:
		hd.mirror_new_actors()


## Hop out of the ground toward `toward` (whoever found it).
func pop(toward: Vector2) -> void:
	grabbable = false
	var dir := global_position.direction_to(toward) if toward.distance_to(global_position) > 1.0 else Vector2.DOWN
	var land := global_position + dir * minf(POP_DISTANCE, global_position.distance_to(toward) * 0.7)
	var t := create_tween().set_parallel()
	t.tween_property(self, "global_position", land, POP_SECONDS)
	t.tween_method(func(k: float) -> void:
		sprite.offset = REST_OFFSET + Vector2(0, -POP_HEIGHT * 4.0 * k * (1.0 - k)),
		0.0, 1.0, POP_SECONDS)
	t.chain().tween_callback(func() -> void: grabbable = true)


func _physics_process(delta: float) -> void:
	if not grabbable or Dialogue.is_active():
		return
	_bob += delta * 3.0
	sprite.offset = REST_OFFSET + Vector2(0, roundf(sin(_bob) * 1.2))
	_glint -= delta
	if _glint <= 0.0:
		_glint = GLINT_EVERY
		Fx.glint(global_position + Vector2(randf_range(-5, 5), 0), randf_range(10.0, 18.0), HiddenItem.GLINT_COLOR)
	var m := Party.leader
	if is_instance_valid(m) and not Party.is_down(m) and m.global_position.distance_to(global_position) <= GRAB_RADIUS:
		collect()


## Into the bag: inventory, found flag, sound, and the HUD's "found" line.
func collect() -> void:
	if is_queued_for_deletion():
		return
	grabbable = false
	if item:
		GameState.add_item(item.id, count)
	if not key.is_empty():
		GameState.set_flag(key, true)
	Audio.play_at("pickup", global_position)
	EventBus.item_found.emit(item, count, key)
	queue_free()


## The scent color for the dog's trails.
func scent_kind() -> String:
	return item.kind if item else "item"
