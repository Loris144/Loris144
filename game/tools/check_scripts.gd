extends SceneTree
## Loads every .gd file in the project so parse/compile errors surface.
## Run: godot --headless --script res://tools/check_scripts.gd

func _init() -> void:
	var files: Array[String] = []
	_walk("res://src", files)
	files.sort()
	var bad := 0
	for f in files:
		var res = load(f)
		if res == null:
			printerr("LOAD FAILED: %s" % f)
			bad += 1
		else:
			print("ok  %s" % f)
	print("---- %d scripts, %d failed ----" % [files.size(), bad])
	quit(1 if bad > 0 else 0)


func _walk(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir():
			if not n.begins_with("."):
				_walk(dir_path + "/" + n, out)
		elif n.ends_with(".gd"):
			out.append(dir_path + "/" + n)
		n = d.get_next()
	d.list_dir_end()
