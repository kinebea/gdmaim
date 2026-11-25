#!/usr/bin/env bash
# Exports the project in tests/project once for every configuration in tests/configs,
# runs each exported pack and reports the cases that fail. See tests/README.md.
#
#   tests/run.sh                  every configuration
#   tests/run.sh default plain    only the ones named
#
#   GODOT   the Godot editor to use (default: godot)
#   ADDON   the addon to test (default: addons/gdmaim of this repository)
#   WORK    where to put the copy of the project that gets exported (default: tests/.work)

tests="$(cd "$(dirname "$0")" && pwd)"
godot="${GODOT:-godot}"
addon="${ADDON:-$tests/../addons/gdmaim}"
work="${WORK:-$tests/.work}"
project="$work/project"

limit() {
	if command -v timeout > /dev/null; then timeout "$@"; else shift; "$@"; fi
}

# The values of the lines "; key=value" in a configuration, and the first of them
options() {
	sed -n "s/^; *$2=//p" "$tests/configs/$1.cfg" | tr -d '\r'
}

option() {
	options "$1" "$2" | head -n 1
}

fail() {
	echo "  FAIL | $1"
	failed_here=$((failed_here + 1))
}

pass() {
	passed_here=$((passed_here + 1))
}

if [ $# -gt 0 ]; then
	configs="$*"
else
	configs="$(cd "$tests/configs" && ls *.cfg | sed 's/\.cfg$//')"
fi
for config in $configs; do
	if [ ! -f "$tests/configs/$config.cfg" ]; then
		echo "There is no configuration $config in $tests/configs"
		exit 2
	fi
done

# A copy of the project with the addon in it, so nothing gets written to the repository
rm -rf "$work" || exit 2
mkdir -p "$work/run" "$project/addons"
cp -r "$tests/project/." "$project"
cp -r "$addon" "$project/addons/gdmaim"
# What an earlier export may have left in the addon
rm -rf "$project/addons/gdmaim/source_maps" "$project/addons/gdmaim/backup" "$project/addons/gdmaim/export.cfg"
mkdir -p "$project/.gdmaim" "$project/out"
touch "$project/.gdmaim/.gdignore" "$project/out/.gdignore"

cd "$project" || exit 2
limit 300 "$godot" --headless --path . --import > out/import.log 2>&1
class_cache=".godot/global_script_class_cache.cfg"
if [ ! -f "$class_cache" ]; then
	echo "The project could not be imported with '$godot', see $project/out/import.log"
	exit 2
fi

total=0
failed=0
for config in $configs; do
	echo "== $config"
	failed_here=0
	passed_here=0
	cp "$tests/configs/$config.cfg" .gdmaim/export.cfg
	features="$(option "$config" features)"
	script_mode="$(option "$config" script_export_mode)"
	exclude="$(option "$config" exclude_filter)"
	sed -i.bak "s|^custom_features=.*|custom_features=\"$features\"|; s|^script_export_mode=.*|script_export_mode=${script_mode:-0}|; s|^exclude_filter=.*|exclude_filter=\"$exclude\"|" export_presets.cfg
	cp "$class_cache" out/class_cache.before
	rm -f out/test.pck out/test.exe out/*gdbc*
	rm -rf addons/gdmaim/source_maps

	# The export, and what it must leave behind whatever the configuration
	if [ "$(option "$config" export)" = "game" ]; then
		# The game and not just its pack, which takes an export template. The preset names this
		# file as its template: the header of a Windows executable is all the export looks at
		{ printf 'MZ'; head -c 58 /dev/zero; printf '\100\000\000\000PE\000\000\144\206'; head -c 64 /dev/zero; } > out/template.exe
		limit 300 "$godot" --headless --path . --export-release "Test" out/test.exe > "out/export.$config.log" 2>&1
		if ls out | grep -q -i -E '^(lib)?gdbc\.'; then
			fail "export | a library of the addon was left next to the game"
		else
			pass
		fi
	else
		limit 300 "$godot" --headless --path . --export-pack "Test" out/test.pck > "out/export.$config.log" 2>&1
	fi
	if grep -E -A3 "SCRIPT ERROR|Parse Error" "out/export.$config.log" | grep -q "addons/gdmaim"; then
		fail "export | a script of the addon reports an error: $(grep -E -m1 "SCRIPT ERROR|Parse Error" "out/export.$config.log")"
	else
		pass
	fi
	if ! cmp -s "$class_cache" out/class_cache.before; then
		fail "export | the class cache of the project was left modified"
		cp out/class_cache.before "$class_cache"
	else
		pass
	fi
	if [ -n "$(ls addons/gdmaim/backup 2> /dev/null)" ]; then
		fail "export | a backup of the files of Godot was left behind"
		rm -rf addons/gdmaim/backup
	else
		pass
	fi
	while IFS= read -r expected; do
		if [ -z "$expected" ]; then
			continue
		elif grep -q -E "$expected" "out/export.$config.log"; then
			pass
		else
			fail "export | the export does not report: $expected"
		fi
	done <<< "$(options "$config" export_log)"
	while IFS= read -r unexpected; do
		if [ -z "$unexpected" ]; then
			continue
		elif grep -q -E "$unexpected" "out/export.$config.log"; then
			fail "export | the export reports: $unexpected"
		else
			pass
		fi
	done <<< "$(options "$config" export_log_not)"

	# The cases, which the exported project runs itself
	if [ "$(option "$config" run)" = "skip" ]; then
		: # the pack has nothing to run
	elif [ -f out/test.pck ]; then
		(cd "$work/run" && limit 120 "$godot" --headless --main-pack ../project/out/test.pck > "../project/out/run.$config.log" 2>&1)
		passed_here=$((passed_here + $(grep -c '^\[CASE\] PASS' "out/run.$config.log")))
		failed_here=$((failed_here + $(grep -c '^\[CASE\] FAIL' "out/run.$config.log")))
		grep '^\[CASE\] FAIL' "out/run.$config.log" | sed 's/^\[CASE\] /  /'
		if ! grep -q '^\[DONE\]' "out/run.$config.log"; then
			fail "run | the game did not run to the end, see $project/out/run.$config.log"
		fi
		# The addon stays out of the game, and so must the extension it brings along
		if grep -q "Error loading extension" "out/run.$config.log"; then
			fail "run | the game looks for an extension that is not in it: $(grep -m1 "Error loading extension" "out/run.$config.log")"
		else
			pass
		fi
	else
		fail "export | nothing was exported, see $project/out/export.$config.log"
	fi

	# The log of that run, led back to the source with the source map of the export
	if [ -n "$(options "$config" translate_log)" ]; then
		translate=(limit 120 "$godot" --headless --path . -s res://addons/gdmaim/util/translate_log.gd --)
		rm -f "out/translated.$config.log"
		"${translate[@]}" "out/run.$config.log" "--out=out/translated.$config.log" > "out/translate.$config.log" 2>&1
		while IFS= read -r expected; do
			if grep -q -E "$expected" "out/translated.$config.log" 2> /dev/null; then
				pass
			else
				fail "translate log | the translated log does not have: $expected"
			fi
		done <<< "$(options "$config" translate_log)"

		# A log which does not name its source map has to be given one, and is printed without --out
		grep -v "GDMaim - Source map" "out/run.$config.log" > "out/unnamed.$config.log"
		source_map="$(ls addons/gdmaim/source_maps/*.map | tail -n 1)"
		if "${translate[@]}" "out/unnamed.$config.log" "--map=$source_map" 2> /dev/null | grep -q -E "$(option "$config" translate_log)"; then
			pass
		else
			fail "translate log | with --map, the log that gets printed is not translated"
		fi
		if "${translate[@]}" "out/unnamed.$config.log" > "out/translate_unnamed.$config.log" 2>&1; then
			fail "translate log | a log which names no source map was taken without --map"
		elif grep -q "does not name its source map" "out/translate_unnamed.$config.log"; then
			pass
		else
			fail "translate log | no word on the source map missing, see $project/out/translate_unnamed.$config.log"
		fi

		# The same log in the source map viewer
		limit 120 "$godot" --headless --path . -s "$tests/check_viewer_log.gd" -- "out/run.$config.log" > "out/viewer.$config.log" 2>&1
		grep '^\[CASE\] FAIL' "out/viewer.$config.log" | sed 's/^\[CASE\] /  /'
		passed_here=$((passed_here + $(grep -c '^\[CASE\] PASS' "out/viewer.$config.log")))
		failed_here=$((failed_here + $(grep -c '^\[CASE\] FAIL' "out/viewer.$config.log")))
		if ! grep -q '^\[DONE\]' "out/viewer.$config.log"; then
			fail "source map viewer | the check did not run to the end, see $project/out/viewer.$config.log"
		fi
	fi

	if [ -f out/test.pck ] && [ "$(option "$config" source_map)" = "check" ]; then
		# The game names its source map when it starts, ahead of anything else it prints
		if grep -m1 -E "GDMaim - Source map|^\[CASE\]" "out/run.$config.log" | grep -q "GDMaim - Source map"; then
			pass
		else
			fail "source map/name printed at startup | "
		fi
		limit 120 "$godot" --headless --path . -s "$tests/check_source_map.gd" > "out/source_map.$config.log" 2>&1
		grep '^\[CASE\] FAIL' "out/source_map.$config.log" | sed 's/^\[CASE\] /  /'
		passed_here=$((passed_here + $(grep -c '^\[CASE\] PASS' "out/source_map.$config.log")))
		failed_here=$((failed_here + $(grep -c '^\[CASE\] FAIL' "out/source_map.$config.log")))
		if ! grep -q '^\[DONE\]' "out/source_map.$config.log"; then
			fail "source map | the check did not run to the end, see $project/out/source_map.$config.log"
		fi
	fi

	echo "  $passed_here passed, $failed_here failed"
	total=$((total + passed_here + failed_here))
	failed=$((failed + failed_here))
done

echo
if [ "$failed" -gt 0 ]; then
	echo "$failed of $total checks failed. Logs are in $project/out"
	exit 1
fi
echo "All $total checks passed."
