#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local inspect = require("inspect")


function run(arguments)
   local name = assert(arguments.name)
   local interface = assert(arguments.iface)
   local script = assert(arguments.script);
   local pid
   local state = "no-interface"
   local options = {}

   local w = swarm.watcher(arguments)
   print("udhcpc ", name, "for ", interface)
   w:subscribe(interface,  { "HEALTHY", "up" });

   while true do
      print("values for udhcpc", inspect(w.values))
      if w.values[interface] then
	 if w.values[interface].up and state == "no-interface" then
	    state = "no-daemon"
	 elseif not w.values[interface].up then
	    state = "no-interface"
	 end
      end
      if state == "no-daemon" then
	 pid = w:spawn(assert(arguments.paths.udhcpc),
		       {"udhcpc",
			"-f",
			"-i", interface,
			"-s", script},
		       {capture = true})
	 -- state = "starting"
	 -- XXX should look for "udhcpc: started" on stderr beofre
	 -- transition from starting to running
	 state = "running"
      end
      swarm.write_state(
	 name, {
	    healthy = (state == "running"),
	    pid = pid,
	    STATUS = state
      })
      for event in w:events() do
	 if event.type == "file" then
	    break
	 end
	 if event.type == "child" and
	    event.pid == pid and
	    state ~= 'no-interface' then
	    warn "udhcp6c exited"
	    state = "no-daemon"
	    break
	 end
	 if event.type == "stream" then
	    print(event.message)
	 end
      end
   end
end
return run
