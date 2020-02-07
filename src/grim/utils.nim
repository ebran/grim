import sequtils

template sequalizeIt*(it: untyped): untyped =
  ## Create sequence from iterator.
  when compiles(toSeq(items(it))):
    toSeq(items(it))
  elif compiles(toSeq(it)):
    toSeq(it)
