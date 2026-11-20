extends Node
## Sound effect pool + music/ambience layers. Sounds are generated offline by
## tools/audio/make_audio.py into res://assets/audio/*.wav.

const POOL := 14
const UI_POOL := 4
const FADE_FLOOR_DB := -50.0

var _players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _cache := {}
var _next := 0
var _ui_next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience_a: AudioStreamPlayer
var _ambience_b: AudioStreamPlayer
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music_name := ""
var _ambience_name := ""
var muted := false
var _last_play := {}
var _fades := {}
var _fade_gen := {}
var _next_fade_id := 0
var _shutting_down := false


static func ensure_bus(name_: String) -> int:
	var i := AudioServer.get_bus_index(name_)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, name_)
		AudioServer.set_bus_send(i, "Master")
	return i


static func _wav_loop_end(s: AudioStreamWAV) -> int:
	if s.format == AudioStreamWAV.FORMAT_16_BITS:
		return int(s.data.size() / (4 if s.stereo else 2))
	if s.format == AudioStreamWAV.FORMAT_8_BITS:
		return int(s.data.size() / (2 if s.stereo else 1))
	var by_length := int(round(s.get_length() * float(s.mix_rate)))
	if by_length > 0:
		return by_length
	return int(s.data.size() / (4 if s.stereo else 2))


static func _configure_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var wav := s as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = _wav_loop_end(wav)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_bus("Music")
	ensure_bus("SFX")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in UI_POOL:
		var up := AudioStreamPlayer.new()
		up.bus = "SFX"
		add_child(up)
		_ui_players.append(up)
	_music_a = _make_layer_player("Music", -9.0)
	_music_b = _make_layer_player("Music", FADE_FLOOR_DB)
	music = _music_a
	_ambience_a = _make_layer_player("SFX", -14.0)
	_ambience_b = _make_layer_player("SFX", FADE_FLOOR_DB)
	ambience = _ambience_a
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


func _make_layer_player(bus_name: String, initial_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.volume_db = initial_db
	add_child(p)
	return p


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
	if _shutting_down:
		return
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


func play_ui(name_: String, vol_db := -4.0, pitch_var := 0.02, pitch := 1.0) -> void:
	if _shutting_down or _ui_players.is_empty():
		return
	var now := Time.get_ticks_msec()
	var key := "ui:" + name_
	if _last_play.get(key, -1000) > now - 20:
		return
	_last_play[key] = now
	var s := _stream(name_)
	if s == null:
		return
	var p := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = s
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()


func play_music(name_: String, vol_db := -9.0, fade_s := 1.35) -> void:
	if _shutting_down:
		return
	if name_ == music_name and is_instance_valid(music) and music.playing:
		return
	music_name = name_
	var s := _stream(name_)
	if s == null:
		for p in [_music_a, _music_b]:
			if is_instance_valid(p):
				_kill_fade(p)
				p.stop()
		return
	_configure_loop(s)
	music = _crossfade_pair(_music_a, _music_b, music, s, vol_db, fade_s)


func play_ambience(name_: String, vol_db := -14.0, fade_s := 1.5) -> void:
	if _shutting_down:
		return
	var s := _stream(name_)
	if s == null:
		return
	_configure_loop(s)
	if is_instance_valid(ambience) and ambience.stream == s and ambience.playing and _ambience_name == name_:
		return
	_ambience_name = name_
	ambience = _crossfade_pair(_ambience_a, _ambience_b, ambience, s, vol_db, fade_s)


func _crossfade_pair(
	a: AudioStreamPlayer,
	b: AudioStreamPlayer,
	active: AudioStreamPlayer,
	s: AudioStream,
	vol_db: float,
	fade_s: float
) -> AudioStreamPlayer:
	var cur := active if is_instance_valid(active) else a
	if not cur.playing or cur.stream == null:
		_fade_in(cur, s, vol_db, fade_s)
		return cur
	var incoming := b if cur == a else a
	_fade_out_and_stop(cur, fade_s)
	_fade_in(incoming, s, vol_db, fade_s)
	return incoming


func _fade_in(p: AudioStreamPlayer, s: AudioStream, vol_db: float, fade_s: float) -> void:
	_kill_fade(p)
	if p.playing:
		p.stop()
	p.stream = s
	p.volume_db = FADE_FLOOR_DB
	p.play()
	var tw := _begin_fade(p)
	var gen: int = _fade_gen[p]
	tw.tween_property(p, "volume_db", vol_db, maxf(fade_s, 0.01)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if _fade_gen.get(p, -1) == gen:
			_fades.erase(p)
	)


func _fade_out_and_stop(p: AudioStreamPlayer, fade_s: float) -> void:
	var tw := _begin_fade(p)
	var gen: int = _fade_gen[p]
	tw.tween_property(p, "volume_db", FADE_FLOOR_DB, maxf(fade_s, 0.01)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if _shutting_down or not is_instance_valid(p):
			return
		if _fade_gen.get(p, -1) != gen:
			return
		_fades.erase(p)
		p.stop()
	)


func stop_music(fade_s := 1.2) -> void:
	if _shutting_down:
		return
	music_name = ""
	for p in [_music_a, _music_b]:
		if is_instance_valid(p) and p.playing:
			_fade_out_and_stop(p, fade_s)


func _kill_fade(p: AudioStreamPlayer) -> void:
	_next_fade_id += 1
	_fade_gen[p] = _next_fade_id
	if _fades.has(p):
		var old_tw = _fades[p]
		_fades.erase(p)
		if old_tw != null and is_instance_valid(old_tw):
			old_tw.kill()


func _begin_fade(p: AudioStreamPlayer) -> Tween:
	_kill_fade(p)
	_next_fade_id += 1
	_fade_gen[p] = _next_fade_id
	var tw := p.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fades[p] = tw
	return tw


func _exit_tree() -> void:
	shutdown()


func shutdown() -> void:
	_shutting_down = true
	for tw in _fades.values():
		if tw != null and is_instance_valid(tw):
			tw.kill()
	_fades.clear()
	_fade_gen.clear()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_cache.clear()
	_last_play.clear()
	music_name = ""
	_ambience_name = ""
