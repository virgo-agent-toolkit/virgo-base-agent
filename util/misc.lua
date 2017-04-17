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

local async = require('async')
local math = require('math')
local table = require('table')
local string = require('string')
local fs = require('fs')

--[[
Split an address.

address - Address in ip:port format.
return [ip, port]
]]--
local function splitAddress(address)
  -- TODO: Split on last colon (ipv6)
  local start, result, _
  start, _ = address:find(':')

  if not start then
    return nil
  end

  result = {}
  result[1] = address:sub(0, start - 1)
  result[2] = tonumber(address:sub(start + 1))
  return result
end

-- See Also: http://lua-users.org/wiki/SplitJoin
local function split(str, pattern)
  pattern = pattern or "[^%s]+"
  if pattern:len() == 0 then pattern = "[^%s]+" end
  local parts = {__index = table.insert}
  setmetatable(parts, parts)
  str:gsub(pattern, parts)
  setmetatable(parts, nil)
  parts.__index = nil
  return parts
end

local function tablePrint(tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    local sb = {}
    for key, value in pairs (tt) do
      table.insert(sb, string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        table.insert(sb, key .. " = {\n");
        table.insert(sb, tablePrint (value, indent + 2, done))
        table.insert(sb, string.rep (" ", indent)) -- indent it
        table.insert(sb, "}\n");
      elseif "number" == type(key) then
        table.insert(sb, string.format("\"%s\"\n", tostring(value)))
      else
        table.insert(sb, string.format(
        "%s = \"%s\"\n", tostring (key), tostring(value)))
      end
    end
    return table.concat(sb)
  else
    return tt .. "\n"
  end
end

local function toString(tbl)
  if  "nil"       == type( tbl ) then
    return tostring(nil)
  elseif  "table" == type( tbl ) then
    return tablePrint(tbl)
  elseif  "string" == type( tbl ) then
    return tbl
  else
    return tostring(tbl)
  end
end

local function calcJitter(n, jitter)
  return math.floor(n + (jitter * math.random()))
end

local function calcJitterMultiplier(n, multiplier)
  local sig = math.floor(math.log10(n)) - 1
  local jitter = multiplier * math.pow(10, sig)
  return math.floor(n + (jitter * math.random()))
end

local function randstr(length)
  local chars, r

  chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  r = {}

  for x=1, length, 1 do
    local ch = string.char(string.byte(chars, math.random(1, #chars)))
    table.insert(r, ch)
  end

  return table.concat(r, '')
end

-- merge tables
local function merge(...)
  local args = {...}
  local first = args[1] or {}
  for i,t in pairs(args) do
    if i ~= 1 and t then
      for k, v in pairs(t) do
        first[k] = v
      end
    end
  end

  return first
end

-- Return true if an item is in a table, false otherwise.
-- f - function which is called on every item and should return true if the item
-- matches, false otherwise
-- t - table
local function tableContains(f, t)
  for _, v in ipairs(t) do
    if f(v) then
      return true
    end
  end

  return false
end

local function trim(s)
  if not s then return end
  return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end

-- Return start index of last occurance of a pattern in a string
local function lastIndexOf(str, pat)
  local startIndex, _
  local lastIndex = -1

  while 1 do
    startIndex, _ = string.find(str, pat, lastIndex + 1)
    if not startIndex then
      break
    else
      lastIndex = startIndex
    end
  end

  if lastIndex == -1 then
    return nil
  end

  return lastIndex
end

local function fireOnce(callback)
  local called = false

  return function(...)
    if not called then
      called = true
      callback(unpack({...}))
    end
  end
end

local function nCallbacks(callback, count)
  local n, triggered = 0, false
  return function()
    if triggered then
      return
    end
    n = n + 1
    if count == n then
      triggered = true
      callback()
    end
  end
end

local function propagateEvents(fromClass, toClass, eventNames)
  for _, v in pairs(eventNames) do
    fromClass:on(v, function(...)
      toClass:emit(v, ...)
    end)
  end
end

local function copyFile(fromFile, toFile, callback)
  callback = fireOnce(callback)
  local writeStream = fs.createWriteStream(toFile)
  local readStream = fs.createReadStream(fromFile)
  readStream:on('error', callback)
  readStream:on('end', callback)
  writeStream:on('error', callback)
  writeStream:on('end', callback)
  readStream:pipe(writeStream)
end

local function copyFileAndRemove(fromFile, toFile, callback)
  async.series({
    function(callback)
      copyFile(fromFile, toFile, callback)
    end,
    function(callback)
      fs.unlink(fromFile, callback)
    end
  }, callback)
end

local function parseCSVLine (line,sep)
  local res = {}
  local pos = 1
  sep = sep or ','
  while true do
    local c = string.sub(line,pos,pos)
    if (c == "") then break end
    if (c == '"') then
      -- quoted value (ignore separator within)
      local txt = ""
      repeat
        local startp,endp = string.find(line,'^%b""',pos)
        txt = txt..string.sub(line,startp+1,endp-1)
        pos = endp + 1
        c = string.sub(line,pos,pos)
        if (c == '"') then txt = txt..'"' end
        -- check first char AFTER quoted string, if it is another
        -- quoted string without separator, then append it
        -- this is the way to "escape" the quote char in a quote. example:
        --   value1,"blub""blip""boing",value3  will result in blub"blip"boing  for the middle
      until (c ~= '"')
      table.insert(res,txt)
      assert(c == sep or c == "")
      pos = pos + 1
    else
      -- no quotes used, just look for the first separator
      local startp,endp = string.find(line,sep,pos)
      if (startp) then
        table.insert(res,string.sub(line,pos,startp-1))
        pos = endp + 1
      else
        -- no separator found -> use rest of string and terminate
        table.insert(res,string.sub(line,pos))
        break
      end
    end
  end
  return res
end


local function deepCopyTable(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[deepCopyTable(orig_key)] = deepCopyTable(orig_value)
    end
    setmetatable(copy, deepCopyTable(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

local tableToString

local function tableValueToStr( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type(v) and tableToString(v) or tostring(v)
  end
end

local function tableKeyToStr( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. tableValueToStr( k ) .. "]"
  end
end

tableToString = function(tbl, delim)
  local result, done = {}, {}
  local keys = {}

  delim = delim or ','

  for k, v in ipairs(tbl) do
    table.insert(result, tableValueToStr(v))
    done[ k ] = true
  end

  for k, v in pairs(tbl) do
    table.insert(keys, k)
  end

  table.sort(keys)

  for _, k in pairs(keys) do
    if not done[ k ] then
      table.insert(result, tableKeyToStr(k) .. "=" .. tableValueToStr(tbl[k]))
    end
  end
  return table.concat(result, delim)
end

--[[ A reliable childprocess spawn and retrieve data utility function ]]--
local function execFileToBuffers(command, args, options, callback)
  local child, stdout, stderr, exitCode

  stdout = {}
  stderr = {}

  child = childProcess.spawn(command, args, options)
  child.stdout:on('data', function (chunk)
    table.insert(stdout, chunk)
  end)
  child.stderr:on('data', function (chunk)
    table.insert(stderr, chunk)
  end)

  async.parallel({
    function(callback)
      child.stdout:on('end', callback)
    end,
    function(callback)
      child.stderr:on('end', callback)
    end,
    function(callback)
      local onExit
      function onExit(code)
        exitCode = code
        callback()
      end

      child:on('exit', onExit)
    end
  }, function(err)
    callback(err, exitCode, table.concat(stdout, ""), table.concat(stderr, ""))
  end)
end

--[[
-- readCast - A utility function to make it easier to read a file and cast values from it into a table
--  @param {string} filePath The file we want to read
--  @param {table} errTable A table to dump errors we encounter into
--  @param {table} outTable A table to dump objects generated from the casterfunc into
--  @param {function} casterFunc A function to call per line of our file, params are
 --   {iterator} iter An iterator that when called will retrieve the first word then the next space seperated value
 --   {table} obj An empty object into which you can insert worthwhile things, will be added into outTable at the end
 --   {string} line The line we are working with in its entirety
--  @param {function} callback Final callback function fired at end
--]]
local function readCast(filePath, errTable, outTable, casterFunc, callback)
  -- Sanity checks
  if (type(filePath) ~= 'string') then filePath = '' end
  if (type(errTable) ~= 'table') then errTable = {} end
  if (type(outTable) ~= 'table') then outTable = {} end
  if (type(casterFunc) ~= 'function') then function casterFunc(iter, obj, line) end end
  if (type(callback) ~= 'function') then function callback() end end

  local obj = {}
  fs.exists(filePath, function(err, file)
    if err then
      table.insert(errTable, string.format('File not found : { fs.exists erred: %s }', err))
      return callback()
    end
    if file then
      fs.readFile(filePath, function(err, data)

        if err then
          table.insert(errTable, string.format('File couldnt be read : { fs.readline erred: %s }', err))
          return callback()
        end

        for line in data:gmatch("[^\r\n]+") do
          local iscomment = string.match(line, '^#')
          local isblank = string.len(line:gsub("%s+", "")) <= 0

          if not iscomment and not isblank then
            -- split the line and assign key vals
            local iter = line:gmatch("%S+")
            casterFunc(iter, obj, line)
          end
        end

        -- Flatten single entry objects
        if #obj == 1 then obj = obj[1] end
        -- Dont insert empty objects into the outTable
        if next(obj) then table.insert(outTable, obj) end

        return callback()
      end)
    else
      table.insert(errTable, 'file not found')
      return callback()
    end

  end)
end

--[[
-- asyncSpawn - Utility function to easily spawn a lot of procs
--  @param {table} dataArr The list to iterate over
--  @param {function} spawnFunc A user defined function to call to get what command to spawn. Expects you to do 'return a, b'
--    @param {?string} datum The array element the asyncspawn utility is currently at
--    @return {string} cmd The shell command to run
--    @return {table} args A table of arguments to supply the shell cmd spawns
--  @param {function} successFunc A function to call if the spawn is succesful
--    @param {string} data The stdout data from the sub proc
--    @param {table} obj A (initially) empty table for you to push things into
--    @param {?string} datum The array element the asyncspawn utility is currently at
--    @param {number} exitcode The exitcode of the sub proc, 0 if alls good
--  @param {function} finaCb The final callback to return
--    @param {table} obj The table you've been entering data into via the successfunc
--    @param {table} errTable A table of any error information retrieved
--]]
local function asyncSpawn(dataArr, spawnFunc, successFunc, finalCb)
  -- Sanity checks
  if type(dataArr) ~= 'table' then
    if dataArr ~= nil then
      local obj = {}
      table.insert(obj, dataArr)
      dataArr = obj
      return
    end
    dataArr = {}
  end
  if type(spawnFunc) ~= 'function' then function spawnFunc(datum) return '', {} end end
  if type(successFunc) ~= 'function' then function successFunc(data, emptyObj, datum) end end
  if type(finalCb) ~= 'function' then function finalCb(obj, errdata) end end

  -- Asynchronous spawn cps & gather data
  local obj = {}
  local errTable = {}
  async.forEachLimit(dataArr, 5, function(datum, cb)
    local cmd, args = spawnFunc(datum)
    local function _successFunc(err, exitcode, data, stderr)
      if exitcode ~= 0 or err or stderr then errTable[cmd..args] = {} end
      if exitcode ~= 0 then table.insert(errTable[cmd..args], {exitcode = exitcode}) end
      if err then table.insert(errTable[cmd..args], {err = err}) end
      if stderr then table.insert(errTable[cmd..args], {stderr = stderr}) end

      successFunc(data, obj, datum, exitcode)
      return cb()
    end
    return execFileToBuffers(cmd, args, opts, _successFunc)
  end, function()
    return finalCb(obj, errTable)
  end)
end

--[[ Exports ]]--
exports.copyFile = copyFile
exports.calcJitter = calcJitter
exports.calcJitterMultiplier = calcJitterMultiplier
exports.copyFileAndRemove = copyFileAndRemove
exports.deepCopyTable = deepCopyTable
exports.tableToString = tableToString
exports.merge = merge
exports.splitAddress = splitAddress
exports.split = split
exports.toString = toString
exports.tableContains = tableContains
exports.trim = trim
exports.lastIndexOf = lastIndexOf
exports.fireOnce = fireOnce
exports.nCallbacks = nCallbacks
exports.propagateEvents = propagateEvents
exports.parseCSVLine = parseCSVLine
exports.randstr = randstr
exports.execFileToBuffers = execFileToBuffers
exports.readCast = readCast
exports.asyncSpawn = asyncSpawn
