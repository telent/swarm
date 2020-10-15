
function slurp(name)
   local f = io.open(name, "r")
   local contents = f:read("*all")
   f:close()
   return contents
end

function path_append(base, branch)
   if base:sub(-1) == "/" then
      return base .. branch
   else
      return base .. "/" .. branch
   end
end

function read_tree(base_directory, tree)
   local out={}
   local absolute_tree = path_append(base_directory, tree)
   for _,name in ipairs(dir(absolute_tree)) do
      local relname = path_append(tree, name)
      local absname = path_append(absolute_tree, name)
      if name == "." or name == ".." then
	 -- skip
      elseif isdir(absname) then
	 out[name] = read_tree(absolute_tree, name)
      else
	 out[name] = slurp(absname)
      end
   end
   return out
end

return read_tree;
