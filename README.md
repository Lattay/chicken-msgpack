msgpack
=============================================

An implementation of [MessagePack](http://msgpack.org/) for [CHICKEN scheme v5](https://www.call-cc.org/).

Forked from [msgpack-scheme](http://github.com/hugoArregui/msgpack-scheme) and partially rewritten
(ported to CHICKEN 5 and cleaned up).
I kept the original license and most of the original API. However the byte-blob have been replaced with
Chicken 5 native blob.

Requirements
------------
This package requires the following eggs:
- matchable
- srfi-1
- srfi-69

Installation
------------
Through `Chicken egg repository`:
Run `chicken-install -s msgpack` anywhere.

From source:
First install the required eggs listed above.
Then clone this [repository](https://github.com/Lattay/chicken-msgpack).
Finally run `chicken-install -s` in the root of this repository.

API Specification
-----------------

Primitive pack-family procedures:

```scheme
(pack-uint port value)
(pack-sint port value)
(pack-float port FLONUM)
(pack-double port FLONUM)
(pack-bin port BLOB)  ; chicken.blob byte blob
(pack-str port STRING)     ; string
(pack-array port VECTOR)   ; vector
(pack-map port HASH-TABLE) ; hash-table
(pack-ext port EXT)        ; extension (see below)
```

Also the simplest way to use is to use the generic procedures:

```scheme
(pack port value)
(pack/blob value)
```

These procedures will call primitive type packers, with the following rules:
- if the value has a packer, apply it.
- if the value is a string, it will be packed as str.
- if the value is a blob, it will be packed as bin.
- if the value is a char, it will be packed as a uint.
- if the value is a list, it will be packed as an array.
- if the value is a extension (see below), it will be packed as an ext

The `/blob` version return a blob of packed data, the others directly write it to the port.

Unpack procedures:
```scheme
(unpack port [mapper])
(unpack/blob blob [mapper])
```
The optional mapper argument is applied to the output before returning.
The `/blob` version unpack the content of blob instead of reading from a port.


Extension
---------

Extension is a record defined as:

```
(define-record extension type data)
```

- type: integer from 0 to 127
- data: a blob

Example:

```scheme
(make-extension 10 (string->byte-blob "hi"))
```


License
-------

Distributed under the New BSD License.
