--[[
Copyright 2013 Rackspace

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

local Error = require('core').Error
local Object = require('core').Object
local async = require('async')
local childprocess = require('childprocess')
local os = require('os')
local fs = require('fs')
local utils = require('virgo_utils')
local fmt = require('string').format

local MachineIdentity = Object:extend()

local function xenAdapter(callback)
  local exePath
  local exeArgs

  if os.type() == 'win32' then
    exePath = 'c:\\Program Files\\Citrix\\XenTools\\xenstore_client.exe'
    if fs.existsSync(exePath) then
      exeArgs = { 'read', 'name' }
    else
      exePath = 'powershell'
      exeArgs = { '-Command', '{$sid = ((Get-WmiObject -Class CitrixXenStoreBase -Namespace root\\wmi).AddSession("Temp").SessionId) ; $s = (Get-WmiObject -Namespace root\\wmi -Query "select * from CitrixXenStoreSession where SessionId=$sid") ; $v = $s.GetValue("name").value ; $s.EndSession() ; $v}' }
    end
  else
    exePath = 'xenstore-read'
    exeArgs = { 'name' }
  end

  local buffer = ''
  local child = childprocess.spawn(exePath, exeArgs)

  child.stdout:on('data', function(chunk)
    buffer = buffer .. chunk
  end)

  child:on('exit', function(code)
    if code == 0 and buffer:len() > 10 then
      callback(nil, utils.trim(buffer:sub(10)))
    else
      callback(Error:new(fmt('Could not retrieve xenstore name, ret: %d, buffer: %s', code, buffer)))
    end
  end)
end

local function cloudInitAdapter(callback)
  -- TODO: Win32 cloud-init paths
  local instanceIdPath = '/var/lib/cloud/data/instance-id'
  fs.readFile(instanceIdPath, function(err, data)
    if err ~= nil then
      callback(err)
      return
    end

    data = utils.trim(data)

    -- the fallback datasource is iid-datasource-none when it does not exist
    -- http://cloudinit.readthedocs.org/en/latest/topics/datasources.html#fallback-none
    if data == 'iid-datasource-none' or data == 'nocloud' then
      callback(Error:new('Invalid instance-id'))
    else
      callback(nil, data)
    end
  end)
end

function MachineIdentity:initialize(config)
  self._config = config
end

function MachineIdentity:get(callback)
  local rv

  rv = utils.tableGetBoolean(self._config, 'autodetect_machine_id', true)
  if rv == false then
    return callback()
  end

  function handle_id(instanceId)
    callback(nil, {id = instanceId})
  end

  cloudInitAdapter(function(err, instanceId)
    if err ~= nil then
      xenAdapter(function(err, instanceId)
        if err ~= nil then
          callback(err)
          return
        end

          handle_id(instanceId)
          return
      end)
      return
    end

    handle_id(instanceId)
    return
  end)

end

local exports = {}
exports.MachineIdentity = MachineIdentity
return exports
