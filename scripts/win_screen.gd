extends CanvasLayer

signal done

onready var box := $CenterContainer
onready var score_text := $CenterContainer/PanelContainer/VBoxContainer/CenterContainer/GridContainer/ScoreText
onready var time_text := $CenterContainer/PanelContainer/VBoxContainer/CenterContainer/GridContainer/TimeText
onready var death_text := $CenterContainer/PanelContainer/VBoxContainer/CenterContainer/GridContainer/DeathText
onready var grade_text := $CenterContainer/PanelContainer/VBoxContainer/GradeText

func _ready() -> void:
	self.box.visible = false

func _continue_pressed() -> void:
	emit_signal("done")

func init(score : int, time_minutes : int, time_seconds : int, deaths : int, grade : float) -> void:
	self.score_text.text = str(score)
	self.time_text.text = "%02d:%02d" % [time_minutes, time_seconds]
	self.death_text.text = str(deaths)
	self.grade_text.text = "Grade: %s" % _format_grade(grade)
	self.box.visible = true

func _format_grade(grade : float) -> String:
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
	if grade_fractional < 1.0 / 3.0 && grade_whole <= 3:
		letter += "+"
	if grade_fractional > 2.0 / 3.0 || grade_whole > 3:
		letter += "-"
	if grade == 0.0:
		letter = "S"
	return letter
