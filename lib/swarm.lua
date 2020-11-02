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
   local tmp=name .. "#"
   local f,err = io.open(tmp, "wb")
   if not f then
      print(err)
   end

   f:write(contents)
   f:close()
   os.rename(tmp, name)
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
	 if name:sub(1,1) == "." or name:sub(-1) == "#"  then
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

function rm_r(pathname)
   local ret, strerr, errno = os.remove(pathname)
   if not ret and errno==39 then
      for _,member in ipairs(dir(pathname)) do
	 if not (member == "." or member == "..") then
	    rm_r(path_append(pathname, member))
	 end
      end
   end
end

function write_state(service_name, state)
   local absdir = path_append(SERVICES_BASE_PATH, service_name)
   if not isdir(absdir) then mkdir(absdir) end
   if state.healthy then
      state.HEALTHY = slurp("/proc/uptime")
   end
   state.healthy = nil
   local existing = f.invert(dir(absdir)) or {}
   for key, value in pairs(state) do
      existing[key] = nil
      local relpath = path_append(service_name, key)
      if type(value) == 'table' then
	 write_state(relpath, value)
      else
	 spit(path_append(SERVICES_BASE_PATH,relpath), value)
      end
   end
   for oldfile, _ in pairs(existing) do
      if not (oldfile == '.' or oldfile == '..') then
	 rm_r(path_append(absdir, oldfile))
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

function capture_streams_sync(fds)
   local captured = '';
   -- call next_event directly to avoid collecting events on other
   -- fds as well as these ones
   while true do
      event = next(fds) and next_event(-1, -1, fds, 10)
      if not event then break end
      if event.message then
	 captured = captured .. event.message
      else
	 fds[event.fd]=nil
      end
   end
   return captured
end

function spawn(watcher, pathname, args, options)
   local flat_env = flatten_env(watcher.environ) -- numeric indexes
   local pid, failure, outfd, errfd = (options.capture and pfork or fork)()
   if not pid then -- error
      log.info("fork %s %s failed: %d", pathname, inspect(args), failure)
   elseif pid==0 then -- child
      -- should we close filehandles here? have we left any open?
      or_fail(execve(pathname, args, flat_env))
      os.exit(0)      -- this *should* be unreachable
   elseif pid > 0 then
      log.info("running %s %s, pid %d", pathname, inspect(args), pid)
      log.debug("environment for pid %d: %s", pid, inspect(flat_env))
      if options.capture and not options.wait then
	 watcher:watch_fd(outfd, {pid = pid, stream = "stdout"})
	 watcher:watch_fd(errfd, {pid = pid, stream = "stderr"})
      end
   end

   if options.wait then
      local pid, failure = waitpid(pid)
      if(options.capture) then
	 local fds = {
	    [outfd] = {pid = pid, stream="stdout"},
	    [errfd] = {pid = pid, stream="stderr"}
	 }
	 return capture_streams_sync(fds)
      end
   end
   return or_fail(pid, failure)
end

function events(me, timeout_ms)
   timeout_ms = timeout_ms or 30*1000
   return function()
      local e = next_event(me.sigchld_fd, me.inotify_fd, me.child_fds, timeout_ms)
      if not e then return nil end
      if e.type == "file" then
	 local need_reread = {}
	 for wd,mask in pairs(e.watches) do
	    need_reread[me.watches[wd]]=true
	 end
	 changes = {}
	 for service,_ in pairs(need_reread) do
	    local state = read_tree(service)
	    changes[service] = {
	       before = me.values[service],
	       after = state
	    }
	    me.values[service] = state
	 end
	 e.changed = changed
	 e.changes = changes
      elseif e.type == "stream" then
	 source = me.child_fds[e.fd]
	 e.source = source
	 if not e.message then
	    me:watch_fd(e.fd, nil)
	 end
      end
      return e
   end
end

function new_watcher(config)
   local config = config or {}
   config.environ = config.environ or {
      PATH = os.getenv("PATH"),
      TERM = "dumb",
   };
   return {
      sigchld_fd = or_fail(sigchld_fd()),
      inotify_fd = or_fail(inotify_init()),
      watches = {},		-- map of watch descriptor -> service name
      values = {},		-- \/ subscriptions, servicename -> values
      child_fds = {},		-- fd -> {pid, stream name}
      environ = config.environ,
      config = config,
      subscriptions = {},	-- servicename -> array of watched filenames
      subscribe = function(me, service, files)
	 base_path = path_append(SERVICES_BASE_PATH, service)
	 me.subscriptions[service] =
	    f.cat_tables(me.subscriptions[service] or {}, files)
	 for _,file in ipairs(files) do
	    local dir = dirname(path_append(base_path, file))
	    me:watch_file(service, dir)
	 end
      end,
      watch_file = function(me, service, file)
	 wd, err = inotify_add_watch(me.inotify_fd, file)
	 if wd then
	    me.watches[wd] = service
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
   -- the swarm table is getting smaller with every day.
   -- current thinking is that we can get rid of it
   -- completely and do everything from inside watcher
   watcher = new_watcher,
   write_state = write_state,

   -- exported for testing
   read_tree = read_tree,
   path_append = path_append,
   SERVICES_BASE_PATH = SERVICES_BASE_PATH
}
