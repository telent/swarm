#!/usr/bin/env lua-swarm
local inspect = require("inspect")
local f = require("prelude")
local swarm = require("swarm")

w = swarm.watcher({
      environ = {
	 TERM = "dumb", PATH="/usr/bin:/run/current-system/sw/bin/"
}})
pid = w:spawn(
   os.getenv("PROJECT_ROOT") .. "/tests/support/child.sh",
   { "child.sh" },
   { capture = true })
local finished = false
local events={}
while not finished  do
   for event in w:events(5*1000) do
      if event.type=='stream' then
	 table.insert(events, event)
      end
      if event.type == 'child' and event.pid == pid then
	 finished = true
	 break
      end
   end
end

assert(events[1].message == "capture output stream\n")
assert(events[1].source.stream == "stdout")
assert(events[2].message == "capture error stream\n")
assert(events[2].source.stream == "stderr")
assert(#events >= 3)
