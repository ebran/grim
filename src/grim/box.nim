# stdlib imports
import strutils

# 3:rd party imports
from yaml import guessType, TypeHint

type
  BoxKind* = enum
    bxNull,
    bxInt,
    bxFloat,
    bxBool,
    bxStr

  Box* = object
    case kind: BoxKind
    of bxInt: intVal: BiggestInt
    of bxStr: strVal: string
    of bxFloat: floatVal: float
    of bxBool: boolVal: bool
    of bxNull: discard

proc `$`(bx: BoxKind): string =
  case bx:
    of bxInt:
      result = "integer"
    of bxStr:
      result = "string"
    of bxFloat:
      result = "float"
    of bxBool:
      result = "boolean"
    of bxNull:
      result = "empty"

proc `$`*(b: Box): string =
  case b.kind:
    of bxInt:
      result = $b.intVal
    of bxStr:
      result = $b.strVal
    of bxFloat:
      result = $b.floatVal
    of bxBool:
      result = $b.boolVal
    of bxNull:
      discard

proc describe*(b: Box): string =
  result = " (" & $b.kind & ")"
  case b.kind:
    of bxInt:
      result = $b.intVal & result
    of bxStr:
      result = $b.strVal & result
    of bxFloat:
      result = $b.floatVal & result
    of bxBool:
      result = $b.boolVal & result
    of bxNull:
      discard

proc initBox*(): Box =
  ## Init an empty Box
  result = Box(kind: bxNull)

proc initBox*(value: BiggestInt): Box =
  ## Init a new integer Box
  result = Box(kind: bxInt, intVal: value)

proc initBox*(value: string): Box =
  ## Init a new String Box
  result = Box(kind: bxStr, strVal: value)

proc initBox*(value: float): Box =
  ## Init a new float Box
  result = Box(kind: bxFloat, floatVal: value)

proc initBox*(value: bool): Box =
  ## Init a new boolean Box
  result = Box(kind: bxBool, boolVal: value)

proc guessBox*(s: string): Box =
  ## Return Box corresponding to (guessed) type contained in string
  case s.guessType:
    of yTypeInteger:
      initBox(s.parseBiggestInt)
    of yTypeFloat:
      initBox(s.parseFloat)
    of yTypeBoolFalse:
      initBox(false)
    of yTypeBoolTrue:
      initBox(true)
    of yTypeNull:
      initBox()
    else:
      initBox(s)

proc getStr*(b: Box): string =
  result = b.strVal

proc getStr*(b: Box, default: string): string =
  result = default

proc getInt*(b: Box): BiggestInt =
  result = b.intVal

proc getInt*(b: Box, default: BiggestInt): BiggestInt =
  result = default

proc getFloat*(b: Box): float =
  result = b.floatVal

proc getFloat*(b: Box, default: float): float =
  result = default

proc getBool*(b: Box): bool =
  result = b.boolVal

proc getBool*(b: Box, default: bool): bool =
  result = default

proc isEmpty*(b: Box): bool =
  ## Check if Box is empty
  result = b.kind == bxNull

proc update*(b: var Box, value: BiggestInt) =
  ## Update value in integer box
  b.intVal = value

proc update*(b: var Box, value: float) =
  ## Update value in float box
  b.floatVal = value

proc update*(b: var Box, value: string) =
  ## Update value in string box
  b.strVal = value

proc update*(b: var Box, value: bool) =
  ## Update value in boolean box
  b.boolVal = value

proc `==`*(self, other: Box): bool =
  ## Check whether two boxes have the same content
  if self.kind != other.kind:
    return false

  case self.kind:
    of bxInt:
      return self.intVal == other.intVal
    of bxStr:
      return self.strVal == other.strVal
    of bxFloat:
      return self.floatVal == other.floatVal
    of bxBool:
      return self.boolVal == other.boolVal
    of bxNull:
      return true
