# To run these tests, simply execute `nimble test`.
import graph
import tables
import sets
import unittest

suite "Basic usage":
  test "create graph":
    let g = newGraph("Test")

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
      p1.properties["name"].getStr() == "John Doe"
      p1.properties["age"].getInt() == 24
      p1.oid == "new guy"

      p2.label == "Person"
      p2.properties["name"].getStr() == "Jane Doe"
      p2.properties["age"].getInt() == 22

  test "add node with label":
    var
      g = newGraph("People")
      oid = g.addNode("Person")

    check:
      oid in g
      g.nodes[oid].label == "Person"
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "add node with label and properties":
    var
      g = newGraph("People")
      oid = g.addNode("Person", %(name: "John Doe", age: 24))

    check:
      oid in g
      g.nodes[oid].label == "Person"
      g.nodes[oid].properties["name"].getStr() == "John Doe"
      g.nodes[oid].properties["age"].getInt() == 24
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
      g.edges[r].label == "MARRIED_TO"
      g.edges[r].properties["since"].getInt() == 2012
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

  test "update node properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))

    check:
      g.nodes[p1].label == "Person"
      g.nodes[p1].properties["name"].getStr() == "John Doe"
      g.nodes[p1].properties["age"].getInt() == 24
      g.numberOfNodes == 1
      g.numberOfEdges == 0

    p1 = g.nodes[p1].update(%(name: "Jane Doe", age: 22))

    check:
      g.nodes[p1].label == "Person"
      g.nodes[p1].properties["name"].getStr() == "Jane Doe"
      g.nodes[p1].properties["age"].getInt() == 22
      g.numberOfNodes == 1
      g.numberOfEdges == 0

  test "update edge properties":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check:
      g.edges[r].label == "MARRIED_TO"
      g.edges[r].properties["since"].getInt() == 2012
      g.hasEdge(p1, p2)
      g.numberOfNodes == 2
      g.numberOfEdges == 1

    r = g.edges[r].update(%(since: 2007))

    check:
      g.edges[r].label == "MARRIED_TO"
      g.edges[r].properties["since"].getInt() == 2007
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
      g.neighbors(p1) == [p2].toHashSet
      g.neighbors(p2) == [p1].toHashSet

  test "get edges":
    var
      g = newGraph("People")
      p1 = g.addNode("Person", %(name: "John Doe", age: 24))
      p2 = g.addNode("Person", %(name: "Jane Doe", age: 22))
      r = g.addEdge(p1, p2, "MARRIED_TO", %(since: 2012))

    check g.getEdges(p1, p2) == @[g.edges[r]]

  test "build graph from table of nodes":
    let name = "People and pets"
    var data = {
      "Person": %*
      [
        {"name": "John Doe", "age": 24, "oid": "unknown John"},
        {"name": "Jane Doe", "age": 22, "oid": "unknown Jane"},
        {"name": "Adam Smith", "age": 83, "smoker": true, "oid": "famous Adam"},
        {"name": "Jane Austen", "age": 37.2, "oid": "famous Jane"},
      ],
      "Pet": %*
      [
        {"name": "Fluffy", "kind": "cat", "age": 5, "oid": "regular cat"},
        {"name": "Fido", "kind": "dog", "age": 2, "oid": "regular dog"},
        {"name": "Piglet", "kind": "pig", "age": 3, "oid": "cute pig"}
      ]
      }.toTable

    var g = graphFromNodes(name, data)

    check:
      "unknown John" in g
      "unknown Jane" in g
      "famous Adam" in g
      "famous Jane" in g
      "regular cat" in g
      "regular dog" in g
      "cute pig" in g
