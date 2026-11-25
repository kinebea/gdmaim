extends RefCounted

## Compiles, and fails when it runs: twice in start_engine(). main.gd only runs it with the feature
## tag `crash`. The configurations with that tag have the log of the game translated, which has to
## name the functions, the variable and the lines of this file.

var fuel_level : int = 3

class Engine_part:
	var part_name : String = "piston"

	func heat_up(degrees : int) -> int:
		var missing_sensor = null
		return missing_sensor.read_temperature(degrees)

func drain_fuel(amount : int) -> int:
	var tank = RefCounted.new()
	return tank.fuel_level - amount

func start_engine() -> int:
	var part := Engine_part.new()
	return part.heat_up(fuel_level) + drain_fuel(1)
