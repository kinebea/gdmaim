extends RefCounted


const _Logger := preload("../../logger.gd")
const _Settings := preload("../../settings.gd")
const _PreprocessorHints := preload("preprocessor_hints.gd")
const _SymbolTable := preload("../symbol_table.gd")
const _Parser := preload("parser/parser.gd")
const _Token := preload("tokenizer/token.gd")
const _Tokenizer := preload("tokenizer/tokenizer.gd")
const _AST := preload("parser/ast.gd")
const _Builtins = preload("../../builtins.gd")

# The functions which take the name of a method, a property or a signal, by the index of that argument
const NAME_ARGUMENTS : Dictionary = {
	"call": 0, "call_deferred": 0, "callv": 0, "has_method": 0, "rpc": 0, "rpc_id": 1,
	"connect": 0, "disconnect": 0, "is_connected": 0, "emit_signal": 0, "has_signal": 0,
	"get": 0, "set": 0, "set_deferred": 0, "tween_property": 1, "Callable": 1, "Signal": 1,
}
# The ones a Dictionary has as well, which only count for the script itself: get("name") or self.get("name")
const NAME_ARGUMENTS_OF_SELF : PackedStringArray = ["get", "set"]
# The ones a Signal has as well, which take what to connect to and not a name
const SIGNAL_METHODS : PackedStringArray = ["connect", "disconnect", "is_connected"]
# The functions which print what they are given, whose strings are not names
const PRINT_FUNCTIONS : PackedStringArray = [
	"print", "prints", "printt", "printerr", "printraw", "print_rich", "print_verbose", "print_debug",
	"push_error", "push_warning",
]
# The functions which give the names of members, as they are once renamed
const NAME_LISTS : PackedStringArray = [
	"get_method_list", "get_script_method_list", "get_property_list", "get_script_property_list",
	"get_signal_list", "get_script_signal_list", "get_script_constant_map",
]
# The methods of String which pick a name by a part of it
const NAME_PATTERNS : PackedStringArray = ["begins_with", "ends_with", "contains", "containsn", "match", "matchn"]

var path : String
var source_code : String
var generated_code : String
var parser : _Parser
var tokenizer : _Tokenizer

var _symbol_table : _SymbolTable
var _ast : _AST._ASTNode
var _encoded_strings : Dictionary # The strings that get exported encoded, and whether a space has to go ahead of them
var _plain_lines : Dictionary # The lines of source code whose strings a hint keeps from being encoded

func _init(path : String) -> void:
	self.path = path

func parse(source_code : String, symbol_table : _SymbolTable, autoload_symbol : _SymbolTable._Symbol = null) -> void:
	# Carriage returns would otherwise end up in comments and their preprocessor hints
	source_code = source_code.replace("\r\n", "\n")
	self.source_code = source_code
	_symbol_table = symbol_table
	tokenizer = _Tokenizer.new()
	tokenizer.read(source_code)
	parser = _Parser.new()
	_ast = parser.read(tokenizer, symbol_table, autoload_symbol)

func run(features : PackedStringArray) -> bool:
	if !parser:
		_Logger.write("ERROR: ScriptObfuscator.run() - No parsed data!")
		return false
	
	if tokenizer.is_static_typing_stripped():
		_strip_static_typing()
	
	tokenizer.reset()
	
	var _str_processing : bool = false
	var plain_strings : bool = false
	while !tokenizer.is_eof():
		var token : _Token = tokenizer.get_next()
		var next_token : _Token = tokenizer.peek()
		var line : _Tokenizer._Line = tokenizer.get_output_line(token.line)
		var prev_line : _Tokenizer._Line = tokenizer.get_output_line(token.line-1)
		
		if token.type == _Token._Type.COMMENT:
			var value : String = token.get_value().strip_edges().trim_prefix(_Settings.current.preprocessor_prefix).get_slice(" ", 0)
			match value:
				_PreprocessorHints.START_OBFUSCATE_STRINGS:
					_str_processing = true
				_PreprocessorHints.END_OBFUSCATE_STRINGS:
					_str_processing = false		
				_PreprocessorHints.START_PLAIN_STRINGS:
					plain_strings = true
				_PreprocessorHints.END_PLAIN_STRINGS:
					plain_strings = false
		
		if plain_strings or tokenizer.has_source_hint(token.source_line, _PreprocessorHints.PLAIN_STRINGS):
			_plain_lines[token.source_line] = true
		
		# Hints for strings go by the line of source code, as several of those may have been merged into one
		if tokenizer.has_source_hint(token.source_line, _PreprocessorHints.OBFUSCATE_STRINGS_SEED):
			_symbol_table.set_custom_seed(tokenizer.get_source_hint_args(token.source_line, _PreprocessorHints.OBFUSCATE_STRINGS_SEED).to_int())
		else:
			_symbol_table.set_custom_seed(0)
	
		if _str_processing or tokenizer.has_source_hint(token.source_line, _PreprocessorHints.OBFUSCATE_STRINGS):
			_string_obfuscation(token)
			
		else:
			_string_param_obfuscation(token, next_token)
		
		if !_Settings.current.feature_filters:
			continue
		
		if prev_line and prev_line.has_hint(_PreprocessorHints.FEATURE_FUNC):
			_func_feature_filter(token, line, prev_line.get_hint_args(_PreprocessorHints.FEATURE_FUNC), features)
	
	if _Settings.current.obfuscation_enabled and _Settings.current.shuffle_top_level:
		_shuffle_toplevel()
	
	_strip_code()

	if _Settings.current.encode_strings:
		_encode_strings()

	return true


func generate_source_code() -> String:
	_keep_signs_apart()
	if _encoded_strings.is_empty():
		generated_code = tokenizer.generate_source_code()
		return generated_code

	# A string is encoded as late as this, since it may have the name of a symbol for its value
	var code : PackedStringArray = []
	for line in tokenizer.get_output_lines():
		for token in line.tokens:
			code.append(_get_encoded_string(token) if _encoded_strings.has(token) else token.get_value())
	generated_code = "".join(code)
	return generated_code


