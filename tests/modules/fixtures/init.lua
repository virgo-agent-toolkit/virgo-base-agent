local bundle = require('luvi').bundle
local fs = require('fs')
local los = require('los')
local path = require('luvi').path
local string = require('string')

function fs.extname(filename)
  return filename:match('%.[^./]+$') or ''
end

function fs.basename(filename)
  return filename:match('[^/]+$'):sub(1, -#fs.extname(filename) - 1)
end

local function load_fixtures(dir, is_json)
  local files, filePath, fileData, finder, tbl

  tbl = {}

  -- Convert the \ to / so path.posix works
  if los.type() == 'win32' then
    dir = dir:gsub("\\", "/")
  end
  files = bundle.readdir(dir)
  for _, v in ipairs(files) do
    filePath = path.join(dir, v)
    fileData = bundle.readfile(filePath)
    if fileData then
      if is_json then fileData = fileData:gsub("\n", " ") end
      tbl[fs.basename(filePath)] = fileData
    end
  end
  return tbl
end

local base = path.join('/', 'modules', 'fixtures', 'protocol')

for k, v in pairs(load_fixtures(base, true)) do
  exports[k] = v
end

exports['invalid-version'] = load_fixtures(path.join(base, 'invalid-version'), true)
exports['invalid-process-version'] = load_fixtures(path.join(base, 'invalid-process-version'), true)
exports['invalid-bundle-version'] = load_fixtures(path.join(base, 'invalid-bundle-version'), true)
