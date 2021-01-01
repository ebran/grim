# To run these tests, simply execute `nimble test`.
import grim
import grim/[dsl, utils]
import tables
import algorithm
import sequtils
import unittest
import zero_functional

suite "Basic usage":
  test "create graph":
    var g = newGraph("Test")

    check:
      g.name == "Test"
      g.numberOfNodes == 0
      g.numberOfEdges == 0

  test "create nodes":
    let
      p1 = newNode("Person", %(name: "John Doe", age: 24), "new guy")
      p2 = newNode("Person", %(name: "Jane Doe", age: 22))

    check:
      p1.label == "Person"
      p1["name"].getStr() == "John Doe"
      p1["age"].getInt() == 24
      p1.oid == "new guy"

      p2.label == "Person"
      p2["name"].getStr() == "Jane Doe"
      p2["age"].getInt() == 22

  test "add node with label":
    var
      g = newGraph("People")
      oid = g.addNode("Person")

    check:
      oid in g
      g.node(oid).label == "Person"
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "add node with label and data":
    var
      g = newGraph("People")
      oid = g.addNode("Person", %(name: "John Doe", age: 24))

    check:
      oid in g
      g.node(oid).label == "Person"
      g.node(oid)["name"].getStr() == "John Doe"
      g.node(oid)["age"].getInt() == 24
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "add edge with label and data":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check:
      r in g
      g.edge(r).label == "MARRIED_TO"
      g.edge(r)["since"].getInt() == 2012
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

  test "update node data":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))

    check:
      g.node(p1).label == "Person"
      g.node(p1)["name"].getStr() == "John Doe"
      g.node(p1)["age"].getInt() == 24
      g.numberOfNodes == 1
      g.numberOfEdges == 0

    p1 = g.node(p1).update(%(name: "Jane Doe", age: 22))

    check:
      g.node(p1).label == "Person"
      g.node(p1)["name"].getStr() == "Jane Doe"
      g.node(p1)["age"].getInt() == 22
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "update edge data":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check:
      g.edge(r).label == "MARRIED_TO"
      g.edge(r)["since"].getInt() == 2012
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

    r = g.edge(r).update(%(since: 2007))

    check:
      g.edge(r).label == "MARRIED_TO"
      g.edge(r)["since"].getInt() == 2007
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

  test "get neighbors":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))

    discard g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check:
      sequalizeIt(g.neighbors(p2)).len == 0
      sequalizeIt(g.neighbors(p1)) == @[p2]
      sequalizeIt(g.neighbors(p2, direction = Direction.In)) == @[p1]

  test "get edges between nodes":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

suite "delete edges and nodes":
  setup:
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Smith", age: 22))
      p3 = g.addNode("Person", %(name: "Thomas Smith", age: 37))
      r1 = g.addEdge(p1, p2, "MARRIED_TO", %(began: 2008, ended: 2012))
      r2 = g.addEdge(p2, p3, "MARRIED_TO", %(began: 2014, ended: 2020))

  test "delete edge":
    check:
      # g has 3 Persons (John, Jane, Thomas) and 2 edges (John->Jane, Jane->Thomas)
      g.delEdge(r2)
      # g has 3 Persons (John, Jane, Thomas) and 1 edge (John->Jane)
      p1 in g
      p2 in g
      p3 in g
      r1 in g
      r2 notin g
      g.numberOfNodes == 3
      g.numberOfEdges == 1
      g.hasEdge(p1, p2) == true
      g.hasEdge(p2, p3) == false

  test "delete node":
    check:
      # g has 3 Persons (John, Jane, Thomas) and 2 edges (John->Jane, Jane->Thomas)
      g.delEdge(r2)
      # g has 3 Persons (John, Jane, Thomas) and 1 edge (John->Jane)
      g.delNode(p1)
      # g has 2 Persons (Jane, Thomas) and 0 edges
      p1 notin g
      p2 in g
      p3 in g
      r1 notin g
      r2 notin g
      g.numberOfNodes == 2
      g.numberOfEdges == 0
      g.hasEdge(p1, p2, direction = Direction.OutIn) == false
      g.hasEdge(p2, p3, direction = Direction.OutIn) == false

suite "Node/edge iterators for getting and setting":
  setup:
    graph g "People and Pets":
      nodes:
        Person:
          "new gal":
            name: "Jane Doe"
            age: 22
          "new guy":
            name: "John Doe"
            age: 24
        Pet:
          "famous cat":
            name: "Tom"
      edges:
        "new gal" -> "new guy":
          MARRIED_TO:
            since: 2012
        "new gal" -> "new guy":
          INHERITS:
            amount: 20004.5
        "new guy" -> "famous cat":
          OWNS:
            insured: true
            since: 2014

  test "getting through node iterators":
    check:
      sorted(g.nodes() --> map(it["name"].getStr)) == @["Jane Doe", "John Doe", "Tom"]
      sorted(g.nodes("Person") --> map(it["name"].getStr)) == @["Jane Doe", "John Doe"]

  test "getting through edge iterators":
    var
      allP: seq[string]
      someP: seq[string]

    for edge in g.edges:
      allP = concat(allP, sequalizeIt(edge.keys))
    for edge in g.edges(["MARRIED_TO", "OWNS"]):
      someP = concat(someP, sequalizeIt(edge.keys))

    check:
      allP.sorted == @["amount", "insured", "since", "since"]
      someP.sorted == @["insured", "since", "since"]

  test "setting through node iterators":
    for node in g.nodes("Pet"):
      discard node.update(%(name: "Garfield"))

    check g.node("famous cat")["name"].getStr == "Garfield"

  test "setting through edge iterators":
    for edge in g.edges(["MARRIED_TO", "OWNS"]):
      discard edge.update(%(since: 2011))

    for edge in g.edgesBetween("new gal", "new guy"):
      if edge.label == "MARRIED_TO":
        check edge["since"].getInt == 2011
    check sequalizeIt(g.edgesBetween("new guy", "famous cat"))[0][
        "since"].getInt == 2011

suite "getting node/edge labels":
  setup:
    graph g "People and Pets":
      nodes:
        Person:
          "new gal":
            name: "Jane Doe"
            age: 22
          "new guy":
            name: "John Doe"
            age: 24
        Pet:
          "famous cat":
            name: "Tom"
      edges:
        "new gal" -> "new guy":
          MARRIED_TO:
            since: 2012
        "new gal" -> "new guy":
          INHERITS:
            amount: 20004.5
        "new guy" -> "famous cat":
          OWNS:
            insured: true
            since: 2014

  test "getting node labels":
    check g.nodeLabels.sorted == @["Person", "Pet"]

  test "getting edge labels":
    check g.edgeLabels.sorted == @["INHERITS", "MARRIED_TO", "OWNS"]


suite "node and edge filters":
  setup:
    graph g "People":
      nodes:
        Person:
          "alice":
            name: "Alice"
            age: 20
          "alice2":
            name: "Alice"
            age: 25
          "bob":
            name: "Bob"
          "charlie":
            name: "Charlie"

      edges:
        "alice" -> "bob":
          KNOWS
        "alice2" -> "bob":
          KNOWS:
            since: 2012
        "bob" -> "charlie":
          KNOWS

  test "node filter":
    let age = zfun(g.nodes("Person", node.name == "Alice" and node.age < 22) --> map(toMap(it)), node):
        map(node.age)
        reduce(node.elem)
    check age == 20

  test "edge filter":
    let couple = zfun(g.edges("KNOWS", edge.since == 2012), edge):
      map((edge.startsAt["name"].getStr, edge.endsAt["name"].getStr))

    check couple == @[("Alice", "Bob")]
