#include <errno.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/inotify.h>
#include <sys/signalfd.h>
#include <unistd.h>

static int l_return_or_error(lua_State *L, int value) {
  if(value >= 0) {
    lua_pushinteger(L, value);
    return 1;
  }
  else {
    lua_pushnil(L);
    lua_pushinteger(L, errno);
    return 2;
  }
}

static int l_inotify_init(lua_State *L) {
  int fd = inotify_init1(IN_NONBLOCK|IN_CLOEXEC);
  return l_return_or_error(L, fd);
}

static int l_inotify_add_watch(lua_State *L) {
  int watch_d;
  int fd = lua_tonumber(L, -2);
  const char* name  = lua_tostring(L, -1);
  watch_d = inotify_add_watch(fd, name,
			      IN_CLOSE_WRITE |
			      IN_DELETE |
			      IN_DELETE_SELF |
			      IN_MOVED_TO);
  return l_return_or_error(L, watch_d);
}

static int l_sigchld_fd(lua_State *L) {
  sigset_t mask;
  sigemptyset(&mask);
  sigaddset(&mask, SIGCHLD);
  sigprocmask(SIG_BLOCK, &mask, NULL);
  int fd = signalfd(-1, &mask, SFD_NONBLOCK|SFD_CLOEXEC);
  return l_return_or_error(L, fd);
}

static int l_push_siginfo(lua_State *L, struct signalfd_siginfo *si) {
  lua_createtable(L, 0, 5);

  lua_pushstring(L, "code");
  lua_pushinteger(L, si->ssi_code);
  lua_settable(L, -3);

  lua_pushstring(L, "pid");
  lua_pushinteger(L, si->ssi_pid);
  lua_settable(L, -3);

  lua_pushstring(L, "utime");
  lua_pushnumber(L, ((double) si->ssi_utime) / sysconf(_SC_CLK_TCK)  );
  lua_settable(L, -3);

  lua_pushstring(L, "stime");
  lua_pushnumber(L, ((double) si->ssi_stime) / sysconf(_SC_CLK_TCK)  );
  lua_settable(L, -3);

  lua_pushstring(L, "status");
  lua_pushinteger(L, si->ssi_status);
  lua_settable(L, -3);

  return 1;
}

static int l_sleep(lua_State *L) {
  sleep(lua_tonumber(L, -1));
  return 0;
}

static int l_fork(lua_State *L) {
  pid_t child = fork();
  lua_pushinteger(L, child);
  return 1;
}

static int l_next_event(lua_State *L) {
  struct pollfd pollfd[2];
  struct signalfd_siginfo si;

  /* receives a sigchld fd and an inotify fd. */
  int inotify_fd = lua_tonumber(L, -2);
  int sigchld_fd = lua_tonumber(L, -3);
  int timeout_msec = lua_tonumber(L, -1);

  pollfd[0].fd = sigchld_fd;
  pollfd[0].events = POLLIN|POLLPRI;
  pollfd[1].fd = inotify_fd;
  pollfd[1].events = POLLIN|POLLPRI;
  int nfds = poll(pollfd, 2, timeout_msec);

  if(pollfd[0].revents) {
    if(read(pollfd[0].fd, &si, sizeof(struct signalfd_siginfo))) {
      lua_pushstring(L, "child");
      return 1 + l_push_siginfo(L, &si);
    }
    return 0;
  } else if (pollfd[1].revents) {
    struct inotify_event ino_events[6];
    int num;
    if(num = read(pollfd[1].fd, ino_events, sizeof ino_events)) {
      lua_pushstring(L, "file");
      lua_newtable(L);
      for(int i=0; i < num/sizeof( struct inotify_event); i++) {
	lua_pushinteger(L, ino_events[i].wd);
	lua_pushinteger(L, ino_events[i].wd);
	lua_settable(L, -3);
      }
      return 2;
    }
    return 0;
  } else {
    return 0;			/* no return for timeout */
  }
}


int
main(int argc, char *argv[])
{
    int status, result, i;
    double sum;
    lua_State *L;

    /*
     * All Lua contexts are held in this structure. We work with it almost
     * all the time.
     */
    L = luaL_newstate();

    luaL_openlibs(L); /* Load Lua libraries */

    /* Load the file containing the script we are going to run */
    status = luaL_loadfile(L, argv[1]);
    if (status) {
        /* If something went wrong, error message is at the top of */
        /* the stack */
        fprintf(stderr, "Couldn't load file: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    /*
     * Ok, now here we go: We pass data to the lua script on the stack.
     * That is, we first have to prepare Lua's virtual stack the way we
     * want the script to receive it, then ask Lua to run it.
     */
    lua_newtable(L);    /* We will pass a table */

    /*
     * To put values into the table, we first push the index, then the
     * value, and then call lua_rawset() with the index of the table in the
     * stack. Let's see why it's -3: In Lua, the value -1 always refers to
     * the top of the stack. When you create the table with lua_newtable(),
     * the table gets pushed into the top of the stack. When you push the
     * index and then the cell value, the stack looks like:
     *
     * <- [stack bottom] -- table, index, value [top]
     *
     * So the -1 will refer to the cell value, thus -3 is used to refer to
     * the table itself. Note that lua_rawset() pops the two last elements
     * of the stack, so that after it has been called, the table is at the
     * top of the stack.
     */
    for (i = 1; i <= 5; i++) {
        lua_pushnumber(L, i);   /* Push the table index */
        lua_pushnumber(L, i*2); /* Push the cell value */
        lua_rawset(L, -3);      /* Stores the pair in the table */
    }

    /* By what name is the script going to reference our table? */
    lua_setglobal(L, "foo");
    lua_register(L, "inotify_init", l_inotify_init);
    lua_register(L, "inotify_add_watch", l_inotify_add_watch);
    lua_register(L, "sigchld_fd", l_sigchld_fd);
    lua_register(L, "next_event", l_next_event);
    lua_register(L, "fork", l_fork);
    lua_register(L, "sleep", l_sleep);

    /* Ask Lua to run our little script */
    result = lua_pcall(L, 0, LUA_MULTRET, 0);
    if (result) {
        fprintf(stderr, "Failed to run script: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    /* Get the returned value at the top of the stack (index -1) */
    sum = lua_tonumber(L, -1);

    printf("Script returned: %.0f\n", sum);

    lua_pop(L, 1);  /* Take the returned value out of the stack */
    lua_close(L);   /* Cya, Lua */

    return 0;
}
