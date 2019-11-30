extends CanvasLayer

signal done

func _goto_level(index : int) -> void:
	var level_str := "res://levels/level%d.tscn" % index
	emit_signal("done")
	get_tree().change_scene(level_str)

func _back_pressed() -> void:
	emit_signal("done")
