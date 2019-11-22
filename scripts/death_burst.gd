extends Node2D

onready var particle := $Particles2D
onready var particles_material := self.particle.process_material as ParticlesMaterial

func burst():
	self.particle.emitting = true
