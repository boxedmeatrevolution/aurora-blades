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

const FLOOR_ANGLE := 40.0 * PI / 180.0
const SLOPE_ANGLE := 85.0 * PI / 180.0
const WALL_ANGLE := 100.0 * PI / 180.0

const GRAVITY := 800.0
const WALK_ACCELERATION := 700.0
const AIR_ACCELERATION := 700.0
const WALK_MAX_CONTROL_SPEED = 100.0
const AIR_MAX_CONTROL_SPEED = 100.0
const JUMP_SPEED := 300.0
const SURFACE_PADDING := 1.0

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

# The time for the player to re-land on the ground after a change in slope that
# is considered to small to be allowed by the physics engine.
func _max_surface_stick_time(state : int) -> float:
	return 0.2

# The maximum velocity which the player can move across the floor with.
func _max_speed(state : int) -> float:
	match state:
		State.STAND:
			return 150.0
		State.WALK:
			return 150.0
		State.SLIDE:
			return 200.0
		State.WALL_SLIDE:
			return 200.0
		State.SKATE:
			return 800.0
		_:
			return 1200.0

# The minimum speed at which the player cannot walk and starts sliding instead.
func _min_slide_speed(state : int) -> float:
	return 175.0

func _has_gravity(state : int) -> bool:
	match state:
		State.STAND:
			return false
		State.WALK:
			return false
		_:
			return true

# The friction (from air or ground) experienced by the player.
func _friction(state : int, speed : float) -> float:
	match state:
		State.STAND:
			return 800.0
		State.WALK:
			if speed <= self.WALK_MAX_CONTROL_SPEED:
				return 0.0
			else:
				return 800.0
		State.SLIDE:
			return 400.0
		State.WALL_SLIDE:
			return 400.0
		State.SKATE:
			return 200.0
		State.JUMP:
			return 50.0
		State.FALL:
			return 50.0
		_:
			return 0.0

func _ready() -> void:
	pass

func _position_process(delta : float, n : int = 4) -> void:
	# Exit if the maximum number of iterations has been reached.
	if n <= 0 || delta <= 0 || self.velocity.length_squared() == 0:
		return
	var delta_remainder := 0.0
	var found_new_surface := false
	var new_surface_normal := Vector2()
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
		delta_remainder = collision.remainder.length() / velocity.length()
		found_new_surface = true
		new_surface_normal = collision.normal
	elif _on_surface(self.physics_state) && collision == null:
		delta_remainder = 0.0
		# If the player used to be on a surface, then we should try to stick
		# to whatever surface may still be below them.
		if self.velocity.x != 0:
			var surface_stick_time := _max_surface_stick_time(self.state)
			var velocity_slope := self.velocity.y / self.velocity.x
			var max_slope_change := 0.5 * GRAVITY / self.velocity.x * surface_stick_time
			var extreme_slope := velocity_slope + max_slope_change
			var test_displacement := Vector2.DOWN * velocity.x * delta * max_slope_change
			var test_collision := move_and_collide(test_displacement, true, true, true)
			if test_collision != null && test_collision.normal.y < 0:
				# If a surface below the player was found, then check that the
				# slope is acceptably close to the slope of the previous slope
				# that the player was on.
				var surface_slope := test_collision.normal.x / abs(test_collision.normal.y)
				var surface_angle := test_collision.normal.angle_to(Vector2.UP)
				var slope_condition := false
				if self.velocity.x < 0:
					slope_condition = surface_slope >= extreme_slope
				else:
					slope_condition = surface_slope <= extreme_slope
				if abs(surface_angle) <= WALL_ANGLE && slope_condition:
					self.position += test_collision.travel
					found_new_surface = true
					new_surface_normal = test_collision.normal
					var velocity_tangent := self.velocity.slide(test_collision.normal)
					var velocity_normal := self.velocity.dot(test_collision.normal) * test_collision.normal
					self.velocity = velocity_tangent.normalized() * self.velocity.length()
	# If the player landed on a new surface, we need to adjust the state.
	if found_new_surface:
		# First, modify the velocity as the player moves onto the surface.
		var velocity_tangent := self.velocity.slide(new_surface_normal)
		var velocity_normal := self.velocity.dot(new_surface_normal) * new_surface_normal
		self.velocity = velocity_tangent
	# Before committing to the new surface, make sure that there isn't a
	# better choice of surface to be on by looking in the direction of the
	# last surface the player was on.
	if _on_surface(self.physics_state):
		var test_collision := move_and_collide(-self.surface_normal, true, true, true)
		if test_collision != null:
			var test_normal := test_collision.normal
			# Whichever surface is the more horizontal is the better choice.
			if !found_new_surface || test_normal.dot(Vector2.UP) > new_surface_normal.dot(Vector2.UP):
				self.position += test_collision.travel
				self.velocity = self.velocity.slide(test_collision.normal)
				found_new_surface = true
				new_surface_normal = test_normal
	if found_new_surface:
		var new_surface_angle := new_surface_normal.angle_to(Vector2.UP)
		self.surface_normal = new_surface_normal
		if abs(new_surface_angle) <= FLOOR_ANGLE:
			self.physics_state = PhysicsState.FLOOR
		elif abs(new_surface_angle) <= SLOPE_ANGLE:
			self.physics_state = PhysicsState.SLOPE
		elif abs(new_surface_angle) <= WALL_ANGLE:
			self.physics_state = PhysicsState.WALL
		else:
			self.physics_state = PhysicsState.AIR
	else:
		self.physics_state = PhysicsState.AIR
	_position_process(delta_remainder, n - 1)

