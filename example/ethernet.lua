#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local json = require("json")
local inspect = require("inspect")

local w = swarm.watcher({
      environ = {
	 PATH = os.getenv("PATH"),
	 TERM = "dumb"
}})

function ip_state_json(command)
   local o = w:spawn("/run/current-system/sw/bin/ip",
		     {"ip", "-j", table.unpack(command)},
		     { wait = true, capture = true })
   return json.decode(o)[1]
end

function get_state(w,ifname)
   linkstate = ip_state_json({"link", "show", ifname})
   addrstate = ip_state_json({"address", "show", ifname})
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

service_name = arg[1]
ifname = arg[2]
print("service " .. service_name , "if " .. ifname)

w:subscribe("dhcp6c", {"address", "routes", "netmask"})

while true do
   for event in w:events(4*1000) do -- argument to events is the poll time (ms)
      if event.changed and event:changed("dhcp6c", {"address", "netmask"}) then
	 local dhcp6c = event.values.dhcp6c
	 w:spawn(ip_path,
		 {"ip", "address",
		  "set", dhcp6c.address,
		  "netmask", dhcp6c.netmask},
		 { wait = true })
	 break
      end
      if event.changed and event:changed("dhcp6c", {"routes"}) then
	 local dhcp6c = event.values.dhcp6c
	 w:spawn(ip_path,
		 {"ip", "route", "set", dhcp6c.routes, "something", "blah"},
		 { wait = true })
	 break
      end
   end
   swarm.write_state(service_name, get_state(ifname))
end
