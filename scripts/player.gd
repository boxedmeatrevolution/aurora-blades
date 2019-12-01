extends KinematicBody2D

const Checkpoint := preload("res://scripts/checkpoint.gd")
const Hazard := preload("res://scripts/hazard.gd")
const Score := preload("res://scripts/score.gd")

const AUDIO_SKATE_BOOST_1 := preload("res://sounds/skate_boost_1.wav")
const AUDIO_SKATE_BOOST_2 := preload("res://sounds/skate_boost_2.wav")
const AUDIO_SKATE_BOOST_3 := preload("res://sounds/skate_boost_3.wav")
const AUDIO_SKATE_BOOST_4 := preload("res://sounds/skate_boost_4.wav")

# Things that need to be done:

# * Make grading show which area you were weakest in.
# * Symbol that pulses at the beat for tutorial.
# * Ensure player sees dash tip.
# * Camera behind player.
# * Flip player sprite around when charging a dash for backwards.
# * Make respawning happen faster.
# * Allow "late jumps".
# * Jump particles
# * Bug when player dashes into ground (should get only the final velocity of
#   the dash, not the instantaneous velocity).
# * Make wall jumps feel better when walking (some delay after letting go when
#   tapping arrows?)
# * Faster dash with less levitation.
# * Double tap arrows to enter skate, tap arrows to boost.
# * Fix snow falling particles.
# * Fix buggy movement over slopes with player. (Not sticking to slopes)
# * Bug: facing direction needs to be flipped around only once the
#   jump_surface_velocity_x variable has become positive.

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
	var skate_brake := false
	var restart := false

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
	
	func has_collision() -> bool:
		return self.floor_collision || self.slope_collision || self.wall_collision || self.ceiling_collision

signal score(score_delta)
signal death(player, respawn_player)
signal spawn(player)
signal win()

const FLOOR_ANGLE := 5.0 * PI / 180.0
const SLOPE_ANGLE := 85.0 * PI / 180.0
const WALL_ANGLE := 100.0 * PI / 180.0

const CHECKPOINT_SPAWN_HEIGHT := 12.0

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
const MAX_SPEED := 2000.0
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

const SKATE_FRICTION := 30.0
# Skating friction does not act below this speed. If the player slows down
# below this speed on level ground, they will experience a slight acceleration
# bringing them back up to this speed.
const SKATE_MIN_SPEED := 150.0
const SKATE_ACCELERATION := 150.0
# Speed needed to launch the player into the skating state.
const SKATE_START_MIN_SPEED := 40.0
# Initial speed when entering the skate state.
const SKATE_START_SPEED := 150.0
const SKATE_PIVOT_START_SPEED_FRACTION := 0.65

# The time over which the landing velocity is interpolated to the true
# velocity.
const SKATE_LANDING_TIME := 0.3

const SKATE_STICK_ANGLE := 30.0 * PI / 180.0
const SKATE_GRAVITY := 400.0
const SKATE_MIN_REDIRECT_ANGLE := 30.0 * PI / 180.0
const SKATE_MAX_REDIRECT_ANGLE := 40.0 * PI / 180.0
const SKATE_MAX_REDIRECT_FRACTION := 1.0

# The speed gained when making a boost.
const SKATE_BOOST_MAX_SPEED := 110.0
const SKATE_BOOST_MIN_SPEED := 20.0
const SKATE_BOOST_MIN_TIME := 0.1
const SKATE_BOOST_MAX_TIME := 0.8
# The period of time over which the player will feel increased friction when
# boosting.
const SKATE_BOOST_FRICTION_TIME := 0.18
const SKATE_BOOST_FRICTION_LOW := 30.0
const SKATE_BOOST_FRICTION_HIGH := 180.0
const SKATE_BOOST_FRICTION_TRANSITION_SPEED := 200.0

# Friction when the player tries to slow down.
const SKATE_BRAKE_FRICTION := 800.0
# The minimum speed the player can brake to on both slopes and the floor.
const SKATE_BRAKE_MIN_SPEED := 10.0
const SKATE_BRAKE_SLOPE_MIN_SPEED := 100.0

