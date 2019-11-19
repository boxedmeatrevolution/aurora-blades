extends KinematicBody2D

# Things that need to be done:
# * Use the new wall_collision variable to clean up some code, such as:
#   * Wipeout collisions
#   * Dashing into walls
#   * Jumping into walls and bonk head
#   * Etc.
# * Redirect reservoir: After every velocity redirect, there is a reservoir
#   that slowly empties. When empty, velocity redirects are no longer as
#   efficient. The reservoir refills with time. Purpose: to keep a super-fast
#   player from just whipping around tight bends without consequence. (It looks
#   weird, like the player should be slowed down signficantly).
# * Possibility: A gradual v^2 friction force that is an obstacle to getting
#   very large amounts of velocity.
# * Bugs:
#   * If boosting while the animation is still going, just schedule another
#     boost for right after the current one is finished.
# * Downhill walljumps can feel unintuitive because of the huge gain in
#   velocity after just barely turning around at the top.
# * It's very easy to accidentally dash into the ground, especially when
#   about to land when skating and wanting to boost. There should probably be
#   a ramping friction when starting it in the air, and if you hit the ground
#   it gets canceled.
# * Sometimes just clamp at max velocity instead of doing a reverse
#   acceleration. A reverse acceleration can make velocities go back and forth
#   around the maximum, and can be kind of ugly. Example: wall slide.
# * Make glow only appear when in a "killer" state above a certain velocity.

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
	SKATE_GLIDE,
	SKATE_BRAKE,
	WIPEOUT,
	JUMP_START,
	JUMP_WALL_START,
	JUMP_BALLISTIC_LOW_START,
	JUMP_BALLISTIC_HIGH_START,
	JUMP_BALLISTIC_WALL_LOW_START,
	JUMP_BALLISTIC_WALL_HIGH_START,
	JUMP,
	FALL,
	BALLISTIC,
	DIVE_CHARGE,
	DIVE_START,
	DIVE
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
	State.SKATE_GLIDE: "SkateGlide",
	State.SKATE_BRAKE: "SkateBrake",
	State.WIPEOUT: "Wipeout",
	State.JUMP_START: "JumpStart",
	State.JUMP_WALL_START: "JumpWallStart",
	State.JUMP_BALLISTIC_LOW_START: "JumpBallisticLowStart",
	State.JUMP_BALLISTIC_HIGH_START: "JumpBallisticHighStart",
	State.JUMP_BALLISTIC_WALL_LOW_START: "JumpBallisticWallLowStart",
	State.JUMP_BALLISTIC_WALL_HIGH_START: "JumpBallisticWallHighStart",
	State.JUMP: "Jump",
	State.FALL: "Fall",
	State.BALLISTIC: "Ballistic",
	State.DIVE_CHARGE: "DiveCharge",
	State.DIVE_START: "DiveStart",
	State.DIVE: "Dive"
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
	var jump_low := false
	var jump_high := false
	var dive := false
	var skate_start := false
	var skate_boost := false
	var skate_glide := false
	var skate_brake := false

# Stores information about types of collisions encountered during a physics
# step.
class CollisionInfo:
	var floor_collision := false
	var slope_collision := false
	var wall_collision := false
	var ceiling_collision := false
	
	func merge(other : CollisionInfo) -> void:
		self.floor_collision = self.floor_collision || other.floor_collision
		self.slope_collision = self.slope_collision || other.slope_collision
		self.wall_collision = self.wall_collision || other.wall_collision
		self.ceiling_collision = self.ceiling_collision || other.ceiling_collision

const FLOOR_ANGLE := 5.0 * PI / 180.0
const SLOPE_ANGLE := 85.0 * PI / 180.0
const WALL_ANGLE := 100.0 * PI / 180.0

# If the player is registered as leaving a surface, but the surface remains
# within this distance of the player, then don't let the player leave the
# surface.
const SURFACE_PADDING := 0.5
# How much tolerance to have when searching whether the player should stick to
# nearby surface that is curving away.
const SURFACE_STICK_SEARCH_TOLERANCE := 0.2

# If the player would land on the ground in this amount of time after leaving
# the ground, then don't bother letting the player leave the ground at all.
const SURFACE_DROP_TIME := 0.3

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
const WALK_MAX_SPEED := 200.0

const SLIDE_ACCELERATION := 500.0
const SLIDE_SPEED := 140.0
# Minimum speed before entering a walk.
const SLIDE_MIN_SPEED := 150.0
# Minimum time to slide for on a flat surface before entering a walk.
const SLIDE_MIN_TIME := 0.4

const WALL_SLIDE_ACCELERATION := 600.0
const WALL_SLIDE_SPEED := 50.0
const WALL_RELEASE_START_SPEED := 50.0

# The time that the player remains paused, briefly, at the end of a brake.
const PIVOT_TIME := 0.2

# Speed needed to launch the player into the skating state.
const SKATE_START_MIN_SPEED := 40.0
# Initial speed when entering the skate state.
const SKATE_START_SPEED := 150.0
const SKATE_PIVOT_START_SPEED_FRACTION := 0.8
# The speed gained when making a boost.
const SKATE_BOOST_MAX_SPEED := 110.0
const SKATE_BOOST_MIN_SPEED := 20.0
const SKATE_BOOST_MIN_TIME := 0.1
const SKATE_BOOST_MAX_TIME := 0.8
# The minimum time which the player will feel regular friction at the start
# of the glide.
const SKATE_FRICTION_LOW := 30.0
const SKATE_FRICTION_HIGH := 200.0
const SKATE_FRICTION_TRANSITION_SPEED := 300.0
const SKATE_GLIDE_FRICTION_TIME := 0.1
# Skating friction does not act below this speed. If the player slows down
# below this speed on level ground, they will experience a slight acceleration
# bringing them back up to this speed.
const SKATE_MIN_SPEED := 150.0
const SKATE_ACCELERATION := 150.0

