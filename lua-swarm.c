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
#include <dirent.h>

#define ERRC(c) lua_pushinteger(L, c);  lua_pushstring(L, #c);  lua_rawset(L, -3)
static void l_errno_table(lua_State *L) {
  lua_newtable(L);
  ERRC(EACCES);
  ERRC(EEXIST);
  ERRC(EFAULT);
  ERRC(EINTR);
  ERRC(EINVAL);
  ERRC(ENOENT);
  ERRC(ENOSPC);
  ERRC(ENOTDIR);
  lua_setglobal(L, "errno");
}
#undef ERRC


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

/* this is a direct paste from http://www.lua.org/pil/26.1.html */

static int l_dir (lua_State *L) {
  DIR *dir;
  struct dirent *entry;
  int i;
  const char *path = luaL_checkstring(L, 1);

  /* open directory */
  dir = opendir(path);
  if (dir == NULL) {  /* error opening the directory? */
    lua_pushnil(L);
    lua_pushinteger(L, errno);
    return 2;  /* number of results */
  }

  /* create result table */
  lua_newtable(L);
  i = 1;
  while ((entry = readdir(dir)) != NULL) {
    lua_pushnumber(L, i++);  /* push key */
    lua_pushstring(L, entry->d_name);  /* push value */
    lua_settable(L, -3);
  }

  closedir(dir);
  return 1;  /* table is already on top */
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

    l_errno_table(L);
    /* Load the file containing the script we are going to run */
    status = luaL_loadfile(L, argv[1]);
    if (status) {
        /* If something went wrong, error message is at the top of */
        /* the stack */
        fprintf(stderr, "Couldn't load file: %s\n", lua_tostring(L, -1));
        exit(1);
    }

    lua_register(L, "inotify_init", l_inotify_init);
    lua_register(L, "inotify_add_watch", l_inotify_add_watch);
    lua_register(L, "sigchld_fd", l_sigchld_fd);
    lua_register(L, "next_event", l_next_event);
    lua_register(L, "fork", l_fork);
    lua_register(L, "dir", l_dir);
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
