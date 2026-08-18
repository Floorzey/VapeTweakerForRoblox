return function(ctx)
	local bin = {items = {}, dead = false}

	local function dispose(obj)
		local kind = typeof and typeof(obj) or type(obj)
		if kind == 'RBXScriptConnection' then
			return obj:Disconnect()
		elseif kind == 'Instance' then
			return obj:Destroy()
		elseif type(obj) == 'function' then
			return obj()
		elseif type(obj) == 'table' or type(obj) == 'userdata' then
			for _, name in ipairs({'Disconnect', 'Destroy', 'Clean', 'Remove'}) do
				local ok, method = pcall(function() return obj[name] end)
				if ok and type(method) == 'function' then
					return method(obj)
				end
			end
		end
		return true
	end

	function bin:add(obj)
		if obj == nil then return nil end
		if self.dead then
			local ok, done = pcall(dispose, obj)
			if not ok or done == false then
				ctx.log:add('cleanup', nil, ok and 'cleanup returned false' or done)
				self.items[#self.items + 1] = obj
			end
			return obj
		end
		self.items[#self.items + 1] = obj
		return obj
	end

	function bin:run()
		self.dead = true
		local items = self.items
		self.items = {}
		for i = #items, 1, -1 do
			local ok, done = pcall(dispose, items[i])
			if not ok or done == false then
				ctx.log:add('cleanup', nil, ok and 'cleanup returned false' or done)
				self.items[#self.items + 1] = items[i]
			end
		end
		return #self.items == 0
	end

	function bin:mark()
		return #self.items
	end

	function bin:rollback(mark)
		if self.dead then return false end
		local items = {}
		for i = #self.items, mark + 1, -1 do
			items[#items + 1] = table.remove(self.items, i)
		end
		local complete = true
		for _, obj in ipairs(items) do
			local ok, done = pcall(dispose, obj)
			if not ok or done == false then
				complete = false
				ctx.log:add('cleanup', nil, ok and 'cleanup returned false' or done)
				self.items[#self.items + 1] = obj
			end
		end
		return complete
	end

	ctx.bin = bin
	function ctx:clean(obj)
		return self.bin:add(obj)
	end
end
