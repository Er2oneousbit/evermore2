# =============================================================================
# hud.gd  -  Placeholder HUD (names + HP), lives inside a SafeFrame
# -----------------------------------------------------------------------------
# WHAT:  Bottom-left: the kid. Bottom-right: the dog. Text only for now; real
#        HP bars, charge meter, and the ring menu come in later prototypes.
# WHY NOW: proves the ultrawide layout rule early. Everything here anchors to
#        the SafeFrame, so on 32:9 it sits in the middle 16:9 area.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends CanvasLayer

@onready var _kid_status: Label = $SafeFrame/KidStatus
@onready var _dog_status: Label = $SafeFrame/DogStatus

## "[E] Talk to Maya": shown while something is in reach (see Interaction).
var _prompt: Label
var _charge_bar: ChargeBar
var _kid: Node2D
var _dog: Node2D


func _ready() -> void:
	_kid = get_tree().get_first_node_in_group("kid")
	_dog = get_tree().get_first_node_in_group("dog")
	_watch_health(_kid, _kid_status, GameState.get_kid_name())
	_watch_health(_dog, _dog_status, GameState.get_dog_name())
	_build_charge_bar()
	_build_prompt()
	EventBus.interaction_target_changed.connect(_on_target_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


## Keep a status label in step with a party member's Health.
func _watch_health(member: Node2D, label: Label, who: String) -> void:
	var h: Health = member.get_node_or_null("Health") if member else null
	if h == null:
		label.text = who
		return
	var update := func(hp: int, max_hp: int) -> void:
		label.text = "%s  HP %d/%d%s" % [who, hp, max_hp, "  KO" if hp <= 0 else ""]
	update.call(h.max_hp if h.hp == 0 and not h.is_dead() else h.hp, h.max_hp)
	h.changed.connect(update)


func _build_charge_bar() -> void:
	_charge_bar = ChargeBar.new()
	_charge_bar.name = "ChargeBar"
	_charge_bar.anchor_top = 1.0
	_charge_bar.anchor_bottom = 1.0
	_charge_bar.offset_left = 5
	_charge_bar.offset_right = 75
	_charge_bar.offset_top = -21
	_charge_bar.offset_bottom = -16
	$SafeFrame.add_child(_charge_bar)


func _process(_delta: float) -> void:
	if _charge_bar and is_instance_valid(_kid) and _kid.get("charge") != null:
		_charge_bar.meter = _kid.charge
		_charge_bar.visible = _kid_status.visible


func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "InteractPrompt"
	_prompt.label_settings = _kid_status.label_settings
	_prompt.add_theme_stylebox_override("normal", _kid_status.get_theme_stylebox("normal"))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.offset_top = -34
	_prompt.offset_bottom = -22
	_prompt.visible = false
	$SafeFrame.add_child(_prompt)


## The text box covers the bottom of the screen: tuck the HUD away meanwhile.
func _on_dialogue_started(_node: String) -> void:
	_prompt.visible = false
	_kid_status.visible = false
	_dog_status.visible = false
	_charge_bar.visible = false


func _on_dialogue_ended(_node: String) -> void:
	_kid_status.visible = true
	_dog_status.visible = true
	_on_target_changed(Interaction.current_target())


func _on_target_changed(target: Node) -> void:
	if target == null or Dialogue.is_active() or not target.has_method("interact_label"):
		_prompt.visible = false
		return
	_prompt.text = "[E] %s" % target.interact_label()
	_prompt.visible = true


## The frame HUD pieces anchor to (tests read this).
func get_safe_frame() -> SafeFrame:
	return $SafeFrame