# Inside brackets Godot takes a + or - that begins a line for the sign of a number right behind it,
# which leaves two values in a row, as in "x\n+2": a space after the operator keeps it one
func _keep_signs_apart() -> void:
	for line in tokenizer.get_output_lines():
		var begins : bool = true # Nothing but spacing since the line began
		var i : int = 0
		while i < line.tokens.size():
			var token : _Token = line.tokens[i]
			i += 1
			if token.is_of_type(_Token._Type.INDENTATION | _Token._Type.WHITESPACE | _Token._Type.COMMENT):
				continue
			var next : _Token = line.tokens[i] if i < line.tokens.size() else null
			if begins and (token.is_operator("+") or token.is_operator("-")) and next and _is_number(next.get_value()):
				line.insert_token(i, _Token.new(_Token._Type.WHITESPACE, " ", -1, token.line))
			begins = token.is_line_break() or token.is_punctuator("\n")


static func _is_number(value : String) -> bool:
	return !value.is_empty() and (value[0].is_valid_int() or (value[0] == "." and value.length() > 1 and value[1].is_valid_int()))


func generate_line_mappings() -> Array[Dictionary]:
	var mappings_in : Dictionary
	var mappings_out : Dictionary

	# Every token knows the line of source code it is from, which holds
	# no matter how lines got merged, moved or removed
	var out_line : int = 0
	for line in tokenizer.get_output_lines():
		for token in line.tokens:
			var line_breaks : int = token.get_value().count("\n")
			if token.source_line != -1:
				# A line break belongs to the line it ends, while a string may span several
				for l in (1 if token.is_line_break() else line_breaks + 1):
					if !mappings_in.has(token.source_line + l):
						mappings_in[token.source_line + l] = out_line + l
					if !mappings_out.has(out_line + l):
						mappings_out[out_line + l] = token.source_line + l
			out_line += line_breaks

	# Lines of which nothing is left go by the line before them
	var last_valid : int = 0
	for i in tokenizer.line_count:
		if mappings_in.has(i):
			last_valid = mappings_in[i]
		else:
			mappings_in[i] = last_valid
	last_valid = 0
	for i in out_line + 1:
		if mappings_out.has(i):
			last_valid = mappings_out[i]
		else:
			mappings_out[i] = last_valid

	return [mappings_in, mappings_out]


func get_class_symbol() -> _SymbolTable._Symbol:
	return parser.get_class_symbol() if parser else null


# Removes type hints. This is done to the parsed script, so that
# the types are still there to tell what a symbol belongs to.
func _strip_static_typing() -> void:
	const TRIVIA : int = _Token._Type.WHITESPACE | _Token._Type.COMMENT | _Token._Type.INDENTATION | _Token._Type.STATEMENT_BREAK

	var tokens : Array[_Token]
	for token in tokenizer.get_tokens():
		if !(token.type & TRIVIA):
			tokens.append(token)

	var removed : Dictionary # Tokens to take out
	var defaults : Dictionary # Value to give a variable, by the token of its name
	var exported : bool = false
	var i : int = 0
	while i < tokens.size():
		var token : _Token = tokens[i]
		if token.is_annotation():
			if token.get_value().begins_with("@export") and !_Builtins.ATTRIBUTES.has(token.get_value()):
				exported = true
		elif token.is_keyword("var") or token.is_keyword("const"):
			# An exported variable needs its type, and a binding in a match pattern has none
			if !exported and i + 1 < tokens.size() and !parser.is_pattern_binding(tokens[i + 1]):
				_strip_variable_type(tokens, i + 1, token.is_keyword("var"), removed, defaults)
			exported = false
		elif token.is_keyword("func") or token.is_keyword("signal"):
			exported = false
			i = _strip_signature_types(tokens, i + 1, removed)
			continue
		elif token.is_keyword("for"):
			# for name : Type in ...
			if i + 2 < tokens.size() and tokens[i + 2].is_punctuator(":"):
				var end : int = _find_type_end(tokens, i + 3)
				if end != -1 and end < tokens.size() and tokens[end].is_keyword("in"):
					for j in range(i + 2, end):
						removed[tokens[j]] = true
		i += 1

	for line in tokenizer.get_output_lines():
		var kept : Array[_Token]
		for token in line.tokens:
			if removed.has(token):
				# Along with the spacing in front of it
				if kept and kept.back().is_whitespace():
					kept.pop_back()
				continue
			kept.append(token)
			if defaults.has(token):
				for added : _Token in [_Token.new(_Token._Type.OPERATOR, "=", -1, token.line), _Token.new(_Token._Type.LITERAL, defaults[token], -1, token.line)]:
					added.source_line = token.source_line
					kept.append(added)
		line.tokens = kept


# Strips the type of the variable or constant whose name is at the given index
func _strip_variable_type(tokens : Array[_Token], name_idx : int, is_var : bool, removed : Dictionary, defaults : Dictionary) -> void:
	var colon : int = name_idx + 1
	if colon + 1 >= tokens.size() or !tokens[name_idx].is_symbol() or !tokens[colon].is_punctuator(":"):
		return

	if tokens[colon + 1].is_operator("="):
		removed[tokens[colon]] = true # An inferred type, as in "var x := 1"
		return

	var end : int = _find_type_end(tokens, colon + 1)
	if end == -1:
		return # The colon begins the accessors of a property

	var next : _Token = tokens[end] if end < tokens.size() else null
	var has_value : bool = next != null and next.is_operator("=")

	# Accessors on the same line, like "var x: get = get_x"
	if end == colon + 2 and next and ["get", "set"].has(tokens[colon + 1].get_value()) and (has_value or next.is_punctuator("(")):
		return
	if next and !has_value and !next.is_punctuator(":") and !next.is_punctuator(";") and !next.is_line_break():
		return # No type after all

	if !has_value and is_var and tokenizer.is_stripped_typing_initialized():
		# Without its type the variable would start out as null, and not as what the type starts out as
		var type_name : String = tokens[end - 1].get_value() if !tokens[end - 1].is_punctuator("]") else tokens[colon + 1].get_value()
		var is_simple : bool = end == colon + 2 or tokens[colon + 2].is_punctuator("[")
		var default : String = _get_default_value(type_name) if is_simple else ""
		if !default.is_empty():
			defaults[tokens[name_idx]] = default
		elif !(is_simple and (type_name == "Variant" or type_name == "Object" or ClassDB.class_exists(type_name))) and !_symbol_table.is_class_name(type_name):
			return # Might be an enum, which starts out as 0, so this type stays

	_keep_float(tokens, colon, end)
	for i in range(colon, end):
		removed[tokens[i]] = true


