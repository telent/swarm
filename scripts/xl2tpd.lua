#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local inspect = require("inspect")

function run(arguments)
   local name = assert(arguments.name)
   local iface = assert(arguments.iface)
   local lac = assert(arguments.lac)
   local transit_iface = assert(arguments.transit_iface)
   local pid
   local state = "no-transit"

   local w = swarm.watcher()

   w:subscribe(transit_iface, { "HEALTHY" })

   while true do
      if state == "no-daemon" then
	 pid = w:spawn(arguments.paths.xl2tpd,
		       {"xl2tpd",
			"-c", arguments.config,
			"-s", arguments.secrets,
			"-D",
			-- "-p", "/run/xl2tpd.pid",
			"-C", "/run/xl2tpd.control"},
		       {capture = true})
	 state = "starting"
      end
      if state == "listening" then
	 local control,err = io.open("/run/xl2tpd.control", "w")
	 if control then
	    control:write("c " .. arguments.lac)
	    state = "starting-session"
	    control:close()
	 else
	    print("err:" .. err)
	 end
      end
      for event in w:events() do
	 if event:changed(transit_iface, "HEALTHY") then
	    if w.values.eth0.HEALTHY then
	       if state == "no-transit" then
		  state = "no-daemon"
		  break
	       end
	    else
	       state = "no-transit"
	       break
	    end
	 end
	 if event.type == "child" and event.pid == pid then
	    warn "xl2tpd exited"
	    state = "no-daemon"
	    break;
	 end
	 if event.type == "stream" then
	    print(event.message)
	    if event.message:find("Listening on IP address") then
	        state = "listening"
		break;
	    end
	    if event.message:find("Connection established") then
	        state = "connected"
		break;
	    end
	    if event.message:find("Maximum retries exceeded") then
	        -- tunnel disconnected, we assume the local daemon
		-- is still active
	        state = "listening"
		break;
	    end
	 end
      end
      swarm.write_state(
	 name, {
	    healthy = (state=="connected"),
	    pid = pid,
	    STATUS = state
      })
   end
end
return run
