extends CanvasLayer

signal done

const DifficultyScreenScene := preload("res://entities/ui/difficulty_screen.tscn")
const DifficultyScreen := preload("res://scripts/difficulty_screen.gd")

var difficulty_screen : DifficultyScreen = null
var level_str := ""

func _goto_level(index : int) -> void:
	if self.difficulty_screen == null:
		self.level_str = "res://levels/level%d.tscn" % index
		self.difficulty_screen = DifficultyScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.difficulty_screen)
		self.difficulty_screen.connect("done", self, "_difficulty_screen_done")

func _difficulty_screen_done() -> void:
	self.difficulty_screen.queue_free()
	self.difficulty_screen = null
	emit_signal("done")
	get_tree().change_scene(level_str)

func _back_pressed() -> void:
	emit_signal("done")
