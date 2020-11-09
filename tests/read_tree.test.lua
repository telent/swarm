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
   ["1"] = {
      dev = "wlp4s0\n",
      dst = "default\n",
      metric = "600\n"
   },
   ["2"] = {
      dev = "docker0\n",
      dst = "172.17.0.0/16\n",
      metric = "\n"
   },
   ["3"] = {
      HEY = "",
      dev = "wlp4s0\n",
      dst = "192.168.8.0/24\n",
      metric = "600\n"
   },
   ["4"] = {
      dev = "rodney\n",
      dst = "192.168.8.0/23\n",
      metric = "\n"
   },
   ["5"] = {
      dev = "rodney\n",
      dst = "192.168.9.0/24\n",
      metric = "\n"
   },
   ["7"] = {
      HEY = ""
   },
   ["8"] = {
      HEY = ""
   }
}
assert(inspect(actual) == inspect(expected))
