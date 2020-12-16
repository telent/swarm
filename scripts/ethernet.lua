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
   local linkstate = ip_state_json(w, {"link", "show", ifname})
   local addrstate = ip_state_json(w, {"address", "show", ifname})
   if linkstate and addrstate then
      local healthy = linkstate.operstate == "UP" and
	 f.find(function(x) return (x.scope == "global") end,
	    addrstate.addr_info)
      local carrier = not f.find(function(x) return (x == "NO-CARRIER") end,
	 linkstate.flags)
      return {
	 healthy = healthy,
	 STATUS = linkstate["operstate"],
	 carrier = (carrier and "true" or "false"),
      }
   else
      return {
	 healthy = false,
	 STATUS = "no-interface",
	 carrier = "false",
      }
   end
end

function run(arguments)
   local name = arguments.name
   local iface = arguments.iface
   print("ethernet for ", service,  "iface", iface)
   local w = swarm.watcher(arguments)

   for _, spec in pairs(arguments.addresses) do
      if spec.family == "inet" then
	 w:spawn(arguments.paths.ip,{
		    "ip", "address", "add", spec.address,
		    "dev", iface},
		 { wait = true })
      end
   end

   -- XXX need arguments to tell us if we should be configring using dhcp6
   -- w:subscribe("dhcp6c", {"address", "routes", "netmask"})

   while true do
      swarm.write_state(name, get_state(w, iface))
      for event in w:events() do
	 -- if event:changed("dhcp6c", "address") or  event:changed("dhcp6c", "netmask") then
	 --    local dhcp6c = event.values.dhcp6c
	 --    w:spawn(arguments.paths.ip,
	 -- 	    {"ip", "address",
	 -- 	     "set", dhcp6c.address,
	 -- 	     "netmask", dhcp6c.netmask},
	 -- 	    { wait = true })
	 --    break
	 -- end
	 -- if event:changed("dhcp6c", "routes") then
	 --    local dhcp6c = event.values.dhcp6c
	 --    w:spawn(arguments.paths.ip,
	 -- 	    {"ip", "route", "set", dhcp6c.routes, "something", "blah"},
	 -- 	    { wait = true })
	 --    break
	 -- end
      end
   end
end

return run