# Friction when the player tries to slow down.
const SKATE_BRAKE_FRICTION := 800.0
# The minimum speed the player can brake to on both slopes and the floor.
const SKATE_BRAKE_MIN_SPEED := 10.0
const SKATE_BRAKE_SLOPE_MIN_SPEED := 100.0

const SKATE_STICK_ANGLE := 30.0 * PI / 180.0
const SKATE_GRAVITY := 400.0
const SKATE_MIN_REDIRECT_ANGLE := 30.0 * PI / 180.0
const SKATE_MAX_REDIRECT_ANGLE := 40.0 * PI / 180.0
const SKATE_MAX_REDIRECT_FRACTION := 1.0

# The "minimum fractional impulse" needed to wipeout, meaning what percentage
# of the player's speed must be lost in an instant.
const WIPEOUT_MIN_FRACTIONAL_IMPULSE := 0.8
# The "minimum impulse" needed to wipeout, meaning what absolute amount of
# speed must be lost in an instant.
const WIPEOUT_MIN_IMPULSE := 300.0
const WIPEOUT_FRICTION := 500.0
const WIPEOUT_TIME := 0.8

const JUMP_START_SPEED := 300.0
const JUMP_WALL_START_SPEED := 350.0
const JUMP_WALL_START_ANGLE := 35.0 * PI / 180.0

const JUMP_BALLISTIC_LOW_BASE_SPEED := 300.0
const JUMP_BALLISTIC_LOW_SPEED_FACTOR := 0.5
const JUMP_BALLISTIC_LOW_SLOPE := 1.2

const JUMP_BALLISTIC_HIGH_BASE_SPEED := 350.0
const JUMP_BALLISTIC_HIGH_SPEED_FACTOR := 0.3
const JUMP_BALLISTIC_HIGH_SLOPE := 2.0

const JUMP_BALLISTIC_WALL_LOW_BASE_SPEED := 200.0
const JUMP_BALLISTIC_WALL_LOW_SPEED_FACTOR := 0.8
const JUMP_BALLISTIC_WALL_LOW_ANGLE := 30.0 * PI / 180.0

const JUMP_BALLISTIC_WALL_HIGH_BASE_SPEED := 350.0
const JUMP_BALLISTIC_WALL_HIGH_SPEED_FACTOR := 0.4
const JUMP_BALLISTIC_WALL_HIGH_ANGLE := 45.0 * PI / 180.0

# The time before the player gains control when doing a ballistic jump.
const JUMP_BALLISTIC_CONTROL_TIME := 0.2

const FALL_ACCELERATION := 800.0
const FALL_FRICTION := 100.0
const FALL_MAX_SPEED_HORIZONTAL := 150.0
const FALL_MAX_SPEED_VERTICAL := 450.0

const BALLISTIC_GRAVITY := 600.0
# The normal acceleration at which the ballistic trajectory can be changed.
const BALLISTIC_ACCELERATION_NORMAL := 400.0
# The forward tangent acceleration at both low and high speeds.
const BALLISTIC_ACCELERATION_TANGENT_FORWARD_LOW := 200.0
const BALLISTIC_ACCELERATION_TANGENT_FORWARD_HIGH := 40.0
const BALLISTIC_ACCELERATION_TANGENT_REVERSE := 200.0
# The acceleration that is applied to the trajectory if the max speed is
# exceeded.
const BALLISTIC_FRICTION_LOW := 30.0
const BALLISTIC_FRICTION_HIGH := 200.0
const BALLISTIC_FRICTION_TRANSITION_SPEED := 400.0
const BALLISTIC_MIN_REDIRECT_ANGLE := 30.0 * PI / 180.0
const BALLISTIC_MAX_REDIRECT_ANGLE := 80.0 * PI / 180.0
const BALLISTIC_MAX_REDIRECT_FRACTION := 0.5

const DIVE_CHARGE_TIME := 0.4
const DIVE_CHARGE_FRICTION := 2000.0
const DIVE_CHARGE_FRICTION_MIN_SPEED := 100.0
const DIVE_CHARGE_SPEED := 80.0
const DIVE_TIME := 0.5
const DIVE_SPEED := 400.0
const DIVE_GRAVITY := 8.0
const DIVE_FRICTION := 50.0

const EFFECT_DRAG_MIN_TIME := 0.3
const EFFECT_DRAG_MIN_PERSIST_TIME := 0.4

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
# Time between boosts.
var skate_boost_timer := 0.0
var skate_glide_timer := 0.0
var wipeout_timer := 0.0
var air_timer := 0.0
# The amount of velocity stored when making a pivot.
var pivot_stored_velocity := 0.0
var pivot_timer := 0.0
var dive_charge_timer := 0.0
var dive_timer := 0.0
var has_dive := true
# For animation purposes, the stride of the skate that the player is currently
# on.
var skate_stride := false

var in_dialogue := false

# Store the previous state as well.
var previous_state := self.state
var previous_physics_state := self.physics_state
# TODO: Should this be initialized with `onready`?
var previous_position := self.position
var previous_velocity := self.velocity

var effect_drag_time := 0.0
var effect_drag_persist_time := 0.0

onready var animation_player := $Sprite/AnimationPlayer
onready var ballistic_effect_sprite := $BallisticEffectSprite
onready var drag_effect_sprite := $DragEffectSprite

onready var skate_brake_effect_a = $SkateA/IceSpray
onready var skate_brake_effect_b = $SkateB/IceSpray

