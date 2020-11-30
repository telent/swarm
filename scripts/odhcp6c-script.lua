#!/usr/bin/env lua
local f = require("prelude")
local swarm = require("swarm")
local inspect = require("inspect")

function parse_environ(environ)
   function split_space(s)
      if s and s ~= nil then
	 local chunks = {}
	 for substring in s:gmatch("%S+") do
	    table.insert(chunks, substring)
	 end
	 return chunks
      end
   end

   local values = {}
   for k, v in environ:gmatch("([%w_]+)=([^\0]+)") do
      print("odhcp6c script", k:lower(), v)
      values[k:lower()] = v
   end

   -- parameter names here are according to
   -- http://www.iana.org/assignments/dhcpv6-parameters/dhcpv6-parameters.xhtml
   -- but downcased and with the initial OPT_ or OPTION_ prefix removed

   local ntp_servers = f.cat_tables(split_space(values.ntp_ip) or {},
				    split_space(values.ntp_fqdn) or {})
   local sntp_servers = f.cat_tables(split_space(values.sntp_ip) or {},
				     split_space(values.sntp_fqdn) or {})
   return {
      ra = {
	 addresses = split_space(values.ra_addresses),
	 dns = split_space(values.ra_dns),
	 domains = split_space(values.ra_domains),
	 routes = split_space(values.ra_routes),
      },
      dhcp6 = {
	 -- ia_ta (temporary address
	 -- ia_na (non-temporary address)
	 -- ia_pd (prefix delegation)
	 dns_servers = split_space(values.rdnss),
	 domain_list = split_space(values.domains),
	 -- not sure this is 100% correct, odhcp _may_ be getting sntp
	 -- ip addresses from got these from OPTION_SNTP_SERVERS (RFC
	 -- 4075) but that doesn't allow for full ntp or for dns addresses
	 ntp_server = f.cat_tables(ntp_servers, sntp_servers),
	 sip_server_a = split_space(values.sip_ip),
	 sip_server_d = split_space(values.sip_domain),
	 -- this is a guess
	 ia_pd = split_space(values.prefixes),
	 -- and this. I don't *think* it also contains RA addresses or
	 -- ia_ta addresses, but I've not done more than skim the code
	 ia_na = split_space(values.addresses),
      },
   }
end

function run(arguments)
   local name = assert(arguments.name)
   local environ = swarm.slurp("/proc/self/environ")
   local state = parse_environ(environ)
   state.healthy = true
   print("odhcp6 script writing state", inspect(state))
   swarm.write_state(name, state)
end

return run
