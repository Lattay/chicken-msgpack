;;;;; msgpack-imple.scm - MessagePack scheme implementation
;;
;;  Copyright (c) 2013, Hugo Arregui
;;  All rights reserved.
;;
;;  Redistribution and use in source and binary forms, with or without
;;  modification, are permitted provided that the following conditions
;;  are met:
;;  1. Redistributions of source code must retain the above copyright
;;     notice, this list of conditions and the following disclaimer.
;;  2. Redistributions in binary form must reproduce the above copyright
;;     notice, this list of conditions and the following disclaimer in the
;;     documentation and/or other materials provided with the distribution.
;;  3. The name of the authors may not be used to endorse or promote products
;;     derived from this software without specific prior written permission.
;;
;;  THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS OR
;;  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
;;  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
;;  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY DIRECT, INDIRECT,
;;  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
;;  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
;;  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
;;  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
;;  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
;;  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(import scheme
        chicken.bitwise
        chicken.blob
        chicken.format
        chicken.io
        chicken.port
        chicken.platform
        srfi-4)
(import srfi-1
        srfi-69
        matchable)

;; limits
(define fixed_uint_limit  127)
(define uint8_limit       (sub1 (expt 2 8)))
(define uint16_limit      (sub1 (expt 2 16)))
(define uint32_limit      (sub1 (expt 2 32)))
(define uint64_limit      (sub1 (expt 2 64)))
(define fixed_int_limit   -32)
(define int8_limit        (sub1 (- (expt 2 7))))
(define int16_limit       (sub1 (- (expt 2 15))))
(define int32_limit       (sub1 (- (expt 2 31))))
(define int64_limit       (sub1 (- (expt 2 63))))
(define int64_maxlimit    (sub1 (expt 2 63)))
(define fixed_raw_limit   31) ;in bytes
(define raw8_limit        (sub1 (expt 2 8)))
(define raw16_limit       (sub1 (expt 2 16)))
(define raw32_limit       (sub1 (expt 2 32)))
(define fixed_array_limit 15) ;in bytes
(define array16_limit     (sub1 (expt 2 16)))
(define array32_limit     (sub1 (expt 2 32)))
(define fixed_map_limit   15) ;in bytes
(define map16_limit       (sub1 (expt 2 16)))
(define map32_limit       (sub1 (expt 2 32)))

