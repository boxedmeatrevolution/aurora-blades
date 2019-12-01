extends Area2D

var on_screen := false
var screen_timer := 0.0

onready var animation_player := $Sprite/AnimationPlayer
onready var collision_shape := $CollisionShape2D
var active := false

func _ready() -> void:
	self.collision_shape.set_disabled(true)

func _process(delta) -> void:
	if $Sprite.frame == 3:
		self.collision_shape.set_disabled(false)
	if self.on_screen:
		self.screen_timer += delta
		if self.screen_timer >= 0.5:
			if !self.active:
				self.active = true
				self.animation_player.play("LevelEndActive")

func _enter_screen() -> void:
	self.on_screen = true
	self.screen_timer = 0.0

func _leave_screen() -> void:
	self.on_screen = false
