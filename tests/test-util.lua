--[[
Copyright 2015 Rackspace

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

local misc = require('../util/misc')
local safeMerge = misc.safeMerge
local run = misc.run
local read = misc.read
local path = require('path')
local fs = require('fs')
local Transform = require('stream').Transform

local Reader = Transform:extend()
function Reader:initialize()
  Transform.initialize(self, {objectMode = true})
end
function Reader:_transform(line, cb) 
  self:push(line)
  cb()
end
require('tap')(function(test)
  test('Test for read', function(expect)
    local txt = [[Line1\n#comment line\n \nLine2]]
    local tmp_file = path.join(module.dir, 'test_read.txt')
    fs.writeFileSync(tmp_file, txt)
    local readData = {}
    local function onEnd()
      local expected = 'Line1 Line2'
      local readString = table.concat(readData)
      assert(expected == readString)
      fs.unlinkSync(tmp_file)
    end

    local readStream = read(tmp_file)
    local reader = Reader:new()
    reader:once('end', onEnd)
    reader:on('data', function(data)
      safeMerge(readData, data)
    end)
    readStream:pipe(reader)
  end)

  test('Test for run', function()
    local store = ''
    local cmd = 'echo'
    local reader = Reader:new()
    local child = run(cmd, {'foo'})
    child:pipe(reader)
    reader:on('data', function(data)
      store = data
    end)
    reader:once('end', function()
      assert(store == 'foo')
    end)
  end)

  test('Test for safeMerge: string insert', function()
    local a = {}
    local expected = {'string'}
    safeMerge(a, 'string')
    assert(a[1] == 'string')
  end)
  test('Test for safeMerge: merge', function()
    local expected = {a = 'string1', b = 'string2'}
    local a = {}
    a.a = 'string1'
    local b = {}
    b.b = 'string2'
    safeMerge(a, b)
    assert(a.a == 'string1')
    assert(a.b == 'string2')
  end)

  test('Test for safeMerge: nil', function()
    local a = {}
    local expected = {}
    safeMerge(a, nil)
    assert(not next(a))
  end)
end)
