class_name Player
extends Area2D

enum State { ORBITING, FLYING, DEAD }

@export var launch_speed: float = 1750.0
@export var base_orbit_speed: float = 3.6
@export var max_orbit_time: float = 3.0

var current_state: State = State.ORBITING
var current_planet: Planet = null
var last_planet: Planet = null
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
	if is_instance_valid(current_planet) and current_planet != planet:
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
	last_planet = null
	queue_redraw()

func launch() -> void:
	if current_state != State.ORBITING:
		return

	if is_instance_valid(current_planet):
		last_planet = current_planet
		current_planet.occupied = false
		current_planet.is_active_target = false
		current_planet.on_player_departed()
		current_planet = null

	current_state = State.FLYING
	var tangent_angle: float = orbit_angle + (PI / 2.0) * orbit_direction
	velocity = Vector2(cos(tangent_angle), sin(tangent_angle)) * launch_speed
	rotation = tangent_angle + PI / 2.0
	launched.emit()
	queue_redraw()

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

	var tangent_angle: float = orbit_angle + (PI / 2.0) * orbit_direction
	rotation = tangent_angle + PI / 2.0

func _process_flight(delta: float) -> void:
	var prev_position: Vector2 = global_position
	global_position += velocity * delta
	rotation = velocity.angle() + PI / 2.0

	_check_planet_captures(prev_position, global_position)

func _check_planet_captures(from_pos: Vector2, to_pos: Vector2) -> void:
	if current_state != State.FLYING:
		return

	var candidate_planets: Array[Node] = get_tree().get_nodes_in_group("Planets")
	var closest_planet: Planet = null
	var closest_dist_sq: float = INF

	for node in candidate_planets:
		var planet: Planet = node as Planet
		if not is_instance_valid(planet) or not planet.is_active_target or planet == last_planet:
			continue

		var p_center: Vector2 = planet.global_position
		var current_dist: float = to_pos.distance_to(p_center)
		if current_dist <= planet.capture_radius:
			var d_sq: float = from_pos.distance_squared_to(p_center)
			if d_sq < closest_dist_sq:
				closest_dist_sq = d_sq
				closest_planet = planet

	if closest_planet != null:
		_capture_planet(closest_planet)

func _capture_planet(target_planet: Planet) -> void:
	if current_state != State.FLYING:
		return

	# Calculate orbital entry direction via 2D cross product of radius and flight vector
	var to_player: Vector2 = global_position - target_planet.global_position
	var cross: float = to_player.cross(velocity)
	var new_dir: float = 1.0 if cross >= 0.0 else -1.0

	init_orbit(target_planet, new_dir)
	score_increased.emit(1)

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

func _on_area_entered(area: Area2
