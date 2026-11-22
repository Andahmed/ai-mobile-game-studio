class_name Hazard
extends Area2D

@export var radius: float = 28.0
@export var rotation_speed: float = 2.4
var points: PackedVector2Array = PackedVector2Array()

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("Hazards")
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape

	var spike_count: int = 8
	for i in range(spike_count * 2):
		var angle: float = (float(i) / float(spike_count * 2)) * TAU
		var dist: float = radius if (i % 2 == 0) else radius * 0.52
		dist += randf_range(-2.0, 2.0)
		points.append(Vector2(cos(angle), sin(angle)) * dist)

func _process(delta: float) -> void:
	rotation += rotation_speed * delta
	queue_redraw()

func _draw() -> void:
	if points.size() > 2:
		draw_circle(Vector2.ZERO, radius * 1.25, Color(1.0, 0.2, 0.2, 0.15))
		draw_colored_polygon(points, Color(0.92, 0.22, 0.25, 1.0))
		draw_polyline(points, Color(1.0, 0.65, 0.65, 1.0), 2.5)
		draw_circle(Vector2.ZERO, radius * 0.25, Color(1.0, 0.9, 0.9, 0.9))
