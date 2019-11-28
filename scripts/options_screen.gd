extends CanvasLayer

onready var box := $CenterContainer
onready var sound_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/SoundButton
onready var jump_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/JumpButton
onready var skate_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/SkateButton
onready var dive_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/DiveButton

var current_action := ""

func _ready() -> void:
	self.box.visible = false

func _process(delta) -> void:
	if !self.box.visible:
		if Input.is_action_just_pressed("ui_options"):
			self.box.visible = true

func _pressed_sound_button() -> void:
	if self.current_action == "":
		var mute : bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))
		mute = !mute
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), mute)
		self.sound_button.text = "off" if mute else "on"

func _pressed_rebind_button(action : String) -> void:
	if self.current_action == "":
		self.current_action = action
		var button := _get_button(self.current_action)
		if button != null:
			button.text = "..."

func _pressed_ok_button() -> void:
	if self.current_action == "":
		self.box.visible = false

func _input(event : InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null && key_event.pressed && !key_event.echo && self.box.visible && self.current_action != "":
		get_tree().set_input_as_handled()
		var converted_key_event = InputEventKey.new()
		converted_key_event.scancode = key_event.scancode
		converted_key_event.unicode = key_event.unicode
		converted_key_event.pressed = true
		for old_event in InputMap.get_action_list(self.current_action):
			var old_key_event := old_event as InputEventKey
			if old_key_event != null:
				old_key_event.unicode = key_event.unicode
				old_key_event.scancode = key_event.scancode
				_get_button(self.current_action).text = OS.get_scancode_string(key_event.scancode)
				break
		self.current_action = ""

func _get_button(action : String) -> Button:
	match action:
		"jump":
			return self.jump_button as Button
		"skate":
			return self.skate_button as Button
		"dive":
			return self.dive_button as Button
		_:
			return null
