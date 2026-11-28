extends RefCounted


const _SymbolTable := preload("../../symbol_table.gd")
const _Token := preload("../tokenizer/token.gd")


class _ASTNode:
	var parent : WeakRef
	var token : _Token
	var children : Array[_ASTNode]
	func _init(p : _ASTNode) -> void: parent = weakref(p)
	func _to_string() -> String: return "pass" if parent else "root"
	func get_parent() -> _ASTNode: return parent.get_ref() as _ASTNode if parent else null
	func get_children() -> Array[_ASTNode]: return children
	func print_tree(indentation : int = 0, indentation_str : String = ">   ") -> String:
		var str : String = "\n" + (indentation_str.repeat(indentation) if indentation > 0 else "") + str(self)
		for child in get_children():
			str += child.print_tree(indentation + 1)
		return str


class _Sequence extends _ASTNode:
	var token_from : _Token
	var token_to : _Token
	var statements : Array[_ASTNode]
	func _to_string() -> String: return "sequence"
	func get_children() -> Array[_ASTNode]: return statements


class _If extends _ASTNode:
	var condition : _Expr
	var body : _Sequence
	#var body_true : Sequence
	#var body_false : Sequence
	func _to_string() -> String: return "if"
	#func get_children() -> Array[ASTNode]: return [condition, body_true] if !body_false else [condition, body_true, body_false]
	func get_children() -> Array[_ASTNode]: return body.statements


class _Elif extends _ASTNode:
	var condition : _Expr
	var body : _Sequence
	#var body_true : Sequence
	#var body_false : Sequence
	func _to_string() -> String: return "elif"
	func get_children() -> Array[_ASTNode]: return body.statements


class _Else extends _ASTNode:
	var body : _Sequence
	#var body_true : Sequence
	#var body_false : Sequence
	func _to_string() -> String: return "else"
	func get_children() -> Array[_ASTNode]: return body.statements


class _Match extends _ASTNode:
	var body : _Sequence
	func _to_string() -> String: return "match"
	func get_children() -> Array[_ASTNode]: return body.statements


class _For extends _ASTNode:
	var iterator : _Var
	var expr : _Expr
	var body : _Sequence
	func _to_string() -> String: return "for"
	func get_children() -> Array[_ASTNode]: return ([iterator] as Array[_ASTNode]) + body.statements


class _Iterator extends _Var:
	func _to_string() -> String: return "iterator " + str(symbol)


class _While extends _ASTNode:
	var condition : _Expr
	var body : _Sequence
	func _to_string() -> String: return "while"
	func get_children() -> Array[_ASTNode]: return body.statements


class _SymbolDeclaration extends _ASTNode:
	var symbol : _SymbolTable._Symbol
	func _to_string() -> String: return "declare symbol " + str(symbol)


class _Class extends _SymbolDeclaration:
	var ext : _SymbolTable._SymbolPath
	var body : _Sequence
	func _to_string() -> String: return "class " + str(symbol) + " extends " + str(ext)
	func get_children() -> Array[_ASTNode]: return body.statements


class _Func extends _SymbolDeclaration:
	var params : Array[_Parameter]
	var body : _Sequence
	func _to_string() -> String: return "func " + str(symbol)
	func get_children() -> Array: return params + body.statements


class _SignalDef extends _SymbolDeclaration:
	var params : Array[_Parameter]
	func _to_string() -> String: return "signal " + str(symbol)
	func get_children() -> Array: return params


class _EnumDef extends _SymbolDeclaration:
	var keys : Array[_KeyDef]
	func _to_string() -> String: return "enum " + str(symbol)
	func get_children() -> Array: return keys

	class _KeyDef extends _SymbolDeclaration:
		var expr : _Expr
		func _to_string() -> String: return "key " + str(symbol)
		#func get_children() -> Array[ASTNode]: return [expr]


class _Var extends _SymbolDeclaration:
	var default : _Sequence
	var getset : _Sequence
	func _to_string() -> String: return "var " + str(symbol)
	func get_children() -> Array[_ASTNode]: return (default.statements if default else ([] as Array[_ASTNode])) + (getset.statements if getset else ([] as Array[_ASTNode]))


class _Const extends _Var:
	func _to_string() -> String: return "const " + str(symbol)


class _ExportVar extends _Var:
	func _to_string() -> String: return "@export var " + str(symbol)


class _ExportNodePathVar extends _ExportVar:
	var types : Array[_StringSymbol]
	func _to_string() -> String: return "@export_node_path var " + str(symbol)
	func get_children() -> Array: return types + super()


class _Parameter extends _Var:
	func _to_string() -> String: return "param " + str(symbol)


class _Symbol extends _ASTNode:
	var path : _SymbolTable._SymbolPath
	func _to_string() -> String: return "symbol " + str(path)


class _StringSymbol extends _ASTNode:
	var path : _SymbolTable._SymbolPath
	func _to_string() -> String: return 'symbol "' + str(path) + '"'


class _Call extends _Symbol:
	var args : Array[_Expr]
	func _to_string() -> String: return "call " + str(path)
	func get_children() -> Array: return args


class _Expr extends _ASTNode:
	var expr : String
	var symbol_paths : Array[_SymbolTable._SymbolPath]
	func _to_string() -> String: return expr + " " + str(symbol_paths)
	#func get_children() -> Array[ASTNode]: return components


class _Assignment extends _ASTNode:
	var target : _SymbolTable._SymbolPath
	var op : String
	var expr : _Expr
	func _to_string() -> String: return "assign " + str(target) + " " + op
	func get_children() -> Array[_ASTNode]: return [expr]
