extends "res://scripts/types/speech.gd"

const Speech := preload("res://scripts/types/speech.gd")

func _init():
	self.lines = [
		Speech.Line.new(self.PLAYER, "I don't want you to destroy the Earth!"),
		Speech.Line.new(self.BADDIE, "You won't be able to stop me in time! I have carefully constructed my doomsday machine so that you will have to cross thirty-one unique zones full of slippery slidey ice!"),
		Speech.Line.new(self.PLAYER, "Time for my skates of fury!")
	]
