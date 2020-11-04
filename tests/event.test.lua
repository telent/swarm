local swarm = require("swarm")
local inspect = require("inspect")
local f = require("prelude")

local before = {
   status = "HEY",
   uptime = 42,
   address = {
      network = "127.0.0.1",
      mask = "24"
   }
}

local after = {
   status = "HEY",
   uptime = 43,
   address = {
      network = "127.0.0.1",
      mask = "25"
   }
}

local event= {
   changes = { svc = f.difftree(before,after) },
   changed = swarm.changed
}

-- it detects changes
assert(event:changed("svc", "uptime"))
-- it detects changes in nested tables
assert(event:changed("svc", "address", "mask"))
-- the parent has changed if any child has
assert(event:changed("svc", "address"))
-- it does not return false positives
assert(not event:changed("svc", "address", "network"))
-- it does not barf if keys don't exist
assert(not event:changed("ssvc", "address", "network"))
