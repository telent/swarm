#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local inspect = require("inspect")

function run(arguments)
   local name = assert(arguments.name)
   local interface = assert(arguments.iface)
   local script = assert(arguments.updatescript);
   local pid
   local state = "no-interface"
   local options = {}

   local w = swarm.watcher(arguments)

   w:subscribe(interface,  { "HEALTHY" });
   print("odhcpc-daemon startup says",
	 inspect(arguments),
	 inspect(w.values))


   while true do
      if state == "no-daemon" then
	 pid = w:spawn(arguments.paths.odhcp6c,
		       {"odhcp6c",
			"-P", "64",
			"-s", script,
			"-v", "-v",
			interface},
		       {capture = true})
	 -- state = "starting"
	 state = "running"
      end
      for event in w:events() do
	 print("odhcp6c-daemon event", inspect(event))
	 if event:changed(interface, "HEALTHY") then
	    print(inspect(w.values[interface]), (w.values[interface].HEALTHY and "TRUE"), state)
	    if w.values[interface].HEALTHY and state=="no-interface" then
	       state = "no-daemon"
	    elseif not w.values[interface].HEALTHY then
	       state = "no-interface"
	    end
	 end
	 if event.type == "child" and event.pid == pid and state ~= "no-interface" then
	    warn "odhcp6c exited"
	    state = "no-daemon"
	 end
	 if event.type == "stream" then
	    print(event.message)
	 end
      end
      swarm.write_state(
	 name, {
	    healthy = (state == "running"),
	    pid = pid,
	    STATUS = state
      })
   end
end
return run
