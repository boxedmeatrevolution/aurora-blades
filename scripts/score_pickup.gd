extends Node2D

onready var particle := $Particles2D
onready var particles_material := self.particle.process_material as ParticlesMaterial

func _ready():
	self.particle.emitting = true

func _process(delta):
	if !self.particle.emitting:
		queue_free()
