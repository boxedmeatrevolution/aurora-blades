extends Node2D

enum State {
	WAIT,
	ACCELERATE,
	TRAVEL
}

const WAIT_TIME := 1.0
const ACCELERATION := 500.0
const MAX_SPEED := 1000.0

var player : Node = null
var respawn_parent : Node = self.get_parent()
export var respawn_location := Vector2.ZERO

var state : int = State.WAIT
var wait_timer := 0.0
var speed := 0.0

func init(player : Node, respawn_parent : Node, respawn_location : Vector2):
	self.player = player
	self.respawn_parent = respawn_parent
	self.respawn_location = respawn_location

func _ready():
	if self.respawn_parent == null:
		self.respawn_parent = self.get_parent()

func _process(delta):
	if self.state == State.WAIT:
		self.wait_timer += delta
		if self.wait_timer >= WAIT_TIME:
			self.state = State.ACCELERATE
	elif self.state == State.ACCELERATE:
		self.speed += delta * ACCELERATION
		if self.speed >= MAX_SPEED:
			self.state = State.TRAVEL
			self.speed = MAX_SPEED
	elif self.state == State.MAX_SPEED:
		self.speed = MAX_SPEED
	var displacement = self.respawn_location - self.position
	if displacement.length() <= 10.0:
		if self.state == State.ACCELERATE || self.state == State.TRAVEL:
			#self.respawn_parent.add_child(self.player)
			self.player.global_position = self.respawn_location
			self.player.spawn()
			queue_free()
	else:
		self.position += displacement.normalized() * self.speed * delta
