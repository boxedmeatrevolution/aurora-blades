extends Node2D

enum State {
	WAIT,
	TRAVEL
}

const DAMPING := 1000.0
const WAIT_TIME := 0.8
const TRAVEL_TIME_MAX := 2.5
const TRAVEL_TIME_MIN := 1.0
const TRAVEL_AVERAGE_SPEED := 400.0

var object : Node = null
export var respawn_location := Vector2.ZERO
var initial_position := Vector2.ZERO

var state : int = State.WAIT
var wait_timer := 0.0
var travel_timer := 0.0
var travel_time := 0.0
var velocity := Vector2.ZERO
var initial_velocity := Vector2.ZERO

func init(object : Node, respawn_location : Vector2, with_image := true):
	self.object = object
	self.respawn_location = respawn_location
	if !with_image:
		$Sprite.visible = false

func _process(delta : float):
	if self.state == State.WAIT:
		self.position += self.initial_velocity * delta
		var delta_velocity := DAMPING * delta
		if delta_velocity < self.initial_velocity.length():
			self.initial_velocity -= delta_velocity * self.initial_velocity.normalized()
		else:
			self.initial_velocity = Vector2.ZERO
		self.wait_timer += delta
		if self.wait_timer >= WAIT_TIME:
			self.state = State.TRAVEL
			self.initial_position = self.global_position
			self.travel_time = (self.respawn_location - self.initial_position).length() / TRAVEL_AVERAGE_SPEED
			self.travel_time = clamp(self.travel_time, TRAVEL_TIME_MIN, TRAVEL_TIME_MAX)
	elif self.state == State.TRAVEL:
		self.travel_timer += delta
		var travel_fraction := self.travel_timer / self.travel_time
		if travel_fraction >= 1.0:
			self.object.spawn()
			self.object.global_position = self.respawn_location
			queue_free()
		else:
			var displacement := self.respawn_location - self.initial_position
			if displacement.length_squared() != 0.0:
				self.global_position = self.initial_position + displacement * 0.5 * (1.0 - cos(PI * travel_fraction))
				self.velocity = Vector2.ZERO
