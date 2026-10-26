extends Node2D
## Game scene root: owns World host, wires player death, window focus pause.

func _ready() -> void:
	InputRouter.set_mode(InputRouter.Mode.WORLD)
	HUD.show_all()
	await get_tree().process_frame
	await MapMan.load_game_into_world()
	if MapMan.player != null and is_instance_valid(MapMan.player):
		MapMan.player.player_died.connect(_on_player_died)
	_apply_window_settings()

func _apply_window_settings() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if bool(GameState.settings.get("fullscreen", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_player_died() -> void:
	GameOverUI.show_death()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if InputRouter.mode() == InputRouter.Mode.WORLD and not get_tree().paused:
			PauseMenu.open_ui()
