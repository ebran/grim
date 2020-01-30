# Standard library imports
import tables
import strutils
import sequtils
import sugar
import sets
import oids
import strformat
import db_sqlite

from std/wordwrap import wrapWords

# grim modules
import box
import utils

type
  GrimNodeOid = string
  GrimEdgeOid = string

  GrimDirectionKind* = enum
    gdIn,
    gdOut,
    gdOutIn

  GrimEdge = ref object
    oid*: GrimEdgeOid
    label*: string
    startsAt*: GrimNode
    endsAt*: GrimNode
    properties: Table[string, Box]

  GrimNode* = ref object
    oid*: GrimNodeOid
    label*: string
    properties: Table[string, Box]
    incoming: Table[GrimNodeOid, Table[GrimEdgeOid, GrimEdge]]
    outgoing: Table[GrimNodeOid, Table[GrimEdgeOid, GrimEdge]]

  Graph* = ref object
    name*: string
    nodeTable: Table[GrimNodeOid, GrimNode]
    edgeTable: Table[GrimEdgeOid, GrimEdge]
    nodeIndex: Table[string, Table[GrimNodeOid, GrimNode]]
    edgeIndex: Table[string, Table[GrimEdgeOid, GrimEdge]]

proc numberOfNodes*(self: Graph): int =
  ## Return number of Nodes in Graph
  result = self.nodeTable.len

proc numberOfEdges*(self: Graph): int =
  ## Return number of Edges in Graph
  result = self.edgeTable.len

proc nodeLabels*(self: Graph): seq[string] =
  ## Return all node labels in the graph
  for label in self.nodeIndex.keys:
    result.add(label)

proc edgeLabels*(self: Graph): seq[string] =
  ## Return all edge labels in the graph
  for label in self.edgeIndex.keys:
    result.add(label)

proc nodes*(self: Graph, labels: varargs[string]): (iterator: GrimNode) =
  ## Return iterator for nodes with `labels` in graph
  # Empty `labels` means use all labels
  let markers =
    if labels.len == 0:
      self.nodeLabels
    else:
      @labels

  # Create closure iterator for nodes
  iterator it: GrimNode {.closure.} =
    for label in markers:
      if label notin self.nodeLabels:
        continue
      for node in self.nodeIndex[label].values:
        yield node

  return it

proc edges*(self: Graph, labels: varargs[string]): (
    iterator: GrimEdge) =
  ## Return iterator for edges with `labels` in graph
  # Empty `labels` means use all labels
  let markers =
    if labels.len == 0:
      self.edgeLabels
    else:
      @labels

  # Create closure iterator for edges
  iterator it: GrimEdge {.closure.} =
    for label in markers:
      if label notin self.edgeLabels:
        continue
      for e in self.edgeIndex[label].values:
        yield e

  return it

proc `$`*(self: Graph): string =
  ## Pretty-print Graph
  let
    m = self.name
    i = self.numberOfNodes
    j = self.numberOfEdges

  var
    nodeStats, edgeStats: Table[string, int]

  for label, nodeTable in self.nodeIndex.pairs:
    nodeStats[label] = nodeTable.len
  for label, edgeTable in self.edgeIndex.pairs:
    edgeStats[label] = edgeTable.len

  result = fmt("<Graph \"{m}\" with {i} node(s) {nodeStats} and {j} edge(s) {edgeStats}>")

proc `$`*(t: Table[string, Box]): string =
  ## Pretty-print String table with Boxes
  result.add("{")
  for key, val in t.pairs:
    result.add(key & ": " & val.describe & ", ")
  if t.len > 0:
    # Delete trailing comma
    result.delete(result.len-2, result.len)
  result.add("}")

proc `$`*(n: GrimNode): string =
  ## Pretty-print Node
  result = fmt("<Node {n.label} \"{n.oid}\">")

proc `$`*(e: GrimEdge): string =
  ## Pretty-print Edge
  result = fmt("<Edge {e.label} (\"{e.startsAt.oid}\" => \"{e.endsAt.oid}\") \"{e.oid}\">")

proc `%`*(t: tuple): Table[string, Box] =
  ## Convert tuple to Table[string, Box]
  for label, value in t.fieldPairs:
    result[label] = initBox(value)

proc contains*(self: Graph, key: string): bool =
  ## Check if Node or Edge oid is in Graph
  result = key in self.nodeTable or key in self.edgeTable

proc contains*(self: Graph, key: GrimNode): bool =
  ## Check if Node object is in Graph
  result = key.oid in self.nodeTable

