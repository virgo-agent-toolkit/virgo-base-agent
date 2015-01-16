local path = require('path')
local table = require('table')
local timer = require('timer')
local uv = require('uv')

local async = require('rphillips/async')
local constants = require('virgo/util/constants_ctx').ConstantsCtx:new()
local ConnectionStream = require('virgo/client/connection_stream').ConnectionStream
local Endpoint = require('virgo/client/endpoint').Endpoint
local Server = require('test-server').Server
local misc = require('virgo/util/misc')

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
        AEP:listen(4444, '127.0.0.1')
        timer.setTimeout(1000, callback)
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
    }, function()
      client:shutdown()
      AEP:close()
      assert(clientEnd > 0)
      assert(reconnect > 0)
    end)
  end)
end)
