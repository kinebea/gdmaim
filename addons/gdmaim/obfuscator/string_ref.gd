extends RefCounted


const _StringRef := preload("string_ref.gd")

var _value : String
var _root : WeakRef


func _init(value : String = "") -> void:
	_value = value


func _to_string() -> String:
	return _value if !_root else _root.get_ref()._to_string()


func set_value(value : String) -> void:
	_value = value


func get_value() -> String:
	return str(self)


func link(other : _StringRef) -> void:
	_root = weakref(other)
