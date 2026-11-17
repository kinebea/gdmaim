extends RefCounted


const _Logger := preload("../../../logger.gd")
const _Settings := preload("../../../settings.gd")
const Token := preload("token.gd")
const Stream := preload("stream.gd")
const PreprocessorHints = preload("../preprocessor_hints.gd")

const KEYWORDS : Array[String] = ["extends", "class_name", "setget", "const", "signal", "enum", "static", "var", "func", "class", "pass", "if", "else", "elif", "while", "for", "in", "match", "continue", "break", "return", "assert", "yield", "await", "preload", "load", "as", "and", "or", "not", "when"]
const LITERALS : Array[String] = ["true", "false", "null", "self", "PI", "TAU", "NAN", "INF"]
const OPERATORS : String = "+-*^/%=<>!&|~"
# Operators of more than one character, longest first
const LONG_OPERATORS : PackedStringArray = ["**=", "<<=", ">>=", "**", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "<<", ">>", "&&", "||", "->"]
const PUNCTUATORS : String = "()[]{},;:."
const IDENTIFIER_CHARACTERS : String = "1234567890_"

static var _pregex : RegEx = null

var line_count : int

var _stream : Stream
var _tokens : Array[Token]
var _idx : int
var _line : int
var _output : Array[Line]
var _can_be_nodepath : bool = true
var _space_indent : int = 4
var _source_line : int # Line of the source code the token being read begins on

## PreprocessorHints
var _stream_preprocessor : Dictionary = {}
var _strip_static_typing : bool = false
var _strip_static_typing_initialized : bool = false

func read(source_code : String) -> void:
	line_count = 1
	_tokens.clear()
	_idx = -1
	_line = 0
	_output = [Line.new()]
	
	_read_preprocessor(source_code)
	_space_indent = _detect_space_indent(source_code)

	_stream = Stream.new(source_code)
	while _read_next_token(): pass

	line_count = _stream.get_line_pos()


func _read_preprocessor(src : String) -> void:
	if null == _pregex:
		_pregex = RegEx.create_from_string("(?m)(?<=\\s|^)##STRIP_([^\\s\\n]+)((?:(?!\\n|##).)*)")
	
	for mtch : RegExMatch in _pregex.search_all(src):
		_stream_preprocessor[mtch.get_string(0).trim_prefix(_Settings.current.preprocessor_prefix)] = mtch.get_string(1).strip_edges()

	if !has_preprocessor(PreprocessorHints.STRIP_IGNORE_STATIC_TYPED_HINT):
		_strip_static_typing = has_preprocessor(PreprocessorHints.STRIP_STATIC_TYPED_HINT) or has_preprocessor(PreprocessorHints.STRIP_STATIC_TYPED_INITIALIZED_HINT) or _Settings.current.strip_static_typing
		_strip_static_typing_initialized = has_preprocessor(PreprocessorHints.STRIP_STATIC_TYPED_INITIALIZED_HINT) or _strip_static_typing_initialized or _Settings.current.striped_static_typing_be_initialized

func has_preprocessor(preprocessor : String) -> bool:
	return _stream_preprocessor.has(preprocessor)

func reset() -> void:
	_idx = -1


func is_eof(offset : int = 0) -> bool:
	return _idx + offset >= _tokens.size() - 1


func get_next() -> Token:
	_idx += 1
	return _tokens[_idx] if _idx < _tokens.size() else null


func get_next_filtered(type_filter : int = Token.Type.WHITESPACE | Token.Type.COMMENT | Token.Type.INDENTATION | Token.Type.LINE_BREAK) -> Token:
	var token : Token = peek_next_filtered(type_filter)
	if token:
		seek_token(token)
	else:
		_idx = _tokens.size() - 1
	
	return token


func peek_next_filtered(type_filter : int = Token.Type.WHITESPACE | Token.Type.COMMENT | Token.Type.INDENTATION | Token.Type.LINE_BREAK) -> Token:
	for i in range(_idx + 1, _tokens.size()):
		var token : Token = _tokens[i]
		if !(token.type & type_filter):
			return token
	
	return null


