# import stdlib pure modules
import sequtils
import strutils
import sugar
import tables

# import stdlib impure modules
import db_sqlite

# import grim
import grim

# relationship object based on foreign key in SQL table
type
  Relationship = object
    table: string
    label: string
    A: tuple[label: string, key: string]
    B: tuple[label: string, key: string]
    with_properties: bool

# with_properties is optional but transfers the SQL column to edge properties
proc initRelationship(
  table: string,
  label: string,
  A: tuple[label: string, key: string],
  B: tuple[label: string, key: string],
  with_properties: bool = false): Relationship =
  result = Relationship(table: table, label: label, A: A, B: B,
      with_properties: with_properties)

const
  # Define SQL queries
  queries = {
    "table": "SELECT * FROM \"$1\"", # get all columns from table
    "header": "SELECT name FROM PRAGMA_TABLE_INFO('$1')" # get column names for table
  }.toTable

  # Define graph nodes from SQL tables
  nodes = [
    "Customer",
    "Supplier",
    "Product",
    "Employee",
    "Category",
    "Order"
  ]

  # Define relationships from foreign keys in SQL tables
  relationships = [
    initRelationship(
      table = "Order",
      A = (label: "Employee", key: "EmployeeId"),
      B = (label: "Order", key: "Id"),
      label = "SOLD",
      with_properties = true),
    initRelationship(
      table = "OrderDetail",
      A = (label: "Order", key: "OrderId"),
      B = (label: "Product", key: "ProductId"),
      label = "PRODUCT"),
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

# Create nodes from tables
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
  let headers = db.getAllRows(sql(queries["header"].format(rel.table))).concat

  # Iterate over table rows
  for row in db.fastRows(sql(queries["table"].format(rel.table))):
    let
      # Read data
      data = zip(headers, row.map(x => x.guessBox)).toTable
      # get the node labels for A and B
      A = "$1.$2".format(rel.A.label, data[rel.A.key])
      B = "$1.$2".format(rel.B.label, data[rel.B.key])

    # Skip the edge if either foreign key is missing
    if data[rel.A.key].isEmpty or data[rel.B.key].isEmpty:
      continue

    # Add the edge
    discard g.addEdge(A, B, rel.label, oid = "$1-$2".format(A, B))

echo g.describe()

# QUERYING THE GRAPH
# ...
# ...
