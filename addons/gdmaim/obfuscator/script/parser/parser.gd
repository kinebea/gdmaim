extends RefCounted


const _Logger := preload("../../../logger.gd")
const _Settings := preload("../../../settings.gd")
const PreprocessorHints := preload("../preprocessor_hints.gd")
const Stream := preload("../tokenizer/stream.gd")
const Token := preload("../tokenizer/token.gd")
const Tokenizer := preload("../tokenizer/tokenizer.gd")
const SymbolTable := preload("../../symbol_table.gd")
const AST := preload("ast.gd")
const BUILT_IN := preload("../../../builtins.gd")

var _tokenizer : Tokenizer
var _symbol_table : SymbolTable
var _class_symbol : SymbolTable.Symbol
var _is_autoload : bool
var _current_indentation : int
var _bracket_lock : int = 0
var _statement_break : bool = false
var _dictionary_keys : Dictionary
var _pattern_bindings : Dictionary

# CUSTOM INTERNALS
var _blocked : bool = false


func read(tokenizer : Tokenizer, symbol_table : SymbolTable, autoload_symbol : SymbolTable.Symbol = null) -> AST.ASTNode:
	_tokenizer = tokenizer
	_symbol_table = symbol_table
	_class_symbol = autoload_symbol
	_is_autoload = autoload_symbol != null
	_find_dictionary_keys()

	var ast := AST.Class.new(null)
	ast.body = _parse_block(ast, -1)
	
	_symbol_table = null
	
	return ast


func get_class_symbol() -> SymbolTable.Symbol:
	return _class_symbol


# Finds the keys of dictionaries written as { key = value }. Such a key is a string
# and not an identifier, so it must keep its name.
func _find_dictionary_keys() -> void:
	const SKIPPED : int = Token.Type.WHITESPACE | Token.Type.COMMENT | Token.Type.INDENTATION | Token.Type.LINE_BREAK | Token.Type.STATEMENT_BREAK

	_dictionary_keys.clear()

	var brackets : Array[bool] # For every open bracket, whether it is that of a dictionary
	var key : Token = null
	var prev : Token = null
	var prev_prev : Token = null
	for token : Token in _tokenizer.get_tokens():
		if token.type & SKIPPED:
			continue

		if key and token.is_operator("="):
			_dictionary_keys[key.idx] = true
		key = null

		if token.is_punctuator():
			match token.get_value():
				"{":
					var is_enum : bool = prev != null and (prev.is_keyword("enum") or (prev.is_symbol() and prev_prev != null and prev_prev.is_keyword("enum")))
					brackets.append(!is_enum)
				"(", "[":
					brackets.append(false)
				")", "]", "}":
					brackets.pop_back()
		elif token.is_symbol() and brackets and brackets.back() and (prev.is_punctuator("{") or prev.is_punctuator(",")):
			key = token

		prev_prev = prev
		prev = token


# Whether a declaration with this parent is a member of a class, and not local to a function
func _is_class_level(parent : AST.ASTNode) -> bool:
	return parent is AST.Sequence and parent.get_parent() is AST.Class


# Whether the token is the name of a binding in a match pattern, like the x in "var x:"
func is_pattern_binding(token : Token) -> bool:
	return token != null and _pattern_bindings.has(token.idx)


func _is_dictionary_key(token : Token) -> bool:
	return token != null and _dictionary_keys.has(token.idx)


func _parse_block_with_callback(parent : AST.ASTNode, indentation : int, token_process: Callable) -> AST.Sequence:
	var ast := AST.Sequence.new(parent)
	ast.token_from = _tokenizer.peek(1)
	
	var prev_line : Tokenizer.Line = null
	while !_tokenizer.is_eof():
		var token : Token = _tokenizer.peek(1)
		var line : Tokenizer.Line = _tokenizer.get_output_line(token.line)
		
		if _bracket_lock < 0:
			break
		
		if prev_line and prev_line != line and line.has_statement() and line.get_indentation() <= indentation and _bracket_lock == 0 and not _statement_break:
			break
		else:
			prev_line = line
		
		if !token_process.call(ast, line, token, indentation):
			break
	
	ast.token_to = _tokenizer.peek(0)
	
	return ast