# Strips the types of the parameters and the return type of a function or signal.
# The index is that of the token after the keyword. Returns the index to go on from.
func _strip_signature_types(tokens : Array[_Token], i : int, removed : Dictionary) -> int:
	if i < tokens.size() and tokens[i].is_symbol():
		i += 1 # The name, which a lambda does not have
	if i >= tokens.size() or !tokens[i].is_punctuator("("):
		return i

	var depth : int = 0
	var at_parameter : bool = false
	while i < tokens.size():
		var token : _Token = tokens[i]
		if token.is_punctuator():
			i += 1
			match token.get_value():
				"(", "[", "{":
					depth += 1
					at_parameter = depth == 1
				")", "]", "}":
					depth -= 1
					if depth == 0:
						break
				",":
					at_parameter = depth == 1
				_:
					at_parameter = false
		elif token.is_line_break():
			i += 1
		elif at_parameter and token.is_symbol() and i + 2 < tokens.size() and tokens[i + 1].is_punctuator(":"):
			at_parameter = false
			var end : int = _find_type_end(tokens, i + 2)
			if tokens[i + 2].is_operator("="):
				end = i + 2 # An inferred type, as in "a := 1"
			if end == -1:
				i += 2
			else:
				_keep_float(tokens, i + 1, end)
				for j in range(i + 1, end):
					removed[tokens[j]] = true
				i = end
		else:
			at_parameter = false
			i += 1

	if i < tokens.size() and tokens[i].is_operator("->"):
		var end : int = _find_type_end(tokens, i + 1)
		if end != -1:
			for j in range(i, end):
				removed[tokens[j]] = true
			i = end

	return i


# A whole number that is given to a float is a float, which it has to be without the type as well.
# The type goes from the colon at the given index up to the end, where the value may follow
func _keep_float(tokens : Array[_Token], colon : int, end : int) -> void:
	if end != colon + 2 or !tokens[colon + 1].is_symbol("float") or end >= tokens.size() or !tokens[end].is_operator("="):
		return
	var i : int = end + 1
	if i < tokens.size() and tokens[i].is_operator("-"):
		i += 1
	if i >= tokens.size() or !tokens[i].is_number_literal():
		return
	# The number has to be all there is to the value
	if i + 1 < tokens.size() and !tokens[i + 1].is_line_break() and !(tokens[i + 1].is_punctuator() and ",):;".contains(tokens[i + 1].get_value())):
		return
	
	var number : String = tokens[i].get_value().replace("_", "")
	if number.begins_with("0x"):
		number = str(number.hex_to_int())
	elif number.begins_with("0b"):
		number = str(number.bin_to_int())
	if number.is_valid_int():
		tokens[i].set_value(number + ".0")


# Returns the index after the type that begins at the given index, like Array[int] or Tween.EaseType.
# Returns -1 if there is no type.
func _find_type_end(tokens : Array[_Token], i : int) -> int:
	if i >= tokens.size() or !tokens[i].is_symbol():
		return -1

	i += 1
	while i + 1 < tokens.size() and tokens[i].is_punctuator(".") and tokens[i + 1].is_symbol():
		i += 2

	if i < tokens.size() and tokens[i].is_punctuator("["):
		var depth : int = 0
		while i < tokens.size():
			if tokens[i].is_punctuator("["):
				depth += 1
			elif tokens[i].is_punctuator("]"):
				depth -= 1
				if depth == 0:
					return i + 1
			elif tokens[i].is_line_break():
				return -1
			i += 1
		return -1

	return i


# Returns what a variable of the given built-in type starts out as, or nothing if it is no such type
func _get_default_value(type_name : String) -> String:
	for type in range(TYPE_BOOL, TYPE_MAX):
		if type != TYPE_OBJECT and type_string(type) == type_name:
			return _Tokenizer.get_default_value(type)
	return ""


func _string_obfuscation(token : _Token) -> void:
	if !token.is_string_literal():
		return
	
	var str : String = token.get_value(false)
	if str.is_empty():
		return
	
	var regex : RegEx = RegEx.create_from_string("(%[\\d\\.]*[a-zA-Z]|\\{\\d+\\})", false)
	if regex.is_valid():
		var fragments : PackedStringArray = []
		var candy_holders : PackedStringArray = []
		var last_candy_idx : int = 0
		var pimpampum : String = "__HOCUSPOCUS__"
	
		var matches : Array[RegExMatch] = regex.search_all(str)
		for rmatch in matches:
			var text_before : String = str.substr(last_candy_idx, rmatch.get_start() - last_candy_idx)
			
			fragments.append(text_before)
			fragments.append(pimpampum)
			candy_holders.append(rmatch.get_string())			
			
			last_candy_idx = rmatch.get_end()
		
		if candy_holders.size() > 0:	
			var candy : int = 0
			var end_pray : PackedStringArray = [" ", "\t", "\n"] # wilwilwilcard String!
			var tail : String = str.substr(last_candy_idx)
			
			if !tail.is_empty():
				fragments.append(tail)
			
			tail = ""
				
			for idx : int in range(0, fragments.size(), 1):
				var fragment : String = fragments[idx]
				
				# avoid obfuscating whitespace-only strings
				var text : String = fragment.strip_edges()
				if text.is_empty():
					tail += fragment
					continue		
								
				elif fragment == pimpampum:
					if candy < candy_holders.size():
						tail += candy_holders[candy]
						candy += 1
					continue
				
				var str_begin : String = fragment[0]
				var str_end : String = fragment[fragment.length() - 1]

				if !(str_begin in end_pray):
					str_begin = ""
				
				if !(str_end in end_pray):
					str_end = ""
				
				tail += str(str_begin, _symbol_table.obfuscate_string_global(text), str_end)
			
			for x in range(candy, candy_holders.size(), 1):
				tail += candy_holders[x]
				
			# prevent set_value from removing the first character if it's % instead of a quote "
			token.set_value(token.decorator + tail)
			return
			
	token.set_value(_symbol_table.obfuscate_string_global(str))