func peek(offset : int = 1) -> Token:
	return _tokens[_idx + offset] if _idx + offset < _tokens.size() and _idx + offset >= 0 else null


func seek_token(token : Token) -> Token:
	_idx = token.idx
	return token


func skip_to(token_str : String) -> Token:
	while !is_eof():
		var token : Token = get_next()
		if token.get_value() == token_str:
			return token
	
	return null


func get_tokens() -> Array[Token]:
	return _tokens


func insert_output_token(line_idx : int, token_idx : int, token : Token) -> void:
	_output[line_idx].insert_token(token_idx, token)


func remove_output_token(line_idx : int, token_idx : int) -> void:
	_output[line_idx].remove_token(token_idx)


func insert_output_line(line_idx : int, line : Line) -> void:
	_output.insert(line_idx, line)


func remove_output_line(line_idx : int) -> void:
	_output.remove_at(line_idx)


func get_output_line(idx : int) -> Line:
	return _output[idx] if idx >= 0 and idx < _output.size() else null


func find_output_line(line : Line) -> int:
	return _output.find(line)


func get_output_line_count() -> int:
	return _output.size()


func get_output_lines() -> Array[Line]:
	return _output


func generate_source_code() -> String:
	var code : String
	for line in _output:
		for token in line.tokens:
			code += token.get_value()
	
	return code
	
func _add_default_value(id: String) -> void:
	var type : int = TYPE_OBJECT
	
	for x in TYPE_MAX:
		if type_string(x) == id:
			type = x
			break
			
	if type == TYPE_OBJECT:
		_add_literal("null")
		return
	
	var variant : String = get_default_value(type)
	
	if variant.is_empty():
		variant = '""'
	
	for x : String in variant:
		if _is_punctuator(x):
			_add_punctuator(x)
		elif _is_whitespace(x):
			continue
		elif _is_keyword(x):
			_add_keyword(x)
		elif _is_literal(x):
			_add_literal(x)
		else:
			_add_symbol(x)
	
func _is_stripped_typed(char : String) -> bool:
	if _strip_static_typing and char == ":":
		const breakers : PackedInt64Array = [Token.Type.WHITESPACE, Token.Type.INDENTATION, Token.Type.STATEMENT_BREAK, Token.Type.LINE_BREAK]
		const snacks : PackedStringArray = ["func", "var", "const"]
		for x in range(_tokens.size() - 2, -1, -1):
			var tkn : Token = _tokens[x]
			if tkn.type in breakers:
				continue
			if tkn.type == Token.Type.KEYWORD and tkn.get_value() in snacks:
				break
			elif tkn.type == Token.Type.PUNCTUATOR:
				if tkn.get_value() == ",":
					continue
				elif "([".contains(tkn.get_value()):
					break
				elif "{".contains(tkn.get_value()):
					return false
			elif tkn.type == Token.Type.OPERATOR and tkn.get_value() == "=":
				break
			elif tkn.type == Token.Type.NUMBER_LITERAL:
				continue
			elif tkn.type == Token.Type.LITERAL or tkn.type == Token.Type.SYMBOL:
				continue
			return false
			
		var candy : Stream = _stream.snapshot()
		
		char = _stream.peek(2)
		
		while _is_whitespace(char):
			_stream.get_next()
			char = _stream.peek()
		
		if char == "=":
			_stream.get_next()
			return true
		else:
			while _is_whitespace(char) or char == "\\":
				_stream.get_next()
				char = _stream.peek()
				
			if !char.is_empty() and !(char in ["\n\"`"]):
				var id : String = _read_while(_is_valid_identifier)
				if !id.is_empty():
					char = _stream.peek()
					while _is_whitespace(char) or char == "\\":
						_stream.get_next()
						char = _stream.peek()
						
					if char == "[":
						char = _stream.get_next()
						while !char.is_empty() and char != "]":
							char = _stream.get_next()
						
					char = _stream.peek()
					while char != "\n" and char != "=" and (_is_whitespace(char) or char == "\\"):
						_stream.get_next()
						char = _stream.peek()
						
					if _strip_static_typing_initialized:
						if char != "=":
							_add_operator("=")
							_add_default_value(id)
						
					return true
					
		_stream = candy
	return false

