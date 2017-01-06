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
    #print len(tp)
    tun = unpackb(tp)
    #print allhash(data), allhash(tun)
    #assert allhash(data) == allhash(tun)

def cpickle_data(data):
    tp = dumps(data, 2)
    #print len(tp)
    tun = loads(tp)
    #print allhash(data), allhash(tun)
    #assert allhash(data) == allhash(tun)

#import code
#code.interact(banner="", local=locals())

import time

def compare_all(times):
    somelist_0 = []
    somelist_1 = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50] * 5
    somelist_11 = [str(x) for x in somelist_1]
    somelist_111 = [x + 0.1 for x in somelist_1]
    somelist_2 = [1, 1234567890, "", "-", "-"*8, "-"*256, "-"*512, 1.1]
    sometuple_0 = tuple(somelist_0)
    sometuple_1 = tuple(somelist_1)
    sometuple_2 = tuple(somelist_2)
    someset_0 = set()
    someset_1 = set(somelist_1)
    someset_2 = set(somelist_2)
    somedict_0 = {}
    somedict_1 = {"1":1, "2":2, "3":3, "4":4, "5":5}
    somedict_2 = {2:(1,2,3,4,5,6,7), 1:(1,2,3), 1:"1", "1":1, "-"*512:"="*512}
    somedict_3 = {12032: 30, 12118: 0, 12033: 194, 10076: 0.0, 10071: 100, 12034: 395, 12121: 51, 12122: 0.04446481929146, 12123: 0.0, 10077: 0.0, 12124: 0.0, 12125: 0, 12128: 0.0, 12129: 0, 18000: 0, 18001: 0, 17001: 0, 17002: 0, 17003: 0, 17004: 0, 17005: 0, 17006: 0, 17007: 0, 17008: 0, 17009: 0, 17010: 0, 17011: 0, 17012: 0, 17013: 0, 17014: 0, 17015: 0.0, 17016: 0.0, 17017: 0.0, 17018: 0.0, 17019: 0.0, 17020: 0.0, 17021: 0.0, 16001: 75, 16002: 75, 16003: 0, 16004: 0, 16005: 0.5, 16006: 0.05, 16007: 0.0, 16008: 0.0, 16009: 0.0, 16010: 0, 16011: 0.0, 16012: 0.0, 16013: 0.0, 16014: 0.0, 16015: 0.0, 16016: 0.0, 16017: 0.0, 16018: 0, 16019: 90, 15001: 1.0, 15002: 1.0, 15003: 0.0, 15004: 0.0, 15005: 0.0, 15006: 0.0, 15007: 0.0, 15008: 0.0, 50010: 0, 14000: 0.0, 14001: 0.0, 14002: 0.0, 13001: 79, 13002: 158, 13003: 0.0, 13016: 0.0, 10066: 5, 12112: 0, 12010: 0, 12011: 0, 12012: 923, 12013: 1299, 12014: 0, 12015: 0, 12016: 416, 12017: 0.62783802048026, 12018: 408, 12019: 0.0, 12020: 174, 12021: 389, 12022: 0.0, 12023: 0.0, 11000: 7, 11001: 188, 11002: 218, 11003: 227, 11004: 13, 11005: 0, 11006: 0, 11007: 0, 11008: 0, 11009: 0, 11010: 0.0, 12035: 0.0, 12036: 0.0, 12037: 0.0, 12038: 0.0, 12039: 0.0, 12040: 341, 12041: 249, 12042: 0.0, 12113: 0.0, 10000: 1, 10001: 0, 10004: 0.0, 10005: 0.0, 10006: 0.0, 10007: 0.0, 10008: 96, 10009: 0, 52001: 0.0, 52002: 0.0, 52003: 0.0, 52004: 0.0, 52005: 0.0, 52006: 0.0, 52011: 0.0, 52012: 0.0, 52013: 0.0, 52014: 0.0, 52015: 0.0, 52016: 0.0, 51000: 4, 51001: 4, 51002: 4, 51003: 4, 51004: 4, 51005: 4, 51006: 4, 10050: 0, 10052: 0, 10053: 25797, 10054: 5917, 12103: 40, 12104: 0.33999999999999997, 12105: 451, 12106: 0.1, 10060: 0, 10061: 0.0, 10062: 25, 10063: 0.0, 10064: 1, 50001: 0, 12114: 42, 12115: 0.0, 12116: 766, 12117: 805, 10070: 0, 12119: 0.0, 12120: 0.7, 10073: 12.0, 10074: 5.0, 10075: 0.0, 50012: 0, 50013: 0, 12126: 0.0, 12127: 0, 10080: 337, 10081: 0, 12130: 0.0, 50019: 0, 50020: 2760, 50021: 0, 50022: 0, 10100: 0, 10101: 0, 50011: 2760, 10120: 3500, 10121: 3500, 10122: 0.0, 10123: 0.0, 12100: 2822, 10140: 0.0, 10141: 400.0, 10142: 0.0, 12101: 6601, 10144: 0, 10145: 0, 10146: 0, 10147: 0, 10148: 0, 10149: 0, 10150: 0.0, 10151: 300, 10152: 0, 10153: 300, 10154: 0, 10155: 0, 10143: 400.0, 12108: 0.0, 12109: 0.0, 12024: 0.01, 12025: 0.0, 12111: 0, 12026: 0.01482160592289, 50000: 1, 12027: 145, 10065: 0.0, 12028: 0.04, 50002: 0.0, 12029: 0.0, 10067: 0.0, 12030: 0.08, 12031: 0.0}
    litNew = NewBase()
    litOld = OldBase()
    bigNew = NewChild("bignew")
    bigOld = OldChild("bigold")

    compare_and_print(times * 5, sometuple_0,"tuple0")
    compare_and_print(times, sometuple_1,"tuple1")
    compare_and_print(times, sometuple_2,"tuple2")
    compare_and_print(times * 5, somelist_0, "list0 ")
    compare_and_print(times, somelist_1, "list1 ")
    compare_and_print(times, somelist_11, "list11 ")
    compare_and_print(times, somelist_111, "list111 ")
    compare_and_print(times, somelist_2, "list2 ")
    compare_and_print(times * 5, somedict_0, "dict0 ")
    compare_and_print(times, somedict_1, "dict1 ")
    compare_and_print(times, somedict_2, "dict2 ")
    compare_and_print(times, somedict_3, "dict3 ")
    compare_and_print(times * 5, someset_0,  "set0  ")
    compare_and_print(times, someset_1,  "set1  ")
    compare_and_print(times, someset_2,  "set2  ")
    compare_and_print(times * 5, litNew, "newobj1")
    compare_and_print(times * 5, litOld, "oldobj1")
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
    len1 = len(packb(data))
    len2 = len(dumps(data, 2))
    print name, "::\tpymsgpack:", int(t1 * 1000)/1000.0, "\tcpickle", int(t2 * 1000)/1000.0, "\tratio", t2/t1, "len:\t", len1, ":", len2

if __name__ == "__main__":
    compare_all(80000)
