local f = require("prelude")
local inspect = require("inspect")

actual = f.map(function(x) return 2*x end, {1,23,4,5,6,9})
assert(inspect(actual) == inspect({ 2, 46, 8, 10, 12, 18 }))

assert(f.find(function(x) return (x%7==0) end, {2,12,26,21}) == 21)

assert(inspect(f.invert({a="z", b="q", n="99"})) ==
       inspect({z="a", q="b", ["99"] = "n"}))