# The "minimum fractional impulse" needed to wipeout, meaning what percentage
# of the player's speed must be lost in an instant.
const WIPEOUT_MIN_IMPULSE_FRACTION := 0.8
# The "minimum impulse" needed to wipeout, meaning what absolute amount of
# speed must be lost in an instant.
const WIPEOUT_MIN_IMPULSE := 300.0
const WIPEOUT_FRICTION := 500.0
const WIPEOUT_TIME := 0.8

const JUMP_START_SPEED := 300.0
const JUMP_WALL_START_SPEED := 350.0
const JUMP_WALL_START_ANGLE := 35.0 * PI / 180.0

# The speed that is required for a ballistic jump to reach its full angle.
const JUMP_BALLISTIC_FULL_ANGLE_SPEED := 300.0

const JUMP_BALLISTIC_LOW_BASE_SPEED := 100.0
const JUMP_BALLISTIC_LOW_SPEED_FACTOR := 0.8
const JUMP_BALLISTIC_LOW_SLOPE := 1.0
const JUMP_BALLISTIC_LOW_SLOPE_MIN := 0.2

const JUMP_BALLISTIC_HIGH_BASE_SPEED := 200.0
const JUMP_BALLISTIC_HIGH_SPEED_FACTOR := 0.6
const JUMP_BALLISTIC_HIGH_SLOPE := 1.5
const JUMP_BALLISTIC_HIGH_SLOPE_MIN := 0.5

const JUMP_BALLISTIC_WALL_BASE_SPEED := 300.0
const JUMP_BALLISTIC_WALL_SPEED_FACTOR := 0.2
const JUMP_BALLISTIC_WALL_ANGLE_MIN := 45.0 * PI / 180.0
const JUMP_BALLISTIC_WALL_ANGLE_MAX := 60.0 * PI / 180.0
const JUMP_BALLISTIC_WALL_TRANSITION_SPEED := 200.0

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
const BALLISTIC_MAX_REDIRECT_ANGLE := 60.0 * PI / 180.0
const BALLISTIC_MAX_REDIRECT_FRACTION := 0.6

const DIVE_CHARGE_TIME := 0.4
const DIVE_CHARGE_FRICTION := 2000.0
const DIVE_CHARGE_FRICTION_MIN_SPEED := 100.0
const DIVE_CHARGE_SPEED := 80.0
const DIVE_DISTANCE := 150.0
const DIVE_SPEED_START := 700.0
const DIVE_SPEED_END := 200.0
const DIVE_GRAVITY := 0.0
# The minimum impulse needed to leave a dive.
const DIVE_MIN_IMPULSE_FRACTION := 0.1
# The distance which is checked to be collision free before starting a dive.
const DIVE_CHECK_DISTANCE := 16.0

# Variables that are persistent between deaths.
var checkpoint : Checkpoint = null
var respawn_position := self.position
var in_dialogue := false
var win := false

var dying := false
var dead := false
var state : int = State.FALL
var physics_state : int = PhysicsState.AIR
# The normal to the surface the player is on (only valid if `_is_surface_physics_state`
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
var wipeout_timer := 0.0
var air_timer := 0.0
# The amount of velocity stored when making a pivot.
var pivot_stored_velocity := 0.0
var pivot_timer := 0.0
var dive_charge_timer := 0.0
var dive_timer := 0.0
var has_dive := false
# These members keep track of what the effective velocity the player has on the
# surface is, for the purpose of making the next jump. 
var skate_landing_velocity_x := 0.0
var skate_landing_timer := 0.0
# For animation purposes, the stride of the skate that the player is currently
# on.
var skate_stride := false

# Store the previous state as well.
var previous_state : int = State.FALL
var previous_physics_state : int = PhysicsState.AIR
var previous_position := Vector2.ZERO
var previous_velocity := Vector2.ZERO
var previous_skate_direction := 1

# Stores a list of coins that have been picked up since the last checkpoint
# that will need to be returned if the player dies.
var score_list := []

onready var score_area2d := $ScoreArea2D
onready var checkpoint_area2d := $CheckpointArea2D
onready var win_area2d := $WinArea2D
onready var hazard_area2d := $HazardArea2D

