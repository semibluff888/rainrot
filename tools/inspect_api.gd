extends SceneTree
func _initialize() -> void:
	var font := load("res://assets/fonts/NotoSansSC.ttf") as Font
	print("FONT_AXES ",font.get_supported_variation_list())
	var vf := load("res://assets/fonts/regular.tres") as FontVariation
	print("FONT_VARIATIONS ",vf.variation_opentype)
	quit()
