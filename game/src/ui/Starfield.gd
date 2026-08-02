extends Node2D
## Slow drifting specks used behind menus.

var _stars: Array = []   # [pos, speed, brightness]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20020101
	for _i in 60:
		_stars.append([
			Vector2(rng.randf_range(0, 480), rng.randf_range(0, 270)),
			rng.randf_range(2.0, 9.0),
			rng.randf_range(0.25, 0.85),
		])
	set_process(true)


func _process(delta: float) -> void:
	for s in _stars:
		s[0].x -= s[1] * delta
		if s[0].x < -2:
			s[0].x += 484
	queue_redraw()


func _draw() -> void:
	for s in _stars:
		var b: float = s[2]
		draw_rect(Rect2(s[0].floor(), Vector2.ONE), Color(0.75, 0.82, 1.0, b))
