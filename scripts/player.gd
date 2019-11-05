extends KinematicBody2D

# The allowed player states.
enum State {
	STAND,
	WALK,
	SLIDE,
	WALL_SLIDE,
	SKATE,
	JUMP,
	FALL,
	DASH
}

var state : int = State.FALL

# The allowed physics states. The physics states are semi-independent of the
# player states. They just refer to whether the player is in the air or moving
# along a surface of some kind.
enum PhysicsState {
	AIR,
	FLOOR,
	SLOPE,
	WALL
}

var physics_state : int = PhysicsState.AIR

const FLOOR_ANGLE := 45.0 * PI / 180.0
const SLOPE_ANGLE := 85.0 * PI / 180.0
const WALL_ANGLE := 95.0 * PI / 180.0

const GRAVITY := 300.0
const WALK_ACCELERATION := 400.0
const JUMP_SPEED := 200.0

# The normal to whatever surface the player is on.
var surface_normal := Vector2()
var velocity := Vector2()

func _on_surface(physics_state : int) -> bool:
	return physics_state == PhysicsState.FLOOR \
		|| physics_state == PhysicsState.SLOPE \
		|| physics_state == PhysicsState.WALL

# The maximum angle over which the player's velocity will be redirected without
# loss when undergoing a velocity change.
func _max_surface_redirect_angle(state : int) -> float:
	return 45.0 * PI / 180.0

# The maximum change in slope over which the player will "stick" to the
# surface.
func _max_surface_stick_slope(state : int) -> float:
	# This should depend on the player state, and potentially the velocity.
	return 0.5

# The maximum velocity which the player can move across the floor with.
func _max_speed(state : int) -> float:
	if state == State.STAND:
		return 100.0
	elif state == State.WALK:
		return 100.0
	elif state == State.SLIDE:
		return 300.0
	elif state == State.WALL_SLIDE:
		return 300.0
	elif state == State.SKATE:
		return 800.0
	else:
		return 1200.0

# The minimum speed at which the player cannot walk and starts sliding instead.
func _min_slide_speed(state : int) -> float:
	return 150.0

# The friction (from air or ground) experienced by the player.
func _friction(state : int) -> float:
	if state == State.STAND:
		return 400.0
	elif state == State.SLIDE:
		return 200.0
	elif state == State.WALL_SLIDE:
		return 200.0
	elif state == State.SKATE:
		return 100.0
	elif state == State.JUMP || state == State.FALL:
		return 30.0
	else:
		return 0.0

func _ready() -> void:
	pass

func _position_process(delta : float, n : int = 4) -> void:
	# Exit if the maximum number of iterations has been reached.
	if n <= 0 || delta <= 0 || self.velocity.length_squared() == 0:
		return
	# Handles a single update of the velocity by an amount `delta`.
	var collision := move_and_collide(self.velocity * delta)
	# There are four possibilities that need to be handled:
	# * Player was in air and did not hit anything.
	#   * Don't do anything.
	# * Player was in air and hit a surface.
	#   * Update the physics state and redirect velocity along surface.
	# * Player was on surface and hit a surface.
	#   * Same as previous case.
	# * Player was on surface and did not hit anything.
	#   * Evaluate whether we should stick to the surface that we just left.
	if collision != null:
		var delta_remainder := collision.remainder.length() / velocity.length()
		var velocity_tangent := self.velocity.slide(collision.normal)
		var velocity_normal := self.velocity.dot(collision.normal) * collision.normal
		var surface_velocity_normal := collision.collider_velocity.dot(collision.normal)
		# Determine with what kind of object the player collided.
		# TODO: If the player collides with a wall but they were on a floor,
		# then we must somehow ensure that they have not left the floor.
		var surface_angle := collision.normal.angle_to(Vector2.UP)
		if surface_angle <= FLOOR_ANGLE:
			self.physics_state = PhysicsState.FLOOR
		elif surface_angle <= SLOPE_ANGLE:
			self.physics_state = PhysicsState.SLOPE
		elif surface_angle <= WALL_ANGLE:
			self.physics_state = PhysicsState.WALL
		else:
			self.physics_state = PhysicsState.AIR
		self.surface_normal = collision.normal
		self.velocity = velocity_tangent
		_position_process(delta_remainder, n - 1)
	elif _on_surface(self.physics_state) && collision == null:
		self.physics_state = PhysicsState.AIR
		# If the player used to be on a surface, then we should try to stick
		# to whatever surface may still be below them.
		if self.velocity.x != 0:
			var velocity_slope := self.velocity.y / abs(self.velocity.x)
			var max_slope_change := _max_surface_stick_slope(self.state)
			var min_slope := velocity_slope - max_slope_change
			var test_displacement := Vector2.DOWN * abs(velocity.x) * delta * max_slope_change
			var test_collision := move_and_collide(test_displacement, true, true, false)
			if test_collision != null && test_collision.normal.y < 0:
				# If a surface below the player was found, then check that the
				# slope is acceptably close to the slope of the previous slope
				# that the player was on.
				var surface_slope := sign(self.velocity.x) * test_collision.normal.x / test_collision.normal.y
				var surface_angle := test_collision.normal.angle_to(Vector2.UP)
				if surface_angle <= WALL_ANGLE && surface_slope >= min_slope:
					self.position += test_collision.travel
					var velocity_tangent := self.velocity.slide(test_collision.normal)
					var velocity_normal := self.velocity.dot(test_collision.normal) * test_collision.normal
					if surface_angle <= FLOOR_ANGLE:
						self.physics_state = PhysicsState.FLOOR
					elif surface_angle <= SLOPE_ANGLE:
						self.physics_state = PhysicsState.SLOPE
					else:
						self.physics_state = PhysicsState.WALL
					self.surface_normal = test_collision.normal
					self.velocity = velocity_tangent.normalized() * self.velocity.length()

