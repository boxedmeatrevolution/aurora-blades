extends Node2D

const DEFAULT_DRAG_MARGINS := 0.2

var target : Node2D = null
export var scroll_speed := 2000.0
export var keep_up_speed := 4000.0

onready var camera := $Camera2D

onready var viewport := get_viewport()
onready var base_size := self.viewport.size

func _set_target(target : Node2D) -> void:
	self.target = target

func _get_viewport_rect_centered() -> Rect2:
	var viewport_rect := self.viewport.get_visible_rect()
	var shift := -viewport_rect.position - 0.5 * viewport_rect.size
	viewport_rect.position += shift
	return viewport_rect

func _set_drag_region(rect : Rect2) -> void:
	var viewport_rect := _get_viewport_rect_centered()
	self.camera.drag_margin_left = rect.position.x / viewport_rect.position.x
	self.camera.drag_margin_right = rect.end.x / viewport_rect.end.x
	self.camera.drag_margin_top = rect.position.y / viewport_rect.position.y
	self.camera.drag_margin_bottom = rect.end.y / viewport_rect.end.y

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.get_tree().connect("screen_resized", self, "_screen_resized")
	self.viewport.set_attach_to_screen_rect(self.viewport.get_visible_rect())
	_screen_resized()
	#get_tree().set_debug_collisions_hint(true)
	var drag_region := _get_viewport_rect_centered()
	drag_region.position *= DEFAULT_DRAG_MARGINS
	drag_region.size *= DEFAULT_DRAG_MARGINS
	_set_drag_region(drag_region)

func _process(delta) -> void:
	# TODO: Note: this is buggy on Wayland (I think).
	if Input.is_action_just_pressed("ui_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen
	if is_instance_valid(self.target):
		var displacement = self.target.global_position - self.global_position
		if displacement.length() < self.keep_up_speed * delta:
			self.global_position = self.target.global_position
		else:
			self.global_position += displacement.normalized() * self.scroll_speed * delta
	else:
		self.target = null

func _screen_resized() -> void:
	var window_size := OS.window_size
	var scale_x := max(int(window_size.x / self.base_size.x), 1)
	var scale_y := max(int(window_size.y / self.base_size.y), 1)
	var scale_factor := min(scale_x, scale_y)
	var upper_left := (0.5 * (window_size - scale_factor * self.viewport.size)).floor()
	self.viewport.set_attach_to_screen_rect(Rect2(upper_left, scale_factor * self.viewport.size))
	
	# Black bars to prevent flickering.
	var odd_offset := Vector2(int(window_size.x) % 2, int(window_size.y) % 2)
	VisualServer.black_bars_set_margins(
		max(upper_left.x, 0),
		max(upper_left.y, 0),
		max(upper_left.x, 0) + odd_offset.x,
		max(upper_left.y, 0) + odd_offset.y)


func _on_dialogue_start():
	var drag_region := _get_viewport_rect_centered()
	drag_region.end.y = 0.0
	drag_region.position += 0.5 * (1.0 - DEFAULT_DRAG_MARGINS) * drag_region.size
	drag_region.size *= DEFAULT_DRAG_MARGINS
	_set_drag_region(drag_region)

func _on_dialogue_end():
	var drag_region := _get_viewport_rect_centered()
	drag_region.position *= DEFAULT_DRAG_MARGINS
	drag_region.size *= DEFAULT_DRAG_MARGINS
	_set_drag_region(drag_region)

func _on_player_spawn(player):
	_set_target(player)

func _on_player_death(player, respawn_player):
	_set_target(respawn_player)
