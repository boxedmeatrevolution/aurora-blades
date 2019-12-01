extends Node

var audio_player_current : AudioStreamPlayer
var audio_player_next : AudioStreamPlayer
var transitioning := false
var transition_timer := 0.0

const TRANSITION_TIME := 1.0

const MUSIC_MAX_VOLUME := 0.0
const MUSIC_MIN_VOLUME := -30.0

const MUSIC_MAIN_MENU := preload("res://music/title.ogg")
const MUSIC_GAME := preload("res://music/ambient_christmas_more.ogg")
const MUSIC_END := preload("res://music/victory_defeat.ogg")

func _ready():
	self.audio_player_current = AudioStreamPlayer.new()
	self.audio_player_next = AudioStreamPlayer.new()
	self.audio_player_current.bus = "Music"
	self.audio_player_next.bus = "Music"
	self.add_child(self.audio_player_current)
	self.add_child(self.audio_player_next)
	self.audio_player_current.volume_db = MUSIC_MAX_VOLUME
	self.audio_player_next.volume_db = MUSIC_MIN_VOLUME
	self.audio_player_current.stream = MUSIC_MAIN_MENU
	self.audio_player_current.play()
	self.audio_player_next.stop()
	self.pause_mode = Node.PAUSE_MODE_PROCESS

func _process(delta):
	if self.transitioning:
		self.transition_timer += delta
		if self.transition_timer >= TRANSITION_TIME:
			self.transitioning = false
			var old_player := self.audio_player_current
			self.audio_player_current = self.audio_player_next
			self.audio_player_next = old_player
			self.audio_player_next.stop()
			self.audio_player_current.volume_db = MUSIC_MAX_VOLUME
		else:
			var frac := self.transition_timer / TRANSITION_TIME
			self.audio_player_current.volume_db = MUSIC_MAX_VOLUME * (1.0 - frac) + MUSIC_MIN_VOLUME * frac
			self.audio_player_next.volume_db = MUSIC_MAX_VOLUME * frac + MUSIC_MIN_VOLUME * (1.0 - frac)

func start_transition(next_stream : AudioStream) -> void:
	if !(!self.transitioning && next_stream == self.audio_player_current.stream) && !(self.transitioning && self.audio_player_next.stream == next_stream):
		if self.transitioning && next_stream == self.audio_player_current.stream:
			self.audio_player_current.volume_db = MUSIC_MAX_VOLUME
			self.audio_player_next.volume_db = MUSIC_MIN_VOLUME
			self.audio_player_next.stop()
			self.transitioning = false
		else:
			self.transitioning = true
			self.transition_timer = 0.0
			self.audio_player_next.volume_db = MUSIC_MIN_VOLUME
			self.audio_player_next.stream = next_stream
			self.audio_player_next.play()
