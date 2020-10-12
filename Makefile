default: lua-swarm

install:
	mkdir -p $(DESTDIR)/bin
	install lua-swarm $(DESTDIR)/bin

LOADLIBES=-llua -lm
