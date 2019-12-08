extends CanvasLayer

signal done(success)

onready var button := $CenterContainer/PanelContainer/VBoxContainer/Button

func _ready() -> void:
	self.button.grab_focus()

func _back_pressed() -> void:
	emit_signal("done", true)
