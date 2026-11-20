class_name PlanetSpawner
extends Node2D

@export var planet_scene: PackedScene = preload("res://scenes/Planet.tscn")
@export var hazard_scene: PackedScene = preload("res://scenes/Hazard.tscn")

var spawned_planets: Array[Planet] = []
var spawned_hazards: Array[Hazard] = []
var highest_y: float = 0.0
var score_level: int = 0

const VIEWPORT_WIDTH: float = 1080.0
const MIN_Y_STEP: float = 430.0
const MAX_Y_STEP: float = 600.0
const CLEANUP_DISTANCE: float = 2400.0

var planet_colors: Array[Color] = [
	Color(0.2, 0.6, 0.98),
	Color(0.35, 0.85, 0.5),
	Color(0.95, 0.6, 0.2),
	Color(0.85, 0.35, 0.85),
	Color(0.25, 0.85, 0.9)
]

func setup_initial_planets() -> Planet:
	_clear_all()
	highest_y = 1350.0
	score_level = 0
	
	# Spawn first planet at centered position
	var start_planet: Planet = _spawn_planet_at(Vector2(VIEWPORT_WIDTH * 0.5, 1350.0), 0)
	start_planet.is_active_target = false # Player starts already in its orbit

	# Spawn initial ahead planets
	for i in range(5):
		_spawn_next_planet()

	return start_planet

func update_generation(cam_y: float, current_score: int) -> void:
	score_level = current_score
	
	# Generate ahead as player goes up (lower Y)
	while highest_y > cam_y - 2200.0:
		_spawn_next_planet()
		
	# Cleanup past entities
	_cleanup_passed_objects(cam_y)

func _spawn_next_planet() -> void:
	var y_step: float = randf_range(MIN_Y_STEP, MAX_Y_STEP)
	highest_y -= y_step

	var x_offset: float = randf_range(-300.0, 300.0)
	var x_pos: float = clampf((VIEWPORT_WIDTH * 0.5) + x_offset, 220.0, VIEWPORT_WIDTH - 220.0)
	
	var planet: Planet = _spawn_planet_at(Vector2(x_pos, highest_y), score_level)

	# Spawn hazard between planets if score is high enough
	if score_level >= 12 and randf() < 0.55:
		_spawn_hazard_between(planet.global_position.y + (y_step * 0.5))

func _spawn_planet_at(pos: Vector2, difficulty: int) -> Planet:
	var planet: Planet = planet_scene.instantiate() as Planet
	planet.global_position = pos
	
	# Difficulty modifiers
	if difficulty >= 20:
		planet.orbit_radius = randf_range(125.0, 145.0)
		planet.capture_radius = planet.orbit_radius + 40.0
	else:
		planet.orbit_radius = randf_range(140.0, 160.0)
		planet.capture_radius = planet.orbit_radius + 50.0

	planet.body_radius = planet.orbit_radius * 0.44

	# Color selection
	var color_idx: int = randi() % planet_colors.size()
	planet.primary_color = planet_colors[color_idx]
	planet.glow_color = Color(planet.primary_color.r, planet.primary_color.g, planet.primary_color.b, 0.25)

	# Moving planet mechanics at higher difficulty
	if difficulty >= 6 and randf() < 0.65:
		planet.move_amplitude = randf_range(90.0, 180.0)
		planet.move_frequency = randf_range(1.2, 2.2)

	add_child(planet)
	spawned_planets.append(planet)
	return planet

func _spawn_hazard_between(y_pos: float) -> void:
	var hazard: Hazard = hazard_scene.instantiate() as Hazard
	var x_pos: float = randf_range(280.0, VIEWPORT_WIDTH - 280.0)
	hazard.global_position = Vector2(x_pos, y_pos)
	hazard.rotation_speed = randf_range(-3.0, 3.0)
	add_child(hazard)
	spawned_hazards.append(hazard)

func _cleanup_passed_objects(cam_y: float) -> void:
	var threshold: float = cam_y + CLEANUP_DISTANCE

	# Cleanup planets
	var i: int = spawned_planets.size() - 1
	while i >= 0:
		var p: Planet = spawned_planets[i]
		if is_instance_valid(p) and p.global_position.y > threshold:
			spawned_planets.remove_at(i)
			p.queue_free()
		i -= 1

	# Cleanup hazards
	var j: int = spawned_hazards.size() - 1
	while j >= 0:
		var h: Hazard = spawned_hazards[j]
		if is_instance_valid(h) and h.global_position.y > threshold:
			spawned_hazards.remove_at(j)
			h.queue_free()
		j -= 1

func _clear_all() -> void:
	for p in spawned_planets:
		if is_instance_valid(p):
			p.queue_free()
	spawned_planets.clear()

	for h in spawned_hazards:
		if is_instance_valid(h):
			h.queue_free()
	spawned_hazards.clear()
