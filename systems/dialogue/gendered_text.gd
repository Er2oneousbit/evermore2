# =============================================================================
# gendered_text.gd  -  The one resolver for {...} tokens in player-facing text
# -----------------------------------------------------------------------------
# WHAT:  The kid is a boy or a girl (the player's choice), so any text that
#        talks about the kid has to adapt. This expands the {...} tokens in a
#        string and checks them at load time. Dialogue, HUD notices and
#        Names.text all go through it (Names.expand is the front door).
#
# TOKENS (case matters for the capitalised pronouns):
#   {boy text|girl text}   inline split: exactly two parts, boy first.
#                          "Hey you, {boy|girl}!"  "Hey, {young man|young lady}."
#                          Parts are plain text (no braces inside).
#   {he} {him} {his}       he/she, him/her, his/her
#   {He} {Him} {His}       the same, capitalised (start of a sentence)
#   {son}  {Son}           son / daughter
#   {boy}  {Boy}           boy / girl
#   {kid} {dog}            the player's names for them (see names.json)
#   {any_key}              any other names.json key
#   Dad's own 1995 self stays plain text ("he", "boy"): only the KID is a token.
#
# VALIDATE: GenderedText.problems(text) -> messages for an unbalanced brace,
#        a split without exactly two parts, an empty token, or a token that is
#        not a pronoun, a player name or a names.json key. DialogueScript turns
#        them into "file:line: ..." errors.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
class_name GenderedText
extends RefCounted

const GENDERS := ["boy", "girl"]

## token -> [boy form, girl form]
const PRONOUNS := {
	"he": ["he", "she"], "He": ["He", "She"],
	"him": ["him", "her"], "Him": ["Him", "Her"],
	"his": ["his", "her"], "His": ["His", "Her"],
	"son": ["son", "daughter"], "Son": ["Son", "Daughter"],
	"boy": ["boy", "girl"], "Boy": ["Boy", "Girl"],
}
## Tokens that are the player's names (resolved by the caller's resolver).
const PLAYER_NAMES := ["kid", "dog"]


## Expand every token. `resolve_name` (Callable(key) -> String) answers {kid},
## {dog} and names.json keys; a missing one shows as [missing:key] there.
## Unbalanced braces are left as they are (problems() reports them at load).
static func expand(text: String, gender: String, resolve_name: Callable) -> String:
	if not text.contains("{"):
		return text
	var idx := 1 if gender == "girl" else 0
	var out := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "{":
			var close := text.find("}", i + 1)
			if close < 0:
				out += text.substr(i)
				break
			var inner := text.substr(i + 1, close - i - 1)
			if inner.contains("{"):  # broken: keep the stray brace, try again after it
				out += c
				i += 1
				continue
			out += _token(inner, idx, resolve_name)
			i = close + 1
			continue
		out += c
		i += 1
	return out


static func _token(inner: String, idx: int, resolve_name: Callable) -> String:
	if inner.contains("|"):
		var parts := inner.split("|")
		return parts[idx] if parts.size() == 2 else "{%s}" % inner
	if PRONOUNS.has(inner):
		return PRONOUNS[inner][idx]
	return str(resolve_name.call(inner))


## Everything wrong with the tokens in `text` (empty = fine). `is_name` is a
## Callable(key) -> bool for the names.json keys; without one, any
## identifier-shaped token passes.
static func problems(text: String, is_name := Callable()) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == "}":
			out.append("unbalanced '}' (no matching '{')")
		elif c == "{":
			var close := text.find("}", i + 1)
			var nxt := text.find("{", i + 1)
			if close < 0 or (nxt >= 0 and nxt < close):
				out.append("unbalanced '{' (no closing '}')")
			else:
				var inner := text.substr(i + 1, close - i - 1)
				var why := _check(inner, is_name)
				if not why.is_empty():
					out.append(why)
				i = close
		i += 1
	return out


static func _check(inner: String, is_name: Callable) -> String:
	if inner.contains("|"):
		var n := inner.split("|").size()
		if n != 2:
			return "split {%s} needs exactly 2 parts (boy|girl), found %d" % [inner, n]
		return ""
	if inner.strip_edges().is_empty():
		return "empty token {}"
	if PRONOUNS.has(inner) or inner in PLAYER_NAMES:
		return ""
	if is_name.is_valid():
		if not is_name.call(inner):
			return "unknown token {%s} (not a pronoun, {kid}, {dog} or a names.json key)" % inner
	return ""
