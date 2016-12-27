=======================
PyMessagePack pymsgpack
=======================

with the same performance of msgpack but also support python objects, sets, tuples.

msgpack protocol is modified so that there is no supports for other languages, except using packb with compatible_mode = true.

This is modified from msgpack-python (described below).

Here is the benchmark results on my x64 server, each for 200000 times:
```
python performance.py 
datatype    pymsgpack time(s)   cpickle time(s) lifting ratio
tuple0 ::   pymsgpack: 0.174    cpickle 0.183   ratio 1.05559422069
tuple1 ::   pymsgpack: 0.239    cpickle 0.661   ratio 2.76297446233
tuple2 ::   pymsgpack: 0.374    cpickle 1.65    ratio 4.40260815435
list0  ::   pymsgpack: 0.152    cpickle 0.241   ratio 1.57958324045
list1  ::   pymsgpack: 0.234    cpickle 0.695   ratio 2.96769310226
list2  ::   pymsgpack: 0.394    cpickle 1.942   ratio 4.92129153318
dict0  ::   pymsgpack: 0.144    cpickle 0.238   ratio 1.64725146546
dict1  ::   pymsgpack: 0.358    cpickle 0.933   ratio 2.60197497112
dict2  ::   pymsgpack: 0.83     cpickle 3.383   ratio 4.07436514496
set0   ::   pymsgpack: 0.191    cpickle 1.041   ratio 5.43598605147
set1   ::   pymsgpack: 0.327    cpickle 1.518   ratio 4.63418349227
set2   ::   pymsgpack: 0.764    cpickle 3.151   ratio 4.12212838607
newobj1 ::  pymsgpack: 0.803    cpickle 3.296   ratio 4.1023097346
oldobj1 ::  pymsgpack: 0.744    cpickle 1.592   ratio 2.14006685093
newobj2 ::  pymsgpack: 7.386    cpickle 34.555  ratio 4.67847017069
oldobj2 ::  pymsgpack: 7.161    cpickle 27.415  ratio 3.82807841966
```

=======================
MessagePack for Python
=======================

:author: INADA Naoki
:version: 0.4.6
:date: 2015-03-13

.. image:: https://secure.travis-ci.org/msgpack/msgpack-python.svg
   :target: https://travis-ci.org/#!/msgpack/msgpack-python
   

What's this
------------

`MessagePack <http://msgpack.org/>`_ is a fast, compact binary serialization format, suitable for
similar data to JSON. This package provides CPython bindings for reading and
writing MessagePack data.

Install
---------

::

   $ pip install msgpack-python

PyPy
^^^^^

msgpack-python provides pure python implementation.  PyPy can use this.

Windows
^^^^^^^

When you can't use binary distribution, you need to install Visual Studio
or Windows SDK on Windows.
Without extension, using pure python implementation on CPython runs slowly.

For Python 2.7, `Microsoft Visual C++ Compiler for Python 2.7 <https://www.microsoft.com/en-us/download/details.aspx?id=44266>`_
is recommended solution.

For Python 3.5, `Microsoft Visual Studio 2015 <https://www.visualstudio.com/en-us/products/vs-2015-product-editions.aspx>`_
Community Edition or Express Edition can be used to build extension module.


How to use
-----------

One-shot pack & unpack
^^^^^^^^^^^^^^^^^^^^^^

Use ``packb`` for packing and ``unpackb`` for unpacking.
msgpack provides ``dumps`` and ``loads`` as alias for compatibility with
``json`` and ``pickle``.

``pack`` and ``dump`` packs to file-like object.
``unpack`` and ``load`` unpacks from file-like object.

.. code-block:: pycon

   >>> import msgpack
   >>> msgpack.packb([1, 2, 3])
   '\x93\x01\x02\x03'
   >>> msgpack.unpackb(_)
   [1, 2, 3]

``unpack`` unpacks msgpack's array to Python's list, but can unpack to tuple:

.. code-block:: pycon

   >>> msgpack.unpackb(b'\x93\x01\x02\x03', use_list=False)
   (1, 2, 3)

You should always pass the ``use_list`` keyword argument. See performance issues relating to `use_list option`_ below.

Read the docstring for other options.


Streaming unpacking
^^^^^^^^^^^^^^^^^^^

``Unpacker`` is a "streaming unpacker". It unpacks multiple objects from one
stream (or from bytes provided through its ``feed`` method).

.. code-block:: python

   import msgpack
   from io import BytesIO

   buf = BytesIO()
   for i in range(100):
      buf.write(msgpack.packb(range(i)))

   buf.seek(0)

   unpacker = msgpack.Unpacker(buf)
   for unpacked in unpacker:
       print unpacked


Packing/unpacking of custom data type
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

It is also possible to pack/unpack custom data types. Here is an example for
``datetime.datetime``.

