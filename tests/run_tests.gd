extends SceneTree
# Runs every test_* method in every tests/test_*.gd file, each on a fresh main scene.
# Exits with code 1 if any check fails or any script error is logged during a test.

const TESTS_DIR := "res://tests/"


class ErrorCounter extends Logger:
	var count := 0
	var mutex := Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		mutex.lock()
		count += 1
		mutex.unlock()


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var passed := 0
	var failed: Array[String] = []
	var files := Array(DirAccess.get_files_at(TESTS_DIR)).filter(
		func(file: String) -> bool: return file.begins_with("test_") and file.ends_with(".gd"))
	files.sort()
	for file: String in files:
		var script: GDScript = load(TESTS_DIR + file)
		if script == null or not script.can_instantiate():
			failed.append(file)
			print("FAIL  ", file, " (script did not load)")
			continue
		for method in script.get_script_method_list():
			var test_name: String = method.name
			if not test_name.begins_with("test_"):
				continue
			var test: Object = script.new()
			var errors_before := errors.count
			await test.start(self)
			await test.call(test_name)
			await test.finish()
			var label := "%s::%s" % [file.get_basename(), test_name]
			var problems: Array[String] = test.failures.duplicate()
			if errors.count > errors_before:
				problems.append("script errors were logged")
			if test.checks == 0:
				problems.append("no checks ran")
			if problems.is_empty():
				passed += 1
				print("PASS  ", label)
			else:
				failed.append(label)
				print("FAIL  ", label)
				for problem in problems:
					print("        ", problem)
	print("\n%d passed, %d failed" % [passed, failed.size()])
	OS.remove_logger(errors)
	quit(1 if failed.size() > 0 or passed == 0 else 0)
