# This tutorial is adapted from https://neo4j.com/developer/guide-importing-data-and-etl
# and describes how to translate a relational (SQL) database into a property graph with `grim`.
#
# The general principles when translating a relation model to a graph model is:
#
#   1. A row is a node
#   2. A table name is a node label name
#   3. A join or foreign key is an edge (relationship)
#
# This first iteration of the graph model can then be fine-tuned manually 
# (as we do in Part 3 of this tutorial).
#
# DONE PART 1: BUILDING THE GRAPH
# ===============================

# import stdlib pure modules
import sequtils
import strutils
import sugar
import sets
import tables

# import stdlib impure modules
import db_sqlite

# import grim
import grim

type
  ## Relationship object that is created from foreign keys in the SQL table
  Relationship = object
    table: string        # Name of the SQL table
    label: string        # The graph node label
    A: tuple[label: string, key: string] # Start node (label: Node label, key: SQL foreign key)
    B: tuple[label: string, key: string] # End node (label: Node label, key: SQL foreign key)
    use_properties: bool # Transfer the columns in `table` to edge properties

proc initRelationship(
  table: string,
  label: string,
  A: tuple[label: string, key: string],
  B: tuple[label: string, key: string],
  useProperties: bool = false): Relationship =
  ## Init a new relationship
  result = Relationship(table: table, label: label, A: A, B: B,
      useProperties: useProperties)

const
  ## Define SQL queries
  queries = {
    "table": "SELECT * FROM \"$1\"", # Get all columns from table
    "header": "SELECT name FROM PRAGMA_TABLE_INFO('$1')" # Get column names for table
  }.toTable

  ## Define graph nodes from SQL tables
  nodes = [
    "Customer",
    "Supplier",
    "Product",
    "Employee",
    "Category",
    "Order"
  ]

  # Define the relationships from foreign keys in SQL tables
  relationships = [
    initRelationship(
      table = "Order",
      A = (label: "Employee", key: "EmployeeId"),
      B = (label: "Order", key: "Id"),
      label = "SOLD"),
    initRelationship(
      table = "OrderDetail",
      A = (label: "Order", key: "OrderId"),
      B = (label: "Product", key: "ProductId"),
      label = "PRODUCT",
      use_properties = true),  # In this table we want to transfer all columns as edge properties
    initRelationship(
      table = "Product",
      A = (label: "Product", key: "Id"),
      B = (label: "Category", key: "CategoryId"),
      label = "PART_OF"
    ),
    initRelationship(
      table = "Product",
      A = (label: "Supplier", key: "SupplierId"),
      B = (label: "Product", key: "Id"),
      label = "SUPPLIES"
    ),
    initRelationship(
      table = "Employee",
      A = (label: "Employee", key: "Id"),
      B = (label: "Employee", key: "ReportsTo"),
      label = "REPORTS_TO"
    )
  ]

# Initialize the graph
var g = newGraph("northwind")

# Open a connection to the database
let db = open("Northwind_small.sqlite", "", "", "")

# Create nodes from database tables
for tbl in nodes:
  # Read the column names for the node table
  let headers = db.getAllRows(sql(queries["header"].format(tbl))).concat

  # Iterate over table rows
  for row in db.fastRows(sql(queries["table"].format(tbl))):
    # Read data and add rows as nodes
    let data = zip(headers, row.map(x => x.guessBox)).toTable
    discard g.addNode(tbl, data, oid = "$1.$2".format(tbl, data["Id"]))

# Create relationships from foreign keys in tables
for rel in relationships:
  # Read the column names for the edge table
  let headers = db.getAllRows(sql(queries["header"].format(
      rel.table))).concat

  # Iterate over table rows
  for row in db.fastRows(sql(queries["table"].format(rel.table))):
    # Read data
    var data = zip(headers, row.map(x => x.guessBox)).toTable

    let
      # get the node labels for A and B
      A = "$1.$2".format(rel.A.label, data[rel.A.key])
      B = "$1.$2".format(rel.B.label, data[rel.B.key])

    # Skip the edge if either foreign key is missing
    if data[rel.A.key].isEmpty or data[rel.B.key].isEmpty:
      continue

    if rel.use_properties:
      # Transfer `data` to edge properties
      # delete the foreign keys from the properties
      data.del(rel.A.key)
      data.del(rel.B.key)
      # Add the edge
      discard g.addEdge(A, B, rel.label, properties = data,
          oid = "$1-$2".format(A, B))
    else:
      discard g.addEdge(A, B, rel.label, oid = "$1-$2".format(A, B))

# Print the graph
echo g.describe

# STARTED PART 2: QUERYING THE GRAPH
# ===============================
# Needed to avoid double counting edges A: A -> B and B: A -> B
var seen: HashSet[string]

# Loop over employee nodes and then over its edges
for node in g.nodes("Employee"):
  for edge in node.edges:
    # Skip doublets
    if edge.label == "REPORTS_TO" and edge.oid notin seen:
      let
        employee = edge.startsAt
        manager = edge.endsAt

      echo "$1 $2 is manager to $3 $4.".format(manager["FirstName"],
          manager["LastName"], employee["FirstName"], employee["LastName"])
    seen.incl(edge.oid)

# TODO 3. Which Employees Report to Each Other Indirectly?
# TODO 4. How Many Orders were Made by Each Part of the Hierarchy?

# TODO PART 3: UPDATING THE GRAPH
# ===============================
# TODO 1. Janet is now reporting to Steven
