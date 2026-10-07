# =============================================================================
# dialogue_trigger.gd  -  Walk onto it and a conversation starts
# -----------------------------------------------------------------------------
# WHAT:  An invisible box (Area2D) that starts a .dlg node when the kid walks
#        in: the gate that makes you stop and think, a sign, a cutscene start.
#        once = true fires a single time per playthrough (remembered as the
#        story flag "trigger.<start_node>", so saves keep it).
# PLACE:  from an AsciiRealm's TRIGGERS_BY_CHAR, or add one in a scene.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name DialogueTrigger
extends Area2D

@export_file("*.dlg") var dialogue_file := ""
@export var start_node := ""
@export var once := true
## Size of the box (px), centered on the node.
@export var size := Vector2(32, 32)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # the kid's layer
	monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = size
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(_on_body_entered)


func flag_name() -> String:
	return "trigger." + start_node


func _on_body_entered(body: Node) -> void:
	if not body is Kid or Dialogue.is_active():
		return
	if once and GameState.get_flag(flag_name()):
		return
	if Dialogue.start(dialogue_file, start_node, self) and once:
		GameState.set_flag(flag_name())
