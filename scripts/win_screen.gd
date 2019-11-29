extends CanvasLayer

const UI := preload("res://scripts/ui.gd")

export var good_score := 0.0
export var good_time := 0.0
export var good_deaths := 0.0
# The distance between two grade levels.
export var power := 2.0

export var next_scene : PackedScene = null

onready var box := $CenterContainer
onready var score_text := $CenterContainer/PanelContainer/VBoxContainer/CenterContainer/GridContainer/ScoreText
onready var time_text := $CenterContainer/PanelContainer/VBoxContainer/CenterContainer/GridContainer/TimeText
onready var death_text := $CenterContainer/PanelContainer/VBoxContainer/CenterContainer/GridContainer/DeathText
onready var grade_text := $CenterContainer/PanelContainer/VBoxContainer/GradeText

func _ready() -> void:
	self.box.visible = false

func _continue_pressed() -> void:
	if self.next_scene != null:
		get_tree().change_scene_to(self.next_scene)

func activate() -> void:
	var ui := get_tree().get_root().find_node("UI", true, false) as UI
	var score := 0
	var time_seconds := 0
	var time_minutes := 0
	var deaths := 0
	if ui != null:
		score = ui.score
		time_seconds = ui.seconds
		time_minutes = ui.minutes
		deaths = ui.deaths
	var time := time_seconds + 60.0 * time_minutes
	self.score_text.text = str(score)
	self.time_text.text = "%02d:%02d" % [time_minutes, time_seconds]
	self.death_text.text = str(deaths)
	self.grade_text.text = "Grade: %s" % _calculate_grade(score, time, deaths)
	self.box.visible = true

func _calculate_grade(score : int, time : float, deaths : int) -> String:
	var score_part := max(log((self.good_score + 1.0) / (score + 1.0)) / log(power), 0.0)
	var time_part := max(log((time + 1.0) / (self.good_time + 1.0)) / log(power), 0.0)
	var deaths_part := max(log((deaths + 1.0) / (self.good_deaths + 1.0)) / log(power), 0.0)
	var grade := (score_part + time_part + deaths_part) / 3.0
	var grade_whole := floor(grade)
	var grade_fractional := grade - grade_whole
	var letter := "A"
	match int(grade_whole):
		0:
			letter = "A"
		1:
			letter = "B"
		2:
			letter = "C"
		_:
			letter = "D"
	if grade_fractional < 1.0 / 3.0:
		letter += "+"
	elif grade_fractional > 2.0 / 3.0:
		letter += "-"
	if grade == 0.0:
		letter = "S"
	return letter