var prev_state = State.FALL
var prev_physics_state = PhysicsState.AIR
func _physics_process(delta):
	# Print the state for debugging purposes.
	var state_str = ""
	var physics_state_str = ""
	match self.physics_state:
		PhysicsState.AIR:
			physics_state_str = "Air"
		PhysicsState.FLOOR:
			physics_state_str = "Floor"
		PhysicsState.WALL:
			physics_state_str = "Wall"
		PhysicsState.SLOPE:
			physics_state_str = "Slope"
	match self.state:
		State.STAND:
			state_str = "Stand"
		State.WALK:
			state_str = "Walk"
		State.SLIDE:
			state_str = "Slide"
		State.WALL_SLIDE:
			state_str = "WallSlide"
		State.SKATE:
			state_str = "Skate"
		State.JUMP:
			state_str = "Jump"
		State.FALL:
			state_str = "Fall"
		State.DASH:
			state_str = "Dash"
	if prev_state != self.state || prev_physics_state != self.physics_state:
		print(physics_state_str, ", ", state_str)
	prev_physics_state = self.physics_state
	prev_state = self.state
	
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
	if _has_gravity(self.state):
		self.velocity += Vector2.DOWN * GRAVITY * delta
	# Apply friction.
	if self.velocity.length_squared() != 0:
		var friction_delta = _friction(self.state, self.velocity.length()) * self.velocity.normalized() * delta
		if friction_delta.length_squared() > self.velocity.length_squared():
			self.velocity = Vector2()
		else:
			self.velocity -= friction_delta
	# Clamp the velocity by the max speed.
	self.velocity = self.velocity.clamped(_max_speed(self.state))
	
	# Step the position forward by the timestep.
	_position_process(delta)
	# Do transitions between the states.
	#_state_transition_process()
	
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
			else:
				var acceleration = input_move_dir.x * WALK_ACCELERATION * Vector2(-self.surface_normal.y, self.surface_normal.x)
				if self.velocity.dot(acceleration) <= WALK_MAX_CONTROL_SPEED * acceleration.length():
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
		if self.state == State.STAND || self.state == State.WALK || self.state == State.SLIDE || self.state == State.WALL_SLIDE || self.state == State.SKATE:
			self.state = State.FALL
		# Now, update the player based on the air state that they are in.
		if self.state == State.FALL:
			var acceleration = Vector2.RIGHT * input_move_dir.x * AIR_ACCELERATION
			if self.velocity.dot(acceleration) <= AIR_MAX_CONTROL_SPEED * acceleration.length():
				self.velocity += acceleration * delta
		elif self.state == State.JUMP:
			var acceleration = Vector2.RIGHT * input_move_dir.x * AIR_ACCELERATION
			if self.velocity.dot(acceleration) <= AIR_MAX_CONTROL_SPEED * acceleration.length():
				self.velocity += acceleration * delta
		pass
