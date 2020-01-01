# To run these tests, simply execute `nimble test`.
import graph
import sets
import unittest

suite "Basic usage":
  test "create graph":
    let g = newGraph("Test")

    check g.name == "Test"
    check g.numberOfNodes == 0
    check g.numberOfEdges == 0

  test "create nodes":
    let p1 = newNode("Person", (name: "John Doe", age: 24), "new guy")
    let p2 = newNode("Person", (name: "Jane Doe", age: 22))

    check p1.label == "Person"
    check p1.properties["name"].getStr() == "John Doe"
    check p1.properties["age"].getInt() == 24
    check p1.oid == "new guy"

    check p2.label == "Person"
    check p2.properties["name"].getStr() == "Jane Doe"
    check p2.properties["age"].getInt() == 22

  test "add node with label":
    var g = newGraph("People")
    let oid = g.addNode("Person")

    check oid in g
    check g.nodes[oid].label == "Person"
    check g.numberOfNodes == 1
    check g.numberOfEdges == 0

  test "add node with label and properties":
    var g = newGraph("People")
    let oid = g.addNode("Person", (name: "John Doe", age: 24))

    check oid in g
    check g.nodes[oid].label == "Person"
    check g.nodes[oid].properties["name"].getStr() == "John Doe"
    check g.nodes[oid].properties["age"].getInt() == 24
    check g.numberOfNodes == 1
    check g.numberOfEdges == 0

  test "add edge with label and properties":
    var g = newGraph("People")
    let p1 = g.addNode("Person", (name: "John Doe", age: 24))
    let p2 = g.addNode("Person", (name: "Jane Doe", age: 22))
    let r = g.addEdge(p1, p2, "MARRIED_TO", (since: 2012))

    check r in g
    check g.edges[r].label == "MARRIED_TO"
    check g.edges[r].properties["since"].getInt() == 2012
    check g.hasEdge(p1, p2)
    check g.numberOfNodes == 2
    check g.numberOfEdges == 1

  test "update node properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", (name: "John Doe", age: 24))

    check g.nodes[p1].label == "Person"
    check g.nodes[p1].properties["name"].getStr() == "John Doe"
    check g.nodes[p1].properties["age"].getInt() == 24
    check g.numberOfNodes == 1
    check g.numberOfEdges == 0

    p1 = g.nodes[p1].update((name: "Jane Doe", age: 22))

    check g.nodes[p1].label == "Person"
    check g.nodes[p1].properties["name"].getStr() == "Jane Doe"
    check g.nodes[p1].properties["age"].getInt() == 22
    check g.numberOfNodes == 1
    check g.numberOfEdges == 0

  test "update edge properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", (name: "John Doe", age: 24))
      p2 = g.addNode("Person", (name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", (since: 2012))

    check g.edges[r].label == "MARRIED_TO"
    check g.edges[r].properties["since"].getInt() == 2012
    check g.hasEdge(p1, p2)
    check g.numberOfNodes == 2
    check g.numberOfEdges == 1

    r = g.edges[r].update((since: 2007))

    check g.edges[r].label == "MARRIED_TO"
    check g.edges[r].properties["since"].getInt() == 2007
    check g.hasEdge(p1, p2)
    check g.numberOfNodes == 2
    check g.numberOfEdges == 1

  test "get neighbors":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", (name: "John Doe", age: 24))
      p2 = g.addNode("Person", (name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", (since: 2012))

    check g.neighbors(p1) == [p2].toHashSet
    check g.neighbors(p2) == [p1].toHashSet

  test "get edges":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", (name: "John Doe", age: 24))
      p2 = g.addNode("Person", (name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", (since: 2012))

    check g.getEdges(p1, p2) == @[g.edges[r]]