func _parse_block(parent : AST.ASTNode, indentation : int) -> AST.Sequence:
	return _parse_block_with_callback(parent, indentation, func(ast : AST.Sequence, line : Tokenizer.Line, token : Token, indentation : int):
		if parent is AST.Match and token.is_punctuator(":") and line.get_indentation() == indentation + 1:
			ast.statements.append(_parse_block(ast, indentation + 1))
		else:
			var statement : AST.ASTNode = _parse_statement(ast)
			if statement:
				ast.statements.append(statement)
		return true
		)


func _parse_and_process_indentation() -> bool:
	var token : Token = _tokenizer.peek()
	match token.type:
		Token.Type.LINE_BREAK: #TODO remove
			_parse_line_break()
			return true
		Token.Type.INDENTATION: #TODO remove
			_parse_indentation()
			return true
		Token.Type.STATEMENT_BREAK:
			_parse_statement_break()
			return true
		Token.Type.WHITESPACE:
			_tokenizer.get_next()
			return true
	return false


func _parse_statement(parent : AST.ASTNode) -> AST.ASTNode:
	var token : Token = _tokenizer.peek()
	
	#TODO skip and consume indentation here
	
	if _parse_and_process_indentation():
		return null
	
	var node : AST.ASTNode = null
	
	match token.type:
		Token.Type.PUNCTUATOR:
			_parse_punctuator()
		Token.Type.SYMBOL:
			node = _parse_symbol(parent)
			#return _parse_call(parent) if _is_call() else _parse_assignment(parent)
		Token.Type.KEYWORD:
			node = _parse_keyword(parent)
		Token.Type.ANNOTATION:
			node = _parse_annotation(parent)
		Token.Type.COMMENT:
			_parse_comment(token)
		_:
			_tokenizer.get_next()
	
	_statement_break = false  # Statement break persists until next non-whitespace token
	
	#TODO skip line break here, unless we've got a semicolon coming up next
	return node

func _parse_statement_break() -> void:
	_tokenizer.get_next()
	_statement_break = true


func _parse_line_break() -> void:
	_tokenizer.get_next()
	if _bracket_lock > 0 or _statement_break:
		return
	_current_indentation = 0


func _parse_indentation() -> void:
	var token : Token = _tokenizer.get_next()
	if _bracket_lock > 0 or _statement_break:
		return
	_current_indentation = token.get_value().length()


func _parse_punctuator() -> void:
	var token : Token = _tokenizer.get_next()
	
	match token.get_value():
		'(', '[', '{':
			_bracket_lock += 1
		')', ']', '}':
			_bracket_lock -= 1

func _parse_annotation(parent : AST.ASTNode) -> AST.ASTNode:
	var token : Token = _tokenizer.get_next()

	if token.get_value().begins_with("@export_node_path") and _tokenizer.peek().is_punctuator("("):
		return _parse_export_node_path_var(parent)
	
	if token.get_value().begins_with("@export"):
		if _tokenizer.peek().is_punctuator("("):
			_parse_annotation_arguments(parent)
		
		var exported_var : bool = true
		for key : String in ["@export_category", "@export_group", '@export_subgroup']:
			if token.get_value().begins_with(key):
				exported_var = false
				break
		
		
		
		if exported_var:
			var _token : Token = _tokenizer.get_next()
			while _token and _token.get_value() != "var":
				_token = _tokenizer.get_next()
			return _parse_export_var(parent)
			
		else:
			var _token : Token = _tokenizer.peek(0)
			while _token and _token.is_whitespace():
				_token = _tokenizer.get_next()
			
	return null


# The arguments of an annotation, up to its closing bracket. A name in them, as in
# @export_range(0, MAX_SPEED), is one like anywhere else and is renamed with what it names
func _parse_annotation_arguments(parent : AST.ASTNode) -> void:
	var depth : int = 0
	while !_tokenizer.is_eof():
		var token : Token = _tokenizer.peek()
		if token.is_symbol() and depth > 0:
			var symbol : AST.Symbol = _parse_symbol(parent)
			if symbol and parent is AST.Sequence:
				parent.statements.append(symbol)
			continue
		_tokenizer.get_next()
		if token.is_punctuator("("):
			depth += 1
		elif token.is_punctuator(")"):
			depth -= 1
			if depth <= 0:
				return


func _parse_symbol(parent : AST.ASTNode) -> AST.Symbol:
	if _is_dictionary_key(_tokenizer.peek()):
		_tokenizer.get_next()
		return null

	var ast := AST.Symbol.new(parent)
	
	ast.path = _parse_symbol_path(ast)
	
	return ast


