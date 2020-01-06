
import macros
import tables
import oids
import sets
import strformat
import strutils
export tables

type
  BoxKind = enum
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

proc `$`*(t: Table[string, Box]): string =
  result.add("{")
  for key, val in t.pairs:
    result.add(key & ": " & $val & ", ")
  result.delete(result.len-2, result.len)
  result.add("}")

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

proc getStr*(b: Box, default = ""): string =
  result =
    if b.kind == bxStr:
      b.strVal
    else:
      default

proc getInt*(b: Box, default = 0): BiggestInt =
  result =
    if b.kind == bxInt:
      b.intVal
    else:
      default

proc getFloat*(b: Box, default = 0.0): float =
  result =
    if b.kind == bxFloat:
      b.floatVal
    else:
      default

proc getBool*(b: Box, default = false): bool =
  result =
    if b.kind == bxBool:
      b.boolVal
    else:
      default

proc len*(t: tuple): int =
  for _ in t.fields:
    result.inc

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

proc toPropertyString(statements: NimNode): string =
  ## Helper proc to parse properties as string
  expectKind(statements, nnkStmtList)
  result.add("%(")

  for node in statements:
    expectKind(node, nnkCall)

    let label = node[0].strVal
    let value = node[1][0]

    result.add(label & ": ")
    case value.kind:
      of nnkStrLit:
        result.add("\"" & value.strVal & "\"")
      of nnkIntLit:
        result.add($value.intVal)
      else:
        discard
    result.add(", ")
  result.delete(result.len-2, result.len)
  result.add(")")

macro graph*(varName: untyped, statements: untyped): untyped =
  ## Macro to build graph with DSL
  expectKind(varName, nnkCommand)
  result = newStmtList()

  # Parse graph variable and name
  let
    g = varName[0].strVal
    name = varName[1].strVal
    newGraphString = "var " & g & " = newGraph(\"" & name & "\")"

  # Create empty graph
  result.add(newGraphString.parseExpr)

  # Find sections for nodes and edges
  expectKind(statements, nnkStmtList)
  var indices = initTable[string, int]()
  for i, st in statements.pairs:
    if st.len > 0:
      indices[st[0].strVal] = i
  let
    nodes = statements[indices["nodes"]][1]
    edges = statements[indices["edges"]][1]

  # Parse nodes first
  expectKind(nodes, nnkStmtList)
  for nodeKind in nodes:
    expectKind(nodeKind[1], nnkStmtList)

    let nodeLabel = nodeKind[0].strVal

    for node in nodeKind[1]:
      let
        oid =
          if node.len == 0:
            node.strVal
          else:
            node[0].strVal

        properties =
          if node.len == 0:
            ""
          else:
            node[1].toPropertyString & ","

        addNodeString = fmt("discard {g}.addNode(\"{nodeLabel}\", {properties} ident=\"{oid}\")")

      # Add nodes to graph
      result.add(addNodeString.parseExpr)

  # Parse edges next
  expectKind(edges, nnkStmtList)
  for op in edges:
    expectKind(op, nnkInfix)
    expectKind(op[3], nnkStmtList)
    doAssert(op[0].strVal == "->")

    let
      oidA = op[1]
      oidB = op[2]
      edgeLabel = op[0].strVal

    for rel in op[3]:
      let
        edgeLabel =
          if rel.len == 0:
            rel.strVal
          else:
            rel[0].strVal

        properties =
          if rel.len == 0:
            ""
          else:
            ", props = " & rel[1].toPropertyString

        addEdgeString = fmt("discard {g}.addEdge(\"{oidA}\", \"{oidB}\", \"{edgeLabel}\"{properties})")

      # Add edges to graph
      result.add(addEdgeString.parseExpr)