onready var sprite := $Sprite
onready var animation_player := $Sprite/AnimationPlayer
onready var walk_audio := $WalkAudio
onready var jump_audio := $JumpAudio
onready var land_audio := $LandAudio
onready var skate_audio := $SkateAudio
onready var skate_boost_audio := $SkateBoostAudio
onready var skate_brake_audio := $SkateBrakeAudio
onready var skate_brake_continuous_audio := $SkateBrakeContinuousAudio
onready var skate_jump_audio := $SkateJumpAudio
onready var skate_land_audio := $SkateLandAudio
onready var dive_charge_audio := $DiveChargeAudio
onready var dive_audio := $DiveAudio
onready var death_audio := $DeathAudio

onready var skate_brake_effect_a := $SkateA/IceSpray
onready var skate_brake_effect_b := $SkateB/IceSpray
onready var skate_trail_effect_a := $SkateA/SkateTrail
onready var skate_trail_effect_b := $SkateB/SkateTrail
onready var dive_trail_effect_a := $SkateA/DiveTrail
onready var dive_trail_effect_b := $SkateB/DiveTrail
onready var jump_burst_effect_a := $SkateA/JumpBurst
onready var jump_burst_effect_b := $SkateB/JumpBurst
onready var dive_charge_effect := $DiveCharge
onready var death_burst_effect := $DeathBurst

func _is_air_physics_state(physics_state : int) -> bool:
	return physics_state == PhysicsState.AIR

# Is the player on a surface, meaning on a floor, slope, or wall?
func _is_surface_physics_state(physics_state : int) -> bool:
	return physics_state == PhysicsState.FLOOR \
			|| physics_state == PhysicsState.SLOPE \
			|| physics_state == PhysicsState.WALL

func _is_wall_physics_state(physics_state : int) -> bool:
	return physics_state == PhysicsState.WALL

func _is_ground_physics_state(physics_state : int) -> bool:
	return physics_state == PhysicsState.FLOOR \
			|| physics_state == PhysicsState.SLOPE

# "Surface states" are those player states which are meant to be compatible
# with the player moving on a surface. If the player is in one of these states,
# then a call to `_is_surface_physics_state` must return true (but the converse is not
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
			|| state == State.JUMP_BALLISTIC_LOW_START \
			|| state == State.JUMP_BALLISTIC_HIGH_START \
			|| state == State.JUMP_BALLISTIC_WALL_LOW_START \
			|| state == State.JUMP_BALLISTIC_WALL_HIGH_START \
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

# Checks whether an air state will "cling" to a wall when next to one.
func _is_wall_cling_state(air_state : int) -> bool:
	if !_is_air_state(air_state):
		printerr("Provided state ", STATE_NAME[air_state], " is not an air state.")
		return false
	return state == State.FALL \
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

# Print an error is physics state and player state are incompatible.
func _check_state_validity() -> void:
	if _is_ground_physics_state(self.physics_state) && !_is_surface_state(self.state):
		printerr("On ground but state ", STATE_NAME[self.state], " is not a surface state.")
	if _is_wall_physics_state(self.physics_state) && !(_is_surface_state(self.state) || (_is_air_state(self.state) && !_is_wall_cling_state(self.state))):
		printerr("On wall but state ", STATE_NAME[self.state], " is not a surface state or is an air state with wall cling.")
	if !_is_surface_physics_state(self.physics_state) && !_is_air_state(self.state):
		printerr("In air but state ", STATE_NAME[self.state], " is not an air state.")

# Returns what the tangent velocity should be given the tangent and normal
# components. Both arguments are positive.
func _redirect_velocity(velocity_tangent : float, velocity_normal : float) -> float:
	var angle_difference = atan2(velocity_normal, velocity_tangent)
	var redirect_fraction := _redirect_normal_velocity(angle_difference)
	return Vector2(velocity_tangent, redirect_fraction * velocity_normal).length()

func _redirect_normal_velocity(angle_difference : float) -> float:
	angle_difference = abs(angle_difference)
	if _is_skate_state(self.state):
		var on_surface = _is_surface_physics_state(self.physics_state)
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
		return 0.5 * surface_gravity / abs(self.velocity.x) * SURFACE_DROP_TIME

func _apply_drag(drag : float, delta : float) -> void:
	if self.velocity.length_squared() > 0.0:
		var drag_delta := -drag * self.velocity.normalized() * delta
		if drag >= 0 && drag_delta.length() >= self.velocity.length():
			self.velocity = Vector2.ZERO
		else:
			self.velocity += drag_delta

