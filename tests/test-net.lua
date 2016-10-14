local timer = require('timer')

local async = require('async')
local constants = require('../util/constants_ctx').ConstantsCtx:new()
local ConnectionStream = require('../client/connection_stream').ConnectionStream
local Endpoint = require('../client/endpoint').Endpoint
local Server = require('server').Server
local uv = require('uv')

constants:setGlobal("DEFAULT_HANDSHAKE_TIMEOUT", 10000)
constants:setGlobal("DATACENTER_FIRST_RECONNECT_DELAY", 500)
constants:setGlobal("DATACENTER_FIRST_RECONNECT_DELAY_JITTER", 500)
constants:setGlobal("DATACENTER_RECONNECT_DELAY", 500)
constants:setGlobal("DATACENTER_RECONNECT_DELAY_JITTER", 500)

local TESTING_AGENT_ENDPOINTS = {
  '127.0.0.1:50041',
  '127.0.0.1:50051',
  '127.0.0.1:50061'
}

local TimeoutServer = Server:extend()
function TimeoutServer:initialize(options)
  Server.initialize(self, options)
end

function TimeoutServer:_onLineProtocol(client, line)
  -- Timeout All Requests
end

require('tap')(function(test)
  test('test_handshake_timeout', function()
    local AEP, options, endpoints, client

    options = {
      datacenter = 'test',
      tls = { rejectUnauthorized = false }
    }

    endpoints = { Endpoint:new('127.0.0.1:4444') }

    async.series({
      function(callback)
        AEP = TimeoutServer:new({includeTimeouts = false})
        AEP:listen(4444, '127.0.0.1', callback)
      end,
      function(callback)
        client = ConnectionStream:new('id', 'token', 'guid', false, options)
        client:createConnections(endpoints, callback)
      end,
      function(callback)
        client:once('reconnect', callback)
      end
    }, function()
      client:shutdown()
      AEP:close()
    end)
  end)

  test('test_hanging_connect', function()
    -- Note: This test will timeout if anything goes wrong with the socket
    -- timeout
    local options = {
      datacenter = 'test',
      timeout = 5000,
      tls = { rejectUnauthorized = false }
    }
    local server = uv.new_tcp()
    uv.tcp_bind(server, "127.0.0.1", 0)
    uv.listen(server, 128, function() end)
    local address = uv.tcp_getsockname(server)
    p(address)

    local endpoints = { Endpoint:new(address.ip .. ':' .. address.port) }
    local stream = ConnectionStream:new('id', 'token', 'guid', false, options)
    stream:createConnections(endpoints)
    stream:once('timeout', function()
      stream:shutdown()
      if not uv.is_closing(server) then uv.close(server) end
    end)
  end)

  --test('test_hanging_connect_memory_test', function()
  --  local options = {
  --    datacenter = 'test',
  --    timeout = 5000,
  --    tls = { rejectUnauthorized = false }
  --  }
  --  local server = uv.new_tcp()
  --  uv.tcp_bind(server, "127.0.0.1", 0)

  --  local address = uv.tcp_getsockname(server)
  --  p(address)

  --  local t = uv.new_timer()
  --  function r()
  --    local endpoints = { Endpoint:new(address.ip .. ':' .. address.port) }
  --    local stream = ConnectionStream:new('id', 'token', 'guid', false, options)
  --    stream:createConnections(endpoints)
  --    stream:once('timeout', function()
  --      stream:shutdown()
  --      collectgarbage()
  --      collectgarbage()
  --      --if not uv.is_closing(server) then uv.close(server) end
  --    end)
  --  end
  --  uv.timer_start(t, 20, 20, r)
  --end)

  test('test_reconnects', function()
    local servers, options, client, clientEnd, reconnect
    local endpoints

    clientEnd = 0
    reconnect = 0
    options = {
      datacenter = 'test',
      tls = { rejectUnauthorized = false }
    }

    client = ConnectionStream:new('id', 'token', 'guid', false, options)
    client:on('client_end', function(err) clientEnd = clientEnd + 1 end)
    client:on('reconnect', function(err) reconnect = reconnect + 1 end)

    endpoints = {Endpoint:new(TESTING_AGENT_ENDPOINTS[1])}
    AEP = Server:new()
    AEP:listen(50041, '127.0.0.1')

    async.series({
      function(callback)
        client:once('handshake_success', function() callback() end)
        client:createConnections(endpoints)
      end,
      function(callback)
        AEP:close()
        client:once('reconnect', function() callback() end)
      end,
      function(callback)
        AEP = Server:new()
        AEP:listen(50041, '127.0.0.1')
        client:once('handshake_success', function() callback() end)
      end,
      function(callback)
        AEP:close()
        AEP = Server:new()
        AEP:listen(50041, '127.0.0.1')
        client:once('reconnect', function() callback() end)
      end
    }, function()
      client:shutdown()
      AEP:close()
      assert(clientEnd > 0)
      assert(reconnect > 0)
    end)
  end)
end)

