local inspect = require("inspect")
local f = require("prelude")

SERVICES_BASE_PATH = "/tmp/services"

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

function read_tree(tree, base_path)
   base_path = base_path or SERVICES_BASE_PATH
   local out={}
   function read_tree_aux(prefix, absolute_tree)
      for _,name in ipairs(dir(absolute_tree)) do
	 local relname = prefix .. name
	 local absname = path_append(absolute_tree, name)
	 if name == "." or name == ".." then
	    -- skip
	 elseif isdir(absname) then
	    read_tree_aux(relname .. "/", absname)
	 else
	    out[relname] = slurp(absname)
	 end
      end
   end
   read_tree_aux("", path_append(base_path, tree))
   return out
end

function or_fail(value, failed)
   if value then
      return value
   else
      error("syscall error: " .. errno[failed])
   end
end

function dirname(pathname)
   return pathname:match("(.*/)")
end


function new_watcher()
   return {
      child_fd = or_fail(sigchld_fd()),
      inotify_fd = or_fail(inotify_init()),
      watches = {},
      subscribe = function(me, service, files)
	 base_path = path_append(SERVICES_BASE_PATH, service)
	 for _,file in ipairs(files) do
	    me:watch_file(path_append(base_path, file))
	 end
      end,
      watch_file = function(me, file)
	 wd, err = inotify_add_watch(me.inotify_fd, file)
	 if wd then
	    me.watches[wd] = file
	 elseif errno[err] == "ENOENT" then
	    -- XXX if we get a 'file created' event from the directory watch
	    -- here, we need to add a watch for the file as well
	    print(file .. " does not exist")
	    me:watch_file(dirname(file))
	 else
	    error("watch_file: " .. err .. ", " .. (errno[err] or "(unknown)"))
	 end
      end,
      events = function(me, timeout_ms)
	 return function()
	    local e = next_event(me.child_fd, me.inotify_fd, timeout_ms)
	    if e and e.type == "file" then
	       e.files = f.map(function(wd) return me.watches[wd] end,
		  e.watches)
	    end
	    return e
	 end
      end
   }
end

-- this does not work recursively, it would be rather good if it did.
-- also, perhaps it should warn if you're trying to look for changes on
-- a path you're not subscribed to?
function changed(newer, older, paths)
   for _,path in ipairs(paths) do
      if not (newer[path] == older[path]) then
	 return true
      end
   end
   return false
end

return {
   watcher = new_watcher,
   changed = changed,
   write_state = function(state)
      print(inspect(state))
   end,
   exec = function(format_string, ...)
      print("EXEC: ".. string.format(format_string, ...))
   end,
   capture = function(format_string, ...)
      local command = string.format(format_string, ...)
      return io.popen(command):read("*all")
   end,

   -- exported for testing
   read_tree = read_tree

}
