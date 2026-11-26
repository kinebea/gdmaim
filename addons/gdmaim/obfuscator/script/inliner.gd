extends RefCounted

## Puts the value of a constant, or of a key of an enum, where its name is used, in every script
## of an export.
##
## Members of classes are told apart by their name alone, across the whole project. The name
## of a constant of a class is therefore only replaced if no class has another member of that
## name, and only where it stands by itself, or after `self` or the name of its own class.
## A constant of a function is found by where it is declared, and replaced wherever it is used.
## A key of an enum is replaced where it follows the name of its enum, which has to be the only
## member of its name as well. The keys of an enum without a name are like constants.
##
## Constants and enums stay declared, for anything that is not replaced: a use this cannot be
## sure of, a string that names one, a scene, a script in another language, an enum used as a type.

const SymbolTable := preload("../symbol_table.gd")
const Token := preload("tokenizer/token.gd")
const Tokenizer := preload("tokenizer/tokenizer.gd")
const AST := preload("parser/ast.gd")
const PreprocessorHints := preload("preprocessor_hints.gd")
const _Settings := preload("../../settings.gd")

# The types a value is written with, as with Vector2(1, 2)
const CONSTRUCTED : PackedStringArray = ["Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i", "Color"]
const NO_CODE : int = Token.Type.INDENTATION | Token.Type.WHITESPACE | Token.Type.COMMENT | Token.Type.LINE_BREAK

var _symbols : SymbolTable
var _unlocked_locals : Dictionary
var _declarations : Dictionary # How many members of classes there are of a name, by the symbol they share
var _values : Dictionary # What takes the place of a name, by its symbol: a Value
var _enums : Dictionary # What takes the place of the keys of an enum with a name, by the symbol of the enum and the name of the key
var _declared_at : Dictionary # The tokens which name something where it is declared


## A list of ScriptObfuscators, whose symbols have been resolved. Without named_enums, only the keys
## of enums without a name are replaced, which are whole numbers and no enum
func run(obfuscators : Array, symbols : SymbolTable, constants : bool, enums : bool, named_enums : bool = true) -> void:
	_symbols = symbols
	for symbol in symbols._local_symbols:
		_unlocked_locals[symbol] = true

	for obfuscator in obfuscators:
		_count_declarations(obfuscator._ast)
	for obfuscator in obfuscators:
		var class_symbol : SymbolTable.Symbol = obfuscator.get_class_symbol()
		var class_root : SymbolTable.Symbol = class_symbol.get_root() if class_symbol else null
		var lines : Array[Tokenizer.Line] = obfuscator.tokenizer.get_output_lines()
		var obfuscates_strings : bool = false
		for l in lines.size():
			for token in lines[l].tokens:
				if token.is_comment():
					match token.get_value().strip_edges().trim_prefix(_Settings.current.preprocessor_prefix).get_slice(" ", 0):
						PreprocessorHints.START_OBFUSCATE_STRINGS:
							obfuscates_strings = true
						PreprocessorHints.END_OBFUSCATE_STRINGS:
							obfuscates_strings = false
			var first : int = _next(lines[l].tokens, -1)
			if first == -1:
				continue
			if constants and lines[l].tokens[first].is_keyword("const"):
				# A string that gets obfuscated here is not what the constant will stand for
				var keeps_string : bool = !obfuscates_strings and !obfuscator.tokenizer.has_source_hint(lines[l].tokens[first].source_line, PreprocessorHints.OBFUSCATE_STRINGS)
				_read_constant(lines[l].tokens, first, class_root, keeps_string)
			elif enums and lines[l].tokens[first].is_keyword("enum"):
				_read_enum(lines, l, class_root, named_enums)
	if _values.is_empty() and _enums.is_empty():
		return
	for obfuscator in obfuscators:
		for line in obfuscator.tokenizer.get_output_lines():
			_replace_names(line.tokens)


func _count_declarations(node : AST.ASTNode) -> void:
	if node is AST.SymbolDeclaration and node.symbol and node.symbol.parent:
		var root : SymbolTable.Symbol = node.symbol.get_root()
		_declarations[root] = _declarations.get(root, 0) + 1
	for child in node.get_children():
		if child:
			_count_declarations(child)


# Whether the symbol is the one of a member of a class which is the only member of its name,
# and which nothing but the scripts of the project know by that name
func _is_only_member(symbol : SymbolTable.Symbol) -> bool:
	if !symbol or !symbol.parent:
		return false
	var name : String = symbol.get_source_name()
	return _declarations.get(symbol.get_root(), 0) == 1 and !_symbols._locked_symbols.has(name) and !_symbols.is_class_name(name)