func _post_operator() -> void:
	if _strip_static_typing:
		if _tokens.size() > 0 and _tokens[_tokens.size() - 1].get_value() == "->":
			var tkn : Token = _tokens.pop_back()
			
			for x : int in range(_output.size() - 1, -1, -1):
				var l : Line = _output[x]
				var y : int = l.tokens.rfind(tkn)
				if y > -1:
					l.tokens.remove_at(y)
					break
					
			var char : String = _stream.get_next()
			
			while _is_whitespace(char) or char == "\\":
				char = _stream.get_next()
				
			if char == ":":
				return
			
			_read_while(_is_valid_identifier)

func _read_next_token() -> bool:
	if _stream.is_eof():
		return false
	
	_source_line = _stream.get_line_pos() - 1
	
	if _stream.peek() == "\n":
		if !_read_sequence_break_line():
			# Line break
			_stream.get_next()
			_add_line_break()
			line_count += 1
			_output.append(Line.new())
			_can_be_nodepath = true
		return true
	
	var char : String = _stream.peek()
	if char == '\\':
		if _is_continue_line():
			_stream.get_next()
			_read_continue_line()
			# The lines are joined, but what is on them stays apart
			_add_whitespace(" ")
		else:
			# Statement break
			_stream.get_next()
			_add_statement_break()
	elif _is_whitespace(char):
		if _stream.get_column_pos() == 0:
			# Indentation
			_read_indentation()
		else:
			# Whitespace
			_read_whitespace()
	elif char == "#":
		# Comment
		_read_comment()
	elif "\"'".contains(char):
		var multi : bool = false
		
		for x : int in range(2, 4, 1):
			if _stream.peek(x) == char:
				if x == 3 and _stream.peek(x + 1) != char:
					multi = true
				continue
			break
			
		if multi:
			_read_multi_string()
		else:		
			# String(literal)
			_read_string()
	elif char == "$" or (char == "%" and _can_be_nodepath):
		_read_node_path()
	elif char == "@":
		_read_annotation()
	elif _is_operator(char):
		# Operator
		_read_operator()
		_post_operator()
		
	elif _is_digit(char):
		# Number(literal)
		_read_number()
	elif _is_punctuator(char):
		if !_is_stripped_typed(char) and !_is_continue_sequence_line(char, ",([{", "\n"):
			# Punctuator
			_add_punctuator(_stream.get_next())
		# An operand follows an opening bracket, a comma or a colon: '%Name' there is a unique node
		_can_be_nodepath = "([{,:;".contains(char)
	elif _is_valid_identifier(char):
		_read_identifier()
	else:
		_stream.get_next()
		_Logger.write("ERROR: Tokenizer._read_next_token() - Invalid character '" + char + "' at " + _stream.get_pos_str())
	
	return true
		
func _is_continue_sequence_line(char : String, from : String, to : String) -> bool:
	if is_instance_valid(_Settings.current) and !_Settings.current.strip_sequential_newlines:
		return false
	
	if char in from:
		_add_punctuator(_stream.get_next())
		_read_while(_is_whitespace)
		if _stream.peek() == to:
			var _idx : int = 2
			var chr : String = _stream.peek(_idx)
			
			while !chr.is_empty():
				if chr == ":":
					return false
				elif chr == to:
					break
				
				_idx += 1
				chr = _stream.peek(_idx)
			
			_stream.peek(2)
			_stream.get_next()
			_read_while(_is_whitespace)
		return true
	return false
	