func _parse_string_symbol(ast_node : AST.ASTNode) -> SymbolTable.SymbolPath:
	var path : SymbolTable.SymbolPath = _symbol_table.create_symbol_path(ast_node)
	path.maybe_local = !_tokenizer.peek(0) or !_tokenizer.peek(0).is_punctuator(".")
	path.set_log(_Logger.current_log)
	path.line = _tokenizer.peek().line
	
	var token : Token = _tokenizer.peek()
	var symbol : SymbolTable.Symbol = path.add(token.get_value(false))
	token.link_symbol(symbol)
	
	_tokenizer.get_next()
	return path


func _is_symbol_typed(token : Token) -> bool:
	return null != token and token.get_value() in BUILT_IN.SYMBOLS_TYPED

func _parse_symbol_path(ast_node : AST.ASTNode) -> SymbolTable.SymbolPath:
	var path : SymbolTable.SymbolPath = _symbol_table.create_symbol_path(ast_node)
	path.maybe_local = !_tokenizer.peek(0) or !_tokenizer.peek(0).is_punctuator(".")
	path.set_log(_Logger.current_log)
	path.line = _tokenizer.peek().line
	
	while !_tokenizer.is_eof():
		var token : Token = _tokenizer.peek()
		if token.is_punctuator():
			var value : String = token.get_value()
			if "." == value:
				_tokenizer.get_next()
				continue
			elif "[" == value:
				if _is_symbol_typed(_tokenizer.peek(0)):
					_tokenizer.get_next()
					while !_tokenizer.is_eof():
						token = _tokenizer.peek()
						if token.is_punctuator("]"):
							_tokenizer.get_next()
							break
						elif token.is_symbol():
							_tokenizer.get_next()
							var _symbol : SymbolTable.Symbol = path.add(token.get_value())
							token.link_symbol(_symbol)
						else:
							_tokenizer.get_next()
					continue
		elif token.is_symbol():
			_tokenizer.get_next()
			var symbol : SymbolTable.Symbol = path.add(token.get_value())
			token.link_symbol(symbol)
			continue
		break
	
	path.is_call = _tokenizer.peek().is_punctuator("(")
	
	return path


func _parse_call(parent : AST.ASTNode) -> AST.Call:
	var ast := AST.Call.new(parent)
	
	ast.path = _parse_symbol_path(ast)
	ast.args = _parse_args(ast)
	
	return ast


func _parse_args(parent : AST.ASTNode) -> Array[AST.Expr]:
	var args : Array[AST.Expr]
	
	while !_tokenizer.is_eof():
		var token : Token = _tokenizer.peek()
		if token.is_punctuator("(") or token.is_punctuator(","):
			_tokenizer.get_next()
			_parse_expression(parent)
		elif token.is_punctuator(")"):
			_tokenizer.get_next()
			break
		else:
			_Logger.write("ERROR: Parser._parse_args() - Unexpected token '" + str(token) + "'!")
			return args
	
	return args


func _parse_assignment(parent : AST.ASTNode) -> AST.Assignment:
	var ast := AST.Assignment.new(parent)
	
	ast.target = _parse_symbol_path(ast)
	ast.op = _tokenizer.get_next().get_value()
	ast.expr = _parse_expression(ast)
	
	return ast


func _parse_expression(parent : AST.ASTNode, end : String = "") -> AST.Expr:
	var ast := AST.Expr.new(parent)
	
	#TODO
	
	return ast


func _parse_keyword(parent : AST.ASTNode) -> AST.ASTNode:
	var token : Token = _tokenizer.get_next()
	
	match token.get_value():
		"class_name":
			_parse_class_name(parent)
		"extends":
			_parse_extends(parent)
		"class":
			return _parse_class(parent)
		"signal":
			return _parse_signal(parent)
		"enum":
			return _parse_enum(parent)
		"const":
			return _parse_const(parent)
		"var":
			return _parse_var(parent)
		"func":
			return _parse_func(parent)
		"if":
			return _parse_if(parent)
		"else":
			return _parse_else(parent)
		"elif":
			return _parse_elif(parent)
		"match":
			return _parse_match(parent)
		"for":
			return _parse_for(parent)
		"while":
			return _parse_while(parent)
	
	return null


func _parse_if(parent : AST.ASTNode) -> AST.If:
	if _tokenizer.peek(-1).type != Token.Type.INDENTATION:
		return null # Don't parse inline conditionals
	
	var ast := AST.If.new(parent)
	
	var indentation : int = _current_indentation
	
	ast.condition = _parse_expression(ast, ":")
	ast.body = _parse_block(ast, indentation)
	
	return ast


