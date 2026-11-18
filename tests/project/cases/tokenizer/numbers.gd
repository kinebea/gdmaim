extends RefCounted

## A number literal ends where its syntax ends.
## `10-extra` used to be one literal, so `extra` was never renamed.

func subtract(count : int) -> int:
	var extra : int = 2
	return 10-extra+count

func mixed(amount : float, flag : int) -> Array:
	var edge : float = 0.5
	var bits : int = 0xF0|flag
	var tiny : float = 1e-3
	var big : float = 2.5e2+amount
	var grouped : int = 1_000-flag
	var whole : float = 3.-edge
	return [1.5-edge, bits, tiny, big, grouped, whole, 0b101+flag, 7.0/amount, 1.5e+2-amount]

func run_case() -> String:
	if subtract(1) != 9:
		return "subtract wrong"
	var got : Array = mixed(2.0, 1)
	var want : Array = [1.0, 241, 0.001, 252.0, 999, 2.5, 6, 3.5, 148.0]
	if got != want:
		return "mixed wrong: " + str(got)
	return "ok"
