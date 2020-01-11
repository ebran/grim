import grim
import unittest
import sequtils
from os import getAppDir, `/`

suite "Input and output":
  setup:
    var g = loadYaml(getAppDir() / "example.yaml")

  test "Test YAML reader on example file":
    let
      p1 = g.getNode("new gal")
      p2 = g.getNode("new guy")
      p3 = g.getNode("young gun")

    check:
      g.name == "Happy People"
      "new gal" in g
      "new guy" in g
      "young gun" in g

      p1.label == "Person"
      p1.properties["name"].getStr == "Jane Doe"
      p1.properties["age"].getInt == 22
      p1.properties["smoker"].getBool == true

      p2.label == "Person"
      p2.properties["name"].getStr == "John Doe"
      p2.properties["age"].getInt == 24
      p2.properties["weight"].getFloat == 37.2

      p3.label == "Person"

      g.numberOfNodes == 3

    for r in g.getEdges("new guy", "new gal"):
      check:
        r in g
        r.startsAt == p1
        r.endsAt == p2

      case r.label:
        of "MARRIED_TO":
          check r.properties["since"].getInt == 2012
        of "INHERITS":
          check r.properties["amount"].getFloat == 1937.2
        else:
          discard

    check:
      toSeq(g.neighbors("new gal")) == @["new guy"]
      toSeq(g.neighbors("new guy")) == @["new gal"]
      g.numberOfEdges == 2

  test "Test saving graph to YAML by round-tripping":
    # Round-trip: save => load => save => load => save
    g.saveYaml(getAppDir() / "example_test1.yaml", force_overwrite = true)

    var g1 = loadYaml(getAppDir() / "example_test1.yaml")
    g1.saveYaml(getAppDir() / "example_test2.yaml", force_overwrite = true)
    var g2 = loadYaml(getAppDir() / "example_test2.yaml")
    g2.saveYaml(getAppDir() / "example_test3.yaml", force_overwrite = true)

    let
      before = readFile(getAppDir() / "example_test2.yaml")
      after = readFile(getAppDir() / "example_test3.yaml")

    check before == after
