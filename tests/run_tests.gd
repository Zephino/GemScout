extends SceneTree
## Runs every tests/test_*.gd file headless and prints a summary:
##
##   godot --headless --path . -s tests/run_tests.gd
##
## Each test file extends TestCase; every method starting with "test_" runs.
## Exits with code 1 if any check failed, so CI can see it.


func _initialize() -> void:
	var failed: int = 0
	var passed: int = 0
	var files: Array[String] = []
	for f in DirAccess.get_files_at("res://tests"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for method: Dictionary in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.tree = self
			var started: int = Time.get_ticks_msec()
			await case.call(name)
			var ms: int = Time.get_ticks_msec() - started
			if case.failures.is_empty():
				passed += 1
				print("  ok   %s :: %s (%d ms)" % [f, name, ms])
			else:
				failed += 1
				print("  FAIL %s :: %s" % [f, name])
				for msg in case.failures:
					print("         " + msg)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
