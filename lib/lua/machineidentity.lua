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
local utils = require('virgo_utils')
local fmt = require('string').format

local MachineIdentity = Object:extend()

local function xenAdapter(callback)
  local exePath
  local exeArgs

  if os.type() == 'win32' then
    exePath = 'c:\\Program Files\\Citrix\\XenTools\\xenstore_client.exe'
    exeArgs = { 'read', 'name' }
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

function MachineIdentity:initialize(config)
  self._config = config
end

function MachineIdentity:get(callback)
  local results = {}
  local rv

  rv = utils.tableGetBoolean(self._config, 'autodetect_machine_id', true)
  if rv == false then
    return callback()
  end

  async.series({
    function(callback)
      xenAdapter(function(err, _id)
        if err then
          return callback(err)
        end
        results['id'] = _id
        callback()
      end)
    end
  }, function(err)
    callback(err, results)
  end)
end

local exports = {}
exports.MachineIdentity = MachineIdentity
return exports
