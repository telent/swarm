local f = require("prelude")
local inspect = require("inspect")
local i=inspect

actual = f.map(function(x) return 2*x end, {1,23,4,5,6,9})
assert(inspect(actual) == inspect({ 2, 46, 8, 10, 12, 18 }))

assert(f.find(function(x) return (x%7==0) end, {2,12,26,21}) == 21)

assert(inspect(f.invert({a="z", b="q", n="99"})) ==
       inspect({z="a", q="b", ["99"] = "n"}))

local t1 = { a =1, b= 2, c=3}
local t2 = { a =1, b= 2, c=99, d=4}
actual = f.difftree(t1, t2)
assert(i(actual) == i({c=true, d=true}), inspect(actual))

actual = f.difftree(t2, t1)
assert(i(actual) == i({c=true, d=true}), inspect(actual))


local t1 = { a = 1, c=2 }
local t2 = { a = 1, b = {z = 99}, c=3 }
actual = f.difftree(t1, t2)
assert(i(actual) == i({c=true, b = {z=true}}), inspect(actual))

local t1 = { a = 1, b= {z = 99}, c=2 }
local t2 = { a = 1, b = {z = 99, q=2}, c=3 }
actual = f.difftree(t1, t2)
assert(i(actual) == i({c=true, b = {q=true}}), inspect(actual))

local t1 = {
   HEALTHY = "37.36 29.41\n",
   dhcp6 = {
      dns_servers = {
	 ["1"] = "2001:8b0::2020",
	 ["2"] = "2001:8b0::2021"
      },
      ia_na = {
	 ["1"] = "2001:8b0:1111:1111:0:ffff:51bb:165b/128,3600,7200"
      },
      ia_pd = {
	 ["1"] = "2001:8b0:de3a:40dc::/64,7200,7200"
      },
      ntp_server = {}

   },
   ra = {
      routes = {}
   }
}

assert(f.get_in(t1, "dhcp6", "ia_na", "1") == "2001:8b0:1111:1111:0:ffff:51bb:165b/128,3600,7200")
assert(f.get_in(t1, "dhcp6", "ia_na", "17", "55") == nil)
