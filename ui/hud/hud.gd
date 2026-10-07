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


func _ready() -> void:
	# Placeholder numbers until a health system exists.
	_kid_status.text = "%s  HP 10/10" % GameState.get_kid_name()
	_dog_status.text = "%s  HP 10/10" % GameState.get_dog_name()
	_build_prompt()
	EventBus.interaction_target_changed.connect(_on_target_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


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