func _reset() -> void:
	self.dying = false
	self.dead = false
	
	self.state = State.FALL
	self.physics_state = PhysicsState.AIR
	self.velocity = Vector2.ZERO
	self.facing_direction = 1
	self.skate_direction = 1
	self.slide_timer = 0.0
	self.skate_timer = 0.0
	self.skate_boost_timer = 0.0
	self.wipeout_timer = 0.0
	self.air_timer = 0.0
	self.pivot_stored_velocity = 0.0
	self.pivot_timer = 0.0
	self.dive_charge_timer = 0.0
	self.dive_timer = 0.0
	self.has_dive = false
	self.skate_landing_velocity_x = 0.0
	self.skate_landing_timer = 0.0
	self.skate_stride = false
	self.previous_state = self.state
	self.previous_physics_state = self.physics_state
	self.previous_position = self.position
	self.previous_velocity = self.velocity
	self.previous_skate_direction = self.skate_direction
	
	self.score_area2d.get_child(0).disabled = false
	self.checkpoint_area2d.get_child(0).disabled = false
	self.win_area2d.get_child(0).disabled = false
	self.hazard_area2d.get_child(0).disabled = false
	
	self.sprite.visible = true
	self.skate_brake_effect_a.set_emitting(false)
	self.skate_brake_effect_b.set_emitting(false)
	self.skate_trail_effect_a.set_emitting(false)
	self.skate_trail_effect_b.set_emitting(false)
	self.dive_charge_effect.set_emitting(false)
	self.dive_trail_effect_a.set_emitting(false)
	self.dive_trail_effect_b.set_emitting(false)
	
	self.skate_audio.stop()
	self.skate_brake_continuous_audio.stop()
	
	_animation_process()
	_effects_process()

func spawn() -> void:
	_reset()
	self.global_position = self.respawn_position
	self.death_burst_effect.burst()
	emit_signal("spawn", self)

func death() -> void:
	_reset()
	
	self.death_audio.play()
	
	self.dying = false
	self.dead = true
	self.sprite.visible = false
	
	self.score_area2d.get_child(0).disabled = true
	self.checkpoint_area2d.get_child(0).disabled = true
	self.win_area2d.get_child(0).disabled = true
	self.hazard_area2d.get_child(0).disabled = true
	
	self.death_burst_effect.burst()
	
	var layer_count_max := 16
	var index := 0
	var layer_index := 0
	for score_obj in self.score_list:
		var score := score_obj as Score
		emit_signal("score", -score.points)
		var respawn_score = Scenes.Respawn.instance()
		respawn_score.init(score, score.global_position, false)
		respawn_score.add_child(score.sprite.duplicate())
		respawn_score.global_position = self.global_position
		var angle := 0.0
		var speed := 0.0
		if self.score_list.size() <= layer_count_max:
			angle = 2.0 * PI * index / (self.score_list.size())
			speed = 300.0
		else:
			if index >= layer_count_max:
				index -= layer_count_max
				layer_index += 1
			angle = 2.0 * PI * (index + 0.5 * (layer_index % 2)) / layer_count_max
			speed = 300.0 + 50.0 * layer_index
		index += 1
		respawn_score.initial_velocity = speed * Vector2(sin(angle), -cos(angle))
		self.get_parent().add_child(respawn_score)
	
	self.score_list.clear()
	
	var respawn_player = Scenes.Respawn.instance()
	respawn_player.init(self, self.respawn_position)
	respawn_player.global_position = self.global_position
	self.get_parent().add_child(respawn_player)
	
	emit_signal("death", self, respawn_player)

func _ready() -> void:
	self.score_area2d.connect("area_entered", self, "_on_score_pickup")
	self.checkpoint_area2d.connect("area_entered", self, "_on_checkpoint_activate")
	self.win_area2d.connect("area_entered", self, "_on_win")
	self.hazard_area2d.connect("area_entered", self, "_on_hazard_collision")
	spawn()

func _on_score_pickup(area2d : Area2D) -> void:
	var score := area2d as Score
	if score != null:
		emit_signal("score", score.points)
		score.death()
		self.score_list.append(score)

func _on_checkpoint_activate(area2d : Area2D) -> void:
	var checkpoint := area2d as Checkpoint
	if checkpoint != null && checkpoint != self.checkpoint:
		checkpoint.activate()
		if self.checkpoint != null:
			self.checkpoint.deactivate()
		self.checkpoint = checkpoint
		self.respawn_position = self.checkpoint.global_position + Vector2.UP * CHECKPOINT_SPAWN_HEIGHT
		for score in self.score_list:
			score.queue_free()
		self.score_list.clear()

