extends CanvasLayer

signal done(success)

const DifficultyScreenScene := preload("res://entities/ui/difficulty_screen.tscn")
const DifficultyScreen := preload("res://scripts/difficulty_screen.gd")

var difficulty_screen : DifficultyScreen = null
var level_str := ""

onready var level1_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/Level1

onready var button_container := $CenterContainer/PanelContainer/VBoxContainer/GridContainer
var buttons := []
var index := 0

func _ready():
	for button in self.button_container.get_children():
		self.buttons.push_back(button)
	self.buttons[0].grab_focus()

func _process(delta) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_back_pressed()

func _goto_level(index : int) -> void:
	if self.difficulty_screen == null:
		self.index = index
		self.level_str = "res://levels/level%d.tscn" % index
		self.difficulty_screen = DifficultyScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.difficulty_screen)
		self.difficulty_screen.connect("done", self, "_difficulty_screen_done")

func _difficulty_screen_done(success) -> void:
	self.difficulty_screen.queue_free()
	self.difficulty_screen = null
	if success:
		emit_signal("done", true)
		get_tree().change_scene(level_str)
	else:
		self.buttons[self.index - 1].grab_focus()

func _back_pressed() -> void:
	emit_signal("done", false)
