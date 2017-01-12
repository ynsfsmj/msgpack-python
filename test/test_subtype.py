#!/usr/bin/env python
# coding: utf-8

from pymsgpack import packb, unpackb
from collections import namedtuple

class MyList(list):
    pass

class MyDict(dict):
    pass

class MyTuple(tuple):
    pass

MyNamedTuple = namedtuple('MyNamedTuple', 'x y')

# pymsgpack defaultly not support derived classes from list, tuple, set, dict
def test_types():
    pass
    #assert packb(MyNamedTuple(1, 2)) == packb((1, 2))
