extends Camera2D

onready var viewport := self.get_viewport()
onready var root := self.get_tree().get_root()
onready var base_size := self.root.size

# Called when the node enters the scene tree for the first time.
func _ready():
	self.get_tree().connect("screen_resized", self, "_screen_resized")
	self.root.set_attach_to_screen_rect(self.root.get_visible_rect())
	_screen_resized()

func _process(delta):
	# TODO: Note: this is buggy on Wayland (I think).
	if Input.is_action_just_pressed("ui_fullscreen"):
		OS.window_fullscreen = !OS.window_fullscreen

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
