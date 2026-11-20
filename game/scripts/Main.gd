class_name Main
extends Node2D

@onready var camera: Camera2D = $Camera2D
@onready var player: Player = $Player
@onready var spawner: PlanetSpawner = $PlanetSpawner
@onready var ui: UIManager = $UI
@onready var sound_manager: SoundManager = $SoundManager

# Camera Screen Shake
var shake_intensity: float = 0.0
var shake_decay: float = 8.0
var camera_base_offset: Vector2 = Vector2.ZERO

# Game loop variables
var current_score: int = 0
var best_score: int = 0
var combo_streak: int = 0
var is_game_active: bool = false
var save_path: String = "user://save.cfg"

# Background Starfield
var stars: Array[Vector3] = [] # x, y, size
const STAR_COUNT: int = 80
const VIEWPORT_WIDTH: float = 1080.0
const VIEWPORT_HEIGHT: float = 1920.0

func _ready() -> void:
	_init_starfield()
	_load_best_score()
	
	player.score_increased.connect(_on_score_increased)
	player.player_died.connect(_on_player_died)
	player.launched.connect(_on_player_launched)
	ui.restart_requested.connect(start_new_game)
	
	start_new_game()

func _init_starfield() -> void:
	stars.clear()
	for i in range(STAR_COUNT):
		stars.append(Vector3(
			randf_range(0.0, VIEWPORT_WIDTH),
			randf_range(-VIEWPORT_HEIGHT * 3.0, VIEWPORT_HEIGHT),
			randf_range(1.5, 4.0)
		))

func start_new_game() -> void:
	current_score = 0
	combo_streak = 0
	ui.update_score(0)
	ui.hide_game_over()
	
	# Reset Camera
	camera.global_position = Vector2(VIEWPORT_WIDTH * 0.5, VIEWPORT_HEIGHT * 0.5)
	
	# Setup initial planets
	var start_planet: Planet = spawner.setup_initial_planets()
	
	# Setup Player
	player.show()
	player.global_position = start_planet.global_position + Vector2(start_planet.orbit_radius, 0.0)
	player.init_orbit(start_planet, 1.0)
	
	is_game_active = true

func _process(delta: float) -> void:
	_handle_camera(delta)
	_handle_shake(delta)
	_check_out_of_bounds()
	queue_redraw()

func _handle_camera(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	# Follow player vertically (upwards only or smoothly when high)
	var target_y: float = player.global_position.y - 200.0
	if target_y < camera.global_position.y:
		camera.global_position.y = lerpf(camera.global_position.y, target_y, 7.5 * delta)
	
	# Spawner update based on camera position
	spawner.update_generation(camera.global_position.y, current_score)

func _handle_shake(delta: float) -> void:
	if shake_intensity > 0.0:
		shake_intensity = lerpf(shake_intensity, 0.0, shake_decay * delta)
		var shake_offset: Vector2 = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		camera.offset = camera_base_offset + shake_offset
	else:
		camera.offset = camera_base_offset

func apply_screen_shake(amount: float, decay: float = 8.0) -> void:
	shake_intensity = amount
	shake_decay = decay

func _check_out_of_bounds() -> void:
	if not is_game_active or player.current_state == Player.State.DEAD:
		return
		
	# Check if player drifted too far below the camera or outside view boundaries
	var lower_boundary: float = camera.global_position.y + (VIEWPORT_HEIGHT * 0.65)
	var left_boundary: float = -150.0
	var right_boundary: float = VIEWPORT_WIDTH + 150.0

	if player.global_position.y > lower_boundary or player.global_position.x < left_boundary or player.global_position.x > right_boundary:
		player.die()

func _on_player_launched() -> void:
	apply_screen_shake(4.5, 12.0)
	sound_manager.play_launch()

func _on_score_increased(points: int) -> void:
	current_score += points
	combo_streak += 1
	ui.update_score(current_score)
	apply_screen_shake(9.0, 10.0)
	sound_manager.play_capture(combo_streak)

	if combo_streak >= 3 and combo_streak % 2 == 1:
		ui.show_combo("COMBO x" + str(combo_streak) + "!")

	if current_score > best_score:
		best_score = current_score
		_save_best_score()

func _on_player_died() -> void:
	if not is_game_active:
		return
	is_game_active = false
	combo_streak = 0
	apply_screen_shake(26.0, 5.0)
	sound_manager.play_death()
	_spawn_death_particles(player.global_position)
	ui.show_game_over(current_score, best_score)

func _spawn_death_particles(pos: Vector2) -> void:
	var cp: CPUParticles2D = CPUParticles2D.new()
	cp.global_position = pos
	cp.emitting = true
	cp.one_shot = true
	cp.explosiveness = 1.0
	cp.amount = 32
	cp.lifetime = 0.8
	cp.spread = 180.0
	cp.gravity = Vector2(0, 180)
	cp.initial_velocity_min = 180.0
	cp.initial_velocity_max = 420.0
	cp.scale_amount_min = 4.0
	cp.scale_amount_max = 8.0
	cp.color = Color(1.0, 0.4, 0.2, 1.0)
	add_child(cp)
	
	# Self clean up particle node
	get_tree().create_timer(1.2).timeout.connect(cp.queue_free)

func _save_best_score() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("game", "best_score", best_score)
	config.save(save_path)

func _load_best_score() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(save_path) == OK:
		best_score = config.get_value("game", "best_score", 0)

func _draw() -> void:
	# Infinite parallax background stars relative to camera
	var cam_y: float = camera.global_position.y
	for s in stars:
		# Parallax wrap
		var screen_y: float = fposmod(s.y - (cam_y * 0.35), VIEWPORT_HEIGHT * 2.0) + (cam_y - VIEWPORT_HEIGHT)
		var star_color: Color = Color(0.85, 0.95, 1.0, clampf(s.z / 4.0, 0.3, 0.9))
		draw_circle(Vector2(s.x, screen_y), s.z * 0.6, star_color)
