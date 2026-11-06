extends TestCase
## The version is the same everywhere it's stored (rules: version.mdc,
## changelog.mdc): VERSION, project.godot, and the newest CHANGELOG entry.


func test_version_matches_everywhere() -> void:
	var version: String = FileAccess.get_file_as_string("res://VERSION").strip_edges()
	var regex := RegEx.create_from_string("^\\d{2}\\.\\d{2}\\.\\d{2}$")
	check(regex.search(version) != null, "VERSION looks like XX.XX.XX (%s)" % version)
	check_eq(str(ProjectSettings.get_setting("application/config/version")), version, "project.godot matches VERSION")
	var changelog: String = FileAccess.get_file_as_string("res://CHANGELOG.md")
	var first := RegEx.create_from_string("## Version (\\d{2}\\.\\d{2}\\.\\d{2})").search(changelog)
	check(first != null, "CHANGELOG.md has entries")
	if first != null:
		check_eq(first.get_string(1), version, "the newest changelog entry is this version")
