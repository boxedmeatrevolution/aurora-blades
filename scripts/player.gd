extends KinematicBody2D

# Things that need to be done:
# * Jumping rework:
#   * Jumping goes higher if you hold button.
#   * Jumping pushes you partly in the direction of the normal, and partly
#     upwards.
#   * Three kinds of jumps: Walking jumps go straight up, "moving" jumps put
#     the player into the ballistic state and are affected by normals, and wall
#     jumps which are basically a special type of walking jump.
#   * Well-timed jumps just after hitting the ground can keep the player in
#     ballistic state.
# * Collisions when skating with wall result in wipeout. This should work by
#   checking that if the velocity change from colliding with a surface takes
#   you below the min skating velocity, the player wipes out.
# * Make sliding off of a slope and onto a floor give a small velocity boost,
#   to stop awkward situations where the player keeps trying to walk onto a
#   slope.
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
#   * If the player misses entering the skating state on landing (from coming
#     in at too high of an angle), they will instead wipe out.
#   * The speed requirement is higher in the downward vertical direction than
#     the others, to account for ordinary jumps.
#   * In the ballistic state: air resistance and gravity are lessened.
#   * To enter the ballistic state, do a jump or go flying into the air while
#     skating. A jump will only enter the player into the ballistic state if
#     the player is skating above a critical speed threshold.
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
	WIPEOUT,
	JUMP_START,
	JUMP_WALL_START,
	JUMP_BALLISTIC_START,
	JUMP,
	FALL,
	BALLISTIC,
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
	State.WIPEOUT: "Wipeout",
	State.JUMP_START: "JumpStart",
	State.JUMP_WALL_START: "JumpWallStart",
	State.JUMP_BALLISTIC_START: "JumpBallisticStart",
	State.JUMP: "Jump",
	State.FALL: "Fall",
	State.BALLISTIC: "Ballistic",
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
	var skate_transition := false

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
const SKATE_START_SPEED := 180.0
# Maximum speed gain when getting a perfect boost.
const SKATE_BOOST_MAX_SPEED := 80.0
const SKATE_BOOST_MIN_SPEED := 20.0
const SKATE_MIN_SPEED := 120.0
const SKATE_MAX_SPEED := 1000.0
const SKATE_FRICTION := 50.0
# Friction when going over the max speed or when slowing down.
const SKATE_MAX_FRICTION := 300.0
const SKATE_GRAVITY := 100.0
const SKATE_BOOST_MIN_TIME := 0.4
const SKATE_BOOST_MAX_TIME := 0.8
const SKATE_REDIRECT_ANGLE := 45.0 * PI / 180.0
const SKATE_BALLISTIC_SPEED := 250.0

# The "minimum fractional impulse" needed to wipeout, meaning what percentage
# of the player's speed must be lost in an instant.
const WIPEOUT_MIN_FRACTIONAL_IMPULSE := 0.6
# The "minimum impulse" needed to wipeout, meaning what absolute amount of
# speed must be lost in an instant.
const WIPEOUT_MIN_IMPULSE := 200.0
const WIPEOUT_FRICTION := 500.0
const WIPEOUT_TIME := 1.5

const JUMP_START_SPEED := 300.0
const JUMP_WALL_START_SPEED := 350.0
const JUMP_WALL_START_ANGLE := 35.0 * PI / 180.0
const JUMP_BALLISTIC_START_SPEED := 350.0

const FALL_ACCELERATION := 800.0
const FALL_FRICTION := 100.0
const FALL_MAX_SPEED_HORIZONTAL := 100.0
const FALL_MAX_SPEED_VERTICAL := 800.0

