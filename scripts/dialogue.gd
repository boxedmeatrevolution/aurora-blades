extends CanvasLayer

const Speech := preload("res://scripts/types/speech.gd")

signal dialogue_start
signal dialogue_end

onready var box := $Box
onready var portrait := $Box/PanelContainer/HBoxContainer/MarginContainer/CenterContainer/Portrait
onready var name_label := $Box/PanelContainer/HBoxContainer/MarginContainer2/VBoxContainer/Name
onready var speech_label := $Box/PanelContainer/HBoxContainer/MarginContainer2/VBoxContainer/Speech

export(Array, GDScript) var speech_generators := []

var current_speech : Speech = null
var line_index := 0
var current_line : Speech.Line = null
var scroll_speed := 2
var line_finished := false
var active := false

func _activate():
	if !self.active:
		self.line_index = -1
		if _update_dialogue_box_line():
			self.active = true
			self.box.visible = true
			emit_signal("dialogue_start")
		else:
			_deactivate()

func _deactivate():
	if self.active:
		emit_signal("dialogue_end")
		self.active = false
		self.box.visible = false

func _ready():
	self.active = false
	self.box.visible = false

func play(index : int) -> void:
	var speech_generator := self.speech_generators[index] as GDScript
	self.current_speech = null
	if speech_generator != null:
		var speech_object := speech_generator.new()
		if speech_object is Speech:
			self.current_speech = speech_object
	if self.current_speech == null:
		printerr("Couldn't load current_speech ", index)
	else:
		_activate()

func _update_dialogue_box_line() -> bool:
	self.line_index += 1
	if self.line_index < 0 || self.line_index >= self.current_speech.lines.size():
		return false
	self.current_line = self.current_speech.lines[self.line_index] as Speech.Line
	if self.current_line == null:
		printerr("Couldn't read line ", self.line_index, " from current_speech.")
		return false
	else:
		self.scroll_speed = 1
		self.line_finished = false
		var actor := self.current_line.actor
		self.portrait.texture = actor.portrait
		self.name_label.text = actor.name
		self.speech_label.text = ""
		return true

func _update_dialogue_box_char() -> bool:
	var current_str : String = self.speech_label.text
	var diff := self.current_line.speech.length() - current_str.length()
	var finished := true
	if diff > self.scroll_speed:
		diff = self.scroll_speed
		finished = false
	var next_str := self.current_line.speech.substr(current_str.length(), diff)
	self.speech_label.text = str(current_str, next_str)
	return finished

func _process(delta):
	if self.active:
		if Input.is_action_just_pressed("ui_accept"):
			if self.line_finished:
				if !_update_dialogue_box_line():
					_deactivate()
			else:
				self.scroll_speed = 4
		if _update_dialogue_box_char():
			self.line_finished = true
	else:
		if Input.is_action_just_pressed("ui_focus_next"):
			play(0)
