# stdlib imports
import tables
import strformat
import strutils
import oids

from std/wordwrap import wrapWords

# grim imports
import grim/box

type
  ## Unique string representing an entity -- node or edge
  EntityOid* = string

  ## Edge direction
  Direction* {.pure.} = enum
    In, Out, OutIn

  ## Edge entity
  Edge* = ref object
    oid*: EntityOid
    label*: string
    startsAt*: Node
    endsAt*: Node
    properties: Table[string, Box]

  ## Node entity
  Node* = ref object
    oid*: EntityOid
    label*: string
    properties: Table[string, Box]
    incoming: Table[EntityOid, Table[EntityOid, Edge]]
    outgoing: Table[EntityOid, Table[EntityOid, Edge]]

proc newNode*(label: string, properties: Table[string, Box] = initTable[string,
Box](), oid: string = $genOid()): Node =
  ## Create a new node
  new result

  result.label = label
  result.properties = properties
  result.oid = oid

proc newEdge*(A: Node, B: Node, label: string,
    properties: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): Edge =
  ## Create a new edge
  new result

  result.startsAt = A
  result.endsAt = B
  result.label = label
  result.properties = properties
  result.oid = oid

  # Modify nodes' adjacency tables
  discard A.outgoing
  .mgetOrPut(B.oid, initTable[EntityOid, Edge]())
  .mgetOrPut(result.oid, result)

  discard B.incoming
  .mgetOrPut(A.oid, initTable[EntityOid, Edge]())
  .mgetOrPut(result.oid, result)

proc delete*(e: Edge) =
  ## Delete an edge
  let
    A = e.startsAt
    B = e.endsAt

  # Modify nodes' adjacency tables
  A.outgoing[B.oid].del(e.oid)
  B.incoming[A.oid].del(e.oid)

  # Delete tables if empty
  if A.outgoing[B.oid].len == 0:
    A.outgoing.del(B.oid)
  if B.incoming[A.oid].len == 0:
    B.incoming.del(A.oid)

proc `==`*(self, other: Node): bool =
  ## Check if two Nodes are equal
  result = (self.oid == other.oid)

proc `==`*(self, other: Edge): bool =
  ## Check if two Edges are equal
  result = (self.oid == other.oid)

proc `[]`*(node: Node, property: string): Box =
  ## Get `property` of `node`
  result = node.properties[property]

proc `[]=`*(node: Node, property: string, value: Box) =
  ## Set `property` of `node` to `value`
  node.properties[property] = value

proc `[]`*(edge: Edge, property: string): Box =
  ## Get `property` of `edge`
  result = edge.properties[property]

proc `[]=`*(edge: Edge, property: string, value: Box) =
  ## Set `property` of `edge` to `value`
  edge.properties[property] = value

proc len*[T: Node | Edge](entity: T): int =
  ## Return number of properties of node or edge
  result = entity.properties.len

proc numberOfNeighbors*(n: Node, direction: Direction = Direction.Out): int =
  ## Return the number of neighbors of node `n` in `direction`.
  let choices = {
    Direction.Out: n.outgoing.len,
    Direction.In: n.incoming.len,
    Direction.OutIn: n.outgoing.len + n.incoming.len
  }.toTable

  return choices[direction]

iterator pairs*[T: Node | Edge](obj: T): (string, Box) {.closure.} =
  ## Iterate over property pairs
  for property, value in obj.properties.pairs:
    yield (property, value)

iterator keys*[T: Node | Edge](obj: T): string {.closure.} =
  ## Iterate over property keys
  for property in obj.properties.keys:
    yield property

iterator values*[T: Node | Edge](obj: T): Box {.closure.} =
  ## Iterate over property values
  for value in obj.properties.values:
    yield value

proc update*[T](self: T, p: Table[string, Box]): string =
  ## Update node or edge properties
  for prop, val in p.pairs:
    self[prop] = val

  result = self.oid

proc neighbors*(n: Node, direction: Direction = Direction.Out): (
    iterator: string) =
  ## Return neighbors to `n` counting edges with `direction`.
  # Create closure iterator for neighbors
  iterator outgoingIt: string {.closure.} =
    for oid in n.outgoing.keys:
      yield oid

  iterator incomingIt: string {.closure.} =
    for oid in n.incoming.keys:
      yield oid

  iterator bothIt: string {.closure.} =
    for oid in n.outgoing.keys:
      yield oid
    for oid in n.incoming.keys:
      yield oid

  let choices = {Direction.Out: outgoingIt, Direction.In: incomingIt,
      Direction.OutIn: bothIt}.toTable
  return choices[direction]

