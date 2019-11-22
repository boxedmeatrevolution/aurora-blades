extends Node2D

enum State {
	WAIT,
	ACCELERATE,
	TRAVEL
}

const DAMPING := 1000.0
const WAIT_TIME := 0.6
const ACCELERATION := 800.0
const MAX_SPEED := 1200.0

var object : Node = null
export var respawn_location := Vector2.ZERO

var state : int = State.WAIT
var wait_timer := 0.0
var speed := 0.0
var initial_velocity := Vector2.ZERO

func init(object : Node, respawn_location : Vector2):
	self.object = object
	self.respawn_location = respawn_location

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
			self.state = State.ACCELERATE
	elif self.state == State.ACCELERATE:
		self.speed += delta * ACCELERATION
		if self.speed >= MAX_SPEED:
			self.state = State.TRAVEL
			self.speed = MAX_SPEED
	elif self.state == MAX_SPEED:
		self.speed = MAX_SPEED
	var displacement = self.respawn_location - self.position
	if displacement.length() <= 10.0:
		if self.state == State.ACCELERATE || self.state == State.TRAVEL:
			self.object.spawn()
			self.object.global_position = self.respawn_location
			queue_free()
	else:
		self.position += displacement.normalized() * self.speed * delta
