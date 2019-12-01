extends Area2D

onready var animation_player := $Sprite/AnimationPlayer
onready var activate_audio := $ActivateAudio

func _ready():
	self.animation_player.play("CheckpointInactive")

func activate():
	self.animation_player.play("CheckpointActive")
	self.activate_audio.play()

func deactivate():
	self.animation_player.play("CheckpointInactive")
