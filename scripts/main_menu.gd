extends CanvasLayer

const OptionsScreenScene := preload("res://entities/ui/options_screen.tscn")
const OptionsScreen := preload("res://scripts/options_screen.gd")

const LevelSelectScreenScene := preload("res://entities/ui/level_select_screen.tscn")
const LevelSelectScreen := preload("res://scripts/level_select_screen.gd")

const DifficultyScreenScene := preload("res://entities/ui/difficulty_screen.tscn")
const DifficultyScreen := preload("res://scripts/difficulty_screen.gd")

const CreditsScreenScene := preload("res://entities/ui/credits_screen.tscn")
const CreditsScreen := preload("res://scripts/credits_screen.gd")

onready var start_button := $MarginContainer/VBoxContainer/StartButton
onready var level_select_button := $MarginContainer/VBoxContainer/LevelSelectButton
onready var options_button := $MarginContainer/VBoxContainer/OptionsButton
onready var credits_button := $MarginContainer/VBoxContainer/CreditsButton
onready var exit_button := $MarginContainer/VBoxContainer/ExitButton

var options_screen : OptionsScreen = null
var level_select_screen : LevelSelectScreen = null
var difficulty_screen : DifficultyScreen = null
var credits_screen : CreditsScreen = null

func _ready() -> void:
	Music.start_transition(Music.MUSIC_MAIN_MENU)
	self.start_button.grab_focus()

func _start_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null && self.difficulty_screen == null && self.credits_screen == null:
		self.difficulty_screen = DifficultyScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.difficulty_screen)
		self.difficulty_screen.connect("done", self, "_difficulty_screen_done")

func _difficulty_screen_done(success) -> void:
	self.difficulty_screen.queue_free()
	self.difficulty_screen = null
	self.start_button.grab_focus()
	if success:
		get_tree().change_scene("res://levels/level1.tscn")

func _level_select_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null && self.difficulty_screen == null && self.credits_screen == null:
		self.level_select_screen = LevelSelectScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.level_select_screen)
		self.level_select_screen.connect("done", self, "_level_select_screen_done")

func _level_select_screen_done(success) -> void:
	self.level_select_screen.queue_free()
	self.level_select_screen = null
	self.level_select_button.grab_focus()

func _options_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null && self.difficulty_screen == null && self.credits_screen == null:
		self.options_screen = OptionsScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.options_screen)
		self.options_screen.connect("done", self, "_options_screen_done")

func _options_screen_done(success) -> void:
	self.options_screen.queue_free()
	self.options_screen = null
	self.options_button.grab_focus()

func _credits_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null && self.difficulty_screen == null && self.credits_screen == null:
		self.credits_screen = CreditsScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.credits_screen)
		self.credits_screen.connect("done", self, "_credits_screen_done")

func _credits_screen_done(success) -> void:
	self.credits_screen.queue_free()
	self.credits_screen = null
	self.credits_button.grab_focus()

func _exit_pressed() -> void:
	if self.options_screen == null && self.level_select_screen == null && self.difficulty_screen == null && self.credits_screen == null:
		get_tree().quit()
