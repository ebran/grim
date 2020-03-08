==============================================
Grim brings the labeled property graph to Nim!
==============================================

.. figure:: logo.svg
   :alt: grim, the bringer of graphs

.. contents::


Grim provides a labeled `property graph <https://en.wikipedia.org/wiki/Graph_database#Labeled-property_graph>`_ (LPG) data structure for the Nim language, inspired by the storage model of the `Neo4j <https://neo4j.com/>`_ database. This model consists of labeled **entities** (Nodes and Edges) with associated data stored as key/value-pairs.

🚀 Quickstart
=============
Grim can be installed with the Nimble package manager:

.. code-block:: bash

   nimble install grim

and used as a library in a Nim project by inserting

.. code-block:: bash

   requires "grim"

in the .nimble file in the root folder. Then to get access to the Grim API use 

.. code-block:: nim

   import grim

in your code. This will import all submodules except ``dsl`` (needs to be imported as ``import grim/dsl``) in grim into the namespace. 

📝 User guide
=============

The grim library is divided into submodules which may be imported directly as appropriate. Here we list the most imporant procs, templates, and macros. The generated documentation and the index can be used to find out exactly what attributes and procs that are available.

graph
-----
The submodule contains the LPG data structure and various way of retrieving information and manipulating the graph structure..

- ``Graph`` (*type*)
    The LPG data structure.

- ``node`` (*proc*)
    Return a node from the graph.

- ``edge`` (*proc*)
    Return an edge from the graph.

- ``nodes`` (*iterator*)
    Iterate over nodes with the same label (or all) in the graph.

- ``edges`` (*iterator*)
    Iterate over edges with the same label (or all) in the graph.

- ``edgesBetween`` (*iterator*)
    Iterate over all edges between two nodes.

- ``neighbors`` (*iterator*)
    Iterate over neighbors to a node.

- ``addNode`` (*proc*)
    Add a node to the graph.

- ``addEdge`` (*proc*)
    Add an edge to the graph.

- ``delNode`` (*proc*)
    Delete a node from the graph.

- ``delEdge`` (*proc*)
    Delete an edge from the graph.

- ``hasEdge`` (*proc*)
    Return whether there is an edge between two nodes.

- ``pattern`` (*proc*)
    Start a PathCollection for pattern matching.

- ``describe`` (*proc*)
    Return a summary of the graph.

- ``update`` (*proc*)
    Update node or edge properties.

paths
-----

Path
******

- ``first`` (*proc*)
    Get the first member of the path (O(1) operation).

- ``last`` (*proc*)
    Get the last member of the path (O(1) operation).

- ``nth`` (*proc*)
    Get the n:th member of the path (O(n) operation).

- ``copy`` (*proc*)
    Copy all members and return a new path (O(n) operation).

PathCollection
**************

- ``step``
    Take a single step while matching paths on node/edge patterns.

- ``steps``
    Take multiple steps while matching paths on node/edge patterns.

- ``follow``
    Keep taking steps until no more paths match the node/edge pattern.

dsl
-----
The submodule contains a domain specific language (DSL) macro to create LPGs.

- ``graph`` (*macro*)
    DSL to easily create LPGs with minimal boilerplate. Usage examples can be found in the unit tests and in the README.

neo4j
-----
The submodule contains a simple database client to communicate with a Neo4j database instance.

- ``dump`` (*proc*)
    Dump a Neo4j database as a labeled property graph (LPG) in grim.

- ``execute`` (*proc*)
    Execute a Cypher query on the database and return result as a grim graph.

io
-----
The submodule contains input and output routines that are used to read graphs from files and write graphs to file.

- ``loadYaml`` (*proc*)
    Load a YAML graph from file.

- ``saveYaml`` (*proc*)
    Save a YAML graph to file.

box
-----
The submodule contains a box (or container) type that is used to store values of different kinds in the same static structure.

- ``Box`` (*type*)
    A container used to store heterogenuous data in a single static structure.

- ``initBox`` (*proc*)
    Create a new box.

- ``guessBox`` (*proc*)
    Create a new box of proper kind based on input.

- ``getStr`` (*proc*)
    Return string value in box.

- ``getInt`` (*proc*)
    Return integer value in box.

- ``getFloat`` (*proc*)
    Return float value in box.

- ``getBool`` (*proc*)
    Return boolean value in box.

- ``isEmpty`` (*proc*)
    Check whether box is empty.

- ``update`` (*proc*)
    Update the value in the box.

Reference API
=============
See the generated documentation for `grim <grim.html>`_.


.. Ordinary reference `Subheading A`_
.. gives ``<a class="reference external" href="#subheading-a">``

.. Note that according to the TOC, the href should be ``"#a-major-heading-subheading-a">``

.. Use id role `Subheading A`:id:
.. gives ``<span class="id">Subheading A</span>``

.. Use id argument `Subheading A`:id-abc:
.. gives ``<cite>Subheading A</cite>:id-abc:``

.. Use idx role `Subheading A`:idx:
.. gives ``<span id="subheading-a_1">Subheading A</span>``

.. Use idw role `Subheading A`:idw:
.. gives ``<span class="idw">Subheading A</span>``

.. A Major Heading
.. ===============

.. Highly important stuffA

.. Subheading A
.. ------------

.. Detailed stuff
