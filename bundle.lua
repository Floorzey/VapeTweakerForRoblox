return {
	build = '1.2.2',
	games = false,
	files = {
		['src/adapters/vape.lua'] = [=[return function(ctx)
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
		if type(vape) ~= 'table' or type(vape.Categories) ~= 'table' then return configured end
		local cats = vape.Categories
		if cats.Main and type(vape.Legit) == 'table' then return 'new' end
		if cats.Movement or cats.Ghost or cats.Search then return 'rise' end
		if cats.TopBar then return 'old' end
		if type(vape.Legit) ~= 'table' then return 'wurst' end
		if configured ~= 'unknown' then return configured end
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
			if not mod and self.flavor == 'rise' and cat == 'inventory' then
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
		for _, tab in ipairs({self.object.RainbowSliders, self.object.RainbowTable}) do
			if type(tab) == 'table' then
				for i = #tab, 1, -1 do
					if tab[i] == opt then table.remove(tab, i) end
				end
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

	function api:setbind(mod, data)
		local bind = type(mod) == 'table' and mod.Bind
		if type(bind) == 'table' and type(bind.SetBind) == 'function' then
			local keys = data
			if type(data) == 'table' and (data.Keys ~= nil or data.keys ~= nil or data.Hold ~= nil or data.hold ~= nil
				or data.Mobile ~= nil or data.mobile ~= nil) then
				keys = data.Keys or data.keys or {}
				bind.Hold = data.Hold == true or data.hold == true
				local mobile = data.Mobile or data.mobile
				if type(bind.DestroyMobileButton) == 'function' then bind:DestroyMobileButton() end
				if type(mobile) == 'table' and type(bind.CreateMobileButton) == 'function' then
					local x = tonumber(mobile.X or mobile.x)
					local y = tonumber(mobile.Y or mobile.y)
					if x and y then bind:CreateMobileButton(Vector2.new(x, y)) end
				end
			end
			if type(keys) ~= 'table' then
				if keys == nil or keys == '' then keys = {} else keys = {tostring(keys)} end
			end
			bind:SetBind(keys)
			return true
		end
		if type(mod) ~= 'table' or type(mod.SetBind) ~= 'function' then return false end
		if self.flavor == 'wurst' and type(data) == 'table' then data = data[1] or '' end
		mod:SetBind(data)
		return true
	end

	function api:savebind(mod)
		local bind = type(mod) == 'table' and mod.Bind
		if type(bind) == 'table' and type(bind.Keys) == 'table' then
			local out = {Keys = table.clone(bind.Keys), Hold = bind.Hold == true}
			local mobile = bind.Mobile
			if typeof and typeof(mobile) == 'Instance' then
				local ok, pos = pcall(function() return mobile.Position end)
				if ok then out.Mobile = {X = pos.X.Offset, Y = pos.Y.Offset} end
			end
			return out
		end
		local button = type(bind) == 'table' and (bind.Button or bind.Object) or typeof and typeof(bind) == 'Instance' and bind
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
]=],
		['src/categories.lua'] = [[return {
	order = {
		'combat',
		'blatant',
		'render',
		'utility',
		'world',
		'inventory',
		'legit'
	},
	names = {
		combat = 'Combat',
		blatant = 'Blatant',
		render = 'Render',
		utility = 'Utility',
		world = 'World',
		inventory = 'Inventory',
		legit = 'Legit'
	}
}
]],
		['src/core/clean.lua'] = [[return function(ctx)
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
]],
		['src/core/config.lua'] = [[return function(ctx)
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
		if type(item.obj.Bind) == 'table' then
			local bind = item.obj.Bind
			watchmethod(bind, 'SetBind')
			watchmethod(bind, 'CreateMobileButton')
			watchmethod(bind, 'DestroyMobileButton')
			if typeof and typeof(bind.Object) == 'Instance' and bind.Object.MouseButton1Click then
				ctx:clean(bind.Object.MouseButton1Click:Connect(function()
					task.defer(function() config:schedule() end)
				end))
			end
		end
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
]],
		['src/core/layers.lua'] = [[return function(ctx)
	local http = game:GetService('HttpService')
	local seen = {}
	local tree

	local function clean(path)
		return tostring(path or '')
			:gsub('\\', '/')
			:gsub('/+', '/')
			:gsub('^/+', '')
			:gsub('/+$', '')
			:lower()
	end

	local function fail(kind, path, msg, fatal)
		ctx.log:add(kind, path, msg, fatal)
		if fatal then error(msg, 0) end
	end

	local function trace(msg)
		if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
			return debug.traceback(tostring(msg), 2)
		end
		return tostring(msg)
	end

	local function run(path, data)
		path = clean(path)
		if seen[path] then return false end
		seen[path] = true
		local mark = ctx:_mark()
		local old = ctx.loading
		ctx.loading = {
			layer = data.layer,
			scope = data.scope,
			category = data.category,
			kind = data.kind,
			path = path,
			required = data.required == true
		}
		local ok, msg = xpcall(function()
			local init = ctx.loader:run(path)
			if type(init) ~= 'function' then error(path..' must return a function', 0) end
			init(ctx)
		end, trace)
		ctx.loading = old
		if ok then return true end
		if not ctx:_rollback(mark) then error('incomplete rollback for '..path, 0) end
		fail(data.kind, path, msg, ctx.cfg.strict or data.required == true)
		return false
	end

	local function cats(data, path)
		if data.categories == nil then return table.clone(ctx.cats.order) end
		if type(data.categories) ~= 'table' then error(path..' categories must be a table', 0) end
		local out = {}
		local seen2 = {}
		for key, val in pairs(data.categories) do
			local cat = type(key) == 'number' and val or val and key or nil
			if cat then
				cat = tostring(cat):lower()
				if not ctx.cats.names[cat] then error(path..' has unsupported category '..cat, 0) end
				if not seen2[cat] then
					seen2[cat] = true
					out[#out + 1] = cat
				end
			end
		end
		table.sort(out, function(a, b)
			return table.find(ctx.cats.order, a) < table.find(ctx.cats.order, b)
		end)
		return out
	end

	local function catload(root, cat, kind, layer, scope)
		local path = root..'/'..cat..'/manifest.lua'
		local ok, data, state = ctx.loader:try(path)
		if not ok then
			if state ~= 'missing' then fail(kind, path, data, ctx.cfg.strict) end
			return 0
		end
		if type(data) ~= 'table' then
			fail(kind, path, path..' must return a table', ctx.cfg.strict)
			return 0
		end
		local count = 0
		for _, item in ipairs(data.files or data[kind] or data) do
			local file = type(item) == 'string' and item or type(item) == 'table' and (item.path or item.file)
			if file and (type(item) ~= 'table' or item.enabled ~= false) then
				if run(root..'/'..cat..'/'..file, {
					layer = layer,
					scope = scope,
					category = cat,
					kind = kind,
					required = type(item) == 'table' and item.required == true
				}) then count += 1 end
			end
		end
		return count
	end

	local function rootload(root, kind, layer, scope, required)
		local path = root..'/manifest.lua'
		local ok, data, state = ctx.loader:try(path)
		if not ok then
			if required or state ~= 'missing' then fail('layer', path, data or 'missing manifest', required or ctx.cfg.strict) end
			return 0
		end
		if type(data) ~= 'table' then
			fail('layer', path, path..' must return a table', required or ctx.cfg.strict)
			return 0
		end
		local count = 0
		if data.init and run(root..'/'..data.init, {
			layer = layer,
			scope = scope,
			kind = kind,
			required = true
		}) then count += 1 end
		for _, cat in ipairs(cats(data, path)) do
			count += catload(root, cat, kind, layer, scope)
		end
		ctx.layers[#ctx.layers + 1] = {
			name = layer,
			kind = kind,
			root = root,
			files = count
		}
		return count
	end

	local function repo()
		local base = tostring(ctx.loader.base or ctx.loader.requestbase or '')
		return base:match('^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)')
	end

	local function scan()
		if tree ~= nil then return tree end
		tree = false
		local owner, name, ref = repo()
		if not owner or not name or not ref then return false end
		local url = 'https://api.github.com/repos/'..owner..'/'..name..'/git/trees/'..ref..'?recursive=1&vt='..tostring(os.clock())
		local ok, raw = pcall(game.HttpGet, game, url, true)
		if not ok or type(raw) ~= 'string' then return false end
		local ok2, data = pcall(http.JSONDecode, http, raw)
		if not ok2 or type(data) ~= 'table' or type(data.tree) ~= 'table' then return false end
		local out = {}
		for _, item in ipairs(data.tree) do
			if item.type == 'blob' and type(item.path) == 'string' then
				local path = clean(item.path)
				if path:sub(-4) == '.lua' then out[#out + 1] = path end
			end
		end
		table.sort(out)
		tree = out
		return out
	end

	local function gameload()
		if ctx.loader.games == false then
			ctx.supportedgame = false
			ctx.gamefolder = nil
			return 0
		end
		local list = scan()
		if type(list) ~= 'table' then
			ctx.supportedgame = false
			ctx.gamefolder = nil
			return 0
		end
		local id = tostring(ctx.target.placeid or game.PlaceId)
		local root = 'src/games/'..id
		local prefix = root..'/'
		local files = {}
		for _, path in ipairs(list) do
			if path:sub(1, #prefix) == prefix then
				local rel = path:sub(#prefix + 1)
				if not rel:find('/', 1, true) then files[#files + 1] = path end
			end
		end
		table.sort(files)
		local count = 0
		for _, path in ipairs(files) do
			if run(path, {
				layer = 'place:'..id,
				scope = 'place',
				kind = 'game'
			}) then count += 1 end
		end
		ctx.supportedgame = count > 0
		ctx.gamefolder = count > 0 and root or nil
		if count > 0 then
			ctx.layers[#ctx.layers + 1] = {
				name = 'place:'..id,
				kind = 'game',
				root = root,
				files = count
			}
		end
		return count
	end

	function ctx:loadlayers()
		rootload('src/modules', 'modules', 'universal:modules', 'universal', true)
		rootload('src/patches', 'patches', 'universal:patches', 'universal', true)
		gameload()
	end
end
]],
		['src/core/log.lua'] = [[return function(ctx)
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
]],
		['src/core/patch.lua'] = [=[return function(ctx)
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
]=],
		['src/core/profile.lua'] = [[return function(ctx)
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
]],
		['src/core/runtime.lua'] = [[return function(ctx)
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
]],
		['src/core/storage.lua'] = [[return function(ctx)
	local http = game:GetService('HttpService')
	local store = {root = ctx.loader.root, dirs = {}}

	local function norm(path)
		path = tostring(path or ''):gsub('\\', '/'):gsub('/+', '/')
		path = path:gsub('^%./', ''):gsub('^/+', ''):gsub('/+$', '')
		if path:find('[%z\1-\31:]') then return nil end
		local parts = {}
		for part in path:gmatch('[^/]+') do
			if part == '..' then return nil end
			if part ~= '.' then parts[#parts + 1] = part end
		end
		return table.concat(parts, '/')
	end


	local function variant(path, tag)
		path = norm(path)
		if not path then return nil end
		local stem, ext = path:match('^(.*)(%.[^/%.]+)$')
		return stem and stem..'.'..tag..ext or path..'.'..tag
	end

	function store:path(path)
		path = norm(path)
		if not path then return nil end
		return path == '' and self.root or self.root..'/'..path
	end

	function store:mkdir(path)
		path = self:path(path)
		if not path or type(makefolder) ~= 'function' then return false end
		local out = ''
		for part in path:gmatch('[^/]+') do
			out = out == '' and part or out..'/'..part
			if not self.dirs[out] then
				local present = false
				if type(isfolder) == 'function' then
					local ok, val = pcall(isfolder, out)
					present = ok and val == true
				end
				if not present then
					local ok, msg = pcall(makefolder, out)
					if not ok and type(isfolder) == 'function' then
						local checked, val = pcall(isfolder, out)
						if checked and val then ok = true end
					end
					if not ok and type(isfolder) == 'function' then
						ctx.log:add('storage', out, msg)
						return false
					end
				end
				self.dirs[out] = true
			end
		end
		return true
	end

	function store:read(path)
		path = self:path(path)
		if not path or type(readfile) ~= 'function' then return nil end
		if type(isfile) == 'function' then
			local ok, val = pcall(isfile, path)
			if ok and not val then return nil end
		end
		local ok, data = pcall(readfile, path)
		if ok and type(data) == 'string' then return data end
		if not ok then ctx.log:add('storage', path, data) end
	end

	function store:variant(path, tag)
		return variant(path, tostring(tag or 'tmp'))
	end

	function store:temp(path, token)
		local tag = token and tostring(token)..'.tmp' or 'tmp'
		return variant(path, tag)
	end

	function store:backup(path)
		return variant(path, 'bak')
	end

	function store:write(path, data)
		path = norm(path)
		local full = path and self:path(path)
		if not full or type(writefile) ~= 'function' then return false end
		local dir = path:match('^(.*)/[^/]+$')
		if dir and not self:mkdir(dir) then return false end
		local ok, msg = pcall(writefile, full, tostring(data))
		if not ok or msg == false then
			ctx.log:add('storage', full, ok and 'writefile returned false' or msg)
			return false
		end
		return true
	end

	function store:remove(path)
		local full = self:path(path)
		if not full or type(delfile) ~= 'function' then return false end
		if type(isfile) == 'function' then
			local checked, present = pcall(isfile, full)
			if checked and not present then return true end
		end
		local ok, msg = pcall(delfile, full)
		if not ok or msg == false then
			ctx.log:add('storage', full, ok and 'delfile returned false' or msg)
			return false
		end
		return true
	end

	function store:decode(raw, path)
		local ok, data = pcall(http.JSONDecode, http, raw)
		if ok then return data end
		ctx.log:add('config_parse', path, data)
	end

	function store:encode(data, path)
		local ok, raw = pcall(http.JSONEncode, http, data)
		if ok then return raw end
		ctx.log:add('config_write', path, raw)
	end

	function store:json(path)
		local raw = self:read(path)
		if not raw then return nil end
		return self:decode(raw, path)
	end

	function store:has(path)
		return self:read(path) ~= nil
	end

	store.fs = {
		read = type(readfile) == 'function',
		write = type(writefile) == 'function',
		folders = type(makefolder) == 'function',
		delete = type(delfile) == 'function'
	}

	ctx.store = store
end
]],
		['src/core/target.lua'] = [[return function(ctx)
	local function file(path)
		if type(isfile) ~= 'function' then return nil end
		local ok, val = pcall(isfile, path)
		if not ok then return nil end
		return val == true
	end

	function ctx:resolvetarget()
		local vape = self.vape
		local gameid = game.GameId
		local placeid = game.PlaceId
		local buildid = vape.Place or placeid
		local nativefile = file('newvape/games/'..tostring(placeid)..'.lua')
		local independent = type(shared) == 'table' and shared.VapeIndependent == true
		local native = not independent and (buildid ~= placeid or nativefile == true)
		local mode = independent and 'independent' or native and 'game' or 'universal'

		self.target = {
			mode = mode,
			gameid = gameid,
			placeid = placeid,
			buildid = buildid,
			native = native,
			native_known = buildid ~= placeid or nativefile ~= nil,
			gui = self.vapeapi.flavor or 'unknown',
			version = vape.Version,
			readiness = self.vapeapi.readiness
		}
		return self.target
	end
end
]],
		['src/init.lua'] = [[local ld = ...
if type(ld) ~= 'table' or type(ld.run) ~= 'function' then error('invalid VapeTweaker loader', 0) end

local env = (getgenv and getgenv()) or _G
local paths = {
	log = 'src/core/log.lua',
	clean = 'src/core/clean.lua',
	storage = 'src/core/storage.lua',
	adapter = 'src/adapters/vape.lua',
	target = 'src/core/target.lua',
	patch = 'src/core/patch.lua',
	runtime = 'src/core/runtime.lua',
	profile = 'src/core/profile.lua',
	config = 'src/core/config.lua',
	layers = 'src/core/layers.lua'
}
local init = {}

for name, path in pairs(paths) do
	local fn = ld:run(path)
	if type(fn) ~= 'function' then error(path..' must return a function', 0) end
	init[name] = fn
end
local cats = ld:run('src/categories.lua')
if type(cats) ~= 'table' or type(cats.order) ~= 'table' or type(cats.names) ~= 'table' then
	error('invalid category map', 0)
end

local function forceold(old)
	pcall(function()
		if old.vapeapi and type(old.vapeapi.unhook) == 'function' then old.vapeapi:unhook() end
	end)
	pcall(function()
		if old.patchsys and type(old.patchsys.restore) == 'function' then old.patchsys:restore() end
	end)
	pcall(function()
		if old.config and type(old.config.unwatch) == 'function' then old.config:unwatch() end
	end)
	pcall(function()
		if type(old.modorder) == 'table' and old.vapeapi and type(old.vapeapi.remove) == 'function' then
			for i = #old.modorder, 1, -1 do
				local data = old.modorder[i]
				if type(data) == 'table' then pcall(old.vapeapi.remove, old.vapeapi, data.name, data.obj) end
			end
		end
	end)
	pcall(function()
		if old.bin and type(old.bin.run) == 'function' then old.bin:run() end
	end)
	old.state = 'unloaded'
	if env.VapeTweaker == old then env.VapeTweaker = nil end
end

local old = env.VapeTweaker
if type(old) == 'table' then
	local unload = type(old.unload) == 'function' and old.unload or old.Unload
	local done = false
	if type(unload) == 'function' then
		local ok, result = pcall(unload, old, 'reload')
		done = ok and result ~= false
	end
	if not done then forceold(old) end
end

local ctx = {
	name = 'VapeTweaker',
	version = ld.version,
	loader = ld,
	cfg = ld.cfg,
	state = 'starting',
	started = os.clock(),
	cats = cats,
	mods = {},
	modorder = {},
	patchopts = {},
	layers = {},
	events = {}
}

init.log(ctx)
init.clean(ctx)
init.storage(ctx)
init.adapter(ctx)
init.target(ctx)
init.patch(ctx)
init.runtime(ctx)
init.layers(ctx)

local function trace(msg)
	if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
		return debug.traceback(tostring(msg), 2)
	end
	return tostring(msg)
end

local ok, msg = xpcall(function()
	ctx.vape = ctx.vapeapi:attach()
	ctx.vapeapi:reindex()
	ctx:resolvetarget()
	init.profile(ctx)
	init.config(ctx)
	ctx.vapeapi:hook()
	ctx:loadlayers()
	if not ctx.config:capture() then error('configuration baseline could not be captured', 0) end
	ctx.config:load()
	if not ctx.config:restore() then error('configuration could not be restored', 0) end
	ctx.config:watch()
	ctx.state = 'loaded'
	ctx.config:index()

	local session = {
		version = ctx.version,
		build = ld.build,
		started = ctx.started,
		profile = ctx.profile.name,
		target = ctx.target,
		layers = ctx.layers
	}
	local raw = ctx.store:encode(session, 'state/session.json')
	if raw then ctx.store:write('state/session.json', raw) end
end, trace)

if not ok then
	ctx.log:add('startup', nil, msg, true)
	ctx:unload('startup failure')
	error(msg, 0)
end

env.VapeTweaker = ctx
ctx.vapeapi:notify('VapeTweaker', 'Loaded', 4, 'info')
return ctx
]],
		['src/modules/manifest.lua'] = [[return {
	categories = {'render'}
}
]],
		['src/modules/render/manifest.lua'] = [[return {
	files = {
		'proximitypromptesp.lua'
	}
}
]],
		['src/modules/render/proximitypromptesp.lua'] = [[return function(ctx)
	local players = game:GetService('Players')
	local run = game:GetService('RunService')
	local input = game:GetService('UserInputService')
	local lp = players.LocalPlayer
	local refs = {}
	local rayparams = RaycastParams.new()
	local mod
	local distance
	local scale
	local objecttext
	local actiontext
	local keybind
	local holdduration
	local targets
	local background
	local color
	local folder
	local elapsed = 0

	rayparams.FilterType = Enum.RaycastFilterType.Exclude
	rayparams.IgnoreWater = true

	local function escape(text)
		return tostring(text)
			:gsub('&', '&amp;')
			:gsub('<', '&lt;')
			:gsub('>', '&gt;')
			:gsub('"', '&quot;')
	end

	local function adornee(prompt)
		local parent = prompt.Parent
		if not parent then return nil end
		if parent:IsA('Attachment') or parent:IsA('BasePart') then
			return parent
		end
		if parent:IsA('Model') then
			return parent.PrimaryPart or parent:FindFirstChildWhichIsA('BasePart', true)
		end
		return parent:FindFirstAncestorWhichIsA('BasePart')
	end

	local function partof(obj)
		if not obj then return nil end
		if obj:IsA('Attachment') then return obj.Parent end
		if obj:IsA('BasePart') then return obj end
	end

	local function position(obj)
		if not obj then return nil end
		if obj:IsA('Attachment') then return obj.WorldPosition end
		if obj:IsA('BasePart') then return obj.Position end
	end

	local function key(prompt)
		local code = prompt.KeyboardKeyCode
		if input.GamepadEnabled and prompt.GamepadKeyCode ~= Enum.KeyCode.Unknown then
			code = prompt.GamepadKeyCode
		end
		if code == Enum.KeyCode.Unknown then return nil end
		return code.Name
	end

	local function objectname(prompt)
		if prompt.ObjectText ~= '' then return prompt.ObjectText end
		local parent = prompt.Parent
		if parent and parent:IsA('Attachment') then parent = parent.Parent end
		return parent and parent.Name or 'Prompt'
	end

	local function maketext(prompt, studs)
		local top = {}
		local bottom = {}

		if objecttext.Enabled then
			top[#top + 1] = '<b>'..escape(objectname(prompt))..'</b>'
		end

		if actiontext.Enabled then
			bottom[#bottom + 1] = escape(prompt.ActionText ~= '' and prompt.ActionText or 'Interact')
		end

		if keybind.Enabled then
			local bind = key(prompt)
			if bind then table.insert(bottom, 1, '['..escape(bind)..']') end
		end

		if holdduration.Enabled and prompt.HoldDuration > 0 then
			bottom[#bottom + 1] = string.format('%.1fs', prompt.HoldDuration)
		end

		if distance.Enabled then
			bottom[#bottom + 1] = tostring(math.floor(studs + 0.5))..' studs'
		end

		if #top == 0 then return table.concat(bottom, '  ') end
		if #bottom == 0 then return table.concat(top, '  ') end
		return table.concat(top, '  ')..'\n'..table.concat(bottom, '  ')
	end

	local function remove(prompt)
		local data = refs[prompt]
		if not data then return end
		refs[prompt] = nil
		data:destroy()
	end

	local function clear()
		for prompt, data in pairs(refs) do
			refs[prompt] = nil
			data:destroy()
		end
	end

	local function add(prompt)
		if refs[prompt] or not prompt:IsA('ProximityPrompt') then return end
		local target = adornee(prompt)
		if not target then return end

		local gui = Instance.new('BillboardGui')
		gui.Name = 'ProximityPromptESP'
		gui.Adornee = target
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.StudsOffsetWorldSpace = Vector3.new(0, 1.25, 0)
		gui.Size = UDim2.fromOffset(210, 48)
		gui.Parent = folder

		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.new()
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = frame

		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Transparency = 0.25
		stroke.Parent = frame

		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, -10, 1, -6)
		label.Position = UDim2.fromOffset(5, 3)
		label.BackgroundTransparency = 1
		label.RichText = true
		label.Text = ''
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.65
		label.TextWrapped = true
		label.TextSize = 14
		label.Font = Enum.Font.Gotham
		label.Parent = frame

		local dead = false
		local data = {
			gui = gui,
			frame = frame,
			label = label,
			stroke = stroke,
			target = target
		}

		function data:destroy()
			if dead then return end
			dead = true
			gui:Destroy()
		end

		refs[prompt] = data
	end

	local function targetallowed(prompt)
		local model = prompt:FindFirstAncestorOfClass('Model')
		if not model then return true end
		if players:GetPlayerFromCharacter(model) then
			return targets.Players.Enabled
		end
		if model:FindFirstChildOfClass('Humanoid') then
			return targets.NPCs.Enabled
		end
		return true
	end

	local function invisible(prompt, target)
		if not prompt.Enabled then return true end
		local part = partof(target)
		if not part then return false end
		return math.max(part.Transparency, part.LocalTransparencyModifier) >= 1
	end

	local function behindwall(prompt, target, origin, pos, char)
		local offset = pos - origin
		if offset.Magnitude <= 0.01 then return false end
		rayparams.FilterDescendantsInstances = char and {char} or {}
		local hit = workspace:Raycast(origin, offset, rayparams)
		if not hit then return false end

		local part = partof(target)
		if part and hit.Instance == part then return false end
		local model = prompt:FindFirstAncestorOfClass('Model')
		if model and hit.Instance:IsDescendantOf(model) then return false end
		return true
	end

	local function update()
		local char = lp.Character
		local root = char and char:FindFirstChild('HumanoidRootPart')
		local cam = workspace.CurrentCamera
		local origin = cam and cam.CFrame.Position or root and root.Position
		if not origin then return end

		local tint = Color3.fromHSV(color.Hue, color.Sat, color.Value)
		local size = scale.Value / 100
		local max = distance.Value
		local removequeue = {}

		for prompt, data in pairs(refs) do
			if not prompt.Parent or not prompt:IsDescendantOf(workspace) then
				removequeue[#removequeue + 1] = prompt
			else
				local target = adornee(prompt)
				local pos = position(target)
				if not target or not pos then
					data.gui.Enabled = false
				else
					if data.target ~= target then
						data.target = target
						data.gui.Adornee = target
					end

					local studs = (pos - origin).Magnitude
					local shown = studs <= max and targetallowed(prompt)
					if shown and targets.Invisible.Enabled then
						shown = not invisible(prompt, target)
					end
					if shown and targets.Walls.Enabled then
						shown = not behindwall(prompt, target, origin, pos, char)
					end
					data.gui.Enabled = shown

					if shown then
						data.gui.Size = UDim2.fromOffset(210 * size, 48 * size)
						data.frame.BackgroundTransparency = background.Enabled and 0.35 or 1
						data.label.TextSize = math.floor(14 * size + 0.5)
						data.label.TextColor3 = tint
						data.label.TextTransparency = studs <= prompt.MaxActivationDistance and 0 or 0.25
						data.stroke.Color = tint
						data.stroke.Enabled = background.Enabled
						data.label.Text = maketext(prompt, studs)
					end
				end
			end
		end

		for _, prompt in ipairs(removequeue) do
			remove(prompt)
		end
	end

	mod = ctx:module('render', {
		name = 'ProximityPromptESP',
		tooltip = 'Extra Sensory Perception for proximity prompts',
		func = function(on)
			if on then
				clear()
				folder = Instance.new('Folder')
				folder.Name = 'ProximityPromptESP'
				folder.Parent = typeof(ctx.vape.gui) == 'Instance' and ctx.vape.gui or lp:WaitForChild('PlayerGui')
				mod:Clean(folder)

				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA('ProximityPrompt') then add(obj) end
				end

				mod:Clean(workspace.DescendantAdded:Connect(function(obj)
					if obj:IsA('ProximityPrompt') then add(obj) end
				end))

				mod:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if obj:IsA('ProximityPrompt') then remove(obj) end
				end))

				mod:Clean(run.Heartbeat:Connect(function(dt)
					elapsed = elapsed + dt
					if elapsed < 0.1 then return end
					elapsed = 0
					update()
				end))

				update()
			else
				clear()
				folder = nil
				elapsed = 0
			end
		end
	})

	targets = mod:CreateTargets({
		Players = true,
		NPCs = true,
		Invisible = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	distance = mod:CreateSlider({
		Name = 'Distance',
		Min = 10,
		Max = 1000,
		Default = 250,
		Suffix = function(val)
			return val == 1 and ' stud' or ' studs'
		end,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	scale = mod:CreateSlider({
		Name = 'Scale',
		Min = 50,
		Max = 150,
		Default = 100,
		Suffix = '%',
		Function = function()
			if mod.Enabled then update() end
		end
	})

	objecttext = mod:CreateToggle({
		Name = 'Object Text',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	actiontext = mod:CreateToggle({
		Name = 'Action Text',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	keybind = mod:CreateToggle({
		Name = 'Keybind',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	holdduration = mod:CreateToggle({
		Name = 'Hold Duration',
		Function = function()
			if mod.Enabled then update() end
		end
	})

	background = mod:CreateToggle({
		Name = 'Background',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	color = mod:CreateColorSlider({
		Name = 'Color',
		Function = function()
			if mod.Enabled then update() end
		end
	})
end
]],
		['src/patches/combat/manifest.lua'] = [[return {
	files = {
		'silentaimfix.lua'
	}
}
]],
		['src/patches/combat/silentaimfix.lua'] = [[
return function(ctx)
	local patch = ctx:patch('SilentAim', 'SilentAimfix', 'combat')
	if not patch then return end

	local mod = patch.mod
	local players = game:GetService('Players')
	local localPlayer = players.LocalPlayer
	local guard
	local geometryGuard
	local weaponScripts

	local function readUpvalues(fn)
		local getter = debug and debug.getupvalues or getupvalues
		if type(getter) == 'function' then
			local ok, values = pcall(getter, fn)
			if ok and type(values) == 'table' then return values end
		end

		local get = debug and debug.getupvalue or getupvalue
		if type(get) ~= 'function' then return {} end

		local values = {}
		for index = 1, 48 do
			local result = table.pack(pcall(get, fn, index))
			if not result[1] or result[2] == nil then break end
			values[#values + 1] = result.n >= 3 and result[3] or result[2]
		end
		return values
	end

	local ok, moduleFunction = ctx.vapeapi:getprop(mod, 'Function')
	if not ok or type(moduleFunction) ~= 'function' then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim Function is unavailable')
		return
	end

	local hooks
	local function valid(v)
		return type(v) == 'function' or type(v) == 'table' and type(v.Function) == 'function'
	end
	for _, value in pairs(readUpvalues(moduleFunction)) do
		if type(value) == 'table'
			and valid(value.Ray)
			and valid(value.Raycast)
			and valid(value.ScreenPointToRay) then
			hooks = value
			break
		end
	end

	if not hooks then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim hook table was not found')
		return
	end

	local ray = hooks.Ray
	local originalRay = type(ray) == 'table' and ray.Function or ray

	local exactCamera = {
		basecamera = true,
		camerainput = true,
		cameramodule = true,
		camerascript = true,
		camerascriptnew = true,
		cameratogglestatecontroller = true,
		camerautils = true,
		classiccamera = true,
		clicktomovecontroller = true,
		controlmodule = true,
		controlscript = true,
		invisicam = true,
		legacycamera = true,
		mouselockcontroller = true,
		orbitalcamera = true,
		poppercam = true,
		shiftlockcontroller = true,
		shouldercamera = true,
		transparencycontroller = true,
		vehiclecamera = true,
		vrcamera = true,
		zoomcontroller = true
	}

	local cameraPatterns = {
		'camera',
		'clicktomove',
		'controlmodule',
		'controlscript',
		'invisicam',
		'mouselock',
		'occlusion',
		'poppercam',
		'shiftlock',
		'shouldercam',
		'transparencycontroller',
		'zoomcontroller'
	}

	local weaponPatterns = {
		'blaster',
		'bow',
		'bullet',
		'cannon',
		'firearm',
		'gun',
		'launcher',
		'pistol',
		'projectile',
		'rifle',
		'shoot',
		'shotgun',
		'sniper',
		'weapon'
	}

	local function lower(value)
		return tostring(value or ''):lower()
	end

	local function containsAny(text, patterns)
		text = lower(text)
		for _, pattern in ipairs(patterns) do
			if text:find(pattern, 1, true) then return true end
		end
		return false
	end

	local function fullName(instance)
		if typeof(instance) ~= 'Instance' then return '' end
		local got, value = pcall(instance.GetFullName, instance)
		return got and lower(value) or lower(instance.Name)
	end

	local function manuallyAllowed(instance)
		local list = weaponScripts and weaponScripts.ListEnabled
		if type(list) ~= 'table' then return false end

		local name = typeof(instance) == 'Instance' and lower(instance.Name) or ''
		local path = fullName(instance)
		for _, item in ipairs(list) do
			item = lower(item)
			if item ~= '' and (item == name or item == path or path:find(item, 1, true)) then
				return true
			end
		end
		return false
	end

	local function hasAncestor(instance, wanted)
		if typeof(instance) ~= 'Instance' then return false end
		local current = instance.Parent
		for _ = 1, 16 do
			if not current or current == game then break end
			local name = lower(current.Name)
			if wanted[name] then return true end
			current = current.Parent
		end
		return false
	end

	local function cameraCaller(instance)
		if typeof(instance) ~= 'Instance' then return false end
		local name = lower(instance.Name)
		local path = fullName(instance)
		if exactCamera[name] then return true end
		if containsAny(name, cameraPatterns) or containsAny(path, cameraPatterns) then return true end
		return hasAncestor(instance, {
			cameramodule = true,
			controlmodule = true
		})
	end

	local function weaponCaller(instance)
		if typeof(instance) ~= 'Instance' then return false end

		local current = instance.Parent
		for _ = 1, 16 do
			if not current or current == game then break end
			if current:IsA('Tool') then return true end
			current = current.Parent
		end

		local backpack = localPlayer and localPlayer:FindFirstChildOfClass('Backpack')
		if backpack and instance:IsDescendantOf(backpack) then return true end

		local name = lower(instance.Name)
		local path = fullName(instance)
		return containsAny(name, weaponPatterns) or containsAny(path, weaponPatterns)
	end

	local function near(first, second, radius)
		return (first - second).Magnitude <= radius
	end

	local function cameraGeometry(origin, direction)
		if not geometryGuard or not geometryGuard.Enabled then return false end
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' then return false end

		local length = direction.Magnitude
		if length <= 0.001 then return true end

		local camera = workspace.CurrentCamera
		if not camera then return false end

		local cameraPosition = camera.CFrame.Position
		local focusPosition = camera.Focus.Position
		local endpoint = origin + direction

		if length <= 256 then
			if near(origin, focusPosition, 8) and near(endpoint, cameraPosition, 10) then return true end
			if near(origin, cameraPosition, 8) and near(endpoint, focusPosition, 10) then return true end

			local character = localPlayer and localPlayer.Character
			local root = character and character:FindFirstChild('HumanoidRootPart')
			if root and near(origin, root.Position, 10) and near(endpoint, cameraPosition, 10) then
				return true
			end
		end

		if length <= 6 and (near(origin, cameraPosition, 6) or near(origin, focusPosition, 6)) then
			return true
		end

		return false
	end

	local function callingScript()
		if type(getcallingscript) ~= 'function' then return nil end
		local got, value = pcall(getcallingscript)
		return got and value or nil
	end

	local function shouldBypass(origin, direction)
		local calling = callingScript()
		if manuallyAllowed(calling) then return false end
		if cameraCaller(calling) then return true end
		if weaponCaller(calling) then return false end
		return cameraGeometry(origin, direction)
	end

	weaponScripts = patch:option('textlist', {
		name = 'Ray Weapon Scripts',
		darker = true,
		tooltip = 'Script names or full-name fragments that should always remain eligible for the Ray.new method.'
	})

	geometryGuard = patch:option('toggle', {
		name = 'Ray Geometry Guard',
		default = true,
		darker = true,
		tooltip = 'Also recognizes camera obstruction rays from their origin and endpoint when the calling script is unavailable.'
	})

	guard = patch:option('toggle', {
		name = 'Ray Camera Guard',
		default = true,
		darker = true,
		tooltip = 'Prevents the Ray.new method from redirecting camera, occlusion, shift-lock, and control rays.'
	})

	local guardedRay = function(args)
		if guard and guard.Enabled and shouldBypass(args[1], args[2]) then return end
		return originalRay(args)
	end

	local res
	if type(ray) == 'table' then
		res = patch:set('Function', guardedRay, ray)
	else
		res = patch:set('Ray', guardedRay, hooks)
	end
	if not res then
		error('SilentAim Ray transform could not be patched', 0)
	end
end
]],
		['src/patches/manifest.lua'] = [[return {
	init = 'teleport.lua',
	categories = {'combat', 'render'}
}
]],
		['src/patches/render/crosshair.lua'] = [[return function(ctx)
	local vape = ctx.vape
	if type(vape) ~= 'table' or type(vape.CreateOverlay) ~= 'function' then
		error('Crosshair requires the new Vape GUI overlay API', 0)
	end

	local run = game:GetService('RunService')

	local iconpath = ctx.store:path('assets/crosshair.png')
	local icon = 'rbxassetid://14368354234'
	local present = false
	if type(isfile) == 'function' and iconpath then
		local ok, val = pcall(isfile, iconpath)
		present = ok and val == true
	end
	local asset = vape.Libraries and vape.Libraries.getcustomasset or getcustomasset
	if present and type(asset) == 'function' then
		local ok, val = pcall(asset, iconpath)
		if ok and type(val) == 'string' and val ~= '' then icon = val end
	end

	local overlay
	local holder
	local style
	local color
	local size
	local thickness
	local gap
	local outline
	local outlinewidth

	local function clear()
		if not holder then return end
		for _, obj in ipairs(holder:GetChildren()) do
			obj:Destroy()
		end
	end

	local function corner(obj)
		local ui = Instance.new('UICorner')
		ui.CornerRadius = UDim.new(1, 0)
		ui.Parent = obj
		return ui
	end

	local function box(name, parent, width, height, x, y, anchor, fill, transparency, round)
		local obj = Instance.new('Frame')
		obj.Name = name
		obj.Size = UDim2.fromOffset(math.max(1, width), math.max(1, height))
		obj.Position = UDim2.new(0.5, x, 0.5, y)
		obj.AnchorPoint = anchor
		obj.BackgroundColor3 = fill
		obj.BackgroundTransparency = transparency
		obj.BorderSizePixel = 0
		obj.ZIndex = 1000000
		obj.Parent = parent
		if round then corner(obj) end
		return obj
	end

	local function arm(name, width, height, x, y, anchor, fill, transparency, edge)
		if outline.Enabled then
			box(
				name..'Outline',
				holder,
				width + outlinewidth.Value * 2,
				height + outlinewidth.Value * 2,
				x,
				y,
				anchor,
				Color3.new(),
				transparency,
				edge
			)
		end
		box(name, holder, width, height, x, y, anchor, fill, transparency, edge)
	end

	local function dot(name, diameter, fill, transparency)
		if outline.Enabled then
			box(
				name..'Outline',
				holder,
				diameter + outlinewidth.Value * 2,
				diameter + outlinewidth.Value * 2,
				0,
				0,
				Vector2.new(0.5, 0.5),
				Color3.new(),
				transparency,
				true
			)
		end
		box(name, holder, diameter, diameter, 0, 0, Vector2.new(0.5, 0.5), fill, transparency, true)
	end

	local function circle(diameter, line, fill, transparency)
		if outline.Enabled then
			local outer = box(
				'CircleOutline',
				holder,
				diameter,
				diameter,
				0,
				0,
				Vector2.new(0.5, 0.5),
				Color3.new(),
				1,
				true
			)
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.new()
			stroke.Thickness = line + outlinewidth.Value * 2
			stroke.Transparency = transparency
			stroke.Parent = outer
		end

		local ring = box(
			'Circle',
			holder,
			diameter,
			diameter,
			0,
			0,
			Vector2.new(0.5, 0.5),
			fill,
			1,
			true
		)
		local stroke = Instance.new('UIStroke')
		stroke.Color = fill
		stroke.Thickness = line
		stroke.Transparency = transparency
		stroke.Parent = ring
		dot('CenterDot', math.max(2, line + 1), fill, transparency)
	end

	local function optionvisibility()
		if not style then return end
		local selected = style.Value
		if gap then gap.Object.Visible = selected == 'Classic' end
		if thickness then thickness.Object.Visible = selected ~= 'Dot' end
		if outlinewidth then outlinewidth.Object.Visible = outline.Enabled end
	end

	local function draw()
		if not holder or not style or not color or not size or not thickness or not gap or not outline or not outlinewidth then
			return
		end
		clear()
		optionvisibility()

		local fill = Color3.fromHSV(color.Hue, color.Sat, color.Value)
		local transparency = 1 - color.Opacity
		local length = size.Value
		local line = thickness.Value
		local space = gap.Value

		if style.Value == 'Dot' then
			dot('Dot', math.max(2, math.floor(length * 0.45 + 0.5)), fill, transparency)
		elseif style.Value == 'Circle' then
			circle(math.max(8, length * 2), line, fill, transparency)
		else
			arm('Left', length, line, -space, 0, Vector2.new(1, 0.5), fill, transparency, true)
			arm('Right', length, line, space, 0, Vector2.new(0, 0.5), fill, transparency, true)
			arm('Top', line, length, 0, -space, Vector2.new(0.5, 1), fill, transparency, true)
			arm('Bottom', line, length, 0, space, Vector2.new(0.5, 0), fill, transparency, true)
		end
	end

	local centerticket = 0
	local centering = false

	local function positionscale(obj)
		local value = 1
		local current = obj and obj.Parent
		while current do
			if current:IsA('GuiObject') then
				for _, child in ipairs(current:GetChildren()) do
					if child:IsA('UIScale') then
						value *= child.Scale
					end
				end
			end
			current = current.Parent
		end
		return math.max(value, 0.01)
	end

	local function viewportcenter()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
			viewport = Vector2.new(1920, 1080)
		end
		return viewport / 2
	end

	local function center()
		if not overlay or not overlay.Object or not holder then return end
		centerticket += 1
		local ticket = centerticket

		task.spawn(function()
			centering = true
			for _ = 1, 4 do
				run.RenderStepped:Wait()
				if ticket ~= centerticket
					or not overlay
					or not overlay.Object
					or not overlay.Object.Parent
					or not holder
					or not holder.Parent then
					centering = false
					return
				end

				local rendered = holder.AbsolutePosition + (holder.AbsoluteSize / 2)
				local delta = viewportcenter() - rendered
				if math.abs(delta.X) <= 0.25 and math.abs(delta.Y) <= 0.25 then
					break
				end

				local factor = positionscale(overlay.Object)
				local position = overlay.Object.Position
				overlay.Object.Position = UDim2.new(
					position.X.Scale,
					position.X.Offset + (delta.X / factor),
					position.Y.Scale,
					position.Y.Offset + (delta.Y / factor)
				)
			end
			centering = false
		end)
	end

	overlay = vape:CreateOverlay({
		Name = 'Crosshair',
		Icon = icon,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(11, 12),
		CategorySize = 220,
		Function = function(on)
			if holder then holder.Visible = on end
		end
	})

	if not present and iconpath and ctx.store.fs.write then
		task.spawn(function()
			local ok, body = pcall(game.HttpGet, game, ctx.loader.base..'/assets/crosshair.png', true)
			if not ok or type(body) ~= 'string' or #body <= 8 or not ctx.store:write('assets/crosshair.png', body) then return end
			local get = vape.Libraries and vape.Libraries.getcustomasset or getcustomasset
			if type(get) ~= 'function' then return end
			local got, val = pcall(get, iconpath)
			if not got or type(val) ~= 'string' or val == '' or not overlay or not overlay.Object then return end
			local head = overlay.Object:FindFirstChildWhichIsA('ImageLabel')
			local button = overlay.Button and overlay.Button.Object and overlay.Button.Object:FindFirstChild('Icon')
			if head then head.Image = val end
			if button then button.Image = val end
		end)
	end

	ctx:clean(function()
		if type(vape.Overlays) == 'table' and type(vape.Overlays.Toggles) == 'table' then
			for i = #vape.Overlays.Toggles, 1, -1 do
				if vape.Overlays.Toggles[i] == overlay.Button then
					table.remove(vape.Overlays.Toggles, i)
				end
			end
		end
		if vape.Categories and vape.Categories.Crosshair == overlay then
			if overlay.Button and overlay.Button.Enabled then pcall(overlay.Button.Toggle, overlay.Button) end
			pcall(vape.Remove, vape, 'Crosshair')
		end
	end)

	holder = Instance.new('Frame')
	holder.Name = 'Crosshair'
	holder.Size = UDim2.fromOffset(160, 160)
	holder.Position = UDim2.fromOffset(110, 41)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.ZIndex = 1000000
	holder.Parent = overlay.Object

	style = overlay:CreateDropdown({
		Name = 'Style',
		List = {'Classic', 'Dot', 'Circle'},
		Function = draw
	})

	color = overlay:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		DefaultSat = 0,
		DefaultValue = 1,
		DefaultOpacity = 1,
		Function = draw
	})

	size = overlay:CreateSlider({
		Name = 'Size',
		Min = 2,
		Max = 40,
		Default = 12,
		Function = draw
	})

	thickness = overlay:CreateSlider({
		Name = 'Thickness',
		Min = 1,
		Max = 10,
		Default = 2,
		Function = draw
	})

	gap = overlay:CreateSlider({
		Name = 'Gap',
		Min = 0,
		Max = 30,
		Default = 6,
		Function = draw
	})

	outline = overlay:CreateToggle({
		Name = 'Outline',
		Default = true,
		Function = draw
	})

	outlinewidth = overlay:CreateSlider({
		Name = 'Outline Thickness',
		Min = 1,
		Max = 5,
		Default = 1,
		Function = draw
	})

	local centerlocked = false
	overlay:CreateButton({
		Name = 'Center Crosshair',
		Function = function()
			centerlocked = true
			center()
		end
	})

	ctx:clean(overlay.Object:GetPropertyChangedSignal('Position'):Connect(function()
		if not centering then centerlocked = false end
	end))

	local cameraconnection
	local function watchcamera()
		if cameraconnection then
			cameraconnection:Disconnect()
			cameraconnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraconnection = camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
				if centerlocked then center() end
			end)
		end
	end
	watchcamera()
	ctx:clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		watchcamera()
		if centerlocked then center() end
	end))
	ctx:clean(function()
		if cameraconnection then cameraconnection:Disconnect() end
	end)

	center()
	if not overlay.Pinned then overlay:Pin() end
	draw()

	pcall(function()
		vape:Load(true)
	end)

end
]],
		['src/patches/render/manifest.lua'] = [[return {
	files = {
		'crosshair.lua',
		'modulemanager.lua'
	}
}
]],
		['src/patches/render/modulemanager.lua'] = [[return function(ctx)
	local vape = ctx.vape
	if ctx.target.gui ~= 'new' or type(vape) ~= 'table'
		or type(vape.CreateCategory) ~= 'function'
		or type(vape.Categories) ~= 'table'
		or type(vape.Modules) ~= 'table' then
		return
	end

	local tweenservice = game:GetService('TweenService')
	local runservice = game:GetService('RunService')
	local players = game:GetService('Players')
	local textservice = game:GetService('TextService')
	local inputservice = game:GetService('UserInputService')
	local alive = true
	local ticket = 0
	local profile
	local migrate = false
	local state = {
		favorites = {},
		hidden = {},
		editing = false,
		favoritewindow = {Enabled = false}
	}
	local decorated = {}
	local headers = {}
	local rows = {}
	local apiold = {}
	local assets = {}
	local fav
	local favchildren
	local favbutton
	local openfavorite
	local restoringwindow = false
	local palette
	local bounds = Instance.new('GetTextBoundsParams')
	bounds.Width = math.huge
	ctx:clean(bounds)

	local function isinst(obj)
		return typeof(obj) == 'Instance'
	end

	local function clone(tab)
		local out = {}
		for key, value in pairs(tab or {}) do
			out[key] = value
		end
		return out
	end

	local function tomap(tab)
		local out = {}
		if type(tab) ~= 'table' then return out end
		for key, value in pairs(tab) do
			local name = type(key) == 'number' and value or value and key
			if type(name) == 'string' and name ~= '' then
				out[name] = true
			end
		end
		return out
	end

	local function tolist(tab)
		local out = {}
		for name, enabled in pairs(tab or {}) do
			if enabled then out[#out + 1] = name end
		end
		table.sort(out)
		return out
	end

	local function asset(name)
		if assets[name] ~= nil then return assets[name] end
		local rel = 'assets/gui/'..name
		local full = ctx.store:path(rel)
		local present = false
		if full and type(isfile) == 'function' then
			local ok, value = pcall(isfile, full)
			present = ok and value == true
		end
		local get = vape.Libraries and vape.Libraries.getcustomasset or getcustomasset
		if present and type(get) == 'function' then
			local ok, value = pcall(get, full)
			if ok and type(value) == 'string' then
				assets[name] = value
				return value
			end
		end
		assets[name] = ''
		return ''
	end

	local favoriteoff = asset('favoriteoff.png')
	local favoriteon = asset('favoriteon.png')
	local favoriteofftab = asset('favoriteofftab.png')
	local hiddeneyeoff = asset('hiddeneyeoff.png')
	local editasset = asset('edit.png')

	local function fetch(name, done)
		if assets[name] ~= '' then return end
		task.spawn(function()
			local rel = 'assets/gui/'..name
			local full = ctx.store:path(rel)
			if not full or not ctx.store.fs.write then return end
			local ok, body = pcall(game.HttpGet, game, ctx.loader.base..'/'..rel, true)
			if not ok or type(body) ~= 'string' or #body <= 8 or not ctx.store:write(rel, body) then return end
			local get = vape.Libraries and vape.Libraries.getcustomasset or getcustomasset
			if type(get) ~= 'function' then return end
			local got, value = pcall(get, full)
			if not got or type(value) ~= 'string' or value == '' then return end
			assets[name] = value
			if alive and type(done) == 'function' then done(value) end
		end)
	end

	local function getpalette()
		if palette then return palette end
		local cat
		for name, value in pairs(vape.Categories) do
			if name ~= 'Main' and name ~= 'Favorites' and type(value) == 'table'
				and value.Type == 'Category' and isinst(value.Object) then
				cat = value
				break
			end
		end
		local row
		for _, mod in pairs(vape.Modules) do
			if type(mod) == 'table' and isinst(mod.Object) then
				row = mod.Object
				break
			end
		end
		local window = cat and cat.Object
		local title = window and (window:FindFirstChild('Title') or window:FindFirstChildWhichIsA('TextLabel'))
		local dots = row and row:FindFirstChild('Dots')
		dots = dots and dots:FindFirstChild('Dots')
		local font = title and title.FontFace or row and row.FontFace or Font.fromEnum(Enum.Font.Arial)
		palette = {
			main = window and window.BackgroundColor3 or Color3.fromRGB(26, 25, 26),
			text = title and title.TextColor3 or Color3.fromRGB(200, 200, 200),
			inactive = dots and dots.ImageColor3 or Color3.fromRGB(120, 120, 128),
			font = font,
			semibold = Font.new(font.Family, Enum.FontWeight.SemiBold)
		}
		return palette
	end

	local function shifted(col, amount, light)
		local pal = getpalette()
		local h, s, v = col:ToHSV()
		local _, _, mainv = pal.main:ToHSV()
		local delta
		if light then
			delta = mainv > 0.5 and -amount or amount
		else
			delta = mainv > 0.5 and amount or -amount
		end
		return Color3.fromHSV(h, s, math.clamp(v + delta, 0, 1))
	end

	local function light(col, amount)
		return shifted(col, amount, true)
	end

	local function dark(col, amount)
		return shifted(col, amount, false)
	end

	local function textwidth(text, size, font)
		bounds.Text = tostring(text or '')
		bounds.Size = size
		bounds.Font = font
		local ok, value = pcall(textservice.GetTextBoundsAsync, textservice, bounds)
		return ok and value.X or (#bounds.Text * size * 0.55)
	end

	local function tween(obj, info, goal)
		if not isinst(obj) then return end
		local ok, value = pcall(tweenservice.Create, tweenservice, obj, info, goal)
		if ok then value:Play() end
	end

	local function pulse(obj)
		if not isinst(obj) then return end
		if obj:IsA('ImageButton') or obj:IsA('ImageLabel') then
			local size = obj:GetAttribute('VTOriginalSize') or obj.Size
			obj:SetAttribute('VTOriginalSize', size)
			tween(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(size.X.Offset + 3, size.Y.Offset + 3)
			})
			task.delay(0.08, function()
				if alive and isinst(obj) and obj.Parent then
					tween(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = size})
				end
			end)
			return
		end
		local size = obj:GetAttribute('VTOriginalTextSize') or obj.TextSize
		obj:SetAttribute('VTOriginalTextSize', size)
		tween(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = size + 3})
		task.delay(0.08, function()
			if alive and isinst(obj) and obj.Parent then
				tween(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = size})
			end
		end)
	end

	local function activecolor()
		return Color3.fromRGB(255, 170, 42)
	end

	local function starvisual(star, active, hover)
		if not isinst(star) then return end
		local pal = getpalette()
		local image = (star:IsA('ImageButton') or star:IsA('ImageLabel')) and star or star:FindFirstChild('VTImage')
		if image and (image:IsA('ImageButton') or image:IsA('ImageLabel')) then
			image.Image = active and favoriteon or favoriteoff
			tween(image, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				ImageColor3 = active and Color3.new(1, 1, 1)
					or hover and dark(pal.text, 0.16) or light(pal.main, 0.37),
				ImageTransparency = 0
			})
			return
		end
		tween(star, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = active and activecolor()
				or hover and dark(pal.text, 0.16) or light(pal.main, 0.37)
		})
	end

	local function placeid()
		return tostring(math.floor(tonumber(game.PlaceId) or 0))
	end

	local function configpath(dir, id)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/'..tostring(id or placeid())..'.lua'
	end

	local function legacyconfigpath(dir)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/gui.json'
	end

	local function migrationpath(dir)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/placeconfigs.migrated'
	end

	local function luastr(value)
		return string.format('%q', tostring(value))
	end

	local function lualist(values)
		local out = {}
		for index, value in ipairs(values or {}) do
			out[index] = luastr(value)
		end
		return '{'..table.concat(out, ', ')..'}'
	end

	local function number(value, fallback)
		value = tonumber(value)
		if not value or value ~= value or value == math.huge or value == -math.huge then
			return fallback or 0
		end
		return value
	end

	local function readconfig(path)
		local raw = ctx.store:read(path)
		if not raw then return nil end
		local compiled, err = loadstring(raw)
		if not compiled then
			ctx.log:add('config_parse', path, err)
			return nil
		end
		local ok, data = pcall(compiled)
		if ok and type(data) == 'table' then return data end
		ctx.log:add('config_parse', path, ok and 'config did not return a table' or data)
	end

	local function syncapi()
		vape.Favorites = vape.Favorites or {}
		vape.Favorites.List = tolist(state.favorites)
		vape.Favorites.Rows = rows
		vape.Favorites.StarButton = favbutton
		vape.Favorites.Window = fav
		vape.Hidden = vape.Hidden or {}
		vape.Hidden.List = tolist(state.hidden)
		vape.Hidden.Editing = state.editing
	end

	local function favoritewindow()
		local saved = state.favoritewindow or {Enabled = false}
		if fav and isinst(fav.Object) then
			local position = fav.Object.Position
			saved = {
				Enabled = fav.Button and fav.Button.Enabled == true or false,
				Expanded = fav.Expanded == true,
				Position = {
					XScale = position.X.Scale,
					X = position.X.Offset,
					YScale = position.Y.Scale,
					Y = position.Y.Offset
				}
			}
		end
		state.favoritewindow = saved
		return saved
	end

	local function configsource()
		local window = favoritewindow()
		local position = window.Position or window.position or {}
		return table.concat({
			'return {',
			'\tversion = 4,',
			'\tplaceid = '..placeid()..',',
			'\tfavorites = '..lualist(tolist(state.favorites))..',',
			'\thidden = '..lualist(tolist(state.hidden))..',',
			'\ttabs = {',
			'\t\tFavorites = {',
			'\t\t\tEnabled = '..tostring(window.Enabled == true)..',',
			'\t\t\tExpanded = '..tostring(window.Expanded == true)..',',
			'\t\t\tPosition = {',
			'\t\t\t\tXScale = '..tostring(number(position.XScale or position.xscale, 0))..',',
			'\t\t\t\tX = '..tostring(number(position.X or position.XOffset or position.x or position.xoffset, 0))..',',
			'\t\t\t\tYScale = '..tostring(number(position.YScale or position.yscale, 0))..',',
			'\t\t\t\tY = '..tostring(number(position.Y or position.YOffset or position.y or position.yoffset, 0)),
			'\t\t\t}',
			'\t\t}',
			'\t}',
			'}'
		}, '\n')
	end

	local function save(dir)
		if not alive then return false end
		return ctx.store:write(configpath(dir), configsource())
	end

	local function queuesave()
		ticket = ticket + 1
		local current = ticket
		task.delay(0.35, function()
			if alive and ticket == current then save() end
		end)
	end

	local function load()
		profile = ctx.profile and ctx.profile.dir or 'default'
		local file = configpath(profile)
		local data = readconfig(file)
		local created = type(data) ~= 'table'
		if data and tonumber(data.placeid) ~= tonumber(game.PlaceId) then
			data = nil
			created = true
		end

		if not data and not ctx.store:has(migrationpath(profile)) then
			local legacy = ctx.store:json(legacyconfigpath(profile))
			if type(legacy) == 'table' then data = legacy end
			ctx.store:write(migrationpath(profile), placeid())
		end

		state.favorites = tomap(data and data.favorites)
		state.hidden = tomap(data and data.hidden)
		local tabs = data and data.tabs
		local window = type(tabs) == 'table' and (tabs.Favorites or tabs.favorites)
			or data and data.favoritewindow
		local position = type(window) == 'table' and (window.Position or window.position)
		state.favoritewindow = {
			Enabled = type(window) == 'table' and (window.Enabled == true or window.enabled == true) or false,
			Expanded = type(window) == 'table' and (window.Expanded == true or window.expanded == true) or false,
			Position = type(position) == 'table' and {
				XScale = number(position.XScale or position.xscale, 0),
				X = number(position.X or position.XOffset or position.x or position.xoffset, 0),
				YScale = number(position.YScale or position.yscale, 0),
				Y = number(position.Y or position.YOffset or position.y or position.yoffset, 0)
			} or nil
		}
		state.editing = false
		migrate = created or not ctx.store:has(file)
		syncapi()
	end

	local function accent(mod)
		local gui = vape.GUIColor
		if type(gui) == 'table' then
			local h = tonumber(gui.Hue) or 0.46
			local s = tonumber(gui.Sat) or 0.96
			local v = tonumber(gui.Value) or 0.52
			if gui.Rainbow and type(vape.Color) == 'function' then
				local ok, ch, cs, cv = pcall(vape.Color, vape, (h - (((mod and mod.Index) or 1) * 0.025)) % 1)
				if ok then
					if typeof(ch) == 'Color3' then return ch end
					if type(ch) == 'number' then return Color3.fromHSV(ch, cs or 1, cv or 1) end
				end
			end
			return Color3.fromHSV(h, s, v)
		end
		return Color3.fromRGB(5, 134, 105)
	end

	local function corner(parent, radius)
		local value = Instance.new('UICorner')
		value.CornerRadius = radius or UDim.new(0, 5)
		value.Parent = parent
		return value
	end

	local function makehiddenrail(parent, zindex)
		local rail = Instance.new('Frame')
		rail.Name = 'VTHiddenRail'
		rail.Size = UDim2.new(0, 43, 1, 0)
		rail.Position = UDim2.fromOffset(0, 0)
		rail.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		rail.BackgroundTransparency = 0
		rail.BorderSizePixel = 0
		rail.Visible = false
		rail.ZIndex = zindex or parent.ZIndex
		rail.Parent = parent
		return rail
	end

	local function makehiddenbox(parent, zindex)
		local box = Instance.new('TextButton')
		box.Name = 'HiddenBox'
		box.Size = UDim2.fromOffset(12, 12)
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.new(0, 21.5, 0.5, 0)
		box.BackgroundColor3 = Color3.fromRGB(52, 52, 58)
		box.BackgroundTransparency = 0
		box.BorderSizePixel = 0
		box.AutoButtonColor = false
		box.Visible = false
		box.Text = ''
		box.ZIndex = zindex or parent.ZIndex
		box.Parent = parent

		local gap = Instance.new('Frame')
		gap.Name = 'Outline'
		gap.Size = UDim2.new(1, -2, 1, -2)
		gap.Position = UDim2.fromOffset(1, 1)
		gap.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		gap.BackgroundTransparency = 0
		gap.BorderSizePixel = 0
		gap.ZIndex = box.ZIndex
		gap.Parent = box

		local fill = Instance.new('Frame')
		fill.Name = 'Fill'
		fill.Size = UDim2.new(1, -4, 1, -4)
		fill.Position = UDim2.fromOffset(2, 2)
		fill.BackgroundTransparency = 1
		fill.BorderSizePixel = 0
		fill.ZIndex = box.ZIndex + 1
		fill.Parent = box
		return box, gap, fill
	end

	local function updatehiddenbox(box, gap, fill, hidden, mod)
		if not isinst(box) or not isinst(gap) or not isinst(fill) then return end
		local color = hidden and Color3.fromRGB(52, 52, 58) or accent(mod)
		box.BackgroundColor3 = color
		box.BackgroundTransparency = 0
		gap.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		gap.BackgroundTransparency = 0
		fill.BackgroundColor3 = color
		fill.BackgroundTransparency = hidden and 1 or 0
	end

	local refreshfavorites
	local updateheaders
	local applymodule
	local updatefavoriterow

	local function isfavorite(name)
		return state.favorites[name] == true
	end

	local function ishidden(name)
		return state.hidden[name] == true
	end

	local function bindkeys(mod)
		local bind = type(mod) == 'table' and mod.Bind
		if type(bind) ~= 'table' then return {} end
		if type(bind.Keys) == 'table' then return bind.Keys end
		local out = {}
		for i, key in ipairs(bind) do
			if type(key) == 'string' then out[i] = key end
		end
		return out
	end

	local function hiddenincategory(category)
		local count = 0
		for _, mod in pairs(vape.Modules) do
			if type(mod) == 'table' and mod.Category == category and ishidden(mod.Name) then
				count = count + 1
			end
		end
		return count
	end

	local function restorechildren(data, hide)
		if not data or not data.favoriteopen or not isinst(data.children) then return end
		data.children.Visible = false
		if isinst(data.originalparent) then
			data.children.Parent = data.originalparent
			data.children.LayoutOrder = data.originalorder
		end
		data.favoriteopen = false
		if openfavorite == data then openfavorite = nil end
		if not hide then data.children.Visible = false end
		if applymodule then applymodule(data.mod) end
		if updatefavoriterow then updatefavoriterow(data.mod.Name) end
	end

	local function closefavoritechildren()
		if openfavorite then restorechildren(openfavorite, true) end
	end

	local function setfavoritechildren(data, enabled, order)
		if not data or not isinst(data.children) or state.editing then return end
		if not enabled then
			restorechildren(data, true)
			return
		end
		if openfavorite and openfavorite ~= data then restorechildren(openfavorite, true) end
		if data.children.Parent ~= data.originalparent and not data.favoriteopen then
			data.originalparent = data.children.Parent
			data.originalorder = data.children.LayoutOrder
		end
		data.children.Visible = false
		data.children.Parent = favchildren
		data.children.LayoutOrder = order
		data.children.Visible = true
		data.favoriteopen = true
		openfavorite = data
		applymodule(data.mod)
		updatefavoriterow(data.mod.Name)
	end

	local function setfavorite(name, enabled, skipsave)
		local mod = vape.Modules[name]
		if type(mod) ~= 'table' then return end
		state.favorites[name] = enabled and true or nil
		mod.Favorited = enabled and true or false
		local data = decorated[mod]
		if not enabled and data and data.favoriteopen then restorechildren(data, true) end
		syncapi()
		applymodule(mod)
		refreshfavorites()
		if not skipsave then queuesave() end
	end

	local function sethidden(name, enabled, skipsave)
		local mod = vape.Modules[name]
		if type(mod) ~= 'table' then return end
		state.hidden[name] = enabled and true or nil
		local data = decorated[mod]
		if enabled and data then
			if data.favoriteopen then restorechildren(data, true) end
			if isinst(data.children) then data.children.Visible = false end
		end
		syncapi()
		applymodule(mod)
		refreshfavorites()
		updateheaders()
		if not skipsave then queuesave() end
	end

	local function setediting(enabled)
		state.editing = enabled and true or false
		if state.editing then
			closefavoritechildren()
			for _, data in pairs(decorated) do
				if isinst(data.children) then data.children.Visible = false end
			end
		end
		syncapi()
		for _, data in pairs(decorated) do applymodule(data.mod) end
		refreshfavorites()
		updateheaders()
	end

	local function cleanstale(parent)
		if not isinst(parent) then return end
		for _, name in ipairs({
			'VTFavorite', 'VTHideShield', 'VTHideGuard', 'VTEditHidden',
			'VTDoneHidden', 'VTHiddenCount', 'VTHiddenRail', 'Favorite', 'HiddenBox',
			'EditHiddenModules', 'DoneHiddenModules', 'HiddenCount'
		}) do
			local child = parent:FindFirstChild(name)
			if child then child:Destroy() end
		end
	end

	local function addheader(name, cat)
		if headers[name] or name == 'Main' or type(cat) ~= 'table'
			or cat.Type ~= 'Category' or not isinst(cat.Object) then return end
		local window = cat.Object
		local native = cat.Done
		local pencil
		for _, obj in ipairs(window:GetChildren()) do
			if obj:IsA('TextButton') and obj ~= native
				and obj.Position.X.Scale == 1 and obj.Position.X.Offset == -49
				and obj.Size.X.Offset == 20 and obj.Size.Y.Offset == 40 then
				pencil = obj
				break
			end
		end
		if isinst(native) then native.Visible = false end
		if isinst(pencil) then pencil.Visible = false end
		cleanstale(window)
		local pal = getpalette()

		local edit = Instance.new('TextButton')
		edit.Name = 'EditHiddenModules'
		edit.Size = UDim2.fromOffset(30, 40)
		edit.Position = UDim2.new(1, -61, 0, 0)
		edit.BackgroundTransparency = 1
		edit.AutoButtonColor = false
		edit.Visible = false
		edit.Text = ''
		edit.Parent = window

		local editicon = Instance.new('ImageLabel')
		editicon.Name = 'Icon'
		editicon.Size = UDim2.fromOffset(12, 12)
		editicon.Position = UDim2.fromOffset(11, 14)
		editicon.BackgroundTransparency = 1
		editicon.Image = editasset
		editicon.ImageColor3 = light(pal.main, 0.37)
		editicon.Parent = edit

		local done = Instance.new('TextButton')
		done.Name = 'DoneHiddenModules'
		done.Size = UDim2.fromOffset(58, 40)
		done.Position = UDim2.new(1, -75, 0, 0)
		done.BackgroundTransparency = 1
		done.AutoButtonColor = false
		done.Visible = false
		done.Text = 'DONE'
		done.TextColor3 = dark(pal.text, 0.16)
		done.TextSize = 12
		done.FontFace = pal.font
		done.Parent = window

		local count = Instance.new('Frame')
		count.Name = 'HiddenCount'
		count.Size = UDim2.fromOffset(40, 40)
		count.Position = UDim2.new(1, -60, 0, 0)
		count.BackgroundTransparency = 1
		count.Visible = false
		count.Parent = window

		local number = Instance.new('TextLabel')
		number.Name = 'Count'
		number.Size = UDim2.fromOffset(12, 40)
		number.Position = UDim2.fromOffset(3, 0)
		number.BackgroundTransparency = 1
		number.Text = '0'
		number.TextColor3 = Color3.fromRGB(145, 145, 153)
		number.TextSize = 13
		number.FontFace = pal.font
		number.Parent = count

		local eye = Instance.new('ImageLabel')
		eye.Name = 'Eye'
		eye.Size = UDim2.fromOffset(22, 22)
		eye.Position = UDim2.fromOffset(13, 9)
		eye.BackgroundTransparency = 1
		eye.Image = hiddeneyeoff
		eye.ImageColor3 = Color3.fromRGB(118, 118, 126)
		eye.ImageTransparency = 0
		eye.ScaleType = Enum.ScaleType.Fit
		eye.Parent = count

		local data = {
			name = name,
			cat = cat,
			window = window,
			native = native,
			pencil = pencil,
			edit = edit,
			editicon = editicon,
			done = done,
			count = count,
			number = number,
			hover = false
		}
		headers[name] = data

		if isinst(native) then
			ctx:clean(native:GetPropertyChangedSignal('Visible'):Connect(function()
				if alive and native.Visible then native.Visible = false end
			end))
		end
		if isinst(pencil) then
			ctx:clean(pencil:GetPropertyChangedSignal('Visible'):Connect(function()
				if alive and pencil.Visible then pencil.Visible = false end
			end))
		end

		ctx:clean(edit.MouseEnter:Connect(function()
			editicon.ImageColor3 = pal.text
		end))
		ctx:clean(edit.MouseLeave:Connect(function()
			editicon.ImageColor3 = light(pal.main, 0.37)
		end))
		ctx:clean(edit.MouseButton1Click:Connect(function()
			setediting(true)
		end))
		ctx:clean(done.MouseEnter:Connect(function()
			done.TextColor3 = pal.text
		end))
		ctx:clean(done.MouseLeave:Connect(function()
			done.TextColor3 = dark(pal.text, 0.16)
		end))
		ctx:clean(done.MouseButton1Click:Connect(function()
			setediting(false)
		end))
		ctx:clean(window.MouseEnter:Connect(function()
			data.hover = true
			updateheaders()
		end))
		ctx:clean(window.MouseLeave:Connect(function()
			data.hover = false
			updateheaders()
		end))
	end

	updateheaders = function()
		vape.EditGUI = false
		for name, data in pairs(headers) do
			local count = hiddenincategory(name)
			if isinst(data.native) then data.native.Visible = false end
			if isinst(data.pencil) then data.pencil.Visible = false end
			data.number.Text = tostring(count)
			data.done.Visible = state.editing
			data.edit.Visible = not state.editing and data.hover
			data.count.Visible = not state.editing and not data.hover and count > 0
		end
	end

	local function addmodule(mod)
		if type(mod) ~= 'table' or decorated[mod] or type(mod.Name) ~= 'string'
			or not isinst(mod.Object) then return end
		local row = mod.Object
		cleanstale(row)
		local pal = getpalette()
		local normal = '            '..mod.Name:gsub(' ', '')
		local edittext = '    '..mod.Name:gsub(' ', '')
		row.Text = normal

		local star = Instance.new('TextButton')
		star.Name = 'Favorite'
		star.Size = UDim2.fromOffset(22, 22)
		star.Position = UDim2.new(1, -61, 0, 8)
		star.AnchorPoint = Vector2.new(1, 0)
		star.BackgroundTransparency = 1
		star.AutoButtonColor = false
		star.Visible = false
		star.Text = '★'
		star.TextSize = 22
		star.FontFace = pal.semibold
		star.TextColor3 = light(pal.main, 0.37)
		star.ZIndex = row.ZIndex + 20
		star.Parent = row

		local guard = Instance.new('TextButton')
		guard.Name = 'VTHideGuard'
		guard.Size = UDim2.fromScale(1, 1)
		guard.BackgroundTransparency = 1
		guard.BorderSizePixel = 0
		guard.AutoButtonColor = false
		guard.Visible = false
		guard.Text = ''
		guard.ZIndex = row.ZIndex + 30
		guard.Parent = row

		local rail = makehiddenrail(row, row.ZIndex + 29)
		local hiddenbox, outline, fill = makehiddenbox(row, row.ZIndex + 31)
		local dots = row:FindFirstChild('Dots')
		local bind = row:FindFirstChild('Bind')
		local children = mod.Children
		local native = mod.SetVisible
		local edit = mod.Edit
		local data = {
			mod = mod,
			row = row,
			star = star,
			guard = guard,
			rail = rail,
			hiddenbox = hiddenbox,
			outline = outline,
			fill = fill,
			dots = dots,
			bind = bind,
			children = children,
			native = native,
			edit = edit,
			originalparent = isinst(children) and children.Parent or nil,
			originalorder = isinst(children) and children.LayoutOrder or 0,
			normal = normal,
			edittext = edittext,
			starhover = false,
			hover = false,
			favoriteopen = false,
			oldfields = {
				Favorited = mod.Favorited,
				FavoriteStar = mod.FavoriteStar,
				HiddenBox = mod.HiddenBox,
				HiddenBoxOutline = mod.HiddenBoxOutline,
				HiddenBoxFill = mod.HiddenBoxFill,
				NormalText = mod.NormalText,
				EditHiddenText = mod.EditHiddenText,
				UpdateHiddenBox = mod.UpdateHiddenBox,
				UpdateFavoriteVisual = mod.UpdateFavoriteVisual,
				ApplyHiddenState = mod.ApplyHiddenState,
				SetChildrenVisible = mod.SetChildrenVisible,
				SetFavoriteChildrenVisible = mod.SetFavoriteChildrenVisible,
				FavoriteRow = mod.FavoriteRow,
				SetVisible = mod.SetVisible
			}
		}
		decorated[mod] = data

		mod.Visible = true
		if isinst(edit) then edit.Visible = false end
		if type(native) == 'function' then
			mod.SetVisible = function(self, visible, loading)
				self.Visible = true
				if alive and not loading then sethidden(self.Name, visible == false) end
				return true
			end
		end

		mod.Favorited = isfavorite(mod.Name)
		mod.FavoriteStar = star
		mod.HiddenBox = hiddenbox
		mod.HiddenBoxOutline = outline
		mod.HiddenBoxFill = fill
		mod.NormalText = normal
		mod.EditHiddenText = edittext
		mod.UpdateHiddenBox = function(self)
			updatehiddenbox(hiddenbox, outline, fill, ishidden(self.Name), self)
		end
		mod.UpdateFavoriteVisual = function(self)
			starvisual(star, isfavorite(self.Name), data.starhover)
		end
		mod.ApplyHiddenState = function(self)
			applymodule(self)
		end
		mod.SetChildrenVisible = function(self, enabled)
			if state.editing or not isinst(children) then return end
			if data.favoriteopen then restorechildren(data, true) end
			children.Parent = data.originalparent
			children.LayoutOrder = data.originalorder
			children.Visible = enabled and true or false
			applymodule(self)
		end
		mod.SetFavoriteChildrenVisible = function(_, enabled, customparent, order)
			setfavoritechildren(data, enabled, order or 1)
		end

		ctx:clean(row.MouseEnter:Connect(function()
			data.hover = true
			applymodule(mod)
		end))
		ctx:clean(row.MouseLeave:Connect(function()
			data.hover = false
			applymodule(mod)
		end))
		ctx:clean(star.MouseButton1Down:Connect(function()
			data.starclick = true
		end))
		ctx:clean(star.MouseEnter:Connect(function()
			data.starhover = true
			starvisual(star, isfavorite(mod.Name), true)
		end))
		ctx:clean(star.MouseLeave:Connect(function()
			data.starhover = false
			starvisual(star, isfavorite(mod.Name), false)
		end))
		ctx:clean(star.MouseButton1Click:Connect(function()
			pulse(star)
			setfavorite(mod.Name, not isfavorite(mod.Name))
			data.starclick = false
		end))
		ctx:clean(hiddenbox.MouseButton1Click:Connect(function()
			sethidden(mod.Name, not ishidden(mod.Name))
		end))
		if isinst(children) then
			ctx:clean(children:GetPropertyChangedSignal('Visible'):Connect(function()
				applymodule(mod)
				if rows[mod.Name] then updatefavoriterow(mod.Name) end
			end))
			ctx:clean(children:GetPropertyChangedSignal('Parent'):Connect(function()
				applymodule(mod)
			end))
		end
		ctx:clean(row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 and data.favoriteopen then
				restorechildren(data, true)
			end
		end))
		if isinst(dots) then
			ctx:clean(dots.InputBegan:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2) and data.favoriteopen then
					restorechildren(data, true)
				end
			end))
		end
		applymodule(mod)
	end

	applymodule = function(mod)
		local data = decorated[mod]
		if not data or not isinst(data.row) then return end
		local hidden = ishidden(mod.Name)
		local editing = state.editing
		if hidden and not editing then
			if data.favoriteopen then restorechildren(data, true) end
			if isinst(data.children) then data.children.Visible = false end
		end
		data.row.Visible = editing or not hidden
		data.guard.Visible = editing
		data.rail.Visible = editing
		data.hiddenbox.Visible = editing
		data.row.Text = editing and data.edittext or data.normal
		if isinst(data.dots) then data.dots.Visible = not editing end
		if isinst(data.edit) then data.edit.Visible = false end
		mod.Visible = true
		local originalopen = isinst(data.children) and data.children.Visible
			and data.children.Parent == data.originalparent and not data.favoriteopen
		if isinst(data.bind) then
			local keys = bindkeys(mod)
			local mobile = type(mod.Bind) == 'table' and mod.Bind.Mobile
			local bound = #keys > 0 or isinst(mobile)
			data.bind.Visible = not editing and (bound or data.hover or originalopen)
		end
		data.star.Visible = not editing and originalopen
		updatehiddenbox(data.hiddenbox, data.outline, data.fill, hidden, mod)
		starvisual(data.star, isfavorite(mod.Name), data.starhover)
		mod.Favorited = isfavorite(mod.Name)
	end

	local function guicolor()
		local gui = vape.GUIColor
		return tonumber(gui and gui.Hue) or 0, tonumber(gui and gui.Sat) or 0, tonumber(gui and gui.Value) or 1, gui and gui.Rainbow == true
	end

	local function vapecolor(h)
		if type(vape.Color) == 'function' then
			local ok, a, b, c = pcall(vape.Color, vape, h)
			if ok then return Color3.fromHSV(a, b, c) end
		end
		return Color3.fromHSV(h, 1, 1)
	end

	local function vapetext(h, s, v, rainbow)
		if rainbow then return Color3.new(0.19, 0.19, 0.19) end
		if type(vape.TextColor) == 'function' then
			local ok, col = pcall(vape.TextColor, vape, h, s, v)
			if ok and typeof(col) == 'Color3' then return col end
		end
		return Color3.new(1, 1, 1)
	end

	local function paintfavoriterow(data, mod)
		if not data or type(mod) ~= 'table' or not isinst(data.row) then return end
		local pal = getpalette()
		if not mod.Enabled then
			data.gradient.Enabled = false
			if not data.hover then
				data.row.TextColor3 = dark(pal.text, 0.16)
				data.row.BackgroundColor3 = pal.main
				data.dots.ImageColor3 = light(pal.main, 0.37)
			end
			data.bindicon.ImageColor3 = dark(pal.text, 0.43)
			data.bindtext.TextColor3 = dark(pal.text, 0.43)
			return
		end
		local h, s, v, rainbow = guicolor()
		local mode = vape.RainbowMode and vape.RainbowMode.Value or 'Normal'
		local sweep = rainbow and mode ~= 'Retro'
		local index = math.max(tonumber(data.index) or 0, 0)
		local text = vapetext(h, s, v, rainbow)
		if sweep then
			local h1 = (h - (index * 0.025)) % 1
			local h2 = (h - ((index + 1) * 0.025)) % 1
			if mode == 'Gradient' then
				data.row.BackgroundColor3 = Color3.new(1, 1, 1)
				data.gradient.Enabled = true
				data.gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, vapecolor(h1)),
					ColorSequenceKeypoint.new(1, vapecolor(h2))
				})
			else
				data.gradient.Enabled = false
				data.row.BackgroundColor3 = vapecolor(h1)
			end
		else
			data.gradient.Enabled = false
			data.row.BackgroundColor3 = Color3.fromHSV(h, s, v)
		end
		data.row.TextColor3 = text
		data.dots.ImageColor3 = text
		data.bindicon.ImageColor3 = text
		data.bindtext.TextColor3 = text
	end

	local function updatebindpreview(data)
		if not data or not isinst(data.bind) then return end
		if state.editing then
			data.bind.Visible = false
			return
		end
		local bindvalue = bindkeys(data.mod)
		local hasbind = #bindvalue > 0
		data.bind.Visible = data.hover or hasbind or data.moddata and data.moddata.favoriteopen
		if hasbind then
			data.bindtext.Visible = true
			data.bindicon.Visible = false
			data.bindtext.Text = table.concat(bindvalue, ' + '):upper()
			data.bind.Size = UDim2.fromOffset(math.max(textwidth(data.bindtext.Text, data.bindtext.TextSize, data.bindtext.FontFace) + 10, 20), 21)
		else
			data.bindtext.Visible = false
			data.bindicon.Visible = true
			data.bindicon.Image = data.bindasset
			data.bindicon.ImageColor3 = dark(getpalette().text, 0.43)
			data.bind.Size = UDim2.fromOffset(20, 21)
		end
	end

	local function createfavoriterow(mod)
		if rows[mod.Name] or not isinst(favchildren) then return end
		local pal = getpalette()
		local source = decorated[mod]
		if not source then return end
		local row = Instance.new('TextButton')
		row.Name = mod.Name
		row.Size = UDim2.fromOffset(220, 40)
		row.BackgroundColor3 = pal.main
		row.BorderSizePixel = 0
		row.AutoButtonColor = false
		row.Text = '            '..mod.Name:gsub(' ', '')
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = dark(pal.text, 0.16)
		row.TextSize = 14
		row.FontFace = pal.font
		row.Parent = favchildren

		local gradient = Instance.new('UIGradient')
		gradient.Rotation = 90
		gradient.Enabled = false
		gradient.Parent = row

		local rail = makehiddenrail(row, row.ZIndex + 1)
		local hiddenbox, outline, fill = makehiddenbox(row, row.ZIndex + 2)

		local bind = Instance.new('TextButton')
		bind.Name = 'BindPreview'
		bind.Size = UDim2.fromOffset(20, 21)
		bind.Position = UDim2.new(1, -36, 0, 9)
		bind.AnchorPoint = Vector2.new(1, 0)
		bind.BackgroundColor3 = Color3.new(1, 1, 1)
		bind.BackgroundTransparency = 0.92
		bind.BorderSizePixel = 0
		bind.AutoButtonColor = false
		bind.Visible = false
		bind.Text = ''
		bind.Parent = row
		corner(bind, UDim.new(0, 4))

		local sourcebind = source.bind
		local sourceicon = isinst(sourcebind) and sourcebind:FindFirstChild('Icon')
		local bindicon = Instance.new('ImageLabel')
		bindicon.Name = 'Icon'
		bindicon.Size = UDim2.fromOffset(12, 12)
		bindicon.Position = UDim2.new(0.5, -6, 0, 5)
		bindicon.BackgroundTransparency = 1
		bindicon.Image = sourceicon and sourceicon.Image or ''
		bindicon.ImageColor3 = dark(pal.text, 0.43)
		bindicon.Parent = bind

		local bindtext = Instance.new('TextLabel')
		bindtext.Name = 'Text'
		bindtext.Size = UDim2.fromScale(1, 1)
		bindtext.Position = UDim2.fromOffset(0, 1)
		bindtext.BackgroundTransparency = 1
		bindtext.Visible = false
		bindtext.Text = ''
		bindtext.TextColor3 = dark(pal.text, 0.43)
		bindtext.TextSize = 12
		bindtext.FontFace = pal.font
		bindtext.Parent = bind

		local sourcecover = source.row:FindFirstChild('Cover')
		local bindcover = Instance.new('ImageLabel')
		bindcover.Name = 'Cover'
		bindcover.Size = UDim2.fromOffset(154, 40)
		bindcover.BackgroundTransparency = 1
		bindcover.Visible = false
		bindcover.Image = sourcecover and sourcecover.Image or ''
		bindcover.ScaleType = Enum.ScaleType.Slice
		bindcover.SliceCenter = Rect.new(0, 0, 141, 40)
		bindcover.Parent = row

		local bindcovertext = Instance.new('TextLabel')
		bindcovertext.Name = 'Text'
		bindcovertext.Size = UDim2.new(1, -10, 1, -3)
		bindcovertext.BackgroundTransparency = 1
		bindcovertext.Text = 'PRESS A KEY TO BIND'
		bindcovertext.TextColor3 = pal.text
		bindcovertext.TextSize = 11
		bindcovertext.FontFace = pal.font
		bindcovertext.Parent = bindcover

		local dotsbutton = Instance.new('TextButton')
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(25, 40)
		dotsbutton.Position = UDim2.new(1, -25, 0, 0)
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Text = ''
		dotsbutton.Parent = row

		local sourcedots = source.dots and source.dots:FindFirstChild('Dots')
		local dots = Instance.new('ImageLabel')
		dots.Name = 'Dots'
		dots.Size = UDim2.fromOffset(3, 16)
		dots.Position = UDim2.fromOffset(4, 12)
		dots.BackgroundTransparency = 1
		dots.Image = sourcedots and sourcedots.Image or ''
		dots.ImageColor3 = light(pal.main, 0.37)
		dots.Parent = dotsbutton

		local data = {
			mod = mod,
			moddata = source,
			row = row,
			gradient = gradient,
			rail = rail,
			hiddenbox = hiddenbox,
			outline = outline,
			fill = fill,
			bind = bind,
			bindicon = bindicon,
			bindtext = bindtext,
			bindcover = bindcover,
			bindcovertext = bindcovertext,
			bindasset = bindicon.Image,
			dotsbutton = dotsbutton,
			dots = dots,
			hover = false,
			bindguard = false
		}
		rows[mod.Name] = data
		mod.FavoriteRow = row

		ctx:clean(row.MouseEnter:Connect(function()
			data.hover = true
			if not mod.Enabled then
				row.TextColor3 = pal.text
				row.BackgroundColor3 = light(pal.main, 0.02)
			end
			dots.ImageColor3 = pal.text
			updatebindpreview(data)
		end))
		ctx:clean(row.MouseLeave:Connect(function()
			data.hover = false
			updatefavoriterow(mod.Name)
			updatebindpreview(data)
		end))
		ctx:clean(row.MouseButton1Click:Connect(function()
			if state.editing then return end
			if data.bindguard then
				data.bindguard = false
				return
			end
			pcall(mod.Toggle, mod)
			updatefavoriterow(mod.Name)
		end))
		local function togglesettings()
			if state.editing then return end
			setfavoritechildren(source, not source.favoriteopen, row.LayoutOrder + 1)
			updatebindpreview(data)
		end
		ctx:clean(row.MouseButton2Click:Connect(togglesettings))
		ctx:clean(dotsbutton.MouseButton1Click:Connect(togglesettings))
		ctx:clean(dotsbutton.MouseButton2Click:Connect(togglesettings))
		ctx:clean(bind.MouseEnter:Connect(function()
			bindtext.Visible = false
			bindicon.Visible = true
			local edit = source.bind and source.bind:FindFirstChild('Icon')
			bindicon.Image = edit and edit.Image or bindicon.Image
			if editasset ~= '' then bindicon.Image = editasset end
			bindicon.ImageColor3 = dark(pal.text, 0.16)
		end))
		ctx:clean(bind.MouseLeave:Connect(function()
			updatebindpreview(data)
		end))
		ctx:clean(bind.MouseButton1Down:Connect(function()
			data.bindguard = true
		end))
		ctx:clean(bind.MouseButton1Click:Connect(function()
			if state.editing then return end
			bindcovertext.Text = 'PRESS A KEY TO BIND'
			bindcover.Size = UDim2.fromOffset(textwidth(bindcovertext.Text, bindcovertext.TextSize, bindcovertext.FontFace) + 20, 40)
			bindcover.Visible = true
			vape.Binding = {
				SetBind = function(_, tab, mouse)
					local bind = mod.Bind
					if type(bind) == 'table' and type(bind.SetBind) == 'function' then
						bind:SetBind(tab, mouse)
					elseif type(mod.SetBind) == 'function' then
						mod:SetBind(tab, mouse)
					end
					updatebindpreview(data)
					bindcovertext.Text = #tab <= 0 and 'BIND REMOVED' or 'BOUND TO'
					bindcover.Size = UDim2.fromOffset(textwidth(bindcovertext.Text, bindcovertext.TextSize, bindcovertext.FontFace) + 20, 40)
					task.delay(1, function()
						if alive and isinst(bindcover) then bindcover.Visible = false end
					end)
				end
			}
		end))
		ctx:clean(hiddenbox.MouseButton1Click:Connect(function()
			sethidden(mod.Name, not ishidden(mod.Name))
		end))
		updatebindpreview(data)
		updatefavoriterow(mod.Name)
	end

	updatefavoriterow = function(name)
		local data = rows[name]
		local mod = vape.Modules[name]
		if not data or type(mod) ~= 'table' or not isinst(data.row) then return end
		local hidden = ishidden(name)
		data.row.Visible = state.editing or not hidden
		data.row.Text = state.editing and ('    '..mod.Name:gsub(' ', ''))
			or ('            '..mod.Name:gsub(' ', ''))
		data.rail.Visible = state.editing
		data.hiddenbox.Visible = state.editing
		data.dotsbutton.Visible = not state.editing
		updatehiddenbox(data.hiddenbox, data.outline, data.fill, hidden, mod)
		if state.editing then data.bind.Visible = false end

		paintfavoriterow(data, mod)
		updatebindpreview(data)
	end

	refreshfavorites = function()
		for name, data in pairs(clone(rows)) do
			if not isfavorite(name) or type(vape.Modules[name]) ~= 'table' then
				if data.moddata and data.moddata.favoriteopen then restorechildren(data.moddata, true) end
				if isinst(data.row) then data.row:Destroy() end
				rows[name] = nil
			end
		end
		local list = tolist(state.favorites)
		for order, name in ipairs(list) do
			local mod = vape.Modules[name]
			if type(mod) == 'table' then
				createfavoriterow(mod)
				local data = rows[name]
				if data then
					data.index = order - 1
					data.row.LayoutOrder = order * 2
					if data.moddata.favoriteopen and isinst(data.moddata.children) then
						data.moddata.children.LayoutOrder = order * 2 + 1
					end
					updatefavoriterow(name)
				end
			end
		end
		syncapi()
		if favbutton then
			local open = fav and fav.Button and fav.Button.Enabled
			starvisual(favbutton, open, vape.Favorites and vape.Favorites.StarButtonHovered)
		end
	end

	local function addfavoritesbutton()
		if isinst(favbutton) then return end
		local main = vape.Categories.Main
		local root = main and main.Object
		local bar = root and root:FindFirstChild('Overlays', true)
		if not isinst(bar) then return end
		local old = bar:FindFirstChild('FavoritesButton')
		if old then old:Destroy() end
		local button = Instance.new(favoriteoff ~= '' and 'ImageButton' or 'TextButton')
		button.Name = 'FavoritesButton'
		button.Size = UDim2.fromOffset(21, 21)
		button.Position = UDim2.new(1, -52, 0, 8)
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		if button:IsA('ImageButton') then
			button.Image = favoriteoff
			button.ImageColor3 = light(getpalette().main, 0.37)
		else
			button.Text = '★'
			button.TextSize = 22
			button.FontFace = getpalette().semibold
			button.TextColor3 = light(getpalette().main, 0.37)
		end
		button.Parent = bar
		favbutton = button
		ctx:clean(button.MouseEnter:Connect(function()
			vape.Favorites.StarButtonHovered = true
			starvisual(button, fav and fav.Button and fav.Button.Enabled, true)
		end))
		ctx:clean(button.MouseLeave:Connect(function()
			vape.Favorites.StarButtonHovered = false
			starvisual(button, fav and fav.Button and fav.Button.Enabled, false)
		end))
		ctx:clean(button.MouseButton1Click:Connect(function()
			pulse(button)
			if not fav or not fav.Button then return end
			fav.Button:Toggle()
			if fav.Button.Enabled and not fav.Expanded and type(fav.Expand) == 'function' then
				fav:Expand()
			end
			starvisual(button, fav.Button.Enabled, false)
		end))
		syncapi()
		starvisual(button, fav and fav.Button and fav.Button.Enabled, false)
	end

	local function applyfavoritewindow()
		if not fav or not isinst(fav.Object) or not fav.Button then return end
		local saved = state.favoritewindow or {Enabled = false}
		restoringwindow = true
		local position = saved.Position or saved.position
		local xscale = type(position) == 'table' and tonumber(position.XScale or position.xscale) or 0
		local x = type(position) == 'table'
			and tonumber(position.X or position.XOffset or position.x or position.xoffset)
		local yscale = type(position) == 'table' and tonumber(position.YScale or position.yscale) or 0
		local y = type(position) == 'table'
			and tonumber(position.Y or position.YOffset or position.y or position.yoffset)
		if x and y then fav.Object.Position = UDim2.new(xscale or 0, x, yscale or 0, y) end
		local expanded = saved.Expanded == true or saved.expanded == true
		if type(fav.Expand) == 'function' and fav.Expanded ~= expanded then fav:Expand() end
		local enabled = saved.Enabled == true or saved.enabled == true
		if fav.Button.Enabled ~= enabled then fav.Button:Toggle() end
		restoringwindow = false
		favoritewindow()
		if favbutton then starvisual(favbutton, fav.Button.Enabled, false) end
	end

	local function createfavorites()
		fav = vape.Categories.Favorites
		if type(fav) ~= 'table' or not isinst(fav.Object) then
			fav = vape:CreateCategory({
				Name = 'Favorites',
				Icon = '',
				Size = UDim2.fromOffset(25, 25)
			})
		end
		if type(fav) ~= 'table' or not isinst(fav.Object) then return false end
		fav.__VapeTweakerFavorites = true
		favchildren = fav.Children or fav.Object:FindFirstChild('Children')
		if not isinst(favchildren) then return false end
		fav.Children = favchildren
		for _, child in ipairs(favchildren:GetChildren()) do
			if child:IsA('GuiObject') then child:Destroy() end
		end
		local icon = fav.Object:FindFirstChild('Icon') or fav.Object:FindFirstChildWhichIsA('ImageLabel')
		if icon then
			icon.Size = UDim2.fromOffset(25, 25)
			icon.Position = UDim2.fromOffset(12, 8)
			icon.ImageTransparency = 0
			icon.Image = favoriteofftab
			icon.ImageColor3 = Color3.new(1, 1, 1)
		end
		local oldbutton = fav.Button
		if oldbutton and isinst(oldbutton.Object) then oldbutton.Object:Destroy() end
		local main = vape.Categories.Main
		if main and type(main.Buttons) == 'table' then main.Buttons.Favorites = nil end
		if vape.Categories.Favorites == fav then vape.Categories.Favorites = nil end
		fav.Button = {
			Enabled = false,
			Toggle = function(buttonapi)
				buttonapi.Enabled = not buttonapi.Enabled
				fav.Object.Visible = buttonapi.Enabled
				if not buttonapi.Enabled then
					closefavoritechildren()
					local divider = fav.Object:FindFirstChild('Divider')
					if divider then divider.Visible = false end
				end
				if favbutton then starvisual(favbutton, buttonapi.Enabled, false) end
				if not restoringwindow then
					favoritewindow()
					queuesave()
				end
			end
		}
		fav.Object.Visible = false
		ctx:clean(fav.Object:GetPropertyChangedSignal('Position'):Connect(function()
			if restoringwindow then return end
			favoritewindow()
			queuesave()
		end))
		return true
	end

	for _, name in ipairs({
		'Favorites', 'Hidden', 'IsFavorite', 'GetFavoriteStarAsset', 'GetFavoriteActiveColor',
		'AnimateStarColor', 'PulseStar', 'PulseImage', 'UpdateFavoritesButton',
		'UpdateFavoriteRow', 'CreateFavoriteRow', 'RefreshFavorites', 'SetFavorite',
		'IsHidden', 'GetHiddenAccentColor', 'GetHiddenCategoryCount', 'UpdateHiddenHeaders',
		'UpdateHiddenModule', 'RefreshHiddenModules', 'SetHiddenEditing', 'SetHidden'
	}) do
		apiold[name] = vape[name]
	end

	load()
	if createfavorites() == false then return end
	addheader('Favorites', fav)
	addfavoritesbutton()
	applyfavoritewindow()

	vape.Favorites = {List = {}, Rows = rows, StarButton = favbutton, Window = fav}
	vape.Hidden = {List = {}, Editing = false}
	vape.IsFavorite = function(_, name) return isfavorite(name) end
	vape.GetFavoriteStarAsset = function(_, enabled) return enabled and favoriteon or favoriteoff end
	vape.GetFavoriteActiveColor = function() return activecolor() end
	vape.AnimateStarColor = function(_, star, enabled, hover) starvisual(star, enabled, hover) end
	vape.PulseStar = function(_, star) pulse(star) end
	vape.PulseImage = function(_, image) pulse(image) end
	vape.UpdateFavoritesButton = function()
		if favbutton then starvisual(favbutton, fav and fav.Button and fav.Button.Enabled, vape.Favorites.StarButtonHovered) end
	end
	vape.UpdateFavoriteRow = function(_, name) updatefavoriterow(name) end
	vape.CreateFavoriteRow = function(_, mod) createfavoriterow(mod) end
	vape.RefreshFavorites = function() refreshfavorites() end
	vape.SetFavorite = function(_, name, enabled, skipsave) setfavorite(name, enabled, skipsave) end
	vape.IsHidden = function(_, name) return ishidden(name) end
	vape.GetHiddenAccentColor = function(_, mod) return accent(mod) end
	vape.GetHiddenCategoryCount = function(_, category) return hiddenincategory(category) end
	vape.UpdateHiddenHeaders = function() updateheaders() end
	vape.UpdateHiddenModule = function(_, name)
		local mod = vape.Modules[name]
		if mod then applymodule(mod) end
		if rows[name] then updatefavoriterow(name) end
	end
	vape.RefreshHiddenModules = function()
		for _, data in pairs(decorated) do applymodule(data.mod) end
		refreshfavorites()
		updateheaders()
	end
	vape.SetHiddenEditing = function(_, enabled) setediting(enabled) end
	vape.SetHidden = function(_, name, enabled, skipsave) sethidden(name, enabled, skipsave) end
	syncapi()
	fetch('favoriteoff.png', function(value)
		favoriteoff = value
		if isinst(favbutton) then
			if favbutton:IsA('ImageButton') then
				favbutton.Image = value
			elseif favbutton:IsA('TextButton') then
				local image = favbutton:FindFirstChild('VTImage') or Instance.new('ImageLabel')
				image.Name = 'VTImage'
				image.BackgroundTransparency = 1
				image.Size = UDim2.fromScale(1, 1)
				image.Parent = favbutton
				favbutton.Text = ''
			end
			starvisual(favbutton, fav and fav.Button and fav.Button.Enabled, vape.Favorites and vape.Favorites.StarButtonHovered)
		end
	end)
	fetch('favoriteon.png', function(value)
		favoriteon = value
		if isinst(favbutton) then starvisual(favbutton, fav and fav.Button and fav.Button.Enabled, false) end
	end)
	fetch('favoriteofftab.png', function(value)
		favoriteofftab = value
		local icon = fav and isinst(fav.Object) and (fav.Object:FindFirstChild('Icon') or fav.Object:FindFirstChildWhichIsA('ImageLabel'))
		if icon then icon.Image = value end
	end)
	fetch('hiddeneyeoff.png', function(value)
		hiddeneyeoff = value
		for _, data in pairs(headers) do
			local eye = data.count and data.count:FindFirstChild('Eye')
			if eye then eye.Image = value end
		end
	end)
	fetch('edit.png', function(value)
		editasset = value
		for _, data in pairs(headers) do
			if data.editicon then data.editicon.Image = value end
		end
	end)

	local function scan()
		if migrate then
			for _, mod in pairs(vape.Modules) do
				if type(mod) == 'table' and type(mod.Name) == 'string' and mod.Visible == false then
					state.hidden[mod.Name] = true
				end
			end
		end
		for name, cat in pairs(vape.Categories) do
			if name ~= 'Main' then addheader(name, cat) end
		end
		for _, mod in pairs(vape.Modules) do addmodule(mod) end
		for mod, data in pairs(clone(decorated)) do
			if vape.Modules[mod.Name] ~= mod or not isinst(data.row) then
				if data.favoriteopen then restorechildren(data, true) end
				decorated[mod] = nil
			end
		end
		for name in pairs(clone(state.favorites)) do
			if type(vape.Modules[name]) ~= 'table' then state.favorites[name] = nil end
		end
		for name in pairs(clone(state.hidden)) do
			if type(vape.Modules[name]) ~= 'table' then state.hidden[name] = nil end
		end
		addfavoritesbutton()
		refreshfavorites()
		updateheaders()
		if migrate then
			migrate = false
			syncapi()
			save(profile)
		end
	end

	scan()
	local lp = players.LocalPlayer
	if lp and lp.OnTeleport then
		ctx:clean(lp.OnTeleport:Connect(function(teleportstate)
			if teleportstate == Enum.TeleportState.Started
				or teleportstate == Enum.TeleportState.InProgress then
				save(profile)
			end
		end))
	end
	local scanclock = 0
	local syncclock = 0
	ctx:clean(runservice.RenderStepped:Connect(function()
		if not alive or not fav or not isinst(fav.Object) or not fav.Object.Visible then return end
		for name, data in pairs(rows) do
			local mod = vape.Modules[name]
			if type(mod) == 'table' then paintfavoriterow(data, mod) end
		end
	end))
	ctx:clean(runservice.Heartbeat:Connect(function(dt)
		scanclock = scanclock + dt
		syncclock = syncclock + dt
		local current = ctx.profile and ctx.profile.dir or 'default'
		if current ~= profile then
			save(profile)
			closefavoritechildren()
			load()
			scan()
			applyfavoritewindow()
		end
		if scanclock >= 0.5 then
			scanclock = 0
			scan()
		end
		if syncclock >= 0.1 then
			syncclock = 0
			for _, data in pairs(decorated) do applymodule(data.mod) end
			for name in pairs(rows) do updatefavoriterow(name) end
		end
	end))

	ctx:clean(function()
		if not alive then return end
		save(profile)
		alive = false
		closefavoritechildren()
		for mod, data in pairs(decorated) do
			local hidden = ishidden(mod.Name)
			if isinst(data.row) then
				data.row.Visible = not hidden
				data.row.Text = data.normal
			end
			for _, obj in ipairs({data.star, data.guard, data.rail, data.hiddenbox}) do
				if isinst(obj) then obj:Destroy() end
			end
			if isinst(data.dots) then data.dots.Visible = true end
			for name, value in pairs(data.oldfields or {}) do
				mod[name] = value
			end
			mod.Visible = not hidden
			if type(mod.SetVisible) == 'function' then pcall(mod.SetVisible, mod, not hidden, true) end
		end
		for _, data in pairs(rows) do
			if isinst(data.row) then data.row:Destroy() end
		end
		for _, data in pairs(headers) do
			for _, obj in ipairs({data.edit, data.done, data.count}) do
				if isinst(obj) then obj:Destroy() end
			end
		end
		if isinst(favbutton) then favbutton:Destroy() end
		if fav and fav.__VapeTweakerFavorites then
			if fav.Button and fav.Button.Enabled then fav.Button:Toggle() end
			if isinst(fav.Object) then fav.Object:Destroy() end
			if vape.Categories.Favorites == fav then vape.Categories.Favorites = nil end
		end
		for name, value in pairs(apiold) do
			vape[name] = value
		end
	end)
end
]],
		['src/patches/teleport.lua'] = [=[return function(ctx)
	local env = (getgenv and getgenv()) or _G
	local raw = type(env.VapeTweakerConfig) == 'table' and env.VapeTweakerConfig or {}
	local enabled = raw.teleport
	if enabled == nil then enabled = raw.Teleport end
	if enabled == false then
		ctx.teleport = {supported = false, queued = false, disabled = true}
		return
	end

	local queue = env.queue_on_teleport or env.queueonteleport or env.queueteleport
	if type(queue) ~= 'function' and type(syn) == 'table' then
		queue = syn.queue_on_teleport
	end
	if type(queue) ~= 'function' and type(fluxus) == 'table' then
		queue = fluxus.queue_on_teleport
	end

	local supported = type(queue) == 'function'
	ctx.teleport = {
		supported = supported,
		queued = env.VapeTweakerTeleportQueued == true,
		disabled = false
	}

	local players = game:GetService('Players')
	local lp = players.LocalPlayer
	if lp and lp.OnTeleport then
		ctx:clean(lp.OnTeleport:Connect(function(state)
			if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then
				if ctx.config and type(ctx.config.save) == 'function' then
					pcall(ctx.config.save, ctx.config, true)
				end
			end
		end))
	end

	if not supported or env.VapeTweakerTeleportQueued then return end

	local cfg = {}
	for key, value in pairs(ctx.cfg or {}) do
		local kind = type(value)
		if kind == 'boolean' or kind == 'number' or kind == 'string' then
			cfg[key] = value
		end
	end
	cfg.base = ctx.loader.requestbase or cfg.base
	cfg.teleport = true

	local http = game:GetService('HttpService')
	local ok, encoded = pcall(http.JSONEncode, http, cfg)
	if not ok then encoded = '{}' end

	local loaderurl = tostring(
		cfg.base or 'https://raw.githubusercontent.com/Floorzey/VapeTweakerForRoblox/main'
	):gsub('/+$', '')..'/loader.lua'

	local source = string.format([[
local env = (getgenv and getgenv()) or _G
if env.VapeTweakerTeleportBooting then return end
env.VapeTweakerTeleportBooting = true
env.VapeTweakerTeleportQueued = nil

local http = game:GetService('HttpService')
local ok, cfg = pcall(http.JSONDecode, http, %q)
env.VapeTweakerConfig = ok and type(cfg) == 'table' and cfg or {}

local fetched, body = pcall(
	game.HttpGet,
	game,
	%q..'?teleport='..tostring(os.clock()),
	true
)

if fetched and type(body) == 'string' then
	local fn = loadstring(body)
	if fn then pcall(fn) end
end

env.VapeTweakerTeleportBooting = nil
]], encoded, loaderurl)

	local queued = pcall(queue, source)
	if queued then
		env.VapeTweakerTeleportQueued = true
		ctx.teleport.queued = true
	end
end
]=],
	}
}