# Is the player on a surface, meaning on a floor, slope, or wall?
func _on_surface(physics_state : int) -> bool:
	return physics_state == PhysicsState.FLOOR \
			|| physics_state == PhysicsState.SLOPE \
			|| physics_state == PhysicsState.WALL

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
			|| state == State.SKATE_GLIDE \
			|| state == State.SKATE_BRAKE \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP_BALLISTIC_LOW_START \
			|| state == State.JUMP_BALLISTIC_HIGH_START \
			|| state == State.JUMP_BALLISTIC_WALL_LOW_START \
			|| state == State.JUMP_BALLISTIC_WALL_HIGH_START \
			|| state == State.JUMP \
			|| state == State.WIPEOUT \
			|| state == State.DIVE_CHARGE

# "Air states" are the opposite of surface states. Note that a state can be
# both an air state and a surface state. That simply means that the player may
# be on a surface or in the air when they are in that state.
func _is_air_state(state : int) -> bool:
	return state == State.FALL \
			|| state == State.BALLISTIC \
			|| state == State.DIVE_START \
			|| state == State.DIVE \
			|| state == State.JUMP \
			|| state == State.WIPEOUT \
			|| state == State.DIVE_CHARGE

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
			|| state == State.WIPEOUT \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP \
			|| state == State.FALL \
			|| state == State.DIVE_CHARGE

# "Skate states" are those related to skating. While in a skate state, the only
# way to transition to a normal state is through braking (SKATE_BRAKE) or
# through wiping out (WIPEOUT).
func _is_skate_state(state : int) -> bool:
	return state == State.SKATE_START \
			|| state == State.SKATE_PIVOT_START \
			|| state == State.SKATE \
			|| state == State.SKATE_BOOST \
			|| state == State.SKATE_GLIDE \
			|| state == State.SKATE_BRAKE \
			|| state == State.JUMP_BALLISTIC_LOW_START \
			|| state == State.JUMP_BALLISTIC_HIGH_START \
			|| state == State.JUMP_BALLISTIC_WALL_LOW_START \
			|| state == State.JUMP_BALLISTIC_WALL_HIGH_START \
			|| state == State.BALLISTIC \
			|| state == State.DIVE_START \
			|| state == State.DIVE

# A "stun state" is one in which the player cannot act.
func _is_stun_state(state : int) -> bool:
	return state == State.WIPEOUT \
			|| state == State.DIVE_CHARGE \
			|| state == State.DIVE_START \
			|| state == State.DIVE \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP_BALLISTIC_LOW_START \
			|| state == State.JUMP_BALLISTIC_HIGH_START \
			|| state == State.JUMP_BALLISTIC_WALL_LOW_START \
			|| state == State.JUMP_BALLISTIC_WALL_HIGH_START

# A "pre-jump state" is one that the player enters right before intentionally
# leaving a surface.
func _is_prejump_state(state : int) -> bool:
	return state == State.WALL_RELEASE \
			|| state == State.JUMP_START \
			|| state == State.JUMP_WALL_START \
			|| state == State.JUMP_BALLISTIC_LOW_START \
			|| state == State.JUMP_BALLISTIC_HIGH_START \
			|| state == State.JUMP_BALLISTIC_WALL_LOW_START \
			|| state == State.JUMP_BALLISTIC_WALL_HIGH_START

# Returns what the tangent velocity should be given the tangent and normal
# components. Both arguments are positive.
func _redirect_velocity(velocity_tangent : float, velocity_normal : float) -> float:
	var angle_difference = atan2(velocity_normal, velocity_tangent)
	var redirect_fraction := _redirect_normal_velocity(angle_difference)
	return Vector2(velocity_tangent, redirect_fraction * velocity_normal).length()

func _redirect_normal_velocity(angle_difference : float) -> float:
	angle_difference = abs(angle_difference)
	if _is_skate_state(self.state):
		var on_surface = _on_surface(self.physics_state)
		var min_redirect_angle := SKATE_MIN_REDIRECT_ANGLE if on_surface else BALLISTIC_MIN_REDIRECT_ANGLE
		var max_redirect_angle := SKATE_MAX_REDIRECT_ANGLE if on_surface else BALLISTIC_MAX_REDIRECT_ANGLE
		var max_redirect_fraction := SKATE_MAX_REDIRECT_FRACTION if on_surface else BALLISTIC_MAX_REDIRECT_FRACTION
		return max_redirect_fraction * clamp((max_redirect_angle - angle_difference) / (max_redirect_angle - min_redirect_angle), 0.0, 1.0)
	else:
		return 0.0

# Returns a range of angles over which the player should "cling" to a surface.
func _surface_stick_max_angle() -> float:
	if _is_prejump_state(self.state):
		return 0.0
	elif _is_skate_state(self.state):
		return SKATE_STICK_ANGLE
	else:
		return 0.0

func _surface_stick_max_slope() -> float:
	var surface_gravity := BALLISTIC_GRAVITY if _is_skate_state(self.state) else GRAVITY
	if _is_prejump_state(self.state):
		return 0.0
	else:
		return 0.5 * surface_gravity / self.velocity.x * SURFACE_DROP_TIME

func _apply_drag(drag : float, delta : float) -> void:
	if self.velocity.length_squared() > 0.0:
		var drag_delta := -drag * self.velocity.normalized() * delta
		if drag >= 0 && drag_delta.length() >= self.velocity.length():
			self.velocity = Vector2.ZERO
		else:
			self.velocity += drag_delta

func _ready() -> void:
	self.ballistic_effect_sprite.visible = false
	self.drag_effect_sprite.visible = false

func _physics_process(delta : float) -> void:
	var move_direction := _read_move_direction()
	# Update the velocities based on the current state.
	_state_process(delta, move_direction)
	# Step the position forward by the timestep.
	var collision_info := _position_process(delta)
	# Transition between states.
	var intent := _read_intent(move_direction)
	if _state_transition_physics(intent):
		intent = _read_intent(move_direction)
	if _state_transition(delta, intent, collision_info):
		intent = _read_intent(move_direction)
	# Update the animation based on the state.
	_facing_direction_process(move_direction)
	_animation_process()
	_effects_process(delta)
	
	# Print the state for debugging purposes.
	if self.previous_state != self.state || self.previous_physics_state != self.physics_state:
		print(PHYSICS_STATE_NAME[self.physics_state], "; ", STATE_NAME[self.state])
	
	self.previous_state = self.state
	self.previous_physics_state = self.physics_state
	self.previous_position = self.position
	self.previous_velocity = self.velocity