proc contains*(self: Graph, key: GrimEdge): bool =
  ## Check if Edge object is in Graph
  result = key.oid in self.edgeTable

proc `==`*(self, other: GrimNode): bool =
  ## Check if two Nodes are equal
  result = self.oid == other.oid

proc `==`*(self, other: GrimEdge): bool =
  ## Check if two Edges are equal
  result = self.oid == other.oid

proc `[]`*(node: GrimNode, property: string): Box =
  ## Get `property` of `node`
  result = node.properties[property]

proc `[]=`*(node: GrimNode, property: string, value: Box) =
  ## Set `property` of `node` to `value`
  node.properties[property] = value

proc `[]`*(edge: GrimEdge, property: string): Box =
  ## Get `property` of `edge`
  result = edge.properties[property]

proc `[]=`*(edge: GrimEdge, property: string, value: Box) =
  ## Set `property` of `edge` to `value`
  edge.properties[property] = value

proc len*[T: GrimNode | GrimEdge](obj: T): int =
  ## Return number of properties of node or edge
  result = obj.properties.len

iterator pairs*[T: GrimNode | GrimEdge](obj: T): (string, Box) {.closure.} =
  ## Iterate over property pairs
  for property, value in obj.properties.pairs:
    yield (property, value)

iterator keys*[T: GrimNode | GrimEdge](obj: T): string {.closure.} =
  ## Iterate over property keys
  for property in obj.properties.keys:
    yield property

iterator values*[T: GrimNode | GrimEdge](obj: T): Box {.closure.} =
  ## Iterate over property values
  for value in obj.properties.values:
    yield value

proc newGraph*(name: string = "graph"): Graph =
  ## Create a new graph
  new result

  result.name = name

proc newNode*(label: string, properties: Table[string, Box] = initTable[string,
    Box](), oid: string = $genOid()): GrimNode =
  ## Create a new node
  new result

  result.label = label
  result.properties = properties
  result.oid = oid

proc newEdge*(A: GrimNode, B: GrimNode, label: string,
    properties: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): GrimEdge =
  ## Create a new edge
  new result

  result.startsAt = A
  result.endsAt = B
  result.label = label
  result.properties = properties
  result.oid = oid

proc addNode*(self: Graph, label: string, properties: Table[string,
    Box] = initTable[string, Box](), oid: string = $genOid()): string =
  ## Add node to graph.
  let n = newNode(label, properties = properties, oid = oid)

  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  discard self
    .nodeIndex
    .mgetOrPut(label, initTable[GrimNodeOid, GrimNode]())
    .mgetOrPut(n.oid, n)

  result = n.oid

proc addNode*(self: Graph, n: GrimNode): string =
  ## Add node to graph.
  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  discard self
    .nodeIndex
    .mgetOrPut(n.label, initTable[GrimNodeOid, GrimNode]())
    .mgetOrPut(n.oid, n)

  result = n.oid

