local bind = require('utils').bind
local timer = require('timer')
local Emitter = require('core').Emitter
local path = require('path')
local Object = require('core').Object
local table = require('table')
local os = require('os')
local https = require('https')
local fs = require('fs')
local instanceof = require('core').instanceof
local string = require('string')
local sigar = require('sigar')

local misc = require('/base/util/misc')
local logging = require('logging')
local consts = require('/base/util/constants')
local async = require('async')
local fmt = require('string').format
local fsutil = require('/base/util/fs')
local errors = require('/base/errors')
local request = require('/base/protocol/request')


-- Connection Messages
local ConnectionMessages = Emitter:extend()
function ConnectionMessages:initialize(connectionStream)
  self._connectionStream = connectionStream
  self:on('handshake_success', bind(ConnectionMessages.onHandshake, self))
  self:on('client_end', bind(ConnectionMessages.onClientEnd, self))
  self:on('message', bind(ConnectionMessages.onMessage, self))
  self._lastFetchTime = 0
end

function ConnectionMessages:getStream()
  return self._connectionStream
end

function ConnectionMessages:onClientEnd(client)
  client:log(logging.INFO, 'Detected client disconnect')
end

function ConnectionMessages:onHandshake(client, data)
  -- Only retrieve manifest if agent is bound to an entity
  if data.entity_id then
    self:fetchManifest(client)
  else
    client:log(logging.DEBUG, 'Not retrieving check manifest, because ' ..
                              'agent is not bound to an entity')
  end
end

function ConnectionMessages:fetchManifest(client)
  local function run()
    if client then
      client:log(logging.DEBUG, 'Retrieving check manifest...')

      client.protocol:request('check_schedule.get', function(err, resp)
        if err then
          -- TODO Abort connection?
          client:log(logging.ERROR, 'Error while retrieving manifest: ' .. err.message)
        else
          client:scheduleManifest(resp.result)
        end
      end)
    end
  end

  if self._lastFetchTime == 0 then
    if self._timer then
      timer.clearTimer(self._timer)
    end
    self._timer = process.nextTick(run)
    self._lastFetchTime = os.time()
  end
end

function ConnectionMessages:onMessage(client, msg)

  local method = msg.method

  if not method then
    client:log(logging.WARNING, fmt('no method on message!'))
    return
  end

  client:log(logging.DEBUG, fmt('received %s', method))

  local callback = function(err, msg)
    if (err) then
      client:log(logging.ERROR, fmt('error handling %s %s', method, err))
      return
    end

    if method == 'check_schedule.changed' then
      self._lastFetchTime =   0
      client:log(logging.DEBUG, 'fetching manifest')
      self:fetchManifest(client)
      return
    end

    if method == 'upgrade.request' then
      self:emit(method, msg)
      return
    end

    client:log(logging.DEBUG, fmt('No handler for method: %s', method))
  end

  client.protocol:respond(method, msg, callback)
end

local exports = {}
exports.ConnectionMessages = ConnectionMessages
return exports