func _on_win(win2d : Area2D) -> void:
	self.respawn_position = self.global_position
	for score in self.score_list:
		score.queue_free()
	var old_state = self.state
	self.state = _get_default_normal_state(Intent.new())
	_handle_state_transition(old_state)
	self.win = true
	emit_signal("win")

func _on_hazard_collision(area2d : Area2D) -> void:
	var hazard := area2d as Hazard
	if hazard != null:
		self.dying = true

func _physics_process(delta : float) -> void:
	# Handle death.
	if self.dead:
		return
	
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
	_effects_process()
	_audio_process()
	
	if self.dying || intent.restart:
		death()
	
	# Print the state for debugging purposes.
	if self.previous_state != self.state || self.previous_physics_state != self.physics_state:
		print(PHYSICS_STATE_NAME[self.physics_state], "; ", STATE_NAME[self.state])
	self.previous_state = self.state
	self.previous_physics_state = self.physics_state
	self.previous_position = self.position
	self.previous_velocity = self.velocity
	self.previous_skate_direction = self.skate_direction

func _read_move_direction() -> Vector2:
	if self.in_dialogue || self.win:
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
	if self.in_dialogue || self.win:
		return Intent.new()
	var intent := Intent.new()
	intent.move_direction = move_direction
	# Get input from the user. The intent structure represents the action that
	# the player wants to do, not the input that the player actually did, so
	# parts of it are conditional on the current state.
	if Input.is_action_just_pressed("restart"):
		intent.restart = true
	if Input.is_action_just_pressed("jump"):
		if _is_surface_physics_state(self.physics_state):
			if _is_skate_state(self.state):
				if move_direction.y < 0 || move_direction.x * self.skate_direction < 0:
					intent.jump_high = true
				else:
					intent.jump_low = true
			elif _is_normal_state(self.state):
				intent.jump_high = true
	if _is_surface_physics_state(self.physics_state):
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
				if !_is_surface_physics_state(self.previous_physics_state) && \
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
		if abs(self.surface_normal.angle_to(Vector2.UP)) <= WALK_MAX_ANGLE:
			next_facing_direction = int(sign(self.velocity.x))
		else:
			next_facing_direction = int(sign(self.surface_normal.x))
	elif self.state == State.WALL_SLIDE:
		if _is_wall_physics_state(self.physics_state):
			next_facing_direction = int(sign(self.surface_normal.x))
	elif _is_skate_state(self.state):
		next_facing_direction = self.skate_direction
	if next_facing_direction != 0:
		self.facing_direction = next_facing_direction

