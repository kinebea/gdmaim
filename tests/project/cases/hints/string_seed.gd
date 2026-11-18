extends RefCounted

## ##OBFUSCATE_STRINGS_SEED changes what a string becomes.
## The README once called it OBFUSCATE_STRING_SEED, which is accepted too.

func run_case() -> String:
	var unseeded : String = "Shared Text Sq" ##OBFUSCATE_STRINGS
	var seeded : String = "Shared Text Sq" ##OBFUSCATE_STRINGS ##OBFUSCATE_STRINGS_SEED 1000
	var documented : String = "Shared Text Sq" ##OBFUSCATE_STRINGS ##OBFUSCATE_STRING_SEED 1000
	if !OS.has_feature("renamed"):
		return "ok" if unseeded == seeded and seeded == documented else "strings changed without renaming"
	if seeded == unseeded:
		return "OBFUSCATE_STRINGS_SEED has no effect"
	if documented != seeded:
		return "OBFUSCATE_STRING_SEED is not the same as OBFUSCATE_STRINGS_SEED"
	return "ok"
