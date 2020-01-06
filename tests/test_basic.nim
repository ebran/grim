import grim
import unittest

suite "Box":
  setup:
    var
      b1 = initBox()
      b2 = initBox(2)
      b3 = initBox("John")
      b4 = initBox(3.2)
      b5 = initBox(true)

  test "Setup basic box types":
    check:
      b1.isEmpty == true
      b2.isEmpty == false
      b2.getInt == 2
      b3.getStr == "John"
      b4.getFloat == 3.2
      b5.getBool == true

  test "Update box values":
    b2.update(3)
    b3.update("Jane")
    b4.update(6.4)
    b5.update(false)

    check:
      b2.getInt == 3
      b3.getStr == "Jane"
      b4.getFloat == 6.4
      b5.getBool == false
