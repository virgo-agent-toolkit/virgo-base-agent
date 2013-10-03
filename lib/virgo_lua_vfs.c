/*
 *  Copyright 2012 Rackspace
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#include "virgo.h"
#include "virgo__types.h"
#include "virgo__lua.h"

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include "luaconf.h"

#include "bundle.h"

#include <archive.h>

#include <stdlib.h>
#include <string.h>

#define ZIPFILEHANDLE "lminizip"

typedef struct archive archive_t;
typedef struct archive_entry entry_t;

static archive_t*
newunzFile(lua_State *L)
{
  archive_t **a = (archive_t**)lua_newuserdata(L, sizeof(archive_t**));
  luaL_getmetatable(L, ZIPFILEHANDLE);
  lua_setmetatable(L, -2);
  return *a;
}

static archive_t*
zip_context(lua_State *L, int findex) {
  archive_t **a = (archive_t**)luaL_checkudata(L, findex, ZIPFILEHANDLE);
  if (a == NULL) {
    luaL_argerror(L, findex, "bad vfs context");
  }
  return *a;
}

static int
vfs_open(lua_State *L) {
  (void) newunzFile(L);
  return 1;
}

static int
vfs_close(lua_State *L) {
  luaL_checkudata(L, 1, ZIPFILEHANDLE);
  return 0;
}

static int
vfs_gc(lua_State *L) {
  return vfs_close(L);
}

static int
vfs_read(lua_State *L) {
  archive_t *a;
  entry_t *entry;
  const char *name;
  int rv;
  char *buf = NULL;
  size_t len;
  virgo_t *v = virgo__lua_context(L);

  a = archive_read_new();
  archive_read_support_format_zip(a);

  name = luaL_checkstring(L, 2);

  if (name[0] == '/') {
    name++;
  }

  rv = archive_read_open_memory(a, bundle, sizeof(bundle));
  if (rv != ARCHIVE_OK) {
    lua_pushnil(L);
    lua_pushfstring(L, "could not open file '%s'", name);
    return 2;
  }

  for (;;) {
    rv = archive_read_next_header(a, &entry);
    if (rv == ARCHIVE_EOF) {
      lua_pushnil(L);
      lua_pushfstring(L, "could not open file '%s'", name);
      archive_read_close(a);
      archive_read_free(a);
      return 2;
    }
    if (rv != ARCHIVE_OK) {
      lua_pushnil(L);
      lua_pushfstring(L, "error: %s", archive_error_string(a));
      archive_read_close(a);
      archive_read_free(a);
      return 2;
    }

    if (strcmp(name, archive_entry_pathname(entry)) == 0) {
      break;
    }
  }

  len = archive_entry_size(entry);
  buf = malloc(len);
  ssize_t size = archive_read_data(a, buf, len);
  lua_pushlstring(L, buf, size);

  free(buf);
  archive_read_close(a);
  archive_read_free(a);
  return 1;
}

static int
vfs_exists(lua_State *L) {
  int rv;
  archive_t *a;
  const char *name;
  entry_t *entry;
  virgo_t *v = virgo__lua_context(L);
  int found = 0;

  name = luaL_checkstring(L, 2);
  a = archive_read_new();
  archive_read_support_format_zip(a);

  if (name[0] == '/')
    name++;

  rv = archive_read_open_memory(a, bundle, sizeof(bundle));
  if (rv != ARCHIVE_OK) {
    lua_pushnil(L);
    return 1;
  }

  for (;;) {
    rv = archive_read_next_header(a, &entry);
    if (rv == ARCHIVE_EOF) {
      break;
    }
    if (rv != ARCHIVE_OK) {
      break;
    }
    if (strcmp(name, archive_entry_pathname(entry)) == 0) {
      found = 1;
      break;
    }
  }

  if (found) {
    lua_pushboolean(L, 1);
  } else {
    lua_pushnil(L);
  }

  archive_read_close(a);
  archive_read_free(a);
  return 1;
}

static const luaL_reg fvfslib[] = {
  {"exists", vfs_exists},
  {"read", vfs_read},
  {"__gc", vfs_gc},
  {NULL, NULL}
};

static const luaL_reg vfslib[] = {
  {"open", vfs_open},
  {NULL, NULL}
};

int
virgo__lua_vfs_init(lua_State *L)
{
  luaL_newmetatable(L, ZIPFILEHANDLE);
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);  /* push metatable */
  lua_rawset(L, -3);  /* metatable.__index = metatable */
  luaL_openlib(L, NULL, fvfslib, 0);
  lua_pushvalue(L, -1);

  luaL_openlib(L, "VFS", vfslib, 1);
  return 1;
}
