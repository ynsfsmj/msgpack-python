# coding: utf-8
#cython: embedsignature=True

# 现在我们��? pymsgpack 支持简单的 Python 对象的序列化
# msgpack 中的 0xc1 类型保留无用，我们拿过来作为自定义的类型头前缀
# 我们的自定义头命名为 diy，第一个字节为 0xc1
# diy 的第二个字节表示子类型，定义如下��?
# 0x00: tuple
# 0x01: set (frozenset will be treated as set now)
# 0x10: object
# 外部沿用 msgpack.packb/unpackb 接口，因此不采用定义 default 函数的方法，而是在内部实现��?

from cpython cimport *
from collections import namedtuple

cdef __init__():
    pass

class ExtType(namedtuple('ExtType', 'code data')):
    """ExtType represents ext type in msgpack."""
    def __new__(cls, code, data):
        if not isinstance(code, int):
            raise TypeError("code must be int")
        if not isinstance(data, bytes):
            raise TypeError("data must be bytes")
        if not 0 <= code <= 127:
            raise ValueError("code must be 0~127")
        return super(ExtType, cls).__new__(cls, code, data)

class UnpackException(Exception):
    """Deprecated.  Use Exception instead to catch all exception during unpacking."""


class BufferFull(UnpackException):
    pass


class OutOfData(UnpackException):
    pass


class UnpackValueError(UnpackException, ValueError):
    """Deprecated.  Use ValueError instead."""


class ExtraData(UnpackValueError):
    def __init__(self, unpacked, extra):
        self.unpacked = unpacked
        self.extra = extra

    def __str__(self):
        return "unpack(b) received extra data."


class PackException(Exception):
    """Deprecated.  Use Exception instead to catch all exception during packing."""


class PackValueError(PackException, ValueError):
    """PackValueError is raised when type of input data is supported but it's value is unsupported.

    Deprecated.  Use ValueError instead.
    """


class PackOverflowError(PackValueError, OverflowError):
    """PackOverflowError is raised when integer value is out of range of msgpack support [-2**31, 2**32).

    Deprecated.  Use ValueError instead.
    """

################################
# packer

cdef defaultPacker = Packer()

def packbarg(o, **kwargs):
    return Packer(**kwargs).pack(o)

packb = defaultPacker.pack

cdef extern from "Python.h":

    int PyMemoryView_Check(object obj)
    int PySet_Check(object obj)
    int PySet_CheckExact(object obj)

cdef extern from "pack.h":
    struct msgpack_packer:
        char* buf
        size_t length
        size_t buf_size
        bint use_bin_type

    int msgpack_pack_int(msgpack_packer* pk, int d)
    int msgpack_pack_nil(msgpack_packer* pk)
    int msgpack_pack_true(msgpack_packer* pk)
    int msgpack_pack_false(msgpack_packer* pk)
    int msgpack_pack_long(msgpack_packer* pk, long d)
    int msgpack_pack_long_long(msgpack_packer* pk, long long d)
    int msgpack_pack_unsigned_long_long(msgpack_packer* pk, unsigned long long d)
    int msgpack_pack_float(msgpack_packer* pk, float d)
    int msgpack_pack_double(msgpack_packer* pk, double d)
    int msgpack_pack_array(msgpack_packer* pk, size_t l)
    int msgpack_pack_tuple(msgpack_packer* pk, size_t l)
    int msgpack_pack_set(msgpack_packer* pk, size_t l)
    int msgpack_pack_object(msgpack_packer* pk)
    int msgpack_pack_map(msgpack_packer* pk, size_t l)
    int msgpack_pack_raw(msgpack_packer* pk, size_t l)
    int msgpack_pack_bin(msgpack_packer* pk, size_t l)
    int msgpack_pack_raw_body(msgpack_packer* pk, char* body, size_t l)
    int msgpack_pack_ext(msgpack_packer* pk, char typecode, size_t l)

cdef int DEFAULT_RECURSE_LIMIT=16
cdef size_t ITEM_LIMIT = (2**32)-1
cdef size_t MODULE_CLASS_NAME_LIMIT = 128


