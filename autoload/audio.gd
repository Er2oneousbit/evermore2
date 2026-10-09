# =============================================================================
# audio.gd  (autoload: Audio)
# -----------------------------------------------------------------------------
# WHAT:  Plays every sound and the music, by name:
#          Audio.play_at("swing", kid.global_position)   a sound in the world
#          Audio.play("ui_move")                          a menu / HUD sound
#          Audio.play_music("lot")                        crossfades the music
#          Audio.voice("bright", "greet")                 a character's voice clip
#          Audio.set_ambience("outdoor")                  birds by day, crickets
#                                                         at night (follows the
#                                                         time of day by itself)
#          Audio.set_music_set("outdoor")                 music that follows the
#                                                         time of day too: two
#                                                         day and two night tracks,
#                                                         each switch plays the
#                                                         next one in that list
#        SOUNDS is the one table of sound names: which files (one is picked at
#        random, so repeats don't sound robotic), how loud, how much the pitch
#        wanders. The files come from tools/audio/build_audio.py (all CC0, see
#        credits/audio/credits.txt).
#
# HOW:   World sounds use a pool of AudioStreamPlayer2Ds on the "SFX" bus:
#        they pan and fade with distance from the 2D camera (which follows
#        whoever you drive, in both views) and pause with the game. Menu
#        sounds use a separate pool that keeps playing while paused. Music has
#        two players on the "Music" bus for crossfades, ambience two on the
#        "Ambience" bus. The volumes in the settings menu drive those buses.
#
# TESTS: `history` keeps the last sound names played (and music_name the
#        track), so tests can check that a swing really made a sound.
#
# Written with help from Claude (Anthropic) via Claude Code.
# Made with ❤️ from your friendly hacker - er2oneousbit
# =============================================================================
extends Node

## A sound was picked and started (tests listen).
signal played(sound: String)

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

