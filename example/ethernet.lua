#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local json = require("json")
local inspect = require("inspect")

function get_state(ifname)
   linkstate = json.decode(swarm.capture("ip -j link show %s", ifname))[1]
   addrstate = json.decode(swarm.capture("ip -j address show %s", ifname))[1]
   healthy = linkstate.operstate == "UP" and
      f.find(function(x) return (x.scope == "global") end,
	 addrstate.addr_info) and
      true
   carrier = not f.find(function(x) return (x == "NO-CARRIER") end,
      linkstate.flags)
   return {
      healthy = healthy,
      state = linkstate["operstate"],
      carrier = carrier
   }
end


service_name = arg[1]
ifname = arg[2]
print("service " .. service_name , "if " .. ifname)

w = swarm.watcher()
w:subscribe("dhcp6c", {"address", "routes", "netmask"})

while true do
   for event in w:events(4*1000) do -- argument to events is the poll time (ms)
      if event:changed("dhcp6c", {"address", "netmask"}) then
	 local dhcp6c = event.values.dhcp6c
	 swarm.exec("ip address set %s netmask %s", dhcp6c.address, dhcp6c.netmask)
	 break
      end
      if event:changed("dhcp6c", {"routes"}) then
	 local dhcp6c = event.values.dhcp6c
	 swarm.exec("ip route something something %s", dhcp6c.routes)
	 break
      end
   end
   swarm.write_state(service_name, get_state(ifname))
end
