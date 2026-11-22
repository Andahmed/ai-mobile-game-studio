class_name Planet
extends Area2D

@export var body_radius: float = 65.0
@export var orbit_radius: float = 145.0
@export var capture_radius: float = 195.0
@export var primary_color: Color = Color(0.2, 0.55, 0.95, 1.0)
@export var glow_color: Color = Color(0.15, 0.8, 1.0, 0.25)
@export var orbit_line_color: Color = Color(0.3, 0.7, 1.0, 0.35)

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
	tw.tween_property(self, "scale", Vector2(1.22, 0.84), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func on_player_departed() -> void:
	is_active_target = false
	occupied = false
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.32, 0.45)

func _draw() -> void:
	# Outer capture field
	var outer_alpha: float = 0.14 if is_active_target else 0.05
	draw_arc(Vector2.ZERO, capture_radius, 0.0, TAU, 52, Color(orbit_line_color.r, orbit_line_color.g, orbit_line_color.b, outer_alpha), 2.0)

	# Orbit trajectory ring
	var ring_alpha: float = 0.4 if is_active_target else 0.15
	draw_arc(Vector2.ZERO, orbit_radius, 0.0, TAU, 64, Color(orbit_line_color.r, orbit_line_color.g, orbit_line_color.b, ring_alpha), 2.5)

	# Anti-camping warning ring
	if occupied and collapse_progress > 0.0:
		var fill_angle: float = collapse_progress * TAU
		var warning_color: Color = Color(1.0, 0.25, 0.3, 0.9)
		draw_arc(Vector2.ZERO, orbit_radius + 5.0, -PI/2.0, -PI/2.0 + fill_angle, 48, warning_color, 5.0)

	# Atmospheric halo
	draw_circle(Vector2.ZERO, body_radius + 16.0, glow_color)

	# Planet core
	draw_circle(Vector2.ZERO, body_radius, primary_color)

	# Decorative crater details
	draw_circle(Vector2(-body_radius * 0.28, -body_radius * 0.28), body_radius * 0.26, primary_color.lightened(0.25))
	draw_circle(Vector2(body_radius * 0.32, body_radius * 0.28), body_radius * 0.18, primary_color.darkened(0.25))