# Takes down the constant a line declares, if it is one with a value that can be written anywhere
func _read_constant(tokens : Array[Token], at : int, class_root : SymbolTable.Symbol, keeps_string : bool) -> void:
	var name_at : int = _next(tokens, at)
	if name_at == -1 or !tokens[name_at].is_symbol() or !tokens[name_at].symbol:
		return

	# const NAME = value, const NAME := value, const NAME : Type = value
	at = _next(tokens, name_at)
	var type : String = ""
	if at != -1 and tokens[at].is_punctuator(":"):
		at = _next(tokens, at)
		if at != -1 and tokens[at].is_symbol():
			type = tokens[at].get_value()
			at = _next(tokens, at)
	if at == -1 or !tokens[at].is_operator("="):
		return
	var value : Value = _read_value(tokens, _next(tokens, at), type)
	if !value or (value.string and !keeps_string):
		return

	var symbol : SymbolTable.Symbol = tokens[name_at].symbol
	if _is_only_member(symbol):
		value.class_root = class_root
		_values[symbol.get_root()] = value
	elif !symbol.parent and _unlocked_locals.has(symbol):
		_values[symbol] = value
	else:
		return
	_declared_at[tokens[name_at]] = true


# The value that begins at the given token and goes on to the end of the line, if it is one number,
# bool or string, or a vector or a color made of numbers, and of the type the constant is declared with
func _read_value(tokens : Array[Token], from : int, type : String) -> Value:
	if from == -1:
		return null
	var parts : Array[Token] = []
	for i in range(from, tokens.size()):
		if !tokens[i].is_of_type(NO_CODE):
			parts.append(tokens[i])
	if parts.is_empty():
		return null

	var value := Value.new()
	var first : Token = parts[0]
	if parts.size() == 1 and first.is_literal() and first.get_value() in ["true", "false"]:
		value.text = first.get_value()
		return value if type in ["", "bool"] else null

	if parts.size() == 1 and first.type == Token.Type.STRING_LITERAL and first.decorator in ["\"", "'"] and !first.get_value().contains("\n"):
		# &"StringName", ^"NodePath" and r"raw string" have something ahead of the string, and are no string alone
		value.string = first
		return value if type in ["", "String"] else null

	if _is_number(parts):
		var number : String = parts.back().get_value()
		var is_float : bool = !number.begins_with("0x") and !number.begins_with("0b") and (number.contains(".") or number.containsn("e"))
		if type == "float" and !is_float:
			# The value is a float all the same, and has to stay one where it is written out
			if number.begins_with("0x") or number.begins_with("0b"):
				return null
			number += ".0"
		elif !(type in ["", "float" if is_float else "int"]):
			return null
		value.text = number if parts.size() == 1 else "(-" + number + ")"
		return value

	if parts.size() >= 4 and first.is_symbol() and first.get_value() in CONSTRUCTED and parts[1].is_punctuator("(") and parts.back().is_punctuator(")"):
		if !(type in ["", first.get_value()]):
			return null
		for i in range(2, parts.size() - 1):
			if !parts[i].is_number_literal() and !parts[i].is_operator("-") and !parts[i].is_punctuator(","):
				return null
			value.text += parts[i].get_value()
		value.text = first.get_value() + "(" + value.text + ")"
		return value

	return null


func _is_number(parts : Array[Token]) -> bool:
	if parts.size() == 1:
		return parts[0].is_number_literal()
	return parts.size() == 2 and parts[0].is_operator("-") and parts[1].is_number_literal()


