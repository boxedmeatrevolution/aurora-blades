extends Area2D

onready var animation_player := $Sprite/AnimationPlayer

func _ready():
	self.animation_player.play("CheckpointInactive")

func activate():
	self.animation_player.play("CheckpointActive")

func deactivate():
	self.animation_player.play("CheckpointInactive")
