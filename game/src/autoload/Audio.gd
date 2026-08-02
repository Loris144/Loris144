extends Node
## Tiny chiptune engine.
##
## There are no audio files in the project, so music and sound effects are
## synthesised at runtime into an AudioStreamGenerator. Melodies are stored as
## note tables; each track loops until another one is requested.

const RATE := 22050.0

var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _music_pb: AudioStreamGeneratorPlayback
var _sfx_pb: AudioStreamGeneratorPlayback

var _track := ""
var _note_i := 0
var _phase := 0.0
var _note_left := 0.0
var _sfx_queue: Array = []           # [freq, secs, wave, vol]
var _sfx_phase := 0.0
var _sfx_left := 0.0
var _sfx_cur: Array = []

# note name -> frequency (octave 4 base)
const N := {
	"C": 261.63, "C#": 277.18, "D": 293.66, "D#": 311.13, "E": 329.63,
	"F": 349.23, "F#": 369.99, "G": 392.00, "G#": 415.30, "A": 440.00,
	"A#": 466.16, "B": 493.88, "-": 0.0,
}

## Each entry: [note, octave-shift, beats]. "-" is a rest.
const TRACKS := {
	"town": [
		["C", 0, 1], ["E", 0, 1], ["G", 0, 1], ["E", 0, 1],
		["F", 0, 1], ["A", 0, 1], ["C", 1, 2],
		["G", 0, 1], ["E", 0, 1], ["C", 0, 2],
		["D", 0, 1], ["F", 0, 1], ["A", 0, 1], ["G", 0, 1],
		["E", 0, 2], ["C", 0, 2],
	],
	"duel": [
		["E", 0, 1], ["E", 0, 1], ["G", 0, 1], ["B", 0, 1],
		["A", 0, 1], ["G", 0, 1], ["E", 0, 2],
		["D", 0, 1], ["E", 0, 1], ["G", 0, 1], ["A", 0, 1],
		["B", 0, 2], ["G", 0, 2],
		["C", 1, 1], ["B", 0, 1], ["G", 0, 1], ["E", 0, 1],
		["D", 0, 2], ["E", 0, 2],
	],
	"tense": [
		["A", -1, 1], ["A", -1, 1], ["C", 0, 1], ["A", -1, 1],
		["D#", 0, 2], ["D", 0, 2],
		["A", -1, 1], ["A", -1, 1], ["C", 0, 1], ["D", 0, 1],
		["D#", 0, 2], ["E", 0, 2],
	],
	"sad": [
		["A", 0, 2], ["G", 0, 2], ["F", 0, 2], ["E", 0, 2],
		["D", 0, 2], ["E", 0, 2], ["C", 0, 4],
		["F", 0, 2], ["E", 0, 2], ["D", 0, 2], ["C", 0, 2],
		["A", -1, 4],
	],
	"victory": [
		["C", 0, 1], ["E", 0, 1], ["G", 0, 1], ["C", 1, 2],
		["G", 0, 1], ["C", 1, 3],
	],
	"egypt": [
		["D", 0, 1], ["E", 0, 1], ["F", 0, 1], ["G#", 0, 1],
		["A", 0, 2], ["G#", 0, 1], ["F", 0, 1],
		["E", 0, 2], ["D", 0, 2],
		["A", -1, 1], ["D", 0, 1], ["F", 0, 1], ["E", 0, 1],
		["D", 0, 4],
	],
	"title": [
		["G", 0, 1], ["C", 1, 2], ["B", 0, 1],
		["A", 0, 1], ["G", 0, 1], ["E", 0, 2],
		["F", 0, 1], ["A", 0, 1], ["G", 0, 3],
	],
}

const BEAT := 0.28


func _ready() -> void:
	_music_player = _make_player(-14.0)
	_sfx_player = _make_player(-8.0)
	await get_tree().process_frame
	_music_pb = _music_player.get_stream_playback()
	_sfx_pb = _sfx_player.get_stream_playback()


func _make_player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	p.stream = gen
	p.volume_db = db
	add_child(p)
	p.play()
	return p


func _process(_delta: float) -> void:
	if _music_pb:
		_fill_music()
	if _sfx_pb:
		_fill_sfx()


# =====================================================================
# music
# =====================================================================

func play_music(track: String) -> void:
	if track == _track:
		return
	_track = track
	_note_i = 0
	_note_left = 0.0
	_phase = 0.0


func stop_music() -> void:
	_track = ""


