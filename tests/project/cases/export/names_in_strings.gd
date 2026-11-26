extends Node

## A string that names a method, a property or a signal which gets renamed is not renamed with it.
## GDMaim warns about one given to call(), call_deferred(), connect() and the like when it exports,
## which the configurations look for in the output of the export. The calls that would fail once
## the names are renamed are never made.

signal ns_signal
var ns_property : int = 0
var ns_dictionary : Dictionary = { "ns_property": 1 }

func ns_method() -> void:
	pass

func ns_hinted() -> void:
	pass

func ns_not_run() -> void:
	call_deferred("ns_method")
	connect("ns_signal", ns_method)
	set("ns_property", 1)
	create_tween().tween_property(self, "ns_property", 1, 1.0)
	Callable(self, "ns_method").call()
	self.has_method(&"ns_method")
	rpc_id(1,
		"ns_method")
	# Not warned about: a string a hint renames, a key of a dictionary, a method of Godot, a name nothing has
	call_deferred("ns_hinted") ##OBFUSCATE_STRINGS
	ns_dictionary.get("ns_property")
	call_deferred("queue_free")
	call_deferred("ns_unknown")
	call_deferred("ns_" + "method")

func run_case() -> String:
	return "ok"
