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

local Error = require('core').Error
local Object = require('core').Object
local childprocess = require('childprocess')
local los = require('los')
local fs = require('fs')
local utils = require('./utils')
local fireOnce = require('./util/misc').fireOnce
local fmt = require('string').format
local table = require('table')

local MachineIdentity = Object:extend()

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

  local function onEnd()
    done()
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
  -- TODO: Win32 cloud-init paths

  local instanceIdPath = '/var/lib/cloud/data/instance-id'
  local data, err = fs.readFileSync(instanceIdPath)
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

function MachineIdentity:initialize(config)
  self._config = config
end

function MachineIdentity:get(callback)
  local rv, handle_id, onCloudInit, onXenAdapter

  rv = utils.tableGetBoolean(self._config, 'autodetect_machine_id', true)
  if rv == false then
    return callback()
  end

  function handle_id(instanceId)
    callback(nil, {id = instanceId})
  end

  function onXenAdapter(err, instanceId)
    if err then
      return callback(err)
    end
    handle_id(instanceId)
  end

  function onCloudInit(err, instanceId)
    if err then
      return xenAdapter(onXenAdapter)
    end
    handle_id(instanceId)
  end

  cloudInitAdapter(onCloudInit)
end

exports.MachineIdentity = MachineIdentity
