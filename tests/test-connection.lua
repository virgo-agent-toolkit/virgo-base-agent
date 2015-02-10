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
local Connection = require('virgo/connection')
local Duplex = require('stream').Duplex
local core = require('core')
local fixtures = require('fixtures')
local pem = require('pem')
local timer = require('timer')
local tls = require('tls')
local Writable = require('stream').Writable

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
  local connection, server, onListen

  connection = Connection:new(nil, {
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

  function onListen()
    local onSuccess, onError
    function onSuccess() end
    function onError(err)
      checkErr(err)
      connection:destroy()
      server:destroy()
    end
    connection:connect(onSuccess, onError)
  end

  server = mock_server(fixture .. '\n')
  server:listen(50041, onListen)
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
    test_hello_response_error_handling(fixtures['invalid-version']['handshake.hello.response'], function(err)
      assert(err == 'Version mismatch: message_version=1 response_version=2147483647')
    end)
  end)

  test('test bad process version hello fails', function(t)
    test_hello_response_error_handling(fixtures['invalid-process-version']['handshake.hello.response'], function(err)
      assert(err:find('Agent version [%w%p]* is too old, please upgrade to'))
    end)
  end)

  test('test bad bundle version hello fails', function(t)
    test_hello_response_error_handling(fixtures['invalid-bundle-version']['handshake.hello.response'], function(err)
      assert(err:find('Agent bundle version [%w%p]* is too old, please upgrade to'))
    end)
  end)

  -- TODO
  -- test('unexpected response and hello timeout', function()
  --   local data
  --   data = JSON.parse(fixtures['invalid-version']['handshake.hello.response'])
  --   data.id = 4
  --   data = JSON.stringify(data):gsub('\n', " ")
  --   test_hello_response_error_handling(data, function(err)
  --     assert(err:find('Handshake timeout, haven\'t received response in'))
  --   end)
  -- end)

  test('fragmented message', function()
    local connection, fixture, server
    local onSuccess, onError

    connection = Connection:new(nil, {
      endpoint = {
        host = '127.0.0.1',
        port = 50041,
      },
      agent = {
        token = 'this_is_a_token',
        id = 'agentA',
      },
      tls_options = {
        rejectUnauthorized = false,
      },
    })

    function onSuccess()
      local onConnect
      function onConnect()
        connection:destroy()
        server:close()
      end
      connection:connect(onConnect)
    end

    function onError(err)
      assert(false, 'error encounter in connection handshake')
      connection:destroy()
      server:close()
    end

    fixture = fixtures['handshake.hello.response']
    server = mock_server({fixture:sub(1, 4), fixture:sub(5, #fixture) .. '\n'})
    server:listen(50041, onSuccess, onError)
  end)

  test('multiple messages in a single chunk', function()
    local connection, fixture, server, sink
    local onListen

    connection = Connection:new(nil, {
      endpoint = {
        host = '127.0.0.1',
        port = 50041,
      },
      agent = {
        token = 'this_is_a_token',
        id = 'agentA',
      },
      tls_options = {
        rejectUnauthorized = false,
      },
      features = {
        'TEST_FEATURE_1'
      }
    })

    fixture = fixtures['handshake.hello.response'] .. '\n'
    server = mock_server(fixture .. fixture)

    sink = Writable:new({objectMode = true})
    function sink._write(this, data, encoding, callback)
      callback()
      connection:destroy()
      server:close()
    end

    function onListen()
      local onSuccess, onError
      
      function onSuccess()
        connection:pipe(sink)
      end

      function onError(err)
        assert(false)
        connection:destroy()
        server:close()
      end

      connection:connect(onSuccess, onError)
    end

    server:listen(50041, onListen)
  end)

  test('test no features', function(t)
    local connection, fixture, sink, server
    local onListen

    connection = Connection:new(nil, {
      endpoint = {
        host = '127.0.0.1',
        port = 50041,
      },
      agent = {
        token = 'this_is_a_token',
        id = 'agentA',
      },
      tls_options = {
        rejectUnauthorized = false,
      }
    })

    fixture = fixtures['handshake.hello.response'] .. '\n'
    server = mock_server(fixture .. fixture)
    sink = Writable:new({objectMode = true})
    function sink._write(this, data, encoding, callback)
      callback()
      connection:destroy()
      server:close()
    end

    function onListen()
      local onSuccess, onError

      function onSuccess()
        connection:pipe(sink)
      end

      function onError(err)
        connection:destroy()
        server:close()
      end

      connection:connect(onSuccess, onError)
    end

    server:listen(50041, onListen)
  end)
end)