func _parse_else(parent : AST.ASTNode) -> AST.Else:
	if _tokenizer.peek(-1).type != Token.Type.INDENTATION:
		return null # Don't parse inline conditionals
	
	var ast := AST.Else.new(parent)
	
	var indentation : int = _current_indentation
	
	ast.body = _parse_block(ast, indentation)
	
	return ast


func _parse_elif(parent : AST.ASTNode) -> AST.Elif:
	if _tokenizer.peek(-1).type != Token.Type.INDENTATION:
		return null # do not parse inline conditionals
	
	var ast := AST.Elif.new(parent)
	
	var indentation : int = _current_indentation
	
	ast.condition = _parse_expression(ast, ":")
	ast.body = _parse_block(ast, indentation)
	
	return ast


func _parse_match(parent : AST.ASTNode) -> AST.Match:
	var ast := AST.Match.new(parent)
	
	ast.body = _parse_block(ast, _current_indentation)
	#var indentation : int = _current_indentation
	#
	#while !_tokenizer.is_eof():
		#var token : Token = _tokenizer.peek()
		#if token.is_symbol():
			#ast.symbols.append(_parse_symbol(ast))
		#elif token.is_punctuator(":"):
			#_tokenizer.get_next()
			#_tokenizer.get_next()
			#break
		#else:
			#_tokenizer.get_next()
	#
	#while !_tokenizer.is_eof():
		#var token : Token = _tokenizer.peek()
		#var line : Tokenizer.Line = _tokenizer.get_output_line(token.line)
		#if !line.has_statement():
			#_tokenizer.skip_to("\n")
		#elif line.get_indentation() <= indentation:
			#break
		#else:
			#_tokenizer.get_next()
			#if _tokenizer.peek().is_symbol():
				#ast.symbols.append(_parse_symbol(ast))
			#_tokenizer.skip_to("\n")
			#ast.patterns.append(_parse_block(ast, indentation + 1))
	
	return ast


func _parse_for(parent : AST.ASTNode) -> AST.For:
	var ast := AST.For.new(parent)
	
	var indentation : int = _current_indentation
	var symbol_token : Token = _tokenizer.get_next()
	var lock_symbol : bool = _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS)
	
	var iterator := AST.Iterator.new(ast)
	iterator.symbol = _symbol_table.create_symbol(ast, symbol_token.get_value(), _parse_var_type(ast))
	
	ast.iterator = iterator
	ast.expr = _parse_expression(ast, ":")
	ast.body = _parse_block(ast, indentation)
	
	symbol_token.link_symbol(iterator.symbol)
	if lock_symbol:
		_symbol_table.lock_symbol(iterator.symbol)
	
	return ast


func _parse_while(parent : AST.ASTNode) -> AST.While:
	var ast := AST.While.new(parent)
	
	var indentation : int = _current_indentation
	
	ast.condition = _parse_expression(ast, ":")
	ast.body = _parse_block(ast, indentation)
	
	return ast


func _parse_class_name(parent : AST.ASTNode) -> void:
	var token : Token = _tokenizer.get_next()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_class_name() - Symbol expected!")
		return
	
	var ast : AST.ASTNode = parent
	while ast.get_parent() and not ast is AST.Class:
		ast = ast.get_parent()
	
	_symbol_table.add_class_name(token.get_value())
	_class_symbol = _symbol_table.create_global_symbol(token.get_value())
	ast.symbol = _class_symbol
	
	token.link_symbol(ast.symbol)
	
	if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
		_symbol_table.lock_symbol(ast.symbol)


func _parse_extends(parent : AST.ASTNode) -> void:
	var token : Token = _tokenizer.peek()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_extends() - Symbol expected!")
		return
	
	var ast : AST.ASTNode = parent
	while ast.get_parent() and not ast is AST.Class:
		ast = ast.get_parent()
	
	ast.ext = _parse_symbol_path(ast)


