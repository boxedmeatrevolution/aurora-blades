extends Area2D

onready var sprite := $Sprite

func _ready():
	if self.sprite.visible:
		if Difficulty.difficulty == Difficulty.Difficulty.VERY_EASY:
			self.queue_free()
