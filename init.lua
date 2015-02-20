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

return function(options)
  assert(type(options) == "table", "options must be a table")
  assert(options.version, "version is missing")
  _G.virgo = {}
  _G.virgo.virgo_version = require('./package').version
  _G.virgo.bundle_version = _G.virgo.virgo_version
  _G.virgo.pkg_name = options.pkg_name
  _G.virgo_paths = {}
  _G.virgo_paths.VIRGO_PATH_PERSISTENT_DIR = options.paths.persistent_dir
  _G.virgo_paths.VIRGO_PATH_EXE_DIR = options.paths.exe_dir
  _G.virgo_paths.VIRGO_PATH_CONFIG_DIR = options.paths.config_dir
  _G.virgo_paths.VIRGO_PATH_LIBRARY_DIR = options.paths.library_dir
  _G.virgo_paths.VIRGO_PATH_RUNTIME_DIR = options.paths.runtime_dir
  _G.virgo_paths.get = function() end
end