func _parse_class(parent : AST.ASTNode) -> AST.Class:
	var token : Token = _tokenizer.get_next()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_class() - Symbol expected!")
		return null
		
	var ast := AST.Class.new(parent)
	
	var name : String = token.get_value()
	var indentation : int = _current_indentation
	var lock_symbol : bool = _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS)
	
	if _tokenizer.peek().is_keyword("extends"):
		_tokenizer.get_next()
		ast.ext = _parse_symbol_path(ast)
	
	_symbol_table.add_class_name(name)
	ast.symbol = _symbol_table.create_global_symbol(name)
	ast.body = _parse_block(ast, indentation)
	
	token.link_symbol(ast.symbol)
	if lock_symbol:
		_symbol_table.lock_symbol(ast.symbol)
	
	if _class_symbol:
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_signal(parent : AST.ASTNode) -> AST.SignalDef:
	var token : Token = _tokenizer.get_next()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_signal() - Symbol expected!")
		return null
	
	var ast := AST.SignalDef.new(parent)
	ast.symbol = _symbol_table.create_global_symbol(token.get_value())
	ast.params = _parse_params(parent)
	
	token.link_symbol(ast.symbol)
	if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
		_symbol_table.lock_symbol(ast.symbol)
	
	if _class_symbol and _is_autoload and _is_class_level(parent):
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_enum(parent : AST.ASTNode) -> AST.EnumDef:
	var ast : AST.EnumDef
	
	# Check if enum is Named
	var token : Token = _tokenizer.get_next()
	
	if token.is_symbol():
		ast = AST.EnumDef.new(parent)
		ast.symbol = _symbol_table.create_global_symbol(token.get_value())
		
		token.link_symbol(ast.symbol)
		if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
			_symbol_table.lock_symbol(ast.symbol)
	
	var expect_key : bool = true
	while !_tokenizer.is_eof():
		token = _tokenizer.peek()
		if token.is_symbol():
			if expect_key:
				if ast:
					ast.keys.append(_parse_enum_key(ast))
				else:
					parent.statements.append(_parse_enum_key(parent))
				expect_key = false
				continue
			else:
				# Part of a value, like the RED in DEFAULT = RED. The token after it is yet to be looked at.
				var value : AST.Symbol = _parse_symbol(parent)
				if value:
					parent.statements.append(value)
				continue
		elif token.is_punctuator(","):
			expect_key = true
		elif token.is_punctuator("}"):
			_tokenizer.get_next()
			break
		elif token.is_comment():
			_parse_comment(token)
			continue
		_tokenizer.get_next()
	
	if _class_symbol and ast and _is_class_level(parent):
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_enum_key(parent : AST.ASTNode) -> AST.EnumDef.KeyDef:
	var token : Token = _tokenizer.get_next()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_enum_key() - Symbol expected!")
		return null
	
	var key := AST.EnumDef.KeyDef.new(parent)
	#key.symbol = _symbol_table.create_local_symbol(token.get_value())
	key.symbol = _symbol_table.create_global_symbol(token.get_value())
	
	token.link_symbol(key.symbol)
	if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
		_symbol_table.lock_symbol(key.symbol)
	
	if parent is AST.SymbolDeclaration and parent.symbol:
		parent.symbol.add_child(key.symbol)
	elif _class_symbol:
		_class_symbol.add_child(key.symbol)
	
	token = _tokenizer.peek()
	if token.is_operator("="):
		_tokenizer.get_next()
		key.expr = _parse_expression(key)
	else:
		key.expr = AST.Expr.new(key)
	
	return key


