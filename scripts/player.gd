extends KinematicBody2D

# Things that need to be done:
# * Sometimes just clamp at max velocity instead of doing a reverse
#   acceleration. A reverse acceleration can make velocities go back and forth
#   around the maximum, and can be kind of ugly. Example: wall slide.
# * Jumping rework:
#   * Jumping goes higher if you hold button.
#   * Jumping pushes you partly in the direction of the normal, and partly
#     upwards.
#   * Well-timed jumps just after hitting the ground can keep the player in
#     ballistic state.
# * Make sliding off of a slope and onto a floor give a small velocity boost,
#   to stop awkward situations where the player keeps trying to walk onto a
#   slope.
# * Some kind of ballistic arial system. Some thoughts on this:
#   * The ballistic state can allow for redirection by dashes and well-timed
#     wall-jumps.
#   * The ballistic state allows for the skating state to be entered directly
#     at high speed upon landing (do you have to press a button?)

# The allowed player states.
enum State {
	STAND,
	WALK,
	SLIDE,
	WALL_SLIDE,
	WALL_RELEASE,
	PIVOT,
	SKATE_START,
	SKATE_PIVOT_START,
	SKATE,
	SKATE_BOOST,
	SKATE_BRAKE,
	WIPEOUT,
	JUMP_START,
	JUMP_WALL_START,
	JUMP_BALLISTIC_START,
	JUMP,
	FALL,
	BALLISTIC
}
const STATE_NAME := {
	State.STAND: "Stand",
	State.WALK: "Walk",
	State.SLIDE: "Slide",
	State.WALL_SLIDE: "WallSlide",
	State.WALL_RELEASE: "WallRelease",
	State.PIVOT: "Pivot",
	State.SKATE_START: "SkateStart",
	State.SKATE_PIVOT_START: "SkatePivotStart",
	State.SKATE: "Skate",
	State.SKATE_BOOST: "SkateBoost",
	State.SKATE_BRAKE: "SkateBrake",
	State.WIPEOUT: "Wipeout",
	State.JUMP_START: "JumpStart",
	State.JUMP_WALL_START: "JumpWallStart",
	State.JUMP_BALLISTIC_START: "JumpBallisticStart",
	State.JUMP: "Jump",
	State.FALL: "Fall",
	State.BALLISTIC: "Ballistic"
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
	var move_direction := Vector2.ZERO
	var jump := false
	var skate_start := false
	var skate_boost := false
	var skate_brake := false

const FLOOR_ANGLE := 5.0 * PI / 180.0
const SLOPE_ANGLE := 85.0 * PI / 180.0
const WALL_ANGLE := 100.0 * PI / 180.0

# If the player would land on the ground in this amount of time after leaving
# the ground, then don't bother letting the player leave the ground at all.
const SURFACE_DROP_TIME := 0.4
# If the player is registered as leaving a surface, but the surface remains
# within this distance of the player, then don't let the player leave the
# surface.
const SURFACE_PADDING := 0.5

# The regular force of gravity. Depending on the state of the player, they may
# experience a different amount of gravity than this.
const GRAVITY := 800.0
const MAX_SPEED := 1000.0
const EXHAUSTED_TIME := 0.5

const WALK_ACCELERATION := 700.0
const WALK_SPEED := 100.0
# Maximum angle the player can walk up without slipping.
const WALK_MAX_ANGLE := 30.0 * PI / 180.0
# Maximum speed before entering a slide.
const WALK_MAX_SPEED := 150.0

const SLIDE_ACCELERATION := 500.0
const SLIDE_SPEED := 140.0
# Minimum speed before entering a walk.
const SLIDE_MIN_SPEED := 100.0
# Minimum time to slide for on a flat surface before entering a walk.
const SLIDE_MIN_TIME := 0.2

const WALL_SLIDE_ACCELERATION := 600.0
const WALL_SLIDE_SPEED := 50.0
const WALL_RELEASE_START_SPEED := 50.0

# The time that the player remains paused, briefly, at the end of a brake.
const PIVOT_TIME := 0.25

# Speed needed to launch the player into the skating state.
const SKATE_START_MIN_SPEED := 40.0
# Initial speed when entering the skate state.
const SKATE_START_SPEED := 100.0
const SKATE_PIVOT_START_SPEED_FRACTION := 0.8
# The base amount of speed gained when making a boost.
const SKATE_BOOST_BASE_SPEED := 10.0
# What fraction of the current speed gets added to the boost.
const SKATE_BOOST_SPEED_FRACTION := 0.5
# The optimal frequency per velocity that the boost button should be pressed
# for maximum acceleration.
const SKATE_BOOST_SPEED_COST := (1.0 / 0.75) * 500.0
# Skating friction does not act below this speed. If the player slows down
# below this speed on level ground, they will experience a slight acceleration
# bringing them back up to this speed.
const SKATE_MIN_SPEED := 100.0
const SKATE_FRICTION := 60.0

# Friction when the player tries to slow down.
const SKATE_BRAKE_FRICTION := 400.0
# The minimum speed the player can brake to on both slopes and the floor.
const SKATE_BRAKE_MIN_SPEED := 10.0

const SKATE_GRAVITY := 200.0
const SKATE_MAX_REDIRECT_ANGLE := 40.0 * PI / 180.0
const SKATE_MAX_REDIRECT_FRACTION := 0.6

# The "minimum fractional impulse" needed to wipeout, meaning what percentage
# of the player's speed must be lost in an instant.
const WIPEOUT_MIN_FRACTIONAL_IMPULSE := 0.6
# The "minimum impulse" needed to wipeout, meaning what absolute amount of
# speed must be lost in an instant.
const WIPEOUT_MIN_IMPULSE := 200.0
const WIPEOUT_FRICTION := 500.0
const WIPEOUT_TIME := 0.8

const JUMP_START_SPEED := 300.0
const JUMP_WALL_START_SPEED := 350.0
const JUMP_WALL_START_ANGLE := 35.0 * PI / 180.0

# Ballistic jumps have a minimum vertical component and a minimum normal
# component. The rest of the jump can be aimed as desired by the player.
const JUMP_BALLISTIC_START_SPEED := 350.0

const FALL_ACCELERATION := 800.0
const FALL_FRICTION := 100.0
const FALL_MAX_SPEED_HORIZONTAL := 150.0
const FALL_MAX_SPEED_VERTICAL := 450.0

const BALLISTIC_GRAVITY := 800.0
# The angular speed at which the ballistic trajectory can be affected.
const BALLISTIC_ANGULAR_SPEED := 30.0 * PI / 180.0
# The acceleration that is applied to the trajectory if the max speed is
# exceeded. Gravity is also stopped in that case.
const BALLISTIC_ACCELERATION := 400.0
const BALLISTIC_MAX_SPEED := 1000.0
const BALLISTIC_MAX_REDIRECT_ANGLE := 90.0 * PI / 180.0
const BALLISTIC_MAX_REDIRECT_FRACTION := 0.5

var state : int = State.FALL
var physics_state : int = PhysicsState.AIR
# The normal to the surface the player is on (only valid if `_on_surface`
# returns true).
var surface_normal := Vector2.ZERO
var velocity := Vector2.ZERO
var facing_direction := 1

var skate_direction := 1
var slide_timer := 0.0
# This timer keeps track of how long the player has been skating for.
var skate_timer := 0.0
var skate_boost_timer := 0.0
var wipeout_timer := 0.0
# The amount of velocity stored when making a pivot.
var pivot_stored_velocity := 0.0
var pivot_timer := 0.0

# Store the previous state as well.
var previous_state := self.state
var previous_physics_state := self.physics_state
# TODO: Should this be initialized with `onready`?
var previous_position := self.position
var previous_velocity := self.velocity

onready var animation_player := $Sprite/AnimationPlayer
onready var ballistic_effect_sprite := $BallisticEffectSprite

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
	# Jump can be a surface state if we jump next to a wall.
	return state == State.STAND \
			|| state == State.WALK \
			|| state == State.SLIDE \
			|| state == State.WALL_SLIDE \
			|| state == State.WALL_RELEASE \
			|| state == State.PIVOT \
			|| state == State.SKATE_START \
			|| state == State.SKATE_PIVOT_START \
			|| state == State.SKATE \
			|| state == State.SKATE_BOOST \
			|| state == State.SKATE_BRAKE \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP_BALLISTIC_START \
			|| state == State.JUMP \
			|| state == State.WIPEOUT

# "Air states" are the opposite of surface states. Note that a state can be
# both an air state and a surface state. That simply means that the player may
# be on a surface or in the air when they are in that state.
func _is_air_state(state : int) -> bool:
	return state == State.JUMP \
			|| state == State.FALL \
			|| state == State.BALLISTIC \
			|| state == State.WIPEOUT

# A "normal" state are those related to moving around at slow velocities with
# normal platforming controls. While in a normal state, the only way to
# transition to a skate state is through 
func _is_normal_state(state : int) -> bool:
	return state == State.STAND \
			|| state == State.WALK \
			|| state == State.SLIDE \
			|| state == State.WALL_SLIDE \
			|| state == State.WALL_RELEASE \
			|| state == State.PIVOT \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP \
			|| state == State.FALL

# "Skate states" are those related to skating. While in a skate state, the only
# way to transition to a normal state is through braking (SKATE_BRAKE) or
# through wiping out (WIPEOUT).
func _is_skate_state(state : int) -> bool:
	return state == State.SKATE_START \
			|| state == State.SKATE_PIVOT_START \
			|| state == State.SKATE \
			|| state == State.SKATE_BOOST \
			|| state == State.SKATE_BRAKE \
			|| state == State.JUMP_BALLISTIC_START \
			|| state == State.BALLISTIC

# A "stun state" is one in which the player cannot act.
func _is_stun_state(state : int) -> bool:
	return state == State.WIPEOUT

# Returns the fraction of the normal velocity that should be kept over a given
# angle difference.
func _redirect_normal_velocity(angle_difference : float) -> float:
	if _is_skate_state(self.state):
		if _on_surface():
			return clamp((SKATE_MAX_REDIRECT_ANGLE - angle_difference) / SKATE_MAX_REDIRECT_ANGLE, 0.0, 1.0) * SKATE_MAX_REDIRECT_FRACTION
		else:
			return clamp((BALLISTIC_MAX_REDIRECT_ANGLE - angle_difference) / BALLISTIC_MAX_REDIRECT_ANGLE, 0.0, 1.0) * BALLISTIC_MAX_REDIRECT_FRACTION
	else:
		return 0.0

func _apply_drag(drag : float, delta : float) -> void:
	if self.velocity.length_squared() > 0.0:
		var drag_delta := -drag * self.velocity.normalized() * delta
		if drag >= 0 && drag_delta.length() >= self.velocity.length():
			self.velocity = Vector2.ZERO
		else:
			self.velocity += drag_delta

func _ready() -> void:
	self.ballistic_effect_sprite.visible = false

func _physics_process(delta : float) -> void:
	var move_direction := _read_move_direction()
	_facing_direction_process(move_direction)
	# Update the velocities based on the current state.
	_state_process(delta, move_direction)
	# Step the position forward by the timestep.
	_position_process(delta)
	# Transition between states.
	var intent := _read_intent(move_direction)
	if _state_transition_physics(intent):
		intent = _read_intent(move_direction)
	if _state_transition(delta, intent):
		intent = _read_intent(move_direction)
	#print(boost, ",", self.skate_boost_timer, ",", self.velocity.length() / SKATE_BOOST_SPEED_COST)
	print(self.velocity.length())
	# Update the animation based on the state.
	_visuals_process()
	
	# Print the state for debugging purposes.
	if self.previous_state != self.state || self.previous_physics_state != self.physics_state:
		print(PHYSICS_STATE_NAME[self.physics_state], "; ", STATE_NAME[self.state])
	
	self.previous_state = self.state
	self.previous_physics_state = self.physics_state
	self.previous_position = self.position
	self.previous_velocity = self.velocity

func _read_move_direction() -> Vector2:
	var move_direction := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		move_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		move_direction.x += 1
	if Input.is_action_pressed("move_up"):
		move_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		move_direction.y += 1
	return move_direction

func _read_intent(move_direction : Vector2) -> Intent:
	var intent := Intent.new()
	intent.move_direction = move_direction
	# Get input from the user.
	# TODO: Perhaps some of these should be conditional depending on the
	# current state. For example, pressing the skate button means to start
	# skating when you are on the ground, but to boost when already skating.
	if Input.is_action_just_pressed("jump"):
		intent.jump = true
	if _on_surface():
		if !_is_skate_state(self.state):
			if self.state == State.PIVOT:
				if sign(move_direction.x) == -sign(self.pivot_stored_velocity) && Input.is_action_just_pressed("skate"):
					intent.skate_start = true
			else:
				if Input.is_action_just_pressed("skate"):
					intent.skate_start = true
		if _is_skate_state(self.state):
			if self.state != State.SKATE_BRAKE:
				if self.skate_direction == -1 && Input.is_action_just_pressed("move_right") \
						|| self.skate_direction == 1 && Input.is_action_just_pressed("move_left"):
					intent.skate_brake = true
			else:
				if self.skate_direction == -1 && Input.is_action_pressed("move_right") \
						|| self.skate_direction == 1 && Input.is_action_pressed("move_left"):
					intent.skate_brake = true
				else:
					intent.skate_brake = false
			if !intent.skate_brake && Input.is_action_just_pressed("skate"):
				intent.skate_boost = true
	return intent

# Updates the facing direction based on the state. Note that the facing
# direction should not affect the logic, only the animations.
func _facing_direction_process(move_direction : Vector2) -> void:
	var next_facing_direction := 0
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	if self.state == State.STAND || self.state == State.WALK || self.state == State.FALL:
		next_facing_direction = int(sign(move_direction.x))
	elif self.state == State.SLIDE:
		next_facing_direction = int(sign(self.velocity.x))
	elif self.state == State.WALL_SLIDE:
		if self.physics_state == PhysicsState.WALL:
			next_facing_direction = int(sign(self.surface_normal.x))
	elif _is_skate_state(self.state):
		next_facing_direction = self.skate_direction
	if next_facing_direction != 0:
		self.facing_direction = next_facing_direction

# Updates the velocities based on the current state.
func _state_process(delta : float, move_direction : Vector2) -> void:
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	if self.state == State.STAND:
		# When the player is standing, they should slow down to a stop. We use
		# the walk acceleration here so that it blends nicely with ceasing to
		# walk.
		_apply_drag(WALK_ACCELERATION, delta)
	elif self.state == State.WALK:
		# When the player is walking, we must accelerate them up to speed in
		# the direction they have chosen to move.
		if self.velocity.length() > WALK_SPEED:
			_apply_drag(WALK_ACCELERATION, delta)
		else:
			self.velocity += move_direction.x * WALK_ACCELERATION * surface_tangent * delta
	elif self.state == State.SLIDE:
		# When the player is sliding, they will speed up to reach the sliding
		# speed, and then maintain that speed. If they slide onto a floor
		# region, they will slow down to a stop.
		var surface_angle = self.surface_normal.angle_to(Vector2.UP)
		if abs(surface_angle) <= WALK_MAX_ANGLE:
			_apply_drag(SLIDE_ACCELERATION, delta)
		elif self.velocity.length() > SLIDE_SPEED:
			_apply_drag(SLIDE_ACCELERATION, delta)
		else:
			self.velocity += sign(self.surface_normal.x) * SLIDE_ACCELERATION * surface_tangent * delta
	elif self.state == State.WALL_SLIDE:
		# Similar to regular sliding.
		if self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE:
			_apply_drag(WALL_SLIDE_ACCELERATION, delta)
		elif self.physics_state == PhysicsState.WALL:
			if self.velocity.length() > WALL_SLIDE_SPEED:
				_apply_drag(WALL_SLIDE_ACCELERATION, delta)
			else:
				self.velocity += sign(self.surface_normal.x) * WALL_SLIDE_ACCELERATION * surface_tangent * delta
	elif self.state == State.WALL_RELEASE:
		# Similar to a small jump off of the wall.
		self.velocity += self.surface_normal * WALL_RELEASE_START_SPEED
	elif self.state == State.SKATE_START:
		self.velocity = self.skate_direction * surface_tangent * SKATE_START_SPEED
	elif self.state == State.SKATE_PIVOT_START:
		var skate_speed := SKATE_START_SPEED + SKATE_PIVOT_START_SPEED_FRACTION * max(abs(self.pivot_stored_velocity) - SKATE_START_SPEED, 0.0)
		self.velocity = self.skate_direction * surface_tangent * skate_speed
	elif self.state == State.SKATE:
		if self.physics_state == PhysicsState.FLOOR:
			if self.velocity.dot(self.skate_direction * surface_tangent) > SKATE_MIN_SPEED:
				_apply_drag(SKATE_FRICTION, delta)
			else:
				self.velocity += self.skate_direction * surface_tangent * SKATE_FRICTION * delta
		else:
			if self.velocity.dot(self.skate_direction * surface_tangent) > SKATE_MIN_SPEED:
				self.velocity += surface_tangent * surface_tangent.dot(SKATE_GRAVITY * Vector2.DOWN) * delta
				_apply_drag(SKATE_FRICTION, delta)
			else:
				self.velocity += surface_tangent * surface_tangent.dot(GRAVITY * Vector2.DOWN) * delta
	elif self.state == State.PIVOT:
		self.velocity = Vector2.ZERO
	elif self.state == State.SKATE_BOOST:
		var boost := SKATE_BOOST_BASE_SPEED + SKATE_BOOST_SPEED_FRACTION * self.velocity.length()
		if self.skate_boost_timer != 0.0:
			boost *= exp(-self.velocity.length() / (SKATE_BOOST_SPEED_COST * self.skate_boost_timer))
		self.velocity += self.skate_direction * surface_tangent * boost
	elif self.state == State.SKATE_BRAKE:
		self.velocity += surface_tangent * surface_tangent.dot(SKATE_GRAVITY * Vector2.DOWN) * delta
		if self.velocity.dot(self.skate_direction * surface_tangent) > 0.0:
			_apply_drag(SKATE_BRAKE_FRICTION, delta)
	elif self.state == State.WIPEOUT:
		if self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE:
			self.velocity += surface_tangent * surface_tangent.dot(GRAVITY * Vector2.DOWN) * delta
			_apply_drag(WIPEOUT_FRICTION, delta)
		elif self.velocity.y < FALL_MAX_SPEED_VERTICAL:
			self.velocity.y += GRAVITY * delta
	elif self.state == State.JUMP_START:
		# Launch the player into the air.
		self.velocity.y = min(-JUMP_START_SPEED, self.velocity.y)
	elif self.state == State.JUMP_WALL_START:
		self.velocity.x = sign(self.surface_normal.x) * JUMP_WALL_START_SPEED * cos(JUMP_WALL_START_ANGLE)
		self.velocity.y = -JUMP_WALL_START_SPEED * sin(JUMP_WALL_START_ANGLE)
	elif self.state == State.JUMP_BALLISTIC_START:
		self.velocity += self.surface_normal * JUMP_BALLISTIC_START_SPEED
	elif self.state == State.JUMP || self.state == State.FALL:
		# Apply gravity.
		self.velocity.y += GRAVITY * delta
		self.velocity.y = clamp(self.velocity.y, -FALL_MAX_SPEED_VERTICAL, FALL_MAX_SPEED_VERTICAL)
		# Apply air friction (along x only).
		if abs(self.velocity.x) <= FALL_FRICTION * delta:
			self.velocity.x = 0.0
		else:
			self.velocity.x -= sign(self.velocity.x) * FALL_FRICTION * delta
		# Air movement.
		if abs(self.velocity.x) > FALL_MAX_SPEED_HORIZONTAL:
			self.velocity.x -= sign(self.velocity.x) * FALL_ACCELERATION * delta
		else:
			self.velocity.x += move_direction.x * FALL_ACCELERATION * delta
	elif self.state == State.BALLISTIC:
		if self.velocity.length() > BALLISTIC_MAX_SPEED:
			_apply_drag(BALLISTIC_ACCELERATION, delta)
		else:
			self.velocity.y += BALLISTIC_GRAVITY * delta
		var angle_change_direction := sign(self.velocity.angle_to(move_direction))
		if angle_change_direction != 0:
			# When in the ballistic state, the player's direction can be
			# changed, but not the magnitude of the velocity.
			self.velocity = self.velocity.rotated(angle_change_direction * BALLISTIC_ANGULAR_SPEED * delta)
	
	# Clamp the velocity by the absolute max speed.
	self.velocity = self.velocity.clamped(MAX_SPEED)

# Steps the position forward by a small amount based on the current velocity.
func _position_process(delta : float, n : int = 4) -> void:
	# Exit if the maximum number of iterations has been reached.
	if n <= 0 || delta <= 0 || self.velocity.length_squared() == 0:
		return
	var delta_remainder := 0.0
	var found_new_surface := false
	var new_surface_normal := Vector2.ZERO
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
		if velocity_tangent.length_squared() != 0.0 && self.velocity.length_squared() != 0.0:
			var angle_difference := self.velocity.angle_to(velocity_tangent)
			var redirect_fraction := _redirect_normal_velocity(angle_difference)
			self.velocity = velocity_tangent.normalized() * (velocity_tangent + redirect_fraction * velocity_normal).length()
		else:
			self.velocity = velocity_tangent
	# Before committing to the new surface, make sure that there isn't a
	# better choice of surface to be on by looking in the direction of the
	# last surface the player was on.
	if _on_surface():
		var test_collision := move_and_collide(-self.surface_normal * SURFACE_PADDING, true, true, true)
		if test_collision != null:
			var test_normal := test_collision.normal
			# The test normal should be the same (to within tolerance) as the
			# normal of the last surface the player was on.
			var normal_condition := test_normal.dot(self.surface_normal) >= 1.0 - 0.01
			# The surface must not be a ceiling.
			var ceiling_condition := abs(test_normal.angle_to(Vector2.UP)) <= WALL_ANGLE
			# The velocity vector must not be such that the player will move
			# more than the padding distance away in the next step.
			var velocity_condition := test_normal.dot(self.velocity * delta) <= SURFACE_PADDING
			if normal_condition && ceiling_condition && velocity_condition:
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

# Handle transitions into and away from different states.
func _handle_state_transition(old_state : int) -> bool:
	if old_state != self.state:
		# First handle transitions between skate states and non-skate states.
		if !_is_skate_state(self.state) && _is_skate_state(old_state):
			pass
		if _is_skate_state(self.state) && !_is_skate_state(old_state):
			self.skate_timer = 0.0
			self.skate_boost_timer = 0.0
		if _is_surface_state(self.state) && _is_skate_state(self.state) && (!_is_surface_state(old_state) || !_is_skate_state(old_state)):
			var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
			self.skate_direction = int(sign(self.velocity.dot(surface_tangent)))
			if self.skate_direction == 0:
				self.skate_direction = self.facing_direction
		
		if self.state == State.PIVOT:
			self.pivot_timer = 0.0
		elif self.state == State.SLIDE:
			self.slide_timer = 0.0
		elif self.state == State.SKATE_PIVOT_START:
			self.skate_direction = -int(sign(self.pivot_stored_velocity))
			if self.skate_direction == 0:
				self.skate_direction = self.facing_direction
		elif self.state == State.SKATE:
			if old_state == State.SKATE_BOOST || old_state == State.SKATE_START || old_state == State.SKATE_PIVOT_START:
				self.skate_boost_timer = 0.0
		elif self.state == State.SKATE_BRAKE:
			self.pivot_stored_velocity = 0.0
		elif self.state == State.WIPEOUT:
			self.wipeout_timer = 0.0
		return true
	else:
		return false

# This function does state transitions that are required due to physics, which
# basically means air-to-surface and surface-to-air state transitions.
func _state_transition_physics(intent : Intent) -> bool:
	var old_state := self.state
	if _on_surface():
		# If `_on_surface` is true, then the player must be in a surface state.
		# In case the player is not, make a transition into one of the surface
		# states.
		if !_is_surface_state(self.state):
			if _is_skate_state(self.state):
				self.state = _get_default_skate_state(intent)
			elif _is_normal_state(self.state):
				self.state = _get_default_normal_state(intent)
			else:
				self.state = State.WIPEOUT
	else:
		# If the player is in the air but not in an air-compatible state, then
		# transition into the correct air state.
		if !_is_air_state(self.state):
			if self.state == State.WALL_RELEASE:
				self.state = State.FALL
			elif self.state == State.JUMP_START:
				self.state = State.JUMP
			elif self.state == State.JUMP_WALL_START:
				self.state = State.JUMP
			elif self.state == State.JUMP_BALLISTIC_START:
				self.state = State.BALLISTIC
			elif _is_skate_state(self.state):
				self.state = _get_default_skate_state(intent)
			elif _is_normal_state(self.state):
				self.state = _get_default_normal_state(intent)
			else:
				self.state = State.WIPEOUT
	
	if self._on_surface() && !_is_surface_state(self.state):
		printerr("On surface but state ", STATE_NAME[self.state], " is not a surface state.")
	if !self._on_surface() && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")
	
	return _handle_state_transition(old_state)

func _state_transition(delta : float, intent : Intent) -> bool:
	var old_state := self.state
	var surface_tangent = Vector2(-self.surface_normal.y, self.surface_normal.x)
	
	if _is_normal_state(self.state):
		# Input transitions take priority over all else.
		if intent.jump && _is_surface_state(self.state) && self.state != State.JUMP:
			if self.physics_state == PhysicsState.WALL:
				self.state = State.JUMP_WALL_START
			else:
				self.state = State.JUMP_START
		elif intent.skate_start && self.state == State.PIVOT && self.pivot_stored_velocity != 0.0:
			self.state = State.SKATE_PIVOT_START
		elif intent.skate_start && _is_surface_state(self.state) && self.state != State.JUMP && self.velocity.length() >= SKATE_START_MIN_SPEED:
			self.state = State.SKATE_START
		# Then do transitions in between normal states.
		elif self.state == State.STAND:
			if self.physics_state != PhysicsState.FLOOR:
				self.state = _get_default_normal_state(intent)
			elif self.velocity.length() > WALK_MAX_SPEED:
				self.state = State.SLIDE
			elif intent.move_direction.x != 0:
				self.state = State.WALK
		elif self.state == State.WALK:
			if self.physics_state != PhysicsState.FLOOR:
				self.state = _get_default_normal_state(intent)
			elif self.velocity.length() > WALK_MAX_SPEED:
				self.state = State.SLIDE
				self.slide_timer = 0.0
			elif intent.move_direction.x == 0:
				self.state = State.STAND
		elif self.state == State.SLIDE:
			var surface_angle = self.surface_normal.angle_to(Vector2.UP)
			if self.slide_timer < SLIDE_MIN_TIME:
				self.slide_timer += delta
				if self.physics_state == PhysicsState.WALL:
					self.state = _get_default_normal_state(intent, true)
			elif self.physics_state == PhysicsState.WALL || abs(surface_angle) <= WALK_MAX_ANGLE:
				self.state = _get_default_normal_state(intent, true)
		elif self.state == State.WALL_SLIDE:
			if self.physics_state != PhysicsState.WALL:
				self.state = _get_default_normal_state(intent, true)
			elif sign(intent.move_direction.x) == sign(self.surface_normal.x):
				self.state = State.WALL_RELEASE
		elif self.state == State.WALL_RELEASE:
			# Shouldn't happen.
			printerr("Failed to release wall.")
			self.state = _get_default_normal_state(intent)
		elif self.state == State.PIVOT:
			self.pivot_timer += delta
			if self.pivot_timer > PIVOT_TIME:
				self.state = _get_default_normal_state(intent)
		elif self.state == State.JUMP_START:
			# Shouldn't happen.
			printerr("Failed to jump.")
			self.state = _get_default_normal_state(intent)
		elif self.state == State.JUMP_WALL_START:
			printerr("Failed to wall jump.")
			self.state = _get_default_normal_state(intent)
		elif self.state == State.JUMP:
			if self.velocity.y >= 0.0:
				self.state = _get_default_normal_state(intent)
		elif self.state == State.FALL:
			pass
	elif _is_skate_state(self.state):
		self.skate_timer += delta
		self.skate_boost_timer += delta
		if _on_surface():
			if self.velocity.dot(self.skate_direction * surface_tangent) < 0.0:
				if self.physics_state == PhysicsState.SLOPE || self.physics_state == PhysicsState.WALL:
					self.skate_direction = -self.skate_direction
				else:
					printerr("Flipped skate direction on floor.")
		
		# Impulse is used to determine if the player has crashed into a wall.
		var impulse := self.velocity.length() - self.previous_velocity.length()
		var fractional_impulse := 0.0
		if self.previous_velocity.length_squared() != 0.0:
			fractional_impulse = impulse / self.previous_velocity.length()
		
		if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
			self.state = State.WIPEOUT
		elif intent.jump && _is_surface_state(self.state):
			self.state = State.JUMP_BALLISTIC_START
		elif intent.skate_brake && _is_surface_state(self.state) && self.state != State.SKATE_BRAKE:
			self.state = State.SKATE_BRAKE
		elif !intent.skate_brake && self.state == State.SKATE_BRAKE:
			self.state = State.SKATE
		elif self.state == State.SKATE_START:
			self.state = State.SKATE
		elif self.state == State.SKATE_PIVOT_START:
			self.state = State.SKATE
		elif intent.skate_boost:
			self.state = State.SKATE_BOOST
		elif self.state == State.SKATE:
			pass
		elif self.state == State.SKATE_BOOST:
			self.state = State.SKATE
		elif self.state == State.SKATE_BRAKE:
			self.pivot_stored_velocity += (self.previous_velocity - self.velocity).dot(surface_tangent)
			if self.velocity.length() < SKATE_BRAKE_MIN_SPEED:
				self.state = State.PIVOT
		elif self.state == State.BALLISTIC:
			if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
				self.state = State.WIPEOUT
		elif self.state == State.JUMP_BALLISTIC_START:
			printerr("Failed to ballistic jump.")
			self.state = _get_default_normal_state(intent)
	elif _is_stun_state(self.state):
		if self.state == State.WIPEOUT:
			if (self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE) && self.velocity.length() < WALK_MAX_SPEED:
				self.wipeout_timer += delta
				if self.wipeout_timer > WIPEOUT_TIME:
					self.state = _get_default_normal_state(intent)
	
	if self._on_surface() && !_is_surface_state(self.state):
		printerr("On surface but state ", STATE_NAME[self.state], " is not a surface state.")
	if !self._on_surface() && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")
	
	return _handle_state_transition(old_state)

# Gets an appropriate choice of state based on the physics state of the player.
# This is used when resetting the player state.
func _get_default_normal_state(intent : Intent, prefer_slide : bool = false) -> int:
	if !_on_surface():
		return State.FALL
	else:
		var surface_angle = self.surface_normal.angle_to(Vector2.UP)
		if self.physics_state == PhysicsState.WALL:
			return State.WALL_SLIDE
		elif abs(surface_angle) <= WALK_MAX_ANGLE:
			var enter_slide := self.velocity.length() >= SLIDE_MIN_SPEED if prefer_slide \
					else self.velocity.length() > WALK_MAX_SPEED
			if enter_slide:
				return State.SLIDE
			elif intent.move_direction.x != 0:
				return State.WALK
			else:
				return State.STAND
		else:
			# If landing on a steep slope, then just slide down it.
			return State.SLIDE

func _get_default_skate_state(intent : Intent) -> int:
	if self.physics_state == PhysicsState.AIR:
		return State.BALLISTIC
	else:
		return State.SKATE

func _visuals_process() -> void:
	var next_animation := ""
	var current_animation : String = self.animation_player.current_animation
	var is_playing : bool = self.animation_player.is_playing()
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
		if self.facing_direction == -1:
			next_animation = "SlideLeft"
		else:
			next_animation = "SlideRight"
	elif self.state == State.WALL_SLIDE || self.state == State.WALL_RELEASE:
		if self.facing_direction == -1:
			next_animation = "WallSlideLeft"
		else:
			next_animation = "WallSlideRight"
	elif self.state == State.SKATE_START || self.state == State.SKATE_BOOST:
		if self.facing_direction == -1:
			next_animation = "SkateBoostLeft"
		else:
			next_animation = "SkateBoostRight"
	elif self.state == State.SKATE:
		if !is_playing || (current_animation != "SkateBoostLeft" && current_animation != "SkateBoostRight"):
			if self.facing_direction == -1:
				next_animation = "SkateLeft"
			else:
				next_animation = "SkateRight"
	elif self.state == State.WIPEOUT:
		if self.facing_direction == -1:
			next_animation = "WipeoutLeft"
		else:
			next_animation = "WipeoutRight"
	elif self.state == State.JUMP_START || self.state == State.JUMP_WALL_START || self.state == State.JUMP_BALLISTIC_START || self.state == State.JUMP:
		if self.facing_direction == -1:
			next_animation = "JumpLeft"
		else:
			next_animation = "JumpRight"
	elif self.state == State.FALL:
		if self.facing_direction == -1:
			next_animation = "FallLeft"
		else:
			next_animation = "FallRight"
	elif self.state == State.BALLISTIC:
		if self.facing_direction == -1:
			next_animation = "FallLeft"
		else:
			next_animation = "FallRight"
	else:
		pass
		#printerr("No animation found for state ", STATE_NAME[self.state])
	if self.animation_player.current_animation != next_animation:
		self.animation_player.play(next_animation)
	
	# Effects.
	if self.state == State.BALLISTIC:
		if !self.ballistic_effect_sprite.visible:
			self.ballistic_effect_sprite.visible = true
		self.ballistic_effect_sprite.rotation = self.velocity.angle()
	else:
		self.ballistic_effect_sprite.visible = false
