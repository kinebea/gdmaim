extends RefCounted


const _Logger := preload("../../logger.gd")
const _Settings := preload("../../settings.gd")
const PreprocessorHints := preload("preprocessor_hints.gd")
const SymbolTable := preload("../symbol_table.gd")
const Parser := preload("parser/parser.gd")
const Token := preload("tokenizer/token.gd")
const Tokenizer := preload("tokenizer/tokenizer.gd")
const AST := preload("parser/ast.gd")
const Builtins = preload("../../builtins.gd")

var path : String
var source_code : String
var generated_code : String
var parser : Parser
var tokenizer : Tokenizer

var _symbol_table : SymbolTable
var _ast : AST.ASTNode

func _init(path : String) -> void:
	self.path = path

func parse(source_code : String, symbol_table : SymbolTable, autoload_symbol : SymbolTable.Symbol = null) -> void:
	# Carriage returns would otherwise end up in comments and their preprocessor hints
	source_code = source_code.replace("\r\n", "\n")
	self.source_code = source_code
	_symbol_table = symbol_table
	tokenizer = Tokenizer.new()
	tokenizer.read(source_code)
	parser = Parser.new()
	_ast = parser.read(tokenizer, symbol_table, autoload_symbol)

func run(features : PackedStringArray) -> bool:
	if !parser:
		_Logger.write("ERROR: ScriptObfuscator.run() - No parsed data!")
		return false
	
	if tokenizer.is_static_typing_stripped():
		_strip_static_typing()
	
	tokenizer.reset()
	
	var _str_processing : bool = false
	while !tokenizer.is_eof():
		var token : Token = tokenizer.get_next()
		var next_token : Token = tokenizer.peek()
		var line : Tokenizer.Line = tokenizer.get_output_line(token.line)
		var prev_line : Tokenizer.Line = tokenizer.get_output_line(token.line-1)
		
		if token.type == Token.Type.COMMENT:
			var value : String = token.get_value().strip_edges().trim_prefix(_Settings.current.preprocessor_prefix).get_slice(" ", 0)
			match value:
				PreprocessorHints.START_OBFUSCATE_STRINGS:
					_str_processing = true
				PreprocessorHints.END_OBFUSCATE_STRINGS:
					_str_processing = false		
		
		# Hints for strings go by the line of source code, as several of those may have been merged into one
		if tokenizer.has_source_hint(token.source_line, PreprocessorHints.OBFUSCATE_STRINGS_SEED):
			_symbol_table.set_custom_seed(tokenizer.get_source_hint_args(token.source_line, PreprocessorHints.OBFUSCATE_STRINGS_SEED).to_int())
		else:
			_symbol_table.set_custom_seed(0)
	
		if _str_processing or tokenizer.has_source_hint(token.source_line, PreprocessorHints.OBFUSCATE_STRINGS):
			_string_obfuscation(token)
			
		else:
			_string_param_obfuscation(token, next_token)
		
		if !_Settings.current.feature_filters:
			continue
		
		if prev_line and prev_line.has_hint(PreprocessorHints.FEATURE_FUNC):
			_func_feature_filter(token, line, prev_line.get_hint_args(PreprocessorHints.FEATURE_FUNC), features)
	
	if _Settings.current.obfuscation_enabled and _Settings.current.shuffle_top_level:
		_shuffle_toplevel()
	
	_strip_code()
	
	return true


func generate_source_code() -> String:
	generated_code = tokenizer.generate_source_code()
	return generated_code


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


func get_class_symbol() -> SymbolTable.Symbol:
	return parser.get_class_symbol() if parser else null


# Removes type hints. This is done to the parsed script, so that
# the types are still there to tell what a symbol belongs to.
func _strip_static_typing() -> void:
	const TRIVIA : int = Token.Type.WHITESPACE | Token.Type.COMMENT | Token.Type.INDENTATION | Token.Type.STATEMENT_BREAK

	var tokens : Array[Token]
	for token in tokenizer.get_tokens():
		if !(token.type & TRIVIA):
			tokens.append(token)

	var removed : Dictionary # Tokens to take out
	var defaults : Dictionary # Value to give a variable, by the token of its name
	var exported : bool = false
	var i : int = 0
	while i < tokens.size():
		var token : Token = tokens[i]
		if token.is_annotation():
			if token.get_value().begins_with("@export") and !Builtins.ATTRIBUTES.has(token.get_value()):
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
		var kept : Array[Token]
		for token in line.tokens:
			if removed.has(token):
				# Along with the spacing in front of it
				if kept and kept.back().is_whitespace():
					kept.pop_back()
				continue
			kept.append(token)
			if defaults.has(token):
				for added : Token in [Token.new(Token.Type.OPERATOR, "=", -1, token.line), Token.new(Token.Type.LITERAL, defaults[token], -1, token.line)]:
					added.source_line = token.source_line
					kept.append(added)
		line.tokens = kept


