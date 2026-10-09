# =============================================================================
# character_data.gd  -  Who someone is: name, sprite sheet, portrait
# -----------------------------------------------------------------------------
# WHAT:  A Resource per speaking character (data/characters/<ID>.tres). The
#        file name is the speaker ID used in .dlg scripts ("DAD.tres" -> DAD).
#        NPCs use it for their sprite; the text box uses it for the name plate
#        and the portrait, which is a crop of the sprite sheet (no extra art).
# MAKE ONE: FileSystem > New Resource > CharacterData, save as
#        data/characters/<ID>.tres, set name_key + sheet. For a Universal LPC
#        sheet the default portrait crop (the face, facing down) just works.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name CharacterData
extends Resource

## names.json key for the display name. "kid" and "dog" mean the names the
## player picked (GameState).
@export var name_key := ""
## Sprite sheet (a Universal LPC 832x3456 sheet for people).
@export var sheet: Texture2D
## The kid only: the sheet shown when the player chose a girl
## (GameState.kid_gender == "girl"); empty = `sheet` for everyone.
@export var sheet_girl: Texture2D
## Part of the sheet shown as the portrait (pixels). The default is the face
## of an LPC character's idle-facing-down frame (row 24, column 0).
@export var portrait_region := Rect2(16, 24 * 64 + 4, 32, 32)
## Optional portraits per emotion ("happy" -> texture). Missing ones fall back
## to the cropped default, so scripts can use emotions before the art exists.
@export var emotion_portraits: Dictionary = {}
## Name plate color.
@export var color := Color(1.0, 0.92, 0.7)
## Voice for the short spoken clips ("Hey!" when you talk to them, reactions
## on emotion tags): a key of Audio.VOICES. Empty = silent (like the kid).
@export var voice := ""


func display_name() -> String:
	match name_key:
		"kid":
			return GameState.get_kid_name()
		"dog":
			return GameState.get_dog_name()
	return Names.text(name_key)


## The portrait for an emotion (falls back to the default crop).
func portrait(emotion := "") -> Texture2D:
	if not emotion.is_empty() and emotion_portraits.has(emotion):
		return emotion_portraits[emotion]
	if sheet == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = sheet_girl if name_key == "kid" and GameState.kid_gender == "girl" and sheet_girl else sheet
	at.region = portrait_region
	return at
