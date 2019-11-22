extends Area2D

onready var parent := self.get_parent()

export var points := 1

func death():
	var score_pickup = Scenes.ScorePickup.instance()
	score_pickup.global_position = self.global_position
	self.parent.remove_child(self)
	self.parent.add_child(score_pickup)

func spawn():
	self.parent.add_child(self.duplicate())
	queue_free()