func _string_param_obfuscation(token : _Token, next_token : _Token) -> void:
	if !token.symbol or !next_token or !next_token.is_punctuator("("):
		return
	
	var symbol : _SymbolTable._Symbol = token.symbol
	if !symbol.has_string_params():
		return
	
	var param : int = 0
	var pth : int = 0
	var maybe_str_param : bool = true
	while !tokenizer.is_eof():
		token = tokenizer.get_next()
		if token.is_punctuator():
			if token.has_value("("):
				pth += 1
			elif token.has_value(")"):
				pth -= 1
				if pth <= 0:
					break
			elif token.has_value(",") and pth == 1:
				param += 1
				maybe_str_param = true
			continue
		elif maybe_str_param and token.is_string_literal() and symbol.is_string_param(param):
			var str : String = token.get_value(false)
			token.set_value(_symbol_table.obfuscate_string_global(str))
		maybe_str_param = false


## The strings which name something that gets renamed, given where a name is expected, as in
## call_deferred("my_method"): the string stays as it is, unless a hint has it renamed as well.
## Each one as [line of source, name]. Takes the output of run()
func find_unrenamed_names() -> Array:
	var tokens : Array[_Token] = _get_code_tokens()
	var found : Array = []
	for i in tokens.size() - 1:
		var at : int = _find_written_name(tokens, i)
		if at < 0:
			continue
		var name : String = tokens[at].get_value(false)
		var symbol : _SymbolTable._Symbol = _symbol_table.find_global_symbol(name)
		if symbol and symbol.get_name() != name:
			found.append([tokens[at].source_line, name])
	return found


# A function which reads the names of members, as from get_script_method_list(), and picks some by a part
# of them, as with begins_with("read_"), does not find those which get renamed. Each call that picks
# what gets renamed, as [line of source, the method, its argument, the function with the names, the names]
func find_names_lost_by_pattern() -> Array:
	var tokens : Array[_Token] = _get_code_tokens()
	var found : Array = []
	var list : String # A function of NAME_LISTS that the function the tokens are in calls
	var picks : Array # The calls of NAME_PATTERNS in that function
	for i in tokens.size() + 1:
		# A function, and not a lambda, begins, or the script ends
		if i == tokens.size() or (tokens[i].is_keyword("func") and i + 1 < tokens.size() and tokens[i + 1].is_symbol()):
			for pick in (picks if list else []):
				var lost : PackedStringArray = _symbol_table.find_names_lost_by(pick[1], pick[2])
				if lost:
					found.append(pick + [list, lost])
			list = ""
			picks = []
			continue
		var token : _Token = tokens[i]
		if !token.is_symbol() or i + 1 >= tokens.size() or !tokens[i + 1].is_punctuator("("):
			continue
		if NAME_LISTS.has(token.get_value()):
			list = list if list else token.get_value()
		elif NAME_PATTERNS.has(token.get_value()) and i > 0 and tokens[i - 1].is_punctuator(".") and i + 3 < tokens.size() and tokens[i + 2].is_string_literal() and (tokens[i + 3].is_punctuator(")") or tokens[i + 3].is_punctuator(",")):
			picks.append([tokens[i + 2].source_line, token.get_value(), tokens[i + 2].get_value(false)])
	return found


# A function which gives a name that is not written out where a name is expected, as in get(property),
# does not find what gets renamed by the strings it may build that name from: a string that is a name,
# as in ["speed"], or one that a name begins or ends with, as in "slot_" + kind. Each string of such a
# function that would not find what gets renamed, as [line of source, how the string is put together
# with something else ("" for not at all, or begins_with, ends_with, contains), the string, the method
# given the name, the names]
func find_names_given_by_variable() -> Array:
	var tokens : Array[_Token] = _get_code_tokens()
	var found : Array = []
	var given : String # A method of NAME_ARGUMENTS given a name not written out in the function
	var strings : Array # The strings of that function, as [index of the token, how it is put together]
	var written : Dictionary # The strings given alone where a name is expected, which find_unrenamed_names() has
	for i in tokens.size() + 1:
		# A function, and not a lambda, begins, or the script ends
		if i == tokens.size() or (tokens[i].is_keyword("func") and i + 1 < tokens.size() and tokens[i + 1].is_symbol()):
			for string in (strings if given else []):
				var token : _Token = tokens[string[0]]
				var text : String = token.get_value(false)
				var lost : PackedStringArray
				if string[1]:
					lost = _symbol_table.find_names_lost_by(string[1], text)
				elif !written.has(string[0]) and !_is_key(tokens, string[0]):
					var symbol : _SymbolTable._Symbol = _symbol_table.find_global_symbol(text)
					if symbol and symbol.get_name() != text:
						lost.append(text)
				if lost:
					found.append([token.source_line, string[1], text, given, lost])
			given = ""
			strings = []
			continue

		var token : _Token = tokens[i]
		if token.is_string_literal() and !token.get_value(false).is_empty() and !PRINT_FUNCTIONS.has(_get_enclosing_call(tokens, i)):
			var before : bool = i > 0 and tokens[i - 1].is_operator("+")
			var after : bool = i + 1 < tokens.size() and tokens[i + 1].is_operator("+")
			strings.append([i, "contains" if before and after else "ends_with" if before else "begins_with" if after else ""])
		elif _find_name_argument(tokens, i) >= 0:
			var at : int = _find_written_name(tokens, i)
			if at >= 0:
				written[at] = true
			# What a Signal connects to is not a name: some_signal.connect(_on_some_signal)
			elif !given and !(SIGNAL_METHODS.has(token.get_value()) and i > 0 and tokens[i - 1].is_punctuator(".")):
				given = token.get_value()
	return found


