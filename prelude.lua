local inspect = require("inspect")

--  a random selection of "functional" functions patterned broadly
--  after Ruby's Enumerable interface

return {
   find = function(f,collection)
      for k,v in pairs(collection) do
	 if f(v) then
	    return v--"FHGDJDGJGFHJ"
	 end
      end
   end

}
