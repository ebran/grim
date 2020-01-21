# Standard library imports
import tables
import strutils
import sets
import oids
import strformat

# grim modules
import box

type
  Edge = ref object
    oid*: string
    label*: string
    startsAt*: Node
    endsAt*: Node
    properties*: Table[string, Box]

  Node* = ref object
    oid*: string
    label*: string
    properties*: Table[string, Box]
    adj: Table[string, Edge]

  Graph* = ref object
    name*: string
    nodeTable: Table[string, Node]
    edgeTable: Table[string, Edge]

proc numberOfNodes*(self: var Graph): int =
  ## Return number of Nodes in Graph
  result = self.nodeTable.len

proc numberOfEdges*(self: var Graph): int =
  ## Return number of Edges in Graph
  result = self.edgeTable.len

iterator nodes*(self: var Graph): Node =
  ## Iterator for all nodes in graph
  for n in self.nodeTable.values:
    yield n

iterator edges*(self: var Graph): Edge =
  ## Iterator for all edges in graph
  for e in self.edgeTable.values:
    yield e

proc `$`*(self: var Graph): string =
  ## Pretty-print Graph
  let
    m = self.name
    i = self.numberOfNodes
    j = self.numberOfEdges

  var nodeStats = initCountTable[string]()
  var edgeStats = initCountTable[string]()
  for n in self.nodes:
    nodeStats.inc(n.label)
  for e in self.edges:
    edgeStats.inc(e.label)

  result = fmt("<Graph \"{m}\" with {i} node(s) {nodeStats} and {j} edge(s) {edgeStats}>")

proc `$`*(t: Table[string, Box]): string =
  ## Pretty-print String table with Boxes
  result.add("{")
  for key, val in t.pairs:
    result.add(key & ": " & val.describe & ", ")
  result.delete(result.len-2, result.len)
  result.add("}")

proc `$`*(n: Node): string =
  ## Pretty-print Node
  result = fmt"<Node {n.oid} ({n.label}): {n.properties}>"

proc `$`*(e: Edge): string =
  ## Pretty-print Edge
  result = fmt"<Edge {e.oid}: {e.startsAt.oid} -- {e.label} {e.properties} --> {e.endsAt.oid}>"

proc `%`*(t: tuple): Table[string, Box] =
  ## Convert tuple to Table[string, Box]
  for label, value in t.fieldPairs:
    result[label] = initBox(value)

proc contains*(self: var Graph, key: string): bool =
  ## Check if Node or Edge oid is in Graph
  result = key in self.nodeTable or key in self.edgeTable

proc contains*(self: var Graph, key: Node): bool =
  ## Check if Node object is in Graph
  result = key.oid in self.nodeTable

proc contains*(self: var Graph, key: Edge): bool =
  ## Check if Edge object is in Graph
  result = key.oid in self.edgeTable

proc `==`*(self, other: Node): bool =
  ## Check if two Nodes are equal
  result = self.oid == other.oid

proc `==`*(self, other: Edge): bool =
  ## Check if two Edges are equal
  result = self.oid == other.oid

proc newGraph*(name: string = "graph"): Graph =
  ## Create a new graph
  new result

  result.name = name

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

proc addNode*(self: Graph, label: string, props: Table[string,
    Box] = initTable[string, Box](), oid: string = $genOid()): string =
  ## Add node to graph.
  let n = newNode(label, properties = props, oid = oid)

  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  result = n.oid

proc addNode*(self: var Graph, n: Node): string =
  ## Add node to graph.
  # Don't add if node already in graph
  if n in self:
    return n.oid

  self.nodeTable[n.oid] = n
  result = n.oid

proc addEdge*(self: var Graph, e: Edge): string =
  ## Add edge to graph.
  # Don't add if edge already in graph
  if e in self:
    return e.oid

  self.nodeTable[e.startsAt.oid].adj.add(e.endsAt.oid, e)
  self.edgeTable[e.oid] = e

proc addEdge*(self: var Graph, A: Node, B: Node, label: string,
    props: Table[string, Box] = initTable[string, Box](),
        oid: string = $genOid()): string =
  ## Add edge to graph
  # Add nodes to graph if not already there
  if A notin self:
    discard self.addNode(A)
  if B notin self:
    discard self.addNode(B)

  let e = newEdge(A, B, label, properties = props, oid = oid)

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge to edges and to adjancy lists
  self.nodeTable[A.oid].adj.mgetOrPut(B.oid, newSeq[Edge]()).add(e)
  self.nodeTable[B.oid].adj.mgetOrPut(A.oid, newSeq[Edge]()).add(e)
  self.edgeTable[e.oid] = e
  self.edgeIndex.mgetOrPut(e.label, newSeq[string]()).add(e.oid)

  result = e.oid

proc addEdge*(self: Graph, A: string, B: string, label: string,
  props: Table[string, Box] = initTable[string, Box](), oid: string = $genOid()): string =
  ## Add edge to graph.
  let e = newEdge(self.nodeTable[A], self.nodeTable[B], label,
      properties = props, oid = oid)

  # Don't add if edge already in graph
  if e in self:
    return e.oid

  # Add edge to edges and to adjancy lists
  self.nodeTable[A].adj.add(B, e)
  self.nodeTable[B].adj.add(A, e)
  self.edgeTable[e.oid] = e

  result = e.oid

proc update*[T](self: var T, p: Table[string, Box]): string =
  ## Update node or edge properties
  for prop, val in p.pairs:
    self.properties[prop] = val

  result = self.oid

proc hasEdge*(self: var Graph, A: string, B: string): bool =
  ## Check if there is an edge between nodes A and B.
  result = A in self.nodeTable and B in self.nodeTable[A].adj

proc getNode*(self: var Graph, node: string): var Node =
  ## Return oid for `node` in graph
  result = self.nodeTable[node]

proc getEdge*(self: var Graph, edge: string): var Edge =
  ## Return oid for `egde` in graph
  result = self.edgeTable[edge]

iterator neighbors*(self: Node): string =
  ## Return neighbors to node `n`.
  var seen: HashSet[string]
  for e in self.adj.values:
    let
      a = e.startsAt.oid
      b = e.endsAt.oid

    if a notin seen and a != self.oid:
      yield a
    if b notin seen and b != self.oid:
      yield b

    seen.incl(a)
    seen.incl(b)

iterator neighbors*(self: var Graph, n: string): string =
  ## Return neighbors to node `n` in graph `g`.
  for n in self.nodeTable[n].neighbors:
    yield n

iterator getEdges*(self: var Graph, A: string, B: string): Edge =
  ## Iterator for all edges between `A` and `B`.
  for e in self.nodeTable[A].adj.allValues(B):
    yield e
