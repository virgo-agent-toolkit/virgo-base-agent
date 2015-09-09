local logging = require('logging')
local Split = require('split-stream')

local Duplex = require('stream').Duplex
local Transform = require('stream').Transform

local JSON = require('json')
local dns = require('dns')
local consts = require('./util/constants')
local loggingUtil = require('./util/logging')
local misc = require('./util/misc')
local fmt = require('string').format
local request = require('request')
local timer = require('timer')
local tls = require('tls')
local utils = require('utils')
local Error = require('core').Error

local CXN_STATES = {
  INITIAL = 'INITIAL',
  RESOLVED = 'RESOLVED',
  PROXIED = 'PROXIED',
  CONNECTED = 'CONNECTED',
  READY = 'READY',
  AUTHENTICATED = 'AUTHENTICATED',
  ERROR = 'ERROR',
  DESTROYED = 'DESTROYED',
}

--[[
-- Connection is a class that initiates TLS connection to other parties,
-- manages protocol states (handshake, etc.) and handles JSON (un)marshalling.
--
-- Although for now it is implemented to be Agent specific, Connection is
-- intended to be a general class that works for both agents and agent
-- endpoints. This means at some point, it will be able to not only initiate
-- connection and handshake, but also listen for connections and respond to
-- handshake requests. (refer to virgo.js)
--]]
local Connection = Duplex:extend()
function Connection:initialize(manifest, options)
  Duplex.initialize(self, {objectMode = true})

  --local manifest
  self.manifest = manifest

  -- remote manifest
  self.remote = nil

  self.options = options or {}
  self.proxy = self.options.proxy
  self.features = options.features or {}
  self._handshake_timeout = consts:get("DEFAULT_HANDSHAKE_TIMEOUT", 30000)

  self.timers = {}

  if type(options.endpoint) == 'table' then
    self.host = options.endpoint.host or nil
    self.port = options.endpoint.port or 443
    self.endpoint = fmt('%s:%s', self.host, self.port)
  elseif type(options.endpoint) == 'string' then
    self.endpoint = options.endpoint
  end

  -- copy tls_options so that we don't alter the object provided by user
  self._tls_options = misc.deepCopyTable(self.options.tls_options) or {}
  self._tls_options.ca = self._tls_options.ca or options.ca
  self._tls_options.key = self._tls_options.key or options.key

  if self.host ~= nil then
    self._state = CXN_STATES.RESOLVED
  else
    -- no host provided; need to resolve SRV.
    self._state = CXN_STATES.INITIAL
  end

  self._log = loggingUtil.makeLogger(fmt('Connection: %s (%s:%s)',
    tostring(self.endpoint),
    self.host,
    tostring(self.port)
  ))

  -- state machine chaining
  self:once(CXN_STATES.INITIAL, utils.bind(self._resolve, self))
  self:once(CXN_STATES.RESOLVED, utils.bind(self._proxy, self))
  self:once(CXN_STATES.PROXIED, utils.bind(self._connect, self))
  self:once(CXN_STATES.CONNECTED, utils.bind(self._ready, self))
  self:once(CXN_STATES.READY, utils.bind(self._handshake, self))
end

-- triggers the state machine to start
function Connection:connect(callback, callback_error)
  self:once(CXN_STATES.AUTHENTICATED, callback)
  self:once(CXN_STATES.ERROR, callback_error)
  self:emit(self._state)
end

function Connection:destroy()
  if self._state == CXN_STATES.DESTROYED then
    return
  end
  if self._tls_connection then
    self._log(logging.DEBUG, 'Closing underlying TLS connection')
    self._tls_connection:destroy()
    for k,v in ipairs(self.timers) do
      timer.clearTimer(v)
    end
    self:_changeState(CXN_STATES.DESTROYED)
  end
end

function Connection:_changeState(to, data)
  self._log(logging.DEBUG, self._state .. ' -> ' .. to)
  self._state = to
  self:emit(to, data)
end

function Connection:_error(err)
  self._log(logging.ERROR, tostring(err))
  self:_changeState(CXN_STATES.ERROR, err)
end

-- resolve SRV record
function Connection:_resolve()
  dns.resolveSrv(self.endpoint, function(err, host)
    if err then
      self:_error(err)
      return
    end
    self.host = host[0].name
    self.port = host[0].port
    self:_changeState(CXN_STATES.RESOLVED)
  end)
end

