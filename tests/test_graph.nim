# To run these tests, simply execute `nimble test`.
import grim
import tables
import algorithm
import sequtils
import sugar
import unittest

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
      g.getNode(oid).label == "Person"
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "add node with label and properties":
    var
      g = newGraph("People")
      oid = g.addNode("Person", %(name: "John Doe", age: 24))

    check:
      oid in g
      g.getNode(oid).label == "Person"
      g.getNode(oid)["name"].getStr() == "John Doe"
      g.getNode(oid)["age"].getInt() == 24
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "add edge with label and properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check:
      r in g
      g.getEdge(r).label == "MARRIED_TO"
      g.getEdge(r)["since"].getInt() == 2012
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

  test "update node properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))

    check:
      g.getNode(p1).label == "Person"
      g.getNode(p1)["name"].getStr() == "John Doe"
      g.getNode(p1)["age"].getInt() == 24
      g.numberOfNodes == 1
      g.numberOfEdges == 0

    p1 = g.getNode(p1).update(%(name: "Jane Doe", age: 22))

    check:
      g.getNode(p1).label == "Person"
      g.getNode(p1)["name"].getStr() == "Jane Doe"
      g.getNode(p1)["age"].getInt() == 22
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "update edge properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check:
      g.getEdge(r).label == "MARRIED_TO"
      g.getEdge(r)["since"].getInt() == 2012
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

    r = g.getEdge(r).update(%(since: 2007))

    check:
      g.getEdge(r).label == "MARRIED_TO"
      g.getEdge(r)["since"].getInt() == 2007
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
      toSeq(g.neighbors(p1)) == @[p2]
      toSeq(g.neighbors(p2)) == @[p1]

  test "get edges":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check toSeq(g.getEdges(p1, p2)) == @[g.getEdge(r)]

suite "node/edge iterators for getting and setting":
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
    let
      allNames = toSeq(g.nodes).map(x => x.properties["name"].getStr).sorted
      someNames = toSeq(g.nodes("Person")).map(x => x.properties[
          "name"].getStr).sorted

    check:
      allNames == @["Jane Doe", "John Doe", "Tom"]
      someNames == @["Jane Doe", "John Doe"]

  test "getting through edge iterators":
    var
      allP: seq[string]
      someP: seq[string]

    for edge in g.edges:
      allP = concat(allP, toSeq(edge.keys))
    for edge in g.edges("MARRIED_TO", "OWNS"):
      someP = concat(someP, toSeq(edge.keys))

    check:
      allP.sorted == @["amount", "insured", "since", "since"]
      someP.sorted == @["insured", "since", "since"]

  test "setting through node iterators":
    for node in g.nodes("Pet"):
      discard node.update(%(name: "Garfield"))

    check g.getNode("famous cat")["name"].getStr == "Garfield"

  test "setting through edge iterators":
    for edge in g.edges("MARRIED_TO", "OWNS"):
      discard edge.update(%(since: 2011))

    check:
      toSeq(g.getEdges("new gal", "new guy"))[0].properties["since"].getInt == 2011
      toSeq(g.getEdges("new guy", "famous cat"))[0].properties[
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
