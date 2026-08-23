return function(ctx)
	local sys = {
		states = setmetatable({}, {__mode = 'k'}),
		map = {},
		order = {}
	}

	local function statefor(obj, prop)
		local props = sys.states[obj]
		if not props then
			props = {}
			sys.states[obj] = props
		end
		if props[prop] then return props[prop] end
		local ok, original = ctx.vapeapi:getprop(obj, prop)
		if not ok then return nil end
		if ctx.config and type(ctx.config.unwrapped) == 'function' then
			original = ctx.config:unwrapped(obj, prop, original)
		end
		local state = {obj = obj, prop = prop, original = original, value = original, ops = {}}
		props[prop] = state
		return state
	end

	local function recompute(state)
		local val = state.original
		for _, op in ipairs(state.ops) do
			if op.patch.enabled then
				if op.kind == 'set' then
					val = op.value
				else
					local old = val
					val = function(...)
						return op.value(old, ...)
					end
				end
			end
		end
		state.value = val
		if sys.suspended then return true end
		if not ctx.vapeapi:setprop(state.obj, state.prop, val) then return false end
		if ctx.config and type(ctx.config.rewatch) == 'function' then ctx.config:rewatch(state.obj, state.prop) end
		return true
	end

	local function optionrecord(obj)
		for _, data in ipairs(ctx.patchopts) do
			if data.obj == obj then return data end
		end
	end

	local function managed(patch, obj, name, created, previous, snapshot)
		local found = optionrecord(obj)
		if found then
			local data = found
				if not data.owners[patch] then
					data.owners[patch] = true
					patch.options[#patch.options + 1] = data
				end
				return data
		end
		local data = {
			patch = patch,
			mod = patch.mod,
			name = name,
			obj = obj,
			created = created == true,
			previous = previous,
			persist = type(obj.Save) == 'function' and type(obj.Load) == 'function',
			owners = {[patch] = true}
		}
		if not data.created and data.persist and type(ctx.vapeapi.snapshotoption) == 'function' then
			local val, ok
			if snapshot then val, ok = snapshot.value, true else val, ok = ctx.vapeapi:snapshotoption(obj) end
			if not ok then return nil end
			data.native = val
			data.nativeknown = true
		end
		ctx.patchopts[#ctx.patchopts + 1] = data
		patch.options[#patch.options + 1] = data
		return data
	end

	local function optionname(mod, obj, wanted)
		if type(mod.Options) ~= 'table' then return nil end
		if wanted and mod.Options[wanted] == obj then return wanted end
		for name, val in pairs(mod.Options) do
			if val == obj then return name end
		end
	end

	local patchmeta = {}
	patchmeta.__index = patchmeta

	function patchmeta:_touch(obj, prop, kind, val)
		obj = obj or self.mod
		local name = obj ~= self.mod and optionname(self.mod, obj)
		local snapshot
		if name and not optionrecord(obj) and type(obj.Save) == 'function' and type(obj.Load) == 'function' then
			local native, ok = ctx.vapeapi:snapshotoption(obj)
			if not ok then return false end
			snapshot = {value = native}
		end
		local state = statefor(obj, prop)
		if not state then return false end
		if kind == 'wrap' and type(state.value) ~= 'function' then
			if #state.ops == 0 then
				local props = sys.states[obj]
				if props then
					props[prop] = nil
					if next(props) == nil then sys.states[obj] = nil end
				end
			end
			return false
		end
		local op = {patch = self, kind = kind, value = val}
		state.ops[#state.ops + 1] = op
		self.ops[#self.ops + 1] = {state = state, op = op}
		if not recompute(state) then
			table.remove(state.ops)
			table.remove(self.ops)
			if #state.ops == 0 then
				state.value = state.original
				local props = sys.states[obj]
				if props then
					props[prop] = nil
					if next(props) == nil then sys.states[obj] = nil end
				end
			else
				recompute(state)
			end
			return false
		end
		if name and not managed(self, obj, name, false, nil, snapshot) then
			for i = #state.ops, 1, -1 do
				if state.ops[i] == op then table.remove(state.ops, i) break end
			end
			table.remove(self.ops)
			recompute(state)
			return false
		end

		return true
	end

	function patchmeta:set(prop, val, obj)
		if type(prop) ~= 'string' or prop == '' then return false end
		return self:_touch(obj, prop, 'set', val)
	end

	function patchmeta:wrap(prop, fn, obj)
		if type(prop) ~= 'string' or type(fn) ~= 'function' then return false end
		return self:_touch(obj, prop, 'wrap', fn)
	end

	function patchmeta:observe(fn)
		if type(fn) ~= 'function' then return false end
		return self:wrap('Toggle', function(old, mod, ...)
			local before = mod.Enabled
			local out = table.pack(old(mod, ...))
			fn(mod.Enabled, before, mod)
			return table.unpack(out, 1, out.n)
		end)
	end

	function patchmeta:manage(opt, name)
		name = optionname(self.mod, opt, name)
		if not name then return nil end
		if not managed(self, opt, name, false) then return nil end
		if ctx.config and ctx.state == 'loaded' and type(ctx.config.watchoption) == 'function' then
			ctx.config:watchoption(opt)
		end
		return opt
	end

	function patchmeta:value(opt, data)
		if type(opt) ~= 'table' or type(data) ~= 'table' then return false end
		local name = optionname(self.mod, opt)
		if not name then return false end
		return self:_touch(opt, '@value', 'set', data)
	end

	function patchmeta:option(kind, def)
		if type(def) ~= 'table' or type(def.name) ~= 'string' or def.name == '' then return nil end
		if type(self.mod.Options) ~= 'table' then return nil end
		local keys = type(ctx.vapeapi.optionkeys) == 'function' and ctx.vapeapi:optionkeys(kind, def) or {def.name}
		for _, name in ipairs(keys) do
			if self.mod.Options[name] ~= nil then return nil end
		end

		local before = {}
		for name, obj in pairs(self.mod.Options) do before[name] = obj end
		local out = table.pack(pcall(ctx.vapeapi.createoption, ctx.vapeapi, self.mod, kind, def))
		local opt, msg = out[2], out[3]
		for name, obj in pairs(self.mod.Options) do
			if before[name] ~= obj then managed(self, obj, name, true, before[name]) end
		end
		if not out[1] then error(out[2], 0) end
		if opt == nil and msg then
			ctx.log:add('patch', self.path, msg)
			return nil
		end
		if ctx.config and ctx.state == 'loaded' and type(ctx.config.watchoption) == 'function' then
			for _, data in ipairs(self.options) do ctx.config:watchoption(data.obj) end
		end
		return opt or self.mod.Options[keys[1]]
	end

	function patchmeta:setenabled(on, quiet)
		on = on == true
		if self.enabled == on then return false end
		local previous = self.enabled
		self.enabled = on
		local seen = {}
		local ok = true
		for _, data in ipairs(self.ops) do
			if not seen[data.state] then
				seen[data.state] = true
				if not recompute(data.state) then ok = false break end
			end
		end
		if not ok then
			self.enabled = previous
			for state in pairs(seen) do recompute(state) end
			ctx.log:add('patch', self.path, 'patch state change could not be applied')
			return false
		end
		if not quiet and ctx.config then ctx.config:schedule() end
		return true
	end

	function patchmeta:enable()
		return self:setenabled(true)
	end

	function patchmeta:disable()
		return self:setenabled(false)
	end

	local function removepatch(patch)
		patch.enabled = false
		local ok = true
		local touched = {}
		for i = #patch.ops, 1, -1 do
			local data = patch.ops[i]
			for n = #data.state.ops, 1, -1 do
				if data.state.ops[n] == data.op then
					table.remove(data.state.ops, n)
					break
				end
			end
			touched[data.state] = true
		end
		for state in pairs(touched) do
			if not recompute(state) then
				ok = false
				ctx.log:add('patch_cleanup', patch.path, 'failed to restore '..tostring(state.prop))
			end
		end
		for i = #patch.options, 1, -1 do
			local data = patch.options[i]
			data.owners[patch] = nil
			if next(data.owners) == nil then
				local removed = true
				if data.created then
					removed = ctx.vapeapi:removeoption(data.mod, data.name, data.obj)
					if removed and data.previous ~= nil and data.mod.Options[data.name] == nil then
						data.mod.Options[data.name] = data.previous
					end
				elseif data.native ~= nil then
					removed = ctx.vapeapi:loadoption(data.obj, data.native)
				end
				ok = removed and ok
				if removed then
					local owner = ctx.mods[data.mod.Name]
					if ctx.config and type(ctx.config.forgetobj) == 'function'
						and (data.created or not owner or owner.obj ~= data.mod) then
						ctx.config:forgetobj(data.obj)
					end
					for n = #ctx.patchopts, 1, -1 do
						if ctx.patchopts[n] == data then table.remove(ctx.patchopts, n) end
					end
				end
			end
		end
		if ok then
			sys.map[patch.id] = nil
			for i = #sys.order, 1, -1 do
				if sys.order[i] == patch then table.remove(sys.order, i) end
			end
		else
			patch.cleanup = false
		end
		return ok
	end

	function sys:rollback(mark)
		local ok = true
		for i = #self.order, mark + 1, -1 do ok = removepatch(self.order[i]) and ok end
		return ok
	end

	function sys:dropmod(mod)
		local ok = true
		for i = #self.order, 1, -1 do
			if self.order[i].mod == mod then ok = removepatch(self.order[i]) and ok end
		end
		return ok
	end

	function sys:restore()
		local ok = true
		for i = #self.order, 1, -1 do ok = removepatch(self.order[i]) and ok end
		for _, props in pairs(self.states) do
			for _, state in pairs(props) do
				if not ctx.vapeapi:setprop(state.obj, state.prop, state.original) then ok = false end
			end
		end
		if ok then table.clear(self.states) end
		return ok
	end

	function sys:suspend()
		self.suspenddepth = (self.suspenddepth or 0) + 1
		if self.suspenddepth > 1 then return self.suspendok ~= false end
		local ok = true
		for _, props in pairs(self.states) do
			for _, state in pairs(props) do
				if not ctx.vapeapi:setprop(state.obj, state.prop, state.original) then ok = false end
				if ctx.config and type(ctx.config.rewatch) == 'function' then ctx.config:rewatch(state.obj, state.prop) end
			end
		end
		self.suspended = true
		self.suspendok = ok
		return ok
	end

	function sys:resume(rebase)
		if not self.suspended then return true end
		self.rebase = self.rebase or rebase == true
		self.suspenddepth = math.max((self.suspenddepth or 1) - 1, 0)
		if self.suspenddepth > 0 then return true end
		rebase = self.rebase
		self.rebase = nil
		self.suspended = false
		self.suspendok = nil
		local ok = true
		for _, props in pairs(self.states) do
			for _, state in pairs(props) do
				if rebase then
					local got, val = ctx.vapeapi:getprop(state.obj, state.prop)
					if got then
						if ctx.config and type(ctx.config.unwrapped) == 'function' then
							val = ctx.config:unwrapped(state.obj, state.prop, val)
						end
						state.original = val
					else ok = false end
				end
				if not recompute(state) then ok = false end
			end
		end
		return ok
	end

	function sys:valuepatched(obj)
		local props = self.states[obj]
		if not props then return false end
		for prop, state in pairs(props) do
			if prop == '@value' then
				for _, op in ipairs(state.ops) do
					if op.patch.enabled then return true end
				end
			end
		end
		return false
	end

	function sys:original(obj, prop, val)
		local state = self.states[obj] and self.states[obj][prop]
		if state and (val == state.value or val == state.original) then return state.original end
		return val
	end

	function ctx:patch(name, id, cat)
		if type(name) ~= 'string' or name == '' or type(id) ~= 'string' or id == '' then return nil end
		if sys.map[id] then
			local first = sys.map[id].path or 'runtime'
			error('duplicate patch id '..id..' (first declared by '..first..')', 0)
		end
		local mod = self.vapeapi:find(name, cat)
		if not mod then
			if self.loading and self.loading.required then error('required patch target missing: '..name, 0) end
			return nil
		end
		local load = self.loading or {}
		local patch = setmetatable({
			id = id,
			name = name,
			category = cat,
			mod = mod,
			enabled = true,
			ops = {},
			options = {},
			layer = load.layer or 'runtime',
			scope = load.scope or 'universal',
			path = load.path
		}, patchmeta)
		sys.map[id] = patch
		sys.order[#sys.order + 1] = patch
		return patch
	end

	ctx.patchsys = sys
end
