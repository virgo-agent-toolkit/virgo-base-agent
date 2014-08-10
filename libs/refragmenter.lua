local stream = require('/base/modules/stream')

local Refragmenter = stream.Transform:extend()
function Refragmenter:initialize(options)
	options = options or {}
	stream.Transform.initialize(self, options)

	self.buff = ''
	self.sep = options.separator or '\n'
end

function Refragmenter:_write(data, encoding, callback)
	self.buff = self.buff .. data
	local p = self.buff:find(self.sep)
	while p do
		self:push(self.buff:sub(1, p - 1))
		self.buff = self.buff:sub(p + 1, -1)
		p = self.buff:find(self.sep)
	end
	callback()
end

return Refragmenter