--exports['test_reconnects'] = function(test, asserts)
--  local AEP
--
--  if os.type() == "win32" then
--    test.skip("Skip test_reconnects until a suitable SIGUSR1 replacement is used in runner.py")
--    return nil
--  end
--
--  local options = {
--    datacenter = 'test',
--    stateDirectory = './tests',
--    tls = { rejectUnauthorized = false }
--  }
--
--  local client = ConnectionStream:new('id', 'token', 'guid', false, options)
--
--  local clientEnd = 0
--  local reconnect = 0
--
--  client:on('client_end', function(err)
--    clientEnd = clientEnd + 1
--  end)
--
--  client:on('reconnect', function(err)
--    reconnect = reconnect + 1
--  end)
--
--  local endpoints = {}
--  for _, address in pairs(TESTING_AGENT_ENDPOINTS) do
--    -- split ip:port
--    table.insert(endpoints, Endpoint:new(address))
--  end
--
--  async.series({
--    function(callback)
--      AEP = helper.start_server(callback)
--    end,
--    function(callback)
--      client:on('handshake_success', misc.nCallbacks(callback, 3))
--      local endpoints = {}
--      for _, address in pairs(TESTING_AGENT_ENDPOINTS) do
--        -- split ip:port
--        table.insert(endpoints, Endpoint:new(address))
--      end
--      client:createConnections(endpoints, function() end)
--    end,
--    function(callback)
--      AEP:kill(9)
--      client:on('reconnect', misc.nCallbacks(callback, 3))
--    end,
--    function(callback)
--      AEP = helper.start_server(function()
--        client:on('handshake_success', misc.nCallbacks(callback, 3))
--      end)
--    end,
--  }, function()
--    AEP:kill(9)
--    asserts.ok(clientEnd > 0)
--    asserts.ok(reconnect > 0)
--    test.done()
--  end)
--end
--
--exports['test_upgrades'] = function(test, asserts)
--  local options, client, endpoints
--
--  if true then
--    test.skip("Skip upgrades test until it is reliable")
--    return nil
--  end
--
--  -- Override the default download path
--  consts:setGlobal('DEFAULT_DOWNLOAD_PATH', path.join('.', 'tmp'))
--
--  options = {
--    datacenter = 'test',
--    stateDirectory = './tests',
--    tls = { rejectUnauthorized = false }
--  }
--
--  local endpoints = {}
--  for _, address in pairs(TESTING_AGENT_ENDPOINTS) do
--    -- split ip:port
--    table.insert(endpoints, Endpoint:new(address))
--  end
--
--  async.series({
--    function(callback)
--      AEP = helper.start_server(callback)
--    end,
--    function(callback)
--      client = ConnectionStream:new('id', 'token', 'guid', false, options)
--      client:once('error', callback)
--      client:createConnections(endpoints, function() end)
--    end,
--  }, function()
--    AEP:kill(9)
--    client:done()
--    test.done()
--  end)
--end
