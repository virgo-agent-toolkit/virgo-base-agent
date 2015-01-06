local Connection = require('virgo/connection')
local Duplex = require('stream_duplex').Duplex
local JSON = require('json')
local core = require('core')
local Emitter = core.Emitter
local path = require('luvi').path
local pem = require('unit-tests/pem')
local spawn = require('childprocess').spawn
local timer = require('timer')
local tls = require('tls')

local mock_server = function(data)
  local onClient, options
  function onClient(c)
    c:on('data', function(dat)
      if type(data) == 'string' then
        c:write(data)
      elseif type(data) == 'table' then
        for k,v in ipairs(data) do
          timer.setTimeout(k * 200, function()
            c:write(v)
          end)
        end
      else
        assert(false)
      end
    end)
  end

  options = {}
  options.cert = pem.certPem
  options.key = pem.keyPem
  options.rejectUnauthorized = false
  return tls.createServer(options, onClient)
end

local test_hello_response_error_handling = function(fixture, checkErr)
  local connection = Connection:new(nil, {
    endpoint = {
      host = '127.0.0.1',
      port = 50041,
    },
    agent = {
      token = 'this_is_a_token',
      id = 'agentA',
    },
    tls_options = {
      rejectUnauthorized = false 
    }
  })
  local server = mock_server(fixture .. '\n')
  server:listen(50041, function()
    local onSuccess, onError
    function onSuccess() end
    function onError(err)
      checkErr(err)
      connection:destroy()
      server:destroy()
    end
    connection:connect(onSuccess, onError)
  end)
end

require('tap')(function(test)
  test('Connection is stream.Duplex', function()
    local connection, options
    options = {
      endpoint = {
        host = 'localhost',
        port = 50041,
      },
      agent = {
        token = 'this_is_a_token',
        id = '1',
      },
      rejectUnauthorized = false
    }
    connection = Connection:new(nil, options)
    assert(core.instanceof(connection, Duplex))
  end)

  test('bad version hello gives err', function()
    test_hello_response_error_handling('{ "v": "2147483647", "id": 0, "source": "endpoint", "target": "agentA", "result": { "heartbeat_interval": 1000 } }', function(err)
      assert('Version mismatch: message_version=1 response_version=2147483647')
    end)
  end)
end)

--
--test('test bad process version hello fails', nil, function(t)
--  test_hello_response_error_handling(t, fixtures['invalid-process-version']['handshake.hello.response'], function(err)
--    t:not_nil(err:find('Agent version [%w%p]* is too old, please upgrade to'))
--  end)
--end)
--
--test('test bad bundle version hello fails', nil, function(t)
--  test_hello_response_error_handling(t, fixtures['invalid-bundle-version']['handshake.hello.response'], function(err)
--    t:not_nil(err:find('Agent bundle version [%w%p]* is too old, please upgrade to'))
--  end)
--end)
--
--test('unexpected response and hello timeout', nil, function(t)
--  local data = JSON.parse(fixtures['invalid-version']['handshake.hello.response'])
--  data.id = 4
--  test_hello_response_error_handling(t, JSON.stringify(data):gsub('\n', " "), function(err)
--    t:not_nil(err:find('Handshake timeout, haven\'t received response in'))
--  end)
--end)
--
--test('fragmented message', nil, function(t)
--  local connection = Connection:new(nil, {
--    endpoint = {
--      host = '127.0.0.1',
--      port = 50041,
--    },
--    agent = {
--      token = 'this_is_a_token',
--      id = 'agentA',
--    },
--    tls_options = {
--      rejectUnauthorized = false,
--    },
--  })
--  local fixture = fixtures['handshake.hello.response']
--  local server = mock_server({fixture:sub(1, 4), fixture:sub(5, #fixture) .. '\n'})
--  server:listen(50041, function()
--    connection:connect(function()
--      connection:destroy()
--      server:close()
--      t:finish()
--    end,
--    function(err)
--      t:equal(true, false, 'error encounter in Connection Handshake')
--      connection:destroy()
--      server:close()
--      t:finish()
--    end)
--  end)
--end)
--
--test('multiple messages in a single chunk', nil, function(t)
--  local connection = Connection:new(nil, {
--    endpoint = {
--      host = '127.0.0.1',
--      port = 50041,
--    },
--    agent = {
--      token = 'this_is_a_token',
--      id = 'agentA',
--    },
--    tls_options = {
--      rejectUnauthorized = false,
--    },
--    features = {
--      'TEST_FEATURE_1'
--    }
--  })
--  local fixture = fixtures['handshake.hello.response'] .. '\n'
--  local server = mock_server(fixture .. fixture)
--  local sink = stream.Writable:new({objectMode = true})
--  sink._write = function(this, data, encoding, callback)
--    callback()
--    connection:destroy()
--    server:close()
--    t:finish()
--  end
--  server:listen(50041, function()
--    connection:connect(function()
--      connection:pipe(sink)
--    end,
--    function(err)
--      t:equal('TEST_FEATURE_1', connection.features[1])
--      t:equal(true, false, 'error encounter in Connection Handshake')
--      connection:destroy()
--      server:close()
--      t:finish()
--    end)
--  end)
--end)
--
--test('test no features', nil, function(t)
--  local connection = Connection:new(nil, {
--    endpoint = {
--      host = '127.0.0.1',
--      port = 50041,
--    },
--    agent = {
--      token = 'this_is_a_token',
--      id = 'agentA',
--    },
--    tls_options = {
--      rejectUnauthorized = false,
--    }
--  })
--  local fixture = fixtures['handshake.hello.response'] .. '\n'
--  local server = mock_server(fixture .. fixture)
--  local sink = stream.Writable:new({objectMode = true})
--  sink._write = function(this, data, encoding, callback)
--    callback()
--    connection:destroy()
--    server:close()
--    t:finish()
--  end
--  server:listen(50041, function()
--    connection:connect(function()
--      connection:pipe(sink)
--    end,
--    function(err)
--      t:equal(nil, connection.features[1])
--      t:equal(true, false, 'error encounter in Connection Handshake')
--      connection:destroy()
--      server:close()
--      t:finish()
--    end)
--  end)
--end)
