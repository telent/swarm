local inspect = require("inspect")

--  a random selection of "functional" functions patterned broadly
--  after Ruby's Enumerable interface

function find(f,collection)
   for k,v in pairs(collection) do
      if f(v) then
	 return v
      end
   end
end
	 end
      end
return {
   find = find,
   contains = function(collection, item)
      return find(function(x) return x==item end, collection)
   end,
   map = function(f,collection)
      local out={}
      for k,v in pairs(collection) do
	 out[k] = f(v)
      end
      return out
   end,
   cat_tables = function(t1, t2)
      for i=1, #t2 do
	 t1[#t1+i] = t2[i]
      end
      return t1
   end,
   invert = function(t1)
      local out={}
      for k,v in pairs(t1) do
	 out[v]=k
      end
      return out
   end
}
