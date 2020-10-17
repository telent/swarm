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


function changed(event, service, paths)
   if event.type == "file" then
      if event.changes and event.changes[service] then
	 local newer = event.changes[service].after
	 local older = event.changes[service].before
	 for _,path in ipairs(paths) do
	    if not older then
	       return true
	    end
	    if not (newer[path] == older[path]) then
	       return true
	    end
	 end
      end
   end
   return false
end

function new_watcher()
   return {
      child_fd = or_fail(sigchld_fd()),
      inotify_fd = or_fail(inotify_init()),
      watches = {},
      services = {},
      subscribe = function(me, service, files)
	 base_path = path_append(SERVICES_BASE_PATH, service)
	 me.services[service] = read_tree(service)
	 for _,file in ipairs(files) do
	    me:watch_file(service, path_append(base_path, file))
	 end
      end,
      watch_file = function(me, service, file)
	 wd, err = inotify_add_watch(me.inotify_fd, file)
	 if wd then
	    me.watches[wd] = { service = service, file = file };
	 elseif errno[err] == "ENOENT" then
	    -- XXX if we get a 'file created' event from the directory watch
	    -- here, we need to add a watch for the file as well
	    print(file .. " does not exist")
	    me:watch_file(service, dirname(file))
	 else
	    error("watch_file: " .. err .. ", " .. (errno[err] or "(unknown)"))
	 end
      end,
      events = function(me, timeout_ms)
	 return function()
	    local e = next_event(me.child_fd, me.inotify_fd, timeout_ms)
	    if not e then return nil end
	    if e.type == "file" then
	       local changes = {}
	       local values = {}
	       for _,wd in pairs(e.watches) do
		  local service_name = me.watches[wd].service
		  if not changes[service_name] then
		     values[service_name] = read_tree(service_name)
		     changes[service_name] = {
			before = me.services[service_name],
			after = values[service_name]
		     }
		     me.services[service_name] = values[service_name]
		  end
	       end
	       e.changes =  changes
	       e.values = values
	    end
	    e.changed = changed
	    return e
	 end
      end
   }
end

return {
   watcher = new_watcher,
   write_state = function(service_name, state)
      -- this is a stub, it should be writing into a run/servicename folder
      local msg = {}
      msg[service_name] = state
      print(inspect(msg))
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
