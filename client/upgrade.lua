--[[
Copyright 2014 Rackspace

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
local consts = require('../util/constants')
local loggingUtil = require ('../util/logging')
local misc = require('../util/misc')
local request = require('../protocol/request')
local v = require('../util/semver')
local utilUpgrade = require('../util/upgrade')

local Error = require('core').Error
local JSON = require('json')
local async = require('async')
local fmt = require('string').format
local fs = require('fs')
local logging = require('logging')
local los = require('los')
local path = require('path')
local spawn = require('childprocess').spawn
local string = require('string')
local table = require('table')
local timer = require('timer')
local windowsConvertCmd = require('../utils').windowsConvertCmd
local _, sigar = pcall(require, 'sigar')
local uv = require('uv')

local trim = misc.trim

local UPGRADE_EQUAL = 0
local UPGRADE_PERFORM = 1
local UPGRADE_DOWNGRADE = 2

-- Call executable with -v and save the version
local function getVersionFromProcess(exe_path, callback)
  local cmd, arg = windowsConvertCmd(exe_path, {"-v", "-o"})
  local child = spawn(cmd, arg)
  local data = {}
  callback = misc.fireOnce(callback)
  child.stdout:on('data', function(_data)
    table.insert(data, _data)
  end)
  child.stdout:on('end', function()
    callback(nil, trim(table.concat(data)))
  end)
  child:on('exit', function(code)
    if code ~= 0 then
      callback(Error:new(fmt("could not get version from %s, exit %d", exe_path, code)))
    end
  end)
end

-- Read the MSI to get the version string
local function getVersionFromMSI(msi_path, callback)
  local version = nil
  local _, err = pcall(function()
    local ffi = require('ffi')
    ffi.cdef[[
      typedef unsigned long MSIHANDLE;
      typedef unsigned int UINT;
      typedef char CHAR;
      typedef CHAR *NPSTR, *LPSTR, *PSTR;
      typedef const CHAR *LPCSTR, *PCSTR;

      enum {
        ERROR_SUCCESS = 0L,
        ERROR_MORE_DATA = 234L
      };

      UINT MsiOpenPackageA(const char* szPackagePath, MSIHANDLE *hProduct);
      UINT MsiGetProductPropertyA(MSIHANDLE hProduct,  LPCTSTR szProperty, LPTSTR lpValueBuf, DWORD *pcchValueBuf);
      UINT MsiCloseHandle(MSIHANDLE hAny);
    ]]

    local msilib = ffi.load("Msi")

    local phProduct = ffi.new('MSIHANDLE[1]')
    local ret = msilib.MsiOpenPackageA(msi_path, phProduct);
    if ret ~= ffi.C.ERROR_SUCCESS then
      error(Error:new(fmt("could not get version from %s", msi_path)))
    end

    local pszVersion = ffi.new('CHAR[1]')
    local pdwSizeVersion = ffi.new('DWORD[1]')
    local prop = 'ProductVersion'

    ret = msilib.MsiGetProductPropertyA(phProduct[0], ffi.cast('char *', prop), pszVersion, pdwSizeVersion)
    if not (ret == ffi.C.ERROR_MORE_DATA or (ret == ffi.C.ERROR_SUCCESS and dwSizeVersion[0] > 0)) then
      msilib.MsiCloseHandle(phProduct[0])
      error(Error:new("msi get product property size failed"))
    end

    pdwSizeVersion[0] = pdwSizeVersion[0] + 1 --add one for the null term
    pszVersion = ffi.new('CHAR[?]', pdwSizeVersion[0])

    ret = msilib.MsiGetProductPropertyA(phProduct[0], ffi.cast('char *', prop), pszVersion, pdwSizeVersion);
    msilib.MsiCloseHandle(phProduct[0])

    if ret ~= ffi.C.ERROR_SUCCESS then
      error(Error:new("msi get product property failed"))
    end

    version = ffi.string(pszVersion)
  end)
  callback(err, version)
end

local function installMSI(msi_path)
  local log = loggingUtil.makeLogger('upgrade-msi')
  local params = {"/passive", "/quiet", "/i", msi_path}
  log(logging.DEBUG, fmt("trying to run: msiexec %s", JSON.stringify(params)))
  local child = spawn("msiexec", params, { detached = true })
  child:on('exit', function(code)
    log(logging.DEBUG, fmt("msiexec %s ; EXIT CODE %d", JSON.stringify(params), code))
  end)
  child:on('error', function(err)
    log(logging.ERROR, fmt("msiexec %s ; ERR %s", JSON.stringify(params), tostring(err)))
  end)
end

local function versionCheck(other_version, my_version)
  if other_version == my_version then
    return UPGRADE_EQUAL
  end
  if v(other_version) > v(my_version) then
    return UPGRADE_PERFORM
  end
  return UPGRADE_DOWNGRADE
end

local function getAPaths(options)
  local paths = {}
  if options.a and options.a.exe then
    paths.exe = options.a.exe
  else
    paths.exe = virgo_paths.VIRGO_PATH_CURRENT_EXECUTABLE_PATH
  end
  return paths
end

local function getBPaths(options)
  local paths = {}
  if options.b and options.b.exe then
    paths.exe = options.b.exe
  else
    local other_exe_path = virgo_paths.VIRGO_PATH_EXE_DIR
    paths.exe = path.join(other_exe_path, virgo.pkg_name)
  end
  return paths
end

local function getPaths(options)
  local paths = {}
  local current_exe

  paths.a = getAPaths(options)
  paths.b = getBPaths(options)

  if options.current_exe then
    current_exe = options.current_exe
  else
    current_exe = virgo_paths.VIRGO_PATH_CURRENT_EXECUTABLE_PATH
  end

  if paths.a.exe == current_exe then
    paths.current_exe = 'a'
    paths.other_exe = 'b'
  elseif paths.b.exe == current_exe then
    paths.current_exe = 'b'
    paths.other_exe = 'a'
  else
    paths.current_exe = 'c'
    paths.other_exe = 'c'
  end

  return paths
end


--[[
-- Try to upgrade the current binary
--
-- options: table (optional)
--  paths = override paths
--  skip = skip upgrade
--  my_version = override version
--  a.exe = a.exe
--  b.exe = b.exe
-- callback: function
--  err, upgrade_status
--]]
local function attempt(options, callback)
  if type(options) == 'function' then
    callback = options
    options = {}
  end

  local log = loggingUtil.makeLogger('upgrade')
  local my_version
  local other_version = nil
  local paths
  local upgrade_status
  local potential
  local getVersion

  if options.skip then
    log(logging.DEBUG, 'skipping upgrade')
    return callback()
  end

  if options.my_version then
    my_version = options.my_version
  else
    my_version = virgo.bundle_version
  end
  
  if options.paths then
    paths = options.paths
  else
    paths = getPaths(options)
  end

  potential = paths[paths.other_exe].exe

  if los.type() == 'win32' then
    getVersion = getVersionFromMSI
  else
    getVersion = getVersionFromProcess
  end

  async.series({
    function(callback)
      local _ , err = fs.statSync(potential)
      if err then return callback(Error:new('no upgrade executable exists')) end
      log(logging.DEBUG, fmt('potential upgrade: %s, exists', potential))
      timer.setImmediate(callback)
    end,
    function(callback)
      log(logging.DEBUG, fmt('check version of potential upgrade: %s', potential))
      getVersion(potential, function(err, version)
        if not err then other_version = version
        end
        callback(err)
      end)
    end,
    function(callback)
      log(logging.DEBUG, fmt('comparing versions (%s, %s)', my_version, other_version))
      upgrade_status = versionCheck(my_version, other_version)
      timer.setImmediate(callback)
    end,
    function(callback)
      if upgrade_status == UPGRADE_EQUAL then
        log(logging.DEBUG, "no upgrade... continuing")
      elseif upgrade_status == UPGRADE_PERFORM then
        log(logging.DEBUG, fmt("upgrading (%s, %s)", my_version, other_version))
        if not options.pretend then
          if los.type() == 'win32' then
            installMSI(potential)
          end
        end
      end
      timer.setImmediate(callback)
    end
  }, function(err)
    callback(err, upgrade_status)
  end)
end

local function downloadUpgradeUnix(codeCert, streams, version, callback)
  local client = streams:getClient()
  local channel = streams:getChannel()
  local unverified_binary_dir = consts:get('DEFAULT_UNVERIFIED_EXE_PATH')
  local verified_binary_dir = consts:get('DEFAULT_VERIFIED_EXE_PATH')

  if not client then return callback(Error:new('No client')) end
  callback = callback or function() end

  local function download_iter(item, callback)
    local options = misc.merge({
      method = 'GET',
      host = client._host,
      port = client._port
    }, client._tls_options)

    local filename = path.join(unverified_binary_dir, item.payload)
    local filename_sig = path.join(unverified_binary_dir, item.signature)

    local function onVerify(err)
      if err then return callback(err) end
      client:log(logging.INFO, fmt('Signature verified %s (ok)', item.payload))
      local exepath = uv.exepath()
      local oldpath = exepath .. '.old'
      async.parallel({
        function(callback)
          uv.fs_rename(exepath, oldpath, callback)
        end,
        function(callback)
          uv.fs_rename(filename, exepath, callback)
        end,
        function(callback)
          uv.fs_unlink(oldpath, callback)
        end
      }, function(err)
        if err then return callback(err) end
        fs.chmod(exepath, string.format('%o', item.permissions), callback)
      end)
    end

    async.parallel({
      payload = function(callback)
        local opts = misc.merge({
          path = fmt('/upgrades/%s/%s', channel, item.payload),
          download = path.join(unverified_binary_dir, item.payload)
        }, options)
        request.makeRequest(opts, callback)
      end,
      signature = function(callback)
        local opts = misc.merge({
          path = fmt('/upgrades/%s/%s', channel, item.signature),
          download = path.join(unverified_binary_dir, item.signature)
        }, options)
        request.makeRequest(opts, callback)
      end
    }, function(err)
      if err then return callback(err) end
      utilUpgrade.verify(filename, filename_sig, codeCert, onVerify)
    end)
  end

  local function mkdirp(path, callback)
    fs.mkdirp(path, "0755", function(err)
      if not err then return callback() end
      if err.code == "EEXIST" then return callback() end
      callback(err)
    end)
  end

  local s = sigar:new():sysinfo()

  if s.name == 'MacOSX' then
    s.vendor = 'darwin'
    s.vendor_version = s.version
  end

  if s.name == "Linux" then
    local semver_match = "^(%d+)%.?(%d*)%.?(%d*)(.-)$"
    local major = s.vendor_version:match(semver_match)
    if s.vendor == "Debian" then
      local mapping = {
        [6] = "squeeze",
        [7] = "wheezy",
        [8] = "jessie",
      }
      s.vendor_version = mapping[tonumber(major)] or 'unknown'
    elseif s.vendor == "CentOS" or s.vendor == "Fedora" then
      major = s.vendor_version:match(semver_match)
      if not major then
        return callback(Error:new('could not extract major version of operating system.'))
      end
      s.vendor_version = major
    elseif s.vendor == "Red Hat" then
      semver_match = "^Enterprise Linux (%d*)$"
      major = s.vendor_version:match(semver_match)
      if not major then
        return callback(Error:new('could not extract major version of operating system.'))
      end
      s.vendor_version = major
      s.vendor = "redhat"
    end
  end

  local binary_name = fmt('%s-%s-%s-%s-%s', s.vendor, s.vendor_version, s.arch, virgo.pkg_name, version):lower()
  local binary_name_sig = fmt('%s.sig', binary_name)

  async.waterfall({
    function(callback)
      async.forEach({unverified_binary_dir, verified_binary_dir}, mkdirp, callback)
    end,
    function(callback)
      local files = {
        payload = binary_name,
        signature = binary_name_sig,
        path = virgo_paths.get(virgo_paths.VIRGO_PATH_EXE_DIR),
        permissions = tonumber('755', 8)
      }
      download_iter(files, callback)
    end
  }, function(err)
    if err then
      client:log(logging.ERROR, fmt('Error downloading update: %s', tostring(err)))
      return callback(err)
    end
    client:log(logging.INFO, 'An update to the agent has been downloaded')
    callback()
  end)
end

local function downloadUpgradeWin(codeCert, streams, version, callback)
  local client = streams:getClient()
  local channel = streams:getChannel()
  local unverified_binary_dir = consts:get('DEFAULT_UNVERIFIED_EXE_PATH')

  if not client then return end
  callback = callback or function() end

  local function download_iter(item, callback)
    local options, opts
    options = misc.merge({
      method = 'GET',
      host = client._host,
      port = client._port
    }, client._tls_options)
    opts = misc.merge({
      path = fmt('/upgrades/%s/%s', channel, item.payload),
      download = path.join(unverified_binary_dir, item.payload)
    }, options)
    request.makeRequest(opts, callback)
  end

  local function mkdirp(path, callback)
    fs.mkdirp(path, "0755", function(err)
      if not err then return callback() end
      if err.code == "EEXIST" then return callback() end
      callback(err)
    end)
  end

  local s = sigar:new():sysinfo()
  local payload = fmt('%s-%s.msi', virgo.pkg_name, s.arch):lower()

  async.waterfall({
    function(callback)
      mkdirp(unverified_binary_dir, callback)
    end,
    function(callback)
      download_iter({ payload = payload }, callback)
    end
  }, function(err)
    if err then
      client:log(logging.ERROR, fmt('Error downloading update: %s', tostring(err)))
      return callback(err)
    end
    client:log(logging.INFO, 'An update to the agent has been downloaded')
    exports.attempt({['b'] = { ['exe'] = path.join(unverified_binary_dir, payload) }}, callback)
  end)
end

local function checkForUpgrade(codeCert, streams, callback)
  local client = streams:getClient()
  if not client then return callback(Error:new('No client')) end

  local channel = streams:getChannel()
  local bundleVersion = virgo.bundle_version
  local uri_path

  local options = misc.merge({
    method = 'GET',
    host = client._host,
    port = client._port
  }, client._tls_options)

  uri_path = fmt('/upgrades/%s/VERSION', channel)
  options = misc.merge({ path = uri_path, }, options)
  request.makeRequest(options, function(err, result, version)
    if err then return callback(err) end
    version = misc.trim(version)
    client:log(logging.DEBUG, fmt('(upgrade) -> Current Version: %s', bundleVersion))
    client:log(logging.DEBUG, fmt('(upgrade) -> Upstream Version: %s', version))
    if version == '0.0.0-0' then
      callback(Error:new('Disabled'))
    elseif versionCheck(bundleVersion, version) == UPGRADE_PERFORM then
      exports.downloadUpgrade(codeCert, streams, version, callback)
    else
      callback(Error:new('No upgrade'))
    end
  end)
end

exports.UPGRADE_EQUAL = UPGRADE_EQUAL
exports.UPGRADE_PERFORM = UPGRADE_PERFORM
exports.UPGRADE_DOWNGRADE = UPGRADE_DOWNGRADE

exports.attempt = attempt
exports.getVersionFromMSI = getVersionFromMSI
exports.downloadUpgrade = los.type() == "win32" and downloadUpgradeWin or downloadUpgradeUnix
exports.checkForUpgrade = checkForUpgrade
exports.getPaths = getPaths
