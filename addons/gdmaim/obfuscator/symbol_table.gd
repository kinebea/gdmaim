extends RefCounted


const _Logger := preload("../logger.gd")
const _Settings := preload("../settings.gd")
const StringRef := preload("string_ref.gd")
const AST := preload("script/parser/ast.gd")

# The type of a variable set to what a function returns, ahead of the name of that function
const RETURNED_BY : String = "returned by "

var settings : _Settings

var _seed : int
var _locked_symbols : Dictionary
var _global_symbols : Dictionary
var _local_symbols : Array[Symbol]
var _export_symbols : Dictionary
var _symbol_paths : Array[SymbolPath]
var _id_list : PackedStringArray
var _id_table : Dictionary
var _unique_ids : Dictionary

var _custom_seed : int = 0
var _class_names : Dictionary
var _used_ids : Dictionary

# Words a generated name must not be, on top of the names that are locked
const RESERVED : PackedStringArray = ["if", "elif", "else", "for", "while", "match", "when", "break", "continue", "pass", "return", "class", "class_name", "extends", "is", "in", "as", "self", "super", "signal", "func", "static", "const", "enum", "var", "breakpoint", "preload", "await", "yield", "assert", "void", "and", "or", "not", "namespace", "trait", "true", "false", "null", "PI", "TAU", "INF", "NAN"]


func _init(settings : _Settings) -> void:
	self.settings = settings
	_seed = hash(str(settings.symbol_seed if !settings.symbol_dynamic_seed else int(Time.get_unix_time_from_system())))


func lock_symbol_name(name : String) -> void:
	_locked_symbols[name] = true


func lock_symbol(symbol : Symbol) -> void:
	var lidx : int = _local_symbols.find(symbol)
	if lidx != -1:
		_local_symbols.remove_at(lidx)
	else:
		lock_symbol_name(symbol.get_name())
		
func set_custom_seed(new_seed : int = 0) -> void:
	_custom_seed = new_seed

func create_symbol(ast_node : AST.ASTNode, name : String, type : String = "") -> Symbol:
	if ast_node.get_parent() is AST.Sequence and ast_node.get_parent().get_parent() is AST.Class:
		return create_global_symbol(name, type)
	else:
		return create_local_symbol(name, type)


func create_export_symbol(name : String, type : String = "") -> Symbol:
	var symbol : Symbol = create_global_symbol(name, type)
	_export_symbols[name] = symbol
	
	if !settings.obfuscate_export_vars:
		lock_symbol_name(name)
	
	return symbol


func create_global_symbol(name : String, type : String = "") -> Symbol:
	var symbol : Symbol = _global_symbols.get(name)
	if !symbol:
		symbol = Symbol.new(name)
		_global_symbols[name] = symbol
	
	return Symbol.new_linked(type, symbol)


func create_local_symbol(name : String, type : String = "") -> Symbol:
	var symbol := Symbol.new(name, type)
	_local_symbols.append(symbol)
	
	return symbol


func create_symbol_path(ast_node : AST.ASTNode) -> SymbolPath:
	var path := SymbolPath.new()
	path.set_ast(ast_node)
	_symbol_paths.append(path)
	
	return path


# Classes of the project, to tell them from its enums where either may be a type
func add_class_name(name : String) -> void:
	_class_names[name] = true


func is_class_name(name : String) -> bool:
	return _class_names.has(name)


func find_global_symbol(symbol : String) -> Symbol:
	return _global_symbols.get(symbol)


func find_export_symbol(symbol : String) -> Symbol:
	return _export_symbols.get(symbol)


func rename_symbol(symbol : Symbol, target : String) -> void:
	#if _locked_symbols.has(symbol.get_name()): #NOTE obfuscation does its own check
		#return
	
	symbol.name.set_value(target)


func resolve_symbol_paths() -> void:
	for symbol_path in _symbol_paths:
		var log : String = "Line " + str(symbol_path.line + 1) + " | " + str(symbol_path) + " |"
		
		var cur : Symbol
		var maybe_local : bool = symbol_path.maybe_local
		for symbol in symbol_path.symbols:
			log += " [" + symbol.get_name() + "="
			if cur:
				cur = cur.children.get(symbol.get_name())
				log += "CHILD" if cur else ""
			if !cur and maybe_local:
				cur = _search_symbol(symbol_path.get_ast(), symbol.get_name(), symbol_path.is_call and symbol_path.symbols.back() == symbol)
				log += "LOCAL" if cur else ""
			elif !cur and symbol_path.of_self and symbol == symbol_path.symbols[0] and symbol_path.get_ast():
				cur = _search_member(symbol_path.get_ast(), symbol.get_name(), symbol_path.is_call and symbol_path.symbols.size() == 1)
				log += "MEMBER" if cur else ""
			if !cur:
				cur = find_global_symbol(symbol.get_name())
				log += "GLOBAL" if cur else ""
			if cur:
				symbol.link(cur)
				# The keys of a dictionary are strings and no members, also those of a Dictionary[K, V]
				if _is_dictionary(cur, symbol_path):
					break
			else:
				log += "?"
			maybe_local = false
			log += "]"
		
		_Logger.swap(symbol_path.get_log())
		_Logger.write(log)