# The function called with the given token in its arguments, or "" for none
func _get_enclosing_call(tokens : Array[_Token], i : int) -> String:
	var depth : int = 0
	for at in range(i - 1, 0, -1):
		if tokens[at].is_punctuator() and ")]}".contains(tokens[at].get_value()):
			depth += 1
		elif tokens[at].is_punctuator() and "([{".contains(tokens[at].get_value()):
			depth -= 1
			if depth < 0:
				return tokens[at - 1].get_value() if tokens[at].is_punctuator("(") and tokens[at - 1].is_symbol() else ""
		elif tokens[at].is_keyword("func"):
			break
	return ""


# Whether the string at the given token is the key of a Dictionary: { "key": 1 }, values["key"] or
# values.get("key")
func _is_key(tokens : Array[_Token], i : int) -> bool:
	if i + 1 < tokens.size() and tokens[i + 1].is_punctuator(":"):
		return true
	if i < 2 or i + 1 >= tokens.size():
		return false
	if tokens[i - 1].is_punctuator("[") and tokens[i + 1].is_punctuator("]"):
		return tokens[i - 2].is_symbol() or tokens[i - 2].is_punctuator(")") or tokens[i - 2].is_punctuator("]")
	return i >= 4 and tokens[i - 1].is_punctuator("(") and tokens[i - 2].get_value() in ["get", "set", "has", "erase"] and tokens[i - 3].is_punctuator(".") and !tokens[i - 4].is_literal("self")


# The first token of the argument with the name, of a call of NAME_ARGUMENTS at the given token, or -1
func _find_name_argument(tokens : Array[_Token], i : int) -> int:
	var token : _Token = tokens[i]
	if !token.is_symbol() or !NAME_ARGUMENTS.has(token.get_value()) or i + 1 >= tokens.size() or !tokens[i + 1].is_punctuator("("):
		return -1
	if NAME_ARGUMENTS_OF_SELF.has(token.get_value()) and i >= 2 and tokens[i - 1].is_punctuator(".") and !tokens[i - 2].is_literal("self"):
		return -1

	var argument : int = 0
	var depth : int = 0
	var at : int = i + 2
	while at < tokens.size() and argument < NAME_ARGUMENTS[token.get_value()]:
		if tokens[at].is_punctuator() and "([{".contains(tokens[at].get_value()):
			depth += 1
		elif tokens[at].is_punctuator() and ")]}".contains(tokens[at].get_value()):
			depth -= 1
			if depth < 0:
				break
		elif tokens[at].is_punctuator(",") and depth == 0:
			argument += 1
		at += 1
	if depth < 0 or at >= tokens.size() or tokens[at].is_punctuator(")"):
		return -1
	return at


# The string given alone as the name, as in call_deferred("my_method"), of a call of NAME_ARGUMENTS at the
# given token, or -1
func _find_written_name(tokens : Array[_Token], i : int) -> int:
	var at : int = _find_name_argument(tokens, i)
	if at < 0:
		return -1
	# A StringName or a NodePath
	if tokens[at].get_value() in ["&", "^"] and !tokens[at].is_string_literal():
		at += 1
	if at + 1 >= tokens.size() or !tokens[at].is_string_literal() or !(tokens[at + 1].is_punctuator(",") or tokens[at + 1].is_punctuator(")")):
		return -1
	return at


func _get_code_tokens() -> Array[_Token]:
	var tokens : Array[_Token] = []
	for line in tokenizer.get_output_lines():
		for token in line.tokens:
			if !token.is_of_type(_Token._Type.INDENTATION | _Token._Type.WHITESPACE | _Token._Type.COMMENT | _Token._Type.LINE_BREAK | _Token._Type.STATEMENT_BREAK):
				tokens.append(token)
	return tokens


func _func_feature_filter(token : _Token, line : _Tokenizer._Line, feature : String, features : PackedStringArray) -> void:
	if !token.is_keyword("func") or features.has(feature):
		return

	var indentation : int = line.get_indentation()
	var func_path : String = path.get_basename() + "." + tokenizer.get_next().get_value()#tokenizer.get_next().symbol.get_source_name()
	var func_body : String = 'printerr("ERROR: illegal call to ' + "'" + func_path + "'!" + '");'

	# The parameters
	var pth : int = 0
	while !tokenizer.is_eof():
		token = tokenizer.get_next()
		if token.is_punctuator("("):
			pth += 1
		elif token.is_punctuator(")"):
			pth -= 1
			if pth <= 0:
				break

	# The return type, up to the colon that begins the body
	var return_type : Array[_Token]
	var colon : _Token = null
	while !tokenizer.is_eof():
		token = tokenizer.get_next()
		if token.is_punctuator(":"):
			colon = token
			break
		elif !token.is_line_break() and !token.is_indentation():
			return_type.append(token)
	if !colon:
		return

	if return_type.size() >= 2 and return_type[0].is_operator("->") and !return_type[1].has_value("void"):
		# Something of the type has to be returned still
		var type_name : String = return_type[1].get_value()
		var value : String = "null"
		if return_type.size() == 2 or return_type[2].is_punctuator("["):
			var default : String = _get_default_value(type_name)
			if !default.is_empty():
				value = default
			elif type_name != "Variant" and type_name != "Object" and !ClassDB.class_exists(type_name) and !(return_type[1].symbol and _symbol_table.is_class_name(return_type[1].symbol.get_source_name())):
				value = ""
		else:
			value = ""
		if value.is_empty():
			# Neither a built-in type nor a class, for which null would do. The type is
			# dropped, as there is no telling what to return for it.
			value = "null"
			for type_token in return_type:
				tokenizer.get_output_line(type_token.line).erase_token(type_token)
		func_body += "return " + value

	# The body takes the place of whatever follows the colon
	var colon_line : _Tokenizer._Line = tokenizer.get_output_line(colon.line)
	for i in range(colon_line.tokens.size() - 1, colon_line.tokens.find(colon), -1):
		if !colon_line.tokens[i].is_line_break():
			colon_line.remove_token(i)
	colon_line.insert_token(colon_line.tokens.find(colon) + 1, _Token.new(_Token._Type.KEYWORD, func_body, 0, colon.line))

	var line_idx : int = colon.line + 1
	while line_idx < tokenizer.get_output_line_count():
		var tline : _Tokenizer._Line = tokenizer.get_output_line(line_idx)
		if tline.has_statement() and tline.get_indentation() <= indentation:
			break
		if tline.tokens:
			tokenizer.seek_token(tline.tokens[0])
		tline.clear_tokens()
		line_idx += 1


