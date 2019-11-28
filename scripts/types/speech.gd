# This type stores all of the information about a session of dialogue.
extends Object

class Actor:
	var name := ""
	var portrait : StreamTexture = null
	func _init(name : String, portrait : StreamTexture):
		self.name = name
		self.portrait = portrait

class Line:
	var actor : Actor = null
	var speech := ""
	func _init(actor : Actor, speech : String):
		self.actor = actor
		self.speech = speech

var PLAYER := Actor.new("Player", preload("res://sprites/ui/portrait_player.png"))
var BADDIE := Actor.new("Baddie", preload("res://sprites/ui/portrait_player.png"))

export var lines := []
