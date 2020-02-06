import grim
import grim/utils

import unittest
import sequtils

suite "DSL":
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

      edges:
        "new gal" -> "new guy":
          MARRIED_TO:
            since: 2012

  test "build graph":
    let
      p1 = g.node("new gal")
      p2 = g.node("new guy")

    check:
      p1 in g
      p2 in g

      p1.label == "Person"
      p1["name"].getStr == "Jane Doe"
      p1["age"].getInt == 22

      p2.label == "Person"
      p2["name"].getStr == "John Doe"
      p2["age"].getInt == 24

      g.numberOfNodes == 2

    for r in g.edgesBetween("new gal", "new guy"):
      check:
        r in g
        r.startsAt == p1
        r.endsAt == p2
        r.label == "MARRIED_TO"
        r["since"].getInt == 2012

    check:
      g.numberOfEdges == 1
      g.edgesBetween("new guy", "new gal").sequalizeIt.len == 0
      g.edgesBetween("new guy", "new gal",
          direction = Direction.In).sequalizeIt.len == 1
      g.edgesBetween("new guy", "new gal",
          direction = Direction.OutIn).sequalizeIt.len == 1

      sequalizeIt(g.neighbors("new guy")).len == 0
      sequalizeIt(g.neighbors("new guy", direction = Direction.In)) == @["new gal"]
      sequalizeIt(g.neighbors("new guy", direction = Direction.OutIn)) == @["new gal"]
