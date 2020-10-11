default: swarm
	@echo hello

LOADLIBES=-llua -lm
swarm: swarm.o
