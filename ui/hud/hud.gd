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


func _ready() -> void:
	# Placeholder numbers until a health system exists.
	_kid_status.text = "%s  HP 10/10" % GameState.get_kid_name()
	_dog_status.text = "%s  HP 10/10" % GameState.get_dog_name()


## The frame HUD pieces anchor to (tests read this).
func get_safe_frame() -> SafeFrame:
	return $SafeFrame
