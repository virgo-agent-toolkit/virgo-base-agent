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

local Emitter = require('core').Emitter
local JSON = require('json')
local ResponseTimeoutError = require('../errors').ResponseTimeoutError
local Writable = require('stream').Writable
local errors = require('../protocol/errors')
local fmt = require('string').format
local timer = require('timer')

local logging = require('logging')
local msg = require ('../protocol/messages')

-- Response timeouts in ms
local HANDSHAKE_TIMEOUT = 30000
local HEARTBEAT_TIMEOUT = 10000

local STATES = {}
STATES.INITIAL = 1
STATES.HANDSHAKE = 2
STATES.RUNNING = 3

local AgentProtocolConnection = Emitter:extend()

--[[ Request Functions ]]--
local requests = {}

requests['handshake.hello'] = function(self, agentId, token, features, callback)
  local m = msg.HandshakeHello:new(token, agentId, features)
  self:_send(m, callback, self.HANDSHAKE_TIMEOUT)
end

requests['heartbeat.post'] = function(self, timestamp, callback)
  local m = msg.Heartbeat:new(timestamp)
  self:_send(m, callback, HEARTBEAT_TIMEOUT)
end

--[[ Reponse Functions ]]--
local responses = {}

responses['upgrade.request'] = function(self, replyTo, callback)
  self:emit('upgrade.request')

  local m = msg.Response:new(replyTo)
  self:_send(m, callback)
end

function AgentProtocolConnection:initialize(log, myid, token, guid, conn, features)

  assert(conn ~= nil)
  assert(myid ~= nil)

  self._features = features
  self._log = log
  self._myid = myid
  self._token = token
  self._conn = conn
  local sink = Writable:new({objectMode = true})
  sink._write = function(sink, data, callback)
    self:_processMessage(data)
    process.nextTick(callback)
  end
  self._conn:pipe(sink)
  
  self._buf = ''
  self._msgid = 0
  self._endpoints = { }
  self._target = 'endpoint'
  self._timeoutIds = {}
  self._completions = {}
  self._requests = requests
  self._responses = responses
  self._guid = guid
  self.HANDSHAKE_TIMEOUT = HANDSHAKE_TIMEOUT
  self:setState(STATES.INITIAL)
end

function AgentProtocolConnection:request(name, ...)
  return self._requests[name](self, unpack({...}))
end

function AgentProtocolConnection:respond(name, ...)
  local args = {...}
  local callback = args[#args]
  local method = self._responses[name]

  if type(callback) ~= 'function' then
    error('last argument to respond() must be a callback')
  end

  if method == nil then
    local err = errors.InvalidMethodError:new(name)
    callback(err)
    return
  else
    return method(self, unpack(args))
  end
end

function AgentProtocolConnection:_popLine()
  local line = false
  local index = self._buf:find('\n')

  if index then
    line = self._buf:sub(0, index - 1)
    self._buf = self._buf:sub(index + 1)
  end

  return line
end

function AgentProtocolConnection:_processMessage(msg)
  -- request
  if msg.method ~= nil then
    self:emit('message', msg)
  else
    -- response
    local key = self:_completionKey(msg.source, msg.id)
    local callback = self._completions[key]
    if callback then
      self._completions[key] = nil
      callback(nil, msg)
    else
      self._log(logging.ERROR, fmt('Ignoring unexpected response object %s', key))
    end
  end
end

--[[
Generate the completion key for a given message id and source (optional)

arg[1] - source or msgid
arg[2] - msgid if source provided
]]--
function AgentProtocolConnection:_completionKey(...)
  local args = {...}
  local source, msgid

  if #args == 1 then
    source = self._guid
    msgid = args[1]
  elseif #args == 2 then
    source = args[1]
    msgid = args[2]
  else
    return nil
  end

  return source .. ':' .. msgid
end

function AgentProtocolConnection:_send(msg, callback, timeout)
  msg = msg:serialize(self._msgid)

  msg.target = 'endpoint'
  msg.source = self._guid
  -- local msg_str = JSON.stringify(msg)
  -- local data = msg_str .. '\n'
  local key = self:_completionKey(msg.target, msg.id)

  if timeout then
    self:_setCommandTimeoutHandler(key, timeout, callback)
  end

  -- if the msg does not have a method then it is
  -- a response so we don't expect a reply. Don't
  -- create a completion in this case.
  if (msg.method == nil) then
    if callback then callback() end
  else
    self._completions[key] = function(err, resp)
      if self._timeoutIds[key] ~= nil then
        timer.clearTimer(self._timeoutIds[key])
      end

      if not err and resp then
        local resp_err = resp['error']

        -- response version must match request version
        if resp.v ~= msg.v then
          err = errors.VersionError:new(msg, resp)
        -- emit error if error field is set
        elseif resp_err then
          err = errors.ProtocolError:new(resp_err)
        end

        if err then
          -- All 400 errors will be logged, but not re-emitted. All other errors
          -- will cause the connection to be dropped to the endpoint. We may
          -- need to revise this behavior in the future.
          if err.code == 400 then
            self._log(logging.ERROR, fmt('Non-fatal error: %s', err.message))
          else
            self:emit('error', err)
          end
        end
      end

      if callback then
        callback(err, resp)
      end
    end
  end

  self._log(logging.DEBUG, fmt('SENDING: (%s) => %s', key, JSON.stringify(msg)))
  self._conn:write(msg)
  self._msgid = self._msgid + 1
end

--[[
Set a timeout handler for a function.

key - Command key.
timeout - Timeout in ms.
callback - Callback which is called with (err) if timeout has been reached.
]]--
function AgentProtocolConnection:_setCommandTimeoutHandler(key, timeout, callback)
  local timeoutId

  timeoutId = timer.setTimeout(timeout, function()
    local msg = fmt("Command timeout, haven't received response in %d ms", timeout)
    local err = ResponseTimeoutError:new(msg)
    callback(err)
  end)
  self._timeoutIds[key] = timeoutId
end

--[[ Public Functions ]] --

function AgentProtocolConnection:setState(state)
  self._state = state
end

function AgentProtocolConnection:startHandshake(callback)
  local function onHello(err, msg)
    if err then
      self._log(logging.ERR, fmt('handshake failed (message=%s)', err.message))
      return callback(err, msg)
    end
    self:setState(STATES.RUNNING)
    self._log(logging.DEBUG, fmt('handshake successful (heartbeat_interval=%dms)', msg.result.heartbeat_interval))
    callback(nil, msg)
  end
  self:setState(STATES.HANDSHAKE)
  self:request('handshake.hello', self._myid, self._token, self._features, onHello)
end

return AgentProtocolConnection
