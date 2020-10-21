#!/usr/bin/env lua-swarm
local inspect = require("inspect")
local f = require("prelude")
local swarm = require("swarm")

w = swarm.watcher()
w:spawn(
   os.getenv("PROJECT_ROOT") .. "/tests/support/child.sh",
   {"child.sh"},
   {env = {TERM = "dumb", PATH="/usr/bin:/run/current-system/sw/bin/"},
    capture = true })
local finished = 0
local events={}
while finished < 10 do
   for event in w:events(10*1000) do
      if event.type=='stream' then
	 table.insert(events, event)
      end
   end
   finished = finished +1
end
assert(events[1].message == "capture output stream\n")
assert(events[1].source.stream == "stdout")
assert(events[2].message == "capture error stream\n")
assert(events[2].source.stream == "stderr")
assert(#events >= 3)