# Updates the velocities based on the current state.
func _state_process(delta : float, move_direction : Vector2) -> void:
	# Dive is special-cased like this because there isn't a better spot to put
	# this code.
	if self.previous_state == State.DIVE && self.state != State.DIVE:
		self.velocity = self.velocity.clamped(DIVE_SPEED_END)
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
	elif self.state == State.SKATE:
		var friction := SKATE_FRICTION
		if self.skate_boost_timer <= SKATE_BOOST_FRICTION_TIME:
			if self.velocity.length() < SKATE_BOOST_FRICTION_TRANSITION_SPEED:
				friction = SKATE_BOOST_FRICTION_LOW
			else:
				friction = SKATE_BOOST_FRICTION_HIGH
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
				base_speed = JUMP_BALLISTIC_WALL_BASE_SPEED
				speed_factor = JUMP_BALLISTIC_WALL_SPEED_FACTOR
			State.JUMP_BALLISTIC_WALL_HIGH_START:
				base_speed = JUMP_BALLISTIC_WALL_BASE_SPEED
				speed_factor = JUMP_BALLISTIC_WALL_SPEED_FACTOR
		# The jump surface speed is the speed of the player on the surface
		# right before making the jump. A larger surface speed leads to a
		# lower, faster jump.
		var jump_surface_speed := self.velocity.length()
		if self.skate_landing_timer <= SKATE_LANDING_TIME: 
			var skate_landing_fraction := (SKATE_LANDING_TIME - self.skate_landing_timer) / SKATE_LANDING_TIME
			jump_surface_speed = skate_landing_fraction * self.skate_landing_velocity_x + (1.0 - skate_landing_fraction) * self.velocity.length()
		var jump_speed := base_speed + abs(jump_surface_speed) * speed_factor
		var jump_direction := self.skate_direction * int(sign(jump_surface_speed))
		if jump_direction == 0:
			jump_direction = self.skate_direction
		var jump_angle := 0.0
		if wall_jump:
			var angle_fraction := self.velocity.dot(surface_tangent) * sign(self.surface_normal.x) / JUMP_BALLISTIC_WALL_TRANSITION_SPEED
			angle_fraction = clamp(angle_fraction, -1.0, 1.0)
			jump_angle = 0.5 * (1.0 - angle_fraction) * JUMP_BALLISTIC_WALL_ANGLE_MIN + 0.5 * (1.0 + angle_fraction) * JUMP_BALLISTIC_WALL_ANGLE_MAX
			jump_angle *= sign(self.surface_normal.x)
		elif surface_tangent.x != 0.0:
			var slope_increase := JUMP_BALLISTIC_HIGH_SLOPE if high_jump else JUMP_BALLISTIC_LOW_SLOPE
			var slope_min := JUMP_BALLISTIC_HIGH_SLOPE_MIN if high_jump else JUMP_BALLISTIC_LOW_SLOPE_MIN
			var surface_slope := float(jump_direction) * surface_tangent.y / surface_tangent.x
			var jump_slope := min(surface_slope - slope_increase, -slope_min)
			jump_angle = atan2(float(jump_direction), -jump_slope)
			# The jump angle gets adjusted in case the player isn't moving very fast.
			var jump_angle_fraction = abs(jump_surface_speed) / JUMP_BALLISTIC_FULL_ANGLE_SPEED
			if jump_angle_fraction < 1.0:
				jump_angle = jump_angle_fraction * jump_angle
		var jump_velocity := jump_speed * Vector2(sin(jump_angle), -cos(jump_angle))
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
		var extreme_angle := PI / 4.0
		if direction.x >= 0:
			extreme_angle = -PI / 4.0
		# Make sure that the direction is collision free.
		while move_and_collide(DIVE_CHECK_DISTANCE * direction, true, true, true) != null:
			direction = direction.rotated(extreme_angle)
			extreme_angle = -sign(extreme_angle) * (abs(extreme_angle) + PI / 4.0)
			if extreme_angle >= 2.0 * PI:
				break
		self.velocity = DIVE_SPEED_START * direction
	elif self.state == State.DIVE:
		self.velocity.y += DIVE_GRAVITY
		var friction := (DIVE_SPEED_START * DIVE_SPEED_START - DIVE_SPEED_END * DIVE_SPEED_END) / (2.0 * DIVE_DISTANCE)
		_apply_drag(friction, delta)
	
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
	elif _is_surface_physics_state(self.physics_state) && collision == null:
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
				var extreme_slope := velocity_slope + sign(self.velocity.x) * max_slope_change
				var test_displacement := tolerance_factor * Vector2.DOWN * abs(velocity.x) * delta * max_slope_change
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
		var velocity_normal := self.velocity.project(new_surface_normal)
		if velocity_tangent.length_squared() != 0.0 && self.velocity.length_squared() != 0.0:
			self.velocity = velocity_tangent.normalized() * _redirect_velocity(velocity_tangent.length(), velocity_normal.length())
		else:
			self.velocity = velocity_tangent
		# Record information about the collision.
		collision_info.merge(_handle_collision_physics_state_transition(new_surface_normal))
	# Before committing to the new surface, make sure that there isn't a
	# better choice of surface to be on by looking in the direction of the
	# last surface the player was on.
	if _is_surface_physics_state(self.physics_state):
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
		# Handle transitions between skate states and non-skate states.
		if !_is_skate_state(self.state) && _is_skate_state(old_state):
			pass
		if _is_skate_state(self.state) && !_is_skate_state(old_state):
			self.skate_timer = 0.0
		# Decide on the skate direction, if we are entering a skate state.
		if _is_skate_state(self.state):
			if _is_surface_state(self.state):
				var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
				self.skate_direction = int(sign(self.velocity.dot(surface_tangent)))
			else:
				self.skate_direction = int(sign(self.velocity.x))
			if self.skate_direction == 0:
				self.skate_direction = self.facing_direction
		# Set the landing velocity upon hitting the ground.
		if _is_skate_state(self.state):
			if _is_surface_state(self.state) && _is_air_state(self.previous_state):
				self.skate_landing_velocity_x = self.previous_velocity.x * self.skate_direction
				self.skate_landing_timer = 0.0
		
		# The boost timer is zeroed here because it is needed for calculating
		# the amount of boost while we are still in the boost state.
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
	if _is_surface_physics_state(self.physics_state) && (!_is_wall_physics_state(self.physics_state) || (_is_air_state(self.state) && _is_wall_cling_state(self.state))):
		# If `_is_surface_physics_state` is true, then the player must be in a surface state.
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
	
	_check_state_validity()
	return _handle_state_transition(old_state)