## Sound name -> files (in SFX_DIR, no extension), volume in dB, random pitch
## spread (0.06 = up to 6% higher or lower) and base pitch.
const SOUNDS := {
	"swing":      {"files": ["swing_1", "swing_2", "swing_3"], "db": -7.0, "pitch": 0.06},
	"hit":        {"files": ["hit_1", "hit_2", "hit_3", "hit_4"], "db": -3.0, "pitch": 0.08},
	"thwack":     {"files": ["thwack"], "db": -7.0, "pitch": 0.05},
	"hurt":       {"files": ["hurt_1", "hurt_2"], "db": -3.0, "pitch": 0.06},
	"dog_bark":   {"files": ["dog_bark_1", "dog_bark_2", "dog_bark_3", "dog_bark_4"], "db": -9.0, "pitch": 0.05},
	"dog_yelp":   {"files": ["dog_yelp"], "db": -8.0, "pitch": 0.05},
	"dog_whine":  {"files": ["dog_whine"], "db": -12.0, "pitch": 0.03},
	# A snarl and a snap of teeth (layered by the pipeline); played as the bite
	# starts, the snap lands on the hit frame.
	"dog_bite":   {"files": ["dog_bite_1", "dog_bite_2", "dog_bite_3"], "db": -4.0, "pitch": 0.06},
	# Cues a second before an enemy shows itself (day/night swap): grass moving,
	# and a wing flap (the swing's whoosh, sped up).
	"rustle":     {"files": ["step_grass_2", "step_grass_4", "step_grass_6"], "db": -11.0, "pitch": 0.2, "base": 0.8},
	"wing_flap":  {"files": ["swing_1", "swing_3"], "db": -15.0, "pitch": 0.15, "base": 1.8},
	"rat_squeak": {"files": ["rat_squeak"], "db": -13.0, "pitch": 0.08},
	"rat_pain":   {"files": ["rat_pain"], "db": -12.0, "pitch": 0.1},
	"rat_death":  {"files": ["rat_death"], "db": -11.0, "pitch": 0.06},
	"rat_bite":   {"files": ["rat_bite"], "db": -2.0, "pitch": 0.08},
	"step_grass": {"files": ["step_grass_1", "step_grass_2", "step_grass_3", "step_grass_4", "step_grass_5", "step_grass_6"],
		"db": -15.0, "pitch": 0.08},
	"step_stone": {"files": ["step_stone_1", "step_stone_2", "step_stone_3", "step_stone_4", "step_stone_5", "step_stone_6"],
		"db": -18.0, "pitch": 0.08},
	# The dog's paws: the same steps, lighter and quicker.
	"paw_grass":  {"files": ["step_grass_1", "step_grass_3", "step_grass_5"], "db": -22.0, "pitch": 0.08, "base": 1.35},
	"paw_stone":  {"files": ["step_stone_1", "step_stone_3", "step_stone_5"], "db": -25.0, "pitch": 0.08, "base": 1.4},
	"dig":        {"files": ["dig"], "db": -6.0, "pitch": 0.05},
	"pickup":     {"files": ["pickup"], "db": -8.0, "pitch": 0.0},
	"bird":       {"files": ["bird_1", "bird_2", "bird_3"], "db": -20.0, "pitch": 0.12},
	"ui_move":    {"files": ["ui_move"], "db": -14.0, "pitch": 0.02},
	"ui_confirm": {"files": ["ui_confirm"], "db": -16.0, "pitch": 0.0},
	"ui_back":    {"files": ["ui_back"], "db": -12.0, "pitch": 0.0},
	# The sky dial's soft chime every 3 game hours (the UI confirm, high and quiet).
	"dial_chime":     {"files": ["ui_confirm"], "db": -30.0, "pitch": 0.0, "base": 1.5},
	"dial_chime_big": {"files": ["ui_confirm"], "db": -26.0, "pitch": 0.0, "base": 1.1},
	"ui_open":    {"files": ["ui_open"], "db": -13.0, "pitch": 0.0},
	"text_blip":  {"files": ["text_blip"], "db": -24.0, "pitch": 0.04},
	"whistle":    {"files": ["whistle"], "db": -17.0, "pitch": 0.02},
	"switch":     {"files": ["switch"], "db": -16.0, "pitch": 0.0},
}
## Music name -> file in MUSIC_DIR. The tracks loop seamlessly.
const MUSIC := {
	"home": "home", "lot": "lot", "yard": "yard", "arena": "arena",
	"tropical": "tropical", "innocence": "innocence", "title": "title",
}
## A music set -> the track list for each time of day. Going INTO a time picks
## the next track of its list (so day, night, day plays the other day track).
## A list shared by two times (day and golden) keeps playing across them.
const _OUTDOOR_DAY := ["yard", "tropical"]
const MUSIC_SETS := {
	"outdoor": {"morning": _OUTDOOR_DAY, "day": _OUTDOOR_DAY, "golden": _OUTDOOR_DAY, "night": ["lot", "innocence"]},
}

const VOICE_DIR := "res://assets/audio/voice/"
## Voices: real voice actors saying one or two words ("Hey!", "What?") when
## someone starts talking to you or reacts. Characters pick one with
## CharacterData.voice. voice -> volume dB and kind -> files (in VOICE_DIR).
## Kinds: greet, question, agree, disagree, laugh, surprise, bye.
const VOICES := {
	"bright": {"db": -6.0, "pitch": 0.02, "kinds": {
		"greet": ["bright_hey_1", "bright_hey_2", "bright_hey_3", "bright_hello_2", "bright_hello_3"],
		"question": ["bright_what_1", "bright_what_2", "bright_why_1", "bright_why_2"],
		"agree": ["bright_okay_1", "bright_okay_2", "bright_okay_3"],
		"laugh": ["bright_laugh_1", "bright_laugh_2"],
		"surprise": ["bright_gasp_1"],
		"bye": ["bright_bye_1", "bright_bye_2", "bright_bye_3"],
	}},
	"adventurer": {"db": -6.0, "pitch": 0.02, "kinds": {
		"greet": ["adventurer_greet_1"],
		"agree": ["adventurer_yes_1", "adventurer_yes_2"],
		"disagree": ["adventurer_no_1", "adventurer_no_2"],
	}},
}
## A line's emotion tag in a .dlg -> which kind of voice clip it plays.
const EMOTION_VOICE := {
	"surprised": "surprise", "shocked": "surprise", "laughing": "laugh", "happy": "laugh",
	"confused": "question", "curious": "question", "relieved": "agree",
}

