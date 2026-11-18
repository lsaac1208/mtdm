extends Node
## Rect-based hit resolution between attack boxes and hurtboxes.
##
## All boxes are axis-aligned world rects. Actors use a bottom-centre (feet)
## origin, so "height above ground" is simply feet_y - rect_y. This is what
## makes the high/low band rules from the design spec (§2.2) literal geometry:
## a horizontal slash spanning 55–145 px above the feet passes over the
## 46 px tall crawler hurtbox without any special-case code.

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

signal struck(attacker, target, info)

var actors: Array = []
var debug_draw := false
var recent_boxes: Array = []   # [{rect, color, t}] for the debug overlay


func register(a: Node) -> void:
	if not actors.has(a):
		actors.append(a)


func unregister(a: Node) -> void:
	actors.erase(a)


func enemies_alive() -> Array:
	var out := []
	for a in actors:
		if a.team == TEAM_ENEMY and not a.dead:
			out.append(a)
	return out


## atk keys: owner, team, rect (Rect2 world), damage, poise, knock (Vector2,
## x is signed by dir), dir (int), kind ("melee"|"projectile"|"aoe"|"hazard"),
## unblockable (bool), tag (String), centre (Vector2, for aoe direction)
## `hit_set` collects actors already hit by this swing so each swing hits once.
func strike(atk: Dictionary, hit_set: Dictionary) -> Array:
	var hits := []
	var r: Rect2 = atk.rect
	if debug_draw:
		recent_boxes.append({"rect": r, "color": Color(1, 0.2, 0.1, 0.35), "t": 0.12})
	for a in actors.duplicate():
		if not is_instance_valid(a) or a.dead or a.team == atk.team:
			continue
		if hit_set.has(a):
			continue
		if not a.is_hittable():
			continue
		if a.get_hurtbox().intersects(r):
			hit_set[a] = true
			var info: Dictionary = a.receive_hit(atk)
			hits.append(a)
			struck.emit(atk.get("owner"), a, info)
	return hits


func _process(delta: float) -> void:
	if recent_boxes.is_empty():
		return
	for b in recent_boxes:
		b.t -= delta
	recent_boxes = recent_boxes.filter(func(b): return b.t > 0.0)
