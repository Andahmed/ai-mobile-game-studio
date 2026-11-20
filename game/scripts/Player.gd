class_name Player
extends Area2D

enum State { ORBITING, FLYING, DEAD }

@export var launch_speed: float = 1750.0
@export var base_orbit_speed: float = 3.6
@export var max_orbit_time: float = 3.0

var current_state: State = State.ORBITING
var current_planet: Planet = null
var orbit_angle: float = 0.0
var orbit_direction: float = 1.0
var orbit_radius: float = 140.0
var velocity: Vector2 = Vector2.ZERO
var orbit_timer: float = 0.0

var trail_points: Array[Vector2] = []
var max_trail_points: int = 16

signal score_increased(points: int)
signal player_died
signal launched

@onready var trail_line: Line2D = $TrailLine

func _ready() -> void:
	add_to_group("Player")
	area_entered.connect(_on_area_entered)
	_setup_trail()

func _setup_trail() -> void:
	if trail_line:
		trail_line.top_level = true
		trail_line.width = 12.0
		var curve: Curve = Curve.new()
		curve.add_point(Vector2(0.0, 0.1))
		curve.add_point(Vector2(1.0, 1.0))
		trail_line.width_curve = curve
		var grad: Gradient = Gradient.new()
		grad.colors = PackedColorArray([Color(0.2, 0.8, 1.0, 0.0), Color(0.3, 0.95, 1.0, 0.85)])
		trail_line.gradient = grad

func _unhandled_input(event: InputEvent) -> void:
	if current_state != State.ORBITING:
		return
	if event.is_action_pressed("tap"):
		launch()

func init_orbit(planet: Planet, direction: float = 1.0) -> void:
	if is_instance_valid(current_planet):
		current_planet.occupied = false
	current_planet = planet
	current_planet.occupied = true
	current_planet.max_orbit_time = max_orbit_time
	current_planet.pulse_on_capture()

	orbit_direction = direction
	orbit_radius = planet.orbit_radius
	orbit_angle = (global_position - planet.global_position).angle()
	orbit_timer = 0.0
	current_state = State.ORBITING
	velocity = Vector2.ZERO

func launch() -> void:
	if current_state != State.ORBITING:
		return
	if is_instance_valid(current_planet):
		current_planet.occupied = false

	current_state = State.FLYING
	var tangent_angle: float = orbit_angle + (PI / 2.0) * orbit_direction
	velocity = Vector2(cos(tangent_angle), sin(tangent_angle)) * launch_speed
	rotation = tangent_angle + PI / 2.0
	current_planet = null
	launched.emit()

func _process(delta: float) -> void:
	match current_state:
		State.ORBITING:
			_process_orbit(delta)
		State.FLYING:
			_process_flight(delta)
		State.DEAD:
			pass

	_update_trail()

func _process_orbit(delta: float) -> void:
	if not is_instance_valid(current_planet):
		die()
		return

	orbit_timer += delta
	if orbit_timer >= max_orbit_time:
		die()
		return

	orbit_angle += base_orbit_speed * orbit_direction * delta
	global_position = current_planet.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_radius
	
	# Align sprite facing tangent direction
	var tangent_angle: float = orbit_angle + (PI / 2.0) * orbit_direction
	rotation = tangent_angle + PI / 2.0

func _process_flight(delta: float) -> void:
	global_position += velocity * delta
	rotation = velocity.angle() + PI / 2.0

func _update_trail() -> void:
	if not trail_line:
		return
	if current_state == State.DEAD:
		trail_line.clear_points()
		return
	
	trail_points.push_front(global_position)
	if trail_points.size() > max_trail_points:
		trail_points.pop_back()

	trail_line.clear_points()
	for pt in trail_points:
		trail_line.add_point(pt)

func _on_area_entered(area: Area2D) -> void:
	if current_state != State.FLYING:
		return

	if area.is_in_group("Planets"):
		var target_planet: Planet = area as Planet
		if target_planet and target_planet.is_active_target:
			# Reverse orbit direction for dynamic feel
			var new_direction: float = -orbit_direction
			init_orbit(target_planet, new_direction)
			score_increased.emit(1)
	elif area.is_in_group("Hazards"):
		die()

func die() -> void:
	if current_state == State.DEAD:
		return
	current_state = State.DEAD
	if is_instance_valid(current_planet):
		current_planet.occupied = false
	if trail_line:
		trail_line.clear_points()
	player_died.emit()
	hide()

func _draw() -> void:
	# Rocket/satellite geometric ship shape pointing upwards (rotated by node)
	var body_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, -22),    # Nose
		Vector2(14, 16),    # Right fin
		Vector2(0, 8),      # Engine bay
		Vector2(-14, 16)    # Left fin
	])
	draw_colored_polygon(body_points, Color(0.95, 0.98, 1.0, 1.0))
	draw_polyline(body_points, Color(0.2, 0.8, 1.0, 1.0), 2.5)
	
	# Cockpit / power core
	draw_circle(Vector2(0, -2), 5.0, Color(0.2, 0.9, 1.0, 1.0))
	
	# Engine flame when flying
	if current_state == State.FLYING:
		var flame: PackedVector2Array = PackedVector2Array([
			Vector2(-6, 12),
			Vector2(0, 26 + randf_range(-4, 4)),
			Vector2(6, 12)
		])
		draw_colored_polygon(flame, Color(1.0, 0.55, 0.1, 0.9))
