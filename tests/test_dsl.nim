import grim
import unittest
import sequtils

suite "DSL":
  test "build graph":
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

    let
      p1 = g.getNode("new gal")
      p2 = g.getNode("new guy")

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

    for r in g.getEdges("new guy", "new gal"):
      check:
        r in g
        r.startsAt == p1
        r.endsAt == p2
        r.label == "MARRIED_TO"
        r["since"].getInt == 2012

    check:
      toSeq(g.neighbors("new gal")) == @["new guy"]
      toSeq(g.neighbors("new guy")) == @["new gal"]

      g.numberOfEdges == 1
