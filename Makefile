ifeq ($(UNWIND_SRC),)
UNWIND_INCLUDES =
UNWIND_LIBS = -lunwind
else
UNWIND_INCLUDES = -I$(UNWIND_SRC)/include
UNWIND_LIBS = $(UNWIND_SRC)/src/.libs/libunwind.a -llzma
endif

VERBOSITY ?= 0

CXX ?= g++
CXXFLAGS = -Wall -fno-omit-frame-pointer -fvisibility=hidden -std=gnu++11 $(UNWIND_INCLUDES) -DVERBOSITY=$(VERBOSITY)

PYTHON ?= python3

all: libmemtrail.so sample benchmark

libmemtrail.so: memtrail.cpp memtrail.version
	$(CXX) -O2 -g2 $(CXXFLAGS) -shared -fPIC -Wl,--version-script,memtrail.version -o $@ $< $(UNWIND_LIBS) -ldl

%: %.cpp
	$(CXX) -O0 -g2 -Wno-unused-result -o $@ $< -ldl

gprof2dot.py:
	wget --quiet --timestamping https://raw.githubusercontent.com/jrfonseca/gprof2dot/master/gprof2dot.py
	chmod +x gprof2dot.py

sample: sample.cpp memtrail.h

test: libmemtrail.so sample gprof2dot.py
	$(RM) memtrail.data $(wildcard memtrail.*.json) $(wildcard memtrail.*.dot)
	$(PYTHON) memtrail record ./sample
	$(PYTHON) memtrail dump
	$(PYTHON) memtrail report --show-snapshots --show-snapshot-deltas --show-cumulative-snapshot-delta --show-maximum --show-leaks --output-graphs
	$(foreach LABEL, snapshot-0 snapshot-1 snapshot-1-delta maximum leaked, ./gprof2dot.py -f json memtrail.$(LABEL).json > memtrail.$(LABEL).dot ;)

test-debug: libmemtrail.so sample
	$(RM) memtrail.data $(wildcard memtrail.*.json) $(wildcard memtrail.*.dot)
	$(PYTHON) memtrail record --debug ./sample

bench: libmemtrail.so benchmark
	$(RM) memtrail.data
	$(PYTHON) memtrail record ./benchmark
	time -p $(PYTHON) memtrail report --show-maximum

profile: benchmark gprof2dot.py
	$(PYTHON) memtrail record ./benchmark
	$(PYTHON) -m cProfile -o memtrail.pstats -- memtrail report --show-maximum
	./gprof2dot.py -f pstats memtrail.pstats > memtrail.dot

clean:
	$(RM) libmemtrail.so gprof2dot.py sample benchmark


.PHONY: all test test-debug bench profile clean