const AMBIENCE_DIR := "res://assets/audio/ambience/"
## Ambience loop -> [file in AMBIENCE_DIR, volume dB]. Both sit about 10 dB
## under the music (measured: day -24 dBFS, night -19 dBFS before this).
const AMBIENCE := {"day": ["day", -6.0], "night": ["night", -11.0]}
## A kind of place -> which loop for each time of day ("" = none).
const AMBIENCE_SETS := {
	"outdoor": {"morning": "day", "day": "day", "golden": "day", "night": "night"},
}
## Outdoors by day, a bird calls every so often (seconds, random in between),
## from somewhere around the camera (px).
const BIRD_EVERY := Vector2(7.0, 16.0)
const BIRD_DISTANCE := Vector2(140.0, 380.0)

const WORLD_VOICES := 16
const UI_VOICES := 4
## World sounds are full volume this close to the camera (px)...
const NEAR_PX := 220.0
## ...and silent past this.
const FAR_PX := 760.0
## The same sound starts at most this many times per frame (a sweep hitting
## five rats is one thump, not a wall of noise).
const MAX_PER_FRAME := 2

## Last sound names played, newest last (tests read it).
var history: Array[String] = []
## The music playing now ("" = none).
var music_name := ""
## The ambience loop playing now ("" = none) and the kind of place.
var ambience_name := ""
var ambience_set := ""
## The music set active now ("" = none; play_music() clears it).
var music_set := ""

var _streams: Dictionary = {}  # file -> AudioStream
var _world: Array[AudioStreamPlayer2D] = []
var _ui: Array[AudioStreamPlayer] = []
var _music: Array[AudioStreamPlayer] = []
var _music_on := 0  # which of the two music players is current
var _fade: Tween
var _amb: Array[AudioStreamPlayer] = []
var _amb_on := 0
var _amb_fade: Tween
var _time_name := "day"
var _music_turn: Dictionary = {}  # time name -> how many times we entered it
var _bird_timer := 0.0
var _frame_counts: Dictionary = {}
var _frame := -1
## Headless runs (tests, CI) pick and log sounds but never start playback:
## there's no real audio device, and the dummy driver never mixes, so
## playbacks started there are never released and show up as leaks at exit.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	for i in WORLD_VOICES:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = FAR_PX
		p.attenuation = 1.6
		p.panning_strength = 0.6
		p.process_mode = Node.PROCESS_MODE_PAUSABLE  # stops with the game
		add_child(p)
		_world.append(p)
	for i in UI_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_ui.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Ambience"
		p.volume_db = -80.0
		p.process_mode = Node.PROCESS_MODE_PAUSABLE  # the world goes quiet in the pause menu
		add_child(p)
		_amb.append(p)
	_bird_timer = randf_range(BIRD_EVERY.x, BIRD_EVERY.y)
	EventBus.time_of_day_changed.connect(func(t: String) -> void:
		_time_name = t
		_update_ambience(2.5)
		_update_music_set(2.5, false))


func _process(delta: float) -> void:
	# Now and then a bird, outdoors by day (not while paused).
	if get_tree().paused or ambience_name != "day":
		return
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = randf_range(BIRD_EVERY.x, BIRD_EVERY.y)
		var cam := get_viewport().get_camera_2d()
		if cam:
			var at := cam.get_screen_center_position() \
					+ Vector2.from_angle(randf() * TAU) * randf_range(BIRD_DISTANCE.x, BIRD_DISTANCE.y)
			play_at("bird", at)