const BALLISTIC_GRAVITY := 800.0
# The angular speed at which the ballistic trajectory can be affected.
const BALLISTIC_ANGULAR_SPEED := 30.0 * PI / 180.0
# The acceleration that is applied to the trajectory if the max speed is
# exceeded. Gravity is also stopped in that case.
const BALLISTIC_ACCELERATION := 400.0
const BALLISTIC_MIN_SPEED := 300.0
const BALLISTIC_MAX_SPEED := 1000.0
const BALLISTIC_REDIRECT_ANGLE := 45.0 * PI / 180.0

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
var skate_boost_timer := 0.0
var wipeout_timer := 0.0

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
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP_BALLISTIC_START \
			|| state == State.JUMP \
			|| state == State.WIPEOUT \
			|| state == State.DASH

# "Air states" are the opposite of surface states. Note that a state can be
# both an air state and a surface state. That simply means that the player may
# be on a surface or in the air when they are in that state.
func _is_air_state(state : int) -> bool:
	return state == State.JUMP \
			|| state == State.FALL \
			|| state == State.BALLISTIC \
			|| state == State.WIPEOUT \
			|| state == State.DASH

# The maximum angle over which the player's velocity will be redirected without
# loss when undergoing a velocity change.
func _max_surface_redirect_angle() -> float:
	if self.state == State.SKATE_START \
			|| self.state == State.SKATE \
			|| self.state == State.SKATE_BOOST:
		return SKATE_REDIRECT_ANGLE
	elif self.state == State.BALLISTIC:
		return BALLISTIC_REDIRECT_ANGLE
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

func _physics_process(delta):
	var intent := _read_intent()
	_facing_direction_process(intent)
	# Update the velocities based on the current state.
	_state_process(delta, intent)
	# Step the position forward by the timestep.
	_position_process(delta)
	# Transition between states.
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
	if Input.is_action_just_pressed("skate"):
		intent.skate_start = true
	if Input.is_action_pressed("skate"):
		intent.skate_transition = true
	return intent

# Updates the facing direction based on the state. Note that the facing
# direction should not affect the logic, only the animations.
func _facing_direction_process(intent : Intent) -> void:
	var next_facing_direction := 0
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	if self.state == State.STAND || self.state == State.WALK || self.state == State.FALL:
		next_facing_direction = int(sign(intent.move_direction.x))
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
	if next_facing_direction != 0:
		self.facing_direction = next_facing_direction

# Updates the velocities based on the current state.
func _state_process(delta : float, intent : Intent) -> void:
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
			self.velocity += intent.move_direction.x * WALK_ACCELERATION * surface_tangent * delta
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
		if intent.move_direction.x != 0:
			braking = sign(intent.move_direction.x) != sign(self.velocity.dot(surface_tangent))
		if braking || self.velocity.length() > SKATE_MAX_SPEED:
			_apply_drag(SKATE_MAX_FRICTION, delta)
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
		# Apply air friction.
		_apply_drag(FALL_FRICTION, delta)
		# Air movement.
		if abs(self.velocity.x) > FALL_MAX_SPEED_HORIZONTAL:
			self.velocity.x -= sign(self.velocity.x) * FALL_ACCELERATION * delta
		else:
			self.velocity.x += intent.move_direction.x * FALL_ACCELERATION * delta
	elif self.state == State.BALLISTIC:
		if self.velocity.length() > BALLISTIC_MAX_SPEED:
			_apply_drag(BALLISTIC_ACCELERATION, delta)
		else:
			self.velocity.y += BALLISTIC_GRAVITY * delta
		var angle_change_direction := sign(self.velocity.angle_to(intent.move_direction))
		if angle_change_direction != 0:
			# When in the ballistic state, the player's direction can be
			# changed, but not the magnitude of the velocity.
			self.velocity = self.velocity.rotated(angle_change_direction * BALLISTIC_ANGULAR_SPEED * delta)
	
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
		if self.velocity.length_squared() != 0.0 && velocity_tangent.length_squared() != 0.0 \
				&& abs(self.velocity.angle_to(velocity_tangent)) <= _max_surface_redirect_angle():
			self.velocity = velocity_tangent.normalized() * self.velocity.length()
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

