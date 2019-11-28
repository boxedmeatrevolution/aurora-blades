extends CanvasLayer

var score := 0
var seconds := 0
var minutes := 0
var deaths := 0

onready var score_text := $MarginContainer/PanelContainer/MarginContainer/GridContainer/ScoreText
onready var time_text := $MarginContainer/PanelContainer/MarginContainer/GridContainer/TimeText

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

func update_deaths() -> void:
	self.deaths += 1