func _read_move_direction() -> Vector2:
	if self.in_dialogue:
		return Vector2.ZERO
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
	if self.in_dialogue:
		return Intent.new()
	var intent := Intent.new()
	intent.move_direction = move_direction
	# Get input from the user. The intent structure represents the action that
	# the player wants to do, not the input that the player actually did, so
	# parts of it are conditional on the current state.
	if Input.is_action_just_pressed("jump"):
		if _on_surface(self.physics_state):
			if _is_skate_state(self.state):
				if move_direction.y < 0 || move_direction.x * self.skate_direction < 0:
					intent.jump_high = true
				else:
					intent.jump_low = true
			elif _is_normal_state(self.state):
				intent.jump_high = true
	if _on_surface(self.physics_state):
		if _is_normal_state(self.state):
			if self.state == State.PIVOT:
				if sign(move_direction.x) == -sign(self.pivot_stored_velocity) && Input.is_action_just_pressed("skate"):
					intent.skate_start = true
			else:
				if Input.is_action_just_pressed("skate"):
					intent.skate_start = true
		if _is_skate_state(self.state):
			if self.state != State.SKATE_BRAKE:
				if self.skate_direction == -1 && Input.is_action_pressed("move_right") \
						|| self.skate_direction == 1 && Input.is_action_pressed("move_left"):
					intent.skate_brake = true
				if !_on_surface(self.previous_physics_state) && \
						(self.skate_direction == -1 && Input.is_action_pressed("move_right") \
						|| self.skate_direction == 1 && Input.is_action_pressed("move_left")):
					intent.skate_brake = true
			else:
				if self.skate_direction == -1 && Input.is_action_pressed("move_right") \
						|| self.skate_direction == 1 && Input.is_action_pressed("move_left"):
					intent.skate_brake = true
				else:
					intent.skate_brake = false
			if !intent.skate_brake && Input.is_action_just_pressed("skate"):
				intent.skate_boost = true
		if !intent.skate_brake && Input.is_action_pressed("skate"):
			intent.skate_glide = true
	if Input.is_action_just_pressed("dive"):
		intent.dive = true
	return intent

