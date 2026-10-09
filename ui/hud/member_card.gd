# =============================================================================
# member_card.gd  -  One of the duo on the HUD: name, health, charge, state
# -----------------------------------------------------------------------------
# WHAT:  A small card in a bottom corner (the kid left, the dog right):
#          > Kid                          Offensive
#          [###########-----]  32/40
#          [charge bar ............] o o o
#        - "> " and a gold border mark the one you drive; the partner's card
#          shows his stance, and "Stay" on Stay put
#        - the health bar goes green -> yellow -> red; a hit leaves a pale
#          "ghost" of the lost health that drains away after a moment, so you
#          see how much that hit took; the bar flashes when he's hurt
#        - knocked out: the card dims, says KO and counts down to the revive
#        - his charge bar (ChargeBar) sits underneath, winded blink and all
#        Reads the member every frame; no signals to wire.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name MemberCard
extends Control

const SIZE := Vector2(132, 33)
const PAD := 4.0
const BAR_H := 5.0
const BG := Color(0.05, 0.04, 0.09, 0.72)
const BORDER_LEADER := Color(0.95, 0.85, 0.6)
const BORDER := Color(1, 1, 1, 0.22)
const HP_GOOD := Color(0.45, 0.9, 0.45)
const HP_MID := Color(0.98, 0.82, 0.3)
const HP_LOW := Color(0.95, 0.32, 0.28)
const GHOST := Color(1.0, 0.95, 0.85, 0.75)
const TEXT := Color(0.94, 0.94, 0.97)
const DIM := Color(0.68, 0.68, 0.76)
## The ghost holds this long after a hit, then drains at GHOST_DRAIN of max HP/s.
const GHOST_HOLD := 0.45
const GHOST_DRAIN := 0.6
## How long the bar flashes after a hit (s).
const FLASH := 0.2
const STANCE_LABELS := {"offensive": "Offensive", "defensive": "Defensive", "search": "Search"}

## The kid or the dog.
var member: Node2D
## His name on the card (the HUD sets it).
var display_name := ""
## Right-aligned card (the dog's, bottom right).
var right_side := false
var charge_bar: ChargeBar

## Health shown by the ghost (fraction of max), and timers.
var _ghost := 1.0
var _ghost_hold := 0.0
var _flash := 0.0
var _last_hp := -1


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Keeps drawing while the ring menu pauses the game (an apple eaten there
	# shows at once); the ghost and flash timers still stop while paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	charge_bar = ChargeBar.new()
	charge_bar.name = "ChargeBar"
	charge_bar.position = Vector2(PAD, SIZE.y - 9)
	charge_bar.size = Vector2(SIZE.x - PAD * 2, 6)
	add_child(charge_bar)


func _process(delta: float) -> void:
	if get_tree().paused:
		delta = 0.0
	var h := _health()
	if h:
		var frac := _hp_fraction(h)
		if _last_hp >= 0 and h.hp < _last_hp:
			_ghost_hold = GHOST_HOLD
			_flash = FLASH
		_last_hp = h.hp
		if frac >= _ghost:
			_ghost = frac  # healing: the ghost jumps up with the bar
		elif _ghost_hold > 0.0:
			_ghost_hold -= delta
		else:
			_ghost = maxf(frac, _ghost - GHOST_DRAIN * delta)
	_flash = maxf(0.0, _flash - delta)
	if is_instance_valid(member):
		charge_bar.meter = member.get("charge")
		charge_bar.run = member.get("run")
	queue_redraw()


## The card as one line, like the old text HUD (tests read it):
## "> Kid  HP 32/40" for the one you drive, "Dog  HP 30/32  Search  Stay".
func summary() -> String:
	var h := _health()
	var text := display_name
	if h:
		text += "  HP %d/%d" % [_hp_now(h), h.max_hp]
		if h.is_dead():
			text += "  KO"
	if Party.partner() == null or not is_instance_valid(member):
		return text
	if member == Party.leader:
		return "> " + text
	return text + "  " + _state_text()


## How much health the ghost still shows (fraction), for tests.
func ghost_fraction() -> float:
	return _ghost


func _health() -> Health:
	return member.get_node_or_null("Health") as Health if is_instance_valid(member) else null


## Health may not have filled up yet if the HUD readies first.
func _hp_now(h: Health) -> int:
	return h.max_hp if h.hp == 0 and not h.is_dead() else h.hp


func _hp_fraction(h: Health) -> float:
	return clampf(float(_hp_now(h)) / maxf(1.0, h.max_hp), 0.0, 1.0)


## The partner's stance (and Stay put).
func _state_text() -> String:
	var st := Party.stance_of(member)
	var text: String = STANCE_LABELS.get(st, st)
	if Party.is_staying(member):
		text += "  Stay"
	return text


func _draw() -> void:
	var font := get_theme_default_font()
	var h := _health()
	var leader := is_instance_valid(member) and member == Party.leader and Party.partner() != null
	var down := h != null and h.is_dead()
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	draw_rect(Rect2(Vector2(0.5, 0.5), SIZE - Vector2.ONE), BORDER_LEADER if leader else BORDER, false, 1.0)

	# Name line (and the partner's stance on the other side).
	var name_text := ("> " if leader else "") + display_name
	draw_string(font, Vector2(PAD, 10), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BORDER_LEADER if leader else TEXT)
	if is_instance_valid(member) and not leader and Party.partner() != null and not down:
		draw_string(font, Vector2(PAD, 10), _state_text(), HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - PAD * 2, 8, DIM)

	# Health bar: lost-health ghost under the live bar, numbers to the right.
	if h:
		var frac := _hp_fraction(h)
		var bar := Rect2(PAD, 13, SIZE.x - PAD * 2 - 34, BAR_H)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * _ghost, BAR_H)), GHOST)
		var col := HP_GOOD if frac > 0.5 else (HP_MID if frac > 0.25 else HP_LOW)
		if _flash > 0.0:
			col = col.lerp(Color.WHITE, 0.6)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, BAR_H)), col)
		draw_string(font, Vector2(bar.end.x + 3, bar.end.y + 1), "%d/%d" % [_hp_now(h), h.max_hp],
				HORIZONTAL_ALIGNMENT_RIGHT, 31, 8, TEXT)

	# Knocked out: dim the card, say so, count down to getting back up.
	if down:
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0, 0, 0, 0.45))
		var left := Party.revive_left(member)
		var ko := "KO" + ("  back in %d" % ceili(left) if left > 0.0 else "")
		draw_string(font, Vector2(PAD, 10), ko, HORIZONTAL_ALIGNMENT_RIGHT, SIZE.x - PAD * 2, 9, HP_LOW)
