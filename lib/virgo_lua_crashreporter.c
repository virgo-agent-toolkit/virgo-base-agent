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
#include "virgo__util.h"

static int
luahook_crash_reporter_init(lua_State *L) {
  virgo_t *v = virgo__lua_context(L);
  const char *path = luaL_checkstring(L, -1);
  virgo__crash_reporter_init(v, path);
  return 0;
}

static const luaL_reg crash_reporter[] = {
  {"init", luahook_crash_reporter_init},
  {NULL, NULL}
};

int
virgo__lua_crashreporter_init(lua_State *L) {
  luaL_openlib(L, "virgo_crash", crash_reporter, 1);
  return 1;
}

