extends CanvasLayer

signal done

onready var box := $CenterContainer
onready var sound_slider := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/SoundSlider
onready var music_slider := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/MusicSlider
onready var fullscreen_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/FullscreenButton
onready var jump_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/JumpButton
onready var skate_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/SkateButton
onready var dive_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/DiveButton
onready var restart_button := $CenterContainer/PanelContainer/VBoxContainer/GridContainer/RestartButton

var current_action := ""

func _ready() -> void:
	_update_sound_slider()
	_update_music_slider()
	_update_fullscreen_button()
	_update_rebind_button("jump")
	_update_rebind_button("skate")
	_update_rebind_button("dive")
	_update_rebind_button("restart")

func _update_sound_slider() -> void:
	var mute : bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Sound"))
	if mute:
		self.sound_slider.value = self.sound_slider.min_value
	else:
		self.sound_slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sound"))

func _update_music_slider() -> void:
	var mute : bool = AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	if mute:
		self.music_slider.value = self.music_slider.min_value
	else:
		self.music_slider.value = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))

func _update_fullscreen_button() -> void:
	var fullscreen := OS.window_fullscreen
	self.fullscreen_button.text = "off" if !fullscreen else "on"

func _changed_sound_slider(value : float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sound"), value)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Sound"), value <= self.sound_slider.min_value)

func _changed_music_slider(value : float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), value)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), value <= self.music_slider.min_value)

func _pressed_fullscreen_button() -> void:
	# TODO: Note: this is buggy on Wayland (I think).
	OS.window_fullscreen = !OS.window_fullscreen
	_update_fullscreen_button()

func _update_rebind_button(action : String) -> void:
	for event in InputMap.get_action_list(action):
		var key_event := event as InputEventKey
		if key_event != null:
			_get_button(action).text = OS.get_scancode_string(key_event.scancode)
			break

func _pressed_rebind_button(action : String) -> void:
	if self.current_action == "":
		self.current_action = action
		var button := _get_button(self.current_action)
		if button != null:
			button.text = "..."

func _pressed_ok_button() -> void:
	emit_signal("done")

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
				break
		_update_rebind_button(self.current_action)
		self.current_action = ""

func _get_button(action : String) -> Button:
	match action:
		"jump":
			return self.jump_button as Button
		"skate":
			return self.skate_button as Button
		"dive":
			return self.dive_button as Button
		"restart":
			return self.restart_button as Button
		_:
			return null