func _shuffle_toplevel() -> void:
	var lines : Array[_Tokenizer._Line] = tokenizer.get_output_lines()
	var top_block : Array
	var on_ready : Array[Array] = []
	var blocks : Array[Array] = []
	var current_block : Array
	var current_is_onready : bool
	
	var add_block = func(block : Array, is_onready : bool):
		if block.is_empty(): return
		if is_onready:
			on_ready.append(block)
		else:
			blocks.append(block)
	
	for i in lines.size():
		var line : _Tokenizer._Line = lines[i]
		var prev_line : _Tokenizer._Line = lines[i - 1] if i >= 1 else null
		var starter_token : _Token = line.tokens[0] if line.tokens else null
		var prev_starter_token : _Token = prev_line.tokens[0] if prev_line and prev_line.tokens else null
		if starter_token and _Builtins.STARTER_TOKENS.has(starter_token.get_value()):
			var custom : bool = false
			
			if starter_token.get_value() in _Builtins.DECORATORS:
				var z : int = i
				var current_line : _Tokenizer._Line = line
				
				while true:
					var t : String = ""
					
					for x in current_line.tokens.size():
						var tkn : String = current_line.tokens[x].get_value().strip_edges()
						if !tkn.is_empty() and !_Builtins.DECORATORS.has(tkn):
							t = tkn
							break

					if t.is_empty() and lines.size() > z + 1:
						z += 1
						current_line = lines[z]	
						continue
						
					break
					
				for itoken in range(0, current_line.tokens.size(), 1):
					var value : String = current_line.tokens[itoken].get_value().strip_edges()
					if !value.is_empty():
						if _Builtins.DECORATORS.has(value):
							continue
						elif ["class", "func", "var"].has(value):
							custom = true
						break
						
			if !custom:
				top_block.append(line)
				continue
				
		if starter_token and starter_token.get_value() == "@onready":
			add_block.call(current_block, current_is_onready)
			current_block = []
			current_is_onready = true
		elif line.get_indentation() == 0 and starter_token and (starter_token.is_keyword() or starter_token.is_annotation()) and !_is_annotation_line(prev_line):
			add_block.call(current_block, current_is_onready)
			current_block = []
			current_is_onready = false
		
		current_block.append(line)
	
	add_block.call(current_block, current_is_onready)
	
	var w_blocks : Dictionary
	var random := RandomNumberGenerator.new()
	var line_seeds : Dictionary
	for block in blocks:
		var line_seed : int = 0
		if block:
			line_seed = hash(block[0].to_string())
			line_seeds[line_seed] = line_seeds.get(line_seed, -1) + 1
			line_seed += line_seeds[line_seed]
		random.seed = hash(path) + path.length() + _symbol_table._seed + line_seed
		w_blocks[block] = random.randi()
	var source_blocks : Array[Array] = blocks.duplicate()
	blocks.sort_custom((func(a, b): return w_blocks[a] > w_blocks[b]))

	# Variables are initialized in the order they are declared and may depend on
	# earlier ones, so they only take each other's places and keep their order
	var var_slots : PackedInt32Array = []
	for i in blocks.size():
		if _is_var_block(blocks[i]):
			var_slots.append(i)
	var slot : int = 0
	for block in source_blocks:
		if _is_var_block(block):
			blocks[var_slots[slot]] = block
			slot += 1

	if on_ready:
		var idx : int = 0
		# At least 1, so every @onready var lands after the previous one and they keep their order
		var max_spacing : int = maxi(1, mini(blocks.size() / on_ready.size() * 2, blocks.size() + 1))
		random.seed = hash(path) + path.length() + _symbol_table._seed
		for block in on_ready:
			idx += maxi(1, random.randi() % max_spacing)
			blocks.insert(mini(idx, blocks.size()), block)
	
	lines.clear()
	for block in [top_block] + blocks:
		lines.append_array(block)


# Whether the line holds nothing but annotations, which then apply to the line after it
func _is_annotation_line(line : _Tokenizer._Line) -> bool:
	if !line or !line.tokens or !line.tokens[0].is_annotation():
		return false
	for token in line.tokens:
		if token.is_keyword():
			return false
	return true


# Whether a top-level block declares a variable, as opposed to a function, class, signal, etc.
func _is_var_block(block : Array) -> bool:
	for line : _Tokenizer._Line in block:
		for token : _Token in line.tokens:
			if token.is_keyword() and !token.is_keyword("static"):
				return token.is_keyword("var")
	return false