# Strips the type of the variable or constant whose name is at the given index
func _strip_variable_type(tokens : Array[Token], name_idx : int, is_var : bool, removed : Dictionary, defaults : Dictionary) -> void:
	var colon : int = name_idx + 1
	if colon + 1 >= tokens.size() or !tokens[name_idx].is_symbol() or !tokens[colon].is_punctuator(":"):
		return

	if tokens[colon + 1].is_operator("="):
		removed[tokens[colon]] = true # An inferred type, as in "var x := 1"
		return

	var end : int = _find_type_end(tokens, colon + 1)
	if end == -1:
		return # The colon begins the accessors of a property

	var next : Token = tokens[end] if end < tokens.size() else null
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

	for i in range(colon, end):
		removed[tokens[i]] = true


# Strips the types of the parameters and the return type of a function or signal.
# The index is that of the token after the keyword. Returns the index to go on from.
func _strip_signature_types(tokens : Array[Token], i : int, removed : Dictionary) -> int:
	if i < tokens.size() and tokens[i].is_symbol():
		i += 1 # The name, which a lambda does not have
	if i >= tokens.size() or !tokens[i].is_punctuator("("):
		return i

	var depth : int = 0
	var at_parameter : bool = false
	while i < tokens.size():
		var token : Token = tokens[i]
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


# Returns the index after the type that begins at the given index, like Array[int] or Tween.EaseType.
# Returns -1 if there is no type.
func _find_type_end(tokens : Array[Token], i : int) -> int:
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
			return Tokenizer.get_default_value(type)
	return ""


func _string_obfuscation(token : Token) -> void:
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


func _string_param_obfuscation(token : Token, next_token : Token) -> void:
	if !token.symbol or !next_token or !next_token.is_punctuator("("):
		return
	
	var symbol : SymbolTable.Symbol = token.symbol
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


func _func_feature_filter(token : Token, line : Tokenizer.Line, feature : String, features : PackedStringArray) -> void:
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
	var return_type : Array[Token]
	var colon : Token = null
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
	var colon_line : Tokenizer.Line = tokenizer.get_output_line(colon.line)
	for i in range(colon_line.tokens.size() - 1, colon_line.tokens.find(colon), -1):
		if !colon_line.tokens[i].is_line_break():
			colon_line.remove_token(i)
	colon_line.insert_token(colon_line.tokens.find(colon) + 1, Token.new(Token.Type.KEYWORD, func_body, 0, colon.line))

	var line_idx : int = colon.line + 1
	while line_idx < tokenizer.get_output_line_count():
		var tline : Tokenizer.Line = tokenizer.get_output_line(line_idx)
		if tline.has_statement() and tline.get_indentation() <= indentation:
			break
		if tline.tokens:
			tokenizer.seek_token(tline.tokens[0])
		tline.clear_tokens()
		line_idx += 1


func _shuffle_toplevel() -> void:
	var lines : Array[Tokenizer.Line] = tokenizer.get_output_lines()
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
		var line : Tokenizer.Line = lines[i]
		var prev_line : Tokenizer.Line = lines[i - 1] if i >= 1 else null
		var starter_token : Token = line.tokens[0] if line.tokens else null
		var prev_starter_token : Token = prev_line.tokens[0] if prev_line and prev_line.tokens else null
		if starter_token and Builtins.STARTER_TOKENS.has(starter_token.get_value()):
			var custom : bool = false
			
			if starter_token.get_value() in Builtins.DECORATORS:
				var z : int = i
				var current_line : Tokenizer.Line = line
				
				while true:
					var t : String = ""
					
					for x in current_line.tokens.size():
						var tkn : String = current_line.tokens[x].get_value().strip_edges()
						if !tkn.is_empty() and !Builtins.DECORATORS.has(tkn):
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
						if Builtins.DECORATORS.has(value):
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
func _is_annotation_line(line : Tokenizer.Line) -> bool:
	if !line or !line.tokens or !line.tokens[0].is_annotation():
		return false
	for token in line.tokens:
		if token.is_keyword():
			return false
	return true


