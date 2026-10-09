# =============================================================================
# hud.gd  -  The HUD, inside a SafeFrame
# -----------------------------------------------------------------------------
# WHAT:  - bottom left / right: a MemberCard for the kid and the dog (name,
#          health bar with the lost-health ghost, charge bar, the partner's
#          stance and Stay, KO with the revive countdown; "> " and a gold
#          border on the one you drive)
#        - top middle: the sky dial (SkyDial: the clock), and under it
#          "Found Old key  2/5 here" with notices below that
#        - bottom middle: the quick slots (QuickBar) between the cards, with
#          "[E] Talk to Maya" just above them while something is in reach
#        - an arrow at the frame edge points at the partner when he's off screen
#        The text box covers the bottom of the screen, so the cards, prompt
#        and quick slots tuck away while people talk.
# WHY THE FRAME: everything anchors to the SafeFrame, so on 32:9 the HUD sits
#        in the middle 16:9 area instead of the far corners.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends CanvasLayer

const TOAST_SECONDS := 2.8
## Gap between the cards and the frame edge (px).
const MARGIN := 4.0

## The kid's and the dog's cards (tests read them).
var kid_card: MemberCard
var dog_card: MemberCard

## "[E] Talk to Maya": shown while something is in reach (see Interaction).
var _prompt: Label
var _partner_arrow: PartnerArrow
var _quick_bar: QuickBar
var _sky_dial: SkyDial
## "Found Old key  2/5 here", for TOAST_SECONDS (game time).
var _toast: Label
var _toast_left := 0.0
## Short notices ("Slot 2 is empty") on their own line under it, so they
## never cover a find.
var _notice: Label
var _notice_left := 0.0
var _label_settings: LabelSettings
var _label_box: StyleBoxFlat


func _ready() -> void:
	_label_settings = LabelSettings.new()
	_label_settings.font_size = 8
	_label_settings.outline_size = 2
	_label_settings.outline_color = Color.BLACK
	_label_box = StyleBoxFlat.new()
	_label_box.bg_color = Color(0, 0, 0, 0.45)
	_label_box.content_margin_left = 3
	_label_box.content_margin_right = 3
	_label_box.content_margin_top = 1
	_label_box.content_margin_bottom = 1
	kid_card = _build_card("KidCard", get_tree().get_first_node_in_group("kid"), false)
	dog_card = _build_card("DogCard", get_tree().get_first_node_in_group("dog"), true)
	_partner_arrow = PartnerArrow.new()
	_partner_arrow.name = "PartnerArrow"
	$SafeFrame.add_child(_partner_arrow)
	_prompt = _build_label("InteractPrompt")
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	# Above the quick slots, which fill the bottom centre.
	_prompt.offset_top = -QuickBar.SIZE.y - MARGIN - 14
	_prompt.offset_bottom = -QuickBar.SIZE.y - MARGIN - 2
	# Under the sky dial (the top centre).
	_toast = _build_label("FoundToast")
	_toast.offset_top = MARGIN + SkyDial.SIZE.y + 3
	_toast.offset_bottom = _toast.offset_top + 12
	_notice = _build_label("Notice")
	_notice.offset_top = _toast.offset_bottom + 3
	_notice.offset_bottom = _notice.offset_top + 12
	_quick_bar = QuickBar.new()
	_quick_bar.name = "QuickBar"
	_quick_bar.anchor_left = 0.5
	_quick_bar.anchor_right = 0.5
	_quick_bar.anchor_top = 1.0
	_quick_bar.anchor_bottom = 1.0
	_quick_bar.offset_left = -QuickBar.SIZE.x * 0.5
	_quick_bar.offset_right = QuickBar.SIZE.x * 0.5
	_quick_bar.offset_top = -QuickBar.SIZE.y - MARGIN
	_quick_bar.offset_bottom = -MARGIN
	$SafeFrame.add_child(_quick_bar)
	_sky_dial = SkyDial.new()
	_sky_dial.name = "SkyDial"
	_sky_dial.anchor_left = 0.5
	_sky_dial.anchor_right = 0.5
	_sky_dial.offset_left = -SkyDial.SIZE.x * 0.5
	_sky_dial.offset_right = SkyDial.SIZE.x * 0.5
	_sky_dial.offset_top = MARGIN
	_sky_dial.offset_bottom = MARGIN + SkyDial.SIZE.y
	$SafeFrame.add_child(_sky_dial)
	EventBus.item_found.connect(_on_item_found)
	EventBus.notice.connect(show_notice)
	EventBus.interaction_target_changed.connect(_on_target_changed)
	EventBus.dialogue_started.connect(_on_dialogue_started)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.visible = _notice_left > 0.0
	# Names can change (the player names them); cheap to keep in step.
	kid_card.display_name = GameState.get_kid_name()
	dog_card.display_name = GameState.get_dog_name()


func _build_card(card_name: String, member: Node2D, right_side: bool) -> MemberCard:
	var card := MemberCard.new()
	card.name = card_name
	card.member = member
	card.right_side = right_side
	card.anchor_top = 1.0
	card.anchor_bottom = 1.0
	card.offset_top = -MemberCard.SIZE.y - MARGIN
	card.offset_bottom = -MARGIN
	if right_side:
		card.anchor_left = 1.0
		card.anchor_right = 1.0
		card.offset_left = -MemberCard.SIZE.x - MARGIN
		card.offset_right = -MARGIN
	else:
		card.offset_left = MARGIN
		card.offset_right = MARGIN + MemberCard.SIZE.x
	card.visible = member != null
	$SafeFrame.add_child(card)
	return card


## A centered one-line label in the HUD's text style.
func _build_label(label_name: String) -> Label:
	var l := Label.new()
	l.name = label_name
	l.label_settings = _label_settings
	l.add_theme_stylebox_override("normal", _label_box)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.visible = false
	$SafeFrame.add_child(l)
	return l


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


## A line at the top of the screen for a moment (found items).
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


## The text box covers the bottom of the screen: tuck the HUD away meanwhile.
func _on_dialogue_started(_node: String) -> void:
	_prompt.visible = false
	kid_card.visible = false
	dog_card.visible = false
	_quick_bar.visible = false
	_sky_dial.visible = false


func _on_dialogue_ended(_node: String) -> void:
	kid_card.visible = kid_card.member != null
	dog_card.visible = dog_card.member != null
	_quick_bar.visible = true
	_sky_dial.visible = true
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


## The sky dial (tests read it).
func sky_dial() -> SkyDial:
	return _sky_dial


## The frame HUD pieces anchor to (tests read this).
func get_safe_frame() -> SafeFrame:
	return $SafeFrame
