extends KinematicBody2D

# Things that need to be done:
# * Allow wall-jumps and moving away from a wall-slide.
# * Allow jumping with forward momentum from a slope-slide.
# * Skating.
# * Some kind of ballistic arial system. Some thoughts on this:
#   * If the player is moving fast enough, they enter a "ballistic" state
#     where they can no longer accelerate as usual in the air.
#   * Instead, pressing arrow keys tangent to their direction of motion will
#     slightly adjust their angle.
#   * Pressing arrow keys backwards from the direction of motion will slow down
#     the player. If slowed down enough, enters normal arial movement.
#   * The ballistic state can allow for redirection by dashes and well-timed
#     wall-jumps.
#   * The ballistic state allows for the skating state to be entered directly
#     at high speed upon landing.

# The allowed player states.
enum State {
	STAND,
	WALK,
	SLIDE,
	WALL_SLIDE,
	SKATE_START,
	SKATE,
	JUMP_START,
	JUMP,
	FALL,
	DASH
}
const STATE_NAME := {
	State.STAND: "Stand",
	State.WALK: "Walk",
	State.SLIDE: "Slide",
	State.WALL_SLIDE: "WallSlide",
	State.SKATE_START: "SkateStart",
	State.SKATE: "Skate",
	State.JUMP_START: "JumpStart",
	State.JUMP: "Jump",
	State.FALL: "Fall",
	State.DASH: "Dash"
}

# The allowed physics states. The physics states are semi-independent of the
# player states. They just refer to whether the player is in the air or moving
# along a surface of some kind.
enum PhysicsState {
	AIR,
	FLOOR,
	SLOPE,
	WALL
}
const PHYSICS_STATE_NAME := {
	PhysicsState.AIR: "Air",
	PhysicsState.FLOOR: "Floor",
	PhysicsState.SLOPE: "Slope",
	PhysicsState.WALL: "Wall"
}

# Represents what the player wants to do.
class Intent:
	var move_direction := Vector2()
	var jump := false
	var dash := false
	var skate_start := false
	var skate_boost := false

const FLOOR_ANGLE := 40.0 * PI / 180.0
const SLOPE_ANGLE := 85.0 * PI / 180.0
const WALL_ANGLE := 100.0 * PI / 180.0

# If the player would land on the ground in this amount of time after leaving
# the ground, then don't bother letting the player leave the ground at all.
const SURFACE_DROP_TIME := 0.2
# If the player is registered as leaving a surface, but the surface remains
# within this distance of the player, then don't let the player leave the
# surface.
const SURFACE_PADDING := 1.0

const MAX_SPEED := 1000.0
const GRAVITY := 800.0

const WALK_ACCELERATION := 700.0
const WALK_SPEED := 100.0
# Maximum speed before entering a slide.
const WALK_MAX_SPEED := 125.0

const SLIDE_ACCELERATION := 600.0
const SLIDE_SPEED := 150.0
# Minimum speed before entering a walk.
const SLIDE_MIN_SPEED := 100.0

# Initial speed when entering the skate state.
const SKATE_LAUNCH_SPEED := 150.0
# Maximum speed gain when getting a perfect boost.
const SKATE_BOOST_MAX_SPEED := 80.0
const SKATE_BOOST_MIN_SPEED := 20.0
const SKATE_MIN_SPEED := 100.0
const SKATE_MAX_SPEED := 1000.0
const SKATE_FRICTION := 60.0
# Friction when going over the max speed.
const SKATE_MAX_FRICTION := 140.0
const SKATE_GRAVITY := 100.0
const SKATE_BOOST_MIN_TIME := 0.25
const SKATE_BOOST_MAX_TIME := 0.50

const WALL_SLIDE_ACCELERATION := 600.0
const WALL_SLIDE_SPEED := 100.0

const JUMP_LAUNCH_SPEED := 300.0
const AIR_ACCELERATION := 700.0
const AIR_FRICTION := 100.0
const AIR_CONTROL_SPEED := 100.0

var state : int = State.FALL
var physics_state : int = PhysicsState.AIR
# The normal to the surface the player is on (only valid if `_on_surface`
# returns true).
var surface_normal := Vector2()
var velocity := Vector2()
var facing_direction := -1
var skate_boost_timer := 0.0

onready var animation_player := $Sprite/AnimationPlayer

# Is the player on a surface, meaning on a floor, slope, or wall?
func _on_surface() -> bool:
	return self.physics_state == PhysicsState.FLOOR \
			|| self.physics_state == PhysicsState.SLOPE \
			|| self.physics_state == PhysicsState.WALL

