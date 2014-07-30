local dns = require('dns')
local JSON = require('json')
local logging = require('logging')
local loggingUtil = require('/base/util/logging')
local stream = require('stream')
local string = require('string')
local tls = require('tls')
local utils = require('utils')

local CXN_STATES = {
  INITIAL = 'INITIAL',
  RESOLVED = 'RESOLVED',
  CONNECTED = 'CONNECTED',
  READY = 'READY',
  AUTHENTICATED = 'AUTHENTICATED',
  ERROR = 'ERROR',
}

local Connection = stream.Duplex:extend()
function Connection:initialize(manifest, options)
  stream.Duplex.initialize(self, {objectMode = true})

  --local manifest
  self.manifest = manifest

  -- remote manifest
  self.remote = nil

  self.options = options or {}

  --[[
  This means different behaviors on initiating the connection and during the
  handshake. Client initiates connection while server listens; clients
  initiates handshake while server responds.
  ]]
  self._is_server = false

  self.connection = self.options.connection or nil
  if self.connection == nil then -- client (agent) mode
    if type(options.endpoint) == 'table' then
      self.host = options.endpoint.host or nil
      self.port = options.endpoint.port or 443
    elseif type(options.endpoint) == 'string' then
      self.endpoint = options.endpoint
    else
      assert(false) -- TODO
    end

    self.ca = options.ca or nil
    self.key = options.key or nil

    if self.host ~= nil then
      self._state = CXN_STATES.RESOLVED
    else
      -- no host provided; need to resolve SRV.
      self._state = CXN_STATES.INITIAL
    end
  else -- underlying tls connection provided; server mode
    self._is_server = true
    self._state = CXN_STATES.CONNECTED
  end

  self._log = loggingUtil.makeLogger(string.format('Connection: %s (%s:%s)',
    tostring(self.endpoint),
    self.host,
    tostring(self.port)
  ))

  -- state machine chaining
  self:once(CXN_STATES.INITIAL, utils.bind(self._resolve, self))
  self:once(CXN_STATES.RESOLVED, utils.bind(self._connect, self))
  self:once(CXN_STATES.CONNECTED, utils.bind(self._ready, self))
  self:once(CXN_STATES.READY, utils.bind(self._handshake, self))
end

-- triggers the state machine to start
function Connection:connect(callback)
  self:once(CXN_STATES.AUTHENTICATED, callback)
  self:once(CXN_STATES.ERROR, callback)

  self:emit(self._state)
end

function Connection:_changeState(to, data)
  self._log(logging.DEBUG, self._state + ' -> ' + to)
  self._state = to
  self:emit(to, data)
end

function Connection:_error(err)
  self._log(logging.ERROR, err)
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

-- initiate TLS connection
function Connection:_connect()
  local tls_options = {}
  for _,k in pairs({'host', 'port', 'ca', 'key'}) do
    tls_options[k] = self[k]
  end
  self.connection = tls.connect(tls_options, function(err)
    if err then
      self:_error(err)
      return
    end
    self:_changeState(CXN_STATES.CONNECTED)
  end)
end

-- construct JSON parser/encoding on top of the TLS connection
function Connection:_ready()
  local msg_id = 0

  local jsonify = stream.Transform:new({
    objectMode = false,
    writableObjectMode = true
  })
  jsonify._transform = function(self, chunk, encoding, callback)
    if not chunk.id then
      chunk.id = msg_id
      msg_id = msg_id + 1
    end
    success, err = pcall(function()
      self:push(JSON.stringify(o) + '\n')
      callback(nil)
    end)
    if not success then
      self:_error(err)
      callback(err)
    end
  end

  local dejsonify = stream.Transform:new({
    objectMode = true,
    writableObjectMode = false
  })
  dejsonify._transform = function(self, chunk, encoding, callback)
    success, err = pcall(function()
      self:push(JSON.parse(chunk))
      callback()
    end)
    if not success then
      self:_error(err)
      callback(err)
    end
  end

  self.readable = self.connection:pipe(dejsonify)
  self.writable = jsonify
  self.writable:pipe(self.connection)
  self:_changeState(CXN_STATES.READY)
end

-- client (agent) and server (endpoint) handshake and exchange manifest data.
function Connection:_handshake()
  if (self._is_server) then
    local function onDataServer(data)
      if data.method == 'handshake.post' then
        self.remote = data.manifest
        -- TODO
        if true then -- if successful
          self.readable:removeListener('data', onDataServer)
          self.writable:write(self:_handshakeMessage())
          self:_changeState(CXN_STATES.AUTHENTICATED)
        end
      end
    end
    -- using on() instead of once() and let the handler removes itself because
    -- incoming message might be non-handshake messages.
    self.readable:on('data', onDataServer)
  else
    local function onDataClient(data)
      if data.method == 'handshake.post' then
        -- TODO
          self.remote = data.manifest
        if true then -- if successful
          self.readable:removeListener('data', onDataClient)
          self:_changeState(CXN_STATES.AUTHENTICATED)
        end
      end
    end
    -- using on() instead of once() and let the handler removes itself because
    -- incoming message might be non-handshake messages.
    self.readable:on('data', onDataClient)
    self.writable:write(self:_handshakeMessage())
  end
end

function Connection:_handshakeMessage()
  return {
    manifest = self.manifest,
    method = 'handshake.post',
    -- TODO
    -- * normal handsake stuff
  }
end

function Connection:pipe(dest, pipeOpts)
  return self.readable:pipe(dest, pipeOpts)
end

function Connection:_read(n)
  return self.readable:_read(n)
end

function Connection:_write(chunk, encoding, callback)
  -- since it's the Connecter rather than self.writable that is piped into from
  -- upstream stream, we call write() instead of _write() here.
  self.writable:write(chunk, encoding)
  callback()
end

return Connection
