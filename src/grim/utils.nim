# stdlib imports
import os
import sequtils
import strutils

template sequalizeIt*(it: untyped): untyped =
  ## Create sequence from iterator.
  when compiles(toSeq(items(it))):
    toSeq(items(it))
  elif compiles(toSeq(it)):
    toSeq(it)

proc getEnvOrRaise*(env: string): string =
  ## Return environment variable or raise ValueError if not defined.
  if not os.existsEnv(env):
    raise newException(ValueError, "Environment variable $1 is not defined.".format(env))
  result = os.getEnv(env)
