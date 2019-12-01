extends CanvasLayer

const PauseScreenScene := preload("res://entities/ui/pause_screen.tscn")
const PauseScreen := preload("res://scripts/pause_screen.gd")

const WinScreenScene := preload("res://entities/ui/win_screen.tscn")
const WinScreen := preload("res://scripts/win_screen.gd")

var score := 0
var seconds := 0
var minutes := 0
var deaths := 0

export var next_level : String = ""
export var good_score := 0.0
export var good_time := 0.0
export var good_deaths := 0.0
export var power := 1.2

onready var score_text := $MarginContainer/PanelContainer/GridContainer/ScoreText
onready var time_text := $MarginContainer/PanelContainer/GridContainer/TimeText

var pause_screen : PauseScreen = null
var win_screen : WinScreen = null

func _ready() -> void:
	Music.start_transition(Music.MUSIC_GAME)

func _process(delta) -> void:
	if Input.is_action_just_pressed("ui_pause"):
		if self.pause_screen == null && self.win_screen == null:
			self.pause_screen = PauseScreenScene.instance()
			self.get_parent().add_child_below_node(self, self.pause_screen)
			self.pause_screen.connect("done", self, "_pause_screen_done")
			get_tree().paused = true

func _pause_screen_done() -> void:
	self.pause_screen.queue_free()
	self.pause_screen = null
	get_tree().paused = false

func show_win_screen() -> void:
	if self.win_screen == null && self.pause_screen == null:
		Music.start_transition(Music.MUSIC_END)
		self.win_screen = WinScreenScene.instance()
		self.get_parent().add_child_below_node(self, self.win_screen)
		self.win_screen.init(self.score, self.minutes, self.seconds, self.deaths, _calculate_grade())
		self.win_screen.connect("done", self, "_win_screen_done")
		get_tree().paused = true

func _win_screen_done() -> void:
	self.win_screen.queue_free()
	self.win_screen = null
	get_tree().paused = false
	get_tree().change_scene(self.next_level)

func _calculate_grade() -> float:
	var time := self.minutes * 60.0 + self.seconds * 1.0
	var score_part := max(log((self.good_score + 1.0) / (self.score + 1.0)) / log(self.power), 0.0)
	var time_part := max(log((time + 1.0) / (self.good_time + 1.0)) / log(self.power), 0.0)
	var deaths_part := max(log((self.deaths + 1.0) / (self.good_deaths + 1.0)) / log(self.power), 0.0)
	var grade := (score_part + time_part + deaths_part) / 3.0
	print("Score part:  ", score_part)
	print("Time part:   ", time_part)
	print("Deaths part: ", deaths_part)
	return grade

func update_score(score_delta : float) -> void:
	self.score += score_delta
	self.score_text.text = str(self.score)

func update_timer() -> void:
	self.seconds += 1
	if self.seconds >= 60:
		self.seconds = 0
		self.minutes += 1
	if self.minutes >= 60:
		self.minutes = 59
		self.seconds = 59
	self.time_text.text = "%02d:%02d" % [self.minutes, self.seconds]

func update_deaths(a, b) -> void:
	self.deaths += 1
