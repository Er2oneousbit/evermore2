# =============================================================================
# hud.gd  -  Placeholder HUD (names + HP), lives inside a SafeFrame
# -----------------------------------------------------------------------------
# WHAT:  Bottom-left: the kid. Bottom-right: the dog. Each shows HP and his
#        charge bar; "> " marks the one you drive, and the partner shows his
#        stance (and "Stay" on Stay put). An arrow points at the partner when
#        he's off-screen. Finding a hidden item shows a line at the top
#        ("Found Old key  2/5 here"). Text only for now; real bars and the
#        ring menu later.
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
var _dog_charge_bar: ChargeBar
var _partner_arrow: PartnerArrow
var _quick_bar: QuickBar
## "Found Old key  2/5 here", for TOAST_SECONDS (game time).
var _toast: Label
var _toast_left := 0.0
## Short notices ("Slot 2 is empty") on their own line under it, so they
## never cover a find.
var _notice: Label
var _notice_left := 0.0
const TOAST_SECONDS := 2.8
var _kid: Node2D
var _dog: Node2D

const STANCE_LABELS := {"offensive": "Offensive", "defensive": "Defensive", "search": "Search"}


func _ready() -> void:
	_kid = get_tree().get_first_node_in_group("kid")
	_dog = get_tree().get_first_node_in_group("dog")
	for m in [_kid, _dog]:
		var h: Health = m.get_node_or_null("Health") if m else null
		if h:
			h.changed.connect(func(_hp: int, _max: int) -> void: _refresh_status())
	_charge_bar = _build_charge_bar("ChargeBar", false)
	_dog_charge_bar = _build_charge_bar("DogChargeBar", true)
	_partner_arrow = PartnerArrow.new()
	_partner_arrow.name = "PartnerArrow"
	$SafeFrame.add_child(_partner_arrow)
	_build_prompt()
	_build_toast()
	_quick_bar = QuickBar.new()
	_quick_bar.name = "QuickBar"
	_quick_bar.position = Vector2(5, 5)
	$SafeFrame.add_child(_quick_bar)
	_refresh_status()
	EventBus.item_found.connect(_on_item_found)
	EventBus.notice.connect(show_notice)
	EventBus.interaction_target_changed.connect(_on_target_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.control_changed.connect(func(_l: Node2D) -> void: _refresh_status())
	EventBus.partner_stay_changed.connect(func(_on: bool) -> void: _refresh_status())
	EventBus.stance_changed.connect(func(_m: Node2D, _s: String) -> void: _refresh_status())


## Both status labels: "> " on the one you drive, HP, and the partner's stance.
func _refresh_status() -> void:
	_kid_status.text = _status_text(_kid, GameState.get_kid_name())
	_dog_status.text = _status_text(_dog, GameState.get_dog_name())


func _status_text(member: Node2D, who: String) -> String:
	if not is_instance_valid(member):
		return who
	var text := who
	var h: Health = member.get_node_or_null("Health")
	if h:
		# Health may not have filled up yet if the HUD readies first.
		var hp := h.max_hp if h.hp == 0 and not h.is_dead() else h.hp
		text += "  HP %d/%d" % [hp, h.max_hp]
		if h.is_dead():
			text += "  KO"
	if Party.partner() == null:
		return text
	if member == Party.leader:
		return "> " + text
	text += "  " + STANCE_LABELS.get(Party.stance_of(member), Party.stance_of(member))
	if Party.is_staying(member):
		text += "  Stay"
	return text


func _build_charge_bar(bar_name: String, right_side: bool) -> ChargeBar:
	var bar := ChargeBar.new()
	bar.name = bar_name
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	if right_side:
		bar.anchor_left = 1.0
		bar.anchor_right = 1.0
		bar.offset_left = -75
		bar.offset_right = -5
	else:
		bar.offset_left = 5
		bar.offset_right = 75
	bar.offset_top = -21
	bar.offset_bottom = -16
	$SafeFrame.add_child(bar)
	return bar


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0
	for pair in [[_charge_bar, _kid, _kid_status], [_dog_charge_bar, _dog, _dog_status]]:
		var bar: ChargeBar = pair[0]
		var m: Node2D = pair[1]
		if bar and is_instance_valid(m) and m.get("charge") != null:
			bar.meter = m.charge
			bar.run = m.get("run")
			bar.visible = (pair[2] as Label).visible
		elif bar:
			bar.visible = false


func _build_toast() -> void:
	_toast = Label.new()
	_toast.name = "FoundToast"
	_toast.label_settings = _kid_status.label_settings
	_toast.add_theme_stylebox_override("normal", _kid_status.get_theme_stylebox("normal"))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 8
	_toast.offset_bottom = 20
	_toast.visible = false
	$SafeFrame.add_child(_toast)
	_notice = _toast.duplicate() as Label
	_notice.name = "Notice"
	_notice.offset_top = 24
	_notice.offset_bottom = 36
	$SafeFrame.add_child(_notice)


func _on_item_found(item: ItemData, count: int, _key: String) -> void:
	var text := "Found %s" % (item.display_name if item else "something")
	if count > 1:
		text += " x%d" % count
	var realm := get_tree().get_first_node_in_group("ascii_realm") as AsciiRealm
	if realm:
		var c := realm.hidden_counts()
		if c.y > 0:
			text += "   %d/%d here" % [c.x, c.y]
	show_toast(text)


## A line at the top of the screen for a moment (found items, notices).
func show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_left = TOAST_SECONDS


## A short notice for a moment, under the find line.
func show_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = true
	_notice_left = TOAST_SECONDS


## The notice line's text while it shows ("" otherwise). Tests read it.
func notice_text() -> String:
	return _notice.text if _notice.visible else ""


## The find line's text while it shows ("" otherwise). Tests read it.
func toast_text() -> String:
	return _toast.text if _toast.visible else ""


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
	_dog_charge_bar.visible = false
	_quick_bar.visible = false


func _on_dialogue_ended(_node: String) -> void:
	_kid_status.visible = true
	_dog_status.visible = true
	_quick_bar.visible = true
	_on_target_changed(Interaction.current_target())


func _on_target_changed(target: Node) -> void:
	if target == null or Dialogue.is_active() or not target.has_method("interact_label"):
		_prompt.visible = false
		return
	_prompt.text = "[%s] %s" % [_key_name("interact"), target.interact_label()]
	_prompt.visible = true


## The first key bound to an action (rebindable), for prompts.
func _key_name(action: String) -> String:
	var keys: Array = InputSetup.bindings_of(action)["keys"]
	return InputSetup.key_label(keys[0]) if not keys.is_empty() else "?"


## The frame HUD pieces anchor to (tests read this).
func get_safe_frame() -> SafeFrame:
	return $SafeFrame
