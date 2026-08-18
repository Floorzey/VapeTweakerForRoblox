return function(ctx)
	local function category(cat)
		if type(cat) ~= 'string' then return nil end
		cat = cat:lower()
		if ctx.cats.names[cat] then return cat end
		for low, real in pairs(ctx.cats.names) do
			if real:lower() == cat then return low end
		end
	end

	function ctx:find(name, cat)
		return self.vapeapi:find(name, cat)
	end

	function ctx:drop(name)
		local data = self.mods[name]
		if not data then return false end
		if not self.patchsys:dropmod(data.obj) then return false end
		if not self.vapeapi:remove(name, data.obj) then return false end
		if self.config and type(self.config.forgetmodule) == 'function' then self.config:forgetmodule(data.obj) end
		self.mods[name] = nil
		for i = #self.modorder, 1, -1 do
			if self.modorder[i] == data then
				table.remove(self.modorder, i)
				break
			end
		end
		return true
	end

	function ctx:module(cat, def)
		cat = category(cat)
		if not cat then error('unsupported Vape category', 0) end
		if type(def) ~= 'table' then error('module definition must be a table', 0) end
		local name = def.name or def.Name
		if type(name) ~= 'string' or name == '' then error('module name is required', 0) end
		local load = self.loading or {}
		if load.category and load.category ~= cat then
			error('module category does not match its manifest', 0)
		end

		self.vapeapi:reindex()
		local live, _, kind = self.vapeapi:liveslot(name)
		if kind == 'category' then error('module name collides with a Vape category: '..name, 0) end
		local old = self.vapeapi:find(name)
		if live ~= nil and not old then error('Vape registry name is already in use: '..name, 0) end
		if old then
			if def.replace ~= true then error('Vape module already exists: '..name, 0) end
			if old.Enabled then error('an enabled Vape module cannot be replaced safely: '..name, 0) end
			local id = 'replace:'..tostring(load.path or 'runtime')..':'..name
			local patch = self:patch(name, id, cat)
			if not patch then error('module replacement could not start: '..name, 0) end
			local func = def.func or def.Function
			if func and not patch:set('Function', func) then
				error('Vape callback is unavailable for replacement: '..name, 0)
			end
			local tooltip = def.tooltip or def.Tooltip
			if tooltip ~= nil and not patch:set('Tooltip', tooltip) then
				error('Vape tooltip is unavailable for replacement: '..name, 0)
			end
			local extra = def.extratext or def.ExtraText
			if extra ~= nil then patch:set('ExtraText', extra) end
			return old
		end

		local spec = self.vapeapi:spec(def)
		spec.Name = name
		local func = def.func or def.Function or function() end
		spec.Function = function(on)
			if self.config then self.config:schedule() end
			return func(on)
		end
		local mod = self.vapeapi:create(cat, spec)
		local data = {
			name = name,
			category = cat,
			obj = mod,
			layer = load.layer or 'runtime',
			scope = load.scope or 'universal',
			path = load.path
		}
		self.mods[name] = data
		self.modorder[#self.modorder + 1] = data
		if self.config and self.state == 'loaded' then self.config:watchmodule(data) end
		return mod
	end

	function ctx:_mark()
		return {mods = #self.modorder, patches = #self.patchsys.order, clean = self.bin:mark()}
	end

	function ctx:_rollback(mark)
		local ok = self.patchsys:rollback(mark.patches)
		for i = #self.modorder, mark.mods + 1, -1 do
			local data = self.modorder[i]
			if self.vapeapi:remove(data.name, data.obj) then
				self.mods[data.name] = nil
				table.remove(self.modorder, i)
			else
				ok = false
				self.log:add('module_cleanup', data.path, 'failed to roll back '..data.name)
			end
		end
		ok = self.bin:rollback(mark.clean) and ok
		return ok
	end

	function ctx:modules()
		local out = {}
		for _, data in ipairs(self.modorder) do
			out[#out + 1] = {
				name = data.name,
				category = data.category,
				layer = data.layer,
				scope = data.scope,
				path = data.path,
				enabled = data.obj.Enabled == true
			}
		end
		return out
	end

	function ctx:patches()
		local out = {}
		for _, data in ipairs(self.patchsys.order) do
			out[#out + 1] = {
				id = data.id,
				name = data.name,
				category = data.category,
				layer = data.layer,
				scope = data.scope,
				path = data.path,
				enabled = data.enabled,
				operations = #data.ops,
				options = #data.options
			}
		end
		return out
	end

	function ctx:errors(kind)
		local out = self.log:list(kind)
		for _, item in ipairs(self.loader.errors or {}) do
			if not kind or item.kind == kind then out[#out + 1] = table.clone(item) end
		end
		return out
	end

	function ctx:status()
		return {
			name = self.name,
			version = self.version,
			build = self.loader.build,
			state = self.state,
			started = self.started,
			target = self.target and table.clone(self.target) or nil,
			layers = table.clone(self.layers),
			profile = self.profile and self.profile.name or 'default',
			config = self.config and self.config.paths and table.clone(self.config.paths) or {},
			cache = type(self.loader.cachestatus) == 'function'
				and self.loader:cachestatus() or table.clone(self.loader.stats),
			modules = #self.modorder,
			patches = #self.patchsys.order,
			errors = #self.log.history + #(self.loader.errors or {})
		}
	end

	function ctx:selfcheck()
		local cats = {}
		for _, cat in ipairs(self.cats.order) do
			cats[cat] = self.vapeapi:category(cat) ~= nil
		end
		return {
			vape = self.vape == self.vapeapi.object and self.vape.Loaded ~= nil,
			readiness = self.vapeapi.readiness,
			categories = cats,
			filesystem = table.clone(self.store.fs),
			profile = self.profile and self.profile.name or 'default',
			registry = type(self.vape.Modules) == 'table',
			patch_restore = type(self.patchsys.restore) == 'function',
			config = self.config and self.config:check() or false
		}
	end

	function ctx:unload(reason)
		if self.state == 'unloading' or self.state == 'unloaded' then return false end
		local previous = self.state
		self.state = 'unloading'
		local complete = true
		local function stage(kind, fn)
			local ok, val = pcall(fn)
			if not ok or val == false then
				complete = false
				self.log:add(kind, nil, ok and 'cleanup returned false' or val)
			end
		end
		if self.config and previous == 'loaded' then
			local ok, saved = pcall(self.config.save, self.config, true)
			if not ok or saved == false then
				self.savefailed = true
				self.log:add('config_write', nil, ok and 'cleanup save returned false' or saved)
			end
		end
		stage('cleanup', function() self.vapeapi:unhook() return true end)
		stage('patch_cleanup', function() return self.patchsys:restore() end)
		if self.config and self.config.unwatch then stage('cleanup', function() self.config:unwatch() return true end) end
		for i = #self.modorder, 1, -1 do
			local data = self.modorder[i]
			local ok, removed = pcall(self.vapeapi.remove, self.vapeapi, data.name, data.obj)
			if ok and removed then
				self.mods[data.name] = nil
				table.remove(self.modorder, i)
			else
				complete = false
				self.log:add('module_cleanup', data.path, ok and 'cleanup returned false' or removed)
			end
		end
		stage('cleanup', function() return self.bin:run() end)
		table.clear(self.events)
		self.reason = reason
		self.state = complete and 'unloaded' or 'unload_failed'
		local env = (getgenv and getgenv()) or _G
		if env.VapeTweaker == self and (complete or reason == 'reload' or reason == 'startup failure') then
			env.VapeTweaker = nil
		end
		return complete
	end
end