func _parse_const(parent : AST.ASTNode) -> AST.Const:
	var token : Token = _tokenizer.get_next()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_const() - Symbol expected!")
		return null
	
	# Before the value is read, which may end on another line
	var lock_symbol : bool = _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS)
	
	var ast := AST.Const.new(parent)
	ast.symbol = _symbol_table.create_symbol(ast, token.get_value(), _parse_var_type(ast))
	ast.default = _parse_var_default(ast)
	ast.getset = _parse_var_getset(ast)
	
	token.link_symbol(ast.symbol)
	if lock_symbol:
		_symbol_table.lock_symbol(ast.symbol)
	
	if _class_symbol and _is_class_level(parent):
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_var(parent : AST.ASTNode) -> AST.Var:
	var token : Token = _tokenizer.get_next()
	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_var() - Symbol expected!")
		return null
	
	var is_static : bool = _tokenizer.peek(-2).is_keyword("static") if _tokenizer.peek(-2) else false

	var ast := AST.Var.new(parent)

	# A binding in a match pattern, like "var x:", has neither type, value nor accessors.
	# The colon after it begins the body of the branch.
	if parent.get_parent() is AST.Match:
		_pattern_bindings[token.idx] = true
		ast.symbol = _symbol_table.create_local_symbol(token.get_value())
		token.link_symbol(ast.symbol)
		if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
			_symbol_table.lock_symbol(ast.symbol)
		return ast

	ast.symbol = _symbol_table.create_symbol(ast, token.get_value(), _parse_var_type(ast))

	token.link_symbol(ast.symbol)
	if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
		_symbol_table.lock_symbol(ast.symbol)

	ast.default = _parse_var_default(ast)
	ast.getset = _parse_var_getset(ast)
	
	if _class_symbol and (_is_autoload or is_static) and _is_class_level(parent):
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_export_var(parent : AST.ASTNode) -> AST.ExportVar:
	var token : Token = _tokenizer.get_next()
	if !token or !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_export_var() - Symbol expected!")
		return null
	
	var ast := AST.ExportVar.new(parent)
	ast.symbol = _symbol_table.create_export_symbol(token.get_value(), _parse_var_type(ast))
	
	token.link_symbol(ast.symbol)
	if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
		_symbol_table.lock_symbol(ast.symbol)
	
	ast.default = _parse_var_default(ast)
	ast.getset = _parse_var_getset(ast)
	
	if _class_symbol and _is_autoload:
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_export_node_path_var(parent : AST.ASTNode) -> AST.ExportNodePathVar:
	var token : Token = _tokenizer.get_next()

	var ast := AST.ExportNodePathVar.new(parent)
	ast.types = _parse_string_symbol_array(ast)
	
	while _tokenizer.get_next().get_value() != "var":
		pass

	token = _tokenizer.get_next()

	if !token.is_symbol():
		_Logger.write("ERROR: Parser._parse_export_node_path_var() - Symbol expected!")
		return null
	
	ast.symbol = _symbol_table.create_export_symbol(token.get_value(), _parse_var_type(ast))
	
	token.link_symbol(ast.symbol)
	if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
		_symbol_table.lock_symbol(ast.symbol)
	
	ast.default = _parse_var_default(ast)
	ast.getset = _parse_var_getset(ast)
	
	if _class_symbol and _is_autoload:
		_class_symbol.add_child(ast.symbol)
	
	return ast


func _parse_string_symbol_array(parent : AST.ASTNode) -> Array[AST.StringSymbol]:
	var result : Array[AST.StringSymbol] = []

	var token : Token

	var pth : int = 0
	while !_tokenizer.is_eof():
		token = _tokenizer.peek()
	
		if token.is_string_literal():
			var ast := AST.StringSymbol.new(parent)
			ast.path = _parse_string_symbol(ast)
			result.append(ast)
			continue
	
		if token.is_punctuator():
			if token.get_value() == "(":
				pth += 1
			elif token.get_value() == ")":
				pth -= 1
				if pth <= 0:
					break
		_tokenizer.get_next()

	return result


func _parse_func(parent : AST.ASTNode) -> AST.Func:
	var token : Token = _tokenizer.peek()
	var name : String = "@lambda"
	var is_static : bool = false
	var lock_symbols : bool = _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS)
	var obfuscate_string_params : bool = _line_has_hint(PreprocessorHints.OBFUSCATE_STRING_PARAMETERS, -1)
	var string_params : PackedStringArray = _line_get_hint_args(PreprocessorHints.OBFUSCATE_STRING_PARAMETERS, -1).split(" ", false)
	
	if token.is_symbol():
		_tokenizer.get_next()
		name = token.get_value()
		is_static = _tokenizer.peek(-2).is_keyword("static") if _tokenizer.peek(-2) else false
	
	var indentation : int = _current_indentation
	var bracket_lock : int = _bracket_lock
	
	var ast := AST.Func.new(parent)
	
		
	var params : Array[AST.Parameter] = _parse_params(ast)
	var type : String = _parse_func_type(ast)
	
	
	_bracket_lock = 0

	ast.symbol = _symbol_table.create_symbol(ast, name, type)
	ast.params = params
	ast.body = _parse_block(ast, indentation)
	
	if token.is_symbol():
		token.link_symbol(ast.symbol)
		if lock_symbols:
			_symbol_table.lock_symbol(ast.symbol)
	
	if obfuscate_string_params:
		for i in params.size():
			if string_params.has(params[i].symbol.get_name()):
				ast.symbol.add_string_param(i)
	
	if _class_symbol and (_is_autoload or is_static) and _is_class_level(parent):
		_class_symbol.add_child(ast.symbol)
	
	_bracket_lock += bracket_lock
	if bracket_lock:
		_current_indentation = indentation
	
	return ast


