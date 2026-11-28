extends RefCounted


enum _Type {
	NONE = 0,
	SYMBOL = 2**0,
	KEYWORD = 2**1,
	LITERAL = 2**2,
	NUMBER_LITERAL = 2**3,
	STRING_LITERAL = 2**4,
	STRING_MULTI_LINE = 2**5,
	NODE_PATH = 2**6,
	ANNOTATION = 2**7,
	PUNCTUATOR = 2**8,
	OPERATOR = 2**9,
	COMMENT = 2**10,
	WHITESPACE = 2**11,
	INDENTATION = 2**12,
	LINE_BREAK = 2**13,
	STATEMENT_BREAK = 2**14,
}

const _StringRef := preload("../../string_ref.gd")
const _SymbolTable := preload("../../symbol_table.gd")

var type : _Type
var idx : int
var line : int
var source_line : int = -1 # Line of the source code it is from, if any
var decorator : String
var symbol : _SymbolTable._Symbol

var _value := _StringRef.new()


func _init(type : _Type, value : String, idx : int, line : int, decorator : String = "") -> void:
	self.type = type
	self.idx = idx
	self.line = line
	self.decorator = decorator
	_value.set_value(value)


func _to_string() -> String:
	return str(get_value())


func set_value(new_val : String) -> void:
	if decorator and new_val.begins_with(decorator):
		_value.set_value(new_val.substr(len(decorator)))
	else:
		_value.set_value(new_val)


func get_value(decorated : bool = true) -> String:
	if !decorated:
		return str(_value)
	return decorator + str(_value) + decorator


func link_value(root : _StringRef) -> void:
	_value.link(root)


func link_symbol(symbol : _SymbolTable._Symbol) -> void:
	self.symbol = symbol
	_value.link(symbol.name)


func has_value(value : String) -> bool:
	return get_value() == value


func is_symbol(value : String = "") -> bool:
	return type == _Type.SYMBOL and (!value or get_value() == value)


func is_keyword(value : String = "") -> bool:
	return type == _Type.KEYWORD and (!value or get_value() == value)


func is_literal(value : String = "") -> bool:
	return type == _Type.LITERAL and (!value or get_value() == value)


func is_number_literal(value : String = "") -> bool:
	return type == _Type.NUMBER_LITERAL and (!value or get_value() == value)


func is_string_literal(value : String = "") -> bool:
	return (type == _Type.STRING_LITERAL or type == _Type.STRING_MULTI_LINE) and (!value or get_value() == value)

func is_string_multiline(value : String = "") -> bool:
	return type == _Type.STRING_MULTI_LINE and (!value or get_value() == value)


func is_node_path(value : String = "") -> bool:
	return type == _Type.NODE_PATH and (!value or get_value() == value)


func is_annotation(value : String = "") -> bool:
	return type == _Type.ANNOTATION and (!value or get_value() == value)


func is_punctuator(value : String = "") -> bool:
	return type == _Type.PUNCTUATOR and (!value or get_value() == value)


func is_operator(value : String = "") -> bool:
	return type == _Type.OPERATOR and (!value or get_value() == value)


func is_comment(value : String = "") -> bool:
	return type == _Type.COMMENT and (!value or get_value() == value)


func is_whitespace(value : String = "") -> bool:
	return type == _Type.WHITESPACE and (!value or get_value() == value)


func is_indentation(value : String = "") -> bool:
	return type == _Type.INDENTATION and (!value or get_value() == value)


func is_line_break(value : String = "") -> bool:
	return type == _Type.LINE_BREAK and (!value or get_value() == value)


func is_statement_break(value : String = "") -> bool:
	return type == _Type.STATEMENT_BREAK and (!value or get_value() == value)


func is_of_type(type_bitflags : int) -> bool:
	return (type & type_bitflags) || type == type_bitflags
