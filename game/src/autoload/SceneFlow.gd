extends CanvasLayer
## Screen switching with a fade, plus a global "busy" overlay.
##
## Screens are plain Control/Node2D scenes instantiated into a holder that
## Main.tscn registers on ready.

signal screen_changed(name: String)

var holder: Node = null
var current_name := ""
var _current: Node = null
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func register_holder(node: Node) -> void:
	holder = node


func _script_for(name: String) -> String:
	return "res://src/screens/%s.gd" % name


## Swap to a screen by name; the script must define `static func build()`
## or be a Node script we can instantiate directly.
func goto(name: String, args: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true
	await fade_out()
	if is_instance_valid(_current):
		_current.queue_free()
		# let the node actually leave the tree before adding the next one
		await get_tree().process_frame
	var path := _script_for(name)
	if not ResourceLoader.exists(path):
		push_error("[SceneFlow] no screen script: %s" % path)
		_busy = false
		await fade_in()
		return
	var scr: Script = load(path)
	var node: Node = scr.new()
	if node.has_method("setup"):
		node.setup(args)
	_current = node
	current_name = name
	if holder:
		holder.add_child(node)
	else:
		get_tree().root.add_child(node)
	screen_changed.emit(name)
	await get_tree().process_frame
	await fade_in()
	_busy = false


func fade_out(secs: float = 0.22) -> void:
	_fade.color.a = 0.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, secs)
	await t.finished


func fade_in(secs: float = 0.22) -> void:
	_fade.color.a = 1.0
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, secs)
	await t.finished


func flash(color: Color = Color(1, 1, 1), secs: float = 0.25) -> void:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	var t := create_tween()
	t.tween_property(r, "color:a", 0.0, secs)
	await t.finished
	r.queue_free()
