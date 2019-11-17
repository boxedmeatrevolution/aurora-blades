extends "res://scripts/types/speech.gd"

const Speech := preload("res://scripts/types/speech.gd")

func _init():
	self.lines = [
		Speech.Line.new(self.PLAYER, "I don't want you to destroy the Earth!"),
		Speech.Line.new(self.PLAYER, "Time for my skates of fury!")
	]
