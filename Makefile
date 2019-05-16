PREFIX=/usr/local

.PHONY: all test test-python-ref clean

all: msgpack.so

# Development tests
test: msgpack-imple.so
	$(PREFIX)/bin/csc -I tests/ tests/tests.scm -o run
	./run

# Post install tests
test-python-ref: clean
	$(PREFIX)/bin/chicken-install -s
	python tests/python-ref.py
	$(PREFIX)/bin/csi -s tests/python-ref-tests.scm

# Development interface
msgpack-imple.so:
	$(PREFIX)/bin/csc -s src/msgpack-imple.scm

# Module interface
msgpack.so:
	$(PREFIX)/bin/csc -s -j msgpack -o msgpack.so src/msgpack.scm
	$(PREFIX)/bin/csc msgpack.import.scm -dynamic

clean:
	rm -f tests/*.o *.o run *.c tests/*.c *.so msgpack.import.scm tests/python-ref-tests.scm tests/run src/*.c src/*.so
	rm -f msgpack.*.sh msgpack.link
