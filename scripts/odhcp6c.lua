#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local inspect = require("inspect")

function parse_environ(environ)
   local p = {
      split_space = function(s)
	 local chunks = {}
	 for substring in s:gmatch("%S+") do
	    table.insert(chunks, substring)
	 end
	 return chunks
      end,
      unbase16 = function(s)
	 return s
      end,
      identity = function(s)
	 return s
      end
   }

   -- what's CER?
   local value_parsers = {
      ADDRESSES=p.split_space,
      DOMAINS=p.split_space,
      SNTP_IP=p.split_space,
      SNTP_FQDN=p.split_space,
      NTP_IP=p.split_space,
      NTP_FQDN=p.split_space,
      PREFIXES=p.split_space,
      RA_ADDRESSES=p.split_space,
      RA_DNS=p.split_space,
      RA_DOMAINS=p.split_space,
      RA_ROUTES=p.split_space,
      RDNSS=p.split_space,
      SIP_IP=p.split_space,
      SIP_DOMAIN=p.split_space,

      AFTR=p.identity,
      SERVER=p.identity,

      PASSSTHRU=p.unbase16
   }
   local values = {}
   for k, v in environ:gmatch("([%w_]+)=([^\0]+)") do
      if k:sub(1, 7) == "OPTION_" then
	 values[k:lower()] = p.unbase16(v)
      elseif value_parsers[k] then
	 values[k:lower()] = (value_parsers[k])(v)
      end
   end
   return values
end


function run(arguments)
   local name = assert(arguments.name)
   local interface = assert(arguments.iface)
   local script = assert(arguments.updatescript);
   local pid
   local state = "no-daemon"
   local options = {}

   local w = swarm.watcher()

   w:subscribe("odhcp6c-script",  { "environ" });
   w:subscribe("odhcp6c-script",  { "environ" });

   while true do
      if state == "no-daemon" then
	 pid = w:spawn(arguments.paths.odhcp6c,
		       {"odhcp6c",
			"-P", "64",
			"-s", script,
			"-v", "-v",
			interface},
		       {capture = true})
	 state = "starting"
      end
      for event in w:events() do
	 if event.type == "child" and event.pid == pid then
	    warn "odhcp6c exited"
	    state = "no-daemon"
	 end
	 if event:changed("odhcp6c-script", "environ") then
	    local environ = event.values["odhcp6c-script"].environ
	    if environ then
	       options = parse_environ(environ)
	       break
	    else
	       print("environ is nil")
	    end
	 end
	 if event.type == "stream" then
	    print(event.message)
	 end
      end
      swarm.write_state(
	 name, {
	    healthy = (options.addresses and true),
	    pid = pid,
	    options = options,
	    STATUS = state
      })
   end
end
return run
