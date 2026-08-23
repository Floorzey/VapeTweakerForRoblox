return function(ctx)
	local prof = {name = 'default', dir = 'default'}

	local function canonical(name)
		if type(name) ~= 'string' then return nil end
		name = name:gsub('^%s+', ''):gsub('%s+$', '')
		if name == '' or name == '.' or name == '..' or #name > 64
			or name:find('[/\\:%z\1-\31]') then return nil end
		return name
	end

	local function clean(name)
		local out = name:gsub('[^%w%._ %-]', '_')
		if name == 'default' then return name end
		local hash = 0
		for i = 1, #name do hash = (hash * 33 + name:byte(i)) % 4294967296 end
		return out:sub(1, 54)..'-'..string.format('%08x', hash)
	end

	function prof:set(name)
		self.name = canonical(name) or 'default'
		self.dir = clean(self.name)
		ctx.store:mkdir('configs/profiles/'..self.dir)
		if ctx.config then ctx.config:setpaths() end
		return self.name
	end

	function prof:switch(name, saved)
		name = canonical(name)
		if not name then return false end
		if name == self.name then return true end
		if ctx.config and not saved and not ctx.config:save(true) then return false end
		local oldname, olddir = self.name, self.dir
		self:set(name)
		if ctx.config then
			ctx.config:load()
			if not ctx.config:restore() or not ctx.config:index() then
				self.name, self.dir = oldname, olddir
				ctx.config:setpaths()
				ctx.config:load()
				if not ctx.config:restore() then ctx.log:add('profile', oldname, 'profile rollback failed') end
				ctx.config:index()
				return false
			end
		end
		return true
	end

	function prof:select(name)
		name = canonical(name)
		if not name then return false end
		local vape = ctx.vape
		if ctx.vapeapi.realprofile and type(vape.Save) == 'function' and type(vape.Load) == 'function' then
			local ok, msg = pcall(function()
				vape:Save(name)
				vape:Load(true)
			end)
			if not ok then
				ctx.log:add('profile', name, msg)
				return false
			end
			return self.name == name
		end
		return self:switch(name)
	end

	prof:set(ctx.vapeapi:profile())
	ctx.profile = prof
	function ctx:setprofile(name)
		return self.profile:select(name)
	end
end
