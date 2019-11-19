extends Node2D

onready var particle := $Particle2D
onready var particles_material := self.particle.process_material as ParticlesMaterial

func _ready():
	self.particle.emitting = false

func set_emitting(emitting : bool, velocity : float = 0.0) -> void:
	if emitting && !self.particle.emitting:
		self.particle.emitting = true
		self.particles_material.initial_velocity = 150.0 + velocity
	if !emitting && self.particle.emitting:
		self.particle.emitting = false