.. code-block:: python

    import datetime

    import msgpack

    useful_dict = {
        "id": 1,
        "created": datetime.datetime.now(),
    }

    def decode_datetime(obj):
        if b'__datetime__' in obj:
            obj = datetime.datetime.strptime(obj["as_str"], "%Y%m%dT%H:%M:%S.%f")
        return obj

    def encode_datetime(obj):
        if isinstance(obj, datetime.datetime):
            return {'__datetime__': True, 'as_str': obj.strftime("%Y%m%dT%H:%M:%S.%f")}
        return obj


    packed_dict = msgpack.packb(useful_dict, default=encode_datetime)
    this_dict_again = msgpack.unpackb(packed_dict, object_hook=decode_datetime)

``Unpacker``'s ``object_hook`` callback receives a dict; the
``object_pairs_hook`` callback may instead be used to receive a list of
key-value pairs.

Extended types
^^^^^^^^^^^^^^^

It is also possible to pack/unpack custom data types using the **ext** type.

.. code-block:: pycon

    >>> import msgpack
    >>> import array
    >>> def default(obj):
    ...     if isinstance(obj, array.array) and obj.typecode == 'd':
    ...         return msgpack.ExtType(42, obj.tostring())
    ...     raise TypeError("Unknown type: %r" % (obj,))
    ...
    >>> def ext_hook(code, data):
    ...     if code == 42:
    ...         a = array.array('d')
    ...         a.fromstring(data)
    ...         return a
    ...     return ExtType(code, data)
    ...
    >>> data = array.array('d', [1.2, 3.4])
    >>> packed = msgpack.packb(data, default=default)
    >>> unpacked = msgpack.unpackb(packed, ext_hook=ext_hook)
    >>> data == unpacked
    True


Advanced unpacking control
^^^^^^^^^^^^^^^^^^^^^^^^^^

As an alternative to iteration, ``Unpacker`` objects provide ``unpack``,
``skip``, ``read_array_header`` and ``read_map_header`` methods. The former two
read an entire message from the stream, respectively deserialising and returning
the result, or ignoring it. The latter two methods return the number of elements
in the upcoming container, so that each element in an array, or key-value pair
in a map, can be unpacked or skipped individually.

Each of these methods may optionally write the packed data it reads to a
callback function:

.. code-block:: python

    from io import BytesIO

    def distribute(unpacker, get_worker):
        nelems = unpacker.read_map_header()
        for i in range(nelems):
            # Select a worker for the given key
            key = unpacker.unpack()
            worker = get_worker(key)

            # Send the value as a packed message to worker
            bytestream = BytesIO()
            unpacker.skip(bytestream.write)
            worker.send(bytestream.getvalue())


Notes
-----

string and binary type
^^^^^^^^^^^^^^^^^^^^^^

In old days, msgpack doesn't distinguish string and binary types like Python 1.
The type for represent string and binary types is named **raw**.

msgpack can distinguish string and binary type for now.  But it is not like Python 2.
Python 2 added unicode string.  But msgpack renamed **raw** to **str** and added **bin** type.
It is because keep compatibility with data created by old libs. **raw** was used for text more than binary.

Currently, while msgpack-python supports new **bin** type, default setting doesn't use it and
decodes **raw** as `bytes` instead of `unicode` (`str` in Python 3).

You can change this by using `use_bin_type=True` option in Packer and `encoding="utf-8"` option in Unpacker.

.. code-block:: pycon

    >>> import msgpack
    >>> packed = msgpack.packb([b'spam', u'egg'], use_bin_type=True)
    >>> msgpack.unpackb(packed, encoding='utf-8')
    ['spam', u'egg']

ext type
^^^^^^^^

To use **ext** type, pass ``msgpack.ExtType`` object to packer.

.. code-block:: pycon

    >>> import msgpack
    >>> packed = msgpack.packb(msgpack.ExtType(42, b'xyzzy'))
    >>> msgpack.unpackb(packed)
    ExtType(code=42, data='xyzzy')

You can use it with ``default`` and ``ext_hook``. See below.

Note for msgpack-python 0.2.x users
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The msgpack-python 0.3 have some incompatible changes.

The default value of ``use_list`` keyword argument is ``True`` from 0.3.
You should pass the argument explicitly for backward compatibility.

`Unpacker.unpack()` and some unpack methods now raises `OutOfData`
instead of `StopIteration`.
`StopIteration` is used for iterator protocol only.

Note about performance
------------------------

GC
^^

CPython's GC starts when growing allocated object.
This means unpacking may cause useless GC.
You can use ``gc.disable()`` when unpacking large message.

use_list option
^^^^^^^^^^^^^^^^
List is the default sequence type of Python.
But tuple is lighter than list.
You can use ``use_list=False`` while unpacking when performance is important.

Python's dict can't use list as key and MessagePack allows array for key of mapping.
``use_list=False`` allows unpacking such message.
Another way to unpacking such object is using ``object_pairs_hook``.


Development
------------

Test
^^^^

MessagePack uses `pytest` for testing.
Run test with following command:

    $ py.test


..
    vim: filetype=rst
