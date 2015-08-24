--[[
Copyright 2013-2015 Rackspace

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

local async = require('async')
local Error = require('core').Error
local Object = require('core').Object
local childprocess = require('childprocess')
local fireOnce = require('./util/misc').fireOnce
local fmt = require('string').format
local fs = require('fs')
local http = require('http')
local los = require('los')
local table = require('table')
local utils = require('./utils')

local MachineIdentity = Object:extend()

local function awsAdapter(callback)
  local uri = 'http://instance-data.ec2.internal/latest/meta-data/instance-id'
  local req = http.request(uri, function(res)
    local id = ''
    res:on('data', function(data)
      id = id .. data
    end)
    res:on("end", function()
      res:destroy()
      callback(nil, id)
    end)
  end)
  req:setTimeout(2000)
  req:once('timeout', callback)
  req:once('error', callback)
  req:done()
end

local function xenAdapter(callback)
  local exePath, exeArgs
  local buffer, child

  callback = fireOnce(callback)
  buffer = {}

  if los.type() == 'win32' then
    exePath = 'c:\\Program Files\\Citrix\\XenTools\\xenstore_client.exe'
    if fs.statSync(exePath) then
      exeArgs = { 'read', 'name' }
    else
      exePath = 'powershell'
      exeArgs = { '-Command', '& {$sid = ((Get-WmiObject -Class CitrixXenStoreBase -Namespace root\\wmi).AddSession("Temp").SessionId) ; $s = (Get-WmiObject -Namespace root\\wmi -Query "select * from CitrixXenStoreSession where SessionId=$sid") ; $v = $s.GetValue("name").value ; $s.EndSession() ; $v}' }
    end
  else
    exePath = 'xenstore-read'
    exeArgs = { 'name' }
  end

  local count = 2
  local _code
  local function done()
    count = count - 1
    if count == 0 then
      buffer = table.concat(buffer)
      if _code == 0 and buffer:len() > 10 then
        callback(nil, utils.trim(buffer:sub(10)))
      else
        callback(Error:new(fmt('Could not retrieve xenstore name, ret: %d, buffer: %s', _code, buffer)))
      end
    end
  end

  local function onStdout(chunk)
    table.insert(buffer, chunk)
  end

  local function onExit(code)
    _code = code
    done()
  end

  child = childprocess.spawn(exePath, exeArgs)
  child.stdout:on('data', onStdout)
  child.stdout:on('end', done)
  child:once('error', callback)
  child:once('exit', onExit)
end

local function cloudInitAdapter(callback)
  local onData, instanceIdPath

  -- Cloud Init is not supported on Windows
  if los.type() == 'win32' then return callback(Error:new('not supported')) end

  instanceIdPath = '/var/lib/cloud/data/instance-id'

  function onData(err, data)
    if err then
      return callback(err)
    end

    -- the fallback datasource is iid-datasource-none when it does not exist
    -- http://cloudinit.readthedocs.org/en/latest/topics/datasources.html#fallback-none
    data = utils.trim(data)
    if data == 'iid-datasource-none' or data == 'nocloud' then
      callback(Error:new('Invalid instance-id'))
    else
      callback(nil, data)
   end
  end

  fs.readFile(instanceIdPath, onData)
end

function MachineIdentity:initialize(config)
  self._config = config
end

function MachineIdentity:get(callback)
  local instanceId

  local rv = utils.tableGetBoolean(self._config, 'autodetect_machine_id', true)
  if not rv then return callback() end

  local adapters = {
    cloudInitAdapter,
    xenAdapter,
    awsAdapter
  }

  async.forEachSeries(adapters, function(adapter, callback)
    adapter(function(err, _instanceId)
      if err then return callback() end
      if instanceId then return callback() end
      instanceId = _instanceId
      callback()
    end)
  end, function(err)
    if err then return callback(err) end
    if not instanceId then return callback(Error:new('no instance id')) end
    callback(nil, { id = instanceId })
  end)
end

exports.MachineIdentity = MachineIdentity
