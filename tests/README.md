# Tests

These tests export a small Godot project with GDMaim and run what got exported. A case passes if the
exported game still does what its source says.

## Running

You need the Godot editor (4.5 or newer) and bash. On Windows, Git Bash will do.

```bash
tests/run.sh
```

It looks for the editor as `godot`. Set `GODOT` to use another one:

```bash
GODOT=/path/to/godot tests/run.sh
```

A run takes three to four minutes and ends with `All 1017 checks passed.` or with the cases that failed:

```
== default
  FAIL | parser/enums | value set to another value
  52 passed, 1 failed
```

The exit code is 0 only if everything passed. To run some configurations only, name them:
`tests/run.sh default plain`.

Nothing is written to the repository. The project is copied to `tests/.work` together with the addon,
and the logs of every export and run are in `tests/.work/project/out`.

Do not start two runs at the same time: GDMaim keeps the files it converts in the user data folder of
the project, which every run shares.

## How it works

`tests/project` is a Godot project with one scene. Its script, `main.gd`, runs every case in
`project/cases` and prints a line for each. A case is a script with a method `run_case()` that returns
`"ok"`, or a few words on what is wrong.

`run.sh` exports that project once for every file in `tests/configs` and runs each exported pack.
Around every export it also checks that no script of the addon reported an error and that the files
of Godot which GDMaim edits during an export are back to what they were, and of every game that it
does not look for an extension which is not in it. For the configuration `default` it checks the
source map as well, with `check_source_map.gd`.

## Configurations

A configuration is the `export.cfg` GDMaim reads its settings from. Settings it does not mention keep
their default value.

| Configuration | What it exports with |
| --- | --- |
| `plain` | No GDMaim at all (feature tag `no_gdmaim`). A case that fails here is wrong itself. |
| `default` | The settings GDMaim starts out with. The export has to warn about the strings of `export/names_in_strings.gd` that name something which gets renamed, and about those alone. |
| `other_seed` | The same with another seed, which names and shuffles everything differently. |
| `strip_typing` | Strip Static Typing turned on. |
| `rename_only` | Only renaming: no post-processing, no shuffling, no source map name in the game. Check Exported Scripts is on and has nothing to report. |
| `no_rename` | Enable Obfuscation turned off, which leaves post-processing. Inline Constants and Inline Enums are on, and must do nothing then. |
| `empty_prefix` | No prefix for generated names. |
| `fallbacks` | An empty preprocessor prefix and an empty list of characters. |
| `binary` | Export Mode set to Binary: scripts as binary tokens, scenes and resources as binary files. Check Exported Scripts is on, as in `verify`, and the log of the game is translated, as in `translate`. |
| `compressed` | Export Mode set to Compressed, with Encode Strings, Inline Constants and Inline Enums. |
| `no_scripts` | A preset that leaves every script out. Only the export is checked, the pack is not run. |
| `addon_not_excluded` | No GDMaim, and a preset that does not leave the addon out, which the export plugin then does. Exports the game and not just its pack. |
| `verify` | The settings GDMaim starts out with and Check Exported Scripts, which has to report `broken/after_export.gd`: a script no case loads, and which does not compile once the regex filter has removed a line of it. `broken/a_needs_broken.gd` preloads that script, and has to be counted as held up by it instead of being reported. The check is also run on the game by `run.sh`, where `export/checked_autoloads.gd` sets a static variable from an autoload when it loads, which must not find the autoload freed. |
| `translate` | The settings GDMaim starts out with, a compressed source map among them. The game runs `broken/at_runtime.gd` (feature tag `crash`), which fails twice. Its log, translated with `util/translate_log.gd`, has to name the functions, the variable and the lines of the source. `check_viewer_log.gd` checks the same in the tab `Log` of the source map viewer. |
| `encode` | The settings GDMaim starts out with and Encode Strings: every case has to do the same with its strings encoded. Check Exported Scripts is on as well. |
| `inline` | The settings GDMaim starts out with, Inline Constants and Inline Enums: every case has to do the same with values in place of names. Encode Strings is on as well, for a string that took the place of a constant to be encoded, and Check Exported Scripts. |
| `enum_warning` | Inline Enums in a project that sets the warning `Int As Enum Without Cast` to Error: the export has to say that it leaves the keys of enums with a name as they are, and the game has to compile. The keys of an enum without a name are still replaced. |
| `binary_preset` | A preset that exports scripts as binary tokens, which GDMaim reports as an error. |

The lines beginning with `;` at the top of a configuration are for `run.sh`:

- `features` are the feature tags of the export preset. A case reads them with `OS.has_feature()` to
  tell what to expect: `renamed` if names are obfuscated, `postprocessed` if comments, filtered lines
  and feature functions are removed, `untyped` if static typing is stripped, `binary` if GDMaim
  exports scripts as binary tokens, `encoded` if strings are
  exported encoded, `inlined` if the values of constants and of the keys of enums are put in place of their names,
  `inlined_loose` if that is done for the keys of enums without a name alone, `crash` to have the game start with two errors.
- `script_export_mode` is the GDScript export mode of the preset, text if left out.
- `exclude_filter` is the filter of the preset for files to leave out, empty if left out.
- `export=game` exports the game instead of its pack alone, and has it checked that no library of the
  addon is left next to it. No export templates are needed: `run.sh` writes a file that passes for one.
- `export_log` is an expression the output of the export has to match. It may be given several times.
- `export_log_not` is one the output of the export must not match.
- `project_setting` is a setting of the project, as `section/key=value`, added to `project.godot` for
  that configuration, so the exported game has it as well. It may be given several times.
- `translate_log` has the log of the game translated with the source map of the export. It is an
  expression the translated log has to match, and may be given several times. The game has to run
  with the feature tag `crash` for this, as `check_viewer_log.gd` looks for its errors.
- `run=skip` keeps the exported pack from being run.
- `source_map=check` has the source map checked.

## Adding a case

1. Add a script to `project/cases`, in the folder of the part of GDMaim it is about. Say in a comment
   at its top what it is about.
2. Give it a method `run_case()` that returns `"ok"` or what is wrong. Extend `Node` if the case has to
   be in the scene tree. `run_case()` may `await`.
3. Add it to the list in `project/main.gd`.

GDMaim renames by name across the whole project, so give the members of a case names no other case
uses. The cases here begin them with two letters of their own, like `sc_health` in `parser/scopes.gd`.

A case has to pass in every configuration, `plain` included. Where the outcome depends on how the
project got exported, ask `OS.has_feature()`.

## What is not covered

- The dock, and the source map viewer apart from its tab `Log`.
- Binary scenes (`.scn`) and binary resources that depend on other files.
- Anything that only shows in a running editor, like a second export in the same session.
