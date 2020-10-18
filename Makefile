default: src/lua-swarm

install:
	mkdir -p $(DESTDIR)/bin $(DESTDIR)/lib
	install src/lua-swarm $(DESTDIR)/bin
	cp -r lib/* $(DESTDIR)/lib

test: SWARM_BASE_PATH=$(shell mktemp -d)/
test: src/lua-swarm
	for i in $(wildcard tests/*.test.lua); do \
	 echo -n "$$i : " && src/lua-swarm $$i ;\
	done
	rm -rf $(SWARM_BASE_PATH)

LOADLIBES=-llua -lm
