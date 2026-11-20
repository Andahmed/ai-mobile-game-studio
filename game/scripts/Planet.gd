class_name Planet
extends Area2D

@export var body_radius: float = 65.0
@export var orbit_radius: float = 145.0
@export var capture_radius: float = 190.0
@export var primary_color: Color = Color(0.2, 0.55, 0.95, 1.0)
@export var glow_color: Color = Color(0.15, 0.8, 1.0, 0.25)
@export var orbit_line_color: Color = Color(0.3, 0.7, 1.0, 0.3)

var is_active_target: bool = true
var time_alive: float = 0.0
var move_amplitude: float = 0.0
var move_frequency: float = 1.0
var initial_x: float = 0.0

var occupied: bool = false
var collapse_progress: float = 0.0
var max_orbit_time: float = 3.0
var current_orbit_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("Planets")
	initial_x = global_position.x
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = capture_radius
	collision_shape.shape = circle_shape

func _process(delta: float) -> void:
	time_alive += delta
	if move_amplitude > 0.0:
		global_position.x = initial_x + sin(time_alive * move_frequency) * move_amplitude

	if occupied:
		current_orbit_timer += delta
		collapse_progress = clampf(current_orbit_timer / max_orbit_time, 0.0, 1.0)
		queue_redraw()
	elif collapse_progress > 0.0:
		collapse_progress = 0.0
		current_orbit_timer = 0.0
		queue_redraw()

func pulse_on_capture() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2(1.18, 0.86), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	# Capture gravitational ring
	draw_arc(Vector2.ZERO, capture_radius, 0.0, TAU, 48, Color(orbit_line_color.r, orbit_line_color.g, orbit_line_color.b, 0.15), 2.0)
	
	# Orbit trajectory ring
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 56, orbit_line_color, 2.5)

	# Anti-camping timer ring indicator
	if occupied and collapse_progress > 0.0:
		var fill_angle: float = collapse_progress * TAU
		draw_arc(Vector2.ZERO, orbit_radius + 6.0, -PI/2.0, -PI/2.0 + fill_angle, 40, Color(1.0, 0.25, 0.35, 0.85), 5.0)

	# Planet core atmosphere glow
	draw_circle(Vector2.ZERO, body_radius + 16.0, glow_color)
	
	# Planet core
	draw_circle(Vector2.ZERO, body_radius, primary_color)
	
	# Inner decorative crater/detail
	draw_circle(Vector2(-body_radius * 0.25, -body_radius * 0.25), body_radius * 0.28, primary_color.lightened(0.25))
	draw_circle(Vector2(body_radius * 0.3, body_radius * 0.28), body_radius * 0.18, primary_color.darkened(0.25))
