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


ifname = "wlp4s0" -- "enp0s31f6"
w = swarm.watcher()
w:subscribe("dhcp6c", {"address", "routes", "netmask"})

local previous = swarm.read_tree("/tmp/services", "dhcp6c")
while true do
   for event in w:events(4*1000) do -- argument to events is the poll time (ms)
      print(inspect(event))
      -- maybe the framework could do some of this tracking for us
      -- instead of our having to remember what the previous value was
      local inputs = swarm.read_tree("/tmp/services", "dhcp6c")
      if swarm.changed(inputs, previous, {"address", "netmask"}) then
	 swarm.exec("ip address set %s netmask %s", event.address, event.netmask)
	 previous = inputs
	 break
      end
      if swarm.changed(inputs, previous, {"routes"}) then
	 swarm.exec("ip route something blahk %s", event.routes)
	 previous = inputs
	 break
      end
--      print("previously, ", inspect(previous))
   end
   swarm.write_state(get_state(ifname))
end
