extends CanvasLayer

const OptionsScreenScene := preload("res://entities/ui/options_screen.tscn")
const OptionsScreen := preload("res://scripts/options_screen.gd")

const LevelSelectScreenScene := preload("res://entities/ui/level_select_screen.tscn")
const LevelSelectScreen := preload("res://scripts/level_select_screen.gd")

var options_screen : OptionsScreen = null
var level_select_screen : LevelSelectScreen = null

func _start_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null:
		get_tree().change_scene("res://levels/level1.tscn")

func _level_select_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null:
		self.level_select_screen = LevelSelectScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.level_select_screen)
		self.level_select_screen.connect("done", self, "_level_select_screen_done")

func _level_select_screen_done() -> void:
	self.level_select_screen.queue_free()
	self.level_select_screen = null

func _options_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null:
		self.options_screen = OptionsScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.options_screen)
		self.options_screen.connect("done", self, "_options_screen_done")

func _options_screen_done() -> void:
	self.options_screen.queue_free()
	self.options_screen = null

func _exit_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null:
		get_tree().quit()