func _read_sequence_break_line() -> bool:
	var idx : int = 1
	var char : String = " "
	var t1 : int = 0
	
	while !char.is_empty():
		idx += 1
		char = _stream.peek(idx)
				
		if _is_space(char):
			continue
		elif _is_tab(char):
			t1 += 1
			continue
			
		if ",})]".contains(char):
			var dt : String = _stream._data 
			var t0 : int = 0
			for x : int in range(_stream._idx, -1, -1):
				var c : String = dt[x] 
				if c != "\n":
					if _is_tab(c):
						t0 += 1
				else:
					break
			
			if t0 >= t1:
				return false
				
			_stream.get_next()
			_read_while(_is_whitespace)
			return true
		
		break
	return false

# Returns how many spaces make up one indentation level in the given source code.
# A file may use another size than the editor is set to, so this is read from the
# first indented block. Falls back to the editor setting if spaces are not used.
func _detect_space_indent(src : String) -> int:
	if src.contains("\n "):
		var prev_line : String = ""
		var prev_spaces : int = 0
		for line : String in src.split("\n"):
			var code : String = line.strip_edges()
			if code.is_empty() or code.begins_with("#"):
				continue
			var spaces : int = line.length() - line.lstrip(" ").length()
			if spaces > prev_spaces and prev_line.ends_with(":"):
				return spaces - prev_spaces
			prev_line = code
			prev_spaces = spaces

	return _Settings.current.space_as_tabs


func _read_indentation() -> void:
	var x0 : int = _space_indent
	var ax : int = 0
	var zf : bool = true
	
	while zf:
		var bx : int = _read_while(_is_space).length() / x0 + _read_while(_is_tab).length()
		ax += bx
		zf = bx > 0
		
	_add_indentation(ax)

func _read_whitespace() -> void:
	_add_whitespace(_read_while(_is_whitespace))

func _read_comment() -> void:
	var text : String = _read_until("\n")
	if text.begins_with(_Settings.current.preprocessor_prefix):
		var hints : PackedStringArray = text.split(_Settings.current.preprocessor_prefix)
		for hint in hints:
			var slices : PackedStringArray = hint.split(" ", false, 1)
			if slices:
				_output.back().add_hint(slices[0], slices[1] if slices.size() == 2 else "")
	_add_comment(text)

func _read_continue_line() -> void:
	var nchar : String = _stream.peek()
	
	while _is_whitespace(nchar) or nchar == "\n":
		_stream.get_next()
		nchar = _stream.peek()


func _read_string() -> void:
	var str : String
	var end : String = _stream.get_next()
	
	while !_stream.is_eof():
		var char : String = _stream.get_next()
		if char == "\\":
			char += _stream.get_next()
		if char == end:
			break
		str += char
	_add_string_literal(str, end)
	_can_be_nodepath = false

