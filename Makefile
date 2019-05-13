PREFIX=/usr/local

.PHONY: all test module test-python-ref clean

all: module test-python-ref test

test: module
	$(PREFIX)/bin/csc -X bind -c++ -I tests/ tests/tests.scm -o run
	./run

module: clean
	$(PREFIX)/bin/csc -X bind -c++ -s flonum-utils.scm
	$(PREFIX)/bin/csc -X bind -c++ -s msgpack-imple.scm
	$(PREFIX)/bin/csc -X bind -c++ -s -j msgpack -o msgpack.so msgpack.scm
	$(PREFIX)/bin/csc msgpack.import.scm -dynamic

test-python-ref: module
	python tests/python-ref.py
	$(PREFIX)/bin/csi -s tests/python-ref-tests.scm

clean:
	rm -f tests/*.o *.o run *.c tests/*.c *.so msgpack.import.scm tests/python-ref-tests.scm tests/run
