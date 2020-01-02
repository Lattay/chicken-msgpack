PREFIX=
CSC=
ifeq ($(CSC),)
ifeq ($(PREFIX),)
CSC=csc
else
CSC=$(CSC)
endif
endif

CSI=
ifeq ($(CSI),)
ifeq ($(PREFIX),)
CSI=csi
else
CSI=$(CSI)
endif
endif

.PHONY: all test test-python-ref clean

all: msgpack.so

# Development tests
test: msgpack-imple.so
	$(CSC) -I tests/ tests/tests.scm -o run
	./run

# Post install tests
test-python-ref: clean
	$(PREFIX)/bin/chicken-install -s
	python tests/python-ref.py
	$(CSI) -s tests/python-ref-tests.scm

# Development interface
msgpack-imple.so:
	$(CSC) -s src/msgpack-imple.scm

# Module interface
msgpack.so:
	$(CSC) -s -j msgpack -o msgpack.so src/msgpack.scm
	$(CSC) msgpack.import.scm -dynamic

clean:
	rm -f tests/*.o *.o run *.c tests/*.c *.so msgpack.import.scm tests/python-ref-tests.scm tests/run src/*.c src/*.so
	rm -f msgpack.*.sh msgpack.link
