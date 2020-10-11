#!/usr/bin/env lua
swarm = require("swarm")
f = require("prelude")

iface = "wlp4s0" -- "enp0s31f6"

local inspect = require("inspect")
local json = require("json")

inputs = swarm.subscribe({"dhcp6c/address", "dhcp6c/routes"})

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
--!linkstate["flags"].include?("NO-CARRIER"))
end

for event in inputs:wait() do
   print(inspect(event.source))
  if event.source == "dhcpc/address" then
     swarm.exec("ip address set %s netmask %s", event.address, event.netmask)
  elseif false then
     print("nothings")
--    ...
  end
  swarm.write_state(get_state(iface))
end
