extends KinematicBody2D

# Things that need to be done:
# * Fix issue where tapping skate just after landing will wipe you out. Landing
#   in skate mode shouldn't wipe you out if you try to boost too soon.
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
	SKATE_START,
	SKATE,
	SKATE_BOOST,
	SKATE_BRAKE,
	WIPEOUT,
	JUMP_START,
	JUMP_WALL_START,
	JUMP_BALLISTIC_START,
	JUMP,
	FALL,
	BALLISTIC,
	DASH_CHARGE,
	DASH_START,
	DASH
}
const STATE_NAME := {
	State.STAND: "Stand",
	State.WALK: "Walk",
	State.SLIDE: "Slide",
	State.WALL_SLIDE: "WallSlide",
	State.WALL_RELEASE: "WallRelease",
	State.SKATE_START: "SkateStart",
	State.SKATE: "Skate",
	State.SKATE_BOOST: "SkateBoost",
	State.SKATE_BRAKE: "SkateBrake",
	State.WIPEOUT: "Wipeout",
	State.JUMP_START: "JumpStart",
	State.JUMP_WALL_START: "JumpWallStart",
	State.JUMP_BALLISTIC_START: "JumpBallisticStart",
	State.JUMP: "Jump",
	State.FALL: "Fall",
	State.BALLISTIC: "Ballistic",
	State.DASH_CHARGE: "DashCharge",
	State.DASH_START: "DashStart",
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
	var skate_start := false
	var skate_boost := false
	var skate_transition := false
	var dash_charge := false
	var dash_start := false

const FLOOR_ANGLE := 40.0 * PI / 180.0
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

# Speed needed to launch the player into the skating state.
const SKATE_START_MIN_SPEED := 40.0
# Initial speed when entering the skate state.
const SKATE_START_SPEED := 220.0
# Maximum speed gain when getting a perfect boost.
const SKATE_BOOST_MAX_SPEED := 200.0
const SKATE_BOOST_MIN_SPEED := 60.0
# Skating friction does not act below this speed. If the player slows down
# below this speed on level ground, they will experience a slight acceleration
# bringing them back up to this speed.
const SKATE_MIN_SPEED := 40.0
const SKATE_FRICTION := 80.0
# Friction when the player tries to slow down.
const SKATE_BRAKE_ACCELERATION := 400.0
const SKATE_GRAVITY := 140.0
const SKATE_BOOST_MIN_TIME := 0.3
const SKATE_BOOST_MAX_TIME := 0.8
const SKATE_MAX_REDIRECT_ANGLE := 40.0 * PI / 180.0
const SKATE_MAX_REDIRECT_FRACTION := 0.6

# Maximum skating speed before entering the ballistic state.
const SKATE_MAX_SPEED := 350.0
# Minimum skating speed to maintain the ballistic state.
const SKATE_BALLISTIC_MIN_SPEED := 250.0

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
const BALLISTIC_MIN_SPEED := 200.0
const BALLISTIC_MAX_SPEED := 1000.0
const BALLISTIC_MAX_REDIRECT_ANGLE := 90.0 * PI / 180.0
const BALLISTIC_MAX_REDIRECT_FRACTION := 0.5

# The friction that brings the player to a halt while starting a dash.
const DASH_CHARGE_FRICTION := 600.0
# The maximum time the dash can be charged to gain benefit.
const DASH_CHARGE_MAX_TIME := 0.4
const DASH_CHARGE_WIPEOUT_TIME := 1.0

const DASH_GRAVITY := 400.0
const DASH_FRICTION := 100.0
const DASH_BASE_SPEED := 300.0
const DASH_MIN_SPEED_FRACTION := 0.2
const DASH_MAX_SPEED_FRACTION := 0.8
const DASH_MAX_TIME := 0.4
const DASH_MAX_DISTANCE := 150.0

var state : int = State.FALL
var physics_state : int = PhysicsState.AIR
# The normal to the surface the player is on (only valid if `_on_surface`
# returns true).
var surface_normal := Vector2()
var velocity := Vector2()
var facing_direction := -1

# When the player is exhausted, they can no longer skate for a short period.
var exhausted := false
var exhausted_timer := 0.0
var slide_timer := 0.0
var is_skating := false
var is_skating_ballistic := false
# This timer keeps track of how long the player has been skating for.
var skate_timer := 0.0
var skate_boost_timer := 0.0
var wipeout_timer := 0.0
var dash_stored_speed := 0.0
var dash_charge_timer := 0.0
var dash_velocity := Vector2()
var dash_timer := 0.0
var dash_distance := 0.0

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
			|| state == State.SKATE_START \
			|| state == State.SKATE \
			|| state == State.SKATE_BOOST \
			|| state == State.SKATE_BRAKE \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP_BALLISTIC_START \
			|| state == State.JUMP \
			|| state == State.WIPEOUT \
			|| state == State.DASH_CHARGE \
			|| state == State.DASH_START \
			|| state == State.DASH

# "Air states" are the opposite of surface states. Note that a state can be
# both an air state and a surface state. That simply means that the player may
# be on a surface or in the air when they are in that state.
func _is_air_state(state : int) -> bool:
	return state == State.JUMP \
			|| state == State.FALL \
			|| state == State.BALLISTIC \
			|| state == State.WIPEOUT \
			|| state == State.DASH_CHARGE \
			|| state == State.DASH_START \
			|| state == State.DASH

# Returns the fraction of the normal velocity that should be kept over a given
# angle difference.
func _redirect_normal_velocity(angle_difference : float) -> float:
	if self.state == State.SKATE_START \
			|| self.state == State.SKATE \
			|| self.state == State.SKATE_BOOST \
			|| self.state == State.SKATE_BRAKE:
		return clamp((SKATE_MAX_REDIRECT_ANGLE - angle_difference) / SKATE_MAX_REDIRECT_ANGLE, 0.0, 1.0) * SKATE_MAX_REDIRECT_FRACTION
	elif self.state == State.BALLISTIC:
		return clamp((BALLISTIC_MAX_REDIRECT_ANGLE - angle_difference) / BALLISTIC_MAX_REDIRECT_ANGLE, 0.0, 1.0) * BALLISTIC_MAX_REDIRECT_FRACTION
	else:
		return 0.0

func _apply_drag(drag : float, delta : float) -> void:
	if self.velocity.length_squared() > 0.0:
		var drag_delta := -drag * self.velocity.normalized() * delta
		if drag >= 0 && drag_delta.length() >= self.velocity.length():
			self.velocity = Vector2()
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
	if !_state_transition_physics(intent):
		# Only do these state transitions if there wasn't a physics state transition.
		_state_transition(delta, intent)
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
	var move_direction := Vector2()
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
	if Input.is_action_just_pressed("skate"):
		intent.skate_boost = true
	if Input.is_action_just_pressed("skate"):
		intent.skate_start = true
	if Input.is_action_pressed("skate"):
		intent.skate_transition = true
	if Input.is_action_just_pressed("dash"):
		intent.dash_charge = true
	if Input.is_action_just_released("dash"):
		intent.dash_start = true
	return intent

# Updates the facing direction based on the state. Note that the facing
# direction should not affect the logic, only the animations.
func _facing_direction_process(move_direction : Vector2) -> void:
	var next_facing_direction := 0
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	if self.state == State.STAND || self.state == State.WALK || self.state == State.FALL:
		next_facing_direction = int(sign(move_direction.x))
	elif self.state == State.SLIDE:
		if self.physics_state == PhysicsState.SLOPE:
			next_facing_direction = int(sign(self.surface_normal.x))
		elif self.physics_state == PhysicsState.FLOOR:
			next_facing_direction = int(sign(self.velocity.x))
	elif self.state == State.WALL_SLIDE:
		if self.physics_state == PhysicsState.WALL:
			next_facing_direction = int(sign(self.surface_normal.x))
	elif self.state == State.SKATE_START || self.state == State.SKATE || self.state == State.SKATE_BOOST:
		next_facing_direction = int(sign(self.velocity.dot(surface_tangent)))
	elif self.state == State.DASH_CHARGE || self.state == State.DASH_START:
		next_facing_direction = int(sign(move_direction.x))
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
		if self.physics_state == PhysicsState.FLOOR:
			_apply_drag(SLIDE_ACCELERATION, delta)
		elif self.physics_state == PhysicsState.SLOPE || self.physics_state == PhysicsState.WALL:
			if self.velocity.length() > SLIDE_SPEED:
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
		var skate_direction := sign(self.velocity.dot(surface_tangent))
		if skate_direction != 0:
			self.velocity = skate_direction * surface_tangent * SKATE_START_SPEED
	elif self.state == State.SKATE:
		# Apply gravity.
		self.velocity.y += SKATE_GRAVITY * delta
		var braking := false
		if move_direction.x != 0:
			braking = sign(move_direction.x) != sign(self.velocity.dot(surface_tangent))
		if braking:
			_apply_drag(SKATE_BRAKE_ACCELERATION, delta)
		else:
			_apply_drag(SKATE_FRICTION, delta)
	elif self.state == State.SKATE_BOOST:
		# If you boost too early, you wipe out. If you boost too late, it
		# doesn't do very much.
		var skate_direction := sign(self.velocity.dot(surface_tangent))
		var boost_fraction := clamp((SKATE_BOOST_MAX_TIME - self.skate_boost_timer) / (SKATE_BOOST_MAX_TIME - SKATE_BOOST_MIN_TIME), 0.0, 1.0)
		var boost := SKATE_BOOST_MIN_SPEED * boost_fraction + SKATE_BOOST_MAX_SPEED * (1.0 - boost_fraction)
		self.velocity += skate_direction * surface_tangent * boost
	elif self.state == State.WIPEOUT:
		if self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE:
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
	elif self.state == State.DASH_CHARGE:
		_apply_drag(DASH_CHARGE_FRICTION, delta)
	elif self.state == State.DASH_START:
		var dash_fraction := clamp(self.dash_charge_timer / DASH_CHARGE_MAX_TIME, 0.0, 1.0)
		var dash_min_speed = max(self.dash_stored_speed, 0.0) * DASH_MIN_SPEED_FRACTION + DASH_BASE_SPEED
		var dash_max_speed = max(self.dash_stored_speed, 0.0) * DASH_MAX_SPEED_FRACTION + DASH_BASE_SPEED
		var dash_speed = dash_max_speed * dash_fraction + dash_min_speed * (1.0 - dash_fraction)
		if move_direction.length_squared() != 0.0:
			self.velocity = dash_speed * move_direction.normalized()
		else:
			self.velocity = dash_speed * self.facing_direction * Vector2.RIGHT
	elif self.state == State.DASH:
		self.velocity.y += DASH_GRAVITY * delta
		_apply_drag(DASH_FRICTION, delta)
	
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
		# Transition away from previous state.
		# Transition into new state.
		if self.state == State.SLIDE:
			self.slide_timer = 0.0
		elif self.state == State.SKATE:
			self.is_skating = true
			if old_state == State.SKATE_BOOST || old_state == State.SKATE_START:
				self.skate_boost_timer = 0.0
		elif self.state == State.WIPEOUT:
			self.wipeout_timer = 0.0
		elif self.state == State.DASH_CHARGE:
			self.dash_stored_speed = 0.0
			self.dash_charge_timer = 0.0
		elif self.state == State.DASH:
			self.dash_velocity = self.velocity
			self.dash_timer = 0.0
			self.dash_distance = 0.0
		
		if self.state != State.SKATE && self.state != State.SKATE_BOOST && self.state != State.JUMP_BALLISTIC_START && self.state != State.BALLISTIC:
			self.is_skating = false
			self.is_skating_ballistic = false
			self.skate_timer = 0.0
			self.skate_boost_timer = 0.0
		
		return true
	else:
		return false

# This function does state transitions that are required due to physics, which
# basically means air-to-surface and surface-to-air state transitions.
func _state_transition_physics(intent : Intent) -> bool:
	var old_state := self.state
	var impulse := self.velocity.length() - self.previous_velocity.length()
	var fractional_impulse := 0.0
	if self.previous_velocity.length_squared() != 0.0:
		fractional_impulse = impulse / self.previous_velocity.length()
	if _on_surface():
		# If `_on_surface` is true, then the player must be in a surface state.
		# In case the player is not, make a transition into one of the surface
		# states.
		if !_is_surface_state(self.state):
			if self.state == State.BALLISTIC:
				# If the player is ballistic, they will either crash or skate
				# upon collision with the ground.
				if self.velocity.length() >= SKATE_MIN_SPEED && (impulse > -WIPEOUT_MIN_IMPULSE || fractional_impulse > -WIPEOUT_MIN_FRACTIONAL_IMPULSE):
					self.state = State.SKATE
				else:
					self.state = State.WIPEOUT
			else:
				if intent.skate_transition && self.velocity.length() >= SKATE_MIN_SPEED:
					self.state = State.SKATE
				else:
					self.state = _get_default_state(intent)
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
			elif (self.state == State.SKATE || self.state == State.SKATE_BOOST) && self.is_skating_ballistic:
				self.state = State.BALLISTIC
			else:
				self.state = _get_default_state(intent)
	
	if self._on_surface() && !_is_surface_state(self.state):
		printerr("On surface but state ", STATE_NAME[self.state], " is not a surface state.")
	if !self._on_surface() && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")
	
	return _handle_state_transition(old_state)

func _state_transition(delta : float, intent : Intent) -> bool:
	var old_state := self.state
	
	# Since exhaustion is related to allowed state transitions, handle it here.
	if self.exhausted:
		self.exhausted_timer += delta
		if self.exhausted_timer > EXHAUSTED_TIME:
			self.exhausted = false
			self.exhausted_timer = 0.0
	# Update the skating timers.
	if self.is_skating:
		self.skate_timer += delta
		self.skate_boost_timer += delta
	# Impulse is used in a few state transitions.
	var impulse := self.velocity.length() - self.previous_velocity.length()
	var fractional_impulse := 0.0
	if self.previous_velocity.length_squared() != 0.0:
		fractional_impulse = impulse / self.previous_velocity.length()
	
	if self.state == State.STAND:
		if intent.jump:
			self.state = State.JUMP_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif intent.skate_start && !self.exhausted && self.velocity.length() >= SKATE_START_MIN_SPEED:
			self.state = State.SKATE_START
		elif self.physics_state != PhysicsState.FLOOR:
			self.state = _get_default_state(intent)
		elif self.velocity.length() > WALK_MAX_SPEED:
			self.state = State.SLIDE
		elif intent.move_direction.x != 0:
			self.state = State.WALK
	elif self.state == State.WALK:
		if intent.jump:
			self.state = State.JUMP_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif intent.skate_start && !self.exhausted && self.velocity.length() >= SKATE_START_MIN_SPEED:
			self.state = State.SKATE_START
		elif self.physics_state != PhysicsState.FLOOR:
			self.state = _get_default_state(intent)
		elif self.velocity.length() > WALK_MAX_SPEED:
			self.state = State.SLIDE
			self.slide_timer = 0.0
		elif intent.move_direction.x == 0:
			self.state = State.STAND
	elif self.state == State.SLIDE:
		if intent.jump:
			self.state = State.JUMP_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif intent.skate_start && !self.exhausted && self.velocity.length() >= SKATE_START_MIN_SPEED:
			self.state = State.SKATE_START
		elif self.slide_timer < SLIDE_MIN_TIME:
			self.slide_timer += delta
			if self.physics_state != PhysicsState.SLOPE && self.physics_state != PhysicsState.FLOOR:
				self.state = _get_default_state(intent, true)
		elif self.physics_state != PhysicsState.SLOPE:
			self.state = _get_default_state(intent, true)
	elif self.state == State.WALL_SLIDE:
		if intent.jump:
			self.state = State.JUMP_WALL_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif intent.skate_start && !self.exhausted && self.velocity.length() >= SKATE_START_MIN_SPEED:
			self.state = State.SKATE_START
		elif self.physics_state != PhysicsState.WALL:
			self.state = _get_default_state(intent, true)
		elif sign(intent.move_direction.x) == sign(self.surface_normal.x):
			self.state = State.WALL_RELEASE
	elif self.state == State.WALL_RELEASE:
		# Shouldn't happen.
		printerr("Failed to release wall.")
		self.state = _get_default_state(intent)
	elif self.state == State.SKATE_START:
		if intent.jump:
			self.state = State.JUMP_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		else:
			self.state = State.SKATE
	elif self.state == State.SKATE:
		if self.is_skating_ballistic:
			if self.velocity.length() < SKATE_BALLISTIC_MIN_SPEED:
				self.is_skating_ballistic = false
		else:
			if self.velocity.length() > SKATE_MAX_SPEED:
				self.is_skating_ballistic = true
		if intent.jump:
			if self.is_skating_ballistic:
				self.state = State.JUMP_BALLISTIC_START
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.JUMP_WALL_START
			else:
				self.state = State.JUMP_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
			self.state = State.WIPEOUT
		elif self.velocity.length() < SKATE_MIN_SPEED:
			self.state = _get_default_state(intent)
			self.exhausted = true
		elif intent.skate_boost:
			if self.skate_boost_timer < SKATE_BOOST_MIN_TIME:
				self.state = State.WIPEOUT
			else:
				self.state = State.SKATE_BOOST
	elif self.state == State.SKATE_BOOST:
		if intent.jump:
			if self.is_skating_ballistic:
				self.state = State.JUMP_BALLISTIC_START
			elif self.physics_state == PhysicsState.WALL:
				self.state = State.JUMP_WALL_START
			else:
				self.state = State.JUMP_START
		elif intent.dash_charge:
			self.state = State.DASH_CHARGE
		else:
			self.state = State.SKATE
	elif self.state == State.WIPEOUT:
		if (self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE) && self.velocity.length() < WALK_MAX_SPEED:
			self.wipeout_timer += delta
			if self.wipeout_timer > WIPEOUT_TIME:
				self.state = _get_default_state(intent)
	elif self.state == State.JUMP_START:
		# Shouldn't happen.
		printerr("Failed to jump.")
		self.state = _get_default_state(intent)
	elif self.state == State.JUMP_WALL_START:
		printerr("Failed to wall jump.")
		self.state = _get_default_state(intent)
	elif self.state == State.JUMP_BALLISTIC_START:
		printerr("Failed to ballistic jump.")
		self.state = _get_default_state(intent)
	elif self.state == State.JUMP:
		if intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif self.velocity.y >= 0.0:
			self.state = _get_default_state(intent)
	elif self.state == State.FALL:
		if intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif self.velocity.y > FALL_MAX_SPEED_VERTICAL:
			self.state = State.BALLISTIC
	elif self.state == State.BALLISTIC:
		if intent.dash_charge:
			self.state = State.DASH_CHARGE
		elif impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
			self.state = State.WIPEOUT
		elif self.velocity.length() < BALLISTIC_MIN_SPEED:
			self.state = State.FALL
	elif self.state == State.DASH_CHARGE:
		self.dash_charge_timer += delta
		self.dash_stored_speed += self.previous_velocity.length() - self.velocity.length()
		if intent.dash_start:
			self.state = State.DASH_START
		elif self.dash_charge_timer >= DASH_CHARGE_WIPEOUT_TIME:
			self.state = State.WIPEOUT
	elif self.state == State.DASH_START:
		self.state = State.DASH
	elif self.state == State.DASH:
		self.dash_timer += delta
		self.dash_distance += self.velocity.length() * delta
		var disrupted := self.velocity.dot(self.dash_velocity) < (1.0 - 0.1) * self.dash_velocity.length_squared()
		# Enter either the wipeout state, ballistic state, or skating state.
		if disrupted || self.dash_timer > DASH_MAX_TIME || self.dash_distance > DASH_MAX_DISTANCE:
			if _on_surface():
				if self.velocity.length() >= SKATE_MIN_SPEED && (impulse > -WIPEOUT_MIN_IMPULSE || fractional_impulse > -WIPEOUT_MIN_FRACTIONAL_IMPULSE):
					self.state = State.SKATE
				else:
					self.state = State.WIPEOUT
			elif self.velocity.length() >= BALLISTIC_MIN_SPEED:
				self.state = State.BALLISTIC
			else:
				self.state = _get_default_state(intent)
	
	if self._on_surface() && !_is_surface_state(self.state):
		printerr("On surface but state ", STATE_NAME[self.state], " is not a surface state.")
	if !self._on_surface() && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")
	
	return _handle_state_transition(old_state)

# Gets an appropriate choice of state based on the physics state of the player.
# This is used when resetting the player state.
func _get_default_state(intent : Intent, prefer_slide : bool = false) -> int:
	if self.physics_state == PhysicsState.AIR:
		return State.FALL
	elif self.physics_state == PhysicsState.FLOOR:
		var enter_slide := self.velocity.length() >= SLIDE_MIN_SPEED if prefer_slide \
				else self.velocity.length() > WALK_MAX_SPEED
		if enter_slide:
			return State.SLIDE
		elif intent.move_direction.x != 0:
			return State.WALK
		else:
			return State.STAND
	elif self.physics_state == PhysicsState.SLOPE:
		# If landing on a slope, then just slide down it.
		return State.SLIDE
	elif self.physics_state == PhysicsState.WALL:
		return State.WALL_SLIDE
	else:
		printerr("Couldn't get default state for physics state ", PHYSICS_STATE_NAME[self.physics_state])
		return State.STAND

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
		printerr("No animation found for state ", STATE_NAME[self.state])
	if self.animation_player.current_animation != next_animation:
		self.animation_player.play(next_animation)
	
	# Effects.
	if self.state == State.BALLISTIC || (self.state == State.SKATE || self.state == State.SKATE_BOOST) && self.is_skating_ballistic:
		if !self.ballistic_effect_sprite.visible:
			self.ballistic_effect_sprite.visible = true
		self.ballistic_effect_sprite.rotation = self.velocity.angle()
	else:
		self.ballistic_effect_sprite.visible = false
