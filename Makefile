PREFIX=/usr/local

.PHONY: all test test-python-ref clean

all: test-python-ref test msgpack.so

test: msgpack-imple.so
	$(PREFIX)/bin/csc -X bind -c++ -I tests/ tests/tests.scm -o run
	./run

test-python-ref: msgpack.so
	python tests/python-ref.py
	$(PREFIX)/bin/csi -s tests/python-ref-tests.scm

msgpack-imple.so:
	$(PREFIX)/bin/csc -X bind -c++ -s msgpack-imple.scm

msgpack.so:
	$(PREFIX)/bin/csc -X bind -c++ -s -j msgpack -o msgpack.so msgpack.scm
	$(PREFIX)/bin/csc msgpack.import.scm -dynamic

clean:
	rm -f tests/*.o *.o run *.c tests/*.c *.so msgpack.import.scm tests/python-ref-tests.scm tests/run
