return [[
/* Copyright The LuaBundler Contributors
SPDX: Apache-2.0
*/
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>


// !lua-bundler-placeholder(pre-decls)

typedef int (*lua_bundler_lua_libopen_fn)(lua_State *S);

enum lua_bundler_pak_kind {
  LUA_BUNDLER_PAK_SRC,
  LUA_BUNDLER_PAK_NATIVE,
};

struct lua_bundler_dvec {
  void *data;
  size_t len;
};

union lua_bundler_bundled_pak_target {
  struct lua_bundler_dvec src;
  lua_bundler_lua_libopen_fn native_open_fn;
};

struct lua_bundler_bundled_pak {
  const char *name;
  const char *path; // might be NULL at runtime
  enum lua_bundler_pak_kind kind;
  union lua_bundler_bundled_pak_target target;
};

struct lua_bundler_src_reader_state {
  const struct lua_bundler_bundled_pak *pak;
  size_t read_len;
};

extern const size_t LUA_BUNDLER_BUNDLED_PAKS_LEN;
extern const struct lua_bundler_bundled_pak LUA_BUNDLER_BUNDLED_PAKS[];

// !lua-bundler-placeholder(declarations)

static int lua_bundler_bundled_get_searchers(lua_State *S) {
  luaL_checkstack(S, 2, NULL);
  int ret;
  if ((ret = lua_getglobal(S, "package")) != LUA_TTABLE) {
    luaL_error(S,
               "bundle install_seacher error: global \"package\" is not a "
               "table? (a %s)",
               luaL_typename(S, -1));
  }
  if ((ret = lua_getfield(S, -1, "searchers")) != LUA_TTABLE) {
    luaL_error(S,
               "bundle install_seacher error: global \"package.searcher\" "
               "is not a table? (a %s)",
               luaL_typename(S, -1));
  }
  lua_remove(S, -2);
  return 1;
}

static void lua_bundler_bundled_disable_external_searchers(lua_State *S) {
  int ret = luaL_dostring(S, "for i=3,5 do package.searchers[i] = nil end");
  if (ret != LUA_OK) {
    lua_error(S);
  }
}

static const char *lua_bundler_src_reader(lua_State *S, void *data,
                                          size_t *size) {
  struct lua_bundler_src_reader_state *state = data;
  if (state->read_len == 0) {
    *size = state->pak->target.src.len;
    state->read_len = state->pak->target.src.len;
    return state->pak->target.src.data;
  } else {
    *size = 0;
    return NULL;
  }
}

static int lua_bundler_bundled_searcher(lua_State *S) {
  // params: string (the name of the package)
  const char *pakname = luaL_checkstring(S, 1);
  for (size_t i = 0; i < LUA_BUNDLER_BUNDLED_PAKS_LEN; i++) {
    const struct lua_bundler_bundled_pak *pak = &LUA_BUNDLER_BUNDLED_PAKS[i];
    if (strcmp(pakname, pak->name) == 0) {
      luaL_checkstack(S, 2, NULL);
      switch (pak->kind) {
      case LUA_BUNDLER_PAK_NATIVE:
        lua_pushcfunction(S, pak->target.native_open_fn);
        lua_pushstring(S, pak->name);
        return 2;
      case LUA_BUNDLER_PAK_SRC: {
        struct lua_bundler_src_reader_state reader_state = {
            .pak = pak,
            .read_len = 0,
        };
        luaL_checkstack(S, 1, NULL);
        if (pak->path !=
            NULL) { /* build chunk name based on file path or package name */
          lua_pushfstring(S, "@%s", pak->path);
        } else {
          lua_pushfstring(S, "=%s", pak->name);
        }
        int loadret = lua_load(S, &lua_bundler_src_reader, &reader_state,
                               lua_tostring(S, -1), "t");
        switch (loadret) {
        case LUA_ERRSYNTAX:
          lua_error(S);
        case LUA_ERRMEM:
          lua_error(S);
        }
        lua_pushstring(S, pak->name);
        return 2;
      }
      }
    }
  }
  lua_pushfstring(S, "package \"%s\" is not bundled", pakname);
  return 1;
}

// It's NOT a Lua C function and is intended to be call in C
// Push the table into the stack before call this function
static int lua_bundler_bundled_table_copy(lua_State *S, lua_Integer start,
                                          lua_Integer length,
                                          lua_Integer target) {
  luaL_checkstack(S, 1, NULL);
  for (lua_Integer i = length; i >= 0; i--) {
    lua_geti(S, -1, start + length);
    lua_seti(S, -2, target + length);
  }
  return LUA_OK;
}

static int lua_bundler_bundled_install_searcher(lua_State *S) {
  // params:
  luaL_checkstack(S, 2, NULL);
  lua_pushcfunction(S, &lua_bundler_bundled_get_searchers);
  lua_call(S, 0, 1);
  lua_Integer searchers_len = luaL_len(S, -1);
  if (lua_bundler_bundled_table_copy(S, 2, searchers_len - 1, 3) != LUA_OK) {
    lua_pop(S, 1);
    luaL_error(S, "bundle install_searcher error: failed to inject searcher "
                  "(table_copy)");
  }
  lua_pushcfunction(S, &lua_bundler_bundled_searcher);
  lua_seti(S, -2, 2);
  lua_pop(S, 2);
  return 0;
}

const char *LUA_BUNDLER_MAIN_PACKAGE =
    "// !lua-bundler-placeholder(main-package-name)";

static int lua_bundler_bundled_pmain(lua_State *S) {
  // params: integer (argcount), lightuserdata (args)
  lua_Integer argcount = luaL_checkinteger(S, 1);
  luaL_checktype(S, 2, LUA_TLIGHTUSERDATA);
  char **args = lua_touserdata(S, 2);

  luaL_requiref(S, LUA_GNAME, &luaopen_base, 1);
  luaL_requiref(S, LUA_LOADLIBNAME, &luaopen_package, 1);
  lua_pop(S, 2);

  luaL_checkstack(S, 2, NULL);
  lua_pushcfunction(S, &lua_bundler_bundled_install_searcher);
  lua_call(S, 0, 0);

  // !lua-bundler-placeholder(config-state)

  luaL_checkstack(S, 2, NULL);
  if (lua_getglobal(S, "require") != LUA_TFUNCTION) {
    luaL_error(S, "bundle pmain error: global \"require\" is not a function?");
  }
  lua_pushstring(S, LUA_BUNDLER_MAIN_PACKAGE);
  lua_call(S, 1, 1);
  lua_Integer ret = 0;
  if (lua_isfunction(S, -1)) {
    if (argcount > INT_MAX) {
      luaL_error(S, "too many arguments (limit is %d, got %lld)", INT_MAX,
                 argcount);
    }
    luaL_checkstack(S, argcount, NULL);
    for (lua_Integer i = 0; i < argcount; i++) {
      lua_pushstring(S, args[i]);
    }
    lua_call(S, argcount, 1);
    if (lua_isinteger(S, -1)) {
      ret = lua_tointeger(S, -1);
    } else if (lua_isboolean(S, -1)) {
      ret = lua_toboolean(S, -1);
    }
    lua_pop(S, 1);
  } else {
    luaL_error(S,
               "bundle pmain error: main package did not return a function to "
               "run (got %s).",
               luaL_typename(S, -1));
  }
  luaL_checkstack(S, 1, NULL);
  lua_pushinteger(S, ret);
  return 1;
}

static int luabundler_bundled_err_handler(lua_State *S) {
  const char *msg = lua_tostring(S, 1);
  if (msg == NULL) {
    if (luaL_callmeta(S, 1, "__tostring") == LUA_OK &&
        lua_type(S, -1) == LUA_TSTRING) {
      return 1;
    } else {
      msg = lua_pushfstring(S, "(error is a %s value)", luaL_typename(S, 1));
    }
  }
  luaL_traceback(S, S, msg, 1);
  return 1;
}

int main(int argcount, char *args[]) {
  lua_State *S = luaL_newstate();
  lua_pushcfunction(S, &luabundler_bundled_err_handler);
  int errhandler_idx = lua_gettop(S);
  lua_pushcfunction(S, &lua_bundler_bundled_pmain);
  luaL_checkstack(S, 2, NULL);
  lua_pushinteger(S, argcount);
  lua_pushlightuserdata(S, args);
  int status = lua_pcall(S, 2, 1, errhandler_idx);
  lua_Integer ret = 0;
  if (status != LUA_OK) {
    const char *msg = lua_tostring(S, -1);
    fprintf(stderr, "%s\n", msg);
    fflush(stderr);
    lua_pop(S, 1);
    ret = 1;
  } else {
    ret = lua_tointeger(S, -1);
    lua_pop(S, 1);
  }
  lua_close(S);

  if (ret >= INT_MIN && ret <= INT_MAX) {
    return ret;
  } else {
    fprintf(stderr, "unsupported return code: %lld\n", ret);
    fflush(stderr);
    return 22;
  }
}
]]
