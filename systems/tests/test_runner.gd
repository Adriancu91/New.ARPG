extends Node
## Headless unit test runner.
##   godot --headless res://systems/tests/test_runner.tscn
## Prints PASS/FAIL per test, writes systems/tests/output/unit_results.json,
## and exits with code 0 only if every test passed.

const SUITES := [
	"res://systems/tests/unit/test_damage.gd",
	"res://systems/tests/unit/test_progression.gd",
	"res://systems/tests/unit/test_items.gd",
	"res://systems/tests/unit/test_inventory.gd",
	"res://systems/tests/unit/test_equipment.gd",
	"res://systems/tests/unit/test_loot.gd",
	"res://systems/tests/unit/test_quests.gd",
	"res://systems/tests/unit/test_save.gd",
	"res://systems/tests/unit/test_skills_data.gd",
]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	SaveSystem.autosave_enabled = false
	var results: Array = []
	var passed := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null:
			print("FAIL  %s  (could not load suite)" % path)
			failed += 1
			results.append({"suite": path, "test": "<load>", "result": "FAIL", "notes": "load error"})
			continue
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var suite: TestCase = script.new()
			suite.current = name
			suite.before_each()
			var r = suite.call(name)
			if r is Object and r.has_method("is_valid"):
				pass
			var ok := suite.failures.is_empty()
			var suite_name: String = String(path).get_file().get_basename()
			if ok:
				passed += 1
				print("PASS  %s.%s" % [suite_name, name])
			else:
				failed += 1
				print("FAIL  %s.%s" % [suite_name, name])
				for f in suite.failures:
					print("        - " + f)
			results.append({"suite": suite_name, "test": name, "result": "PASS" if ok else "FAIL", "notes": "; ".join(suite.failures)})
	print("\nUNIT TESTS: %d passed, %d failed, %d total" % [passed, failed, passed + failed])
	var out_dir := ProjectSettings.globalize_path("res://systems/tests/output")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir + "/unit_results.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"date": Time.get_datetime_string_from_system(), "engine": Engine.get_version_info().string, "passed": passed, "failed": failed, "results": results}, "\t"))
		f.close()
	get_tree().quit(0 if failed == 0 else 1)
