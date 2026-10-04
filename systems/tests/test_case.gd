class_name TestCase
extends RefCounted
## Minimal xUnit-style base. Methods named test_* are run by the runner.

var failures: Array = []
var current := ""


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a, b, msg: String = "") -> void:
	if typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		if absf(float(a) - float(b)) > 0.0001:
			failures.append("%s: expected %s == %s %s" % [current, a, b, msg])
	elif a != b:
		failures.append("%s: expected %s == %s %s" % [current, a, b, msg])


func before_each() -> void:
	pass
