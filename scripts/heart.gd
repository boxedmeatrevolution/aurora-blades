extends Sprite

const Player := preload("res://entities/player.tscn")

const PERIOD := 0.5 * 0.845

var beat_timer := 0.0

func _process(delta):
	self.beat_timer += delta
	if self.beat_timer >= PERIOD:
		self.beat_timer = 0.0
		self.rotation = rand_range(-1.0, 1.0) * 10.0 * PI / 180.0
	var scale_factor := 1.3 + 0.6 * exp(-self.beat_timer / PERIOD)
	self.scale.x = scale_factor
	self.scale.y = scale_factor
