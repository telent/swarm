local inspect = require("inspect")
local f = require("prelude")

SERVICES_BASE_PATH = os.getenv("SWARM_BASE_PATH") or "/run/swarm/services"

function slurp(name)
   local f = io.open(name, "r")
   local contents = f:read("*all")
   f:close()
   return contents
end

function spit(name, contents)
   local f = io.open(name, "wb")
   f:write(contents)
   f:close()
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
   return false
end

function write_state(service_name, state)
   -- this needs to delete files that don't correspond to table keys,
   -- otherwise it will leave stale data around. Also, need some way
   -- to ensure that downstreams are not reading partly-written files
   for key, value in pairs(state) do
      local absdir = path_append(SERVICES_BASE_PATH, service_name)
      if not isdir(absdir) then mkdir(absdir) end
      local relpath = path_append(service_name, key)
      if type(value) == 'table' then
	 write_state(relpath, value)
      else
	 spit(path_append(SERVICES_BASE_PATH,relpath), value)
      end
   end
end

local log = {
   info = function(format_string, ...)
      local line = string.format(format_string, ...)
      print(line)
   end,
   debug = function(format_string, ...)
      if os.getenv("SWARM_DEBUG") then
	 local line = string.format(format_string, ...)
	 print(line)
      end
   end,
}

function flatten_env(env_table)
   local flat = {}
   -- what should we do if we get non-string v?
   for k, v in pairs(env_table) do
      table.insert(flat, k .. "=" .. v)
   end
   return flat
end

function spawn(watcher, pathname, args, options)
   local pid, failure, outfd, errfd = (options.capture and pfork or fork)()
   if pid==0 then -- child
      -- should we close filehandles here? have we left any open?
      local flat_env = flatten_env(options.env) -- numeric indexes
      or_fail(execve(pathname, args, flat_env))
      os.exit(0)      -- this *should* be unreachable
   elseif pid > 0 then
      log.info("running %s %s, pid %d", pathname, inspect(args), pid)
      log.debug("environment for pid %d: %s", pid, inspect(options.env))
      if options.capture then
	 watcher:watch_fd(outfd, {pid = pid, stream = "stdout"})
	 watcher:watch_fd(errfd, {pid = pid, stream = "stderr"})
      end
   else
      log.info("fork %s %s failed: %d", pathname, inspect(args), failure)
   end
   return or_fail(pid, failure)
end

function events(me, timeout_ms)
   return function()
      local e = next_event(me.sigchld_fd, me.inotify_fd, me.child_fds, timeout_ms)
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
	 e.changed = changed
	 e.changes =  changes
	 e.values = values
      elseif e.type == "stream" then
	 source = me.child_fds[e.fd]
	 e.source = source
      end
      return e
   end
end

function new_watcher()
   return {
      sigchld_fd = or_fail(sigchld_fd()),
      inotify_fd = or_fail(inotify_init()),
      watches = {},
      services = {},
      child_fds = {},
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
      watch_fd = function(me, fd, source)
	 me.child_fds[fd] = source
      end,
      spawn = spawn,
      events = events,
   }
end

return {
   watcher = new_watcher,
   write_state = write_state,
   run = function(pathname, args, env)
      env = env or ENV
      local pid = spawn(pathname, args, env)
      -- might be appropriate to have a timeout here
      log.info("waiting for pid %d", pid)
      return or_fail(waitpid(pid))
   end,
   run_async = function(pathname, args, env)
      return spawn(pathname, args, env or ENV)
   end,
   capture = function(format_string, ...)
      local command = string.format(format_string, ...)
      return io.popen(command):read("*all")
   end,

   -- exported for testing
   read_tree = read_tree,
   path_append = path_append,
   SERVICES_BASE_PATH = SERVICES_BASE_PATH
}