## Quitting with sounds still playing would leave their playbacks alive past
## shutdown (reported as leaks): stop everything and let go of the streams.
func _exit_tree() -> void:
	if _fade:
		_fade.kill()
	var all: Array[Node] = []
	all.append_array(_world)
	all.append_array(_ui)
	all.append_array(_music)
	all.append_array(_amb)
	for p in all:
		p.stop()
		p.stream = null
	_streams.clear()


## A menu or HUD sound (not placed in the world; plays while paused).
func play(sound: String, pitch := 1.0) -> bool:
	var s := _prepare(sound)
	if s.is_empty():
		return false
	var p := _free_voice(_ui) as AudioStreamPlayer
	p.stream = s["stream"]
	p.volume_db = s["db"]
	p.pitch_scale = s["pitch"] * pitch
	if not _silent:
		p.play()
	return true


## A sound at a spot in the world (pans and fades with distance; pauses with
## the game). Too far from the camera = not played at all.
func play_at(sound: String, world_pos: Vector2, pitch := 1.0) -> bool:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.get_screen_center_position().distance_to(world_pos) > FAR_PX:
		return false
	var s := _prepare(sound)
	if s.is_empty():
		return false
	var p := _free_voice(_world) as AudioStreamPlayer2D
	p.global_position = world_pos
	p.stream = s["stream"]
	p.volume_db = s["db"]
	p.pitch_scale = s["pitch"] * pitch
	if not _silent:
		p.play()
	return true


## Crossfade to a music track ("" or an unknown name stops the music).
func play_music(track: String, fade := 1.0) -> void:
	music_set = ""  # picking a track by hand ends any time-of-day set
	_play_track(track, fade)


## Music that follows the time of day ("outdoor", or "" for none). Starts the
## current time's next track; the set stays until play_music()/set_music_set("").
func set_music_set(kind: String, fade := 1.5) -> void:
	if kind != "" and not MUSIC_SETS.has(kind):
		Debug.log_warn("Audio: unknown music set '%s'" % kind)
		kind = ""
	music_set = kind
	_music_turn.clear()
	if kind != "":
		_update_music_set(fade, true)


## keep: stay on a track that already belongs to the new time's list (day to
## golden shares one), unless the set was just started.
func _update_music_set(fade: float, force: bool) -> void:
	if music_set == "":
		return
	var list: Array = MUSIC_SETS[music_set].get(_time_name, [])
	if list.is_empty() or (not force and list.has(music_name)):
		return
	var turn: int = _music_turn.get(_time_name, 0)
	_music_turn[_time_name] = turn + 1
	_play_track(list[turn % list.size()], fade)