-- get the proxy ready if configured, or pass to next state if no proxy is
-- configured
function Connection:_proxy()
  if self.proxy then
    self._log(logging.DEBUG, fmt('Using PROXY %s with timeout %s', self.proxy, self.timeout))
    local upstream_host = fmt('%s:%s', self.host, self.port)
    request.proxy(self.proxy, upstream_host, self.timeout, function(err, proxysock)
      if err then
        self:_error(err)
        return
      end
      self._log(logging.DEBUG, '... connected to proxy')
      self._tls_options.socket = proxysock
      self._tls_options.host = self.host
      self._log(logging.DEBUG, '... upgrading socket to TLS')
      self:_changeState(CXN_STATES.PROXIED)
    end)
  else
    self:_changeState(CXN_STATES.PROXIED)
  end
end

-- set the connection timeout
function Connection:setTimeout(ms, callback)
  self.timeout = ms
  self._tls_connection:setTimeout(ms, callback)
end

function Connection:getSocket()
  return self._tls_connection
end

-- initiate TLS connection
function Connection:_connect()
  self._tls_options.host = self.host
  self._tls_options.port = self.port
  self._tls_connection = tls.TLSSocket:new(self._tls_options.socket, self._tls_options)
  if not self._tls_options.socket then
    self._tls_connection:connect(self.port, self.host)
  end
  self._tls_connection:once('secureConnection', function()
    self:_changeState(CXN_STATES.CONNECTED)
  end)
  self._tls_connection:on('error', function(err)
    self:_error(err)
  end)
  self._tls_connection:on('close', function()
    self:emit('close')
  end)
end

-- construct JSON parser/encoding on top of the TLS connection
function Connection:_ready()
  local msg_id = 0
  local success, err

  local jsonify = Transform:new({
    objectMode = false,
    writableObjectMode = true
  })
  jsonify._transform = function(this, chunk, callback)
    if not chunk.id then
      chunk.id = msg_id
      msg_id = msg_id + 1
    end

    chunk.target = 'endpoint'

    success, err = pcall(function()
      this:push(JSON.stringify(chunk) .. '\n') -- \n delimited JSON
    end)
    if not success then
      self._log(logging.ERROR, err)
    end
    callback() -- suppress the error
  end

  local dejsonify = Split:new({
    objectMode = true,
    -- \n is the default separator
    mapper = function(chunk)
      local obj = nil
      success, err = pcall(function()
        obj = JSON.parse(chunk)
      end)
      if not success then
        self._log(logging.ERROR, err)
      end
      return obj
    end,
  })

  self.readable = self._tls_connection:pipe(dejsonify)
  self.writable = jsonify
  self.writable:pipe(self._tls_connection)
  self:_changeState(CXN_STATES.READY)
end

-- initiate Handshake request (handshake.hello)
function Connection:_handshake()
  local msg = self:_handshakeMessage()
  local function onDataClient(data)
    if data.id == msg.id and data.source == msg.target and data.target == msg.source then
      if data.v ~= msg.v then
        self:_error(string.format('Version mismatch: message_version=%d response_version=%d', msg.v, data.v))
        return
      elseif data['error'] then
        self:_error(data['error'].message)
        return
      end

      -- TODO: self.remote = data.manifest | protocol change

      self.readable:removeListener('data', onDataClient)
      -- hack before Connection class fully takes over handshakes
      self.handshake_msg = data
      self._log(logging.DEBUG, string.format('handshake successful (heartbeat_interval=%dms)', self.handshake_msg.result.heartbeat_interval))

      self:_changeState(CXN_STATES.AUTHENTICATED)
    end
  end
  -- using on() instead of once() and let the handler removes itself because
  -- incoming message might be non-handshake messages.
  self.readable:on('data', onDataClient)
  table.insert(self.timers, timer.setTimeout(self._handshake_timeout, function()
    if self._state ~= CXN_STATES.AUTHENTICATED then
      self:_error(string.format("Handshake timeout, haven't received response in %d ms", self._handshake_timeout))
    end
  end))
  self.writable:write(msg)
end

function Connection:_handshakeMessage()
  return {
    v = '1',
    id = nil, -- let jsonify handle msg_id
    target = 'endpoint',
    source = self.options.agent.guid,
    method = 'handshake.hello',
    params = {
      token = self.options.agent.token,
      agent_id = self.options.agent.id,
      agent_name = self.options.agent.name,
      process_version = virgo.virgo_version,
      bundle_version = virgo.bundle_version,
      features = self.features or {},
    },
  }
end

function Connection:pipe(dest, pipeOpts)
  return self.readable:pipe(dest, pipeOpts)
end

function Connection:_read(n)
  return self.readable:_read(n)
end

function Connection:_write(chunk, callback)
  -- since it's the Connecter rather than self.writable that is piped into from
  -- upstream stream, we call write() instead of _write() here.
  self.writable:write(chunk, callback)
end

return Connection
