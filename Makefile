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

all: msgpack.so doc

# Development tests
test: msgpack-imple.so
	cd tests; $(CSI) run.scm

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

doc: README.svnwiki

README.svnwiki: README.md
	markdown-svnwiki -o README.svnwiki README.md

clean:
	rm -f tests/*.o *.o run *.c tests/*.c *.so msgpack.import.scm tests/python-ref-tests.scm tests/run src/*.c src/*.so
	rm -f msgpack.*.sh msgpack.link
