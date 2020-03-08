<p align="center">
<img src="static/logo.svg" alt="grim" width=100>
</p>

# grim brings property graphs to Nim!

Grim brings the [labeled property graph](https://en.wikipedia.org/wiki/Graph_database#Labeled-property_graph) (LPG) data structure to the Nim language. This storage model is used in the [Neo4j](https://neo4j.com) database and consists of labeled **Nodes** and **Edges**. The data itself is stored in key/value-pairs on these entities.

<p align="center">
<img src="static/map.svg" alt="grim" width=500>
</p>

**News:** [2020-02-07] v0.2.0 released! See the [Changelog](Changelog.md).

------

[Using grim](#using-grim) | [Documentation and API](#documentation-and-api) | [Running the tests](#running-the-tests) | [Built with](#built-with) | [Contributing](#contributing) | [Authors](#authors) | [License](#license)

## Using grim

Grim is provided with the Nimble package manager in recent Nim distributions.

### Prerequisites

Install the Nim compiler; see the [nim-lang homepage](https://nim-lang.org) for instructions.

### Installing

Use `nimble` to install `grim` on your local machine:

```bash
nimble install grim
```

Use `grim` in a project by adding
```nim
requires "grim"
```
to its .nimble file.

## Documentation and API

[Basic](#basic) | [Iteration](#iteration) | [Loading/saving](loading-and-saving-graphs) | [Graph-building DSL](#dsl-for-building-graphs) | [Neo4j](#communicating-with-neo4j-database) | [Paths](#paths) | [Navigating paths](#navigating-paths)

The `grim` API is quite user-friendly. Use examples are found in the .nim files in the tests/ folder. The [Northwind tutorial](./tutorials/Northwind.nim) demonstrates how a relational SQL model (of the sales in a small company) is translated to the labeled property graph provided by `grim`. 

The `grim` documentation is continuously improved and is [hosted on Github](https://ebran.github.io/grim). 

### Basic

Create a new graph:

```nim
import grim

var g = newGraph("my graph")
echo g.name    
# => "my graph"
doAssert g.numberOfNodes == 0 and g.numberOfEdges == 0
```
Add nodes to the graph:
```nim
let 
  c1 = g.addNode("Country", %(name: "Sweden", GDP_per_capita: 53208.0))
  c2 = g.addNode("Country", %(name: "Norway", GDP_per_capita: 74536.0))
  c3 = g.addNode("Country", %(name: "Germany", GDP_per_capita: 52559.0))

  o1 = g.addNode("Organization", %(name: "NATO", founded: 1949, active: true))
  o2 = g.addNode("Organization", %(name: "EU", founded: 1993, active: true))
  o3 = g.addNode("Organization", %(name: "Nordic Council", founded: 1952))
```
Note:
- The `%`operator converts tuples to key/value properties that are stored in heterogeneous data tables on the LPG.
- `addNode` and `addEdge` return `oid`s for the entities (node or edge). The `oid` is a unique (string) identifier for the entity that can be explicitly set with the `oid` argument to `addNode` and `addEdge`, or is auto-generated if the `oid` argument is omitted.

Here is how data is extracted from the graph:

```nim
doAssert g.node(c1).label == "Country"
doAssert g.node(c1)["name"] == "Sweden"
```
Note:
- The `oid`s are used to identify the node.

Add edges to the graph:
```nim
let
  e1 = g.addEdge(c1, o2, "MEMBER_OF", %(since: 1995))
  e2 = g.addEdge(c1, o3, "MEMBER_OF", %(since: 1952))
  e3 = g.addEdge(c2, o3, "MEMBER_OF", %(since: 1952, membership: "full"))
```
Note:
- The `oid`s are used to identify the nodes and create the new edges (labeled "MEMBER_OF") with key/value properties. 
- Since no `oid` argument is given to `addEdge`, the `oid` is auto-generated (and returned in the `e1`, `e2`, and `e3` variables).

### Iteration

All nodes:
```nim
for node in g.nodes:
  echo node.label, ": ", node     
```
Nodes with a certain label:
```nim
for node in g.nodes("Country"):
  echo node.label, ": ", node
```
All edges:
```nim
for edge in g.edges:
  echo edge.label, ": ", edge
```
All edges with a certain label:
```nim
for edge in g.edges("MEMBER_OF"):
  echo edge.label, ": ", edge
```
All edges between two nodes:
```nim
for edge in g.edgesBetween(c1, o3):
  echo edge.label, ": ", edge
```
Over neighbor nodes:
```nim
for node in g.neighbors(c1):
  echo node.label, ": ", node
```
Note:
- The graph is directional so `addEdge(A, B, "LABEL")` adds an edge with label "LABEL" pointing from A to B. 
- All iterators take a `direction` argument that specifies whether to include outgoing (`A->B`), incoming (`A<-B`) or both (`A<->B`) edges/neighbors.
- The direction is specified with the enum values `Direction.Out`, `Direction.In`, and `Direction.OutIn`.

### Loading and saving graphs

Graph structures can be loaded and saved in YAML format with the help of the [NimYAML](https://nimyaml.org/) library. The two procs `loadYaml` and `saveYaml` can be used (there are examples in the `tests/` folder).

```nim
import grim

var g = loadYaml("example.yaml")    # Load graph from YAML file
g.saveYaml("example2.yaml")         # Save a copy of the file
```

### DSL for building graphs

A small DSL is provided to reduce boilerplate when building graphs. A toy example:
```nim
import grim

graph g "Some people":
  nodes:
  	Person:
  		"a nice guy":
  		  name: "Santa Claus"
  		  age: 108
  		"a smart girl":
  		  name: "Jane Austen"
  		  wealth: 10304.3
  edges:
    "a nice guy" -> "a smart girl":
      DELIVERS:
        category: "writing material"
        value: 204
```
This will expose the graph in the remainder of the code as the mutable variable `g`. This example shows how to access graph properties:
```nim
let
  p1 = g.node("a nice guy")
  p2 = g.node("a smart girl")

doAssert p1.label == "Character" and p2.label == "Character"
doAssert p1["name"].getStr == "Santa Claus"
doAssert p1["age"].getInt == 108
doAssert p2["name"].getStr == "Jane Austen"
doAssert p2["wealth"].getFloat == 10304.3

for e in g.edgesBetween("a nice guy", "a smart girl"):
  doAssert e.label == "DELIVERS"
  doAssert e["category"].getStr == "writing material"
  doAssert e["value"].getInt == 204
```

### Communicating with a Neo4j database
The `neo4j` submodule is used to communicate with a Neo4j database. Data is transferred via Neo4j's http REST API since the bolt protocol is not supported at present. 
```nim
import grim/[neo4j, utils]
```
The `utils` module provides the `getEnvOrRaise` proc, which reads an evironment variable or raises a runtime error when the variable is not defined.
```nim
let
    username = getEnvOrRaise("NEO4J_USERNAME")
    password = getEnvOrRaise("NEO4J_PASSWORD")
    hostname = getEnvOrRaise("NEO4J_HOSTNAME")
```
The contents of NEO4J_USERNAME and NEO4J_PASSWORD are self-explanatory, and the NEO4J_HOSTNAME contains the address to the database on the form `mydatabase.com` (or simply `localhost` if you are running a local instance).

Start the client and dump the database as a grim LPG: 
```nim
  var
    client = initNeo4jClient(hostname, auth = (username, password))
    g = client.dump("SHAARP")
  
  echo g.describe
```
### Paths
A path in the graph is defined by a sequence of continuous edges (members), which link together a number of nodes. The path can be `walked` (or traversed) by iterating from the beginning of the path. The paths starts at an *anchor* node.
```nim
var p = newPath(myNode)
```
`p` is now an empty path starting at `myNode`. We can now start building the path by repeatedly adding members to the path.
```nim
p = p.add(myFirstEdge).add(mySecondEdge).add(myThirdEdge)
```
The add proc returns the path and can therefore be chained. Note that paths and members are ref objects so to create a copy of a path we need to use the explicit `copy` function
```nim
var p2 = p.copy
```
Walk the path by iterating
```nim
for edge in p:
  echo edge
# myFirstEdge, mySecondEdge, myThirdEdge
```
Get the first, last, and n:th member by convenience functions:
```nim
echo p.first    # myFirstEdge
echo p.last     # myThirdEdge
echo p.nth(1)   # mySecondEdge (zero-indexed)
```
The first two of these are O(1) operations, but the last is O(n) and thus slower for long paths.

### Navigating paths
The real power of paths emerge when navigating path via patterns. This is an efficient method for simple traversal of similar paths in the graph. The paths can be scanned and modified in a single sweep. 

Let's start our example by building a graph:

```nim
import grim/dsl

graph g "People":
  nodes:
    Person:
      "alice":
        name: "Alice"
      "bob":
        name: "Bob"
      "charlie":
        name: "Charlie"
  edges:
    "alice" -> "bob":
      KNOWS
    "bob" -> "charlie"
      KNOWS
    "bob" -> "charlie"
      KNOWS  
```
The graph is `Alice -KNOWS-> Bob =KNOWS=> Charlie` ,where `->` and `=>` denotes single and double edges, respectively. Let's say we want to navigate this graph by the pattern Person-KNOWS-Person. There are three such paths of length 1 (containing one member): one is Alice-Bob (which is a single edge) and the other two are Bob-Charlie (which is a double edge).

We start navigating with the graph's `navigate` proc:
```nim
var pc = g.navigate("Person")    # PathCollection
```
The navigation starts at an anchor node ("Person"). The result is a `PathCollection`, which is exactly what it sounds like: A collection of paths matching the given pattern. In other words, the `navigate` constructs a PathCollection with empty paths anchored at nodes matching the label Person. We can iterate over the matched paths in the PathCollection:

```nim
for path in pc:
  echo path, path.anchor["name"]
# ("Empty Path", "Alice"), ("Empty Path", "Bob"), ("Empty Path", "Charlie")
# The matching order is not guaranteed.
```
Let's know expand the navigation to the pattern matched by taking the step:
```nim
pc = pc.step("KNOWS", "Person")
```
With the help of the anchors, we have now matched all paths fulfilling the pattern Person-KNOWS-Person. Each step taken when navigating returns a modified copy of the PathCollection, encouraging sequential steps to be chained:

```nim
var pc = g
  .navigate("Person")
  .step("KNOWS", "Person")
  .step("KNOWS", "Person")
```
In fact, this pattern is expected to be so common that there is a convenience function for repeating a number of identical steps:
```nim
var pc = g
  .navigate("Person")
  .steps("KNOWS", "Person", 2)
```
This navigation will search the graph for motifs of the kind Person-KNOWS->Person-KNOWS->Person, i.e., friends of friends. Note that the match is exhaustive, i.e.,
```nim
var pc = g
  .navigate("Person")
  .step("KNOWS", "Person", 3)
```
will return no matches (i.e., a path collection of empty paths anchored at "Person" labels).

There is one more important path navigation function, namely `follow`. This will match all patterns of variable length until there are no more matching paths. In our example,
```nim
var pc = g
  .navigate("Person")
  .follow("KNOWS", "Person")
```
will match Person-KNOWS-Person, Person-KNOWS-Person-KNOWS-Person, etc. In our graph, we expect matches:
- One 1-step path Alice-KNOWS-Bob.
- Two 1-step paths Bob-KNOWS-Charlie (because of two edges).
- Two 2-step paths Alice-KNOWS-Bob-KNOWS-Charlie (because of two edges between Bob and Charlie).

After matching patterns, we can simply iterate over the paths in the collection:
```nim
for path in pc:
  echo path, path.anchor
# Three 1-step paths, two 2-step paths
# Anchors: Alice (1-step path), Bob (1-step path), Bob (1-step path), Alice (2-step path), Alice (2-step path).
```

## Running the tests

The unit tests can be run with nimble, they test basic usage of the package such as creating and modifying graphs, the DSL, and loading/saving graphs as YAML.

```bash
nimble test
```

## Built With

* [Nim](https://nim-lang.org/) - The Nim programming language.
* [NimYAML](https://nimyaml.org/) - A pure YAML implementation for Nim.

## Contributing

I'll be happy to accept and review PRs and discuss other things on submitted to Issues.

## Authors

* **Erik G. Brandt** - *Original author* - [ebran](https://github.com/ebran)

## License

This project is licensed under the MIT License.
