import sequtils
import sugar
import grim
import db_sqlite

let
  db = open("Northwind_small.sqlite", "", "", "")
  headers = db.getAllRows(sql"SELECT name FROM PRAGMA_TABLE_INFO('Customer')").map(
    x => x[0])

var g = initGraph("northwind")

for row in db.fastRows(sql"SELECT * FROM Customer"):
  discard g.addNode("Customer", zip(headers, row.map(x => initBox(x))).toTable)

echo g