func _fill_music() -> void:
	var frames := _music_pb.get_frames_available()
	if frames <= 0:
		return
	var vol: float = float(Game.settings.get("music", 0.7))
	if _track == "" or not TRACKS.has(_track) or vol <= 0.01:
		for i in frames:
			_music_pb.push_frame(Vector2.ZERO)
		return
	var notes: Array = TRACKS[_track]
	for i in frames:
		if _note_left <= 0.0:
			var n: Array = notes[_note_i % notes.size()]
			_note_i += 1
			var base: float = N.get(str(n[0]), 0.0)
			_cur_freq = base * pow(2.0, float(n[1]))
			_note_left = float(n[2]) * BEAT
			_note_len = _note_left
			_phase = 0.0
		var s := 0.0
		if _cur_freq > 0.0:
			_phase += _cur_freq / RATE
			if _phase >= 1.0:
				_phase -= 1.0
			# square lead + soft triangle sub-octave
			s = (1.0 if _phase < 0.5 else -1.0) * 0.22
			var sub := fmod(_phase * 0.5, 1.0)
			s += (4.0 * absf(sub - 0.5) - 1.0) * 0.10
			# short attack/decay envelope so notes are distinct
			var t := 1.0 - (_note_left / maxf(_note_len, 0.001))
			var env: float = clampf(t / 0.06, 0.0, 1.0) * (1.0 - 0.55 * t)
			s *= env
		_note_left -= 1.0 / RATE
		var v := s * vol
		_music_pb.push_frame(Vector2(v, v))


var _cur_freq := 0.0
var _note_len := 1.0


# =====================================================================
# sound effects
# =====================================================================

func sfx(kind: String) -> void:
	match kind:
		"cursor":  _push_sfx(880.0, 0.05, "sq", 0.25)
		"confirm": _push_sfx(660.0, 0.05, "sq", 0.3); _push_sfx(990.0, 0.07, "sq", 0.3)
		"cancel":  _push_sfx(330.0, 0.08, "sq", 0.25)
		"card":    _push_sfx(1200.0, 0.03, "noise", 0.2)
		"summon":  _push_sfx(220.0, 0.10, "saw", 0.35); _push_sfx(440.0, 0.12, "saw", 0.3)
		"attack":  _push_sfx(160.0, 0.09, "noise", 0.4); _push_sfx(90.0, 0.12, "saw", 0.35)
		"damage":  _push_sfx(120.0, 0.16, "noise", 0.4)
		"win":     for f in [523.0, 659.0, 784.0, 1046.0]: _push_sfx(f, 0.11, "sq", 0.3)
		"lose":    for f in [400.0, 330.0, 260.0, 180.0]: _push_sfx(f, 0.13, "sq", 0.3)
		"text":    _push_sfx(1500.0, 0.012, "sq", 0.10)
		"step":    _push_sfx(200.0, 0.02, "noise", 0.09)
		"open":    _push_sfx(700.0, 0.05, "sq", 0.25); _push_sfx(1050.0, 0.09, "sq", 0.25)


func _push_sfx(freq: float, secs: float, wave: String, vol: float) -> void:
	if _sfx_queue.size() < 24:
		_sfx_queue.append([freq, secs, wave, vol])


func _fill_sfx() -> void:
	var frames := _sfx_pb.get_frames_available()
	if frames <= 0:
		return
	var gvol: float = float(Game.settings.get("sfx", 0.8))
	for i in frames:
		if _sfx_left <= 0.0:
			if _sfx_queue.is_empty():
				_sfx_pb.push_frame(Vector2.ZERO)
				continue
			_sfx_cur = _sfx_queue.pop_front()
			_sfx_left = float(_sfx_cur[1])
			_sfx_len = _sfx_left
			_sfx_phase = 0.0
		var f := float(_sfx_cur[0])
		var wave := str(_sfx_cur[2])
		_sfx_phase += f / RATE
		if _sfx_phase >= 1.0:
			_sfx_phase -= 1.0
		var s := 0.0
		match wave:
			"sq":    s = 1.0 if _sfx_phase < 0.5 else -1.0
			"saw":   s = _sfx_phase * 2.0 - 1.0
			"noise": s = randf() * 2.0 - 1.0
			_:       s = sin(_sfx_phase * TAU)
		var t: float = 1.0 - (_sfx_left / maxf(_sfx_len, 0.001))
		s *= (1.0 - t) * float(_sfx_cur[3]) * gvol
		_sfx_left -= 1.0 / RATE
		_sfx_pb.push_frame(Vector2(s, s))


var _sfx_len := 1.0