# Updates the facing direction based on the state. Note that the facing
# direction should not affect the logic, only the animations.
func _facing_direction_process(move_direction : Vector2) -> void:
	var next_facing_direction := 0
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
	elif self.state == State.PIVOT:
		self.velocity = Vector2.ZERO
	elif self.state == State.SKATE_START:
		self.velocity = self.skate_direction * surface_tangent * SKATE_START_SPEED
	elif self.state == State.SKATE_PIVOT_START:
		var skate_speed := SKATE_START_SPEED + SKATE_PIVOT_START_SPEED_FRACTION * max(abs(self.pivot_stored_velocity) - SKATE_START_SPEED, 0.0)
		self.velocity = self.skate_direction * surface_tangent * skate_speed
	elif self.state == State.SKATE || self.state == State.SKATE_GLIDE:
		var friction := SKATE_FRICTION_LOW
		if self.velocity.length() > SKATE_FRICTION_TRANSITION_SPEED:
			friction = SKATE_FRICTION_HIGH
		if self.state == State.SKATE_GLIDE && self.skate_glide_timer > SKATE_GLIDE_FRICTION_TIME:
			friction = SKATE_FRICTION_LOW
		if self.physics_state == PhysicsState.FLOOR:
			if self.velocity.dot(self.skate_direction * surface_tangent) > SKATE_MIN_SPEED:
				_apply_drag(friction, delta)
			else:
				self.velocity += self.skate_direction * surface_tangent * SKATE_ACCELERATION * delta
		else:
			if self.velocity.dot(self.skate_direction * surface_tangent) > SKATE_MIN_SPEED:
				self.velocity += surface_tangent * surface_tangent.dot(SKATE_GRAVITY * Vector2.DOWN) * delta
				_apply_drag(friction, delta)
			else:
				self.velocity += surface_tangent * surface_tangent.dot(GRAVITY * Vector2.DOWN) * delta
	elif self.state == State.SKATE_BOOST:
		var boost := (self.skate_boost_timer - SKATE_BOOST_MIN_TIME) / (SKATE_BOOST_MAX_TIME - SKATE_BOOST_MIN_TIME)
		var velocity_delta := 0.0
		if boost > 1.0:
			velocity_delta = SKATE_BOOST_MAX_SPEED
		elif boost < 0.0:
			velocity_delta = self.skate_boost_timer / SKATE_BOOST_MIN_TIME * SKATE_BOOST_MIN_SPEED
		else:
			velocity_delta = (1.0 - boost) * SKATE_BOOST_MIN_SPEED + boost * SKATE_BOOST_MAX_SPEED
		self.velocity += self.skate_direction * surface_tangent * velocity_delta
	elif self.state == State.SKATE_BRAKE:
		self.velocity += surface_tangent * surface_tangent.dot(SKATE_GRAVITY * Vector2.DOWN) * delta
		if self.velocity.dot(self.skate_direction * surface_tangent) > 0.0:
			if abs(self.surface_normal.angle_to(Vector2.UP)) <= WALK_MAX_ANGLE || self.skate_direction * surface_tangent.y < 0.0 || self.velocity.length() > SKATE_BRAKE_SLOPE_MIN_SPEED:
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
	elif self.state == State.JUMP_BALLISTIC_LOW_START \
			|| self.state == State.JUMP_BALLISTIC_HIGH_START \
			|| self.state == State.JUMP_BALLISTIC_WALL_LOW_START \
			|| self.state == State.JUMP_BALLISTIC_WALL_HIGH_START:
		var high_jump = self.state == State.JUMP_BALLISTIC_HIGH_START || self.state == State.JUMP_BALLISTIC_WALL_HIGH_START
		var wall_jump = self.state == State.JUMP_BALLISTIC_WALL_LOW_START || self.state == State.JUMP_BALLISTIC_WALL_HIGH_START
		var base_speed := 0.0
		var speed_factor := 0.0
		match self.state:
			State.JUMP_BALLISTIC_LOW_START:
				base_speed = JUMP_BALLISTIC_LOW_BASE_SPEED
				speed_factor = JUMP_BALLISTIC_LOW_SPEED_FACTOR
			State.JUMP_BALLISTIC_HIGH_START:
				base_speed = JUMP_BALLISTIC_HIGH_BASE_SPEED
				speed_factor = JUMP_BALLISTIC_HIGH_SPEED_FACTOR
			State.JUMP_BALLISTIC_WALL_LOW_START:
				base_speed = JUMP_BALLISTIC_WALL_LOW_BASE_SPEED
				speed_factor = JUMP_BALLISTIC_WALL_LOW_SPEED_FACTOR
			State.JUMP_BALLISTIC_WALL_HIGH_START:
				base_speed = JUMP_BALLISTIC_WALL_HIGH_BASE_SPEED
				speed_factor = JUMP_BALLISTIC_WALL_HIGH_SPEED_FACTOR
		var jump_speed := base_speed + self.velocity.length() * speed_factor
		var jump_angle := -PI / 2.0
		if wall_jump:
			var angle_increase := JUMP_BALLISTIC_WALL_HIGH_ANGLE if high_jump else JUMP_BALLISTIC_WALL_LOW_ANGLE
			var surface_angle := (-sign(self.skate_direction) * surface_tangent).angle_to(Vector2.RIGHT)
			jump_angle = surface_angle - float(self.skate_direction) * angle_increase
		elif surface_tangent.x != 0.0:
			var slope_increase := JUMP_BALLISTIC_HIGH_SLOPE if high_jump else JUMP_BALLISTIC_LOW_SLOPE
			var surface_slope := float(self.skate_direction) * surface_tangent.y / surface_tangent.x
			var jump_slope := surface_slope - slope_increase
			jump_angle = atan2(jump_slope, float(self.skate_direction))
		var jump_velocity := jump_speed * Vector2(cos(jump_angle), sin(jump_angle))
		self.velocity = jump_velocity
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
		var is_high_speed := self.velocity.length() > BALLISTIC_FRICTION_TRANSITION_SPEED
		var friction := BALLISTIC_FRICTION_HIGH if is_high_speed else BALLISTIC_FRICTION_LOW
		_apply_drag(friction, delta)
		self.velocity.y += BALLISTIC_GRAVITY * delta
		if self.air_timer >= JUMP_BALLISTIC_CONTROL_TIME:
			var velocity_normal := Vector2(-self.velocity.y, self.velocity.x)
			var velocity_tangent := self.velocity
			if velocity_tangent.length_squared() != 0.0 && velocity_normal.length_squared() != 0.0:
				velocity_normal = velocity_normal.normalized()
				velocity_tangent = velocity_tangent.normalized()
				if move_direction.length_squared() != 0.0:
					# To choose the acceleration vector, we treat the allowed
					# accelerations as a splicing of two ellipses.
					var direction := move_direction.normalized()
					var normal_component := velocity_normal.dot(direction)
					var tangent_component := velocity_tangent.dot(direction)
					normal_component /= BALLISTIC_ACCELERATION_NORMAL
					if direction.dot(velocity_tangent) > 0.0:
						tangent_component /= BALLISTIC_ACCELERATION_TANGENT_FORWARD_HIGH if is_high_speed else BALLISTIC_ACCELERATION_TANGENT_FORWARD_LOW
					else:
						tangent_component /= -BALLISTIC_ACCELERATION_TANGENT_REVERSE
					var scale := sqrt(1.0 / (normal_component * normal_component + tangent_component * tangent_component))
					self.velocity += scale * direction * delta
	elif self.state == State.DIVE_CHARGE:
		if self.velocity.length() >= DIVE_CHARGE_FRICTION_MIN_SPEED:
			_apply_drag(DIVE_CHARGE_FRICTION, delta)
		else:
			self.velocity = DIVE_CHARGE_SPEED * Vector2.UP
	elif self.state == State.DIVE_START:
		var direction := move_direction
		if direction.length_squared() == 0.0:
			direction = Vector2(self.facing_direction, 1.0)
		direction = direction.normalized()
		self.velocity = DIVE_SPEED * direction
	elif self.state == State.DIVE:
		self.velocity.y += DIVE_GRAVITY
		_apply_drag(DIVE_FRICTION, delta)
	
	# Clamp the velocity by the absolute max speed.
	self.velocity = self.velocity.clamped(MAX_SPEED)

