return function(ctx)
	local scopes = {'universal', 'game', 'build', 'place'}
	local rank = {universal = 1, game = 2, build = 3, place = 4}
	local config = {
		version = 1,
		paths = {},
		data = {modules = {}, patches = {}},
		layers = {},
		memory = {},
		bad = {},
		watchers = {},
		watched = setmetatable({}, {__mode = 'k'}),
		ticket = 0,
		scheduled = false,
		restoring = false
	}

	local function safe(val, seen, depth)
		local kind = type(val)
		if kind == 'nil' or kind == 'boolean' or kind == 'string' then return val end
		if kind == 'number' then
			if val ~= val or val == math.huge or val == -math.huge then return nil end
			return val
		end
		if kind ~= 'table' or depth >= 12 or seen[val] then return nil end
		seen[val] = true
		local out = {}
		for key, item in pairs(val) do
			if type(key) == 'string' or type(key) == 'number' then
				local clean = safe(item, seen, depth + 1)
				if clean ~= nil then out[key] = clean end
			end
		end
		seen[val] = nil
		return out
	end

	local function clean(val)
		return safe(val, {}, 0)
	end

	local function equal(a, b, seen)
		if type(a) ~= type(b) then return false end
		if type(a) ~= 'table' then return a == b end
		seen = seen or {}
		if seen[a] == b then return true end
		seen[a] = b
		for key, val in pairs(a) do if not equal(val, b[key], seen) then return false end end
		for key in pairs(b) do if a[key] == nil then return false end end
		return true
	end

	local function validrecord(item, module)
		if type(item) ~= 'table' then return false end
		if item.enabled ~= nil and type(item.enabled) ~= 'boolean' then return false end
		if item.options ~= nil and type(item.options) ~= 'table' then return false end
		if module and item.category ~= nil and type(item.category) ~= 'string' then return false end
		if module and item.bind ~= nil and type(item.bind) ~= 'table' and type(item.bind) ~= 'string' then
			return false
		end
		return true
	end

	local function valid(data)
		if type(data) ~= 'table' or data.version ~= nil and data.version ~= 1 then return false end
		for key, module in pairs({modules = true, patches = false}) do
			local list = data[key]
			if list ~= nil and type(list) ~= 'table' then return false end
			for name, item in pairs(list or {}) do
				if type(name) ~= 'string' or not validrecord(item, module) then return false end
			end
		end
		return true
	end

	local function optiondata(list)
		local out = {}
		for _, entry in ipairs(list) do
			local opt = entry.obj or entry
			if type(opt) == 'table' and type(opt.Save) == 'function' then
				local ok, msg = pcall(opt.Save, opt, out)
				if not ok then
					ctx.log:add('config_serialize', entry.name, msg)
					return nil, false
				end
			end
		end
		return clean(out) or {}, true
	end

	local function moduleoptions(mod)
		local list = {}
		for name, opt in pairs(mod.Options or {}) do list[#list + 1] = {name = name, obj = opt} end
		return optiondata(list)
	end

	local function moduledata(item)
		local options, ok = moduleoptions(item.obj)
		if not ok then return nil, false end
		return {
			category = item.category,
			enabled = item.obj.Enabled == true,
			bind = clean(ctx.vapeapi:savebind(item.obj)),
			options = options
		}, true
	end

	local function patchdata(patch)
		local options, ok = optiondata(patch.options)
		if not ok then return nil, false end
		return {enabled = patch.enabled, options = options}, true
	end

	local function mergeoptions(dst, src)
		dst = type(dst) == 'table' and dst or {}
		for name, val in pairs(src) do dst[name] = clean(val) end
		return dst
	end

	local function mergeitem(dst, src, module)
		dst = type(dst) == 'table' and dst or {}
		if src.enabled ~= nil then dst.enabled = src.enabled end
		if module and src.category ~= nil then dst.category = src.category end
		if module and src.bind ~= nil then dst.bind = clean(src.bind) end
		if src.options ~= nil then dst.options = mergeoptions(dst.options, src.options) end
		return dst
	end

	local function merge(dst, src)
		for name, item in pairs(src.modules or {}) do
			dst.modules[name] = mergeitem(dst.modules[name], item, true)
		end
		for id, item in pairs(src.patches or {}) do
			dst.patches[id] = mergeitem(dst.patches[id], item, false)
		end
		return dst
	end

	function config:setpaths()
		local base = 'configs/profiles/'..ctx.profile.dir..'/'
		local target = ctx.target
		self.paths = {
			universal = base..'universal.json',
			game = base..'game-'..tostring(target.gameid)..'.json',
			build = base..'build-'..tostring(target.buildid)..'.json',
			place = base..'place-'..tostring(target.placeid)..'.json'
		}
		self.legacy = target.gameid ~= target.placeid and {
			game = base..tostring(target.gameid)..'.json',
			place = base..tostring(target.placeid)..'.json'
		} or {}
	end

	local function fieldowner(config, key, name, field, declared)
		for i = #scopes, 1, -1 do
			local scope = scopes[i]
			local layer = config.layers[scope]
			local item = layer and layer[key] and layer[key][name]
			if item and item[field] ~= nil then return scope end
		end
		return rank[declared] and declared or 'universal'
	end

	local function optionowner(config, key, name, option, declared)
		for i = #scopes, 1, -1 do
			local scope = scopes[i]
			local layer = config.layers[scope]
			local item = layer and layer[key] and layer[key][name]
			local options = item and item.options
			if type(options) == 'table' then
				if options[option] ~= nil then return scope end
			end
		end
		return rank[declared] and declared or 'universal'
	end

	local function record(data, key, name)
		data[key][name] = data[key][name] or {}
		return data[key][name]
	end

	function config:collect(scope)
		local prior = clean(self.layers[scope]) or {}
		local data = {
			version = self.version,
			profile = ctx.profile.name,
			target = clean(ctx.target),
			modules = type(prior.modules) == 'table' and prior.modules or {},
			patches = type(prior.patches) == 'table' and prior.patches or {}
		}
		for name, item in pairs(ctx.mods) do
			local current, ok = moduledata(item)
			if not ok then return nil, false end
			for _, field in ipairs({'category', 'enabled', 'bind'}) do
				if current[field] ~= nil and fieldowner(self, 'modules', name, field, item.scope) == scope then
					record(data, 'modules', name)[field] = clean(current[field])
				end
			end
			for option, val in pairs(current.options) do
				if optionowner(self, 'modules', name, option, item.scope) == scope then
					local saved = record(data, 'modules', name)
					saved.options = type(saved.options) == 'table' and saved.options or {}
					saved.options[option] = clean(val)
				end
			end
		end
		for _, patch in ipairs(ctx.patchsys.order) do
			local current, ok = patchdata(patch)
			if not ok then return nil, false end
			if fieldowner(self, 'patches', patch.id, 'enabled', patch.scope) == scope then
				record(data, 'patches', patch.id).enabled = current.enabled
			end
			for option, val in pairs(current.options) do
				if optionowner(self, 'patches', patch.id, option, patch.scope) == scope then
					local saved = record(data, 'patches', patch.id)
					saved.options = type(saved.options) == 'table' and saved.options or {}
					saved.options[option] = clean(val)
				end
			end
		end
		return data, true
	end

	local function rawvalid(path)
		local raw = ctx.store:read(path)
		if not raw then return nil, nil end
		local data = ctx.store:decode(raw, path)
		if valid(data) then return data, raw end
		return nil, raw
	end

	local function backpath(path)
		return type(ctx.store.backup) == 'function' and ctx.store:backup(path) or path..'.bak'
	end

	local function temppath(path)
		return type(ctx.store.temp) == 'function' and ctx.store:temp(path) or path..'.tmp'
	end

	function config:read(path)
		local data, raw = rawvalid(path)
		if data then
			self.bad[path] = nil
			return data
		end
		if raw then self.bad[path] = true end
		local backup = rawvalid(backpath(path))
		if backup then return backup end
		local legacy = rawvalid(path..'.bak')
		if legacy then return legacy end
	end

	function config:atomic(path, data)
		local raw = ctx.store:encode(data, path)
		if not raw then return false end
		local olddata, oldraw = rawvalid(path)
		if olddata and equal(olddata, data) or oldraw == raw then
			self.bad[path] = nil
			return true
		end
		local backupfile = backpath(path)
		local backup, backupraw = rawvalid(backupfile)
		if not backup then backup, backupraw = rawvalid(path..'.bak') end
		if oldraw and not olddata and not backup then
			self.bad[path] = true
			ctx.log:add('config_write', path, 'malformed config preserved')
			return false
		end

		local tmp = temppath(path)
		if not ctx.store:write(tmp, raw) then return false end
		local function discard()
			ctx.store:remove(tmp)
			return false
		end
		local candidate = rawvalid(tmp)
		if not candidate then return discard() end
		if olddata then
			if not ctx.store:write(backupfile, oldraw) then return discard() end
			local checked = rawvalid(backupfile)
			if not checked then return discard() end
			backup, backupraw = olddata, oldraw
		end
		if not ctx.store:write(path, raw) then return discard() end
		local final = rawvalid(path)
		if not final then
			if backup and backupraw then ctx.store:write(path, backupraw) end
			return discard()
		end
		ctx.store:remove(tmp)
		self.bad[path] = nil
		return true
	end

	function config:save(force)
		if self.restoring then return true, false end
		self.ticket = self.ticket + 1
		local all = true
		local wrote = false
		for _, scope in ipairs(scopes) do
			local data, ok = self:collect(scope)
			if not ok then
				all = false
			else
				local useful = next(data.modules) ~= nil or next(data.patches) ~= nil
					or self.layers[scope] ~= nil or ctx.store:read(self.paths[scope]) ~= nil
				if useful then
					self.layers[scope] = data
					if ctx.store.fs.write then
						local saved = self:atomic(self.paths[scope], data)
						all = saved and all
						wrote = saved or wrote
					end
				end
			end
		end
		self.memory[ctx.profile.dir] = clean(self.layers) or {}
		if force and not self:index() then all = false end
		return all, wrote
	end

	function config:schedule()
		if self.restoring or ctx.state ~= 'loaded' then return end
		self.ticket = self.ticket + 1
		if self.scheduled then return end
		self.scheduled = true
		task.spawn(function()
			local ticket
			repeat
				ticket = self.ticket
				task.wait(ctx.cfg.debounce)
			until ticket == self.ticket or ctx.state ~= 'loaded'
			self.scheduled = false
			if ctx.state == 'loaded' then self:save(false) end
		end)
	end

	function config:load()
		self.layers = {}
		local memory = self.memory[ctx.profile.dir]
		for _, scope in ipairs(scopes) do
			local data = memory and clean(memory[scope]) or self:read(self.paths[scope])
			if not data and self.legacy[scope] then
				data = self:read(self.legacy[scope])
				if data and ctx.store.fs.write then self:atomic(self.paths[scope], data) end
			end
			if data then self.layers[scope] = data end
		end
		self.data = clean(self.baseline) or {modules = {}, patches = {}}
		self.data.modules = self.data.modules or {}
		self.data.patches = self.data.patches or {}
		for _, scope in ipairs(scopes) do
			if self.layers[scope] then merge(self.data, self.layers[scope]) end
		end
		return self.data
	end

	local function loadoptions(mod, saved, allowed)
		if type(saved) ~= 'table' or type(mod.Options) ~= 'table' then return true end
		local complete = true
		for name, val in pairs(saved) do
			local opt = mod.Options[name]
			if opt and type(opt.Load) == 'function' and (not allowed or allowed[opt]) then
				local ok, result = pcall(opt.Load, opt, clean(val))
				if not ok or result == false then
					complete = false
					ctx.log:add('config_restore', name, ok and 'option load returned false' or result)
				end
			end
		end
		return complete
	end

	function config:restore()
		local previous = self.restoring
		self.restoring = true
		local complete = true
		local function fail(name, msg)
			complete = false
			ctx.log:add('config_restore', name, msg)
		end
		local ok, msg = xpcall(function()
			for _, item in ipairs(ctx.modorder) do
				if item.obj.Enabled and type(item.obj.Toggle) == 'function' then
					local toggled, err = pcall(item.obj.Toggle, item.obj, true)
					if not toggled or item.obj.Enabled then fail(item.name, toggled and 'module stayed enabled' or err) end
				end
			end
			for _, patch in ipairs(ctx.patchsys.order) do
				if patch.enabled and not patch:setenabled(false, true) then fail(patch.id, 'patch could not be disabled') end
			end
			for name, saved in pairs(self.data.modules or {}) do
				local item = ctx.mods[name]
				if item and not loadoptions(item.obj, saved.options) then complete = false end
			end
			for _, patch in ipairs(ctx.patchsys.order) do
				local saved = self.data.patches and self.data.patches[patch.id]
				if saved then
					local allowed = {}
					for _, entry in ipairs(patch.options) do allowed[entry.obj] = true end
					if not loadoptions(patch.mod, saved.options, allowed) then complete = false end
				end
			end
			for name, saved in pairs(self.data.modules or {}) do
				local item = ctx.mods[name]
				if item and saved.bind ~= nil then
					local bound, result = pcall(ctx.vapeapi.setbind, ctx.vapeapi, item.obj, clean(saved.bind))
					if not bound or result == false then fail(name, bound and 'bind restore returned false' or result) end
				end
			end
			for _, patch in ipairs(ctx.patchsys.order) do
				local saved = self.data.patches and self.data.patches[patch.id]
				local enabled = saved and saved.enabled == true
				if patch.enabled ~= enabled and not patch:setenabled(enabled, true) then
					fail(patch.id, 'patch state could not be restored')
				end
			end
			for name, saved in pairs(self.data.modules or {}) do
				local item = ctx.mods[name]
				if item and type(saved.enabled) == 'boolean' and item.obj.Enabled ~= saved.enabled
					and type(item.obj.Toggle) == 'function' then
					local toggled, err = pcall(item.obj.Toggle, item.obj, true)
					if not toggled or item.obj.Enabled ~= saved.enabled then
						fail(name, toggled and 'module state did not change' or err)
					end
				end
			end
		end, function(err) return tostring(err) end)
		self.restoring = previous
		if not ok then fail(nil, msg) end
		return ok and complete
	end

	local function watchmethod(obj, key, after)
		if type(obj) ~= 'table' or type(obj[key]) ~= 'function' then return end
		config.watched[obj] = config.watched[obj] or {}
		local item = config.watched[obj][key]
		if item then return config:rewatch(obj, key) end
		item = {obj = obj, key = key, old = obj[key]}
		item.wrap = function(self, ...)
			local out = table.pack(item.old(self, ...))
			if after then after(out[1]) end
			config:schedule()
			return table.unpack(out, 1, out.n)
		end
		config.watched[obj][key] = item
		obj[key] = item.wrap
		config.watchers[#config.watchers + 1] = item
	end

	function config:unwrapped(obj, key, val)
		local item = self.watched[obj] and self.watched[obj][key]
		if item and val == item.wrap then return item.old end
		return val
	end

	function config:rewatch(obj, key)
		local item = self.watched[obj] and self.watched[obj][key]
		if not item then return false end
		if obj[key] ~= item.wrap then
			item.old = obj[key]
			obj[key] = item.wrap
		end
		return true
	end

	function config:watchoption(opt)
		if type(opt) ~= 'table' then return end
		for _, key in ipairs({'Toggle', 'SetValue', 'SetBind', 'ChangeValue', 'Change'}) do
			watchmethod(opt, key)
		end
		for _, key in ipairs({'Players', 'NPCs', 'Invisible', 'Walls'}) do
			if type(opt[key]) == 'table' then watchmethod(opt[key], 'Toggle') end
		end
	end

	function config:watchmodule(item)
		watchmethod(item.obj, 'Toggle')
		watchmethod(item.obj, 'SetBind')
		for _, opt in pairs(item.obj.Options or {}) do self:watchoption(opt) end
		for _, method in pairs({
			'CreateToggle', 'CreateSlider', 'CreateTwoSlider', 'CreateDropdown', 'CreateMultiDropdown',
			'CreateTextBox', 'CreateTextList', 'CreateBind', 'CreateColorSlider', 'CreateFont', 'CreateTargets'
		}) do
			watchmethod(item.obj, method, function(opt)
				self:watchoption(opt)
				for _, option in pairs(item.obj.Options or {}) do self:watchoption(option) end
			end)
		end
	end

	function config:watch()
		for _, item in ipairs(ctx.modorder) do self:watchmodule(item) end
		for _, entry in ipairs(ctx.patchopts) do self:watchoption(entry.obj) end
	end

	function config:unwatch()
		for i = #self.watchers, 1, -1 do
			local item = self.watchers[i]
			if item.obj[item.key] == item.wrap then item.obj[item.key] = item.old end
			self.watchers[i] = nil
		end
		table.clear(self.watched)
	end

	function config:forgetobj(obj)
		for i = #self.watchers, 1, -1 do
			local item = self.watchers[i]
			if item.obj == obj then
				if item.obj[item.key] == item.wrap then item.obj[item.key] = item.old end
				table.remove(self.watchers, i)
			end
		end
		self.watched[obj] = nil
	end

	function config:forgetmodule(mod)
		self:forgetobj(mod)
		for _, opt in pairs(mod.Options or {}) do self:forgetobj(opt) end
	end

	local function nativeentry(entry)
		if not entry.persist then return nil, true end
		local val, ok = ctx.vapeapi:snapshotoption(entry.obj)
		if not ok then
			ctx.log:add('config_serialize', entry.name, val)
			return nil, false
		end
		return clean(val), true
	end

	function config:capture()
		local baseline = {version = self.version, modules = {}, patches = {}}
		local complete = true
		for name, item in pairs(ctx.mods) do
			local data, ok = moduledata(item)
			if not ok then return false end
			baseline.modules[name] = data
		end
		for _, patch in ipairs(ctx.patchsys.order) do
			local data, ok = patchdata(patch)
			if not ok then return false end
			baseline.patches[patch.id] = data
		end
		for _, entry in ipairs(ctx.patchopts) do
			if not entry.created and entry.persist and not entry.nativeknown then
				local data, ok = nativeentry(entry)
				if ok then
					entry.native = data
					entry.nativeknown = true
				else
					entry.native = nil
					entry.nativeknown = false
					complete = false
				end
			end
		end
		self.baseline = baseline
		return complete
	end

	function config:nativeloaded()
		local complete = true
		for _, entry in ipairs(ctx.patchopts) do
			if not entry.created and entry.persist then
				local data, ok = nativeentry(entry)
				if ok then
					entry.native = data
					entry.nativeknown = true
					if not ctx.patchsys:valuepatched(entry.obj) then
						for patch in pairs(entry.owners) do
							local saved = self.baseline and self.baseline.patches[patch.id]
							if saved then
								saved.options = saved.options or {}
								saved.options[entry.name] = clean(data)
							end
						end
					end
				else
					entry.native = nil
					entry.nativeknown = false
					complete = false
				end
			end
		end
		return complete
	end

	local function nativevalues()
		local live = {}
		local complete = true
		for _, entry in ipairs(ctx.patchopts) do
			if not entry.created and entry.persist then
				local data, ok = nativeentry(entry)
				if ok then live[#live + 1] = {entry = entry, data = data} else complete = false end
			end
		end
		return live, complete
	end

	local function loadnative(live)
		for _, item in ipairs(live) do
			local entry = item.entry
			if not entry.nativeknown then return false end
			if entry.native ~= nil and not ctx.vapeapi:loadoption(entry.obj, entry.native) then return false end
		end
		return true
	end

	local function restorelive(live)
		local complete = true
		for _, item in ipairs(live) do
			if item.data ~= nil and not ctx.vapeapi:loadoption(item.entry.obj, item.data) then complete = false end
		end
		return complete
	end

	function config:nativesave(fn, ...)
		local previous = self.restoring
		self.restoring = true
		local live, ready = nativevalues()
		local suspended = false
		local touched = false
		if ready and ctx.patchsys then
			suspended = true
			ready = ctx.patchsys:suspend()
		end
		if ready then touched = true ready = loadnative(live) end
		local out = ready and table.pack(pcall(fn, ...)) or table.pack(false, 'native save isolation failed')
		local restored = not touched or restorelive(live)
		if suspended and not ctx.patchsys:resume(false) then restored = false end
		self.restoring = previous
		if not ready or not restored then ctx.log:add('profile', nil, 'native save isolation was incomplete') end
		if not out[1] then error(out[2], 0) end
		if not restored then error('native save state could not be restored', 0) end
		return table.unpack(out, 2, out.n)
	end

	function config:nativeload(fn, ...)
		local previous = self.restoring
		self.restoring = true
		local live, ready = nativevalues()
		local suspended = false
		local touched = false
		if ready and ctx.patchsys then
			suspended = true
			ready = ctx.patchsys:suspend()
		end
		if ready then touched = true ready = loadnative(live) end
		local out = ready and table.pack(pcall(fn, ...)) or table.pack(false, 'native load isolation failed')
		local captured = out[1] and self:nativeloaded()
		local restored = true
		if out[1] then
			if suspended and not ctx.patchsys:resume(true) then restored = false end
		else
			restored = not touched or restorelive(live)
			if suspended and not ctx.patchsys:resume(false) then restored = false end
		end
		self.restoring = previous
		if not ready or not captured or not restored then ctx.log:add('profile', nil, 'native load isolation was incomplete') end
		if not out[1] then error(out[2], 0) end
		if not captured then error('native option state could not be captured', 0) end
		if not restored then error('native load state could not be restored', 0) end
		return table.unpack(out, 2, out.n)
	end

	function config:index()
		if not ctx.store.fs.write then return true end
		return self:atomic('configs/index.json', {
			version = self.version,
			profile = ctx.profile.name,
			directory = ctx.profile.dir,
			target = clean(ctx.target),
			updated = os.time and os.time() or 0
		})
	end

	function config:check()
		local cyclic = {}
		cyclic.self = cyclic
		local cleaned = clean({value = 1, bad = function() end, cycle = cyclic})
		return type(cleaned) == 'table' and cleaned.value == 1 and cleaned.bad == nil
	end

	config:setpaths()
	ctx.config = config
end