# "Surface states" are those player states which are meant to be compatible
# with the player moving on a surface. If the player is in one of these states,
# then a call to `_on_surface` must return true (but the converse is not
# necessarily true).
func _is_surface_state(state : int) -> bool:
	return state == State.STAND \
			|| state == State.WALK \
			|| state == State.SLIDE \
			|| state == State.WALL_SLIDE \
			|| state == State.SKATE_START \
			|| state == State.SKATE \
			|| state == State.JUMP_START

# The maximum angle over which the player's velocity will be redirected without
# loss when undergoing a velocity change.
# TODO: Actually use this physics concept.
func _max_surface_redirect_angle() -> float:
	return 45.0 * PI / 180.0

func _ready() -> void:
	pass

var prev_state : int = State.FALL
var prev_physics_state : int = PhysicsState.AIR
func _physics_process(delta):
	# Print the state for debugging purposes.
	if prev_state != self.state || prev_physics_state != self.physics_state:
		print(PHYSICS_STATE_NAME[self.physics_state], ", ", STATE_NAME[self.state])
	prev_physics_state = self.physics_state
	prev_state = self.state
	
	var intent := _read_intent()
	if intent.move_direction.x != 0 && (self.state == State.STAND || self.state == State.WALK):
		self.facing_direction = intent.move_direction.x
	# Update the velocities based on the current state.
	_state_process(delta, intent)
	# Step the position forward by the timestep.
	_position_process(delta)
	# Transition between states.
	_state_transition(intent)
	# Update the animation based on the state.
	_animation_transition(intent)

func _read_intent() -> Intent:
	var intent := Intent.new()
	# Get input from the user.
	# TODO: Perhaps some of these should be conditional depending on the
	# current state. For example, pressing the skate button means to start
	# skating when you are on the ground, but to boost when already skating.
	if Input.is_action_pressed("move_left"):
		intent.move_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		intent.move_direction.x += 1
	if Input.is_action_pressed("move_up"):
		intent.move_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		intent.move_direction.y += 1
	if Input.is_action_just_pressed("jump"):
		intent.jump = true
	if Input.is_action_just_pressed("dash"):
		intent.dash = true
	if Input.is_action_just_pressed("skate"):
		intent.skate_boost = true
	if (!self._is_surface_state(self.state) && Input.is_action_pressed("skate")) || Input.is_action_just_pressed("skate"):
		intent.skate_start = true
	return intent