func _read_multi_string() -> void:
	var end : String = _stream.get_next()
	var t3 : String = str(end,end,end)
	var str : String = ""
	var mf : bool = false
	var comment : bool = true

	# Only a string that starts its own line can be a comment
	for tkn : Token in _output.back().tokens:
		if !tkn.is_indentation() and !tkn.is_whitespace():
			comment = false
			break

	for x : int in range(_tokens.size() - 1, -1, -1):
		var tkn : Token = _tokens[x]
		if tkn.is_indentation() or tkn.is_line_break():
			continue
		elif tkn.is_operator() or tkn.is_keyword():
			comment = false
		elif tkn.is_punctuator():
			for z : String in "([{,.:":
				if tkn.is_punctuator(z):
					comment = false
					break
		break
		
	while !_stream.is_eof():
		var char : String = _stream.get_next()
		
		if !mf:
			while char.is_empty():
				char = _stream.get_next()
				
			mf = true
			while char == end:
				char = _stream.get_next()
			
		if char == "\\":
			pass
			
		if char == end:
			if _stream.peek(1) == end and _stream.peek(2) == end and _stream.peek(3) != end:
				_stream.get_next()
				_stream.get_next()
				break
			
		str += char
		
	if comment:
		_add_comment(t3 + str + t3)
	else:
		_add_string_multi_line(str, t3)
	
	# Discard any trailing whitespace
	if _is_whitespace(_stream.peek()):
		_read_whitespace()
	
	# Determine if the str is followed by a newline or string function.
	var has_newline : bool = _stream.peek() == "\n"
	if has_newline:
		_stream.get_next()
		_add_line_break()
	
	# Capture the indentation of the line where the multistring started
	var base_indent := ""
	if _output.back().tokens and _output.back().tokens[0].type == Token.Type.INDENTATION:
		base_indent = _output.back().tokens[0].get_value()
		
	# Append padding lines to maintain 1:1 line counting & indentation depth so the AST doesn't drop scope.
	for i in str.count("\n"):
		line_count += 1
		var new_line := Line.new()
		if base_indent:
			new_line.add_token(Token.new(Token.Type.INDENTATION, base_indent, _tokens.size(), _output.size(), ""))
		_output.append(new_line)
	
	# Ensure we force a newline after a bare multiline string
	if has_newline:
		line_count += 1
		_output.append(Line.new())
	
	_can_be_nodepath = has_newline

func _read_node_path() -> void:
	var str : String = _stream.get_next() # $ or %
	var quote : String = _stream.peek()

	if quote == '"' or quote == "'":
		# A quoted path, in which anything goes up to the closing quote
		str += _stream.get_next()
		while !_stream.is_eof():
			var char : String = _stream.get_next()
			str += char
			if char == "\\":
				str += _stream.get_next()
			elif char == quote or char == "\n":
				break
	else:
		while !_stream.is_eof():
			var char : String = _stream.peek()
			if char == "\n" or char == '"' or char == "'" or _is_punctuator(char) or _is_whitespace(char):
				break
			# An operator other than the / and % of a path ends it, as in %Bar==x
			if char != "/" and char != "%" and _is_operator(char):
				break
			str += char
			_stream.get_next()

	if str == '%':
		_add_operator(str)
		return

	_add_node_path(str)
	_can_be_nodepath = false


func _read_annotation() -> void:
	_stream.get_next()  # skip @ prefix
	_add_annotation("@" + _read_while(_is_valid_identifier))
	_can_be_nodepath = false


func _read_operator() -> void:
	# One operator at a time, so that glued ones stay apart, like the = and - in x=-1
	# or the ! in !%Node, which is followed by a unique node name
	var operator : String = _stream.peek()
	for candidate : String in LONG_OPERATORS:
		var matches : bool = true
		for i in candidate.length():
			if _stream.peek(i + 1) != candidate[i]:
				matches = false
				break
		if matches:
			operator = candidate
			break
	for i in operator.length():
		_stream.get_next()
	_add_operator(operator)
	_can_be_nodepath = true


func _read_number() -> void:
	var number : String = _stream.get_next()
	var next : String = _stream.peek()

	if number == "0" and !next.is_empty() and "xXbB".contains(next):
		# Hexadecimal or binary
		number += _stream.get_next() + _read_while(_is_hex_digit)
	else:
		number += _read_while(_is_decimal_digit)
		# Fraction, unless the dot begins a member access like 1.abs()
		next = _stream.peek(2)
		if _stream.peek() == "." and (next.is_empty() or !_is_valid_identifier(next) or _is_digit(next) or _is_exponent(2)):
			number += _stream.get_next() + _read_while(_is_decimal_digit)
		if _is_exponent(1):
			number += _stream.get_next()
			if "+-".contains(_stream.peek()):
				number += _stream.get_next()
			number += _read_while(_is_decimal_digit)

	_add_number_literal(number)
	_can_be_nodepath = false


func _read_identifier() -> void:
	var id : String = _read_while(_is_valid_identifier)
	if _is_keyword(id):
		_add_keyword(id)
		_can_be_nodepath = true
	elif _is_literal(id):
		_add_literal(id)
		_can_be_nodepath = false
	else:
		_add_symbol(id)
		_can_be_nodepath = false


