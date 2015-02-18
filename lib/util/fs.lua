local async = require('async')

local fs = require('fs')
local os = require('os')
local path = require('path')
local table = require('table')

local exports = {}

-- TODO: move to utils
local function reverse ( t )
  local tout = {}

  for i = #t, 1, -1 do
    table.insert(tout, t[i])
  end

  return tout
end

local function mkdirp(lpath, mode, callback)
  lpath = path.normalize(lpath)
  local tocreate = {lpath}
  local current = lpath
  local last

  while 1 do
    last = current
    current = path.dirname(current)
    if current == "." then
      break
    end

    table.insert(tocreate, current)

    if last == current then
      break
    end
    if current == nil then
      break
    end
  end

  tocreate = reverse(tocreate)
  if os.type() == "win32" then
    -- Do not try to create a Windows Drive
    if tocreate[1]:match("^[%a]:$") then
      table.remove(tocreate, 1)
    end
  end
  async.forEachSeries(tocreate, function (dir, callback)
    fs.mkdir(dir, mode, function(err)
        if not err then
          callback()
          return
        end

        if err.code == "EEXIST" then
          callback()
          return
        end

        fs.stat(dir, function(err2, stats)
          if err2 then
            -- Okay, so the path didn't exist, but our first mkdir failed, so return the original error.
            callback(err)
            return
          end
          if stats.is_directory then
            callback()
            return
          end
          callback(err)
          return
        end)
      end)
  end, callback)
end

exports.mkdirp = mkdirp
