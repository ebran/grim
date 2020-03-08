# Standard library imports
import tables
import sequtils
import strformat
import strutils
import sugar
import oids

from std/wordwrap import wrapWords

# grim modules
import grim/[entities, box, utils, paths]

type
  ## Labeled property graph
  Graph* = ref object
    name*: string
    nodeTable: Table[EntityOid, Node]
    edgeTable: Table[EntityOid, Edge]
    nodeIndex: Table[string, Table[EntityOid, Node]]
    edgeIndex: Table[string, Table[EntityOid, Edge]]

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

proc nodes*(self: Graph, labels: varargs[string]): (iterator: Node) =
  ## Return iterator for nodes with `labels` in graph
  # Empty `labels` means use all labels
  let markers =
    if labels.len == 0:
      self.nodeLabels
    else:
      @labels

  # Create closure iterator for nodes
  iterator it: Node {.closure.} =
    for label in markers:
      if label notin self.nodeLabels:
        continue
      for node in self.nodeIndex[label].values:
        yield node

  return it

proc edges*(self: Graph, labels: varargs[string]): (
    iterator: Edge) =
  ## Return iterator for edges with `labels` in graph
  # Empty `labels` means use all labels
  let markers =
    if labels.len == 0:
      self.edgeLabels
    else:
      @labels

  # Create closure iterator for edges
  iterator it: Edge {.closure.} =
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

  result = fmt("[Graph \"{m}\" with {i} node(s) {nodeStats} and {j} edge(s) {edgeStats}]")

proc contains*(self: Graph, key: string): bool =
  ## Check if Node or Edge oid is in Graph
  result = key in self.nodeTable or key in self.edgeTable

proc contains*(self: Graph, key: Node): bool =
  ## Check if Node object is in Graph
  result = key.oid in self.nodeTable

proc contains*(self: Graph, key: Edge): bool =
  ## Check if Edge object is in Graph
  result = key.oid in self.edgeTable

proc newGraph*(name: string = "graph"): Graph =
  ## Create a new graph
  new result

  result.name = name

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
    .mgetOrPut(label, initTable[EntityOid, Node]())
    .mgetOrPut(n.oid, n)

  result = n.oid

proc addNode*(self: Graph, n: Node): string =
  ## Add node to graph.
  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  discard self
    .nodeIndex
    .mgetOrPut(n.label, initTable[EntityOid, Node]())
    .mgetOrPut(n.oid, n)

  result = n.oid

proc addEdge*(self: Graph, e: Edge): string =
  ## Add edge to graph.
  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge to main index and label index
  self.edgeTable[e.oid] = e
  discard self
    .edgeIndex
    .mgetOrPut(e.label, initTable[EntityOid, Edge]())
    .mgetOrPut(e.oid, e)

proc addEdge*(self: Graph, A: Node, B: Node, label: string,
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

  # Add edge to main index and label index
  self.edgeTable[e.oid] = e
  discard self
    .edgeIndex
    .mgetOrPut(e.label, initTable[EntityOid, Edge]())
    .mgetOrPut(e.oid, e)

  result = e.oid

proc addEdge*(self: Graph, A: string, B: string, label: string,
  properties: Table[string, Box] = initTable[string, Box](),
      oid: string = $genOid()): string =
  ## Add edge to graph.
  let e = newEdge(self.nodeTable[A], self.nodeTable[B], label,
      properties = properties, oid = oid)

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge to main index and label index
  self.edgeTable[e.oid] = e
  discard self
    .edgeIndex
    .mgetOrPut(e.label, initTable[EntityOid, Edge]())
    .mgetOrPut(e.oid, e)

  result = e.oid

iterator neighbors*(self: Graph, n: string,
    direction: Direction = Direction.Out): string {.closure.} =
  ## Return neighbors to node oid `n` in graph `g`.
  for n in self.nodeTable[n].neighbors(direction = direction):
    yield n

proc edgesBetween*(self: Graph, A: string, B: string,
    direction: Direction = Direction.Out): (iterator: Edge) =
  ## Iterator for all edges between nodes `A` and `B` in `direction`.
  # Return empty iterator if A or B not in graph
  if A notin self or B notin self:
    return iterator(): Edge {.closure.} = discard
  else:
    return between(self.nodeTable[A], self.nodeTable[B], direction = direction)

proc node*(self: Graph, node: string): Node =
  ## Return node with `oid` in graph
  result = self.nodeTable[node]

proc edge*(self: Graph, edge: string): Edge =
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

  # Remove edge from involved nodes' adjacency tables
  e.delete

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
    direction: Direction = Direction.Out): bool =
  ## Check if there is an edge between nodes `A` and `B` in `direction` in the graph.
  if A notin self or B notin self:
    return false

  return self.nodeTable[A].connected(self.nodeTable[B], direction = direction)

proc describe*(g: Graph, lineWidth = 100): string =
  ## Return a nice pretty-printed summary of the graph `g`
  var
    # Longest node and edge labels
    longestNodeLabel: int
    longestEdgeLabel: int
    # Largest number of digits in node and edges
    longestNodeNumber: int
    longestEdgeNumber: int
    # Longest label and numbers
    longestLabel: int
    longestNumber: int
    # Indent level
    indentLevel: int

  if g.nodeLabels.len == 0:
    longestNodeLabel = 0
    longestNodeNumber = 0
  else:
    longestNodeLabel = g.nodeLabels.map(x => x.len).foldl(max(a, b))
    longestNodeNumber = ($g.nodeLabels.map(x => g.nodeIndex[x].len).foldl(max(a, b))).len

  if g.edgeLabels.len == 0:
    longestEdgeLabel = 0
    longestEdgeNumber = 0
  else:
    longestEdgeLabel = g.edgeLabels.map(x => x.len).foldl(max(a, b))
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

proc navigate*(g: Graph, anchor: string): PathCollection =
  ## Navigate paths by pattern matching in graph
  var pc = initPathCollection()
  for node in g.nodes(anchor):
    pc.add(node.newPath)

  result = pc
