# stdlib imports
import unittest

# grim imports
import grim
import grim/utils

suite "Paths":
  setup:
    var g = newGraph("test")

    discard g.addNode("Person", %(name: "Alice"), oid = "alice")
    discard g.addNode("Person", %(name: "Bob"), oid = "bob")
    discard g.addNode("Person", %(name: "Charlie"), oid = "charlie")

    let
      e1 = g.addEdge("alice", "bob", "KNOWS", %(since: 2012), oid = "alice-bob")
      e2 = g.addEdge("bob", "charlie", "KNOWS", %(since: 2013),
          oid = "bob-charlie")

  test "create and walk path":
    var
      p = g.node("alice")
        .newPath
        .add(g.edge("alice-bob"))
        .add(g.edge("bob-charlie"))

    check sequalizeIt(p.walk) == @[g.edge(e1), g.edge(e2)]
