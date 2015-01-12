local logging = require('rphillips/logging')


--[[
Create a new logger which is already bound with a message prefix.

prefix - Message prefix.
return New logging function.
--]]
local function makeLogger(prefix)
  if not prefix then
    prefix = ''
  end

  return function(level, message)
    return logging.log(level, prefix  .. ' -> ' .. message)
  end
end

exports.makeLogger = makeLogger