# Steps the position forward by a small amount based on the current velocity.
func _position_process(delta : float, n : int = 4) -> CollisionInfo:
	var collision_info := CollisionInfo.new()
	# Exit if the maximum number of iterations has been reached.
	if n <= 0 || delta <= 0 || self.velocity.length_squared() == 0:
		return collision_info
	var delta_remainder := 0.0
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
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
	elif _on_surface(self.physics_state) && collision == null:
		delta_remainder = 0.0
		# If the player used to be on a surface, then we should try to stick
		# to whatever surface may still be below them. We do this in two ways:
		# First, by checking for a surface at some slope beneath the player,
		# and second, by checking for a surface at some angle beneath the
		# player.
		var tolerance_factor := 1.0 + SURFACE_STICK_SEARCH_TOLERANCE
		if self.velocity.x != 0:
			var velocity_slope := self.velocity.y / self.velocity.x
			var max_slope_change := _surface_stick_max_slope()
			if max_slope_change > 0.0:
				var extreme_slope := velocity_slope + max_slope_change
				var test_displacement := tolerance_factor * Vector2.DOWN * velocity.x * delta * max_slope_change
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
		if !found_new_surface:
			var max_angle_change := _surface_stick_max_angle()
			if max_angle_change > 0.0:
				var test_displacement := tolerance_factor * (self.velocity - self.velocity.rotated(-sign(self.velocity.dot(surface_tangent)) * max_angle_change)) * delta
				var test_collision := move_and_collide(test_displacement, true, true, true)
				if test_collision != null && test_collision.normal.y < 0:
					var surface_angle := test_collision.normal.angle_to(Vector2.UP)
					var surface_angle_relative := test_collision.normal.angle_to(self.surface_normal)
					if abs(surface_angle) <= WALL_ANGLE && abs(surface_angle_relative) <= max_angle_change:
						self.position += test_collision.travel
						found_new_surface = true
						new_surface_normal = test_collision.normal
	# If the player landed on a new surface, we need to adjust the state.
	if found_new_surface:
		# First, modify the velocity as the player moves onto the surface.
		var velocity_tangent := self.velocity.slide(new_surface_normal)
		var velocity_normal := self.velocity.dot(new_surface_normal) * new_surface_normal
		if velocity_tangent.length_squared() != 0.0 && self.velocity.length_squared() != 0.0:
			self.velocity = velocity_tangent.normalized() * _redirect_velocity(velocity_tangent.length(), velocity_normal.length())
		else:
			self.velocity = velocity_tangent
		# Record information about the collision.
		collision_info.merge(_handle_collision_physics_state_transition(new_surface_normal))
	# Before committing to the new surface, make sure that there isn't a
	# better choice of surface to be on by looking in the direction of the
	# last surface the player was on.
	if _on_surface(self.physics_state):
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
					self.velocity = self.velocity.slide(test_collision.normal)
					found_new_surface = true
					new_surface_normal = test_normal
	if found_new_surface:
		collision_info.merge(_handle_collision_physics_state_transition(new_surface_normal))
		self.surface_normal = new_surface_normal
	else:
		self.physics_state = PhysicsState.AIR
	collision_info.merge(_position_process(delta_remainder, n - 1))
	return collision_info

func _handle_collision_physics_state_transition(new_surface_normal : Vector2) -> CollisionInfo:
	var collision_info := CollisionInfo.new()
	var new_surface_angle := new_surface_normal.angle_to(Vector2.UP)
	if abs(new_surface_angle) <= FLOOR_ANGLE:
		self.physics_state = PhysicsState.FLOOR
		collision_info.floor_collision = true
	elif abs(new_surface_angle) <= SLOPE_ANGLE:
		self.physics_state = PhysicsState.SLOPE
		collision_info.slope_collision = true
	elif abs(new_surface_angle) <= WALL_ANGLE:
		self.physics_state = PhysicsState.WALL
		collision_info.wall_collision = true
	else:
		self.physics_state = PhysicsState.AIR
		collision_info.ceiling_collision = true
	return collision_info

# Handle transitions into and away from different states.
func _handle_state_transition(old_state : int) -> bool:
	if old_state != self.state:
		# First handle transitions between skate states and non-skate states.
		if !_is_skate_state(self.state) && _is_skate_state(old_state):
			pass
		if _is_skate_state(self.state) && !_is_skate_state(old_state):
			self.skate_timer = 0.0
		if _is_surface_state(self.state) && _is_skate_state(self.state) && (!_is_surface_state(old_state) || !_is_skate_state(old_state)):
			var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
			self.skate_direction = int(sign(self.velocity.dot(surface_tangent)))
			if self.skate_direction == 0:
				self.skate_direction = self.facing_direction
		
		if old_state == State.SKATE_BOOST:
			self.skate_boost_timer = 0.0
		
		if self.state == State.PIVOT:
			self.pivot_timer = 0.0
		elif self.state == State.SLIDE:
			self.slide_timer = 0.0
		elif self.state == State.SKATE_PIVOT_START:
			self.skate_direction = -int(sign(self.pivot_stored_velocity))
			if self.skate_direction == 0:
				self.skate_direction = self.facing_direction
		elif self.state == State.SKATE_BOOST:
			self.skate_stride = !self.skate_stride
		elif self.state == State.SKATE_GLIDE:
			self.skate_glide_timer = 0.0
		elif self.state == State.SKATE_BRAKE:
			self.pivot_stored_velocity = 0.0
		elif self.state == State.DIVE_CHARGE:
			self.dive_charge_timer = 0.0
			self.has_dive = false
		elif self.state == State.DIVE:
			self.dive_timer = 0.0
		elif self.state == State.WIPEOUT:
			self.wipeout_timer = 0.0
		return true
	else:
		return false

# This function does state transitions that are required due to physics, which
# basically means air-to-surface and surface-to-air state transitions.
func _state_transition_physics(intent : Intent) -> bool:
	var old_state := self.state
	if _on_surface(self.physics_state):
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
			if _is_prejump_state(self.state):
				if _is_skate_state(self.state):
					self.state = State.BALLISTIC
				elif self.state == State.WALL_RELEASE:
					self.state = State.FALL
				else:
					self.state = State.JUMP
			elif _is_skate_state(self.state):
				self.state = _get_default_skate_state(intent)
			elif _is_normal_state(self.state):
				self.state = _get_default_normal_state(intent)
			else:
				self.state = State.WIPEOUT
	
	if self._on_surface(self.physics_state) && !_is_surface_state(self.state):
		printerr("On surface but state ", STATE_NAME[self.state], " is not a surface state.")
	if !self._on_surface(self.physics_state) && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")
	
	return _handle_state_transition(old_state)

