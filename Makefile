default: src/lua-swarm

install:
	mkdir -p $(DESTDIR)/bin $(DESTDIR)/lib
	install src/lua-swarm $(DESTDIR)/bin
	cp -r lib/* $(DESTDIR)/lib

test: src/lua-swarm
	for i in $(wildcard test/*.test.lua); do \
	 echo -n "$$i : " && src/lua-swarm $$i ;\
	done

LOADLIBES=-llua -lm
