extends Node

## Runs every case and prints one line for each, which tests/run.sh reads.
##
## A case is a script in res://cases with a method run_case() that returns "ok", or says what is wrong.
## Cases that extend Node are added to the tree before they run, and a case may await.
## How the project was exported is told by the feature tags of the configuration, see tests/README.md.

func _ready() -> void:
	if OS.has_feature("crash"):
		# Errors for the log, which the configurations with this tag have translated. They come first,
		# so that the line they are on stays the same whatever cases there are
		load("res://broken/at_runtime.gd").new().start_engine()
	var cases : Array = [
		"tokenizer/operators",
		"tokenizer/numbers",
		"tokenizer/unique_names",
		"tokenizer/node_paths",
		"tokenizer/string_values",
		"tokenizer/backslash",
		"tokenizer/space_indent",
		"tokenizer/crlf",
		"tokenizer/multiline_padding",
		"tokenizer/source_lines",
		"tokenizer/less_common_syntax",
		"hints/anywhere",
		"hints/string_seed",
		"hints/string_lines",
		"hints/empty_string",
		"parser/lua_dictionaries",
		"parser/dictionary_literal",
		"parser/typed_dictionary",
		"parser/enums",
		"parser/autoload_locals",
		"parser/match_patterns",
		"parser/scopes",
		"parser/lock_symbols",
		"parser/parameters",
		"parser/generated_names",
		"parser/class_names",
		"parser/annotated_members",
		"parser/member_forms",
		"parser/global_constants",
		"postprocess/strip_typing",
		"postprocess/feature_func",
		"postprocess/member_order",
		"postprocess/script_annotations",
		"postprocess/onready_order",
		"postprocess/annotation_lines",
		"postprocess/export_annotations",
		"postprocess/annotation_arguments",
		"postprocess/removed_lines",
		"postprocess/regex_filter",
		"postprocess/encoded_strings",
		"postprocess/inline_constants",
		"postprocess/inline_enums",
		"resources/multiline_strings",
		"resources/animation_paths",
		"resources/track_types",
		"resources/advance_expression",
		"resources/method_keys",
		"resources/property_paths",
		"resources/builtin_scripts",
		"resources/dependencies",
		"export/settings_applied",
		"export/autoloads",
		"export/enter_tree",
		"export/csv_files",
		"export/addon_left_out",
		"export/excluded_paths",
		"export/names_in_strings",
		"export/names_by_pattern",
		"export/checked_autoloads",
	]
	for case_name in cases:
		var result : String = await run(case_name)
		print("[CASE] ", "PASS" if result == "ok" else "FAIL", " | ", case_name, " | ", result)
	print("[DONE] ", cases.size())
	get_tree().quit()

func run(case_name : String) -> String:
	var script = load("res://cases/" + case_name + ".gd")
	if script == null or not script.can_instantiate():
		return "does not compile"
	var subject = script.new()
	if subject is Node:
		add_child(subject)
	var result = await subject.run_case()
	if subject is Node:
		subject.queue_free()
	if result == null or str(result).is_empty():
		return "stopped by an error"
	return str(result)
