--[[
Copyright 2012 Rackspace

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
local ProtocolConnection = require('virgo/protocol/connection')
local Timer = require('uv').Timer
--local caCerts = require('/certs').caCerts
local consts = require('virgo/util/constants')
local logging = require('rphillips/logging')
local loggingUtil = require ('virgo/util/logging')
local misc = require('virgo/util/misc')
local timer = require('timer')
local utils = require('utils')
local vutils = require('virgo/utils')

local ConnectionStateMachine = require('./connection_statemachine').ConnectionStateMachine
local Connection = require('virgo/connection')

local fmt = require('string').format

local AgentClient = Emitter:extend()

local HEARTBEAT_INTERVAL = 5 * 60 * 1000 -- ms

local DATACENTER_COUNT = {}

function AgentClient:initialize(options, connectionStream, types)
  local onRespawn

  function onRespawn()
    self:emit('respawn')
  end

  self.protocol = nil
  self._connectionStream = connectionStream
  self._types = types or {}
  self._destroyed = false
  self._datacenter = options.datacenter
  self._id = options.id
  self._token = options.token
  self._guid = options.guid
  self._target = 'endpoint'
  self._endpoint = options.endpoint
  self._ip = options.ip
  self._port = options.port
  self._host = options.host
  self._proxy = options.proxy
  self._features = options.features
  self._timeout = options.timeout or 5000
  self._machine = ConnectionStateMachine:new(connectionStream)
  self._machine:on('respawn', onRespawn)
  self:_incrementDatacenterCount()
  self._heartbeat_interval = nil
  self._sent_heartbeat_count = 0
  self._got_pong_count = 0
  self._latency = nil
  self._tls_options = options.tls or {rejectUnauthorized = true, ca = options.ca}
  self._log = loggingUtil.makeLogger(fmt('%s:%s (hostname=%s connID=%d)',
                                     self._ip,
                                     self._port,
                                     self._host,
                                     DATACENTER_COUNT[options.datacenter]))
                                    
end

function AgentClient:_incrementDatacenterCount()
  if DATACENTER_COUNT[self._datacenter] then
    DATACENTER_COUNT[self._datacenter] = DATACENTER_COUNT[self._datacenter] + 1
  else
    DATACENTER_COUNT[self._datacenter] = 1
  end
end

function AgentClient:getDatacenter()
  return self._datacenter
end

function AgentClient:setDatacenter(datacenter)
  self._datacenter = datacenter
end

function AgentClient:getMachine()
  return self._machine
end

function AgentClient:log(priority, ...)
  self._log(priority, unpack({...}))
end

function AgentClient:_socketTimeout()
  return misc.calcJitter(HEARTBEAT_INTERVAL, consts:get('SOCKET_TIMEOUT'))
end

function AgentClient:onUpgradeRequest()
  self._connectionStream:performUpgrade()
end

function AgentClient:connect()
  local options = {}
  local onSuccess, onError
  options.tls_options = self._tls_options
  options.endpoint = {}
  options.endpoint.host = self._ip
  options.endpoint.port = self._port
  options.agent = {}
  options.agent.guid = self._guid
  options.agent.id = self._id
  options.agent.token = self._token
  options.agent.name = virgo.pkg_name
  options.proxy = self._proxy
  options.features = self._features

  function onSuccess()
    self._log(logging.INFO, 'Connected')
    self:emit('connect')

    local protocolType = self._types.ProtocolConnection or ProtocolConnection
    self.protocol = protocolType:new(self._log, self._id, self._token, self._guid, self._connection, self._features)
    self.protocol:on('upgrade.request', utils.bind(AgentClient.onUpgradeRequest, self))
    self.protocol:on('error', function(err)
      -- set self.rateLimitReached so reconnect logic stops
      -- if close event is emitted before this message event
      if err['type'] == 'rateLimitReached' then
        self.rateLimitReached = true
      end

      self:emit('error', err)
    end)

    self.protocol:on('message', function(msg)
      self:emit('message', msg, self)
    end)

    -- hack: should not have to access _connection.handshake_msg
    self._heartbeat_interval = self._connection.handshake_msg.result.heartbeat_interval
    self._entity_id = self._connection.handshake_msg.result.entity_id
    self._connectionStream:setChannel(self._connection.handshake_msg.result.channel)
    self:emit('handshake_success', self._connection.handshake_msg.result)

    self._log(logging.DEBUG, fmt('Using timeout %sms', self:_socketTimeout()))
    -- hack: should be handled in Connection class
    self._connection._tls_connection.socket:setTimeout(self:_socketTimeout(), function()
      self:emit('timeout')
    end)
    --  TODO: make this work: self._connection.readable:on('end', function()
    self._connection._tls_connection:on('end', function()
      self:emit('end')
    end)
  end

  function onError(err)
    self:emit('error', err)
  end

  self._log(logging.DEBUG, 'Connecting...')
  self._connection = Connection:new({}, options)
  self._connection:connect(onConnect, onError)
end

function AgentClient:_attachSocketHandlers()
  self._sock.socket:setTimeout(self:_socketTimeout(), function()
    self:emit('timeout')
  end)
  self._sock:on('error', function(err)
    self._log(logging.ERROR, fmt('Failed to connect: %s', JSON.stringify(err)))
    self:emit('error', err)
  end)
  self._sock:on('end', function()
    self:emit('end')
  end)
end

function AgentClient:getLatency()
  return self._latency
end

function AgentClient:setDestroyed()
  self._destroyed = true
end

function AgentClient:isDestroyed()
  return self._destroyed
end

function AgentClient:startHeartbeatInterval()
  local function startInterval(this)
    local timeout = misc.calcJitterMultiplier(this._heartbeat_interval, consts:get('HEARTBEAT_INTERVAL_JITTER_MULTIPLIER'))

    if this:isDestroyed() then
      return
    end

    this._log(logging.DEBUG, fmt('Starting heartbeat interval, interval=%dms', this._heartbeat_interval))

    local function timerCb()
      local timestamp = Timer.now()
      local send_timestamp = vutils.gmtRaw()

      if this:isDestroyed() then
        return
      end

      this._log(logging.DEBUG, fmt('Sending heartbeat (timestamp=%d,sent_heartbeat_count=%d,got_pong_count=%d)',
                               send_timestamp, this._sent_heartbeat_count, this._got_pong_count))
      this._sent_heartbeat_count = this._sent_heartbeat_count + 1
      this.protocol:request('heartbeat.post', send_timestamp, function(err, msg)
        if this:isDestroyed() then
          return
        end

        if err then
          this:emit('error', err)
          this._log(logging.DEBUG, 'Got an error while sending heartbeat: ' .. tostring(err))
          return
        end

        local recv_timestamp = vutils.gmtRaw()
        this._latency = Timer.now() - timestamp
        if msg.result.timestamp then
          local timeObj = {}
          timeObj.agent_send_timestamp = send_timestamp
          timeObj.agent_recv_timestamp = recv_timestamp
          timeObj.server_receive_timestamp = msg.result.timestamp
          timeObj.server_response_timestamp = msg.result.timestamp
          self:emit('time_sync', timeObj)
        end

        if msg.result.timestamp then
          this._got_pong_count = this._got_pong_count + 1
          this._log(logging.DEBUG, fmt('Got pong (latency=%f,sent_heartbeat_count=%d,got_pong_count=%d)',
                                       this._latency, this._sent_heartbeat_count, this._got_pong_count))
        else
          this._log(logging.DEBUG, 'Got invalid pong response')
        end

        startInterval(this)
      end)
    end

    this._heartbeatTimeout = timer.setTimeout(timeout, timerCb)
   end

   startInterval(self)
end

function AgentClient:clearHeartbeatInterval()
  if self._heartbeatTimeout then
    self._log(logging.DEBUG, 'Clearing heartbeat interval')
    timer.clearTimer(self._heartbeatTimeout)
    self._heartbeatTimeout = nil
  end
end

function AgentClient:destroy()
  if self:isDestroyed() then
    return
  end
  self:getMachine():react(self, 'done')
  self:setDestroyed()
  self._connection:destroy()
end

exports.AgentClient = AgentClient
