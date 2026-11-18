extends RefCounted

## This script is indented with two spaces, whatever the editor is set to.

class Holder:
  var held : int = 2
  func twice() -> int:
    return held * 2

func run_case() -> String:
  var total : int = 0
  for i in 3:
    if i > 0:
      total += i
  if total != 3:
    return "total wrong"
  if Holder.new().twice() != 4:
    return "holder wrong"
  return "ok"
