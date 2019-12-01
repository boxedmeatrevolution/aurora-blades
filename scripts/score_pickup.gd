extends Node2D

onready var particle := $Particles2D
onready var particles_material := self.particle.process_material as ParticlesMaterial
onready var pickup_audio := $PickupAudio

func _ready():
	self.particle.emitting = true
	self.pickup_audio.play()

func _process(delta):
	if !self.particle.emitting && !self.pickup_audio.playing:
		queue_free()
