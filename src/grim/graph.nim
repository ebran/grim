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

template nodes*(self: Graph, labels: untyped = newSeq[string](),
    filter: untyped = true): (iterator: Node) =
  ## Return iterator for nodes with `labels` in graph, conditioned on `filter`.
  # Empty `labels` means use all labels
  let markers =
    when type(labels) is string:
      @[labels]
    else:
      if labels.len == 0:
        self.nodeLabels
      else:
        @labels

  # Create closure iterator for nodes
  iterator it: Node {.closure, gensym.} =
    for label in markers:
      if label notin self.nodeLabels:
        continue
      for n in self.nodeIndex[label].values:
        let node {.inject, used.} = n.toMap
        if filter:
          yield n
  
  it

template edges*(self: Graph, labels: untyped = newSeq[string](),
    filter: untyped = true): (iterator: Edge) =
  ## Return iterator for edges with `labels` in graph, conditioned on `filter`.
  # Empty `labels` means use all labels
  let markers =
    when type(labels) is string:
      @[labels]
    else:
      if labels.len == 0:
        self.edgeLabels
      else:
        @labels

  # Create closure iterator for edges
  iterator it: Edge {.closure, gensym.} =
    for label in markers:
      if label notin self.edgeLabels:
        continue
      for e in self.edgeIndex[label].values:
        let edge {.inject, used.} = e.toMap
        if filter:
          yield e

  it

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

proc addNode*(self: Graph, label: string, data: Table[string,
    Box] = initTable[string, Box](), oid: string = $genOid()): string =
  ## Add node to graph.
  let n = newNode(label, data = data, oid = oid)

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
    data: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): string =
  ## Add edge to graph
  # Add nodes to graph if not already there
  if A notin self:
    discard self.addNode(A)
  if B notin self:
    discard self.addNode(B)

  # Add edge A -> B
  let e = newEdge(A, B, label, data = data, oid = oid)

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
  data: Table[string, Box] = initTable[string, Box](),
      oid: string = $genOid()): string =
  ## Add edge to graph.
  let e = newEdge(self.nodeTable[A], self.nodeTable[B], label,
      data = data, oid = oid)

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

template neighbors*(self: Graph, oid: string, filter: untyped = true, direction: Direction = Direction.Out): (
        iterator: string) =
  ## Return neighbors to node `oid` in graph `g`, in `direction`, conditioned on `filter`.
  iterator it: string {.closure, gensym.} =
    for n_oid in self.nodeTable[oid].neighbors(direction):
      let node {.inject, used.} = self.nodeTable[n_oid].toMap
      if filter:
        yield n_oid

  it

template edgesBetween*(self: Graph, A: string, B: string,  filter: untyped = true, direction: Direction = Direction.Out): (iterator: Edge) =
  ## Iterator for all edges between nodes `A` and `B` in `direction`, conditioned on `filter`.
  iterator it: Edge {.closure, gensym.} =
    if A in self and B in self:
      for e in between(self.nodeTable[A], self.nodeTable[B], direction):
        let edge {.inject, used.} = e.toMap
        if filter:
          yield e

  it

proc node*(self: Graph, node: string): Node =
  ## Return node with `oid` in graph
  result = self.nodeTable[node]

proc edge*(self: Graph, edge: string): Edge =
  ## Return edge with `oid` in graph
  result = self.edgeTable[edge]

proc hasEdge*(self: Graph, A: string, B: string,
    direction: Direction = Direction.Out): bool =
  ## Check if there is an edge between nodes `A` and `B` in `direction` in the graph.
  if A notin self or B notin self:
    return false

  return self.nodeTable[A].connected(self.nodeTable[B], direction = direction)

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

  var 
    edgesToDelete: seq[string]
    ok: bool

  # Delete all edges that node is involved in.
  # Need seqs because we can not modify iterators in-place
  for n_oid in self.neighbors(oid, direction = Direction.OutIn):
    for e in self.edgesBetween(oid, n_oid, filter=true, direction=Direction.OutIn):
      edgesToDelete.add(e.oid)

  for e_oid in edgesToDelete:      
      ok = self.delEdge(e_oid)

  result = ok

  # Delete node from nodeTable and nodeIndex
  let node = self.nodeTable[oid]
  self.nodeTable.del(node.oid)
  self.nodeIndex[node.label].del(node.oid)

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
    # Count data for node type
    propertyCounter = initCountTable[string]()
    for oid in nodeTable.keys:
      propertyCounter.merge(sequalizeIt(g.node(oid).keys).toCountTable)
    propertyCounter.sort()

    # Pretty-print node data
    info = ""
    for key, value in propertyCounter.pairs:
      info.add("$1 ($2), ".format(key, value))
    if propertyCounter.len > 0:
      # delete trailing comma
      info.delete(info.len-2, info.len)
    info = indent(info.wrapWords(72, false), indentLevel)
    info = info & "\n"

    # Paste label before node data
    info[0..indentLevel-1] = "$1 ($2):".format(label, g.nodeIndex[
        label].len).alignLeft(indentLevel)

    # Horizontal separator
    info.add("-".repeat(lineWidth) & "\n")

    result.add(info)

  # Print edge information
  result.add("EDGES".center(lineWidth) & "\n\n")
  for label, edgeTable in g.edgeIndex.pairs:
    # Count data for edge type
    propertyCounter = initCountTable[string]()
    for oid in edgeTable.keys:
      propertyCounter.merge(sequalizeIt(g.edge(oid).keys).toCountTable)
    propertyCounter.sort()

    # Pretty-print edge data
    info = ""
    for key, value in propertyCounter.pairs:
      info.add("$1 ($2), ".format(key, value))
    if propertyCounter.len > 0:
      # delete trailing comma
      info.delete(info.len-2, info.len)
    info = indent(info.wrapWords(72, false), indentLevel)
    info = info & "\n"

    # Paste label before edge data
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