cdef class Packer(object):
    """
    MessagePack Packer

    usage::

        packer = Packer()
        astream.write(packer.pack(a))
        astream.write(packer.pack(b))

    Packer's constructor has some keyword arguments:

    :param callable default:
        Convert user type to builtin type that Packer supports.
        See also simplejson's document.
    :param str encoding:
        Convert unicode to bytes with this encoding. (default: 'utf-8')
    :param str unicode_errors:
        Error handler for encoding unicode. (default: 'strict')
    :param bool autoreset:
        Reset buffer after each pack and return it's content as `bytes`. (default: True).
        If set this to false, use `bytes()` to get content and `.reset()` to clear buffer.
    :param bool use_bin_type:
        Use bin type introduced in msgpack spec 2.0 for bytes.
        It also enable str8 type for unicode.
    :param bool compatible_mode:
        If set to true, use pure msgpack protocol, so we don't support diy types (set, tuple, instance...) with this mode. 
        default False.
    """
    cdef msgpack_packer pk
    cdef object _default
    cdef object _bencoding
    cdef object _berrors
    cdef char *encoding
    cdef char *unicode_errors
    cdef bint compatible_mode
    cdef bool use_float
    cdef bint autoreset

    def __cinit__(self):
        cdef int buf_size = 1024*1024
        self.pk.buf = <char*> PyMem_Malloc(buf_size)
        if self.pk.buf == NULL:
            raise MemoryError("Unable to allocate internal buffer.")
        self.pk.buf_size = buf_size
        self.pk.length = 0

    def __init__(self, default=None, encoding='utf-8', unicode_errors='strict',
                 bint autoreset=1, bint use_bin_type=0,
                 bint compatible_mode=0):
        self.compatible_mode = compatible_mode
        self.autoreset = autoreset
        self.pk.use_bin_type = use_bin_type
        if default is not None:
            if not PyCallable_Check(default):
                raise TypeError("default must be a callable.")
        self._default = default
        if encoding is None:
            self.encoding = NULL
            self.unicode_errors = NULL
        else:
            if isinstance(encoding, unicode):
                self._bencoding = encoding.encode('ascii')
            else:
                self._bencoding = encoding
            self.encoding = PyBytes_AsString(self._bencoding)
            if isinstance(unicode_errors, unicode):
                self._berrors = unicode_errors.encode('ascii')
            else:
                self._berrors = unicode_errors
            self.unicode_errors = PyBytes_AsString(self._berrors)

    def __dealloc__(self):
        PyMem_Free(self.pk.buf)
        self.pk.buf = NULL

    cdef int _pack(self, object o, int nest_limit=DEFAULT_RECURSE_LIMIT, int ignore_basic=0) except -1:
        cdef long long llval
        cdef unsigned long long ullval
        cdef long longval
        cdef double dval
        cdef char* rawval
        cdef char* rawval2
        cdef int ret
        cdef size_t L
        cdef size_t mnl
        cdef size_t cnl
        cdef int default_used = 0
        cdef bint compatible_mode = self.compatible_mode
        cdef Py_buffer view

        if nest_limit < 0:
            raise PackValueError("recursion limit exceeded.")

        while True:
            if not ignore_basic:
                if PyLong_Check(o):
                    # PyInt_Check(long) is True for Python 3.
                    # So we should test long before int.
                    try:
                        if o > 0:
                            ullval = o
                            ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                        else:
                            llval = o
                            ret = msgpack_pack_long_long(&self.pk, llval)
                    except OverflowError as oe:
                        if self._default is not None:
                            self._pack(self._default(o), nest_limit-1)
                        else:
                            raise PackOverflowError("Integer value out of range")
                    return 0
                elif PyInt_Check(o):
                    longval = o
                    msgpack_pack_long(&self.pk, longval)
                    return 0
                elif PyFloat_Check(o):
                    dval = o
                    msgpack_pack_double(&self.pk, dval)
                    return 0
                elif PyBytes_Check(o):
                    L = len(o)
                    if L > ITEM_LIMIT:
                        raise PackValueError("bytes is too large")
                    rawval = o
                    msgpack_pack_bin(&self.pk, L)
                    msgpack_pack_raw_body(&self.pk, rawval, L)
                    return 0
                elif o is None:
                    ret = msgpack_pack_nil(&self.pk)
                    return 0
                elif isinstance(o, bool):
                    if o:
                        msgpack_pack_true(&self.pk)
                    else:
                        msgpack_pack_false(&self.pk)
                    return 0
                elif PyUnicode_Check(o):
                    if not self.encoding:
                        raise TypeError("Can't encode unicode string: no encoding is specified")
                    o = PyUnicode_AsEncodedString(o, self.encoding, self.unicode_errors)
                    L = len(o)
                    if L > ITEM_LIMIT:
                        raise PackValueError("unicode string is too large")
                    rawval = o
                    msgpack_pack_raw(&self.pk, L)
                    msgpack_pack_raw_body(&self.pk, rawval, L)
                    return 0

            if type(o) is ExtType and isinstance(o, ExtType):
                # This should be before Tuple because ExtType is namedtuple.
                longval = o.code
                rawval = o.data
                L = len(o.data)
                if L > ITEM_LIMIT:
                    raise PackValueError("EXT data is too large")
                msgpack_pack_ext(&self.pk, longval, L)
                msgpack_pack_raw_body(&self.pk, rawval, L)

            elif PyDict_CheckExact(o) or (compatible_mode and PyDict_Check(o)):
                L = len(o)
                if L > ITEM_LIMIT:
                    raise PackValueError("dict is too large")
                msgpack_pack_map(&self.pk, L)
                for k, val in o.iteritems():
                    #########
                    v = k
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    v = val
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    #########
            elif PyList_CheckExact(o) or (compatible_mode and (PyList_Check(o) or PyTuple_Check(o))):
                L = len(o)
                if L > ITEM_LIMIT:
                    raise PackValueError("list is too large")
                msgpack_pack_array(&self.pk, L)
                for v in o:
                    #########
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    #########
            elif not compatible_mode and PyTuple_CheckExact(o):
                L = len(o)
                if L > ITEM_LIMIT:
                    raise PackValueError("tuple is too large")
                msgpack_pack_tuple(&self.pk, L)
                msgpack_pack_array(&self.pk, L)
                for v in o:
                    #########
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    #########
            elif not compatible_mode and PySet_CheckExact(o):
                L = len(o)
                if L > ITEM_LIMIT:
                    raise PackValueError("set is too large")
                msgpack_pack_set(&self.pk, L)
                msgpack_pack_array(&self.pk, L)
                for v in o:
                    #########
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    #########
            elif PyMemoryView_Check(o):
                if PyObject_GetBuffer(o, &view, PyBUF_SIMPLE) != 0:
                    raise PackValueError("could not get buffer for memoryview")
                L = view.len
                if L > ITEM_LIMIT:
                    PyBuffer_Release(&view);
                    raise PackValueError("memoryview is too large")
                msgpack_pack_bin(&self.pk, L)
                msgpack_pack_raw_body(&self.pk, <char*>view.buf, L)
                PyBuffer_Release(&view);
            elif not default_used and self._default:
                o = self._default(o)
                default_used = 1
                continue
            #elif PyInstance_Check(o) or isinstance(o, object):
            elif not compatible_mode and (PyInstance_Check(o) or (PyObject_IsInstance(o, object) and PyObject_HasAttr(o, "__dict__"))):
                mnl = len(o.__module__)
                cnl = len(o.__class__.__name__)
                d = <dict>o.__dict__
                L = len(d)
                if L > ITEM_LIMIT:
                    raise PackValueError("object is too large")
                if mnl >= MODULE_CLASS_NAME_LIMIT or cnl >= MODULE_CLASS_NAME_LIMIT or mnl <= 0 or cnl <= 0:
                    # we limit the name length to less than 128 to make sure the bin type is (0xc4)
                    raise PackValueError("module name or class name is too large" % (o.__module__, o.__class__.__name__))
                rawval = o.__module__
                rawval2 = o.__class__.__name__
                msgpack_pack_object(&self.pk)
                msgpack_pack_bin(&self.pk, mnl);
                msgpack_pack_raw_body(&self.pk, rawval, mnl);
                msgpack_pack_bin(&self.pk, cnl);
                msgpack_pack_raw_body(&self.pk, rawval2, cnl);
                msgpack_pack_map(&self.pk, L);
                for k, val in d.iteritems():
                    #########
                    v = k
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    v = val
                    if PyLong_Check(v):
                        try:
                            if v > 0:
                                ullval = v
                                ret = msgpack_pack_unsigned_long_long(&self.pk, ullval)
                            else:
                                llval = v
                                ret = msgpack_pack_long_long(&self.pk, llval)
                        except OverflowError as oe:
                            if self._default is not None:
                                self._pack(self._default(v), nest_limit-1)
                            else:
                                raise PackOverflowError("Integer value out of range")
                    elif PyInt_Check(v):
                        longval = v
                        msgpack_pack_long(&self.pk, longval)
                    elif PyFloat_Check(v):
                        dval = v
                        msgpack_pack_double(&self.pk, dval)
                    elif PyBytes_Check(v):
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("bytes is too large")
                        rawval = v
                        msgpack_pack_bin(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    elif v is None:
                        ret = msgpack_pack_nil(&self.pk)
                    elif isinstance(v, bool):
                        if v:
                            msgpack_pack_true(&self.pk)
                        else:
                            msgpack_pack_false(&self.pk)
                    elif PyUnicode_Check(v):
                        if not self.encoding:
                            raise TypeError("Can't encode unicode string: no encoding is specified")
                        v = PyUnicode_AsEncodedString(v, self.encoding, self.unicode_errors)
                        L = len(v)
                        if L > ITEM_LIMIT:
                            raise PackValueError("unicode string is too large")
                        rawval = v
                        msgpack_pack_raw(&self.pk, L)
                        msgpack_pack_raw_body(&self.pk, rawval, L)
                    else:
                        self._pack(v, nest_limit-1, 1)
                    #########
            else:
                raise TypeError("can't serialize %r" % (o,))
            return 0

    cpdef pack(self, object obj):
        cdef int ret
        ret = self._pack(obj, DEFAULT_RECURSE_LIMIT)
        if ret == -1:
            raise MemoryError
        elif ret:  # should not happen.
            raise TypeError
        if self.autoreset:
            buf = PyBytes_FromStringAndSize(self.pk.buf, self.pk.length)
            self.pk.length = 0
            return buf

    def pack_ext_type(self, typecode, data):
        msgpack_pack_ext(&self.pk, typecode, len(data))
        msgpack_pack_raw_body(&self.pk, data, len(data))

    def pack_array_header(self, long long size):
        if size > ITEM_LIMIT:
            raise PackValueError
        cdef int ret = msgpack_pack_array(&self.pk, size)
        if ret == -1:
            raise MemoryError
        elif ret:  # should not happen
            raise TypeError
        if self.autoreset:
            buf = PyBytes_FromStringAndSize(self.pk.buf, self.pk.length)
            self.pk.length = 0
            return buf

    def pack_map_header(self, long long size):
        if size > ITEM_LIMIT:
            raise PackValueError
        cdef int ret = msgpack_pack_map(&self.pk, size)
        if ret == -1:
            raise MemoryError
        elif ret:  # should not happen
            raise TypeError
        if self.autoreset:
            buf = PyBytes_FromStringAndSize(self.pk.buf, self.pk.length)
            self.pk.length = 0
            return buf

    def pack_map_pairs(self, object pairs):
        """
        Pack *pairs* as msgpack map type.

        *pairs* should sequence of pair.
        (`len(pairs)` and `for k, v in pairs:` should be supported.)
        """
        cdef int ret = msgpack_pack_map(&self.pk, len(pairs))
        if ret == 0:
            for k, v in pairs:
                ret = self._pack(k)
                if ret != 0: break
                ret = self._pack(v)
                if ret != 0: break
        if ret == -1:
            raise MemoryError
        elif ret:  # should not happen
            raise TypeError
        if self.autoreset:
            buf = PyBytes_FromStringAndSize(self.pk.buf, self.pk.length)
            self.pk.length = 0
            return buf


    def reset(self):
        """Clear internal buffer."""
        self.pk.length = 0

    def bytes(self):
        """Return buffer content."""
        return PyBytes_FromStringAndSize(self.pk.buf, self.pk.length)


from cpython.bytes cimport (
    PyBytes_AsString,
    PyBytes_FromStringAndSize,
    PyBytes_Size,
)
from cpython.buffer cimport (
    Py_buffer,
    PyObject_CheckBuffer,
    PyObject_GetBuffer,
    PyBuffer_Release,
    PyBuffer_IsContiguous,
    PyBUF_READ,
    PyBUF_SIMPLE,
    PyBUF_FULL_RO,
)
from cpython.mem cimport PyMem_Malloc, PyMem_Free
from cpython.object cimport PyCallable_Check
from cpython.ref cimport Py_DECREF
from cpython.exc cimport PyErr_WarnEx

cdef extern from "Python.h":
    ctypedef struct PyObject
    cdef int PyObject_AsReadBuffer(object o, const void** buff, Py_ssize_t* buf_len) except -1
    object PyMemoryView_GetContiguous(object obj, int buffertype, char order)

from libc.stdlib cimport *
from libc.string cimport *
from libc.limits cimport *

cdef extern from "unpack.h":
    ctypedef struct msgpack_user:
        bint use_list
        PyObject* object_hook
        bint has_pairs_hook # call object_hook with k-v pairs
        PyObject* list_hook
        PyObject* ext_hook
        char *encoding
        char *unicode_errors
        Py_ssize_t max_str_len
        Py_ssize_t max_bin_len
        Py_ssize_t max_array_len
        Py_ssize_t max_map_len
        Py_ssize_t max_ext_len

    ctypedef struct unpack_context:
        msgpack_user user
        PyObject* obj
        Py_ssize_t count

    ctypedef int (*execute_fn)(unpack_context* ctx, const char* data,
                               Py_ssize_t len, Py_ssize_t* off) except? -1
    execute_fn unpack_construct
    execute_fn unpack_skip
    execute_fn read_array_header
    execute_fn read_map_header
    void unpack_init(unpack_context* ctx)
    object unpack_data(unpack_context* ctx)
    void unpack_clear(unpack_context* ctx)

cdef inline init_ctx(unpack_context *ctx,
                     object object_hook, object object_pairs_hook,
                     object list_hook, object ext_hook,
                     bint use_list, char* encoding, char* unicode_errors,
                     Py_ssize_t max_str_len, Py_ssize_t max_bin_len,
                     Py_ssize_t max_array_len, Py_ssize_t max_map_len,
                     Py_ssize_t max_ext_len):
    unpack_init(ctx)
    ctx.user.use_list = use_list
    ctx.user.object_hook = ctx.user.list_hook = <PyObject*>NULL
    ctx.user.max_str_len = max_str_len
    ctx.user.max_bin_len = max_bin_len
    ctx.user.max_array_len = max_array_len
    ctx.user.max_map_len = max_map_len
    ctx.user.max_ext_len = max_ext_len

    if object_hook is not None and object_pairs_hook is not None:
        raise TypeError("object_pairs_hook and object_hook are mutually exclusive.")

    if object_hook is not None:
        if not PyCallable_Check(object_hook):
            raise TypeError("object_hook must be a callable.")
        ctx.user.object_hook = <PyObject*>object_hook

    if object_pairs_hook is None:
        ctx.user.has_pairs_hook = False
    else:
        if not PyCallable_Check(object_pairs_hook):
            raise TypeError("object_pairs_hook must be a callable.")
        ctx.user.object_hook = <PyObject*>object_pairs_hook
        ctx.user.has_pairs_hook = True

    if list_hook is not None:
        if not PyCallable_Check(list_hook):
            raise TypeError("list_hook must be a callable.")
        ctx.user.list_hook = <PyObject*>list_hook

    if ext_hook is not None:
        if not PyCallable_Check(ext_hook):
            raise TypeError("ext_hook must be a callable.")
        ctx.user.ext_hook = <PyObject*>ext_hook

    ctx.user.encoding = encoding
    ctx.user.unicode_errors = unicode_errors

def default_read_extended_type(typecode, data):
    raise NotImplementedError("Cannot decode extended type with typecode=%d" % typecode)

cdef inline int get_data_from_buffer(object obj,
                                     Py_buffer *view,
                                     char **buf,
                                     Py_ssize_t *buffer_len,
                                     int *new_protocol) except 0:
    cdef object contiguous
    cdef Py_buffer tmp
    if PyObject_CheckBuffer(obj):
        new_protocol[0] = 1
        if PyObject_GetBuffer(obj, view, PyBUF_FULL_RO) == -1:
            raise
        if view.itemsize != 1:
            PyBuffer_Release(view)
            raise BufferError("cannot unpack from multi-byte object")
        if PyBuffer_IsContiguous(view, 'A') == 0:
            PyBuffer_Release(view)
            # create a contiguous copy and get buffer
            contiguous = PyMemoryView_GetContiguous(obj, PyBUF_READ, 'C')
            PyObject_GetBuffer(contiguous, view, PyBUF_SIMPLE)
            # view must hold the only reference to contiguous,
            # so memory is freed when view is released
            Py_DECREF(contiguous)
        buffer_len[0] = view.len
        buf[0] = <char*> view.buf
        return 1
    else:
        new_protocol[0] = 0
        if PyObject_AsReadBuffer(obj, <const void**> buf, buffer_len) == -1:
            raise BufferError("could not get memoryview")
        PyErr_WarnEx(RuntimeWarning,
                     "using old buffer interface to unpack %s; "
                     "this leads to unpacking errors if slicing is used and "
                     "will be removed in a future version" % type(obj),
                     1)
        return 1

def unpackb(object packed, object object_hook=None, object list_hook=None,
            bint use_list=1, encoding=None, unicode_errors="strict",
            object_pairs_hook=None, ext_hook=ExtType,
            Py_ssize_t max_str_len=2147483647, # 2**32-1
            Py_ssize_t max_bin_len=2147483647,
            Py_ssize_t max_array_len=2147483647,
            Py_ssize_t max_map_len=2147483647,
            Py_ssize_t max_ext_len=2147483647):
    """
    Unpack packed_bytes to object. Returns an unpacked object.

    Raises `ValueError` when `packed` contains extra bytes.

    See :class:`Unpacker` for options.
    """
    cdef unpack_context ctx
    cdef Py_ssize_t off = 0
    cdef int ret

    cdef Py_buffer view
    cdef char* buf = NULL
    cdef Py_ssize_t buf_len
    cdef char* cenc = NULL
    cdef char* cerr = NULL
    cdef int new_protocol = 0

    get_data_from_buffer(packed, &view, &buf, &buf_len, &new_protocol)

    try:
        if encoding is not None:
            if isinstance(encoding, unicode):
                encoding = encoding.encode('ascii')
            cenc = PyBytes_AsString(encoding)

        if unicode_errors is not None:
            if isinstance(unicode_errors, unicode):
                unicode_errors = unicode_errors.encode('ascii')
            cerr = PyBytes_AsString(unicode_errors)

        init_ctx(&ctx, object_hook, object_pairs_hook, list_hook, ext_hook,
                 use_list, cenc, cerr,
                 max_str_len, max_bin_len, max_array_len, max_map_len, max_ext_len)
        ret = unpack_construct(&ctx, buf, buf_len, &off)
    finally:
        if new_protocol:
            PyBuffer_Release(&view);

    if ret == 1:
        obj = unpack_data(&ctx)
        if off < buf_len:
            raise ExtraData(obj, PyBytes_FromStringAndSize(buf+off, buf_len-off))
        return obj
    unpack_clear(&ctx)
    raise UnpackValueError("Unpack failed: error = %d" % (ret,))


def unpack(object stream, object object_hook=None, object list_hook=None,
           bint use_list=1, encoding=None, unicode_errors="strict",
           object_pairs_hook=None, ext_hook=ExtType,
           Py_ssize_t max_str_len=2147483647, # 2**32-1
           Py_ssize_t max_bin_len=2147483647,
           Py_ssize_t max_array_len=2147483647,
           Py_ssize_t max_map_len=2147483647,
           Py_ssize_t max_ext_len=2147483647):
    """
    Unpack an object from `stream`.

    Raises `ValueError` when `stream` has extra bytes.

    See :class:`Unpacker` for options.
    """
    return unpackb(stream.read(), use_list=use_list,
                   object_hook=object_hook, object_pairs_hook=object_pairs_hook, list_hook=list_hook,
                   encoding=encoding, unicode_errors=unicode_errors, ext_hook=ext_hook,
                   max_str_len=max_str_len,
                   max_bin_len=max_bin_len,
                   max_array_len=max_array_len,
                   max_map_len=max_map_len,
                   max_ext_len=max_ext_len,
                   )


cdef class Unpacker(object):
    """Streaming unpacker.

    arguments:

    :param file_like:
        File-like object having `.read(n)` method.
        If specified, unpacker reads serialized data from it and :meth:`feed()` is not usable.

    :param int read_size:
        Used as `file_like.read(read_size)`. (default: `min(1024**2, max_buffer_size)`)

    :param bool use_list:
        If true, unpack msgpack array to Python list.
        Otherwise, unpack to Python tuple. (default: True)

    :param callable object_hook:
        When specified, it should be callable.
        Unpacker calls it with a dict argument after unpacking msgpack map.
        (See also simplejson)

    :param callable object_pairs_hook:
        When specified, it should be callable.
        Unpacker calls it with a list of key-value pairs after unpacking msgpack map.
        (See also simplejson)

    :param str encoding:
        Encoding used for decoding msgpack raw.
        If it is None (default), msgpack raw is deserialized to Python bytes.

    :param str unicode_errors:
        Used for decoding msgpack raw with *encoding*.
        (default: `'strict'`)

    :param int max_buffer_size:
        Limits size of data waiting unpacked.  0 means system's INT_MAX (default).
        Raises `BufferFull` exception when it is insufficient.
        You shoud set this parameter when unpacking data from untrusted source.

    :param int max_str_len:
        Limits max length of str. (default: 2**31-1)

    :param int max_bin_len:
        Limits max length of bin. (default: 2**31-1)

    :param int max_array_len:
        Limits max length of array. (default: 2**31-1)

    :param int max_map_len:
        Limits max length of map. (default: 2**31-1)


    example of streaming deserialize from file-like object::

        unpacker = Unpacker(file_like)
        for o in unpacker:
            process(o)

    example of streaming deserialize from socket::

        unpacker = Unpacker()
        while True:
            buf = sock.recv(1024**2)
            if not buf:
                break
            unpacker.feed(buf)
            for o in unpacker:
                process(o)
    """
    cdef unpack_context ctx
    cdef char* buf
    cdef Py_ssize_t buf_size, buf_head, buf_tail
    cdef object file_like
    cdef object file_like_read
    cdef Py_ssize_t read_size
    # To maintain refcnt.
    cdef object object_hook, object_pairs_hook, list_hook, ext_hook
    cdef object encoding, unicode_errors
    cdef Py_ssize_t max_buffer_size

    def __cinit__(self):
        self.buf = NULL

    def __dealloc__(self):
        PyMem_Free(self.buf)
        self.buf = NULL

    def __init__(self, file_like=None, Py_ssize_t read_size=0, bint use_list=1,
                 object object_hook=None, object object_pairs_hook=None, object list_hook=None,
                 encoding=None, unicode_errors='strict', int max_buffer_size=0,
                 object ext_hook=ExtType,
                 Py_ssize_t max_str_len=2147483647, # 2**32-1
                 Py_ssize_t max_bin_len=2147483647,
                 Py_ssize_t max_array_len=2147483647,
                 Py_ssize_t max_map_len=2147483647,
                 Py_ssize_t max_ext_len=2147483647):
        cdef char *cenc=NULL,
        cdef char *cerr=NULL

        self.object_hook = object_hook
        self.object_pairs_hook = object_pairs_hook
        self.list_hook = list_hook
        self.ext_hook = ext_hook

        self.file_like = file_like
        if file_like:
            self.file_like_read = file_like.read
            if not PyCallable_Check(self.file_like_read):
                raise TypeError("`file_like.read` must be a callable.")
        if not max_buffer_size:
            max_buffer_size = INT_MAX
        if read_size > max_buffer_size:
            raise ValueError("read_size should be less or equal to max_buffer_size")
        if not read_size:
            read_size = min(max_buffer_size, 1024**2)
        self.max_buffer_size = max_buffer_size
        self.read_size = read_size
        self.buf = <char*>PyMem_Malloc(read_size)
        if self.buf == NULL:
            raise MemoryError("Unable to allocate internal buffer.")
        self.buf_size = read_size
        self.buf_head = 0
        self.buf_tail = 0

        if encoding is not None:
            if isinstance(encoding, unicode):
                self.encoding = encoding.encode('ascii')
            elif isinstance(encoding, bytes):
                self.encoding = encoding
            else:
                raise TypeError("encoding should be bytes or unicode")
            cenc = PyBytes_AsString(self.encoding)

        if unicode_errors is not None:
            if isinstance(unicode_errors, unicode):
                self.unicode_errors = unicode_errors.encode('ascii')
            elif isinstance(unicode_errors, bytes):
                self.unicode_errors = unicode_errors
            else:
                raise TypeError("unicode_errors should be bytes or unicode")
            cerr = PyBytes_AsString(self.unicode_errors)

        init_ctx(&self.ctx, object_hook, object_pairs_hook, list_hook,
                 ext_hook, use_list, cenc, cerr,
                 max_str_len, max_bin_len, max_array_len,
                 max_map_len, max_ext_len)

    def feed(self, object next_bytes):
        """Append `next_bytes` to internal buffer."""
        cdef Py_buffer pybuff
        cdef int new_protocol = 0
        cdef char* buf
        cdef Py_ssize_t buf_len

        if self.file_like is not None:
            raise AssertionError(
                    "unpacker.feed() is not be able to use with `file_like`.")

        get_data_from_buffer(next_bytes, &pybuff, &buf, &buf_len, &new_protocol)
        try:
            self.append_buffer(buf, buf_len)
        finally:
            if new_protocol:
                PyBuffer_Release(&pybuff)

    cdef append_buffer(self, void* _buf, Py_ssize_t _buf_len):
        cdef:
            char* buf = self.buf
            char* new_buf
            Py_ssize_t head = self.buf_head
            Py_ssize_t tail = self.buf_tail
            Py_ssize_t buf_size = self.buf_size
            Py_ssize_t new_size

        if tail + _buf_len > buf_size:
            if ((tail - head) + _buf_len) <= buf_size:
                # move to front.
                memmove(buf, buf + head, tail - head)
                tail -= head
                head = 0
            else:
                # expand buffer.
                new_size = (tail-head) + _buf_len
                if new_size > self.max_buffer_size:
                    raise BufferFull
                new_size = min(new_size*2, self.max_buffer_size)
                new_buf = <char*>PyMem_Malloc(new_size)
                if new_buf == NULL:
                    # self.buf still holds old buffer and will be freed during
                    # obj destruction
                    raise MemoryError("Unable to enlarge internal buffer.")
                memcpy(new_buf, buf + head, tail - head)
                PyMem_Free(buf)

                buf = new_buf
                buf_size = new_size
                tail -= head
                head = 0

        memcpy(buf + tail, <char*>(_buf), _buf_len)
        self.buf = buf
        self.buf_head = head
        self.buf_size = buf_size
        self.buf_tail = tail + _buf_len

    cdef read_from_file(self):
        next_bytes = self.file_like_read(
                min(self.read_size,
                    self.max_buffer_size - (self.buf_tail - self.buf_head)
                    ))
        if next_bytes:
            self.append_buffer(PyBytes_AsString(next_bytes), PyBytes_Size(next_bytes))
        else:
            self.file_like = None

    cdef object _unpack(self, execute_fn execute, object write_bytes, bint iter=0):
        cdef int ret
        cdef object obj
        cdef Py_ssize_t prev_head

        if self.buf_head >= self.buf_tail and self.file_like is not None:
            self.read_from_file()

        while 1:
            prev_head = self.buf_head
            if prev_head >= self.buf_tail:
                if iter:
                    raise StopIteration("No more data to unpack.")
                else:
                    raise OutOfData("No more data to unpack.")

            try:
                ret = execute(&self.ctx, self.buf, self.buf_tail, &self.buf_head)
                if write_bytes is not None:
                    write_bytes(PyBytes_FromStringAndSize(self.buf + prev_head, self.buf_head - prev_head))

                if ret == 1:
                    obj = unpack_data(&self.ctx)
                    unpack_init(&self.ctx)
                    return obj
                elif ret == 0:
                    if self.file_like is not None:
                        self.read_from_file()
                        continue
                    if iter:
                        raise StopIteration("No more data to unpack.")
                    else:
                        raise OutOfData("No more data to unpack.")
                else:
                    raise UnpackValueError("Unpack failed: error = %d" % (ret,))
            except ValueError as e:
                raise UnpackValueError(e)

    def read_bytes(self, Py_ssize_t nbytes):
        """Read a specified number of raw bytes from the stream"""
        cdef Py_ssize_t nread
        nread = min(self.buf_tail - self.buf_head, nbytes)
        ret = PyBytes_FromStringAndSize(self.buf + self.buf_head, nread)
        self.buf_head += nread
        if len(ret) < nbytes and self.file_like is not None:
            ret += self.file_like.read(nbytes - len(ret))
        return ret

    def unpack(self, object write_bytes=None):
        """Unpack one object

        If write_bytes is not None, it will be called with parts of the raw
        message as it is unpacked.

        Raises `OutOfData` when there are no more bytes to unpack.
        """
        return self._unpack(unpack_construct, write_bytes)

    def skip(self, object write_bytes=None):
        """Read and ignore one object, returning None

        If write_bytes is not None, it will be called with parts of the raw
        message as it is unpacked.

        Raises `OutOfData` when there are no more bytes to unpack.
        """
        return self._unpack(unpack_skip, write_bytes)

    def read_array_header(self, object write_bytes=None):
        """assuming the next object is an array, return its size n, such that
        the next n unpack() calls will iterate over its contents.

        Raises `OutOfData` when there are no more bytes to unpack.
        """
        return self._unpack(read_array_header, write_bytes)

    def read_map_header(self, object write_bytes=None):
        """assuming the next object is a map, return its size n, such that the
        next n * 2 unpack() calls will iterate over its key-value pairs.

        Raises `OutOfData` when there are no more bytes to unpack.
        """
        return self._unpack(read_map_header, write_bytes)

    def __iter__(self):
        return self

    def __next__(self):
        return self._unpack(unpack_construct, None, 1)

    # for debug.
    #def _buf(self):
    #    return PyString_FromStringAndSize(self.buf, self.buf_tail)

    #def _off(self):
    #    return self.buf_head
