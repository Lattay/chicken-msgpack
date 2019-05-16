import msgpack

ASSERT_TEMPLATE = '''
(test-group "{name}"
    (test "unpack" {chicken_expr}
                   (unpack/blob (u8vector->blob/shared #u8({blob}))))
    (test "pack" (u8vector->blob/shared #u8({blob}))
                 (pack/blob {chicken_expr})))
'''


def bytes_to_blob(bytes_):
    return ' '.join(str(b) for b in bytes_)


def asChickenAssertion(data, chicken_expr=None, name=None):
    blob = bytes_to_blob(msgpack.dumps(data))
    return ASSERT_TEMPLATE.format(
        name=name if name else str(data),
        blob=blob,
        chicken_expr=data if chicken_expr is None else chicken_expr
    )


with open('tests/python-ref-header.scm') as f:
    header = f.readlines()

with open('tests/python-ref-tests.scm', 'w') as f:
    f.writelines(header)

    def append_assert(val, chicken_expr=None, name=None):
        f.write(asChickenAssertion(val, chicken_expr=chicken_expr, name=name))

    append_assert(-1)
    append_assert(-100)
    append_assert(100)
    append_assert(-16384)
    append_assert(16384)
    append_assert(56213)
    append_assert(-56213)
    append_assert(100102831903)
    append_assert(-100102831903)
    append_assert(1.3313)
    append_assert(-7.8125653266e-200)
    append_assert(-7.8125653266e-231)
    append_assert([], '\'#()')
    append_assert(
        [10, True, ['hi']],
        chicken_expr='\'#(10 #t #("hi"))',
        name='little nested list'
    )
    append_assert(
        msgpack.ExtType(42, 'a'.encode('utf8')),
        chicken_expr='(make-extension 42 (string->blob "a"))',
        name='extension'
    )