func _physics_process(delta):
	var input_move_dir := Vector2()
	var input_jump := false
	var input_dash := false
	var input_skate := false
	if Input.is_action_pressed("move_left"):
		input_move_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_move_dir.x += 1
	if Input.is_action_pressed("move_up"):
		input_move_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_move_dir.y += 1
	if Input.is_action_just_released("jump"):
		input_jump = true
	if Input.is_action_just_pressed("dash"):
		input_dash = true
	if Input.is_action_just_pressed("skate"):
		input_skate = true
	
	# Apply gravity.
	self.velocity += Vector2.DOWN * GRAVITY * delta
	# Apply friction.
	if self.velocity.length_squared() != 0:
		var friction_delta = _friction(self.state) * self.velocity.normalized() * delta
		if friction_delta.length_squared() > self.velocity.length_squared():
			self.velocity = Vector2()
		else:
			self.velocity -= friction_delta
	# Clamp the velocity by the max speed.
	self.velocity = self.velocity.clamped(_max_speed(self.state))
	
	# Step the position forward by the timestep.
	_position_process(delta)
	
	# Update the player state from the current physics state.
	if _on_surface(self.physics_state):
		# If the player was in an air state, then make a transition into a
		# surface state.
		if self.state == State.FALL || self.state == State.JUMP:
			if false:
				# If the skate button is held down and velocity conditions are met,
				# then enter the skate state directly.
				self.state = State.SKATE
			elif self.physics_state == PhysicsState.FLOOR:
				# If the player landed on the floor, enter either the standing,
				# walking, or sliding state (depending on velocity and input).
				if self.velocity.length() >= _min_slide_speed(self.state):
					self.state = State.SLIDE
				elif input_move_dir.x != 0:
					self.state = State.WALK
				else:
					self.state = State.STAND
			elif self.physics_state == PhysicsState.SLOPE:
				# If landing on a slope, then just slide down it.
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
		# Now, update the player based on the surface state that they are in.
		if self.state == State.STAND:
			if input_jump:
				self.state = State.JUMP
				self.velocity += Vector2.UP * JUMP_SPEED
			elif self.velocity.length() >= _min_slide_speed(self.state):
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.SLOPE:
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
			elif input_move_dir.x != 0:
				self.state = State.WALK
		elif self.state == State.WALK:
			if input_jump:
				self.state = State.JUMP
				self.velocity += Vector2.UP * JUMP_SPEED
			elif self.velocity.length() >= _min_slide_speed(self.state):
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.SLOPE:
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
			elif input_move_dir.x == 0:
				self.state = State.STAND
			var acceleration = input_move_dir.x * WALK_ACCELERATION * Vector2(-self.surface_normal.y, self.surface_normal.x)
			self.velocity += acceleration * delta
		elif self.state == State.SLIDE:
			if self.physics_state == PhysicsState.FLOOR:
				if input_move_dir.x != 0 && self.velocity.length() <= _max_speed(State.WALK):
					self.state = State.WALK
				elif self.velocity.length() <= _max_speed(State.STAND):
					self.state = State.STAND
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
		elif self.state == State.WALL_SLIDE:
			if self.physics_state == PhysicsState.FLOOR:
				if input_move_dir.x != 0 && self.velocity.length() <= _max_speed(State.WALK):
					self.state = State.WALK
				elif self.velocity.length() <= _max_speed(State.STAND):
					self.state = State.STAND
				else:
					self.state = State.SLIDE
			elif self.physics_state == PhysicsState.SLOPE:
				self.state = State.SLIDE
	else:
		# If the player was in a surface state, then they probably walked off
		# an edge, so put them into the fall state.
		if self.state == State.STAND || self.state == State.WALK || self.state == State.SLIDE || self.state == State.SKATE:
			self.state = State.FALL
		# Now, update the player based on the air state that they are in.
		pass
