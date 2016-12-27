.PHONY: test all python2

all: cython
	python setup.py build_ext -i -f

cython:
	cython --cplus msgpack/*.pyx

python3: cython
	python3 setup.py build_ext -i -f

test:
	py.test test

.PHONY: clean
clean:
	rm -rf build
	rm msgpack/*.so
	rm -rf msgpack/__pycache__