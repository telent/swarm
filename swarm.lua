local inspect = require("inspect")
local f = require("prelude")

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

function or_fail(value, failed)
   if value then
      return value
   else
      error("syscall error: " .. errno[failed])
   end
end

function dirname(pathname)
   print(pathname)
   return pathname:match("(.*/)")
end

SERVICES_BASE_PATH = "/tmp/services"

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
	    print(file .. " does not exist")
	    me:watch_file(dirname(file))
	 else
	    error("watch_file: " .. err .. ", " .. (errno[err] or "(unknown)"))
	 end
      end,
      events = function(me)
	 return function()
	    local e = next_event(me.child_fd, me.inotify_fd, 10000)
	    if e and e.type == "file" then
	       e.files = f.map(function(wd) return me.watches[wd] end,
		  e.watches)
	    end
	    return e
	 end
      end
   }
end

-- this does not work recursively, it would be rather good if it did
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
   read_tree = read_tree,
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
   end
}
