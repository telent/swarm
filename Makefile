default: src/lua-swarm

install:
	luac -p example/*.lua lib/*.lua scripts/*.lua
	mkdir -p $(DESTDIR)/bin $(DESTDIR)/lib
	install src/lua-swarm $(DESTDIR)/bin
	cp -r lib/* $(DESTDIR)/lib
	mkdir -p $(DESTDIR)/share/swarm/
	cp -r scripts $(DESTDIR)/share/swarm/

test: SWARM_BASE_PATH=$(shell mktemp -d)/
test: src/lua-swarm
	for i in $(wildcard tests/*.test.lua); do \
	 echo -n "$$i : " && src/lua-swarm $$i && echo OK;\
	done
	rm -rf $(SWARM_BASE_PATH)

LOADLIBES=-llua -lm
