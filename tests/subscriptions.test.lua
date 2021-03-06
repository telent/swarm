local swarm = require("swarm")
local inspect = require("inspect")

function find_event(fn)
   local received = false
   for event in w:events(0.1) do
      if event.changes and fn(event) then
	 received = event
      end
   end
   return received
end

-----------------------
-- given a service exists with some values

swarm.write_state("a_service", {key1 = "val1", key2 = "val2"  })

-- and I have subscribed to one of them

w = swarm.watcher({})
w:subscribe("a_service", {"key1"})

-- when I change it
swarm.write_state("a_service", {key1 = "octopus", key2 = "val2"  })

-- I am notified and I can see the new value
assert(find_event(function (event)
	     return event.changes["a_service"]["key1"] and
		w.values.a_service.key1 == "octopus"
		 end),
       "missing event")

-----------------------
-- given I subscribe to a service that exists with some values

swarm.write_state("a_service", {key1 = "val1", key2 = "val2"  })
w = swarm.watcher({})
w:subscribe("a_service", {"key1"})

-- when I change only value(s) I am not subscribed to
swarm.write_state("a_service", {key1 = "val1", key2 = "val3"  })

-- I am not notified
e = find_event(function (e) return e end)
assert(not e, "received event unexpectedly: " .. inspect(e))

-----------------------
-- given a service exists
swarm.write_state("a_service", {key1 = "val1", key2 = "val2"  })

-- and I have subscribed to a value that is not present
w = swarm.watcher({})
w:subscribe("a_service", {"key10"})

-- when it is added
swarm.write_state("a_service", {key1 = "val1", key2 = "val2", key10 = "heart"})

-- I am notified
assert(find_event(function (event)
	     return event.changes["a_service"]["key10"] and
		w.values.a_service.key10 == "heart"
		 end),
       "event not found")

-----------------------
-- given a service does *not* exist
-- and I have subscribed to a value that is not present
w = swarm.watcher({})
w:subscribe("service_not_started", {"key10"})

-- when it is added
swarm.write_state("service_not_started", {key10 = "heart"})

-- I am notified
assert(find_event(function (event)
	     return event.changes["service_not_started"]["key10"] and
		w.values.service_not_started.key10 == "heart"
		 end), "missing event")

-----------------------
-- given a service did not exist when I subscribed to it
w = swarm.watcher({})
w:subscribe("service_not_started_2", {"key10"})

-- and that it was added
swarm.write_state("service_not_started_2", {key10 = "heart"})

-- I am notified for second and subsequent changes to state, not
-- just the first

assert(find_event(function (event)
	     return event.changes["service_not_started_2"]["key10"] and
		w.values.service_not_started_2.key10 == "heart"
		 end), "missing event")

swarm.write_state("service_not_started_2", {key10 = "club"})

assert(find_event(function (event)
	     return event.changes["service_not_started_2"]["key10"] and
		w.values.service_not_started_2.key10 == "club"
		 end), "missing event")

------------
-- given a service exists with some values
swarm.write_state("a_service2", {key1 = "val1", key2 = "val2"  })

-- and I have subscribed to one of them

w = swarm.watcher({})
w:subscribe("a_service2", {"key1"})

-- when it is deleted
swarm.write_state("a_service2", { key2 = "val2"  })

-- I am notified and I can see the change
assert(find_event(function (event)
	     return event.changes["a_service2"]["key1"] and
		w.values.a_service2.key1 == nil
		 end),
       "missing event")

-- when it is recreated
swarm.write_state("a_service2", { key1= "revenant", key2 = "val2"  })
-- I am notified again
assert(find_event(function (event)
	     return event.changes["a_service2"]["key1"] and
		w.values.a_service2.key1 == "revenant"
		 end),
       "missing event")

-- my notification tells me what has changed since the previous notification
-- (even values I am not subscribed to)
