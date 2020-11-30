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
      local addresses = f.find(function(x) return (x.scope == "global") end,
	    addrstate.addr_info)
      local healthy = linkstate.operstate == "UP" and addresses
      local carrier = not f.find(function(x) return (x == "NO-CARRIER") end,
	 linkstate.flags)
      return {
	 healthy = healthy,
	 up = ((linkstate.operstate == "UP")  and "true" or nil),
	 STATUS = linkstate.operstate,
	 carrier = (carrier and "true" or "false"),
      }
   elseif linkstate then
      return {
	 healthy = false,
	 up = ((linkstate.operstate == "UP")  and "true" or nil),
	 STATUS = linkstate.operstate,
	 carrier = "false",
      }
   else
      return {
	 healthy = false,
	 STATUS = "no-interface",
	 carrier = "false",
      }
   end
end

function set_address_from_dhcp(w, arguments, iface, dhcp)
   if dhcp and dhcp.your_ip_address and
      dhcp.options and dhcp.options.subnet_mask then
      local masked_address =
	 (dhcp.your_ip_address .. "/" .. dhcp.options.subnet_mask)
      -- ideally we would remove any other ip address we'd previously
      -- set from dhcp here, but we don't, because we aren't tracking
      -- what we previously set and don't want to wipe out addresses
      -- set by other means
      w:spawn(arguments.paths.ip, {
		 "ip", "address",
		 "add", masked_address,
		 "dev", iface},
	      { wait = true })
      for i,gw in pairs(dhcp.options.router) do
	 w:spawn(arguments.paths.ip, {
		    "ip", "route",
		    "replace", "default",
		    "via", gw,
		    "metric", (10 + i)}, -- probably make this 10 a param
		 { wait = true })
      end
   end
end

function set_prefix_from_dhcp6(w, arguments, iface, dhcp6)
   print("dhcp6", inspect(dhcp6))
   -- for _, address in pairs(dhcp6.dhcp6.ia_na) do
   --    local address, preferred, valid =
   -- 	 table.unpack(f.split_string("[^,]+", address))
   --    w:spawn(arguments.paths.ip, {
   -- 		 "ip", "-6", "address",
   -- 		 "add", address,
   -- 		 "dev", iface},
   -- 	      { wait = true })
   -- end
   -- "2001:8b0:de3a:40dc::/64,7200,7200"
   local prefix, prefixlen, preferred, valid =
      table.unpack(f.split_string("[^/,]+", dhcp6.dhcp6.ia_pd["1"]))
   w:spawn(arguments.paths.ip, {
	      "ip", "-6", "address",
	      "add", address.."1",
	      "dev", iface},
	   { wait = true })
end

function run(arguments)
   local name = assert(arguments.name)
   local iface = assert(arguments.iface)
   print("ethernet for ", name,  "iface", iface,
	 "dhcp from ", arguments.dhcp)

   local w = swarm.watcher(arguments)
   if arguments.dhcp then
      w:subscribe(arguments.dhcp, {"options", "your_ip_address"})
   end
   if arguments.dhcp6 then
      print("subscribed to dhcp6 ", arguments.dhcp6)
      w:subscribe(arguments.dhcp6, {"HEALTHY", "ra", "dhcp6"})
   end

   swarm.write_state(name, get_state(w, iface))
   w:spawn(arguments.paths.ip,{
	      "ip", "link", "set", "up",
	      "dev", iface},
	   { wait = true })
   swarm.write_state(name, get_state(w, iface))

   -- for _, spec in pairs(arguments.addresses or {}) do
   --    -- this doesn't work (bad syntax to ip(8)
   --    if spec.family == "inet" then
   -- 	 w:spawn(arguments.paths.ip,{
   -- 		    "ip", "address", "add", spec.address,
   -- 		    "dev", iface},
   -- 		 { wait = true })
   --    end
   -- end

   while true do
      local dhcp = arguments.dhcp and w.values[arguments.dhcp]
      local dhcp6 = arguments.dhcp6 and w.values[arguments.dhcp6]
      if dhcp and dhcp.HEALTHY then
--	 print("ethernet set from dhcp options ", inspect(dhcp))
	 set_address_from_dhcp(w, arguments, iface, dhcp)
      end
      if dhcp6 and dhcp6.HEALTHY then
	 print("ethernet: set address from dhcp6 delegated prefix",
	       inspect(dhcp6))
	 set_prefix_from_dhcp6(w, arguments, iface, dhcp6)
      end
      swarm.write_state(name, get_state(w, iface))
      for event in w:events() do
	 if event:changed(arguments.dhcp, "options") then
	    break;
	 end
      end
   end
end

return run
