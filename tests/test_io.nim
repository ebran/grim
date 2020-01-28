import grim
import unittest
import sequtils
from os import tryRemoveFile, getAppDir, `/`, ParDir

suite "Input and output":
  setup:
    var g = loadYaml(getAppDir() / ParDir / "tests" / "example.yaml")

  teardown:
    discard tryRemoveFile(getAppDir() / ParDir / "tests" / "example_test1.yaml")
    discard tryRemoveFile(getAppDir() / ParDir / "tests" / "example_test2.yaml")
    discard tryRemoveFile(getAppDir() / ParDir / "tests" / "example_test3.yaml")

  test "Test YAML reader on example file":
    let
      p1 = g.node("new gal")
      p2 = g.node("new guy")
      p3 = g.node("young gun")

    check:
      g.name == "Happy People"
      "new gal" in g
      "new guy" in g
      "young gun" in g

      p1.label == "Person"
      p1["name"].getStr == "Jane Doe"
      p1["age"].getInt == 22
      p1["smoker"].getBool == true

      p2.label == "Person"
      p2["name"].getStr == "John Doe"
      p2["age"].getInt == 24
      p2["weight"].getFloat == 37.2

      p3.label == "Person"

      g.numberOfNodes == 3

    for r in g.edgesBetween("new guy", "new gal"):
      check:
        r in g
        r.startsAt == p1
        r.endsAt == p2

      case r.label:
        of "MARRIED_TO":
          check r["since"].getInt == 2012
        of "INHERITS":
          check r["amount"].getFloat == 1937.2
        else:
          discard

    check:
      toSeq(g.neighbors("new gal")) == @["new guy"]
      toSeq(g.neighbors("new guy")) == @["new gal"]
      g.numberOfEdges == 2

  test "Test saving graph to YAML by round-tripping":
    # Round-trip: save => load => save => load => save
    g.saveYaml(getAppDir() / ParDir / "tests" / "example_test1.yaml",
        force_overwrite = true)

    var g1 = loadYaml(getAppDir() / ParDir / "tests" / "example_test1.yaml")
    g1.saveYaml(getAppDir() / ParDir / "tests" / "example_test2.yaml",
        force_overwrite = true)
    var g2 = loadYaml(getAppDir() / ParDir / "tests" / "example_test2.yaml")
    g2.saveYaml(getAppDir() / ParDir / "tests" / "example_test3.yaml",
        force_overwrite = true)

    let
      before = readFile(getAppDir() / ParDir / "tests" / "example_test2.yaml")
      after = readFile(getAppDir() / ParDir / "tests" / "example_test3.yaml")

    check before == after
