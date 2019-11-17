extends CanvasLayer

const Speech := preload("res://scripts/types/speech.gd")

signal dialogue_start
signal dialogue_end

onready var viewport := self.get_viewport()
onready var camera := self.viewport.get_camera()
onready var box := $Box
onready var portrait := $Box/PanelContainer/HBoxContainer/MarginContainer/CenterContainer/Portrait
onready var name_label := $Box/PanelContainer/HBoxContainer/MarginContainer2/VBoxContainer/Name
onready var speech_label := $Box/PanelContainer/HBoxContainer/MarginContainer2/VBoxContainer/Speech

export(Array, GDScript) var speech_generators := []

var speech : Speech = null
var line_index := 0
var active := false

func _activate():
	if !self.active:
		self.line_index = 0
		if _update_dialogue_box():
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

func _play(index : int) -> void:
	var speech_generator := self.speech_generators[index] as GDScript
	self.speech = null
	if speech_generator != null:
		var speech_object := speech_generator.new()
		if speech_object is Speech:
			self.speech = speech_object
	if self.speech == null:
		printerr("Couldn't load speech ", index)
	else:
		_activate()

func _update_dialogue_box() -> bool:
	if self.line_index < 0 || self.line_index >= self.speech.lines.size():
		return false
	var line := self.speech.lines[self.line_index] as Speech.Line
	if line == null:
		printerr("Couldn't read line ", self.line_index, " from speech.")
		return false
	else:
		var actor := line.actor
		var speech := line.speech
		self.portrait.texture = actor.portrait
		self.name_label.text = actor.name
		self.speech_label.text = line.speech
		return true

func _process(delta):
	if self.active:
		if Input.is_action_just_pressed("ui_accept"):
			self.line_index += 1
			if !_update_dialogue_box():
				_deactivate()
	else:
		if Input.is_action_just_pressed("ui_focus_next"):
			_play(0)