func _state_transition(delta : float, intent : Intent, collision_info : CollisionInfo) -> bool:
	var old_state := self.state
	var surface_tangent := Vector2(-self.surface_normal.y, self.surface_normal.x)
	var can_act := !_is_stun_state(self.state)
	
	self.air_timer += delta
	if self.skate_landing_timer <= SKATE_LANDING_TIME:
		self.skate_landing_timer += delta
	if _is_surface_state(self.state):
		self.air_timer = 0.0
		# Dive only gets restocked on the ground, not on walls.
		if _is_ground_physics_state(self.physics_state):
			self.has_dive = true
	
	if _is_normal_state(self.state):
		# Input transitions take priority over all else.
		if can_act && intent.jump_high && _is_surface_state(self.state) && self.state != State.JUMP:
			if _is_wall_physics_state(self.physics_state):
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
				if _is_wall_physics_state(self.physics_state):
					self.state = _get_default_normal_state(intent, true)
			elif _is_wall_physics_state(self.physics_state) || abs(surface_angle) <= WALK_MAX_ANGLE:
				self.state = _get_default_normal_state(intent, true)
		elif self.state == State.WALL_SLIDE:
			if _is_ground_physics_state(self.physics_state):
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
			#if !_is_surface_physics_state(self.physics_state):
			#	self.state = _get_default_normal_state(intent)
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
		if _is_surface_physics_state(self.physics_state):
			if self.velocity.dot(self.skate_direction * surface_tangent) < 0.0:
				self.skate_direction = -self.skate_direction
		else:
			var velocity_sign := int(sign(self.velocity.x))
			if velocity_sign * self.skate_direction == -1:
				self.skate_direction = velocity_sign
		
		# Impulse is used to determine if the player has crashed into a wall.
		var impulse := self.velocity.length() - self.previous_velocity.length()
		var fractional_impulse := 0.0
		if self.previous_velocity.length_squared() != 0.0:
			fractional_impulse = impulse / self.previous_velocity.length()
		
		if _is_ground_physics_state(self.physics_state) && (collision_info.wall_collision || collision_info.ceiling_collision):
			if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_IMPULSE_FRACTION:
				self.state = State.WIPEOUT
			else:
				self.state = _get_default_normal_state(intent)
		elif can_act && intent.dive && self.has_dive:
			self.state = State.DIVE_CHARGE
		elif can_act && (intent.jump_low || intent.jump_high) && _is_surface_state(self.state):
			if _is_wall_physics_state(self.physics_state):
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
		elif self.state == State.SKATE:
			pass
		elif self.state == State.SKATE_BOOST:
			self.state = State.SKATE
		elif self.state == State.SKATE_BRAKE:
			self.pivot_stored_velocity += (self.previous_velocity - self.velocity).dot(surface_tangent)
			if abs(self.surface_normal.angle_to(Vector2.UP)) <= WALK_MAX_ANGLE && self.velocity.length() < SKATE_BRAKE_MIN_SPEED:
				self.state = State.PIVOT
		elif self.state == State.BALLISTIC:
			if impulse <= -WIPEOUT_MIN_IMPULSE && fractional_impulse <= -WIPEOUT_MIN_IMPULSE_FRACTION:
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
			var collision := collision_info.has_collision() && fractional_impulse <= -DIVE_MIN_IMPULSE_FRACTION
			var max_dive_time := 2.0 * DIVE_DISTANCE / (DIVE_SPEED_START + DIVE_SPEED_END)
			if self.dive_timer > max_dive_time || collision:
				self.state = _get_default_skate_state(intent)
	
	_check_state_validity()
	return _handle_state_transition(old_state)

