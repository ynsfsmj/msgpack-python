#!/usr/bin/python2

from pymsgpack import packb, unpackb

somelist_0 = []
somelist_1 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
sometuple_0 = tuple(somelist_0)
sometuple_1 = tuple(somelist_1)
someset_0 = set()
someset_1 = set(somelist_1)
somedict_0 = {}
somedict_1 = {():[], (1,2,3):set([1,2,3]), 1:"1", "1":1, "-"*512:"="*512}


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
    elif isinstance(content, object) and hasattr(content, "__dict__"):
        all_hash += allhash(content.__dict__)
    return all_hash

class NewBase(object):
    def __init__(self):
        self.name = "NewBase"
        self.number = 12345678
        self.fnumber = 1.2345678
        self.t_000000000000000000000000000000000000000000000000000000 = ()
        self.l_000000000000000000000000000000000000000000000000000000 = []
        self.d_000000000000000000000000000000000000000000000000000000 = {}
        self.s_000000000000000000000000000000000000000000000000000000 = set()
        self.l_1 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
        self.t_1 = tuple(self.l_1)
        self.s_1 = set(self.l_1)
        self.d_1 = {():[], (1,2,3):set([1,2,3]), 1:"1", "1":1, "-"*512:"="*512}

class NewMeddle1(NewBase):
    def __init__(self):
        super(NewMeddle1, self).__init__()
        self.name = "NewMiddle1"
        self.mt_1 = (1,2,3)

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
        self.t_000000000000000000000000000000000000000000000000000000 = ()
        self.l_000000000000000000000000000000000000000000000000000000 = []
        self.d_000000000000000000000000000000000000000000000000000000 = {}
        self.s_000000000000000000000000000000000000000000000000000000 = set()
        self.l_1 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
        self.t_1 = tuple(self.l_1)
        self.s_1 = set(self.l_1)
        self.d_1 = {():[], (1,2,3):set([1,2,3]), 1:"1", "1":1, "-"*512:"="*512}

class OldMeddle1(OldBase):
    def __init__(self):
        OldBase.__init__(self)
        self.name = "OldMiddle1"
        self.mt_1 = (1,2,3)

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
    assert allhash(data) == allhash(tun)

#import code
#code.interact(banner="", local=locals())

def test_many():
    import sys
    if True:
        for j in xrange(1000):
            pymsgpack_data(sometuple_0)
            pymsgpack_data(sometuple_1)
            pymsgpack_data(somelist_0)
            pymsgpack_data(somelist_1)
            pymsgpack_data(somedict_0)
            pymsgpack_data(somedict_1)
            pymsgpack_data(someset_0)
            pymsgpack_data(someset_1)
            pymsgpack_data(NewChild("new"))
            pymsgpack_data(OldChild("old"))
