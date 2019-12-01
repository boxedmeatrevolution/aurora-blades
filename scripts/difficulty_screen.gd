extends CanvasLayer

signal done

func _very_easy_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.VERY_EASY
	emit_signal("done")

func _easy_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.EASY
	emit_signal("done")

func _medium_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.MEDIUM
	emit_signal("done")

func _hard_pressed() -> void:
	Difficulty.difficulty = Difficulty.Difficulty.HARD
	emit_signal("done")
