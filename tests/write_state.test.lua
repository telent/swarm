local swarm = require("swarm")
local inspect = require("inspect")

-- it dumps a table of flat values

swarm.write_state("flatland", {
		     key1 = "42",
		     hello = "world",
		     zz9 = "triple z\nalpha\nquick brown fox\nlazy dog"
})

expected = [[flatland/hello:1:world
flatland/key1:1:42
flatland/zz9:1:triple z
flatland/zz9:2:alpha
flatland/zz9:3:quick brown fox
flatland/zz9:4:lazy dog
]]
out = swarm.capture("cd %s && grep -nR '' flatland |sort", swarm.SERVICES_BASE_PATH)
assert(out==expected)


-- it dumps a nested table

swarm.write_state("nestd", {
		     key1 = "42",
		     tbl = { nom = "mensa", acc = "mensam" },
		     lst = { "heavy", "heavy", "monster", "sound" },
		     hello = "world",
})

expected = [[nestd/hello:1:world
nestd/key1:1:42
nestd/lst/1:1:heavy
nestd/lst/2:1:heavy
nestd/lst/3:1:monster
nestd/lst/4:1:sound
nestd/tbl/acc:1:mensam
nestd/tbl/nom:1:mensa
]]
out = swarm.capture("cd %s && grep -nR '' nestd |sort", swarm.SERVICES_BASE_PATH)
assert(out==expected)

-- it creates files under numeric keys in nested table

swarm.write_state("undernum", {
		     key1 = "42",
		     key2 = {
			{ a = "vowel"},
			{ b = "consonant" },
			{ e = "vowel"},
			{ y = "sometimes"}}
})
expected=[[
undernum/key1:1:42
undernum/key2/1/a:1:vowel
undernum/key2/2/b:1:consonant
undernum/key2/3/e:1:vowel
undernum/key2/4/y:1:sometimes
]]
out = swarm.capture("cd %s && grep -nR '' undernum |sort", swarm.SERVICES_BASE_PATH)
assert(out==expected)