# Gets an appropriate choice of state based on the physics state of the player.
# This is used when resetting the player state.
func _get_default_normal_state(intent : Intent, prefer_slide : bool = false) -> int:
	if !_is_surface_physics_state(self.physics_state):
		return State.FALL
	else:
		var surface_angle = self.surface_normal.angle_to(Vector2.UP)
		if _is_wall_physics_state(self.physics_state):
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
	# TODO: Make sure that these direct transitions aren't buggy.
	elif intent.skate_boost:
		return State.SKATE_BOOST
	elif intent.skate_brake:
		return State.SKATE_BRAKE
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
	elif self.state == State.SKATE:
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

func _effects_process() -> void:
	if self.state == State.SKATE_BRAKE:
		self.skate_brake_effect_a.set_emitting(true, abs(self.velocity.length()))
		self.skate_brake_effect_b.set_emitting(true, abs(self.velocity.length()))
		self.skate_brake_effect_a.scale.x = self.skate_direction
		self.skate_brake_effect_b.scale.x = self.skate_direction
	else:
		self.skate_brake_effect_a.set_emitting(false)
		self.skate_brake_effect_b.set_emitting(false)
	
	if _is_prejump_state(self.state) && _is_skate_state(self.state):
		self.jump_burst_effect_a.burst()
		self.jump_burst_effect_b.burst()
	
	var skate_trail := false
	var dive_trail := false
	if _is_skate_state(self.state):
		if self.state == State.DIVE || self.state == State.DIVE_START:
			dive_trail = true
			skate_trail = false
		else:
			dive_trail = false
			skate_trail = true
	self.skate_trail_effect_a.set_emitting(skate_trail)
	self.skate_trail_effect_b.set_emitting(skate_trail)
	self.dive_trail_effect_a.set_emitting(dive_trail)
	self.dive_trail_effect_b.set_emitting(dive_trail)
	
	var dive_charge : bool = self.state == State.DIVE_CHARGE
	self.dive_charge_effect.set_emitting(dive_charge)

func _audio_process() -> void:
	var previous_in_air := _is_air_state(self.previous_state)
	var in_air := _is_air_state(self.state)
	if _is_prejump_state(self.state) && self.state != State.WALL_RELEASE:
		if _is_skate_state(self.state):
			if !self.skate_jump_audio.playing:
				self.skate_jump_audio.play()
		if !self.jump_audio.playing:
			self.jump_audio.play()
	if previous_in_air && !in_air:
		if _is_skate_state(self.state):
			if !self.skate_land_audio.playing:
				self.skate_land_audio.play()
		else:
			if !self.land_audio.playing:
				self.land_audio.play()
	if _is_skate_state(self.state) && !in_air:
		if !self.skate_audio.playing:
			self.skate_audio.play()
	else:
		if self.skate_audio.playing:
			self.skate_audio.stop()
	if self.state == State.SKATE_BRAKE:
		if !self.skate_brake_continuous_audio.playing:
			self.skate_brake_continuous_audio.play()
	else:
		if self.skate_brake_continuous_audio.playing:
			self.skate_brake_continuous_audio.stop()
	if self.state == State.PIVOT && self.previous_state != State.PIVOT:
		if !self.skate_brake_audio.playing:
			self.skate_brake_audio.play()
	if self.state == State.SKATE_BOOST || self.state == State.SKATE_START || self.state == State.SKATE_PIVOT_START:
		var idx := randi() % 4
		match idx:
			0:
				self.skate_boost_audio.stream = AUDIO_SKATE_BOOST_1
			1:
				self.skate_boost_audio.stream = AUDIO_SKATE_BOOST_2
			2:
				self.skate_boost_audio.stream = AUDIO_SKATE_BOOST_3
			_:
				self.skate_boost_audio.stream = AUDIO_SKATE_BOOST_4
		self.skate_boost_audio.play()
	if self.state == State.DIVE_CHARGE && self.previous_state != State.DIVE_CHARGE:
		self.dive_charge_audio.play()
	if self.state == State.DIVE_START && self.previous_state != State.DIVE_START:
		self.dive_audio.play()

func _on_dialogue_start():
	self.in_dialogue = true

func _on_dialogue_end():
	self.in_dialogue = false