func _strip_code() -> void:
	var regex := RegEx.new()
	if _Settings.current.regex_filter_enabled and _Settings.current.regex_filter:
		regex.compile(_Settings.current.regex_filter)
	
	var lines : Array[_Tokenizer._Line] = tokenizer.get_output_lines()
	for l in range(lines.size() - 1, -1, -1):
		var line : _Tokenizer._Line = lines[l]
		
		var line_removed : bool = false
		
		# Strip lines matching RegEx, which is applied to the line as it is in the source code
		if regex.is_valid() and _matches_source(line, regex):
			_strip_statement(lines, l)
			continue
		
		if _Settings.current.strip_comments or _Settings.current.strip_extraneous_spacing or _Settings.current.strip_editor_annotations:
			for i in range(line.tokens.size() - 1, -1, -1):
				var token : _Token = line.tokens[i]
				
				# Strip comments
				if _Settings.current.strip_comments and token.type == _Token._Type.COMMENT:
					line.remove_token(i)
					continue
				
				# Strip extraneous spacing
				if _Settings.current.strip_extraneous_spacing:
					if token.type == _Token._Type.INDENTATION and (i == line.tokens.size()-1 or line.tokens[i+1].type == _Token._Type.LINE_BREAK):
						line.remove_token(i)
						continue
					elif token.type == _Token._Type.WHITESPACE:
						var prev_type : int = line.tokens[i-1].type
						var next_type : int = line.tokens[i+1].type if i+1 < line.tokens.size() else _Token._Type.NONE
						if i == 0 or prev_type == _Token._Type.OPERATOR or prev_type == _Token._Type.PUNCTUATOR or (next_type == _Token._Type.OPERATOR and prev_type != _Token._Type.KEYWORD) or next_type == _Token._Type.PUNCTUATOR:
							line.remove_token(i)
							continue
				
				# Strip annotations used exclusively by the editor
				if _Settings.current.strip_editor_annotations:
					if token.is_annotation():
						# These annotations can only be on their own line
						if token.get_value() in _Builtins.ATTRIBUTES:
							tokenizer.remove_output_line(l)
							line_removed = true
							break
						elif token.get_value() in _Builtins.DECORATORS:
							continue
						# These might have parenthesis after them, with whitespace possibly after the parenthesis
						# @export on a variable stays: it is not only for the editor, but also decides
						# what duplicate(), local-to-scene and ResourceSaver copy
						elif token.get_value() in _Builtins.ANNOTATIONS and !line.has_hint(_PreprocessorHints.PRESERVE_ANNOTATION):
							line.remove_token(i)
							if line.tokens.size() > i and line.tokens[i].is_punctuator("("):
								# The arguments, which may hold brackets of their own and go on in the lines after
								var depth : int = 0
								var arg_line : int = l
								while arg_line < lines.size():
									var arg_tokens : Array[_Token] = lines[arg_line].tokens
									var at : int = i if arg_line == l else 0
									while arg_tokens.size() > at:
										var last_token : _Token = arg_tokens[at]
										arg_tokens.remove_at(at)
										if last_token.is_punctuator("("):
											depth += 1
										elif last_token.is_punctuator(")"):
											depth -= 1
											if depth == 0:
												break
									if depth == 0:
										break
									arg_line += 1
							while line.tokens.size() > i and line.tokens[i].is_whitespace(): line.remove_token(i)
							continue
		
		if line_removed:
			continue

		# Strip empty lines
		if _Settings.current.strip_empty_lines and str(line).replace(" ", "").replace("\n", "").replace("\t", "").replace(";", "").is_empty():
			tokenizer.remove_output_line(l)
			continue


# Whether the line of source code the output line begins on matches the expression
func _matches_source(line : _Tokenizer._Line, regex : RegEx) -> bool:
	for token in line.tokens:
		if token.source_line != -1:
			return regex.search(tokenizer.get_source_line(token.source_line)) != null
	return false


# Removes the statement that begins on the given output line
func _strip_statement(lines : Array[_Tokenizer._Line], l : int) -> void:
	var line : _Tokenizer._Line = lines[l]
	var indentation : int = line.get_indentation()

	# The lines the statement goes on in, as long as it has an open bracket
	var depth : int = 0
	var last : int = l
	while last < lines.size():
		for token in lines[last].tokens:
			if token.is_punctuator() and "([{".contains(token.get_value()):
				depth += 1
			elif token.is_punctuator() and ")]}".contains(token.get_value()):
				depth -= 1
		if depth <= 0:
			break
		last += 1
	last = mini(last, lines.size() - 1)

	# A block cannot be empty, so its only statement is replaced
	var before : _Tokenizer._Line = null
	for i in range(l - 1, -1, -1):
		if lines[i].has_statement():
			before = lines[i]
			break
	var after : _Tokenizer._Line = null
	for i in range(last + 1, lines.size()):
		if lines[i].has_statement():
			after = lines[i]
			break
	var is_whole_block : bool = indentation > 0 and before != null and before.get_indentation() < indentation and (after == null or after.get_indentation() < indentation)

	for i in range(last, l, -1):
		lines.remove_at(i)
	if is_whole_block:
		var kept : Array[_Token] = [line.tokens[0], _Token.new(_Token._Type.KEYWORD, "pass", -1, -1)]
		if line.tokens.back().is_line_break() or (last > l):
			kept.append(_Token.new(_Token._Type.LINE_BREAK, "\n", -1, -1))
		line.tokens = kept
	else:
		lines.remove_at(l)


# Picks the strings that get exported encoded: all but the ones GDScript wants as constants,
# which a call that decodes a string is not
func _encode_strings() -> void:
	var lines : Array[_Tokenizer._Line] = tokenizer.get_output_lines()
	var blocks : Array = [] # The statements the line is nested in: their indentation, and whether they are a match
	var statement_line : int = 0
	var depth : int = 0
	var constant : bool = false
	var after_annotation : bool = false
	for l in lines.size():
		var tokens : Array[_Token] = lines[l].tokens
		var first : int = _find_statement(tokens, 0)
		if first == -1:
			continue

		if depth == 0:
			# A statement begins on this line
			statement_line = l
			var indentation : int = lines[l].get_indentation()
			while blocks and blocks.back()[0] >= indentation:
				blocks.pop_back()
			var pattern : bool = !blocks.is_empty() and blocks.back()[1]
			blocks.append([indentation, tokens[first].is_keyword("match")])
			constant = pattern or after_annotation or _takes_constants(tokens, first)
			# Annotations on a line of their own are for the statement after them
			after_annotation = tokens[first].is_annotation()
			for token in tokens:
				if token.is_keyword():
					after_annotation = false
					break

		# A line inside the brackets of a statement may be one of a lambda, with statements of its own
		var line_constant : bool = constant
		if depth > 0 and !constant:
			line_constant = _takes_constants(tokens, first) or _is_nested_pattern(lines, statement_line, l)

		for i in range(first, tokens.size()):
			var token : _Token = tokens[i]
			if token.is_punctuator():
				if "([{".contains(token.get_value()):
					depth += 1
				elif ")]}".contains(token.get_value()):
					depth = maxi(depth - 1, 0)
				elif token.is_punctuator(";") and depth == 0:
					# Another statement on the same line
					var next : int = _find_statement(tokens, i + 1)
					constant = next != -1 and _takes_constants(tokens, next)
					line_constant = constant
			elif token.type == _Token._Type.STRING_LITERAL and !line_constant and !_plain_lines.has(token.source_line) and _can_encode_string(tokens, i):
				_encoded_strings[token] = tokens[i - 1].is_of_type(_Token._Type.KEYWORD | _Token._Type.SYMBOL | _Token._Type.LITERAL | _Token._Type.NUMBER_LITERAL) if i > 0 else false


