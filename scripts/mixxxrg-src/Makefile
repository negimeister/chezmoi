CXX ?= g++
CXXFLAGS ?= -O2 -std=c++17

mixxxrg: main.cpp
	$(CXX) $(CXXFLAGS) -o $@ main.cpp -lFLAC -lebur128 -lm

clean:
	rm -f mixxxrg
