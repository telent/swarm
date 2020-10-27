ethernet = require("ethernet")
ethernet({
      name = "lan",
      iface = "wlp4s0",
      paths = {
	 ip = "/run/current-system/sw/bin/ip"
      }
})