# The first token from the given one on which is part of a statement, -1 if there is none
func _find_statement(tokens : Array[_Token], from : int) -> int:
	for i in range(from, tokens.size()):
		if !tokens[i].is_of_type(_Token._Type.INDENTATION | _Token._Type.WHITESPACE | _Token._Type.COMMENT | _Token._Type.LINE_BREAK):
			return i
	return -1


# Whether the statement which begins with the given token is one whose strings have to be constants,
# or one where it is not worth finding out which of them have to be
func _takes_constants(tokens : Array[_Token], first : int) -> bool:
	if tokens[first].is_annotation():
		return true
	var i : int = first
	while i < tokens.size() and (tokens[i].is_keyword("static") or tokens[i].is_whitespace()):
		i += 1
	return i < tokens.size() and tokens[i].is_keyword() and tokens[i].get_value() in ["const", "extends", "class_name", "class", "enum", "signal", "func", "assert"]


# Whether a line inside the brackets of a statement is a pattern of a match:
# the line it is nested in is the one before it that is indented less
func _is_nested_pattern(lines : Array[_Tokenizer._Line], statement_line : int, l : int) -> bool:
	var indentation : int = lines[l].get_indentation()
	for i in range(l - 1, statement_line, -1):
		var first : int = _find_statement(lines[i].tokens, 0)
		if first != -1 and lines[i].get_indentation() < indentation:
			return lines[i].tokens[first].is_keyword("match")
	return false


# Whether the string is one that can be put together when the game runs
func _can_encode_string(tokens : Array[_Token], i : int) -> bool:
	var token : _Token = tokens[i]
	if !(token.decorator in ["\"", "'"]) or token.get_value(false).contains("\n"):
		return false
	if i == 0:
		return true

	# &"StringName", ^"NodePath" and r"raw string"
	if tokens[i - 1].is_operator("&") or tokens[i - 1].is_operator("^") or tokens[i - 1].is_symbol("r"):
		return false

	# preload("path")
	var before : int = i - 1
	while before > 0 and tokens[before].is_whitespace():
		before -= 1
	if tokens[before].is_punctuator("("):
		before -= 1
		while before > 0 and tokens[before].is_whitespace():
			before -= 1
		if before >= 0 and tokens[before].is_keyword("preload"):
			return false

	return true


# The code that takes the place of a string which gets exported encoded
func _get_encoded_string(token : _Token) -> String:
	var text = _get_string_text(token.get_value(false))
	if text == null or text.is_empty():
		return token.get_value()
	var encoded : String = Marshalls.utf8_to_base64(text)
	if Marshalls.base64_to_utf8(encoded) != text:
		return token.get_value()
	return (" " if _encoded_strings[token] else "") + "Marshalls.base64_to_utf8(\"" + encoded + "\")"


# The text a string stands for as it is written in a script, or null if it has
# something in it this does not know how to read
func _get_string_text(written : String):
	const ESCAPES : Dictionary = { "\\": 92, "\"": 34, "'": 39, "n": 10, "t": 9, "r": 13, "a": 7, "b": 8, "f": 12, "v": 11 }
	var text : PackedStringArray = []
	var i : int = 0
	while i < written.length():
		var from : int = i
		while i < written.length() and written[i] != "\\":
			i += 1
		text.append(written.substr(from, i - from))
		if i == written.length():
			break

		# An escape sequence
		var escape : String = written.substr(i + 1, 1)
		i += 2
		if ESCAPES.has(escape):
			text.append(char(ESCAPES[escape]))
		elif escape == "u" or escape == "U":
			var digits : int = 4 if escape == "u" else 6
			var hex : String = written.substr(i, digits)
			var code : int = hex.hex_to_int() if hex.length() == digits and hex.is_valid_hex_number() else 0
			if code <= 0 or code > 0x10ffff or (code >= 0xd800 and code <= 0xdfff):
				return null
			text.append(char(code))
			i += digits
		else:
			return null
	return "".join(text)


func _is_exclude_required(src : String) -> bool:
	var _str : String = "{0}{1}".format([_Settings.current.preprocessor_prefix, _PreprocessorHints.EXCLUDE_HINT])
	var x : int = src.find(_str)
	
	if x < 0:
		return false
	
	x += _str.length()
	
	if src.length() < x:
		return false
		
	return src.length() == x or src[x] in ["\n","\t"," "]

func _is_exclude_path(path : String) -> bool:
	for value : String in _Settings.current.exclude_files:
		# A file, with or without its extension, or a folder and all that is in it
		value = value.trim_suffix("/")
		if path == value or path.get_basename() == value or path.begins_with(value + "/"):
			return true
	return false

func check_exclusion_source(path : String, source_code : String) -> void:
	if !_is_exclude_path(path) and !_is_exclude_required(source_code):
		return
	tokenizer.reset()
	var token : _Token = tokenizer.get_next()
	while token:
		if token.symbol and token.is_symbol():
			_symbol_table.lock_symbol(token.symbol)
		token = tokenizer.get_next()
	tokenizer.reset()
