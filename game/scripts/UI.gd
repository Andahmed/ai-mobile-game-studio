class_name UIManager
extends CanvasLayer

signal restart_requested

@onready var score_label: Label = $HUDMargin/TopBox/ScoreLabel
@onready var combo_label: Label = $HUDMargin/TopBox/ComboLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var final_score_label: Label = $GameOverPanel/Center/VBox/FinalScoreLabel
@onready var best_score_label: Label = $GameOverPanel/Center/VBox/BestScoreLabel
@onready var restart_button: Button = $GameOverPanel/RestartButton

var can_restart: bool = false

func _ready() -> void:
	game_over_panel.visible = false
	game_over_panel.modulate = Color(1, 1, 1, 0)
	restart_button.pressed.connect(_on_restart_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if can_restart and event.is_action_pressed("tap"):
		_on_restart_pressed()

func update_score(score: int) -> void:
	score_label.text = str(score)
	var tw: Tween = create_tween()
	tw.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.06).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(score_label, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD)

func show_combo(text: String) -> void:
	combo_label.text = text
	var tw: Tween = create_tween()
	tw.tween_property(combo_label, "modulate:a", 1.0, 0.08)
	tw.tween_property(combo_label, "scale", Vector2(1.15, 1.15), 0.1)
	tw.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(0.4)
	tw.tween_property(combo_label, "modulate:a", 0.0, 0.25)

func show_game_over(final_score: int, best_score: int) -> void:
	final_score_label.text = "SCORE: " + str(final_score)
	best_score_label.text = "BEST: " + str(best_score)
	game_over_panel.visible = true
	
	var tw: Tween = create_tween()
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.25)
	tw.tween_callback(func() -> void: can_restart = true)

func hide_game_over() -> void:
	can_restart = false
	game_over_panel.visible = false
	game_over_panel.modulate = Color(1, 1, 1, 0)

func _on_restart_pressed() -> void:
	if can_restart:
		can_restart = false
		restart_requested.emit()
