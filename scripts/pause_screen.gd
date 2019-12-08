extends CanvasLayer

const OptionsScreenScene := preload("res://entities/ui/options_screen.tscn")
const OptionsScreen := preload("res://scripts/options_screen.gd")

signal done

onready var box := $CenterContainer
onready var resume_button := $CenterContainer/PanelContainer/VBoxContainer/ResumeButton
onready var restart_button := $CenterContainer/PanelContainer/VBoxContainer/RestartButton
onready var options_button := $CenterContainer/PanelContainer/VBoxContainer/OptionsButton
onready var main_menu_button := $CenterContainer/PanelContainer/VBoxContainer/MainMenuButton

var options_screen : OptionsScreen = null

func _ready() -> void:
	self.resume_button.grab_focus()

func _process(delta) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_resume_pressed()

func _resume_pressed() -> void:
	if self.options_screen == null:
		emit_signal("done")

func _restart_pressed() -> void:
	if self.options_screen == null:
		emit_signal("done")
		get_tree().reload_current_scene()

func _options_pressed() -> void:
	if self.options_screen == null:
		self.options_screen = OptionsScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.options_screen)
		self.options_screen.connect("done", self, "_options_screen_done")

func _options_screen_done(success) -> void:
	self.options_screen.queue_free()
	self.options_screen = null
	self.options_button.grab_focus()

func _main_menu_pressed() -> void:
	if self.options_screen == null:
		emit_signal("done")
		get_tree().change_scene("res://levels/main_menu.tscn")
