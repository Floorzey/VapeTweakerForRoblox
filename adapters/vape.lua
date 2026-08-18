return function(ctx)
	local api = {
		index = {},
		bycat = {},
		owned = {},
		optioninfo = setmetatable({}, {__mode = 'k'}),
		settingscache = setmetatable({}, {__mode = 'k'}),
		readiness = 'waiting'
	}

	local function configuredgui()
		local configured = ctx.cfg.gui
		if type(configured) == 'string' and configured ~= '' then
			configured = configured:lower():gsub('%s+', '')
			if table.find({'new', 'old', 'rise', 'liquidbounce', 'wurst'}, configured) then return configured end
		end
		if type(readfile) == 'function' then
			local ok, val = pcall(readfile, 'newvape/profiles/gui.txt')
			if ok and type(val) == 'string' then
				val = val:lower():gsub('%s+', '')
				if table.find({'new', 'old', 'rise', 'liquidbounce', 'wurst'}, val) then return val end
			end
		end
		return 'unknown'
	end

	local function detectgui(vape, configured)
		if configured ~= 'unknown' then return configured end
		if type(vape) ~= 'table' or type(vape.Categories) ~= 'table' then return 'unknown' end
		local cats = vape.Categories
		if type(vape.Legit) ~= 'table' then return 'wurst' end
		if cats.Movement or cats.Ghost or cats.Search then return 'rise' end
		if cats.TopBar then return 'old' end
		if cats.Main then return 'new' end
		if cats.Combat and cats.Blatant and cats.Minigames then return 'liquidbounce' end
		return 'unknown'
	end

	local function startvape()
		if not ctx.cfg.autoload then return end
		local src
		if type(ctx.cfg.vapepath) == 'string' and type(readfile) == 'function' then
			local ok, val = pcall(readfile, ctx.cfg.vapepath)
			if ok then src = val end
		end
		if not src then
			local url = ctx.cfg.vapeurl or 'https://raw.githubusercontent.com/7GrandDadPGN/VapeV4ForRoblox/main/NewMainScript.lua'
			local ok, val = pcall(game.HttpGet, game, url, true)
			if not ok then error('Vape source unavailable: '..tostring(val), 0) end
			src = val
		end
		local fn, msg = loadstring(src, '@vapetweaker/vape.lua')
		if not fn then error('Vape compile failed: '..tostring(msg), 0) end
		local vape = fn()
		vape = type(vape) == 'table' and vape or type(shared) == 'table' and shared.vape
		if type(vape) == 'table' and type(shared) == 'table' and type(shared.vape) ~= 'table' then
			shared.vape = vape
		end
	end

	local function shape(vape)
		return type(vape) == 'table'
			and type(vape.Categories) == 'table'
			and type(vape.Modules) == 'table'
	end

	function api:attach()
		if type(shared) ~= 'table' then error('shared is unavailable', 0) end
		local started = os.clock()
		while type(game.IsLoaded) == 'function' and not game:IsLoaded() do
			if type(ctx.loader.active) == 'function' then ctx.loader:active() end
			if os.clock() - started >= ctx.cfg.timeout then error('timed out waiting for Roblox to load', 0) end
			task.wait(0.05)
		end
		if type(shared.vape) ~= 'table' then startvape() end
		if shared.VapeIndependent == true and type(shared.vape) == 'table'
			and type(shared.vape.Init) == 'function' then
			local ok, msg = pcall(shared.vape.Init)
			if not ok then error('Vape initialization failed: '..tostring(msg), 0) end
		end

		started = os.clock()
		local configured = configuredgui()
		local seen
		local stable
		while os.clock() - started < ctx.cfg.timeout do
			if type(ctx.loader.active) == 'function' then ctx.loader:active() end
			local vape = shared.vape
			if vape ~= seen then
				seen = vape
				stable = os.clock()
			end
			local flavor = detectgui(vape, configured)
			if shape(vape) and type(vape.Init) ~= 'function' then
				if vape.Loaded == true then
					self.readiness = (flavor == 'wurst' or flavor == 'liquidbounce') and 'degraded' or 'ready'
					self.object = vape
					self.flavor = flavor
					self.realprofile = flavor ~= 'wurst' and flavor ~= 'liquidbounce'
					return vape
				end
				if flavor == 'liquidbounce' and vape.Loaded ~= nil and os.clock() - stable >= 0.25 then
					self.readiness = 'degraded'
					self.object = vape
					self.flavor = flavor
					self.realprofile = false
					return vape
				end
			end
			task.wait(0.05)
		end
		error('timed out waiting for Vape to finish loading', 0)
	end

	local function lowercat(cat)
		if type(cat) ~= 'string' then return nil end
		cat = cat:lower()
		if ctx.cats.names[cat] then return cat end
		for low, real in pairs(ctx.cats.names) do
			if real:lower() == cat then return low end
		end
		if api.flavor == 'rise' then
			return ({movement = 'blatant', player = 'utility', exploit = 'world', ghost = 'legit'})[cat]
		end
	end

	function api:liveslot(name)
		local vape = self.object
		if type(vape) ~= 'table' or type(name) ~= 'string' then return nil end
		if type(vape.Modules) == 'table' and vape.Modules[name] ~= nil then
			return vape.Modules[name], vape.Modules, 'module'
		end
		if type(vape.Legit) == 'table' and type(vape.Legit.Modules) == 'table'
			and vape.Legit.Modules[name] ~= nil then
			return vape.Legit.Modules[name], vape.Legit.Modules, 'legit'
		end
		if type(vape.Categories) == 'table' and vape.Categories[name] ~= nil then
			return vape.Categories[name], vape.Categories, 'category'
		end
	end

	function api:reindex()
		table.clear(self.index)
		table.clear(self.bycat)
		local seen = {}
		local function add(name, mod, cat)
			if type(name) ~= 'string' or type(mod) ~= 'table' then return end
			if not seen[mod] then
				seen[mod] = true
				self.index[name] = self.index[name] or mod
			end
			cat = lowercat(api.owned[mod] or cat or mod.Category or (mod.Legit and 'legit'))
			if cat then
				self.bycat[cat] = self.bycat[cat] or {}
				self.bycat[cat][name] = mod
			end
		end

		for name, mod in pairs(self.object.Modules or {}) do add(name, mod) end
		for name, mod in pairs(self.object.Legit and self.object.Legit.Modules or {}) do add(name, mod, 'legit') end
		for cat, host in pairs(self.object.Categories or {}) do
			if type(host) == 'table' and type(host.Modules) == 'table' then
				for name, mod in pairs(host.Modules) do add(name, mod, cat) end
			end
		end
		for name, mod in pairs(self.index) do
			for optname, opt in pairs(mod.Options or {}) do
				if type(opt) == 'table' then self.optioninfo[opt] = {mod = mod, name = optname} end
			end
		end
	end

	function api:find(name, cat)
		if type(name) ~= 'string' then return nil end
		if cat then
			cat = lowercat(cat)
			if not cat then return nil end
			local mod = self.bycat[cat] and self.bycat[cat][name]
			if mod then
				local live = self.object.Modules and self.object.Modules[name]
					or self.object.Legit and self.object.Legit.Modules and self.object.Legit.Modules[name]
				if live == mod then return mod end
			end
			self:reindex()
			local mod = self.bycat[cat] and self.bycat[cat][name]
			if not mod and self.flavor == 'rise' and (cat == 'inventory' or cat == 'minigames') then
				mod = self.bycat.utility and self.bycat.utility[name]
			end
			return mod
		end
		local live, _, kind = self:liveslot(name)
		if kind == 'module' or kind == 'legit' then return live end
		self:reindex()
		return self.index[name]
	end

	function api:category(cat)
		cat = lowercat(cat)
		if not cat then return nil end
		if cat == 'legit' and type(self.object.Legit) == 'table' then return self.object.Legit end
		return self.object.Categories[ctx.cats.names[cat]]
	end

	function api:add(name, cat, mod)
		self.index[name] = mod
		self.bycat[cat] = self.bycat[cat] or {}
		self.bycat[cat][name] = mod
		self.owned[mod] = cat
	end

	function api:create(cat, data)
		local live = self:liveslot(data.Name)
		if live ~= nil then error('Vape registry name is already in use: '..data.Name, 0) end
		local host = self:category(cat)
		if type(host) ~= 'table' or type(host.CreateModule) ~= 'function' then
			error('Vape category unavailable: '..tostring(cat), 0)
		end
		local mod = host:CreateModule(data)
		if type(mod) ~= 'table' then error('Vape did not return a module', 0) end
		self:add(data.Name, cat, mod)
		return mod
	end

	local keys = {
		name = 'Name',
		func = 'Function',
		tooltip = 'Tooltip',
		extratext = 'ExtraText',
		default = 'Default',
		min = 'Min',
		max = 'Max',
		decimal = 'Decimal',
		list = 'List',
		placeholder = 'Placeholder',
		darker = 'Darker',
		visible = 'Visible',
		index = 'Index',
		size = 'Size',
		players = 'Players',
		npcs = 'NPCs',
		invisible = 'Invisible',
		walls = 'Walls',
		opacity = 'Opacity',
		blacklist = 'Blacklist',
		special = 'Special'
	}

	function api:spec(data)
		local out = {}
		for key, val in pairs(data or {}) do
			if key ~= 'replace' and key ~= 'raw' then out[keys[key] or key] = val end
		end
		if type(data) == 'table' and type(data.raw) == 'table' then
			for key, val in pairs(data.raw) do out[key] = val end
		end
		return out
	end

	local optionmethods = {
		toggle = 'CreateToggle',
		slider = 'CreateSlider',
		range = 'CreateTwoSlider',
		rangeslider = 'CreateTwoSlider',
		twoslider = 'CreateTwoSlider',
		dropdown = 'CreateDropdown',
		multidropdown = 'CreateMultiDropdown',
		textbox = 'CreateTextBox',
		textlist = 'CreateTextList',
		color = 'CreateColorSlider',
		colorslider = 'CreateColorSlider',
		hsv = 'CreateColorSlider',
		font = 'CreateFont',
		targets = 'CreateTargets',
		targetfilters = 'CreateTargets'
	}

	function api:optionkeys(kind, data)
		kind = tostring(kind):lower()
		if kind == 'targets' or kind == 'targetfilters' then return {'Targets'} end
		if kind == 'font' then return {data.name, data.name..' Asset'} end
		return {data.name}
	end

	function api:createoption(mod, kind, data)
		local method = optionmethods[tostring(kind):lower()]
		if not method or type(mod[method]) ~= 'function' then return nil, 'unsupported option type' end
		local spec = self:spec(data)
		spec.Name = data.name or data.Name
		local opt = mod[method](mod, spec)
		for name, obj in pairs(mod.Options or {}) do
			if type(obj) == 'table' then self.optioninfo[obj] = {mod = mod, name = name} end
		end
		return opt
	end

	local function getups(fn)
		local getter = debug and debug.getupvalues or getupvalues
		if type(getter) == 'function' then
			local ok, vals = pcall(getter, fn)
			if ok and type(vals) == 'table' then return vals end
		end
		local one = debug and debug.getupvalue or getupvalue
		if type(one) ~= 'function' then return {} end
		local vals = {}
		for i = 1, 40 do
			local out = table.pack(pcall(one, fn, i))
			if not out[1] or out[2] == nil then break end
			vals[#vals + 1] = out.n >= 3 and out[3] or out[2]
		end
		return vals
	end

	function api:settings(mod)
		local cached = self.settingscache[mod]
		local methods = {'Toggle', 'SetValue', 'SetBind', 'ChangeValue', 'Change'}
		local info = self.optioninfo[mod]
		local wanted = info and info.name or mod.Name
		local base = {}
		for _, key in ipairs(methods) do
			local method = mod[key]
			if ctx.config and type(ctx.config.unwrapped) == 'function' then
				method = ctx.config:unwrapped(mod, key, method)
			end
			if ctx.patchsys and type(ctx.patchsys.original) == 'function' then
				method = ctx.patchsys:original(mod, key, method)
			end
			base[key] = method
		end
		if type(cached) == 'table' and type(cached.value) == 'table' and cached.value.Name == wanted then
			local valid = true
			for _, key in ipairs(methods) do
				if cached.methods[key] ~= base[key] then valid = false break end
			end
			if valid then return cached.value end
		end
		local found
		for _, key in ipairs(methods) do
			local method = base[key]
			if type(method) == 'function' then
				for _, val in pairs(getups(method)) do
					if type(val) == 'table' and val ~= mod and val.Name == wanted
						and (type(val.Function) == 'function' or val.Tooltip ~= nil or val.Default ~= nil) then
						found = val
						break
					end
				end
				if found then break end
			end
		end
		if found then self.settingscache[mod] = {value = found, methods = base} end
		return found
	end

	function api:snapshotoption(opt)
		if type(opt) ~= 'table' or type(opt.Save) ~= 'function' then return nil, false end
		local out = {}
		local ok, msg = pcall(opt.Save, opt, out)
		if not ok then return msg, false end
		local info = self.optioninfo[opt]
		local val = info and out[info.name]
		if val == nil then
			local key, single = next(out)
			if key ~= nil and next(out, key) == nil then val = single end
		end
		return val, true
	end

	function api:loadoption(opt, data)
		if type(opt) ~= 'table' or type(opt.Load) ~= 'function' or type(data) ~= 'table' then return false end
		local ok, msg = pcall(opt.Load, opt, data)
		if not ok then ctx.log:add('config_restore', self.optioninfo[opt] and self.optioninfo[opt].name, msg) end
		return ok
	end

	function api:getprop(obj, prop)
		if type(obj) ~= 'table' or type(prop) ~= 'string' then return false end
		if prop == '@value' then
			local val, ok = self:snapshotoption(obj)
			return ok and type(val) == 'table', val
		end
		if prop == 'Function' or prop == 'Tooltip' then
			local set = self:settings(obj)
			if set then return true, set[prop] end
			if rawget(obj, prop) == nil then return false end
		end
		return true, obj[prop]
	end

	local function replace(text, old, new)
		if type(text) ~= 'string' or type(old) ~= 'string' or old == '' then return text end
		local first, last = text:find(old, 1, true)
		if not first then return text end
		return text:sub(1, first - 1)..tostring(new or '')..text:sub(last + 1)
	end

	local function setuptext(fn, old, new)
		local get = debug and debug.getupvalue or getupvalue
		local set = debug and debug.setupvalue or setupvalue
		if type(get) ~= 'function' or type(set) ~= 'function' or type(fn) ~= 'function' then return false end
		local changed = false
		for i = 1, 40 do
			local out = table.pack(pcall(get, fn, i))
			if not out[1] or out[2] == nil then break end
			local current = out.n >= 3 and out[3] or out[2]
			if current == old then
				local setok = pcall(set, fn, i, new)
				changed = setok or changed
			end
		end
		return changed
	end

	function api:settooltip(mod, old, new)
		if type(old) ~= 'string' or type(new) ~= 'string' then return false end
		local object = mod.Object
		if not typeof or typeof(object) ~= 'Instance' then return false end
		if self.flavor == 'new' or self.flavor == 'old' then
			if type(getconnections) ~= 'function' then return false end
			local eventok, event = pcall(function() return object.MouseEnter end)
			if not eventok then return false end
			local got, cons = pcall(getconnections, event)
			if not got or type(cons) ~= 'table' then return false end
			local changed = false
			for _, con in pairs(cons) do
				local readok, fn = pcall(function() return con.Function end)
				if readok then changed = setuptext(fn, old, new) or changed end
			end
			return changed
		end
		if self.flavor == 'rise' then
			local got, children = pcall(object.GetChildren, object)
			if not got then return false end
			for _, item in ipairs(children) do
				local readok, name, text = pcall(function() return item.Name, item.Text end)
				if readok and name ~= 'Title' and text == old then
					return pcall(function() item.Text = new end)
				end
			end
			return false
		end
		if self.flavor == 'wurst' and typeof(mod.Children) == 'Instance' then
			local got, children = pcall(mod.Children.GetChildren, mod.Children)
			if not got then return false end
			local before = '\n\nDescription:\n'..old..'\n\nSettings:'
			local after = '\n\nDescription:\n'..new..'\n\nSettings:'
			for _, item in ipairs(children) do
				local readok, text = pcall(function() return item.Text end)
				if readok and type(text) == 'string' and text:find(before, 1, true) then
					return pcall(function() item.Text = replace(text, before, after) end)
				end
			end
		end
		return false
	end

	function api:setprop(obj, prop, val)
		if type(obj) ~= 'table' or type(prop) ~= 'string' then return false end
		if prop == '@value' then return self:loadoption(obj, val) end
		if prop == 'Function' or prop == 'Tooltip' then
			local set = self:settings(obj)
			if set then
				local old = set[prop]
				set[prop] = val
				if prop == 'Tooltip' and not self:settooltip(obj, old, val) then
					set[prop] = old
					return false
				end
				return true
			end
			if rawget(obj, prop) == nil then return false end
		end
		obj[prop] = val
		return true
	end

	function api:remove(name, mod)
		if type(name) ~= 'string' or type(mod) ~= 'table' or not self.owned[mod] then return false end
		local complete = true
		if mod.Enabled and type(mod.Toggle) == 'function' then
			local ok, msg = pcall(mod.Toggle, mod)
			if not ok or mod.Enabled then
				complete = false
				ctx.log:add('module_cleanup', name, ok and 'module stayed enabled' or msg)
			end
		end
		local bind = mod.Bind
		local button = type(bind) == 'table' and bind.Button or typeof and typeof(bind) == 'Instance' and bind
		if typeof and typeof(button) == 'Instance' then
			local ok, msg = pcall(button.Destroy, button)
			if not ok then complete = false ctx.log:add('module_cleanup', name, msg) end
		end

		local live = self:liveslot(name)
		local removed = false
		if live == mod and type(self.object.Remove) == 'function' then
			local ok, msg = pcall(self.object.Remove, self.object, name)
			removed = ok
			if not ok then
				ctx.log:add('module_cleanup', name, msg)
			end
		end

		live = self:liveslot(name)
		if not removed or live == mod then
			for _, con in pairs(mod.Connections or {}) do
				local ok, done = pcall(function()
					if type(con) == 'function' then con()
					elseif type(con) == 'table' and type(con.Disconnect) == 'function' then con:Disconnect()
					elseif typeof and typeof(con) == 'RBXScriptConnection' then con:Disconnect() end
				end)
				if not ok or done == false then
					complete = false
					ctx.log:add('module_cleanup', name, ok and 'connection cleanup returned false' or done)
				end
			end
			for _, key in ipairs({'Object', 'Children', 'Toggle', 'Button'}) do
				local obj = type(mod[key]) == 'table' and mod[key].Object or mod[key]
				if typeof and typeof(obj) == 'Instance' then
					local ok, msg = pcall(obj.Destroy, obj)
					if not ok then complete = false ctx.log:add('module_cleanup', name, msg) end
				end
			end
		end
		if self.object.Modules[name] == mod then self.object.Modules[name] = nil end
		if self.object.Legit and self.object.Legit.Modules and self.object.Legit.Modules[name] == mod then
			self.object.Legit.Modules[name] = nil
		end
		for _, host in pairs(self.object.Categories) do
			if type(host) == 'table' and type(host.Modules) == 'table' and host.Modules[name] == mod then
				host.Modules[name] = nil
			end
		end
		if complete then
			self.owned[mod] = nil
			if self.index[name] == mod then self.index[name] = nil end
			for _, list in pairs(self.bycat) do
				if list[name] == mod then list[name] = nil end
			end
		end
		return complete
	end

	function api:removeoption(mod, name, opt)
		if type(mod) ~= 'table' or type(opt) ~= 'table' then return false end
		local complete = true
		if opt.Type == 'Toggle' and opt.Enabled and type(opt.Toggle) == 'function' then
			local ok = pcall(opt.Toggle, opt)
			if not ok or opt.Enabled then complete = false end
		end
		if opt.Type == 'ColorSlider' and opt.Rainbow and type(opt.Toggle) == 'function' then
			local ok = pcall(opt.Toggle, opt)
			if not ok or opt.Rainbow then complete = false end
		end
		if opt.Type == 'Targets' then
			for _, key in ipairs({'Players', 'NPCs', 'Invisible', 'Walls'}) do
				local part = opt[key]
				if type(part) == 'table' and part.Enabled and type(part.Toggle) == 'function' then
					local ok = pcall(part.Toggle, part)
					if not ok or part.Enabled then complete = false end
				end
			end
		end
		if type(self.object.RainbowTable) == 'table' then
			for i = #self.object.RainbowTable, 1, -1 do
				if self.object.RainbowTable[i] == opt then table.remove(self.object.RainbowTable, i) end
			end
		end
		if type(mod.Options) == 'table' and mod.Options[name] == opt then mod.Options[name] = nil end
		for _, key in ipairs({'Object', 'Window', 'Button'}) do
			local obj = opt[key]
			if typeof and typeof(obj) == 'Instance' then
				local ok = pcall(obj.Destroy, obj)
				if not ok then complete = false end
			end
		end
		if complete then self.optioninfo[opt] = nil end
		return complete
	end

	local function slot(slots, tab, key, val)
		if type(tab) == 'table' and tab[key] == val then
			slots[#slots + 1] = {tab = tab, key = key, val = val}
			tab[key] = nil
		end
	end

	function api:hidden(fn, ...)
		local slots = {}
		for name, data in pairs(ctx.mods) do
			local mod = data.obj
			slot(slots, self.object.Modules, name, mod)
		if self.object.Legit then slot(slots, self.object.Legit.Modules, name, mod) end
			for _, host in pairs(self.object.Categories) do
				if type(host) == 'table' then slot(slots, host.Modules, name, mod) end
			end
		end
		for _, data in ipairs(ctx.patchopts) do
			if data.created then slot(slots, data.mod.Options, data.name, data.obj) end
		end

		local out = table.pack(pcall(fn, ...))
		for i = #slots, 1, -1 do
			local item = slots[i]
			if item.tab[item.key] == nil then item.tab[item.key] = item.val end
		end
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	function api:profile()
		if self.realprofile == false then return 'default' end
		local name = self.object and self.object.Profile
		if type(name) ~= 'string' or name == '' then return 'default' end
		return name
	end

	function api:setbind(mod, bind)
		if type(mod.SetBind) ~= 'function' then return false end
		if self.flavor == 'wurst' and type(bind) == 'table' then bind = bind[1] or '' end
		mod:SetBind(bind)
		return true
	end

	function api:savebind(mod)
		local bind = mod.Bind
		local button = type(bind) == 'table' and bind.Button or typeof and typeof(bind) == 'Instance' and bind
		if typeof and typeof(button) == 'Instance' then
			local ok, pos = pcall(function() return button.Position end)
			if ok then return {Mobile = true, X = pos.X.Offset, Y = pos.Y.Offset} end
		end
		return bind
	end

	function api:hook()
		if self.hooks then return end
		local vape = self.object
		local hooks = {
			save = vape.Save,
			load = vape.Load,
			uninject = vape.Uninject
		}
		self.hooks = hooks

		if type(hooks.save) == 'function' then
			hooks.savewrap = function(obj, ...)
				if ctx.detached or ctx.state == 'unloaded' or api.nativeio then return hooks.save(obj, ...) end
				local active = api:profile()
				if api.realprofile and ctx.profile and ctx.profile.name ~= active
					and not ctx.profile:switch(active) then error('VapeTweaker profile switch failed', 0) end
				if ctx.config and ctx.state == 'loaded' and not ctx.config:save(false) then
					error('VapeTweaker config save failed', 0)
				end
				if ctx.config and type(ctx.config.nativesave) == 'function' then
					return ctx.config:nativesave(function(...)
						return api:hidden(hooks.save, ...)
					end, obj, ...)
				end
				return api:hidden(hooks.save, obj, ...)
			end
			vape.Save = hooks.savewrap
		end
		if type(hooks.load) == 'function' then
			hooks.loadwrap = function(obj, ...)
				if ctx.detached or ctx.state == 'unloaded' or api.nativeio then return hooks.load(obj, ...) end
				if ctx.config and ctx.state == 'loaded' and not ctx.config:save(true) then
					error('VapeTweaker config save failed', 0)
				end
				api.nativeio = (api.nativeio or 0) + 1
				local out
				if ctx.config and type(ctx.config.nativeload) == 'function' then
					out = table.pack(pcall(ctx.config.nativeload, ctx.config, function(...)
						return api:hidden(hooks.load, ...)
					end, obj, ...))
				else
					out = table.pack(pcall(api.hidden, api, hooks.load, obj, ...))
				end
				api.nativeio = api.nativeio - 1
				if api.nativeio == 0 then api.nativeio = nil end
				if not out[1] then error(out[2], 0) end
				local after = api:profile()
				if ctx.state ~= 'loaded' then
					if api.realprofile and ctx.profile and ctx.profile.name ~= after then ctx.profile:set(after) end
				elseif ctx.profile and ctx.profile.name ~= after then
					if not ctx.profile:switch(after, true) then error('VapeTweaker profile restore failed', 0) end
				elseif ctx.config then
					ctx.config:load()
					if not ctx.config:restore() or not ctx.config:index() then
						error('VapeTweaker profile restore failed', 0)
					end
				end
				return table.unpack(out, 2, out.n)
			end
			vape.Load = hooks.loadwrap
		end
		if type(hooks.uninject) == 'function' then
			hooks.uninjectwrap = function(obj, ...)
				local cleaned = ctx.state == 'unloaded'
				if ctx.state ~= 'unloaded' and ctx.state ~= 'unloading' then
					local ok, done = pcall(ctx.unload, ctx, 'vape')
					cleaned = ok and done == true
					if not ok or done == false then ctx.log:add('cleanup', 'vape', ok and 'cleanup returned false' or done) end
				end
				local saved
				local muted
				if not cleaned then
					saved = vape.Save
					muted = function() end
					vape.Save = muted
				end
				local out = table.pack(pcall(hooks.uninject, obj, ...))
				if not out[1] and muted and vape.Save == muted then vape.Save = saved end
				if not out[1] then error(out[2], 0) end
				local env = (getgenv and getgenv()) or _G
				if env.VapeTweaker == ctx then env.VapeTweaker = nil end
				ctx.state = 'unloaded'
				ctx.detached = true
				return table.unpack(out, 2, out.n)
			end
			vape.Uninject = hooks.uninjectwrap
		end

		local root = vape.gui
		if typeof and typeof(root) == 'Instance' and root.Destroying then
			ctx:clean(root.Destroying:Connect(function()
				if ctx.state == 'loaded' then ctx:unload('vape destroyed') end
			end))
		end
	end

	function api:unhook()
		local hooks = self.hooks
		local vape = self.object
		if not hooks or not vape then return end
		if vape.Save == hooks.savewrap then vape.Save = hooks.save end
		if vape.Load == hooks.loadwrap then vape.Load = hooks.load end
		if vape.Uninject == hooks.uninjectwrap then vape.Uninject = hooks.uninject end
		self.hooks = nil
	end

	function api:notify(title, text, duration, kind)
		if not ctx.cfg.notify or type(self.object.CreateNotification) ~= 'function' then return end
		pcall(self.object.CreateNotification, self.object, title, text, duration or 5, kind or 'info')
	end

	ctx.vapeapi = api
end
