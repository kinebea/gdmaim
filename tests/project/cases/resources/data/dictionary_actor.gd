extends Node

class Weapon:
	var damage : int = 2

@export var action_zq : Dictionary = {}
@export var action_last_zq : Dictionary = {}
@export var path_zq : NodePath

var held_weapon := Weapon.new()

func attack_zq() -> int:
	return held_weapon.damage
