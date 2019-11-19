extends Node2D

# TODO: Make particle effects change as the player moves faster?
onready var particle := $Particles2D
onready var particles_material := self.particle.process_material as ParticlesMaterial

func _ready():
	self.particle.emitting = false

func set_emitting(emitting : bool) -> void:
	if emitting && !self.particle.emitting:
		self.particle.emitting = true
	if !emitting && self.particle.emitting:
		self.particle.emitting = false
