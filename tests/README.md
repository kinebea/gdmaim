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

A run takes three to four minutes and ends with `All 680 checks passed.` or with the cases that failed:

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
of Godot which GDMaim edits during an export are back to what they were. For the configuration
`default` it checks the source map as well, with `check_source_map.gd`.

## Configurations

A configuration is the `export.cfg` GDMaim reads its settings from. Settings it does not mention keep
their default value.

| Configuration | What it exports with |
| --- | --- |
| `plain` | No GDMaim at all (feature tag `no_gdmaim`). A case that fails here is wrong itself. |
| `default` | The settings GDMaim starts out with. |
| `other_seed` | The same with another seed, which names and shuffles everything differently. |
| `strip_typing` | Strip Static Typing turned on. |
| `rename_only` | Only renaming: no post-processing, no shuffling, no source map name in the game. Check Exported Scripts is on and has nothing to report. |
| `no_rename` | Enable Obfuscation turned off, which leaves post-processing. |
| `empty_prefix` | No prefix for generated names. |
| `fallbacks` | An empty preprocessor prefix and an empty list of characters. |
| `binary` | Export Mode set to Binary: scripts as binary tokens, scenes and resources as binary files. Check Exported Scripts is on, as in `verify`. |
| `compressed` | Export Mode set to Compressed. |
| `no_scripts` | A preset that leaves every script out. Only the export is checked, the pack is not run. |
| `addon_not_excluded` | No GDMaim, and a preset that does not leave the addon out, which the export plugin then does. Exports the game and not just its pack. |
| `verify` | The settings GDMaim starts out with and Check Exported Scripts, which has to report `broken/after_export.gd`: a script no case loads, and which does not compile once the regex filter has removed a line of it. |
| `binary_preset` | A preset that exports scripts as binary tokens, which GDMaim reports as an error. |

The lines beginning with `;` at the top of a configuration are for `run.sh`:

- `features` are the feature tags of the export preset. A case reads them with `OS.has_feature()` to
  tell what to expect: `renamed` if names are obfuscated, `postprocessed` if comments, filtered lines
  and feature functions are removed, `untyped` if static typing is stripped, `binary` if GDMaim
  exports scripts as binary tokens.
- `script_export_mode` is the GDScript export mode of the preset, text if left out.
- `exclude_filter` is the filter of the preset for files to leave out, empty if left out.
- `export=game` exports the game instead of its pack alone, and has it checked that no library of the
  addon is left next to it. No export templates are needed: `run.sh` writes a file that passes for one.
- `export_log` is an expression the output of the export has to match. It may be given several times.
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

- The dock and the source map viewer.
- Binary scenes (`.scn`) and binary resources that depend on other files.
- Anything that only shows in a running editor, like a second export in the same session.