func _state_transition(delta : float, intent : Intent) -> void:
	# Store the previous state so we can handle transitions at the end.
	var old_state := self.state
	
	# Since exhaustion is related to allowed state transitions, handle it here.
	if self.exhausted:
		self.exhausted_timer += delta
		if self.exhausted_timer > EXHAUSTED_TIME:
			self.exhausted = false
			self.exhausted_timer = 0.0
	# Impulse is used in a few state transitions.
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
				if intent.skate_transition && self.velocity.length() >= SKATE_MIN_SPEED && (impulse > -WIPEOUT_MIN_IMPULSE || fractional_impulse > -WIPEOUT_MIN_FRACTIONAL_IMPULSE):
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
			elif (self.state == State.SKATE || self.state == State.SKATE_BOOST) && self.velocity.length() >= SKATE_BALLISTIC_SPEED:
				self.state = State.BALLISTIC
			else:
				self.state = _get_default_state(intent)
	
	# If the player didn't need to change states to transfer between surface
	# and air states, then do any further transitions here.
	if self.state == old_state:
		if self.state == State.STAND:
			if intent.jump:
				self.state = State.JUMP_START
			elif intent.skate_start && !self.exhausted && self.velocity.length() >= SKATE_START_MIN_SPEED:
				self.state = State.SKATE_START
			elif self.physics_state != PhysicsState.FLOOR:
				self.state = _get_default_state(intent)
			elif self.velocity.length() > WALK_MAX_SPEED:
				self.state = State.SLIDE
				self.slide_timer = 0.0
			elif intent.move_direction.x != 0:
				self.state = State.WALK
		elif self.state == State.WALK:
			if intent.jump:
				self.state = State.JUMP_START
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
			elif self.velocity.length() >= SKATE_MIN_SPEED:
				self.state = State.SKATE
			else:
				# Shouldn't happen.
				printerr("Failed to start skating.")
				self.state = _get_default_state(intent)
		elif self.state == State.SKATE:
			self.skate_boost_timer += delta
			if intent.jump:
				if self.velocity.length() >= SKATE_BALLISTIC_SPEED:
					self.state = State.JUMP_BALLISTIC_START
				elif self.physics_state == PhysicsState.WALL:
					self.state = State.JUMP_WALL_START
				else:
					self.state = State.JUMP_START
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
				if self.velocity.length() >= SKATE_BALLISTIC_SPEED:
					self.state = State.JUMP_BALLISTIC_START
				elif self.physics_state == PhysicsState.WALL:
					self.state = State.JUMP_WALL_START
				else:
					self.state = State.JUMP_START
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
			if self.velocity.y >= 0.0:
				self.state = _get_default_state(intent)
		elif self.state == State.FALL:
			if self.velocity.y > FALL_MAX_SPEED_VERTICAL:
				self.state = State.BALLISTIC
		elif self.state == State.BALLISTIC:
			if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
				self.state = State.WIPEOUT
			elif self.velocity.length() < BALLISTIC_MIN_SPEED:
				self.state = State.FALL
	
	# Handle transitions into and away from different states.
	if old_state != self.state:
		# Transition away from previous state.
		# Transition into new state.
		if self.state == State.SLIDE:
			self.slide_timer = 0.0
		elif self.state == State.SKATE:
			self.skate_boost_timer = 0.0
		elif self.state == State.WIPEOUT:
			self.wipeout_timer = 0.0

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
	if self.state == State.BALLISTIC || (self.state == State.SKATE || self.state == State.SKATE_BOOST) && self.velocity.length() >= SKATE_BALLISTIC_SPEED:
		if !self.ballistic_effect_sprite.visible:
			self.ballistic_effect_sprite.visible = true
		self.ballistic_effect_sprite.rotation = self.velocity.angle()
	else:
		self.ballistic_effect_sprite.visible = false
