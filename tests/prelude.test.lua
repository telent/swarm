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