# Updates the velocities based on the current state.
func _state_process(delta : float, intent : Intent) -> void:
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	# Any acceleration parallel to the surface which the player is on.
	var surface_acceleration := 0.0
	# Any acceleration against the direction of the velocity of the player.
	var drag := 0.0
	
	if self.state == State.STAND:
		# When the player is standing, they should slow down to a stop. We use
		# the walk acceleration here so that it blends nicely with ceasing to
		# walk.
		drag = WALK_ACCELERATION
	elif self.state == State.WALK:
		# When the player is walking, we must accelerate them up to speed in
		# the direction they have chosen to move.
		if self.velocity.length() > WALK_SPEED:
			drag = WALK_ACCELERATION
		else:
			surface_acceleration = intent.move_direction.x * WALK_ACCELERATION
	elif self.state == State.SLIDE:
		# When the player is sliding, they will speed up to reach the sliding
		# speed, and then maintain that speed. If they slide onto a floor
		# region, they will slow down to a stop.
		if self.physics_state == PhysicsState.FLOOR:
			drag = SLIDE_ACCELERATION
		elif self.physics_state == PhysicsState.SLOPE || self.physics_state == PhysicsState.WALL:
			if self.velocity.length() > SLIDE_SPEED:
				drag = SLIDE_ACCELERATION
			else:
				surface_acceleration = sign(self.surface_normal.x) * SLIDE_ACCELERATION
	elif self.state == State.WALL_SLIDE:
		# Similar to regular sliding.
		if self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE:
			drag = WALL_SLIDE_ACCELERATION
		elif self.physics_state == PhysicsState.WALL:
			if self.velocity.length() > WALL_SLIDE_SPEED:
				drag = WALL_SLIDE_ACCELERATION
			else:
				surface_acceleration = sign(self.surface_normal.x) * WALL_SLIDE_ACCELERATION
	elif self.state == State.SKATE_START:
		var skate_direction := intent.move_direction.x
		if skate_direction == 0:
			skate_direction = self.facing_direction
		self.velocity = skate_direction * surface_tangent * SKATE_LAUNCH_SPEED
		self.skate_boost_timer = 0.0
	elif self.state == State.SKATE:
		# Update the boost timer. If you boost too early, you wipe out. If you
		# boost too late, it doesn't do very much.
		self.skate_boost_timer += delta
		if intent.skate_boost:
			if self.skate_boost_timer < SKATE_BOOST_MIN_TIME:
				print("Wipeout!")
			else:
				var skate_direction := sign(self.velocity.dot(surface_tangent))
				var boost_fraction := clamp((SKATE_BOOST_MAX_TIME - self.skate_boost_timer) / (SKATE_BOOST_MAX_TIME - SKATE_BOOST_MIN_TIME), 0.0, 1.0)
				var boost := SKATE_BOOST_MIN_SPEED * boost_fraction + SKATE_BOOST_MAX_SPEED * (1.0 - boost_fraction)
				self.velocity += skate_direction * surface_tangent * boost
				self.skate_boost_timer = 0.0
		# Apply gravity.
		self.velocity.y += SKATE_GRAVITY * delta
		if self.velocity.length() > SKATE_MAX_SPEED:
			drag = SKATE_MAX_FRICTION
		else:
			drag = SKATE_FRICTION
	elif self.state == State.JUMP_START:
		# Launch the player into the air.
		self.velocity.y = min(self.velocity.y, -JUMP_LAUNCH_SPEED)
	elif self.state == State.JUMP || self.state == State.FALL:
		# Apply gravity.
		self.velocity.y += GRAVITY * delta
		# Apply air friction.
		drag = AIR_FRICTION
		# Apply air movement.
		if sign(intent.move_direction.x) * self.velocity.x < AIR_CONTROL_SPEED:
			self.velocity.x += intent.move_direction.x * AIR_ACCELERATION * delta
	
	# Apply drag, making sure that if the drag would bring the velocity to zero
	# we don't overshoot.
	if self.velocity.length_squared() > 0.0:
		var drag_delta := -drag * self.velocity.normalized() * delta
		if drag >= 0 && drag_delta.length() >= self.velocity.length():
			self.velocity = Vector2()
		else:
			self.velocity += drag_delta
	
	# Apply surface acceleration.
	var surface_acceleration_delta := surface_acceleration * surface_tangent * delta
	self.velocity += surface_acceleration_delta
	
	# Clamp the velocity by the max speed.
	self.velocity = self.velocity.clamped(MAX_SPEED)

# Steps the position forward by a small amount based on the current velocity.
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
	elif _on_surface() && collision == null:
		delta_remainder = 0.0
		# If the player used to be on a surface, then we should try to stick
		# to whatever surface may still be below them.
		if self.velocity.x != 0:
			var velocity_slope := self.velocity.y / self.velocity.x
			var max_slope_change := 0.5 * GRAVITY / self.velocity.x * SURFACE_DROP_TIME
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
	# If the player landed on a new surface, we need to adjust the state.
	if found_new_surface:
		# First, modify the velocity as the player moves onto the surface.
		var velocity_tangent := self.velocity.slide(new_surface_normal)
		var velocity_normal := self.velocity.dot(new_surface_normal) * new_surface_normal
		self.velocity = velocity_tangent
	# Before committing to the new surface, make sure that there isn't a
	# better choice of surface to be on by looking in the direction of the
	# last surface the player was on.
	if _on_surface():
		var test_collision := move_and_collide(-self.surface_normal, true, true, true)
		if test_collision != null:
			var test_normal := test_collision.normal
			# The test normal should be the same (to within tolerance) as the
			# normal of the last surface the player was on. Also, ensure that
			# it is not a ceiling.
			if test_normal.dot(self.surface_normal) >= 1.0 - 0.01 && abs(test_normal.angle_to(Vector2.UP)) <= WALL_ANGLE:
				# Choose the more horizontal surface.
				if !found_new_surface || test_normal.dot(Vector2.UP) > new_surface_normal.dot(Vector2.UP):
					self.position += test_collision.travel
					var velocity_tangent := self.velocity.slide(test_collision.normal)
					self.velocity = velocity_tangent
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