func _read_while(condition : Callable) -> String:
	var str : String
	
	while !_stream.is_eof():
		var char : String = _stream.peek()
		if !condition.call(char):
			return str
		str += char
		_stream.get_next()
	
	return str


func _read_until(delimeters : String) -> String:
	var str : String
	
	while !_stream.is_eof():
		var char : String = _stream.peek()
		if delimeters.contains(char):
			return str
		str += char
		_stream.get_next()
	
	return str

func _is_whitespace(char : String) -> bool:
	return _is_space(char) or _is_tab(char)

func _is_space(char : String) -> bool:
	return char == " "
	
func _is_tab(char : String) -> bool:
	return char == "\t"

func _is_operator(char : String) -> bool:
	return OPERATORS.contains(char)


func _is_punctuator(char : String) -> bool:
	return PUNCTUATORS.contains(char)

func _is_continue_line() -> bool:
	var nchar : String = _stream.peek(2)
	return _is_whitespace(nchar) or nchar == "\n"

func _is_digit(char : String) -> bool:
	return "0123456789".contains(char)
	
func _is_decimal_digit(char : String) -> bool:
	return "0123456789_".contains(char)

func _is_hex_digit(char : String) -> bool:
	return "0123456789_abcdef".containsn(char)

# Whether the character at the stream offset starts an exponent, such as e5 or e-5.
func _is_exponent(offset : int) -> bool:
	var char : String = _stream.peek(offset)
	if char.is_empty() or !"eE".contains(char):
		return false
	var next : String = _stream.peek(offset + 1)
	if !next.is_empty() and "+-".contains(next):
		next = _stream.peek(offset + 2)
	return !next.is_empty() and _is_digit(next)

func _is_valid_identifier(char : String) -> bool:
	return TextServerManager.get_primary_interface().is_valid_letter(char.unicode_at(0)) or IDENTIFIER_CHARACTERS.contains(char)
	#return char.is_valid_unicode_identifier() #TODO: Godot 4.4


func _is_keyword(token : String) -> bool:
	return KEYWORDS.has(token)


func _is_literal(token : String) -> bool:
	return LITERALS.has(token)


func _add_token(type : Token.Type, value : String, readable : bool = true, deco : String = "") -> void:
	var token : Token = null
	
	if !readable and value.begins_with(_Settings.current.preprocessor_prefix):
		readable = true
		
	token = Token.new(type, value, _tokens.size(), _output.size()-1, deco)
	token.source_line = _source_line

	_output.back().add_token(token)
	
	if readable:
		_tokens.append(token)
		
	

func _add_symbol(name : String) -> void:
	_add_token(Token.Type.SYMBOL, name)


func _add_keyword(keyword : String) -> void:
	_add_token(Token.Type.KEYWORD, keyword)


func _add_literal(literal : String) -> void:
	_add_token(Token.Type.LITERAL, literal)


func _add_number_literal(number : String) -> void:
	_add_token(Token.Type.NUMBER_LITERAL, number)


func _add_string_literal(str : String, deco : String) -> void:
	_add_token(Token.Type.STRING_LITERAL, str, true, deco)

func _add_string_multi_line(str : String, deco : String) -> void:
	_add_token(Token.Type.STRING_MULTI_LINE, str, true, deco)

func _add_node_path(str : String) -> void:
	_add_token(Token.Type.NODE_PATH, str)


func _add_annotation(str : String) -> void:
	_add_token(Token.Type.ANNOTATION, str)


func _add_punctuator(punctuator : String) -> void:
	_add_token(Token.Type.PUNCTUATOR, punctuator)


func _add_operator(operator : String) -> void:
	_add_token(Token.Type.OPERATOR, operator)


func _add_comment(text : String) -> void:
	_add_token(Token.Type.COMMENT, text, false)


