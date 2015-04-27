--[[
Copyright 2015 Rackspace

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local logging = require('logging')
local Error = require('core').Error
local los = require('los')
local path = require('path')
local table = require('table')
local ffi = require('ffi')
local winpaths = require('./util/win_paths')

local delta = 0
local delay

local function gmtNow()
  local t_secs = os.time() -- get seconds if t was in local time.
  local t_UTC = os.date("!*t", t_secs) -- find out what UTC t was converted to.
  return os.time(t_UTC) -- find out the converted time in seconds.
end

local function trim(s)
  return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end

local gmtRaw

if los.type() == 'win32' then
  ffi.cdef[[
    typedef unsigned long DWORD, *PDWORD, *LPDWORD;
    typedef struct _FILETIME {
      DWORD dwLowDateTime;
      DWORD dwHighDateTime;

    } FILETIME, *PFILETIME;

    void GetSystemTimeAsFileTime(FILETIME*);
  ]]
  function gmtRaw()
    local ft = ffi.new("FILETIME[1]")
    ffi.C.GetSystemTimeAsFileTime(ft)
    local t = tonumber(ft[0].dwLowDateTime)/1e7 + tonumber(ft[0].dwHighDateTime) * (4294967296.0/1.0e7)
    return math.floor(t - 11644473600.0) * 1000
  end
else
  ffi.cdef[[
    typedef long time_t;
    typedef struct {
      time_t tv_sec;
      time_t tv_usec;
    } timeval;
    int gettimeofday(timeval* t, void* tzp);
  ]]
  function gmtRaw()
    local t = ffi.new("timeval")
    ffi.C.gettimeofday(t, nil)
    return tonumber(t.tv_sec * 1000) + tonumber(t.tv_usec / 1000)
  end
end

local function setDelta(_delta)
  delta = _delta
end

local function getDelta()
  return delta
end

--[[

This algorithm follows the NTP algorithm found here:

http://www.eecis.udel.edu/~mills/ntp/html/warp.html

T1 = agent departure timestamp
T2 = server receieved timestamp
T3 = server transmit timestamp
T4 = agent destination timestamp

]]--
local function timesync(T1, T2, T3, T4)
  if not T1 or not T2 or not T3 or not T4 then
    return Error:new('T1, T2, T3, or T4 was null. Failed to sync time.')
  end

  logging.debugf('time_sync data: T1 = %.0f T2 = %.0f T3 = %.0f T4 = %.0f', T1, T2, T3, T4)

  delta = ((T2 - T1) + (T3 - T4)) / 2
  delay = ((T4 - T1) + (T3 - T2))

  logging.debugf('Setting time delta to %.0fms based on server time %.0fms', delta, T2)

  return
end

local function tableGetBoolean(tt, key, default)
  local value = tt[key] or default
  if type(value) == 'string' then
    if value:lower() == 'false' then
      return false
    end
  end
  if type(value) == 'number' then
    if value == 0 then
      return false
    end
  end
  return value
end

local function getCrashPath()
  if process.env.VIRGO_PATH_CRASH then
    return process.env.VIRGO_PATH_CRASH
  end
  return virgo_paths.get(virgo_paths.VIRGO_PATH_PERSISTENT_DIR)
end


local function windowsConvertCmd(cmd, pparams)
  local misc = require('./util/misc')
  local ext = path.extname(cmd)
  local params = misc.deepCopyTable(pparams)

  if los.type() == 'win32' and ext ~= "" then
    -- If we are on windows, we want to suport custom plugins like "foo.py",
    -- but this means we need to map the .py file ending to the Python Executable,
    -- and mutate our run path to be like: C:/Python27/python.exe custom_plugins_path/foo.py
    local assocExe = winpaths.GetAssociatedExe(ext, '0')
    if assocExe == nil then
      assocExe = winpaths.GetAssociatedExe(ext, 'open')
    end
    if assocExe then
      -- If Powershell is the EXE then add a parameter for the exec policy
      local justExe = assocExe:match("^\"([^\"]*)")
      -- On windows if the associated exe is %1 it references itself
      if justExe and justExe ~= "%1" then
        table.insert(params, 1, cmd)
        cmd = justExe
        -- Force Bypass for this child powershell
        if path.basename(justExe) == "powershell.exe" then
          table.insert(params, 1, '-File')
          table.insert(params, 1, 'Bypass')
          table.insert(params, 1, '-ExecutionPolicy')
        end
      end
    else
      logging.warningf('error getting associated executable for "%s"', ext)
    end
  end
  return cmd, params
end

exports.delay = delay
exports.setDelta = setDelta
exports.getDelta = getDelta
exports.gmtNow = gmtNow
exports.gmtRaw = gmtRaw
exports.getCrashPath  = getCrashPath
exports.timesync = timesync
exports.crash = virgo.force_crash
exports.trim = trim
exports.tableGetBoolean = tableGetBoolean
exports.windowsConvertCmd = windowsConvertCmd
