return function(ctx)
	local log = {history = {}, limit = 200}

	local function trim(msg)
		msg = tostring(msg or '')
		if #msg > 1200 and not ctx.cfg.debug then return msg:sub(1, 1200) end
		return msg
	end

	function log:add(kind, path, msg, fatal)
		local item = {
			time = os.clock(),
			kind = tostring(kind or 'runtime'),
			path = path and tostring(path) or nil,
			message = trim(msg),
			fatal = fatal == true
		}
		self.history[#self.history + 1] = item
		if #self.history > self.limit then table.remove(self.history, 1) end
		return item
	end

	function log:list(kind)
		if not kind then return table.clone(self.history) end
		local out = {}
		for _, item in ipairs(self.history) do
			if item.kind == kind then out[#out + 1] = item end
		end
		return out
	end

	ctx.log = log
end
