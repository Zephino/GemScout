class_name TestCase
extends RefCounted
## Base for tests (see run_tests.gd). Checks record failures instead of
## stopping, so one run shows every problem.

var failures: Array[String] = []
var tree: SceneTree


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		failures.append("%s (got %s, expected %s)" % [message, str(actual), str(expected)])
