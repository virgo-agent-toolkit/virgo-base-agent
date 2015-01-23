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
local compareVersions = require('/base/util/misc').compareVersions
local consts = require('/base/util/constants')
local fsutil = require('/base/util/fs')
local loggingUtil = require ('/base/util/logging')
local misc = require('/base/util/misc')
local request = require('/base/protocol/request')
local trim = require('/base/util/misc').trim
local utilUpgrade = require('/base/util/upgrade')

local Error = require('core').Error
local fs = require('fs')
local string = require('string')
local Object = require('core').Object
local async = require('async')
local fmt = require('string').format
local logging = require('logging')
local path = require('path')
local spawn = require('childprocess').spawn
local table = require('table')
local windowsConvertCmd = require('virgo_utils').windowsConvertCmd
local os = require('os')
local JSON = require('json')

local exports = {}

local _, code_cert
if _G.TESTING_CERTS then
  code_cert = _G.TESTING_CERTS
else
  _, code_cert = pcall(require, '/code_cert.prod.lua')
end
_ = nil

local UPGRADE_EQUAL = 0
local UPGRADE_PERFORM = 1
local UPGRADE_DOWNGRADE = 2

-- Call executable with -v and save the version
local function getVersionFromProcess(exe_path, callback)
  local cmd, arg = windowsConvertCmd(exe_path, {"-v", "-o"})
  local child = spawn(cmd, arg)
  local data = ''
  callback = misc.fireOnce(callback)
  child.stdout:on('data', function(_data)
    data = data .. _data
  end)
  child.stdout:on('end', function()
    callback(nil, trim(data))
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
  local status, err = pcall(function()
    version = virgo.fetch_msi_version(msi_path)
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
    log(logging.ERROR, fmt("msiexec %s ; ERR %s", JSON.stringify(params), tostring(code)))
  end)
end

local function versionCheck(my_version, other_version, callback)
  local cmp = compareVersions(my_version, other_version)
  if cmp == 0 then
    callback(nil, UPGRADE_EQUAL)
  elseif cmp > 0 then
    callback(nil, UPGRADE_DOWNGRADE)
  elseif cmp < 0 then
    callback(nil, UPGRADE_PERFORM)
  end
end

local function getAPaths(options)
  local paths = {}
  if options.a and options.a.exe then
    paths.exe = options.a.exe
  else
    paths.exe = virgo_paths.get(virgo_paths.VIRGO_PATH_CURRENT_EXECUTABLE_PATH)
  end
  return paths;
end

local function getBPaths(options)
  local paths = {}
  if options.b and options.b.exe then
    paths.exe = options.b.exe
  else
    local other_exe_path = virgo_paths.get(virgo_paths.VIRGO_PATH_EXE_DIR)
    paths.exe = path.join(other_exe_path, virgo.default_name)
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
    current_exe = virgo_paths.get(virgo_paths.VIRGO_PATH_CURRENT_EXECUTABLE_PATH)
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

local function createArgs(exe, args)
  local newArgs = {}
  local _, i
  table.insert(newArgs, exe)
  for i, v in pairs(args) do
    if i ~= 0 then
      if v ~= '-g' then
        table.insert(newArgs, v)
      end
    end
  end
  table.insert(newArgs, "-o") -- skip upgrade on child
  return newArgs
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

  if os.type() ~= 'win32' then
    getVersion = getVersionFromProcess
  else
    getVersion = getVersionFromMSI
  end

  async.series({
    function(callback)
      fs.exists(potential, function(err, y)
        log(logging.DEBUG, fmt('potential upgrade: %s, exists: %s', potential, tostring(y)))
        callback(err)
      end)
    end,
    function(callback)
      log(logging.DEBUG, fmt('check version of potential upgrade: %s', potential))
      getVersion(potential, function(err, version)
        if not err then
          other_version = version
        end
        callback(err)
      end)
    end,
    function(callback)
      log(logging.DEBUG, fmt('comparing versions (%s, %s)', my_version, other_version))
      versionCheck(my_version, other_version, function(err, status)
        if not err then
          upgrade_status = status
        end
        callback(err)
      end)
    end,
    function(callback)
      if upgrade_status == UPGRADE_EQUAL then
        log(logging.DEBUG, "no upgrade... continuing")
      elseif upgrade_status == UPGRADE_PERFORM then
        log(logging.DEBUG, fmt("upgrading (%s, %s)", my_version, other_version))
        if not options.pretend then
          if os.type() == 'win32' then
            installMSI(potential)
          else
            virgo.perform_upgrade(createArgs(potential, process.argv))            
          end
        end
      end
      callback()
    end
  }, function(err)
    callback(err, upgrade_status)
  end)
end

function downloadUpgradeUnix(streams, version, callback)
  local client = streams:getClient()
  local channel = streams:getChannel()
  local unverified_binary_dir = consts:get('DEFAULT_UNVERIFIED_EXE_PATH')
  local verified_binary_dir = consts:get('DEFAULT_VERIFIED_EXE_PATH')

  if not client then
    return
  end

  callback = callback or function() end

  local function download_iter(item, callback)
    local options = {
      method = 'GET',
      host = client._host,
      port = client._port,
      tls = client._tls_options,
    }

    local filename = path.join(unverified_binary_dir, item.payload)
    local filename_sig = path.join(unverified_binary_dir, item.signature)
    local filename_verified = path.join(item.path, virgo.default_name)
    local filename_verified_sig = path.join(item.path, virgo.default_name .. '.sig')

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
      if err then
        return callback(err)
      end

      utilUpgrade.verify(filename, filename_sig, code_cert.codeCert, function(err)
        if err then
          return callback(err)
        end
        client:log(logging.INFO, fmt('Signature verified %s (ok)', item.payload))
        async.parallel({
          function(callback)
            client:log(logging.INFO, fmt('Moving file to %s', filename_verified))
            misc.copyFileAndRemove(filename, filename_verified, callback)
          end,
          function(callback)
            client:log(logging.INFO, fmt('Moving file to %s', filename_verified_sig))
            misc.copyFileAndRemove(filename_sig, filename_verified_sig, callback)
          end
        }, function(err)
          if err then
            return callback(err)
          end
          fs.chmod(filename_verified, string.format('%o', item.permissions), callback)
        end)
      end)
    end)
  end

  local function mkdirp(path, callback)
    fsutil.mkdirp(path, "0755", function(err)
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
    local major, minor, patch = s.vendor_version:match(semver_match)
    if s.vendor == "Debian" then
      local mapping = {
        [6] = "squeeze",
        [7] = "wheezy"
      }
      s.vendor_version = mapping[tonumber(major)] or 'unknown'
    elseif s.vendor == "CentOS" or s.vendor == "Fedora" then
      local major = s.vendor_version:match(semver_match)
      if not major then
        return callback(Error:new('could not extract major version of operating system.'))
      end
      s.vendor_version = major
    elseif s.vendor == "Red Hat" then
      local semver_match = "^Enterprise Linux (%d*)$"
      local major = s.vendor_version:match(semver_match)
      if not major then
        return callback(Error:new('could not extract major version of operating system.'))
      end
      s.vendor_version = major
      s.vendor = "redhat"
    end
  end

  local binary_name = fmt('%s-%s-%s-%s-%s', s.vendor, s.vendor_version, s.arch, virgo.default_name, version):lower()
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

function downloadUpgradeWin(streams, version, callback)
  local client = streams:getClient()
  local channel = streams:getChannel()
  local unverified_binary_dir = consts:get('DEFAULT_UNVERIFIED_EXE_PATH')

  if not client then
    return
  end

  callback = callback or function() end

  local function download_iter(item, callback)
    local options = {
      method = 'GET',
      host = client._host,
      port = client._port,
      tls = client._tls_options,
    }

    local filename = path.join(unverified_binary_dir, item.payload)

    local opts = misc.merge({
      path = fmt('/upgrades/%s/%s', channel, item.payload),
      download = path.join(unverified_binary_dir, item.payload)
    }, options)
    request.makeRequest(opts, callback)
  end

  local function mkdirp(path, callback)
    fsutil.mkdirp(path, "0755", function(err)
      if not err then return callback() end
      if err.code == "EEXIST" then return callback() end
      callback(err)
    end)
  end

  local s = sigar:new():sysinfo()
  local payload = fmt('%s-%s.msi', virgo.default_name, s.arch):lower()

  async.waterfall({
    function(callback)
      mkdirp(unverified_binary_dir, callback)
    end,
    function(callback)
      local files = {
        payload = payload
      }
      download_iter(files, callback)
    end
  }, function(err)
    if err then
      client:log(logging.ERROR, fmt('Error downloading update: %s', tostring(err)))
      return callback(err)
    end
    client:log(logging.INFO, 'An update to the agent has been downloaded')
    exports.attempt({['b'] = { ['exe'] = path.join(unverified_binary_dir, payload) }},callback)
  end)
end

function checkForUpgrade(options, streams, callback)
  options = options or {}

  local client = streams:getClient()
  if client == nil then
    return
  end

  local channel = streams:getChannel()
  local bundleVersion = virgo.bundle_version
  local uri_path, options

  options = {
    method = 'GET',
    host = client._host,
    port = client._port,
    tls = client._tls_options
  }

  uri_path = fmt('/upgrades/%s/VERSION', channel)
  options = misc.merge({ path = uri_path, }, options)
  request.makeRequest(options, function(err, result, version)
    if err then
      callback(err)
      return
    end
    version = misc.trim(version)
    client:log(logging.DEBUG, fmt('(upgrade) -> Current Version: %s', bundleVersion))
    client:log(logging.DEBUG, fmt('(upgrade) -> Upstream Version: %s', version))
    if version == '0.0.0-0' then
      callback(Error:new('Disabled'))
    elseif misc.compareVersions(version, bundleVersion) > 0 then
      exports.downloadUpgrade(streams, version, callback)
    else
      callback(Error:new('No upgrade'))
    end
  end)
end

exports.attempt = attempt
if os.type() == "win32" then
  exports.downloadUpgrade = downloadUpgradeWin
else
  exports.downloadUpgrade = downloadUpgradeUnix
end
exports.checkForUpgrade = checkForUpgrade
exports.UPGRADE_EQUAL = UPGRADE_EQUAL
exports.UPGRADE_PERFORM = UPGRADE_PERFORM
exports.UPGRADE_DOWNGRADE = UPGRADE_DOWNGRADE
exports.getPaths = getPaths
return exports
