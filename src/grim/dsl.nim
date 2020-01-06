import macros
import tables
import strutils
import strformat

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
