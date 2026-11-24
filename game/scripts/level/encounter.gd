class_name Encounter
extends Node2D
## One encounter: pre-placed enemies, an optional arena lock (talisman-light
## barriers), delayed spawns, the elite's summon, and clear detection.

signal started(enc)
signal cleared(enc)

const TYPES := {
	"grunt": preload("res://scripts/enemies/grunt.gd"),
	"crawler": preload("res://scripts/enemies/crawler.gd"),
	"husk": preload("res://scripts/enemies/husk.gd"),
	"spitter": preload("res://scripts/enemies/spitter.gd"),
	"elite": preload("res://scripts/enemies/elite.gd"),
}
const Barrier := preload("res://scripts/level/barrier.gd")

var data := {}
var state := "idle"     # idle | active | cleared
var alive: Array = []
var pending: Array = []  # [type, x, time_left, rise]
var barriers: Array = []
var boss: Node = null


func setup(d: Dictionary) -> void:
	data = d
	name = d.id
	if Game.cleared.has(d.id):
		state = "cleared"
		return
	for e in d.enemies:
		if e[2] < 0.0:
			_spawn(e[0], e[1], 0.0)


func reset() -> void:
	if data.get("boss", false) and state == "active" and Game.level and Game.level.has_method("resume_zone_music"):
		Game.level.resume_zone_music()
	# called on player respawn: undo a failed attempt
	for a in alive:
		if is_instance_valid(a):
			a.queue_free()
	alive.clear()
	pending.clear()
	for b in barriers:
		if is_instance_valid(b):
			b.queue_free()
	barriers.clear()
	boss = null
	if state != "cleared":
		state = "idle"
		for e in data.enemies:
			if e[2] < 0.0:
				_spawn(e[0], e[1], 0.0)


func _spawn(type: String, x: float, rise: float) -> Node:
	var en: Enemy = TYPES[type].new()
	en.spawn_rise = rise
	en.position = Vector2(x, _surface_y(x) - 2)
	if state == "active":
		en.aggro = true
		_leash(en)
	get_parent().get_node("Actors").add_child(en)
	en.died.connect(_on_died)
	alive.append(en)
	if type == "elite":
		boss = en
		en.summon_request.connect(_on_summon)
	if rise > 0.0:
		Sfx.play("spawn_rise", -6.0)
		Fx.particles(en.position, 16, Color(0.18, 0.16, 0.14, 0.8), 120.0, 60.0, Vector2.UP, -40.0, 1.0, 8.0)
	return en


## Top surface at x (ground or platform), so nothing spawns inside a ledge.
func _surface_y(x: float) -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, Game.GROUND_Y - 400.0), Vector2(x, Game.GROUND_Y + 50.0), 1)
	var res := space.intersect_ray(q)
	return res.position.y if res else Game.GROUND_Y


func _leash(en: Node) -> void:
	if data.lock.size() == 2:
		en.leash_left = data.lock[0] + 40.0
		en.leash_right = data.lock[1] - 40.0


func _physics_process(delta: float) -> void:
	if state == "cleared":
		return
	var p = Game.player
	if state == "idle":
		if data.trigger > 0.0 and p and not p.dead and p.global_position.x >= data.trigger:
			_start()
		elif data.trigger <= 0.0 and alive.is_empty():
			_clear()
		return
	if state == "active":
		for pd in pending:
			pd[2] -= delta
		var ready := pending.filter(func(pd): return pd[2] <= 0.0)
		for pd in ready:
			pending.erase(pd)
			_spawn(pd[0], pd[1], pd[3])
		if pending.is_empty() and alive.is_empty():
			_clear()


var _t_start := 0.0


func _start() -> void:
	state = "active"
	_t_start = Game.run_time
	for e in data.enemies:
		if e[2] >= 0.0:
			pending.append([e[0], e[1], e[2], e[3]])
	for en in alive:
		en.aggro = true
		_leash(en)
	if data.lock.size() == 2:
		for x in data.lock:
			var b := Barrier.new()
			b.position = Vector2(x, Game.GROUND_Y)
			get_parent().get_node("Props").add_child(b)
			barriers.append(b)
		Sfx.play("barrier_up", -2.0)
	if data.get("boss", false) and boss:
		Game.boss_changed.emit(boss)
		Sfx.play("stinger_boss", 0.0, 0.0)
		Sfx.play_music("music_boss", -7.0)
		boss.phase_changed.connect(func(_ph): Sfx.play_music("music_boss2", -6.0))
	started.emit(self)


func _on_died(en: Node) -> void:
	alive.erase(en)
	if data.get("boss", false) and en == boss and state == "active":
		# Banish any remaining summoned/companion grunts when the General falls
		# so the victory cinematic and encounter clear happen together.
		pending.clear()
		for other in alive.duplicate():
			if is_instance_valid(other) and not other.dead:
				other.hp = 0.0
				if other.has_method("_die"):
					other._die(0)
		alive.clear()
		_clear()


func _on_summon(count: int) -> void:
	var l: float = data.lock[0] + 80.0
	var r: float = data.lock[1] - 80.0
	for i in count:
		_spawn("grunt", l if i % 2 == 0 else r, 1.0)


func _clear() -> void:
	if state == "cleared":
		return
	if state == "active":
		Game.tel_enc(data.id, "time", Game.run_time - _t_start)
	state = "cleared"
	Game.cleared[data.id] = true
	for b in barriers:
		if is_instance_valid(b):
			b.dissolve()
	barriers.clear()
	if data.lock.size() == 2:
		Sfx.play("barrier_down", -2.0)
	if data.get("boss", false):
		Game.boss_changed.emit(null)
		if LevelData.WHISPERS.has("boss_sealed"):
			var w: Dictionary = LevelData.WHISPERS["boss_sealed"]
			get_tree().create_timer(3.6).timeout.connect(func():
				if is_instance_valid(self) and Game.running:
					Game.show_whisper("boss_sealed", String(w.mood), Game.t(String(w.speaker), "Wanderer · inner voice"), Game.loc(w), float(w.dur)))
		Sfx.play("stinger_victory", 0.0, 0.0)
		Sfx.stop_music()
		# The level owns this delay. Leaving for the ending or title cancels it.
		var music_delay := create_tween()
		music_delay.tween_interval(3.0)
		music_delay.tween_callback(Game.level.resume_zone_music)
	cleared.emit(self)


func locked_bounds() -> Array:
	return data.lock if state == "active" else []
