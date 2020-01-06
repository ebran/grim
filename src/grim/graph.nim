import tables
import strformat
import strutils
import sets
import oids

import box

type
  Edge = ref object
    oid*: string
    label*: string
    startsAt*: Node
    endsAt*: Node
    properties*: Table[string, Box]

  Node = ref object
    oid*: string
    label*: string
    properties*: Table[string, Box]
    adj: Table[string, Edge]

  Graph = ref object
    name*: string
    nodes*: Table[string, Node]
    edges*: Table[string, Edge]

proc numberOfNodes*(self: Graph): int =
  ## Return number of Nodes in Graph
  result = self.nodes.len

proc numberOfEdges*(self: Graph): int =
  ## Return number of Edges in Graph
  result = self.edges.len

proc `$`*(self: Graph): string =
  ## Pretty-print Graph
  let
    m = self.name
    i = self.numberOfNodes
    j = self.numberOfEdges

  var nodeStats = newCountTable[string]()
  var edgeStats = newCountTable[string]()
  for n in self.nodes.values:
    nodeStats.inc(n.label)
  for e in self.edges.values:
    edgeStats.inc(e.label)

  result = fmt("<Graph \"{m}\" with {i} node(s) {nodeStats} and {j} edge(s) {edgeStats}>")

proc `$`*(n: Node): string =
  ## Pretty-print Node
  result = fmt"<Node {n.oid} ({n.label}): {n.properties}>"

proc `$`*(e: Edge): string =
  ## Pretty-print Edge
  result = fmt"<Edge {e.oid}: {e.startsAt.oid} -- {e.label} {e.properties} --> {e.endsAt.oid}>"

proc `$`*(t: Table[string, Box]): string =
  result.add("{")
  for key, val in t.pairs:
    result.add(key & ": " & $val & ", ")
  result.delete(result.len-2, result.len)
  result.add("}")

proc `%`*(t: tuple): Table[string, Box] =
  for label, value in t.fieldPairs:
    result[label] = initBox(value)

proc contains*(self: Graph, key: string): bool =
  ## Check if Node or Edge oid is in Graph
  result = key in self.nodes or key in self.edges

proc contains*(self: Graph, key: Node): bool =
  ## Check if Node object is in Graph
  result = key.oid in self.nodes

proc contains*(self: Graph, key: Edge): bool =
  ## Check if Edge object is in Graph
  result = key.oid in self.edges

proc newGraph*(name: string = "graph"): Graph =
  ## Create a new Graph
  new result

  result.name = name

proc newNode*(label: string, properties: Table[string, Box] = initTable[string,
    Box](), ident: string = $genOid()): Node =
  ## Create a new Node
  new result

  result.label = label
  result.properties = properties
  result.oid = ident

proc newEdge*(A: Node, B: Node, label: string,
    properties: Table[string, Box] = initTable[string, Box](),
        ident: string = $genOid()): Edge =
  ## Create a new Edge
  new result

  result.startsAt = A
  result.endsAt = B
  result.label = label
  result.properties = properties
  result.oid = ident

proc addNode*(self: var Graph, label: string, props: Table[string,
    Box] = initTable[string, Box](), ident: string = $genOid()): string =
  ## Add Node to Graph.
  let n = newNode(label, properties = props, ident = ident)

  if n in self:
    return n.oid

  self.nodes[n.oid] = n
  result = n.oid

proc addNode*(self: var Graph, n: Node): string =
  ## Add Node to Graph.
  if n in self:
    return n.oid

  self.nodes[n.oid] = n
  result = n.oid

proc addEdge*(self: var Graph, e: Edge): string =
  ## Add Edge to Graph.
  if e in self:
    return e.oid

  self.nodes[e.startsAt.oid].adj.add(e.endsAt.oid, e)
  self.edges[e.oid] = e

proc addEdge*(self: var Graph, A: Node, B: Node, label: string,
    props: Table[string, Box] = initTable[string, Box](),
        ident: string = $genOid()): string =
  ## Add Edge to Graph
  # Add Nodes to Graph if not already there
  if A notin self:
    discard self.addNode(A)
  if B notin self:
    discard self.addNode(B)

  let e = newEdge(A, B, label, properties = props, ident = ident)

  if e in self:
    return e.oid

  self.nodes[A.oid].adj.add(B.oid, e)
  self.nodes[B.oid].adj.add(A.oid, e)
  self.edges[e.oid] = e

  result = e.oid

proc addEdge*(self: var Graph, A: string, B: string, label: string,
  props: Table[string, Box] = initTable[string, Box](), ident: string = $genOid()): string =
  ## Add Edge to Graph.
  let e = newEdge(self.nodes[A], self.nodes[B], label, properties = props, ident = ident)

  if e in self:
    return e.oid

  self.nodes[A].adj.add(B, e)
  self.nodes[B].adj.add(A, e)
  self.edges[e.oid] = e

  result = e.oid

proc update*[T](self: var T, p: Table[string, Box]): string =
  ## Update Node or Edge properties
  for prop, val in p.pairs:
    self.properties[prop] = val

  result = self.oid

proc hasEdge*(self: var Graph, A: string, B: string): bool =
  ## Check if there is an Edge between Nodes A and B.
  result = A in self.nodes and B in self.nodes[A].adj

proc neighbors*(self: Node): HashSet[string] =
  ## Return neighbors to Node `n`. TODO should be iterator
  for e in self.adj.values:
    result.incl(e.startsAt.oid)
    result.incl(e.endsAt.oid)
  result.excl(self.oid)

proc neighbors*(self: Graph, n: string): HashSet[string] =
  ## Return neighbors to Node `n` in Graph `g`. TODO should be iterator
  result = self.nodes[n].neighbors

proc getEdges*(self: Graph, A: string, B: string): seq[Edge] =
  ## Return all edges between `A` and `B`. # TODO should be iterator
  for e in self.nodes[A].adj.allValues(B):
    result.add(e)