func _parse_params(parent : AST.ASTNode) -> Array[AST.Parameter]:
	var params : Array[AST.Parameter]
	if _tokenizer.is_eof() or !_tokenizer.peek().is_punctuator("("):
		return params
	
	var depth : int = 0 # Of all brackets, as a default value may hold an array or a dictionary
	var param := AST.Parameter.new(parent)
	var expect_symbol : bool = true
	while !_tokenizer.is_eof():
		var token : Token = _tokenizer.peek()
		if token.is_punctuator():
			_tokenizer.get_next()
			match token.get_value():
				"(", "[", "{":
					depth += 1
				")", "]", "}":
					depth -= 1
					if depth <= 0:
						if param.symbol:
							params.append(param)
						return params
				",":
					if depth == 1:
						expect_symbol = true
						if param.symbol:
							params.append(param)
						param = AST.Parameter.new(parent)
		elif _is_dictionary_key(token):
			_tokenizer.get_next()
		elif token.is_symbol():
			if expect_symbol:
				_tokenizer.get_next()
				
				expect_symbol = false
				param.symbol = _symbol_table.create_local_symbol(token.get_value(), _parse_var_type(param))
				token.link_symbol(param.symbol)
				if _blocked or _line_has_hint(PreprocessorHints.LOCK_SYMBOLS):
					_symbol_table.lock_symbol(param.symbol)
			else:
				# Part of a default value, which may refer to the parameters before it
				_parse_symbol_path(param)
		elif token.is_comment():
			_parse_comment(token)
		else:
			_tokenizer.get_next()
	
	return params


func _parse_func_type(ast : AST.ASTNode) -> String:
	if _tokenizer.peek(1).is_operator("->"):
		_tokenizer.get_next()
		var path : SymbolTable.SymbolPath = _parse_symbol_path(ast)
		return str(path)#.trim_suffix("void")
	
	return ""


func _parse_var_type(ast : AST.ASTNode) -> String:
	if _tokenizer.peek(1).is_punctuator(":") and !_tokenizer.peek(2).is_operator("="):
		# Check that this isn't a getter setter
		var i : int = 2
		while !_tokenizer.is_eof(i):
			match _tokenizer.peek(i).type:
				Token.Type.SYMBOL:
					break
				Token.Type.LINE_BREAK:
					return ""
			i += 1
		_tokenizer.get_next()
		var path : SymbolTable.SymbolPath = _parse_symbol_path(ast)
		return str(path)

	# A variable set to a dictionary is one, so its keys are not mistaken for members
	var assign : int = 2 if _tokenizer.peek(1).is_punctuator(":") else 1
	var value : Token = _tokenizer.peek(assign + 1)
	if value and value.is_punctuator("{") and _tokenizer.peek(assign).is_operator("="):
		return "Dictionary"

	# A variable set to what a function returns has the type the function is declared with, which
	# is looked up once every symbol is known. The call has to be all there is to the value
	# That may be a static function of a named class, as in ClassName.function()
	var function : String = value.get_value() if value and value.is_symbol() else ""
	var open : int = assign + 2
	if function and _tokenizer.peek(open) and _tokenizer.peek(open).is_punctuator(".") and _tokenizer.peek(open + 1) and _tokenizer.peek(open + 1).is_symbol():
		function += "." + _tokenizer.peek(open + 1).get_value()
		open += 2
	if function and _tokenizer.peek(assign).is_operator("=") and _tokenizer.peek(open) and _tokenizer.peek(open).is_punctuator("("):
		var i : int = open + 1
		var depth : int = 1
		while depth > 0 and _tokenizer.peek(i):
			if _tokenizer.peek(i).is_punctuator("("):
				depth += 1
			elif _tokenizer.peek(i).is_punctuator(")"):
				depth -= 1
			i += 1
		var after : Token = _tokenizer.peek(i)
		if depth == 0 and (!after or after.is_line_break() or after.is_comment() or after.type == Token.Type.STATEMENT_BREAK):
			return SymbolTable.RETURNED_BY + function

	return ""


