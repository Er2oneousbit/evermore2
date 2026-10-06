# =============================================================================
# debug.gd  (autoload: Debug)
# -----------------------------------------------------------------------------
# WHAT:  Command-line options, leveled logging, and the F3 debug overlay.
# WHY:   One place for every "how do I see what's going on?" tool, so testers
#        never need to edit code to get more info.
#
# COMMAND LINE (Godot passes everything after a bare `--` to the game):
#   godot --path . -- --help       Print options and quit
#   godot --path . -- --debug      Start with the debug overlay visible
#   godot --path . -- --verbose    Print VERBOSE-level log lines too
#
# LOGGING:
#   Debug.log_info("text")     always printed
#   Debug.log_verbose("text")  only with --verbose
#   Debug.log_warn("text")     printed + shows in the editor's Debugger panel
#   Debug.log_error("text")    printed + shows in the editor's Debugger panel
#   Godot also writes every print to user://logs/godot.log automatically.
#   (On Windows: %APPDATA%\Godot\app_userdata\Secret of Evermore 2...\logs)
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## Emitted whenever the overlay is shown/hidden (F3 or --debug).
signal overlay_toggled(is_visible: bool)

const OVERLAY_SCENE := preload("res://ui/debug_overlay/debug_overlay.tscn")

const HELP_TEXT := """
Secret of Evermore 2 - command line options
Usage:  godot --path <project folder> -- [options]
        (or, for an exported build:  evermore2.exe -- [options])

  --help, -h     Show this help and quit
  --debug        Start with the debug overlay visible (toggle any time with F3)
  --verbose      Print extra VERBOSE log lines (AI state changes, spawns, etc.)

In-game debug keys (always available in prototypes):
  F2   Cycle time of day (day / golden hour / night)
  F3   Toggle debug overlay (FPS, positions, dog AI state, breadcrumb trail)
  F4   Warp the dog to the kid (unstick the dog)
  F6   Toggle HD-2D view / classic 2D view
"""

## True when --verbose was passed. Read-only from outside, please.
var verbose := false
## Current overlay visibility. Use toggle_overlay()/set_overlay_visible().
var overlay_visible := false

var _overlay: CanvasLayer


func _ready() -> void:
	# Keep working while the game is paused (pause menus, cutscenes, etc.).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args(OS.get_cmdline_user_args())

	_overlay = OVERLAY_SCENE.instantiate()
	add_child(_overlay)
	_overlay.visible = overlay_visible
	log_verbose("Debug ready. verbose=%s overlay=%s" % [verbose, overlay_visible])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		toggle_overlay()
		get_viewport().set_input_as_handled()


# -----------------------------------------------------------------------------
# Overlay control
# -----------------------------------------------------------------------------
func toggle_overlay() -> void:
	set_overlay_visible(not overlay_visible)


func set_overlay_visible(value: bool) -> void:
	overlay_visible = value
	if is_instance_valid(_overlay):
		_overlay.visible = value
	overlay_toggled.emit(value)
	log_verbose("Overlay %s" % ("shown" if value else "hidden"))


# -----------------------------------------------------------------------------
# Logging helpers. Prefixes make grep-ing godot.log easy.
# -----------------------------------------------------------------------------
func log_info(msg: String) -> void:
	print("[INFO] ", msg)


func log_verbose(msg: String) -> void:
	if verbose:
		print("[VERBOSE] ", msg)


func log_warn(msg: String) -> void:
	push_warning(msg)
	print("[WARN] ", msg)


func log_error(msg: String) -> void:
	push_error(msg)
	printerr("[ERROR] ", msg)


# -----------------------------------------------------------------------------
# Command-line parsing
# -----------------------------------------------------------------------------
func _parse_args(args: PackedStringArray) -> void:
	for arg in args:
		match arg:
			"--help", "-h":
				print(HELP_TEXT)
				# Deferred so the autoload finishes _ready cleanly before quitting.
				get_tree().quit.call_deferred()
			"--debug":
				overlay_visible = true
			"--verbose":
				verbose = true
			_:
				log_warn("Unknown option '%s' (run with -- --help for the list)" % arg)