func _state_transition(delta : float, intent : Intent, collision_info : CollisionInfo) -> bool:
	var old_state := self.state
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	var can_act := !_is_stun_state(self.state)
	# The reason we check for not being in an air state (instead of being in a
	# ground state) is because some states (like JUMP) are both air states and
	# ground states, but should not restock dives.
	self.air_timer += delta
	if !_is_air_state(self.state):
		self.has_dive = true
		self.air_timer = 0.0
	
	if _is_normal_state(self.state):
		# Input transitions take priority over all else.
		if can_act && intent.jump_high && _is_surface_state(self.state) && self.state != State.JUMP:
			if self.physics_state == PhysicsState.WALL:
				self.state = State.JUMP_WALL_START
			else:
				self.state = State.JUMP_START
		elif can_act && intent.dive && self.has_dive:
			self.state = State.DIVE_CHARGE
		elif can_act && intent.skate_start && self.state == State.PIVOT && self.pivot_stored_velocity != 0.0:
			self.state = State.SKATE_PIVOT_START
		elif can_act && intent.skate_start && _is_surface_state(self.state) && self.state != State.JUMP && self.velocity.length() >= SKATE_START_MIN_SPEED:
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
		elif self.state == State.WIPEOUT:
			if (self.physics_state == PhysicsState.FLOOR || self.physics_state == PhysicsState.SLOPE) && self.velocity.length() < WALK_MAX_SPEED:
				self.wipeout_timer += delta
				if self.wipeout_timer > WIPEOUT_TIME:
					self.state = _get_default_normal_state(intent)
		elif self.state == State.JUMP_START:
			# Shouldn't happen.
			printerr("Failed to jump.")
			self.state = _get_default_normal_state(intent)
		elif self.state == State.JUMP_WALL_START:
			printerr("Failed to wall jump.")
			self.state = _get_default_normal_state(intent)
		elif self.state == State.JUMP:
			if !_on_surface(self.physics_state):
				self.state = _get_default_normal_state(intent)
			if self.velocity.y >= 0.0:
				self.state = _get_default_normal_state(intent)
		elif self.state == State.FALL:
			pass
		elif self.state == State.DIVE_CHARGE:
			self.dive_charge_timer += delta
			if self.dive_charge_timer > DIVE_CHARGE_TIME:
				self.state = State.DIVE_START
	elif _is_skate_state(self.state):
		self.skate_timer += delta
		self.skate_boost_timer += delta
		if _on_surface(self.physics_state):
			if self.velocity.dot(self.skate_direction * surface_tangent) < 0.0:
				if self.physics_state == PhysicsState.SLOPE || self.physics_state == PhysicsState.WALL:
					self.skate_direction = -self.skate_direction
				else:
					printerr("Flipped skate direction on floor.")
		else:
			var velocity_sign := int(sign(self.velocity.x))
			if velocity_sign * self.skate_direction == -1:
				self.skate_direction = velocity_sign
		
		# Impulse is used to determine if the player has crashed into a wall.
		var impulse := self.velocity.length() - self.previous_velocity.length()
		var fractional_impulse := 0.0
		if self.previous_velocity.length_squared() != 0.0:
			fractional_impulse = impulse / self.previous_velocity.length()
		
		if _on_surface(self.physics_state) && self.physics_state != PhysicsState.WALL && (collision_info.wall_collision || collision_info.ceiling_collision):
			if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
				self.state = State.WIPEOUT
			else:
				self.state = _get_default_normal_state(intent)
		elif can_act && intent.dive && self.has_dive:
			self.state = State.DIVE_CHARGE
		elif can_act && (intent.jump_low || intent.jump_high) && _is_surface_state(self.state):
			if self.physics_state == PhysicsState.WALL:
				if intent.jump_high:
					self.state = State.JUMP_BALLISTIC_WALL_HIGH_START
				else:
					self.state = State.JUMP_BALLISTIC_WALL_LOW_START
			else:
				if intent.jump_high:
					self.state = State.JUMP_BALLISTIC_HIGH_START
				else:
					self.state = State.JUMP_BALLISTIC_LOW_START
		# TODO: decide on additional condition like:
		# (abs(self.surface_normal.angle_to(Vector2.UP)) <= WALK_MAX_ANGLE || self.skate_direction == int(sign(self.surface_normal.x)))
		elif can_act && intent.skate_brake && _is_surface_state(self.state) && self.state != State.SKATE_BRAKE:
			self.state = State.SKATE_BRAKE
		elif can_act && !intent.skate_brake && self.state == State.SKATE_BRAKE:
			self.state = State.SKATE
		elif self.state == State.SKATE_START:
			self.state = State.SKATE
		elif self.state == State.SKATE_PIVOT_START:
			self.state = State.SKATE
		elif intent.skate_boost && _is_surface_state(self.state) && self.state != State.SKATE_BOOST:
			self.state = State.SKATE_BOOST
		elif intent.skate_glide && _is_surface_state(self.state) && self.state != State.SKATE_GLIDE:
			self.state = State.SKATE_GLIDE
		elif !intent.skate_glide && self.state == State.SKATE_GLIDE:
			self.state = State.SKATE
		elif self.state == State.SKATE:
			pass
		elif self.state == State.SKATE_GLIDE:
			self.skate_glide_timer += delta
			if !intent.skate_glide:
				self.state = State.SKATE
		elif self.state == State.SKATE_BOOST:
			self.state = State.SKATE
		elif self.state == State.SKATE_BRAKE:
			self.pivot_stored_velocity += (self.previous_velocity - self.velocity).dot(surface_tangent)
			if abs(self.surface_normal.angle_to(Vector2.UP)) <= WALK_MAX_ANGLE && self.velocity.length() < SKATE_BRAKE_MIN_SPEED:
				self.state = State.PIVOT
		elif self.state == State.BALLISTIC:
			if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_FRACTIONAL_IMPULSE:
				self.state = State.WIPEOUT
		elif self.state == State.JUMP_BALLISTIC_LOW_START \
				|| self.state == State.JUMP_BALLISTIC_HIGH_START \
				|| self.state == State.JUMP_BALLISTIC_WALL_LOW_START \
				|| self.state == State.JUMP_BALLISTIC_WALL_HIGH_START:
			printerr("Failed to ballistic jump.")
			self.state = _get_default_normal_state(intent)
		elif self.state == State.DIVE_START:
			self.state = State.DIVE
		elif self.state == State.DIVE:
			self.dive_timer += delta
			if self.dive_timer > DIVE_TIME:
				self.state = State.BALLISTIC
	
	if self._on_surface(self.physics_state) && !_is_surface_state(self.state):
		printerr("On surface but state ", STATE_NAME[self.state], " is not a surface state.")
	if !self._on_surface(self.physics_state) && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")
	
	return _handle_state_transition(old_state)

