-- this file is used to provide an entry point compliant with current
-- rackspace-monitoring-agent binary that runs luvit-tape tests

local tap = require("tap")
local uv = require('uv')

local function run()
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
end


return require('luvit')(function(...)
  local options = {}
  options.version = require('./package').version
  options.pkg_name = "rackspace-monitoring-agent"
  options.paths = {}
  options.paths.persistent_dir = "/var/lib/rackspace-monitoring-agent"
  options.paths.exe_dir = "/var/lib/rackspace-monitoring-agent/exe"
  options.paths.config_dir = "/etc"
  options.paths.library_dir = "/usr/lib/rackspace-monitoring-agent"
  options.paths.runtime_dir = "/var/run/rackspace-monitoring-agent"
  options.paths.current_exe = args[0]
  require('..')(options, run)
end)
