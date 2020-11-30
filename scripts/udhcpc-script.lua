#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local inspect = require("inspect")

function parse_environ(environ)
   function split_space(s)
      if s then
	 local chunks = {}
	 for substring in s:gmatch("%S+") do
	    table.insert(chunks, substring)
	 end
	 return chunks
      end
   end

   local values = {}
   for k, v in environ:gmatch("([%w_]+)=([^\0]+)") do
      values[k:lower()] = v
   end
   return {
      -- we're going to map the arbitrary names used by udhcp back into
      -- names that resemble the ones used in dhcp standards, just so that
      -- consumers could choose different dhcp clients without having to
      -- be rewritten

      -- these fields are in the core packet (actually, defined by bootp)
      your_ip_address = values.ip,
      server_ip_address = values.siaddr,
      server_host_name = values.sname,
      file = values.boot_file,

      -- options are DHCP extensions to the BOOTP. keys are option
      -- names as written in rfc2132 (or equivalent) but substituting
      -- recognised acronyms for their expansions and underscores for
      -- spaces.  For example, "8.14. Simple Mail Transport Protocol
      -- (SMTP) Server Option" is returned as `smtp_server`

      options = {
	 subnet_mask = values.subnet,
	 router = split_space(values.router),
	 dns = split_space(values.dns),
	 host_name = values.hostname,
	 domain_name = values.domain,
	 default_ip_ttl = values.ipttl,
	 interface_mtu = values.mtu,
	 broadcast_address = values.broadcast,
	 ntp_servers = split_space(values.ntpsrv),
	 ip_address_lease_time = values.lease,
	 message = values.message,
	 tftp_server = values.tftp
      }
   }
end

function run(arguments)
   local name = assert(arguments.name)
   local environ = swarm.slurp("/proc/self/environ")
   local state = parse_environ(environ)
   state.healthy = (state.your_ip_address and true)
   state.STATUS = "running"
   swarm.write_state(name, state)
end

return run