proc addEdge*(self: Graph, e: GrimEdge): string =
  ## Add edge to graph.
  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge A -> B
  let
    A = e.startsAt
    B = e.endsAt

  # Add B to the outgoing edge list for A
  discard self
    .nodeTable[A.oid].outgoing
    .mgetOrPut(B.oid, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  # Add A to the incoming edge list for  B
  discard self
    .nodeTable[e.endsAt.oid].incoming
    .mgetOrPut(e.startsAt.oid, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  # Add edge to main index and label index
  self.edgeTable[e.oid] = e
  discard self
    .edgeIndex
    .mgetOrPut(e.label, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

proc addEdge*(self: Graph, A: GrimNode, B: GrimNode, label: string,
    properties: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): string =
  ## Add edge to graph
  # Add nodes to graph if not already there
  if A notin self:
    discard self.addNode(A)
  if B notin self:
    discard self.addNode(B)

  # Add edge A -> B
  let e = newEdge(A, B, label, properties = properties, oid = oid)

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add B to the outgoing edge list for A
  discard self
    .nodeTable[A.oid].outgoing
    .mgetOrPut(B.oid, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  # Add A to the incoming edge list for B
  discard self
    .nodeTable[B.oid].incoming
    .mgetOrPut(A.oid, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  # Add edge to main index and label index
  self.edgeTable[e.oid] = e
  discard self
    .edgeIndex
    .mgetOrPut(e.label, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  result = e.oid

proc addEdge*(self: Graph, A: string, B: string, label: string,
  properties: Table[string, Box] = initTable[string, Box](),
      oid: string = $genOid()): string =
  ## Add edge to graph.
  let e = newEdge(self.nodeTable[A], self.nodeTable[B], label,
      properties = properties, oid = oid)

  # Add edge A -> B

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add B to the outgoing edge list for A
  discard self
    .nodeTable[A].outgoing
    .mgetOrPut(B, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  # Add A to the incoming edge list for B
  discard self
    .nodeTable[B].incoming
    .mgetOrPut(A, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  # Add edge to main index and label index
  self.edgeTable[e.oid] = e
  discard self
    .edgeIndex
    .mgetOrPut(e.label, initTable[GrimEdgeOid, GrimEdge]())
    .mgetOrPut(e.oid, e)

  result = e.oid

proc update*[T](self: T, p: Table[string, Box]): string =
  ## Update node or edge properties
  for prop, val in p.pairs:
    self[prop] = val

  result = self.oid

proc neighbors*(n: GrimNode, direction: GrimDirectionKind = gdOut): (
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

  let choices = {gdOut: outgoingIt, gdIn: incomingIt, gdOutIn: bothIt}.toTable
  return choices[direction]

iterator neighbors*(self: Graph, n: string,
    direction: GrimDirectionKind = gdOut): string {.closure.} =
  ## Return neighbors to node oid `n` in graph `g`.
  for n in self.nodeTable[n].neighbors(direction = direction):
    yield n

proc edges*(n: GrimNode, direction: GrimDirectionKind = gdOut): (
    iterator: GrimEdge) =
  ## Iterator over node edges
  # Create closure iterator for edges
  iterator outgoingIt: GrimEdge {.closure.} =
    for n_oid, edgeTable in n.outgoing.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e

  iterator incomingIt: GrimEdge {.closure.} =
    for n_oid, edgeTable in n.incoming.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e

  iterator bothIt: GrimEdge {.closure.} =
    for n_oid, edgeTable in n.outgoing.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e
    for n_oid, edgeTable in n.incoming.pairs:
      for e_oid, e in edgeTable.pairs:
        yield e

  let choices = {gdOut: outgoingIt, gdIn: incomingIt, gdOutIn: bothIt}.toTable
  return choices[direction]

proc edgesBetween*(self: Graph, A: string, B: string,
    direction: GrimDirectionKind = gdOut): (iterator: GrimEdge) =
  ## Iterator for all edges between nodes `A` and `B` in `direction`.
  # Return empty iterator if A or B not in graph
  if A notin self or B notin self:
    return iterator(): GrimEdge {.closure.} = discard

  let
    # Outgoing edges between A and B
    outgoing = self
      .nodeTable[A]
      .outgoing
      .getOrDefault(B, initTable[GrimEdgeOid, GrimEdge]())

    # Incoming edges between A and B
    incoming = self
      .nodeTable[A]
      .incoming
      .getOrDefault(B, initTable[GrimEdgeOid, GrimEdge]())

    # Create closure iterators for edges between A and B
  iterator outgoingIt: GrimEdge {.closure.} =
    for e in outgoing.values:
      yield e

  iterator incomingIt: GrimEdge {.closure.} =
    for e in incoming.values:
      yield e

  iterator bothIt: GrimEdge {.closure.} =
    for e in outgoing.values:
      yield e
    for e in incoming.values:
      yield e

  let choices = {gdOut: outgoingIt, gdIn: incomingIt, gdOutIn: bothIt}.toTable
  return choices[direction]

proc node*(self: Graph, node: string): GrimNode =
  ## Return node with `oid` in graph
  result = self.nodeTable[node]

proc edge*(self: Graph, edge: string): GrimEdge =
  ## Return edge with `oid` in graph
  result = self.edgeTable[edge]

proc delEdge*(self: Graph, oid: string): bool =
  ## Delete edge with `oid` in graph, return true if edge was in graph and false otherwise.
  let
    e = self.edgeTable[oid]
    A = e.startsAt
    B = e.endsAt

  if oid notin self or A notin self or B notin self:
    return false

  # Remove edge from global edgeTable and edgeIndex
  self.edgeTable.del(oid)
  self.edgeIndex[e.label].del(oid)

  # Remove edge from involved nodes' adjacency lists
  A.outgoing[B.oid].del(oid)
  B.incoming[A.oid].del(oid)
  # Delete empty tables if adjacency lsit is empty
  if A.outgoing[B.oid].len == 0:
    A.outgoing.del(B.oid)
  if B.incoming[A.oid].len == 0:
    B.incoming.del(A.oid)

  result = true

proc delNode*(self: Graph, oid: string): bool =
  ## Delete node with `oid` in graph, return true if node was in graph and false otherwise.
  if oid notin self:
    return false

  var ok: bool

  # Delete all edges that node is involved in.
  # Need seqs because we can not modify iterators in-place
  for n in sequalizeIt(self.neighbors(oid)):
    for e in sequalizeIt(self.edgesBetween(oid, n)):
      ok = self.delEdge(e.oid)

  result = ok

  # Delete node from nodeTable and nodeIndex
  let n = self.nodeTable[oid]
  self.nodeTable.del(n.oid)
  self.nodeIndex[n.label].del(n.oid)

proc hasEdge*(self: Graph, A: string, B: string,
    direction: GrimDirectionKind = gdOut): bool =
  ## Check if there is an edge between nodes `A` and `B` in `direction`.
  if A notin self or B notin self:
    return false

  let
    isOutgoing = (B in self.nodeTable[A].outgoing) and (A in self.nodeTable[B].incoming)
    isIncoming = (B in self.nodeTable[A].incoming) and (A in self.nodeTable[B].outgoing)

  case direction:
    of gdOut:
      return isOutgoing
    of gdIn:
      return isIncoming
    of gdOutIn:
      return isOutgoing or isIncoming

proc describe*(e: GrimEdge, lineWidth: int = 100,
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

proc describe*(n: GrimNode, lineWidth: int = 100,
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

proc describe*(g: Graph, lineWidth = 100): string =
  ## Return a nice pretty-printed summary of the graph `g`
  let
    # Longest node and edge labels
    longestNodeLabel = g.nodeLabels.map(x => x.len).foldl(max(a, b))
    longestEdgeLabel = g.edgeLabels.map(x => x.len).foldl(max(a, b))
    # Largest number of digits in node and edges
    longestNodeNumber = ($g.nodeLabels.map(x => g.nodeIndex[x].len).foldl(max(a, b))).len
    longestEdgeNumber = ($g.edgeLabels.map(x => g.edgeIndex[x].len).foldl(max(a, b))).len
    # Longest label and numbers
    longestLabel = max(longestNodeLabel, longestEdgeLabel)
    longestNumber = max(longestNodeNumber, longestEdgeNumber)
    # Calculate indent level
    indentLevel = longestLabel + longestNumber + 4

  var
    line: string
    info: string
    propertyCounter: CountTable[string]

  # Print headers
  line = "Graph \"$1\"".format(g.name)
  result.add("\n" & line.center(lineWidth) & "\n\n")

  # Print node information
  result.add("NODES".center(lineWidth) & "\n\n")
  for label, nodeTable in g.nodeIndex.pairs:
    # Count properties for node type
    propertyCounter = initCountTable[string]()
    for oid in nodeTable.keys:
      propertyCounter.merge(sequalizeIt(g.node(oid).keys).toCountTable)
    propertyCounter.sort()

    # Pretty-print node properties
    info = ""
    for key, value in propertyCounter.pairs:
      info.add("$1 ($2), ".format(key, value))
    if propertyCounter.len > 0:
      # delete trailing comma
      info.delete(info.len-2, info.len)
    info = indent(info.wrapWords(72, false), indentLevel)
    info = info & "\n"

    # Paste label before node properties
    info[0..indentLevel-1] = "$1 ($2):".format(label, g.nodeIndex[
        label].len).alignLeft(indentLevel)

    # Horizontal separator
    info.add("-".repeat(lineWidth) & "\n")

    result.add(info)

  # Print edge information
  result.add("EDGES".center(lineWidth) & "\n\n")
  for label, edgeTable in g.edgeIndex.pairs:
    # Count properties for edge type
    propertyCounter = initCountTable[string]()
    for oid in edgeTable.keys:
      propertyCounter.merge(sequalizeIt(g.edge(oid).keys).toCountTable)
    propertyCounter.sort()

    # Pretty-print edge properties
    info = ""
    for key, value in propertyCounter.pairs:
      info.add("$1 ($2), ".format(key, value))
    if propertyCounter.len > 0:
      # delete trailing comma
      info.delete(info.len-2, info.len)
    info = indent(info.wrapWords(72, false), indentLevel)
    info = info & "\n"

    # Paste label before edge properties
    info[0..indentLevel-1] = "$1 ($2):".format(label, g.edgeIndex[
        label].len).alignLeft(indentLevel)

    # Horizontal separator
    info.add("-".repeat(lineWidth) & "\n")

    result.add(info)
