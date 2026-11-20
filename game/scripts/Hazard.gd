class_name Hazard
extends Area2D

@export var radius: float = 26.0
@export var rotation_speed: float = 2.5
var points: PackedVector2Array = PackedVector2Array()

func _ready() -> void:
	add_to_group("Hazards")
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	# Generate jagged asteroid/mine vertices
	var spike_count: int = 8
	for i in range(spike_count * 2):
		var angle: float = (float(i) / float(spike_count * 2)) * TAU
		var dist: float = radius if (i % 2 == 0) else radius * 0.55
		dist += randf_range(-2.0, 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * dist)

func _process(delta: float) -> void:
	rotation += rotation_speed * delta

func _draw() -> void:
	if points.size() > 2:
		draw_colored_polygon(points, Color(0.95, 0.25, 0.25, 1.0))
		draw_polyline(points, Color(1.0, 0.6, 0.6, 1.0), 2.0)