func _add_whitespace(str : String) -> void:
	_add_token(Token.Type.WHITESPACE, str, false)


func _add_indentation(indentation : int) -> void:
	_add_token(Token.Type.INDENTATION, "\t".repeat(indentation))


func _add_line_break() -> void:
	_add_token(Token.Type.LINE_BREAK, "\n")


func _add_statement_break() -> void:
	_add_token(Token.Type.STATEMENT_BREAK, "\\")


class Line:
	var tokens : Array[Token]
	var hints : Dictionary
	var indentation : int
	
	func _init(tokens : Array[Token] = []) -> void:
		self.tokens = tokens
	
	func _to_string() -> String:
		var str : String
		for token in tokens:
			str += str(token)
		return str
	
	func add_token(token : Token) -> void:
		tokens.append(token)
	
	func insert_token(idx : int, token : Token) -> void:
		tokens.insert(idx, token)
	
	func remove_token(idx : int) -> void:
		tokens.remove_at(idx)
	
	func erase_token(token : Token) -> void:
		tokens.erase(token)
	
	func clear_tokens(keep_indentation : bool = true) -> void:
		for i in range(tokens.size() - 1, -1, -1):
			var token : Token = tokens[i]
			if !token.is_line_break() and (!keep_indentation or !token.is_indentation()):
				tokens.remove_at(i)
	
	func add_hint(hint : String, args : String) -> void:
		hints[hint] = args
	
	func has_hint(hint : String) -> bool:
		return hints.has(hint)
	
	func get_hint_args(hint : String) -> String:
		return hints.get(hint, "")
	
	func get_indentation() -> int:
		return 0 if !tokens or tokens[0].type != Token.Type.INDENTATION else tokens[0].get_value().length()
	
	func has_statement() -> bool:
		var t : int = 0 if get_indentation() == 0 else 1
		return tokens.size() >= t + 1 and !tokens[t].is_comment() and !tokens[t].is_line_break()
	
	func has_token_value(value : String) -> bool:
		for token in tokens:
			if token.get_value() == value:
				return true
		return false

static func get_default_value(type: int) -> Variant:
	match type:
		TYPE_NIL: return "null"
		TYPE_BOOL: return "false"
		TYPE_INT: return "0"
		TYPE_FLOAT: return "0.0"
		TYPE_STRING: return "\"\""
		TYPE_VECTOR2: return "Vector2.ZERO"
		TYPE_VECTOR2I: return "Vector2i.ZERO"
		TYPE_RECT2: return "Rect2()"
		TYPE_RECT2I: return "Rect2i()"
		TYPE_VECTOR3: return "Vector3.ZERO"
		TYPE_VECTOR3I: return "Vector3i.ZERO"
		TYPE_TRANSFORM2D: return "Transform2D()"
		TYPE_VECTOR4: return "Vector4.ZERO"
		TYPE_VECTOR4I: return "Vector4i.ZERO"
		TYPE_PLANE: return "Plane()"
		TYPE_QUATERNION: return "Quaternion()"
		TYPE_AABB: return "AABB()"
		TYPE_BASIS: return "Basis()"
		TYPE_TRANSFORM3D: return "Transform3D()"
		TYPE_PROJECTION: return "Projection()"
		TYPE_COLOR: return "Color.BLACK"
		TYPE_STRING_NAME: return "&\"\""
		TYPE_NODE_PATH: return "NodePath()"
		TYPE_RID: return "RID()"
		TYPE_OBJECT: return "null"
		TYPE_CALLABLE: return "Callable()"
		TYPE_SIGNAL: return "Signal()"
		TYPE_DICTIONARY: return "{}"
		TYPE_ARRAY: return "[]"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray()"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array()"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array()"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array()"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array()"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray()"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array()"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array()"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray()"
		TYPE_PACKED_VECTOR4_ARRAY: return "PackedVector4Array()"
		TYPE_OBJECT: return "null"
	return str(type_convert("", type))