# Whether a top-level block declares a variable, as opposed to a function, class, signal, etc.
func _is_var_block(block : Array) -> bool:
	for line : Tokenizer.Line in block:
		for token : Token in line.tokens:
			if token.is_keyword() and !token.is_keyword("static"):
				return token.is_keyword("var")
	return false


func _strip_code() -> void:
	var regex := RegEx.new()
	if _Settings.current.regex_filter_enabled and _Settings.current.regex_filter:
		regex.compile(_Settings.current.regex_filter)
	
	var lines : Array[Tokenizer.Line] = tokenizer.get_output_lines()
	for l in range(lines.size() - 1, -1, -1):
		var line : Tokenizer.Line = lines[l]
		
		if _Settings.current.strip_comments or _Settings.current.strip_extraneous_spacing or _Settings.current.strip_editor_annotations:
			for i in range(line.tokens.size() - 1, -1, -1):
				var token : Token = line.tokens[i]
				
				# Strip comments
				if _Settings.current.strip_comments and token.type == Token.Type.COMMENT:
					line.remove_token(i)
					continue
				
				# Strip extraneous spacing
				if _Settings.current.strip_extraneous_spacing:
					if token.type == Token.Type.INDENTATION and (i == line.tokens.size()-1 or line.tokens[i+1].type == Token.Type.LINE_BREAK):
						line.remove_token(i)
						continue
					elif token.type == Token.Type.WHITESPACE:
						var prev_type : int = line.tokens[i-1].type
						var next_type : int = line.tokens[i+1].type if i+1 < line.tokens.size() else Token.Type.NONE
						if i == 0 or prev_type == Token.Type.OPERATOR or prev_type == Token.Type.PUNCTUATOR or (next_type == Token.Type.OPERATOR and prev_type != Token.Type.KEYWORD) or next_type == Token.Type.PUNCTUATOR:
							line.remove_token(i)
							continue
				
				# Strip annotations used exclusively by the editor
				if _Settings.current.strip_editor_annotations:
					if token.is_annotation():
						# These annotations can only be on their own line
						if token.get_value() in Builtins.ATTRIBUTES:
							tokenizer.remove_output_line(l)
							continue
						elif token.get_value() in Builtins.DECORATORS:
							continue
						# Other @export's and a few others might have parenthesis after them, with whitespace possibly after the parenthesis
						elif (token.get_value().contains("@export") or token.get_value() in Builtins.ANNOTATIONS) and !line.has_hint(PreprocessorHints.PRESERVE_ANNOTATION):
							line.remove_token(i)
							if line.tokens.size() > i and line.tokens[i].is_punctuator("("):
								var last_token: Token
								while line.tokens.size() > i:
									last_token = line.tokens[i]
									line.remove_token(i)
									if last_token.is_punctuator(")"): break
							while line.tokens.size() > i and line.tokens[i].is_whitespace(): line.remove_token(i)
							continue
		
		# Strip empty lines
		if _Settings.current.strip_empty_lines and str(line).replace(" ", "").replace("\n", "").replace("\t", "").replace(";", "").is_empty():
			tokenizer.remove_output_line(l)
			continue
		
		# Strip lines matching RegEx
		if regex.is_valid() and regex.search(str(line)):
			tokenizer.remove_output_line(l)
			continue
			
func _is_exclude_required(src : String) -> bool:
	var _str : String = "{0}{1}".format([_Settings.current.preprocessor_prefix, PreprocessorHints.EXCLUDE_HINT])
	var x : int = src.find(_str)
	
	if x < 0:
		return false
	
	x += _str.length()
	
	if src.length() < x:
		return false
		
	return src.length() == x or src[x] in ["\n","\t"," "]

func _is_exclude_path(path : String) -> bool:
	for value : String in _Settings.current.exclude_files:
		if path.begins_with(value):
			return true
	return false

func check_exclusion_source(path : String, source_code : String) -> void:
	if !_is_exclude_path(path) and !_is_exclude_required(source_code):
		return
	tokenizer.reset()
	var token : Token = tokenizer.get_next()
	while token:
		if token.symbol and token.is_symbol():
			_symbol_table.lock_symbol(token.symbol)
		token = tokenizer.get_next()
	tokenizer.reset()
