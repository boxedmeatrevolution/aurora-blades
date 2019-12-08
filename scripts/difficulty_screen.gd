extends CanvasLayer

signal done(success)

onready var very_easy_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/VeryEasyButton
onready var easy_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/EasyButton
onready var medium_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/MediumButton
onready var hard_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/HardButton

func _ready():
	self.medium_button.grab_focus()

func _process(delta) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_back_pressed()

func _very_easy_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.VERY_EASY
	emit_signal("done", true)

func _easy_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.EASY
	emit_signal("done", true)

func _medium_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.MEDIUM
	emit_signal("done", true)

func _hard_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.HARD
	emit_signal("done", true)

func _back_pressed() -> void:
	emit_signal("done", false)
