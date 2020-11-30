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

function get_in(t1, key1, ...)
   if t1[key1] then
      if ... then
	 return get_in(t1[key1], ...)
      else
	 return t1[key1]
      end
   else
      return nil
   end
end

-- returns a nested table whose keys are the keys of `old` that have
-- different values in `new` or vice versa. Include keys which are abent
-- from one or other table
function difftree(old, new)
   function difftree_(old, new, diff)
      for k,v in pairs(new) do
	 if type(v) == 'table' then
	    diff[k] = difftree(old[k] or {}, v)
	 else
	    if v ~= old[k] then
	       diff[k] = true
	    end
	 end
      end
      return diff
   end
   return difftree_(old, new, difftree_(new, old, {}))
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
   end,
   difftree = difftree,
   split_string = function(pattern, s)
      if s then
	 local chunks = {}
	 for substring in s:gmatch(pattern) do
	    table.insert(chunks, substring)
	 end
	 return chunks
      end
   end,
   get_in = get_in
}