# Whether the symbol is of the type Dictionary, or is set to what a function returns that is declared
# to return one. That function is looked for from where the symbol is used, or among the static
# functions of the class or the autoload it is called on
func _is_dictionary(symbol : Symbol, symbol_path : SymbolPath) -> bool:
	var type : String = symbol.type
	if type.begins_with(RETURNED_BY):
		var name : String = type.trim_prefix(RETURNED_BY)
		var function : Symbol = null
		if name.contains("."):
			# A static function of a named class, or a function of an autoload, which it has among its children
			var owner : Symbol = find_global_symbol(name.get_slice(".", 0))
			function = owner.children.get(name.get_slice(".", 1)) if owner else null
		elif symbol_path.get_ast():
			function = _search_symbol(symbol_path.get_ast(), name, true)
		type = function.type if function else ""
	return type == "Dictionary" or type.begins_with("Dictionary.")


func obfuscate_symbols() -> void:
	if _Settings.current.custom_token_regex_buffer:
		for symbol in _local_symbols:
			var str : String = symbol.get_name()
			if !_locked_symbols.has(str) and !is_custom_lock_settings(str):
				rename_symbol(symbol, _generate_symbol_name(str, true))
		
		for symbol in _global_symbols.values():
			var str : String = symbol.get_name()
			if !_locked_symbols.has(str) and !is_custom_lock_settings(str):
				rename_symbol(symbol, _generate_symbol_name(str))
		
	else:
		for symbol in _local_symbols:
			var str : String = symbol.get_name()
			if !_locked_symbols.has(symbol.get_name()):
				rename_symbol(symbol, _generate_symbol_name(str, true))
		
		for symbol in _global_symbols.values():
			var str : String = symbol.get_name()
			if !_locked_symbols.has(str):
				rename_symbol(symbol, _generate_symbol_name(str))

func is_custom_lock_settings(str : String) -> bool:
	for rgx in _Settings.current.get_tokens_rgx():
		if null != rgx.search(str):
			_locked_symbols[str] = true
			return true
	return false

func obfuscate_string_global(str : String) -> String:
	return _generate_symbol_name(str) if settings.obfuscation_enabled and !_locked_symbols.has(str) and !is_custom_lock_settings(str) else str


func _search_symbol(ast_node : AST.ASTNode, name : String, is_func : bool) -> Symbol:
	var from : AST.ASTNode = ast_node # Where the search came from, at first the place of use
	
	ast_node = ast_node.get_parent()
	while ast_node:
		var children : Array = ast_node.get_children()
		if from is AST.Sequence and not ast_node is AST.Sequence:
			# The statements of its block have been searched, which leaves what the node itself declares
			if ast_node is AST.Func:
				children = ast_node.params
			elif ast_node is AST.For:
				children = [ast_node.iterator]
			else:
				children = []
		
		# Members of a class can be used ahead of their declaration, unlike anything else
		var any_order : bool = ast_node is AST.Sequence and ast_node.get_parent() is AST.Class
		
		# The last declaration ahead of the place of use counts, as the branches
		# of a match may each bind the same name
		var found : Symbol = null
		for child in children:
			if child == from:
				if any_order:
					continue
				break
			elif child is AST.SymbolDeclaration and child.symbol and child.symbol.get_name() == name and (child is AST.Func == is_func):
				found = child.symbol
				if any_order:
					break
		if found:
			return found
		if ast_node is AST.Class:
			found = _search_inherited(ast_node, name, is_func)
			if found:
				return found
		
		from = ast_node
		ast_node = ast_node.get_parent()
	
	return null


# A member of the class the node is in, or of one it extends in the same script, as in self.name
func _search_member(ast_node : AST.ASTNode, name : String, is_func : bool) -> Symbol:
	while ast_node and not ast_node is AST.Class:
		ast_node = ast_node.get_parent()
	if !ast_node:
		return null
	for child in ast_node.body.statements:
		if child is AST.SymbolDeclaration and child.symbol and child.symbol.get_name() == name and (child is AST.Func == is_func):
			return child.symbol
	return _search_inherited(ast_node, name, is_func)


