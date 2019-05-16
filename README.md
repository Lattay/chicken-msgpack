MessagePack implementation for CHICKEN scheme
=============================================

An implementation of [MessagePack](http://msgpack.org/) for [CHICKEN scheme](https://www.call-cc.org/).

Recently ported to CHICKEN 5 and cleaned up.

Requirements
------------
This package require this eggs:
- matchable
- srfi-1
- srfi-69

Installation
------------
Until I publish it to the eggs index the simplest way to install this is to clone
this repository and run `chicken-install -s` inside it.

API Specification
-----------------

Primitive pack-family procedures:

```scheme
(pack-uint port value)
(pack-sint port value)
(pack-float port FLONUM)
(pack-double port FLONUM)
(pack-bin port BYTE-BLOB)  ; byte-blob
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

The /blob version return a blob of packed data, the others directly write it to the port.

Unpack procedures:
```scheme
(unpack port [mapper])
(unpack/blob blob [mapper])
```
The optional mapper argument is applied to the output before returning.
The /blob version unpack the content of blob instead of reading from a port.
Extension
---------

Extension is record defined as:

```
- type: integer from 0 to 127
- data: a blob

(define-record extension type data)
```

Example:

```scheme
(make-extension 10 (string->byte-blob "hi"))
```


License
-------

Distributed under the New BSD License.
