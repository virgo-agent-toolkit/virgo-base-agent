local utils = require('utils')
local uv = require('uv')

local function init()
  -- Make print go through libuv for windows colors
  _G.print = utils.print
  -- Register global 'p' for easy pretty printing
  _G.p = utils.prettyPrint
  _G.process = require('process').globalProcess()
end

local function run()

  -- Start the event loop
  uv.run()
  require('hooks'):emit('process.exit')
  uv.run()

  -- When the loop exits, close all uv handles.
  uv.walk(uv.close)
  uv.run()
end

exports.init = init
exports.run = run
