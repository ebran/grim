import sequtils
import strutils
import sugar
import tables
import db_sqlite
import grim

# Read database
let db = open("Northwind_small.sqlite", "", "", "")

# Initialize graph
var g = initGraph("northwind")

# Define SQL queries
const queries = {
  "table": "SELECT * FROM \"$1\"",
  "header": "SELECT name FROM PRAGMA_TABLE_INFO('$1')"
  }.toTable

const foreignKeys = {
  "Customer": "",
  "Supplier": "",
  "Product": "",
  "Employee": "",
  "Category": "",
  "Order": "EmployeeId"
}.toTable

for tbl in foreignKeys.keys:
  # Read column names for table
  var headers = db.getAllRows(sql(query["header"].format(tbl))).map(x => x[0])

  # Iterate over table and add nodes
  for row in db.fastRows(sql(query["table"].format(tbl))):
    discard g.addNode(tbl, zip(headers, row.map(x => x.initBox)).toTable)

# create relationships of orders to products and employees.
for node in g.nodes:
  if node.label == "Order":
    echo node
    break

