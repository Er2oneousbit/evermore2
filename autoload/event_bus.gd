# =============================================================================
# event_bus.gd  (autoload: EventBus)
# -----------------------------------------------------------------------------
# WHAT:  Global signals that unrelated systems use to talk to each other.
# WHY:   The kid shouldn't need a reference to the HUD, the HUD shouldn't need
#        a reference to the dog, etc. Emit here, listen anywhere.
#
# RULES OF THUMB:
#   - Use EventBus for game-wide events (boss died, realm changed, flag set).
#   - Use normal node signals for local stuff (a button inside one menu).
#   - Name signals in past tense: something already happened.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## The kid's phone flashlight was switched on/off.
@warning_ignore("unused_signal")
signal light_toggled(is_on: bool)

## The dog's AI state changed. state_name is the enum key, e.g. "FOLLOW".
@warning_ignore("unused_signal")
signal dog_state_changed(state_name: String)

## Time of day changed in the current realm ("day", "golden", "night").
@warning_ignore("unused_signal")
signal time_of_day_changed(time_name: String)

## A conversation started / ended (node name from the .dlg file).
@warning_ignore("unused_signal")
signal dialogue_started(node_name: String)
@warning_ignore("unused_signal")
signal dialogue_ended(node_name: String)

## What the kid would interact with right now changed (null = nothing).
@warning_ignore("unused_signal")
signal interaction_target_changed(target: Node)

## Shake the camera (both the 2D and the HD-2D camera listen). px, seconds.
@warning_ignore("unused_signal")
signal camera_shake(strength: float, seconds: float)

## The player now drives `leader` (the kid or the dog). See Party.
@warning_ignore("unused_signal")
signal control_changed(leader: Node2D)

## Stay put was switched on or off for the partner. See Party.
@warning_ignore("unused_signal")
signal partner_stay_changed(staying: bool)

## A party member's stance changed ("offensive", "defensive", "search").
@warning_ignore("unused_signal")
signal stance_changed(member: Node2D, stance: String)

## A story/progress flag was set via GameState.set_flag().
@warning_ignore("unused_signal")
signal flag_changed(flag: String, value: Variant)
