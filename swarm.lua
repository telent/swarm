local inspect = require("inspect")
-- table = require('table')
return {
  subscribe = function(files)
     return {
	files = files,
	wait = function(me)
	   local i = 0
	   return function()
	      i = i + 1
	      if i <= #me.files then return {
		    source = me.files[i], address = "2001::1", netmask="64"
					     }
	      end
	   end
     end }
  end,
  write_state = function(state)
     print(inspect(state))
  end,
  exec = function(format_string, ...)
     print("EXEC: ".. string.format(format_string, ...))
  end,
  capture = function(format_string, ...)
     local command = string.format(format_string, ...)
     return io.popen(command):read("*all")
  end
}