func _parse_var_default(parent : AST.ASTNode) -> AST.Sequence:
	if _tokenizer.peek(2) and (_tokenizer.peek(1).is_punctuator(":") and _tokenizer.peek(2).is_operator("=")) or _tokenizer.peek(1).is_operator("="):
		if _tokenizer.peek(1).is_punctuator(":"):
			_tokenizer.get_next()
		_tokenizer.get_next()
		
		var indentation : int = _current_indentation
		var bracket_lock : int = _bracket_lock
		
		_bracket_lock = 0
		
		var ast: AST.Sequence = _parse_block_with_callback(parent, indentation, func(ast : AST.Sequence, line : Tokenizer.Line, token : Token, indentation : int):
			match token.type:
				Token.Type.KEYWORD:
					_statement_break = false
					_tokenizer.get_next()
					if token.is_keyword('func'):
						var function : AST.Func = _parse_func(ast)
						if function:
							ast.statements.append(function)
				Token.Type.SYMBOL:
					var symbol : AST.ASTNode = _parse_symbol(ast)
					if symbol:
						ast.statements.append(symbol)
				Token.Type.PUNCTUATOR:
					if token.get_value() == ':' and _bracket_lock <= 0:
						return false
					else:
						_parse_punctuator()
				Token.Type.COMMENT:
					_parse_comment(token)
				_:
					if not _parse_and_process_indentation():
						_tokenizer.get_next()
			return true
		)
		
		_bracket_lock += bracket_lock
		if bracket_lock:
			_current_indentation = indentation
		
		return ast
	
	return null


func _parse_var_getset(parent : AST.ASTNode) -> AST.Sequence:
	if _tokenizer.peek(1) and _tokenizer.peek(1).is_punctuator(":"):
		var indentation : int = _current_indentation
		var bracket_lock : int = _bracket_lock
		
		_bracket_lock = 0
		
		var ast: AST.Sequence = _parse_block_with_callback(parent, indentation, func(ast : AST.Sequence, line : Tokenizer.Line, token : Token, indentation : int):
			if token.is_symbol("get") or token.is_symbol("set"):
				var function : AST.Func = _parse_func(ast)
				if function:
					_symbol_table.lock_symbol(function.symbol)
					ast.statements.append(function)
				if _tokenizer.peek() and _tokenizer.peek().is_punctuator(',') and _bracket_lock == 0 and not _statement_break:
					_tokenizer.get_next()
			else:
				if not _parse_and_process_indentation():
					_tokenizer.get_next()
			return true
		)
		
		_bracket_lock += bracket_lock
		if bracket_lock:
			_current_indentation = indentation
		
		return ast
	
	return null


func _skip_brackets(brackets_in : String, brackets_out : String) -> void:
	var pth : int = 0
	while !_tokenizer.is_eof():
		var token : Token = _tokenizer.get_next()
		if token.is_punctuator():
			if token.get_value() == brackets_in:
				pth += 1
			elif token.get_value() == brackets_out:
				pth -= 1
				if pth <= 0:
					return


func _get_line_hints(offset : int = 0) -> Dictionary:
	var line : Tokenizer.Line = _tokenizer.get_output_line(_tokenizer.peek(0).line + offset)
	return line.hints if line else {}


func _line_has_hint(hint : String, offset : int = 0) -> bool:
	var line : Tokenizer.Line = _tokenizer.get_output_line(_tokenizer.peek(0).line + offset)
	return line.hints.has(hint) if line else false


func _line_get_hint_args(hint : String, offset : int = 0) -> String:
	var line : Tokenizer.Line = _tokenizer.get_output_line(_tokenizer.peek(0).line + offset)
	return line.hints.get(hint, "") if line else ""


func _is_call() -> bool:
	var i : int = 1
	var token : Token = _tokenizer.peek(i)
	while token and (token.is_symbol() or token.is_punctuator(".")):
		i += 1
		token = _tokenizer.peek(i)
	
	return token.is_punctuator("(") if token else false


func _is_statement(token : Token) -> bool:
	return token and token.type != Token.Type.COMMENT and token.type != Token.Type.WHITESPACE and token.type != Token.Type.INDENTATION and token.type != Token.Type.LINE_BREAK 

func _parse_comment(token : Token) -> void:
	var value : String = token.get_value().strip_edges().trim_prefix(_Settings.current.preprocessor_prefix).get_slice(" ", 0)
	match value:
		PreprocessorHints.START_LOCK_SYMBOLS:
			_blocked = true
		PreprocessorHints.END_LOCK_SYMBOLS:
			_blocked = false
		
	_tokenizer.get_next()
