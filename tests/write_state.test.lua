local swarm = require("swarm")
local inspect = require("inspect")

function qx(command, ...)
   local s = io.popen(string.format(command,...), "r")
   local content = s:read("*all")
   s:close()
   return content
end

function randomstring(length)
   local res = ""
   for i = 1, length do
      res = res .. string.char(math.random(97, 122))
   end
   return res
end

function write_and_read(tree, servicename)
   servicename = servicename or randomstring(10)
   swarm.write_state(servicename, tree)
   return qx("cd %s/%s && grep -nR '' * |sort",
	     swarm.SERVICES_BASE_PATH,
	     servicename)
end

-- it dumps a table of flat values

actual = write_and_read({
      key1 = "42",
      hello = "world",
      zz9 = "triple z\nalpha\nquick brown fox\nlazy dog"
})

expected = [[hello:1:world
key1:1:42
zz9:1:triple z
zz9:2:alpha
zz9:3:quick brown fox
zz9:4:lazy dog
]]

assert(actual==expected)


-- it dumps a nested table

actual = write_and_read({
      key1 = "42",
      tbl = { nom = "mensa", acc = "mensam" },
      lst = { "heavy", "heavy", "monster", "sound" },
      hello = "world",
})

expected = [[hello:1:world
key1:1:42
lst/1:1:heavy
lst/2:1:heavy
lst/3:1:monster
lst/4:1:sound
tbl/acc:1:mensam
tbl/nom:1:mensa
]]
assert(actual==expected)

-- it creates files under numeric keys in nested table

actual=write_and_read({
      key1 = "42",
      key2 = {
	 { a = "vowel"},
	 { b = "consonant" },
	 { e = "vowel"},
	 { y = "sometimes"}}
})
expected=[[
key1:1:42
key2/1/a:1:vowel
key2/2/b:1:consonant
key2/3/e:1:vowel
key2/4/y:1:sometimes
]]
-- it writes a timestamp in HEALTHY if passed a state with
-- a truthy `healthy` key

timestamp = qx("cat /proc/uptime | cut -d' ' -f1")
actual = write_and_read({ healthy = true, })

for match in actual:gmatch("HEALTHY:1:(%d+.%d+)") do
   assert((match + 0) - (timestamp +0) < 1)
end

-- it does not write HEALTHY if no truthy `healthy` key

actual = write_and_read({ healthy = false, state = "bad"})
assert(not actual:find("HEALTHY"))


-- it removes previous state when writing new state

local servicename=randomstring(10)
write_and_read({
      healthy = false,
      state = "bad",
      zombie = "brains"
	       }, servicename)
actual = write_and_read({ healthy = true }, servicename)

assert(not actual:find("zombie:1:brains"))

local servicename=randomstring(10)
write_and_read({
      healthy = false,
      state = "bad",
      zombie = { need = "brains" }
	       }, servicename)
actual = write_and_read({ healthy = true }, servicename)
assert(not actual:find("zombie/need:1:brains"), actual)