# A member that a class has from the inner classes of the script it extends, one after the other
func _search_inherited(cls : AST.Class, name : String, is_func : bool) -> Symbol:
	var seen : Array[AST.Class] = [cls]
	while cls.ext and cls.ext.symbols.size() == 1:
		cls = _find_inner_class(cls, cls.ext.symbols[0].get_name())
		if !cls or seen.has(cls):
			return null
		seen.append(cls)
		for child in cls.body.statements:
			if child is AST.SymbolDeclaration and child.symbol and child.symbol.get_name() == name and (child is AST.Func == is_func):
				return child.symbol
	return null


# The inner class of the given name that is seen from the given node
func _find_inner_class(from : AST.ASTNode, name : String) -> AST.Class:
	var node : AST.ASTNode = from.get_parent()
	while node:
		if node is AST.Sequence:
			for child in node.statements:
				if child is AST.Class and child.symbol and child.symbol.get_name() == name:
					return child
		node = node.get_parent()
	return null


func _generate_symbol_name(source_name : String, unique : bool = false) -> String:
	if !unique and _id_table.has(source_name) and _custom_seed == 0:
		return _id_table[source_name]
	
	var random := RandomNumberGenerator.new()
	
	var target_length : int = maxi(1, settings.symbol_target_length)
	var id : String
	
	if _custom_seed != 0:
		random.seed = hash(source_name) + source_name.length() + _custom_seed
		
		var _id : String = settings.symbol_prefix
		for j in target_length:
			_id += settings.symbol_characters[random.randi() % settings.symbol_characters.length()]
		id = _to_identifier(_id)
		
	else:
		random.seed = hash(source_name) + source_name.length() + _seed
	
		while !id or _is_taken(id):
			var _id : String = settings.symbol_prefix
			for j in target_length:
				_id += settings.symbol_characters[random.randi() % settings.symbol_characters.length()]
			_id = _to_identifier(_id)
			if !id and unique and _used_ids.has(_id):
				_unique_ids[source_name] = _unique_ids.get(source_name, 0) + 1
				random.seed += _unique_ids[source_name]
			else:
				target_length += 1
			id = _id
		
		_id_list.append(id)
		_used_ids[id] = true
		if !unique:
			_id_table[source_name] = id
		
	return id


# Whether a generated name cannot be used
func _is_taken(id : String) -> bool:
	return _used_ids.has(id) or _locked_symbols.has(id) or RESERVED.has(id)


# A name cannot begin with a digit, which it would with a prefix that is empty or begins with one
func _to_identifier(id : String) -> String:
	return "_" + id if id.is_empty() or (id[0] >= "0" and id[0] <= "9") else id


class Symbol extends RefCounted:
	var name : StringRef
	var source_name : String
	var type : String
	var children : Dictionary
	var string_params : Array
	var parent : Symbol
	
	static func new_linked(type : String, ref : Symbol) -> Symbol:
		var symbol := Symbol.new(ref.source_name, type)
		symbol.link(ref)
		return symbol
	
	func _init(name : String, type : String = "") -> void:
		self.name = StringRef.new(name)
		self.source_name = name
		self.type = type
	
	func _to_string() -> String:
		return str(name) if !type else str(name) + ":" + type
	
	func get_name() -> String:
		return name.get_value()
	
	func get_source_name() -> String:
		return source_name
	
	func add_child(other : Symbol) -> void:
		children[other.name.get_value()] = other
	
	func add_string_param(idx : int) -> void:
		if !string_params.has(idx):
			string_params.append(idx)
	
	func has_string_params() -> bool:
		return !string_params.is_empty()
	
	func is_string_param(idx : int) -> bool:
		return string_params.has(idx)
	
	func link(other : Symbol) -> void:
		name.link(other.name)
		parent = other
		children.merge(other.children)
		other.children = children
		string_params = string_params + other.string_params
		other.string_params = string_params
	
	func get_root() -> Symbol:
		return parent.get_root() if parent else self


class SymbolPath:
	var ast : WeakRef
	var symbols : Array[Symbol]
	var is_call : bool = false
	var maybe_local : bool = true
	var of_self : bool = false # Whether it comes after "self.", which makes it a member of the class
	var log : WeakRef
	var line : int
	
	func _to_string() -> String:
		var str : String
		for symbol in symbols:
			str += str(symbol) + "."
		return str.trim_suffix(".")
	
	func add(name : String) -> Symbol:
		var symbol := Symbol.new(name)
		symbols.append(symbol)
		return symbol
	
	func set_ast(ast : AST.ASTNode) -> void:
		self.ast = weakref(ast)
	
	func get_ast() -> AST.ASTNode:
		return ast.get_ref() as AST.ASTNode if ast else null
	
	func set_log(log : Variant) -> void:
		self.log = weakref(log)
	
	func get_log() -> Variant:
		return log.get_ref() if log else null