# Gets an appropriate choice of state based on the physics state of the player.
# This is used when resetting the player state.
func _get_default_normal_state(intent : Intent, prefer_slide : bool = false) -> int:
	if !_on_surface(self.physics_state):
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
	elif intent.skate_glide:
		return State.SKATE_GLIDE
	else:
		return State.SKATE

func _animation_process() -> void:
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
	elif self.state == State.SKATE || self.state == State.SKATE_GLIDE:
		var playing_stride_a = (current_animation == "SkateBoostLeftA" || current_animation == "SkateBoostRightA")
		var playing_stride_b = (current_animation == "SkateBoostLeftB" || current_animation == "SkateBoostRightB")
		if self.skate_stride && (!is_playing || !playing_stride_a):
			if self.facing_direction == -1:
				next_animation = "SkateLeftA"
			else:
				next_animation = "SkateRightA"
		elif !self.skate_stride && (!is_playing || !playing_stride_b):
			if self.facing_direction == -1:
				next_animation = "SkateLeftB"
			else:
				next_animation = "SkateRightB"
	elif self.state == State.SKATE_START || self.state == State.SKATE_BOOST || self.state == State.SKATE_PIVOT_START:
		if self.skate_stride:
			if self.facing_direction == -1:
				next_animation = "SkateBoostLeftA"
			else:
				next_animation = "SkateBoostRightA"
		else:
			if self.facing_direction == -1:
				next_animation = "SkateBoostLeftB"
			else:
				next_animation = "SkateBoostRightB"
	elif self.state == State.SKATE_BRAKE || self.state == State.PIVOT:
		if self.facing_direction == -1:
			next_animation = "SkateBrakeLeft"
		else:
			next_animation = "SkateBrakeRight"
	elif self.state == State.WIPEOUT:
		if self.facing_direction == -1:
			next_animation = "WipeoutLeft"
		else:
			next_animation = "WipeoutRight"
	elif _is_prejump_state(self.state) || self.state == State.JUMP || self.state == State.FALL:
		if self.velocity.y < 0.0:
			if self.facing_direction == -1:
				next_animation = "JumpLeft"
			else:
				next_animation = "JumpRight"
		else:
			if self.facing_direction == -1:
				next_animation = "FallLeft"
			else:
				next_animation = "FallRight"
	elif self.state == State.BALLISTIC:
		if self.velocity.y < 0.0:
			if self.facing_direction == -1:
				next_animation = "BallisticJumpLeft"
			else:
				next_animation = "BallisticJumpRight"
		else:
			if self.facing_direction == -1:
				next_animation = "BallisticFallLeft"
			else:
				next_animation = "BallisticFallRight"
	elif self.state == State.DIVE_CHARGE:
		if self.facing_direction == -1:
			next_animation = "DiveChargeLeft"
		else:
			next_animation = "DiveChargeRight"
	elif self.state == State.DIVE_START || self.state == State.DIVE:
		if self.facing_direction == -1:
			next_animation = "DiveLeft"
		else:
			next_animation = "DiveRight"
	else:
		printerr("No animation found for state ", STATE_NAME[self.state])
	if self.animation_player.current_animation != next_animation:
		self.animation_player.play(next_animation)

func _effects_process(delta : float) -> void:
#	if self.state == State.BALLISTIC:
#		self.ballistic_effect_sprite.visible = true
#		self.ballistic_effect_sprite.rotation = self.velocity.angle()
#	else:
#		self.ballistic_effect_sprite.visible = false
	
	var drag_condition = self.state == State.SKATE && self.velocity.length() > SKATE_FRICTION_TRANSITION_SPEED
	self.drag_effect_sprite.rotation = -self.velocity.angle_to(Vector2.RIGHT)
	if !drag_condition:
		self.effect_drag_time = 0.0
	if self.drag_effect_sprite.visible:
		self.effect_drag_persist_time += delta
		if !drag_condition && (!_on_surface(self.physics_state) || self.effect_drag_persist_time > EFFECT_DRAG_MIN_PERSIST_TIME):
			self.drag_effect_sprite.visible = false
	else:
		self.effect_drag_time += delta
		if self.effect_drag_time > EFFECT_DRAG_MIN_TIME:
			self.drag_effect_sprite.visible = true
			self.effect_drag_persist_time = 0.0
	
	if self.state == State.SKATE_BRAKE:
		self.skate_brake_effect_a.set_emitting(true, abs(self.velocity.length()))
		self.skate_brake_effect_b.set_emitting(true, abs(self.velocity.length()))
		self.skate_brake_effect_a.scale.x = self.skate_direction
		self.skate_brake_effect_b.scale.x = self.skate_direction
	else:
		self.skate_brake_effect_a.set_emitting(false)
		self.skate_brake_effect_b.set_emitting(false)

func _on_dialogue_start():
	self.in_dialogue = true

func _on_dialogue_end():
	self.in_dialogue = false
