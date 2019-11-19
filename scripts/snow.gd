extends Particles2D

const PADDING_TOP := 16.0
const PADDING_HORIZONTAL_FACTOR := 2.0
const PARTICLE_DENSITY := 10.0 / 100.0

onready var viewport := get_viewport()

func _ready():
	var material : ParticlesMaterial = self.process_material
	var viewport_rect := self.viewport.get_visible_rect()
	var width := 0.5 * PADDING_HORIZONTAL_FACTOR * viewport_rect.size.x
	material.emission_shape = ParticlesMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(width, 0.0, 0.0)
	self.amount = width * PARTICLE_DENSITY
	_center_on_viewport()

func _process(delta):
	_center_on_viewport()

func _center_on_viewport():
	var viewport_rect := self.viewport.get_visible_rect()
	var viewport_center := self.get_canvas_transform().xform_inv(0.5 * viewport_rect.size) as Vector2
	self.position = viewport_center + (0.5 * viewport_rect.size.y + PADDING_TOP) * Vector2.UP
