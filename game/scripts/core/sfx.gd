extends Node
## Sound effect pool + music/ambience layers. Sounds are generated offline by
## tools/audio/make_audio.py into res://assets/audio/*.wav.

const POOL := 14
var _players: Array[AudioStreamPlayer] = []
var _cache := {}
var _next := 0
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music_name := ""
var muted := false
var _last_play := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	add_child(music)
	ambience = AudioStreamPlayer.new()
	ambience.volume_db = -14.0
	add_child(ambience)
	# master bus safety: soft compression + hard limiter so stacked hits never clip
	if AudioServer.get_bus_effect_count(0) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -12.0
		comp.ratio = 3.0
		comp.attack_us = 2000.0
		comp.release_ms = 120.0
		AudioServer.add_bus_effect(0, comp)
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(0, lim)
	if Game.args.has("mute"):
		AudioServer.set_bus_mute(0, true)


func _stream(name_: String) -> AudioStream:
	if _cache.has(name_):
		return _cache[name_]
	var path := "res://assets/audio/%s.wav" % name_
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	_cache[name_] = s
	return s


func play(name_: String, vol_db := 0.0, pitch_var := 0.08, pitch := 1.0) -> void:
	# de-duplicate the same sound within 30 ms (multi-hits)
	var now := Time.get_ticks_msec()
	if _last_play.get(name_, -1000) > now - 30:
		return
	_last_play[name_] = now
	var s := _stream(name_)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = s
	p.volume_db = vol_db - 3.0
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func play_music(name_: String, vol_db := -9.0) -> void:
	if name_ == music_name and music.playing:
		return
	music_name = name_
	var s := _stream(name_)
	if s == null:
		music.stop()
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / (4 if s.stereo else 2)
	_crossfade(music, s, vol_db)


func play_ambience(name_: String) -> void:
	var s := _stream(name_)
	if s == null:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / (4 if s.stereo else 2)
	if ambience.stream == s and ambience.playing:
		return
	_crossfade(ambience, s, -14.0)


func _crossfade(p: AudioStreamPlayer, s: AudioStream, vol_db: float) -> void:
	if not p.playing or p.stream == null:
		p.stream = s
		p.volume_db = -40.0
		p.play()
		create_tween().tween_property(p, "volume_db", vol_db, 1.2)
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, 0.9)
	tw.tween_callback(func(): p.stream = s; p.play())
	tw.tween_property(p, "volume_db", vol_db, 1.4)


func stop_music() -> void:
	music.stop()
	music_name = ""
