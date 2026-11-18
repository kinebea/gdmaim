extends RefCounted

## Every generated name is a valid identifier, also with an empty prefix,
## for which the configuration "fallbacks" exports.

var gn_alpha : int = 1
var gn_beta : int = 2
var gn_gamma : int = 3
var gn_delta : int = 4
var gn_epsilon : int = 5
var gn_zeta : int = 6
var gn_eta : int = 7
var gn_theta : int = 8
var gn_iota : int = 9
var gn_kappa : int = 10
var gn_lambda : int = 11
var gn_mu : int = 12
var gn_nu : int = 13
var gn_xi : int = 14
var gn_omicron : int = 15
var gn_pi : int = 16
var gn_rho : int = 17
var gn_sigma : int = 18
var gn_tau : int = 19
var gn_upsilon : int = 20

func first_half() -> int:
	return gn_alpha + gn_beta + gn_gamma + gn_delta + gn_epsilon + gn_zeta + gn_eta + gn_theta + gn_iota + gn_kappa

func second_half() -> int:
	return gn_lambda + gn_mu + gn_nu + gn_xi + gn_omicron + gn_pi + gn_rho + gn_sigma + gn_tau + gn_upsilon

func scaled(gn_factor : int) -> int:
	var gn_total : int = first_half() + second_half()
	return gn_total * gn_factor

func run_case() -> String:
	return "ok" if scaled(2) == 420 else "sum"
