local swarm = require("swarm")
local inspect = require("inspect")

-- given a service exists with some values

swarm.write_state("a_service", {key1 = "val1", key2 = "val2"  })

-- and I have subscribed to one of them

w = swarm.watcher({})
w:subscribe("a_service", {"key1"})

-- when I change it
swarm.write_state("a_service", {key1 = "octopus", key2 = "val2"  })

-- I am notified and I can see the new value
local received = false
for event in w:events(0.1) do
   if event.changed and
      event:changed("a_service", {"key1"}) and
      w.values.a_service.key1 == "octopus" then
      received = true
   end
end
assert(received, "missing event")

-- when I change a value I am not subscribed to
-- I am not notified

-- given a service exists
-- and I have subscribed to a value that is not present
-- when it is added
-- I am notified

-- given a service does not exist
-- and I have subscribed to a value that is not present
-- when it is added
-- I am notified

-- given a service exists with some values
-- and I have subscribed to one of them
-- when it is deleted
-- I am notified
-- when it is recreated
-- I am notified again

-- my notification tells me what has changed since the previous notification
-- (even values I am not subscribed to)