proc edges*(n: Node, direction: Direction = Direction.Out): (
    iterator: Edge) =
  ## Iterator over node edges
  # Create closure iterator for edges
  iterator outgoingIt: Edge {.closure.} =
    for n_oid, edgeTable in n.outgoing.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e

  iterator incomingIt: Edge {.closure.} =
    for n_oid, edgeTable in n.incoming.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e

  iterator bothIt: Edge {.closure.} =
    for n_oid, edgeTable in n.outgoing.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e
    for n_oid, edgeTable in n.incoming.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e

  let choices = {Direction.Out: outgoingIt, Direction.In: incomingIt,
      Direction.OutIn: bothIt}.toTable
  return choices[direction]

proc between*(A, B: Node, direction: Direction = Direction.Out): (
    iterator: Edge) =
  ## Iterator for all edges between nodes `A` and `B` in `direction`.

  let
    # Outgoing edges between A and B
    outgoing = A
      .outgoing
      .getOrDefault(B.oid, initTable[EntityOid, Edge]())

    # Incoming edges between A and B
    incoming = A
      .incoming
      .getOrDefault(B.oid, initTable[EntityOid, Edge]())

  # Create closure iterators for edges between A and B
  iterator outgoingIt: Edge {.closure.} =
    for e in outgoing.values:
      yield e

  iterator incomingIt: Edge {.closure.} =
    for e in incoming.values:
      yield e

  iterator bothIt: Edge {.closure.} =
    for e in outgoing.values:
      yield e
    for e in incoming.values:
      yield e

  let choices = {Direction.Out: outgoingIt, Direction.In: incomingIt,
      Direction.OutIn: bothIt}.toTable

  return choices[direction]

proc connected*(A, B: Node, direction: Direction = Direction.Out): bool =
  ## Check if `first` and `second`` node` is connected with an edge.
  let
    isOutgoing = B.oid in A.outgoing and A.oid in B.incoming
    isIncoming = B.oid in A.incoming and A.oid in B.outgoing

    choices = {
      Direction.Out: isOutgoing,                # from `first` to `second`
      Direction.In: isIncoming,                 # from `second` to `first`
      Direction.OutIn: isOutgoing or isIncoming # either direction
    }.toTable

  result = choices[direction]

proc `$`*(n: Node): string =
  ## Pretty-print Node
  result = fmt("[Node {n.label} \"{n.oid}\"]")

proc `$`*(e: Edge): string =
  ## Pretty-print Edge
  result = fmt("[Edge {e.label} (\"{e.startsAt.oid}\" => \"{e.endsAt.oid}\") \"{e.oid}\"]")

proc describe*(e: Edge, lineWidth: int = 100,
    propertyWidth: int = 20): string =
  ## Return a nice pretty-printed summary of edge `e`
  # Edge header
  result.add(fmt("{e.label} (\"{e.startsAt.oid}\" => \"{e.endsAt.oid}\") \"{e.oid}\"") & "\n")
  result.add("=".repeat(lineWidth) & "\n")

  # Pretty-print properties
  for prop, val in e.pairs:
    result.add(prop.alignLeft(propertyWidth, '.')[
        0..propertyWidth-1] & " ")

    let desc = wrapWords($val, 72, false).indent(propertyWidth+1)[
        propertyWidth+1..^1]
    result.add(desc & "\n")

  if e.len == 0:
    result.add("No properties")

  result.add("\n")

proc describe*(n: Node, lineWidth: int = 100,
    propertyWidth: int = 20): string =
  ## Return a nice pretty-printed summary of node `n`
  # Node header
  result.add(fmt("{n.label} \"{n.oid}\"") & "\n")
  result.add("=".repeat(lineWidth) & "\n")

  # Pretty-print properties
  for prop, val in n.pairs:
    result.add(prop.alignLeft(propertyWidth, '.')[
        0..propertyWidth-1] & " ")

    let desc = wrapWords($val, 72, false).indent(propertyWidth+1)[
        propertyWidth+1..^1]
    result.add(desc & "\n")

  if n.len == 0:
    result.add("No properties")

  result.add("\n")
