# To run these tests, simply execute `nimble test`.
import json
import graph
import unittest

suite "Basic usage":
  test "create empty graph":
    var g = newGraph()

    check g.numberOfNodes == 0
    check g.numberOfEdges == 0

  test "add node with label":
    var g = newGraph()
    let oid = g.addNode("Person")

    check g.numberOfNodes == 1
    check g.numberOfEdges == 0

  test "add node with label and properties":
    var g = newGraph()
    let oid = g.addNode("Person", (name: "John Doe", age: 24))

    check g.numberOfNodes == 1
    check g.numberOfEdges == 0
    check oid in g

  test "add edge with label and properties":
    var g = newGraph()
    let p1 = initNode("Person", (name: "John Doe", age: 24))
    let p2 = initNode("Person", (name: "Jane Doe", age: 22))

    # let oid = g.addEdge(p1, p2, "MARRIED_TO", (since: 2012))

    # check p1 in g
    # check p2 in g
    # check g.hasEdge(p1, p2)
    # check g.numberOfNodes == 2
    # check g.numberOfEdges == 1
