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

## Time of day changed in the current realm ("morning", "day", "golden",
## "night"). The game clock (autoload/clock.gd) drives it through Atmosphere;
## Clock.last_blend says how long the change fades.
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

## A hidden item was found and picked up. `key` is its found flag; the realm
## counts found/total (AsciiRealm.hidden_counts).
@warning_ignore("unused_signal")
signal item_found(item: ItemData, count: int, key: String)

## The dog sniffed (you drive him): `targets` are what his scent trails lead
## to (hidden items, NPCs).
@warning_ignore("unused_signal")
signal dog_sniffed(targets: Array)

## Someone's equipment changed ("kid" or "dog"). See Equipment.
@warning_ignore("unused_signal")
signal equipment_changed(who: String)

## An item was used on a party member (Usables).
@warning_ignore("unused_signal")
signal item_used(item: ItemData, target: Node)

## The kid cast a formula; leveled_up = it reached a new level with this cast.
@warning_ignore("unused_signal")
signal formula_cast(formula: FormulaData, target: Node, leveled_up: bool)

## A short message for the player (a quick slot that couldn't fire...). The
## HUD shows it at the top of the screen.
@warning_ignore("unused_signal")
signal notice(text: String)

## Something was put in (or moved out of) a quick slot.
@warning_ignore("unused_signal")
signal quick_slots_changed()

## The player picked "boy" or "girl" for the kid (the actor swaps its sheet).
@warning_ignore("unused_signal")
signal kid_gender_changed(gender: String)

## A story/progress flag was set via GameState.set_flag().
@warning_ignore("unused_signal")
signal flag_changed(flag: String, value: Variant)
