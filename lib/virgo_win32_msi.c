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
#include "virgo__util.h"
#include "virgo__lua.h"
#include "virgo__types.h"
#include "virgo_error.h"
#include "virgo_paths.h"

#ifdef _WIN32

#include <windows.h>
#include <msi.h>

int virgo__lua_fetch_msi_version(lua_State *L)
{
  const char *msi = luaL_checkstring(L, 1);
  UINT ret;
  MSIHANDLE hProduct;
  LPSTR pszVersion = NULL;
  DWORD dwSizeVersion = 0;
  LPCSTR prop = "ProductVersion";

  if (!msi) {
    luaL_error(L, "argument 2 must be a string");
  }

  ret = MsiOpenPackage(msi, &hProduct);
  if (ret != ERROR_SUCCESS)
  {
    return luaL_error(L, "msi open package failed");
  }

  ret = MsiGetProductProperty(hProduct, prop, pszVersion, &dwSizeVersion);
  if (!(ret == ERROR_MORE_DATA || (ret == ERROR_SUCCESS && dwSizeVersion > 0)))
  {
    MsiCloseHandle(hProduct);
    return luaL_error(L, "msi get product property size failed");
  }

  ++dwSizeVersion; /* add one for the null term */
  pszVersion = (LPSTR)malloc(dwSizeVersion);

  ret = MsiGetProductProperty(hProduct, prop, pszVersion, &dwSizeVersion);

  MsiCloseHandle(hProduct);

  if (ret != ERROR_SUCCESS)
  {
    free(pszVersion);
    return luaL_error(L, "msi get product property failed");
  }
  
  lua_pushlstring(L, pszVersion, dwSizeVersion);
  free(pszVersion);
  return 1;
}

#endif
