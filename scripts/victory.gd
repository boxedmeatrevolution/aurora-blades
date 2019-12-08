extends CanvasLayer

onready var button := $CenterContainer/VBoxContainer/Button

func _ready():
	Music.start_transition(Music.MUSIC_MAIN_MENU)
	button.grab_focus()

func _main_menu_pressed() -> void:
	get_tree().change_scene("res://levels/main_menu.tscn")