;; constants
(define constants '((()       . #xc0)
                    (#t       . #xc3)
                    (#f       . #xc2)
                    (uint8    . #xcc)
                    (uint16   . #xcd)
                    (uint32   . #xce)
                    (uint64   . #xcf)
                    (int8     . #xd0)
                    (int16    . #xd1)
                    (int32    . #xd2)
                    (int64    . #xd3)
                    (str8     . #xd9)
                    (str16    . #xda)
                    (str32    . #xdb)
                    (bin8     . #xc4)
                    (bin16    . #xc5)
                    (bin32    . #xc6)
                    (float    . #xca)
                    (double   . #xcb)
                    (array16  . #xdc)
                    (array32  . #xdd)
                    (map16    . #xde)
                    (map32    . #xdf)
                    (ext8     . #xc7)
                    (ext16    . #xc8)
                    (ext32    . #xc9)
                    (fixext1  . #xd4)
                    (fixext2  . #xd5)
                    (fixext4  . #xd6)
                    (fixext8  . #xd7)
                    (fixext16 . #xd8)))

(define constant-repr-map (alist->hash-table constants))

(define repr-constant-map
  (alist->hash-table (map (lambda (entry)
                            (cons (cdr entry) (car entry))) constants)))

;; byte manipulation primitives
(define (byte-complement2 n)
  (add1 (- 255 n)))

(define (xff- n)
  (- 255 n))

(define (blob-reverse blob)
  (let* ((size (blob-size blob))
         (old (blob->u8vector/shared blob))
         (new (make-u8vector size)))
    (let loop ((index 0))
      (if (< index size)
          (begin
            (u8vector-set! new index (u8vector-ref old (- size index 1)))
            (loop (add1 index)))
          (u8vector->blob/shared new)))))

; msgpack impose big endianness
; intel processors are little endian
(define to-big-endian
  (if (eq? (machine-byte-order) 'big-endian)
      identity
      blob-reverse))

(define from-big-endian
  (if (eq? (machine-byte-order) 'big-endian)
      identity
      blob-reverse))

(define (float->blob value size)
  (case size
    ((4) (f32vector->blob/shared (make-f32vector 1 value)))
    ((8) (f64vector->blob/shared (make-f64vector 1 value)))
    (else (error (format "invalid size ~A for a float, it should be 4 or 8" size)))))

(define (blob->float blob)
  (case (blob-size blob)
    ((4) (f32vector-ref (blob->f32vector/shared blob) 0))
    ((8) (f64vector-ref (blob->f64vector/shared blob) 0))
    (else (error (format "invalid blob size ~A for a float, it should be 4 or 8" (blob-size blob))))))


;;;;;;;;;; Writers

(define (write-raw port blob size)
  (assert (or (blob? blob) (u8vector? blob)) "write-raw: expected blob" blob)
  (let ((vec (if (blob? blob) (blob->u8vector/shared blob) blob)))
    (let loop ((index 0))
      (when (< index size)
        (write-byte (u8vector-ref vec index) port)
        (loop (add1 index))))))

(define (write-int port value size)
  (if (= size 1)  ; special case of one byte for efficiency
      (write-byte value port)
      (let ((vblob (make-u8vector size)))
        (let loop ((index 0) (value value))
          (when (< index size)
            (u8vector-set! vblob (- size index 1) (bitwise-and #xff value))
            (loop (add1 index) (arithmetic-shift value -8))))
        (write-raw port vblob size))))

(define (write-float port value size)
  (write-raw port (to-big-endian (float->blob value size)) size))

(define (write-array port value size)
  (assert (= (vector-length value) size) "write-array: invalid size" size)
  (let loop ((index 0))
    (when (< index size)
      (pack port (vector-ref value index))
      (loop (add1 index)))))

(define (write-map port value size)
  (assert (hash-table? value) "write-map: expected hash-table" value)
  (hash-table-walk value (lambda (k v)
                           (pack port k)
                           (pack port v))))

(define (write-header port type)
  (let ((header (hash-table-ref constant-repr-map type)))
    (write-byte header port)))

;;;;;;;;;; Readers

(define (read-byte/eof-error port)
  (let ((b (read-byte port)))
    (if (eof-object? b)
      (error "premature eof")
      b)))

(define (read-raw port size #!optional (mapper identity))
  (let ((data (make-u8vector size)))
    (let loop ((index 0))
      (if (< index size)
          (let ((byte (read-byte/eof-error port)))
            (u8vector-set! data index byte)
            (loop (add1 index)))
          (mapper (u8vector->blob data))))))

(define (read-uint port size #!optional (mapper identity))
  (if (= size 1)  ; special case of one byte for efficiency
      (read-byte/eof-error port)
      (let loop ((index 0) (value 0))
        (if (< index size)
            (loop (add1 index) (+ (arithmetic-shift value 8) (read-byte port)))
            (mapper value)))))

(define (read-sint port size #!optional (mapper identity))
  (let loop ((index 0) (value 0))
    (if (< index size)
        (loop (add1 index) (+ (arithmetic-shift value 8) (xff- (read-byte port))))
        (mapper (- (add1 value))))))

(define (read-float port size #!optional (mapper identity))
  (mapper (blob->float (from-big-endian (read-raw port size)))))

; Decode header
(define (fixed-uint? value)
  (= (bitwise-and #x80 value) 0))

(define (fixed-sint? value)
  (= (bitwise-and #xe0 value) #xe0))

(define (fixed-str? value)
  (= (bitwise-and #xe0 value) #xa0))

(define (fixed-array? value)
  (= (bitwise-and #xf0 value) #x90))

(define (fixed-map? value)
  (= (bitwise-and #xf0 value) #x80))
;;

(define (out-of-limit-error type value)
  (error type "Out of limit" value))

(define Uint
  (let* ((lowrite
           (lambda (port value header size)
             (write-header port header)
             (write-int port value size)))
         (read-uint
           read-uint)
         (pack
           (lambda (port value)
             (if (or (not (integer? value))
                     (< value 0))
               (error 'badInput "cannot pack value as uint" value))
             (cond ((<= value fixed_uint_limit)
                    (let ((header (bitwise-and value #x7f)))
                      (write-byte header port)))
                   ((<= value uint8_limit)  (lowrite port value 'uint8  1))
                   ((<= value uint16_limit) (lowrite port value 'uint16 2))
                   ((<= value uint32_limit) (lowrite port value 'uint32 4))
                   ((<= value uint64_limit) (lowrite port value 'uint64 8))
                   (#t                      (out-of-limit-error 'uint value))))))
    (match-lambda*
      (('unpack 'uint8)  (cut read-uint <> 1 <>)) ; port mapper
      (('unpack 'uint16) (cut read-uint <> 2 <>))
      (('unpack 'uint32) (cut read-uint <> 4 <>))
      (('unpack 'uint64) (cut read-uint <> 8 <>))
      (('unpack 'fixed)  (lambda (port value mapper)
                           (mapper value)))
      (('pack)           pack))))

(define Sint
  (let* ((lowrite
           (lambda (port value header size)
             (write-header port header)
             (write-int port value size)))
         (read-sint
           read-sint)
         (pack
           (lambda (port value)
             (if (not (integer? value))
               (error 'badInput "cannot pack value as sint" value))
             (cond ((> value int64_maxlimit)
                    (out-of-limit-error 'sint value))
                   ((> value 0)
                    ((Uint 'pack) port value))
                   ((>= value fixed_int_limit)
                    (let ((header (bitwise-ior #xe0 (bitwise-and #xff value))))
                      (write-byte header port)))
                   ((>= value int8_limit)  (lowrite port value 'int8  1))
                   ((>= value int16_limit) (lowrite port value 'int16 2))
                   ((>= value int32_limit) (lowrite port value 'int32 4))
                   ((>= value int64_limit) (lowrite port value 'int64 8))
                   (#t                     (out-of-limit-error 'sint value))))))
    (match-lambda*
      (('unpack 'int8)  (cut read-sint <> 1 <>)) ; port mapper
      (('unpack 'int16) (cut read-sint <> 2 <>))
      (('unpack 'int32) (cut read-sint <> 4 <>))
      (('unpack 'int64) (cut read-sint <> 8 <>))
      (('unpack 'fixed)  (lambda (port value mapper)
                           (mapper (- (add1 (xff- value))))))
      (('pack)           pack))))

(define Float
  (let* ((unpack
           (lambda (port #!optional (mapper identity))
             (mapper (read-float port 4))))
         (pack
           (lambda (port value)
             (write-header port 'float)
             (write-float port value 4))))
    (match-lambda
      ('unpack unpack)
      ('pack pack))))

(define Double
  (let* ((unpack
           (lambda (port #!optional (mapper identity))
             (mapper (read-float port 8))))
         (pack
           (lambda (port value)
             (write-header port 'double)
             (write-float port value 8))))
    (match-lambda
      ('unpack unpack)
      ('pack pack))))

(define Array
  (let* ((lowrite
           (lambda (port value header header-size size)
             (write-header port header)
             (write-int port size header-size)
             (write-array port value size)))
         (read-array
           (lambda (port size #!optional (mapper identity))
             (define array (make-vector size))
             (let loop ((index 0))
               (when (< index size)
                 (vector-set! array index (unpack port mapper))
                 (loop (add1 index))))
             (mapper array)))
         (pack
           (lambda (port value)
             (if (not (vector? value))
               (error 'badInput "cannot pack value as array" value))
             (let ((size (vector-length value)))
               (cond ((<= size fixed_array_limit)
                      (let ((header (bitwise-ior #x90 size)))
                        (write-byte header port)
                        (write-array port value size)))
                     ((<= size array16_limit) (lowrite port value 'array16 2 size))
                     ((<= size array32_limit) (lowrite port value 'array32 4 size))
                     (#t                      (out-of-limit-error 'array value)))))))
    (match-lambda*
      (('unpack 'array16) (lambda (port mapper) (read-array port (read-uint port 2) mapper)))
      (('unpack 'array32) (lambda (port mapper) (read-array port (read-uint port 4) mapper)))
      (('unpack 'fixed)   (lambda (port value mapper)
                            (let ((size (bitwise-and #x0f value)))
                              (read-array port size mapper))))
      (('pack)            pack))))

(define Map
  (let* ((lowrite
           (lambda (port value header header-size size)
             (write-header port header)
             (write-int port size header-size)
             (write-map port value size)))
         (read-map
           (lambda (port size #!optional (mapper identity))
             (define table (make-hash-table #:size size))
             (let loop ((size size))
               (if (> size 0)
                 (let* ((k (unpack port mapper))
                        (v (unpack port mapper)))
                   (hash-table-set! table k v)
                   (loop (- size 1)))))
             (mapper table)))
         (pack
           (lambda (port value)
             (if (not (hash-table? value))
               (error 'badInput "cannot pack value as map" value))
             (let ((size (hash-table-size value)))
               (cond ((<= size fixed_map_limit)
                      (let ((header (bitwise-ior #x80 size)))
                        (write-byte header port)
                        (write-map port value size)))
                     ((<= size map16_limit) (lowrite port value 'map16 2 size))
                     ((<= size map32_limit) (lowrite port value 'map32 4 size))
                     (#t                    (out-of-limit-error 'map value)))))))
    (match-lambda*
      (('unpack 'map16) (lambda (port mapper) (read-map port (read-uint port 2) mapper)))
      (('unpack 'map32) (lambda (port mapper) (read-map port (read-uint port 4) mapper)))
      (('unpack 'fixed) (lambda (port value mapper)
                          (let ((size (bitwise-and #x0f value)))
                            (read-map port size mapper))))
      (('pack)           pack))))

(define Str
  (let* ((lowrite
           (lambda (port value header header-size size)
             (write-header port header)
             (write-int port size header-size)
             (write-raw port value size)))
         (read-str
           (lambda (port size #!optional (mapper identity))
             (mapper (read-raw port size blob->string))))
         (pack
           (lambda (port value)
             (if (not (string? value))
               (error 'badInput "cannot pack value as str" value))
             (let* ((blob (string->blob value))
                    (size (blob-size blob)))
               (cond ((<= size fixed_raw_limit)
                      (let ((header (bitwise-ior #xa0 size)))
                        (write-byte header port)
                        (write-raw port blob size)))
                     ((<= size raw8_limit)  (lowrite port blob 'str8  1 size))
                     ((<= size raw16_limit) (lowrite port blob 'str16 2 size))
                     ((<= size raw32_limit) (lowrite port blob 'str32 4 size))
                     (#t                    (out-of-limit-error 'str value)))))))
    (match-lambda*
      (('unpack 'str8)  (lambda (port mapper) (read-str port (read-uint port 1) mapper)))
      (('unpack 'str16) (lambda (port mapper) (read-str port (read-uint port 2) mapper)))
      (('unpack 'str32) (lambda (port mapper) (read-str port (read-uint port 4) mapper)))
      (('unpack 'fixed) (lambda (port value mapper)
                          (let ((size (bitwise-and #x1f value)))
                            (read-str port size mapper))))
      (('pack)          pack))))

(define Bin
  (let* ((lowrite
           (lambda (port value header header-size size)
             (write-header port header)
             (write-int port size header-size)
             (write-raw port value size)))
         (read-bin
           read-raw)
         (pack
           (lambda (port value)
             (if (not (blob? value))
               (error 'badInput "cannot pack value as bin" value))
             (let ((size (blob-size value)))
               (cond
                 ((<= size raw8_limit)  (lowrite port value 'bin8  1 size))
                 ((<= size raw16_limit) (lowrite port value 'bin16 2 size))
                 ((<= size raw32_limit) (lowrite port value 'bin32 4 size))
                 (#t                    (out-of-limit-error 'bin value)))))))
    (match-lambda*
      (('unpack 'bin8)  (lambda (port mapper) (read-bin port (read-uint port 1) mapper)))
      (('unpack 'bin16) (lambda (port mapper) (read-bin port (read-uint port 2) mapper)))
      (('unpack 'bin32) (lambda (port mapper) (read-bin port (read-uint port 4) mapper)))
      (('pack)          pack))))


(define-record extension type data)

(define make-extension
  (let ((old-make-extension make-extension))
    (lambda (type data)
      (if (or (not (integer? type))
              (< type 0)
              (> type 127))
        (error (format "invalid type ~A, it should be a number between 0 and 127" type)))
      (if (not (blob? data))
        (error (format "invalid data ~A, it should be a blob" data)))
      (old-make-extension type data))))

(define Ext
  (let* ((lowrite
           (lambda (port header type data header-size size)
             (write-header port header)
             (if header-size
               (write-int port size header-size))
             (write-int port type 1)
             (write-raw port data size)))
         (read-ext
           (lambda (port size mapper)
             (let* ((type (read-uint port 1))
                    (data (read-raw port size)))
               (mapper (make-extension type data)))))
         (pack (lambda (port value)
                 (if (not (extension? value))
                   (error 'badInput "cannot pack value as extension " value))
                 (let* ((type (extension-type value))
                        (data (extension-data value))
                        (size (blob-size data)))
                   (cond
                     ((<= size 1)           (lowrite port 'fixext1  type data #f 1))
                     ((<= size 2)           (lowrite port 'fixext2  type data #f 2))
                     ((<= size 4)           (lowrite port 'fixext4  type data #f 4))
                     ((<= size 8)           (lowrite port 'fixext8  type data #f 8))
                     ((<= size 16)          (lowrite port 'fixext16 type data #f 16))
                     ((<= size raw8_limit)  (lowrite port 'ext8     type data 1  size))
                     ((<= size raw16_limit) (lowrite port 'ext16    type data 2  size))
                     ((<= size raw32_limit) (lowrite port 'ext32    type data 4  size))
                     (#t                    (out-of-limit-error 'ext value)))))))
    (match-lambda*
      (('unpack 'fixext1)  (lambda (port mapper) (read-ext port 1 mapper)))
      (('unpack 'fixext2)  (lambda (port mapper) (read-ext port 2 mapper)))
      (('unpack 'fixext4)  (lambda (port mapper) (read-ext port 4 mapper)))
      (('unpack 'fixext8)  (lambda (port mapper) (read-ext port 8 mapper)))
      (('unpack 'fixext16) (lambda (port mapper) (read-ext port 16 mapper)))
      (('unpack 'ext8)     (lambda (port mapper) (read-ext port (read-uint port 1) mapper)))
      (('unpack 'ext16)    (lambda (port mapper) (read-ext port (read-uint port 2) mapper)))
      (('unpack 'ext32)    (lambda (port mapper) (read-ext port (read-uint port 4) mapper)))
      (('pack)             pack))))

;;;;;;;;;;; Public interface

(define pack-uint   (Uint   'pack))
(define pack-sint   (Sint   'pack))
(define pack-float  (Float  'pack))
(define pack-double (Double 'pack))
(define pack-array  (Array  'pack))
(define pack-map    (Map    'pack))
(define pack-bin    (Bin    'pack))
(define pack-str    (Str    'pack))
(define pack-ext    (Ext    'pack))

(define (pack port value)
  (let ((repr/or-false (hash-table-ref/default constant-repr-map value #f)))
    (cond (repr/or-false
            (write-byte repr/or-false port))
          ((char? value)
           (pack-uint port (char->integer value)))
          ((integer? value)
           ((if (>= value 0) pack-uint pack-sint) port value))
          ((flonum? value)
           (pack-double port value))
          ((and (number? value) (exact? value))
           (pack-double port (exact->inexact value)))
          ((blob? value)
           (pack-bin port value))
          ((string? value)
           (pack-str port value))
          ((extension? value)
           (pack-ext port value))
          ((list? value)
           (pack-array port (list->vector value)))
          ((vector? value)
           (pack-array port value))
          ((hash-table? value)
           (pack-map port value))
          (#t
           (error (format "I don't know how to handle: ~A" value))))))

(define (pack/blob value)
    (string->blob (call-with-output-string (cut pack <> value))))

(define (unpack port #!optional (mapper identity))
  (let ((value (read-byte port)))
    (if (eof-object? value)
      value
      (cond ((hash-table-exists? repr-constant-map value)
             (let ((constant (hash-table-ref repr-constant-map value)))
               (match constant
                      ((or 'uint8 'uint16 'uint32 'uint64) ((Uint   'unpack constant) port mapper))
                      ((or 'int8 'int16 'int32 'int64)     ((Sint   'unpack constant) port mapper))
                      ((or 'str8 'str16 'str32)            ((Str    'unpack constant) port mapper))
                      ((or 'bin8 'bin16 'bin32)            ((Bin    'unpack constant) port mapper))
                      ((or 'array16 'array32)              ((Array  'unpack constant) port mapper))
                      ((or 'map16 'map32)                  ((Map    'unpack constant) port mapper))
                      ((or 'ext8 'ext16 'ext32
                           'fixext1 'fixext2 'fixext4
                           'fixext8 'fixext16)             ((Ext    'unpack constant) port mapper))
                      ('float                              ((Float  'unpack)          port mapper))
                      ('double                             ((Double 'unpack)          port mapper))
                      (other                               (mapper other)))))
            ((fixed-uint? value)  ((Uint  'unpack 'fixed) port value mapper))
            ((fixed-sint? value)  ((Sint  'unpack 'fixed) port value mapper))
            ((fixed-str? value)   ((Str   'unpack 'fixed) port value mapper))
            ((fixed-array? value) ((Array 'unpack 'fixed) port value mapper))
            ((fixed-map? value)   ((Map   'unpack 'fixed) port value mapper))
            (#t                   (error 'unpack "cannot unpack" value))))))

(define (unpack/blob blob #!optional (mapper identity))
  (call-with-input-string (blob->string blob) (cut unpack <> mapper)))

