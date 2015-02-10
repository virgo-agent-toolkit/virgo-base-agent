-- this file is used to provide an entry point compliant with current
-- rackspace-monitoring-agent binary that runs luvit-tape tests

local tap = require("tap")
local uv = require('uv')

local req = uv.fs_scandir("tests")

repeat
  local ent = uv.fs_scandir_next(req)

  if not ent then
    -- run the tests!
    tap(true)
  end
  local match = string.match(ent.name, "^test%-(.*).lua$")
  if match then
    local path = "./test-" .. match
    tap(match)
    require(path)
  end
until not ent

