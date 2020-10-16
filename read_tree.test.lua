local read_tree = require("swarm").read_tree
local inspect = require("inspect")

-- it reads a folder of flat files
actual = read_tree("ew/12/12", os.getenv("PWD").."/fixtures")
expected = {
   HEY = "",
   docker0 = "15145\n",
   wlp4s0 = "26315\n",
   wwp0s20f0u2i12 = "5195\n"
}
assert(inspect(actual) == inspect(expected))

-- it recurses into subdirectories
actual = read_tree("a", os.getenv("PWD").."/fixtures")
expected  = {
   ["1/dev"] = "wlp4s0\n",
   ["1/dst"] = "default\n",
   ["1/metric"] = "600\n",
   ["2/dev"] = "docker0\n",
   ["2/dst"] = "172.17.0.0/16\n",
   ["2/metric"] = "\n",
   ["3/HEY"] = "",
   ["3/dev"] = "wlp4s0\n",
   ["3/dst"] = "192.168.8.0/24\n",
   ["3/metric"] = "600\n",
   ["4/dev"] = "rodney\n",
   ["4/dst"] = "192.168.8.0/23\n",
   ["4/metric"] = "\n",
   ["5/dev"] = "rodney\n",
   ["5/dst"] = "192.168.9.0/24\n",
   ["5/metric"] = "\n",
   ["7/HEY"] = "",
   ["8/HEY"] = "",
}
-- print(inspect(actual))
assert(inspect(actual) == inspect(expected))
