local Connection = require('/base/libs/connection')
local JSON = require('json')
local stream = require('/base/modules/stream')
local test = require('/base/modules/tape')('connection')
local tls = require('tls')
local core = require('core')
local fixtures = require('/tests/fixtures')
local timer = require('timer')

local pem = require('/base/tests/unit-tests/pem')

local mock_server = function(data)
	return tls.createServer({
		cert = pem.certPem,
		key = pem.keyPem,
		includeTimeouts = true,
	}, function (c)
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
	end)
end

test('Connection is stream.Duplex', nil, function(t)
  local connection = Connection:new(nil, {
    endpoint = {
      host = 'localhost',
      port = 12345,
    },
    agent = {
      token = 'this_is_a_token',
      id = '1',
    },
  })
  t:equal(true, core.instanceof(connection, stream.Duplex))
  t:finish()
end)

local test_hello_response_error_handling = function(t, fixture, checkErr)
	local connection = Connection:new(nil, {
		endpoint = {
			host = 'localhost',
			port = 12345,
		},
		agent = {
			token = 'this_is_a_token',
			id = 'agentA',
		},
		tls_options = {
			rejectUnauthorized = false,
		},
	})
	local server = mock_server(fixture .. '\n')
	server:listen(12345, function()
		connection:connect(function()
			t:equal(true, false, 'expected error in Connection')
			t:finish()
		end, function(err)
			checkErr(err)
			connection:destroy()
			server:close()
			t:finish()
		end)
	end)
end

test('bad version hello gives err', nil, function(t)
	test_hello_response_error_handling(t, fixtures['invalid-version']['handshake.hello.response'], function(err)
		t:equal(err, 'Version mismatch: message_version=1 response_version=2147483647')
	end)
end)

test('test bad process version hello fails', nil, function(t)
	test_hello_response_error_handling(t, fixtures['invalid-process-version']['handshake.hello.response'], function(err)
		t:not_nil(err:find('Agent version [%w%p]* is too old, please upgrade to'))
	end)
end)

test('test bad bundle version hello fails', nil, function(t)
	test_hello_response_error_handling(t, fixtures['invalid-bundle-version']['handshake.hello.response'], function(err)
		t:not_nil(err:find('Agent bundle version [%w%p]* is too old, please upgrade to'))
	end)
end)

test('unexpected response and hello timeout', nil, function(t)
	local data = JSON.parse(fixtures['invalid-version']['handshake.hello.response'])
	data.id = 4
	test_hello_response_error_handling(t, JSON.stringify(data):gsub('\n', " "), function(err)
		t:not_nil(err:find('Handshake timeout, haven\'t received response in'))
	end)
end)

test('fragmented message', nil, function(t)
	local connection = Connection:new(nil, {
		endpoint = {
			host = 'localhost',
			port = 12345,
		},
		agent = {
			token = 'this_is_a_token',
			id = 'agentA',
		},
		tls_options = {
			rejectUnauthorized = false,
		},
	})
	local fixture = fixtures['handshake.hello.response']
	local server = mock_server({fixture:sub(1, 4), fixture:sub(5, #fixture) .. '\n'})
	server:listen(12345, function()
		connection:connect(function()
			connection:destroy()
			server:close()
			t:finish()
		end, function(err)
			t:equal(true, false, 'error encounter in Connection Handshake')
			connection:destroy()
			server:close()
			t:finish()
		end)
	end)
end)

test('multiple messages in a single chunk', nil, function(t)
	local connection = Connection:new(nil, {
		endpoint = {
			host = 'localhost',
			port = 12345,
		},
		agent = {
			token = 'this_is_a_token',
			id = 'agentA',
		},
		tls_options = {
			rejectUnauthorized = false,
		},
	})
	local fixture = fixtures['handshake.hello.response'] .. '\n'
	local server = mock_server(fixture .. fixture)
	local sink = stream.Writable:new({objectMode = true})
	sink._write = function(this, data, encoding, callback)
		callback()
		connection:destroy()
		server:close()
		t:finish()
	end
	server:listen(12345, function()
		connection:connect(function()
			connection:pipe(sink)
		end, function(err)
			t:equal(true, false, 'error encounter in Connection Handshake')
			connection:destroy()
			server:close()
			t:finish()
		end)
	end)
end)