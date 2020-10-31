#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local json = require("json")
local inspect = require("inspect")

function ip_state_json(w, command)
   local o = w:spawn(w.config.paths.ip,
		     {"ip", "-j", table.unpack(command)},
		     { wait = true, capture = true })
   return json.decode(o)[1]
end

function get_state(w, ifname)
   linkstate = ip_state_json(w, {"link", "show", ifname})
   addrstate = ip_state_json(w, {"address", "show", ifname})
   healthy = linkstate.operstate == "UP" and
      f.find(function(x) return (x.scope == "global") end,
	 addrstate.addr_info) and
      true
   carrier = not f.find(function(x) return (x == "NO-CARRIER") end,
      linkstate.flags)
   return {
      healthy = (healthy and "true" or "false"),
      state = linkstate["operstate"],
      carrier = (carrier and "true" or "false"),
   }
end

function run(arguments)
   local name = arguments.name
   local iface = arguments.iface
   print("service " .. name , "if " .. iface)

   local w = swarm.watcher(arguments)

   w:subscribe("dhcp6c", {"address", "routes", "netmask"})

   while true do
      for event in w:events(4*1000) do -- argument to events is the poll time (ms)
	 if event.changed and event:changed("dhcp6c", {"address", "netmask"}) then
	    local dhcp6c = event.values.dhcp6c
	    w:spawn(arguments.paths.ip,
		    {"ip", "address",
		     "set", dhcp6c.address,
		     "netmask", dhcp6c.netmask},
		    { wait = true })
	    break
	 end
	 if event.changed and event:changed("dhcp6c", {"routes"}) then
	    local dhcp6c = event.values.dhcp6c
	    w:spawn(arguments.paths.ip,
		    {"ip", "route", "set", dhcp6c.routes, "something", "blah"},
		    { wait = true })
	    break
	 end
      end
      swarm.write_state(name, get_state(w, ifname))
   end
end

return run