func _play_track(track: String, fade: float) -> void:
	if track == music_name:
		return
	if not MUSIC.has(track):
		if track != "":
			Debug.log_warn("Audio: unknown music '%s'" % track)
		stop_music(fade)
		return
	var stream := _load(MUSIC_DIR + MUSIC[track] + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	music_name = track
	var old := _music[_music_on]
	_music_on = 1 - _music_on
	var new := _music[_music_on]
	new.stream = stream
	new.volume_db = -40.0 if fade > 0.0 else 0.0
	if not _silent:
		new.play()
	_crossfade(new, old, fade)
	Debug.log_verbose("Audio: music -> %s" % track)


## A character's voice clip ("bright", "greet"). False if that voice has no
## clip of that kind (then nothing plays: silence beats a wrong word).
func voice(voice_name: String, kind: String) -> bool:
	if voice_name == "" or not VOICES.has(voice_name):
		return false
	var v: Dictionary = VOICES[voice_name]
	var files: Array = v["kinds"].get(kind, [])
	if files.is_empty():
		return false
	var stream := _load(VOICE_DIR + files[randi() % files.size()] + ".ogg")
	if stream == null:
		return false
	var label := "voice:%s:%s" % [voice_name, kind]
	history.append(label)
	played.emit(label)
	var p := _free_voice(_ui) as AudioStreamPlayer
	p.stream = stream
	p.volume_db = v["db"]
	var spread: float = v.get("pitch", 0.0)
	p.pitch_scale = 1.0 + randf_range(-spread, spread)
	if not _silent:
		p.play()
	return true


## What kind of place this is ("outdoor", or "" for silence); the loop then
## follows the time of day by itself.
func set_ambience(kind: String) -> void:
	if kind != "" and not AMBIENCE_SETS.has(kind):
		Debug.log_warn("Audio: unknown ambience '%s'" % kind)
		kind = ""
	ambience_set = kind
	_update_ambience(1.5)


func _update_ambience(fade: float) -> void:
	var want := ""
	if ambience_set != "":
		want = AMBIENCE_SETS[ambience_set].get(_time_name, "")
	if want == ambience_name:
		return
	ambience_name = want
	var old := _amb[_amb_on]
	_amb_on = 1 - _amb_on
	var new := _amb[_amb_on]
	if _amb_fade:
		_amb_fade.kill()
	if want == "" and not old.playing:
		return  # nothing to start, nothing to fade out
	_amb_fade = create_tween().set_parallel(true)
	if want != "":
		var stream := _load(AMBIENCE_DIR + AMBIENCE[want][0] + ".ogg")
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		new.stream = stream
		new.volume_db = -40.0
		if not _silent:
			new.play()
		_amb_fade.tween_property(new, "volume_db", AMBIENCE[want][1], fade)
	if old.playing:
		_amb_fade.tween_property(old, "volume_db", -60.0, fade)
		_amb_fade.chain().tween_callback(old.stop)
	Debug.log_verbose("Audio: ambience -> %s" % (want if want != "" else "none"))


## The player of the current ambience loop (tests read it).
func ambience_player() -> AudioStreamPlayer:
	return _amb[_amb_on]


func stop_music(fade := 1.0) -> void:
	music_name = ""
	_crossfade(null, _music[_music_on], fade)


## The player of the current track (tests read it).
func music_player() -> AudioStreamPlayer:
	return _music[_music_on]


# -----------------------------------------------------------------------------
func _prepare(sound: String) -> Dictionary:
	if not SOUNDS.has(sound):
		Debug.log_warn("Audio: unknown sound '%s'" % sound)
		return {}
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_frame_counts.clear()
	var n: int = _frame_counts.get(sound, 0)
	if n >= MAX_PER_FRAME:
		return {}
	_frame_counts[sound] = n + 1
	var def: Dictionary = SOUNDS[sound]
	var files: Array = def["files"]
	var stream := _load(SFX_DIR + files[randi() % files.size()] + ".ogg")
	if stream == null:
		return {}
	history.append(sound)
	if history.size() > 64:
		history.pop_front()
	played.emit(sound)
	var spread: float = def.get("pitch", 0.0)
	return {"stream": stream, "db": def["db"],
			"pitch": def.get("base", 1.0) * (1.0 + randf_range(-spread, spread))}


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		if not ResourceLoader.exists(path):
			Debug.log_warn("Audio: missing file %s (run tools/audio/build_audio.py)" % path)
			return null
		_streams[path] = load(path)
	return _streams[path]


## A player that's free, or else the one that started longest ago.
func _free_voice(pool: Array) -> Node:
	for p in pool:
		if not p.playing:
			return p
	var p: Node = pool.pop_front()
	pool.append(p)
	return p


func _crossfade(to: AudioStreamPlayer, from: AudioStreamPlayer, seconds: float) -> void:
	if _fade:
		_fade.kill()
	# A fade cut short can leave a third track hanging at low volume: stop it.
	for p in _music:
		if p != to and p != from:
			p.stop()
	if seconds <= 0.0:
		if from and from != to:
			from.stop()
		if to:
			to.volume_db = 0.0
		return
	if to == null and (from == null or not from.playing):
		return  # a stop with nothing playing: no tween without tweeners
	_fade = create_tween().set_parallel(true)
	if to:
		_fade.tween_property(to, "volume_db", 0.0, seconds).set_trans(Tween.TRANS_SINE)
	if from and from != to and from.playing:
		_fade.tween_property(from, "volume_db", -60.0, seconds)
		_fade.chain().tween_callback(from.stop)
