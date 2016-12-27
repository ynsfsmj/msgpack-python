#!/usr/bin/python2

from pymsgpack import packb, unpackb
from cPickle import dumps, loads



def allhash(content):
    all_hash = 0
    if isinstance(content, (str, int, float, tuple, bool)):
        all_hash += hash(content)
    elif isinstance(content, (dict, )):
        for k, v in content.iteritems():
            all_hash += allhash(k) + allhash(v)
    elif isinstance(content, (set, list)):
        for v in content:
            all_hash += allhash(v)
    elif hasattr(content, "__dict__"):
        all_hash += allhash(content.__dict__)
    return all_hash

class NewBase(object):
    def __init__(self):
        self.name = "NewBase"
        self.number = 12345678
        self.fnumber = 1.2345678

class NewMeddle1(NewBase):
    def __init__(self):
        super(NewMeddle1, self).__init__()
        self.name = "NewMiddle1"
        self.mt_1 = (1,2,3)
        self.t_000000000000000000000000000000000000000000000000000000 = ()
        self.l_000000000000000000000000000000000000000000000000000000 = []
        self.d_000000000000000000000000000000000000000000000000000000 = {}
        self.s_000000000000000000000000000000000000000000000000000000 = set()
        self.l_1 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
        self.t_1 = tuple(self.l_1)
        self.s_1 = set(self.l_1)
        self.d_1 = {():[], (1,2,3):set([1,2,3]), 1:"1", "1":1, "-"*512:"="*512}

class NewMeddle2(NewBase):
    def __init__(self):
        super(NewMeddle2, self).__init__()
        self.name = "NewMiddle2"
        self.mt_2 = (4,5,6)
        self.i = 0

class NewChild(NewMeddle1, NewMeddle2):
    def __init__(self, i):
        super(NewChild, self).__init__()
        self.baseprop = NewBase()
        self.meddleprop1 = NewMeddle1()
        self.meddleprop2 = NewMeddle2()
        self.i = i
        self.name = "NewChild"

class OldBase:
    def __init__(self):
        self.name = "OldBase"
        self.number = 12345678
        self.fnumber = 1.2345678

class OldMeddle1(OldBase):
    def __init__(self):
        OldBase.__init__(self)
        self.name = "OldMiddle1"
        self.mt_1 = (1,2,3)
        self.t_000000000000000000000000000000000000000000000000000000 = ()
        self.l_000000000000000000000000000000000000000000000000000000 = []
        self.d_000000000000000000000000000000000000000000000000000000 = {}
        self.s_000000000000000000000000000000000000000000000000000000 = set()
        self.l_1 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
        self.t_1 = tuple(self.l_1)
        self.s_1 = set(self.l_1)
        self.d_1 = {():[], (1,2,3):set([1,2,3]), 1:"1", "1":1, "-"*512:"="*512}

class OldMeddle2(OldBase):
    def __init__(self):
        OldBase.__init__(self)
        self.name = "OldMiddle2"
        self.mt_2 = (4,5,6)

class OldChild(OldMeddle1, OldMeddle2):
    def __init__(self, i):
        OldMeddle1.__init__(self)
        OldMeddle2.__init__(self)
        self.baseprop = OldBase()
        self.meddleprop1 = OldMeddle1()
        self.meddleprop2 = OldMeddle2()
        self.name = "OldChild"
        self.i = i

def pymsgpack_data(data):
    tp = packb(data)
    tun = unpackb(tp)

def cpickle_data(data):
    tp = dumps(data)
    tun = loads(tp)

#import code
#code.interact(banner="", local=locals())

import time


def compare_all(times):
    somelist_0 = []
    somelist_1 = [1,2,3,4,5,6,7]
    somelist_2 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
    sometuple_0 = tuple(somelist_0)
    sometuple_1 = tuple(somelist_1)
    sometuple_2 = tuple(somelist_2)
    someset_0 = set()
    someset_1 = set(somelist_1)
    someset_2 = set(somelist_2)
    somedict_0 = {}
    somedict_1 = {"1":1, "2":2, "3":3, "4":4, "5":5}
    somedict_2 = {():[], (1,2,3):set([1,2,3]), 1:"1", "1":1, "-"*512:"="*512}
    litNew = NewBase()
    litOld = OldBase()
    bigNew = NewChild("bignew")
    bigOld = OldChild("bigold")

    compare_and_print(times, sometuple_0,"tuple0")
    compare_and_print(times, sometuple_1,"tuple1")
    compare_and_print(times, sometuple_2,"tuple2")
    compare_and_print(times, somelist_0, "list0 ")
    compare_and_print(times, somelist_1, "list1 ")
    compare_and_print(times, somelist_2, "list2 ")
    compare_and_print(times, somedict_0, "dict0 ")
    compare_and_print(times, somedict_1, "dict1 ")
    compare_and_print(times, somedict_2, "dict2 ")
    compare_and_print(times, someset_0,  "set0  ")
    compare_and_print(times, someset_1,  "set1  ")
    compare_and_print(times, someset_2,  "set2  ")
    compare_and_print(times, litNew, "newobj1")
    compare_and_print(times, litOld, "oldobj1")
    compare_and_print(times, bigNew, "newobj2")
    compare_and_print(times, bigOld, "oldobj2")

def compare_data(times, data):
    time1 = time.time()
    for j in xrange(times):
        pymsgpack_data(data)
    time2 = time.time()
    for j in xrange(times):
        cpickle_data(data)
    time3 = time.time()
    return time2 - time1, time3 - time2

def compare_and_print(times, data, name):
    t1, t2 = compare_data(times, data)
    print name, "::\tpymsgpack:", int(t1 * 1000)/1000.0, "\tcpickle", int(t2 * 1000)/1000.0, "\tratio", t2/t1

if __name__ == "__main__":
    compare_all(200000)