func _state_transition(intent : Intent) -> void:
	# Always transition from pre-jump to jump before anything else.
	if self.state == State.JUMP_START:
		self.state = State.JUMP
	if _on_surface():
		# If `_on_surface` is true, then the player must be in a surface state.
		# In case the player is not, make a transition into one of the surface
		# states.
		if !_is_surface_state(self.state):
			if intent.skate_start && self.velocity.length() >= SKATE_MIN_SPEED:
				# If the skate button is held down and velocity conditions are
				# met, then enter the skate state directly. Don't worry about
				# pushing off since we have enough velocity.
				self.state = State.SKATE
			elif self.physics_state == PhysicsState.FLOOR:
				# If the player landed on the floor, enter either the standing,
				# walking, or sliding state (depending on velocity and input).
				if self.velocity.length() > WALK_MAX_SPEED:
					self.state = State.SLIDE
				elif intent.move_direction.x != 0:
					self.state = State.WALK
				else:
					self.state = State.STAND
			elif self.physics_state == PhysicsState.SLOPE:
				# If landing on a slope, then just slide down it.
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
		# Now, update the player's state based on their surface state.
		if self.state == State.STAND:
			if self.velocity.length() > WALK_MAX_SPEED:
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.SLOPE:
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
			elif intent.jump:
				self.state = State.JUMP_START
			elif intent.skate_start:
				self.state = State.SKATE_START
			elif intent.move_direction.x != 0:
				self.state = State.WALK
		elif self.state == State.WALK:
			if self.velocity.length() > WALK_MAX_SPEED:
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.SLOPE:
				self.state = State.SLIDE
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
			elif intent.jump:
				self.state = State.JUMP_START
			elif intent.skate_start:
				self.state = State.SKATE_START
			elif intent.move_direction.x == 0:
				self.state = State.STAND
		elif self.state == State.SLIDE:
			if self.physics_state == PhysicsState.FLOOR:
				if self.velocity.length() < SLIDE_MIN_SPEED:
					if intent.move_direction.x != 0:
						self.state = State.WALK
					else:
						self.state = State.STAND
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.WALL_SLIDE
		elif self.state == State.WALL_SLIDE:
			if self.physics_state == PhysicsState.FLOOR:
				if self.velocity.length() < SLIDE_MIN_SPEED:
					if intent.move_direction.x != 0:
						self.state = State.WALK
					else:
						self.state = State.STAND
				else:
					self.state = State.SLIDE
			elif self.physics_state == PhysicsState.SLOPE:
				self.state = State.SLIDE
		elif self.state == State.SKATE_START:
			if intent.jump:
				self.state = State.JUMP_START
			else:
				self.state = State.SKATE
		elif self.state == State.SKATE:
			if intent.jump:
				self.state = State.JUMP_START
			elif self.velocity.length() < SKATE_MIN_SPEED:
				if self.physics_state == PhysicsState.FLOOR:
					if self.velocity.length() <= WALK_MAX_SPEED:
						if intent.move_direction.x != 0:
							self.state = State.WALK
						else:
							self.state = State.STAND
					else:
						self.state = State.SLIDE
				elif self.physics_state == PhysicsState.SLOPE:
					self.state = State.SLIDE
				elif self.physics_state == PhysicsState.WALL:
					self.state = State.WALL_SLIDE
	else:
		# If the player is in a surface state while not being on a surface,
		# then they must have walked off an edge, so put them into the fall
		# state.
		if _is_surface_state(self.state):
			self.state = State.FALL

func _animation_transition(intent : Intent) -> void:
	var next_animation := ""
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	if self.state == State.STAND:
		if self.facing_direction == -1:
			next_animation = "StandLeft"
		else:
			next_animation = "StandRight"
	elif self.state == State.WALK:
		if self.facing_direction == -1:
			next_animation = "WalkLeft"
		else:
			next_animation = "WalkRight"
	elif self.state == State.SLIDE:
		if self.surface_normal.x < 0.0:
			next_animation = "SlideLeft"
		else:
			next_animation = "SlideRight"
	elif self.state == State.WALL_SLIDE:
		if self.surface_normal.x < 0.0:
			next_animation = "WallSlideLeft"
		else:
			next_animation = "WallSlideRight"
	elif self.state == State.SKATE_START:
		if self.facing_direction < 0.0:
			next_animation = "SkateLeft"
		else:
			next_animation = "SkateRight"
	elif self.state == State.SKATE:
		if self.velocity.dot(surface_tangent) < 0.0:
			next_animation = "SkateLeft"
		else:
			next_animation = "SkateRight"
	elif self.state == State.JUMP_START || self.state == State.JUMP:
		if self.facing_direction == -1:
			next_animation = "JumpLeft"
		else:
			next_animation = "JumpRight"
	elif self.state == State.FALL:
		if self.facing_direction == -1:
			next_animation = "FallLeft"
		else:
			next_animation = "FallRight"
	if self.animation_player.current_animation != next_animation:
		self.animation_player.play(next_animation)
