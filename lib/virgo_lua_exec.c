/*
 *  Copyright 2014 Rackspace
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
#include <stdlib.h>

#ifndef _WIN32
#include <unistd.h>
#include <libgen.h>
#include <errno.h>
#endif

#define MAX_CMDLINE_PARAMETERS 20

extern char **environ;

#ifdef _WIN32
/* a Win32 Subsitutue for basename()*/
char *basename(char *path)
{
  static char fname[_MAX_FNAME];
  fname[0] = '\0';
  _splitpath_s(path, NULL, 0, NULL, 0, fname, _MAX_FNAME, NULL, 0);
  return fname;
}
#endif

int virgo__lua_perform_upgrade(lua_State *L) {
  char *args[MAX_CMDLINE_PARAMETERS + 1], *exe = NULL;
  int arg_length, i, rc;

  if (!lua_istable(L, -1)) {
    luaL_error(L, "argument 2 must be a table");
  }

  arg_length = lua_objlen(L, -1);
  if (arg_length >= MAX_CMDLINE_PARAMETERS) {
    luaL_error(L, "too many commandline parameters");
  }

  for (i=0; i<arg_length; i++) {
    lua_rawgeti(L, -1, i + 1);
    if (i == 0) {
      exe = strdup(lua_tostring(L, -1));
      args[0] = strdup(basename((char*)lua_tostring(L, -1)));
    } else {
      args[i] = strdup(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
  }

  args[arg_length] = NULL;

  rc = execve(exe, args, environ);

  if (rc < 0) {
    free(exe);
    for (i=0; i<arg_length; i++) {
      free(args[i]);
    }
    lua_pushstring(L, "Upgrade failed");
    return 1;
  }

  return 0;
}