# Takes down the keys of the enum that begins on the given line, with the values they stand for.
# A key whose value is worked out is left out, and so are the ones counted on from it
func _read_enum(lines : Array[Tokenizer.Line], l : int, class_root : SymbolTable.Symbol, named : bool) -> void:
	# The enum may go on over several lines
	var parts : Array[Token] = []
	var closed : bool = false
	for i in range(l, lines.size()):
		for token in lines[i].tokens:
			if token.is_of_type(NO_CODE):
				continue
			parts.append(token)
			if token.is_punctuator("}"):
				closed = true
				break
		if closed:
			break
	if !closed or parts.size() < 3:
		return

	var name : Token = parts[1] if parts[1].is_symbol() else null
	var at : int = 2 if name else 1
	if !parts[at].is_punctuator("{"):
		return
	at += 1

	var keys : Dictionary # The value of each key that is known, by its token
	var number : int = 0
	var known : bool = true
	while at < parts.size() and !parts[at].is_punctuator("}"):
		var key : Token = parts[at]
		if !key.is_symbol() or !key.symbol:
			return
		at += 1
		if parts[at].is_operator("="):
			var written : Array[Token] = []
			var depth : int = 0
			at += 1
			while at < parts.size() and (depth > 0 or (!parts[at].is_punctuator(",") and !parts[at].is_punctuator("}"))):
				if parts[at].is_punctuator() and "([{".contains(parts[at].get_value()):
					depth += 1
				elif parts[at].is_punctuator() and ")]}".contains(parts[at].get_value()):
					depth -= 1
				written.append(parts[at])
				at += 1
			known = _is_number(written)
			if known:
				var digits : String = written.back().get_value().replace("_", "")
				if digits.begins_with("0x"):
					number = digits.hex_to_int()
				elif digits.begins_with("0b"):
					number = digits.bin_to_int()
				elif digits.is_valid_int():
					number = digits.to_int()
				else:
					known = false
				if written.size() == 2:
					number = -number
		if known:
			keys[key] = number
			number += 1
		if at < parts.size() and parts[at].is_punctuator(","):
			at += 1

	if name:
		if !named or !_is_only_member(name.symbol):
			return
		var values : Dictionary
		for key in keys:
			values[key.symbol.get_source_name()] = _get_number_value(keys[key], class_root)
		_enums[name.symbol.get_root()] = values
		_declared_at[name] = true
	else:
		# The keys of an enum without a name are members of the class, like constants
		for key in keys:
			if _is_only_member(key.symbol):
				_values[key.symbol.get_root()] = _get_number_value(keys[key], class_root)
				_declared_at[key] = true


func _get_number_value(number : int, class_root : SymbolTable.Symbol) -> Value:
	var value := Value.new()
	value.text = str(number) if number >= 0 else "(" + str(number) + ")"
	value.class_root = class_root
	return value


func _replace_names(tokens : Array[Token]) -> void:
	var i : int = 0
	while i < tokens.size():
		var token : Token = tokens[i]
		i += 1
		if !token.is_symbol() or !token.symbol or _declared_at.has(token):
			continue
		var from : int = i - 1
		var to : int = i - 1
		var root : SymbolTable.Symbol = token.symbol.get_root()
		var value : Value = _values.get(root)
		if !value and _enums.has(root):
			# The key that follows the name of an enum
			var dot : int = _next(tokens, to)
			var key : int = _next(tokens, dot) if dot != -1 and tokens[dot].is_punctuator(".") else -1
			if key != -1 and tokens[key].is_symbol() and tokens[key].symbol:
				value = _enums[root].get(tokens[key].symbol.get_source_name())
				to = key
		if !value:
			continue

		# What is called or assigned to is no value
		var next : int = _next(tokens, to)
		if next != -1 and (tokens[next].is_punctuator("(") or tokens[next].is_operator("=")):
			continue

		# The name by itself, or after self or the name of its own class
		var before : int = _previous(tokens, from)
		if before != -1 and tokens[before].is_punctuator("."):
			var owner : int = _previous(tokens, before)
			if owner == -1:
				continue
			var is_owner : bool = tokens[owner].is_literal("self")
			if !is_owner and value.class_root and tokens[owner].is_symbol() and tokens[owner].symbol:
				is_owner = tokens[owner].symbol.get_root() == value.class_root
			var ahead : int = _previous(tokens, owner)
			if !is_owner or (ahead != -1 and tokens[ahead].is_punctuator(".")):
				continue
			from = owner

		var replacement : Token
		if value.string:
			replacement = Token.new(Token.Type.STRING_LITERAL, value.string.get_value(false), token.idx, token.line, value.string.decorator)
		else:
			replacement = Token.new(Token.Type.LITERAL, value.text, token.idx, token.line)
		replacement.source_line = token.source_line
		for j in to - from:
			tokens.remove_at(from)
		tokens[from] = replacement
		i = from + 1


# The token after the given one that is neither whitespace nor a comment, -1 if the line ends first
func _next(tokens : Array[Token], i : int) -> int:
	for j in range(i + 1, tokens.size()):
		if tokens[j].is_line_break():
			return -1
		if !tokens[j].is_of_type(NO_CODE):
			return j
	return -1


func _previous(tokens : Array[Token], i : int) -> int:
	for j in range(i - 1, -1, -1):
		if !tokens[j].is_of_type(NO_CODE):
			return j
	return -1


class Value:
	var text : String # As it is written, for anything but a string
	var string : Token # The string, as the constant has it
	var class_root : SymbolTable.Symbol # The class a member of a class is declared in, if that class has a name
