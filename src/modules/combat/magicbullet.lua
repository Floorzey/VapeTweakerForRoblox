return function(ctx)
	local mod
	local meth
	local detect
	local targets
	local part
	local range
	local fov
	local chance
	local force
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local rep = game:GetService('ReplicatedStorage')
	local cam = workspace.CurrentCamera
	local rand = Random.new()
	local tabs = {}
	local funcs = {}
	local base = {}
	local silent
	local resume = false
	local busy = false
	local count = 0
	local keys = {
		'aim',
		'ballistic',
		'bullet',
		'combat',
		'commonmethod',
		'firearm',
		'gun',
		'projectile',
		'raycast',
		'rifle',
		'shoot',
		'shot',
		'weapon'
	}
	local bad = {
		'camera',
		'control',
		'ground',
		'occlusion',
		'path',
		'visibility'
	}

	local function lower(val)
		return tostring(val or ''):lower()
	end

	local function has(txt, list)
		txt = lower(txt)
		for _, val in ipairs(list) do
			if txt:find(val, 1, true) then return true end
		end
		return false
	end

	local function source(fn)
		if type(fn) ~= 'function' then return '' end
		if debug and type(debug.info) == 'function' then
			local ok, val = pcall(debug.info, fn, 's')
			if ok then return lower(val) end
		end
		if type(getinfo) == 'function' then
			local ok, val = pcall(getinfo, fn)
			if ok and type(val) == 'table' then return lower(val.source or val.short_src) end
		end
		return ''
	end

	local function fullname(obj)
		if typeof(obj) ~= 'Instance' then return '' end
		local ok, val = pcall(obj.GetFullName, obj)
		return ok and lower(val) or lower(obj.Name)
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok, val = pcall(getcallingscript)
		return ok and val or nil
	end

	local function alive()
		return type(lib) == 'table' and lib.isAlive and lib.character and lib.character.RootPart
	end

	local function allow(origin, dir)
		if type(checkcaller) == 'function' and checkcaller() then return false end
		if detect and detect.Value == 'All' then return true end
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or dir.Magnitude < 4 then return false end
		local obj = caller()
		if obj then
			local txt = fullname(obj)
			if has(txt, bad) then return false end
			if has(txt, keys) then return true end
		end
		cam = workspace.CurrentCamera
		local root = alive()
		local near = cam and (origin - cam.CFrame.Position).Magnitude <= 18
		near = near or root and (origin - root.Position).Magnitude <= 18
		if not near then return false end
		if cam and dir.Magnitude > 0 then
			return dir.Unit:Dot(cam.CFrame.LookVector) > -0.15
		end
		return true
	end

	local function pick(origin)
		if type(lib) ~= 'table' or not lib.isAlive or type(lib.EntityMouse) ~= 'function' then return end
		local name = part and part.Value or 'Head'
		local ent = lib.EntityMouse({
			Range = fov and fov.Value or 360,
			Part = name,
			Origin = origin,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		if not ent then return end
		local hit = ent[name] or ent.Head or ent.RootPart
		if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') then return end
		if (hit.Position - origin).Magnitude > (range and range.Value or 1000) then return end
		if rand:NextNumber(0, 100) > (chance and chance.Value or 100) then return end
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
		return ent, hit
	end

	local function direct(hit)
		local y = math.max(hit.Size.Y * 0.5 + 0.15, 0.65)
		return hit.Position + Vector3.new(0, y, 0), Vector3.new(0, -(y * 2 + 0.3), 0)
	end

	local function clone(old, hit)
		if not force or not force.Enabled then return old end
		local out = RaycastParams.new()
		out.FilterType = Enum.RaycastFilterType.Include
		out.FilterDescendantsInstances = {hit}
		if old then
			pcall(function() out.CollisionGroup = old.CollisionGroup end)
			pcall(function() out.IgnoreWater = old.IgnoreWater end)
			pcall(function() out.RespectCanCollide = old.RespectCanCollide end)
			pcall(function() out.BruteForceAllSlow = old.BruteForceAllSlow end)
		end
		return out
	end

	local function args(...)
		local dat = table.pack(...)
		local oi
		local di
		local pi
		for i = 1, dat.n do
			local val = dat[i]
			if typeof(val) == 'Vector3' then
				if not oi then
					oi = i
				elseif not di then
					di = i
				end
			elseif typeof(val) == 'RaycastParams' then
				pi = i
			end
		end
		return dat, oi, di, pi
	end

	local function invoke(old, dat)
		busy = true
		local out = table.pack(pcall(old, table.unpack(dat, 1, dat.n)))
		busy = false
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	local function magic(old, ...)
		if busy or not mod.Enabled then return old(...) end
		local dat, oi, di, pi = args(...)
		if not oi or not di then return old(...) end
		local origin = dat[oi]
		local dir = dat[di]
		if not allow(origin, dir) then return old(...) end
		local ent, hit = pick(origin)
		if not ent then return old(...) end
		local no, nd = direct(hit)
		dat[oi] = no
		dat[di] = nd
		if pi then dat[pi] = clone(dat[pi], hit) end
		return invoke(old, dat)
	end

	local function score(tab, fn, hint)
		local total = 0
		local src = source(fn)
		local txt = lower(hint)
		if src:find('raycast', 1, true) then total += 3 end
		if has(src, keys) then total += 4 end
		if has(txt, keys) then total += 5 end
		if txt:find('gamecommonmethod', 1, true) then total += 12 end
		local seen = 0
		for key in next, tab do
			if type(key) == 'string' then
				local val = lower(key)
				if val == 'raycast' then total += 3 end
				if has(val, keys) then total += 1 end
			end
			seen += 1
			if seen >= 64 then break end
		end
		return total
	end

	local function add(tab, hint)
		if type(tab) ~= 'table' then return false end
		local fn = rawget(tab, 'Raycast')
		if type(fn) ~= 'function' or tabs[tab] then return false end
		if score(tab, fn, hint) < 5 then return false end
		local wrap = function(...)
			return magic(fn, ...)
		end
		local ok = pcall(rawset, tab, 'Raycast', wrap)
		if not ok or rawget(tab, 'Raycast') ~= wrap then return false end
		tabs[tab] = {old = fn, new = wrap}
		count += 1
		return true
	end

	local function known()
		local root = rep:FindFirstChild('ModuleScript')
		local obj = root and root:FindFirstChild('GameCommonMethod')
		if obj and obj:IsA('ModuleScript') then
			local ok, val = pcall(require, obj)
			if ok and add(val, obj:GetFullName()) then return true end
		end
		return false
	end

	local function loaded()
		if type(getloadedmodules) ~= 'function' then return end
		local ok, list = pcall(getloadedmodules)
		if not ok or type(list) ~= 'table' then return end
		for _, obj in ipairs(list) do
			if typeof(obj) == 'Instance' and obj:IsA('ModuleScript') then
				local txt = fullname(obj)
				if has(txt, keys) then
					local good, val = pcall(require, obj)
					if good then add(val, txt) end
				end
			end
		end
	end

	local function gc()
		if type(getgc) ~= 'function' then return end
		local ok, list = pcall(getgc, true)
		if not ok or type(list) ~= 'table' then return end
		for _, val in ipairs(list) do
			if type(val) == 'table' and type(rawget(val, 'Raycast')) == 'function' then
				add(val, source(rawget(val, 'Raycast')))
			end
		end
	end

	local function engine()
		if type(hookfunction) ~= 'function' then return false end
		local fn = workspace.Raycast
		if type(fn) ~= 'function' then return false end
		local old
		local ok = pcall(function()
			old = hookfunction(fn, function(self, origin, dir, rp)
				if busy or not mod.Enabled or self ~= workspace or not allow(origin, dir) then
					return old(self, origin, dir, rp)
				end
				local ent, hit = pick(origin)
				if not ent then return old(self, origin, dir, rp) end
				local no, nd = direct(hit)
				return old(self, no, nd, clone(rp, hit))
			end)
		end)
		if not ok or type(old) ~= 'function' then return false end
		base.fn = fn
		base.old = old
		return true
	end

	local function clear()
		busy = true
		for tab, dat in pairs(tabs) do
			if rawget(tab, 'Raycast') == dat.new then pcall(rawset, tab, 'Raycast', dat.old) end
			tabs[tab] = nil
		end
		if base.fn and base.old then
			if type(restorefunction) == 'function' then
				pcall(restorefunction, base.fn)
			elseif type(hookfunction) == 'function' then
				pcall(hookfunction, base.fn, base.old)
			end
		end
		table.clear(base)
		count = 0
		busy = false
	end

	local function bind()
		clear()
		local val = meth and meth.Value or 'Auto'
		if val == 'Auto' or val == 'Module' then
			known()
			loaded()
			gc()
		end
		if val == 'Auto' or val == 'Engine' then
			engine()
		end
		return count > 0 or base.fn ~= nil
	end

	local function warn()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'Magic Bullet', 'No compatible game Raycast wrapper or engine hook was found.', 6, 'warning')
		end
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		tooltip = 'Hooks the game raycast wrapper and resolves shots directly through the selected target part.',
		extratext = function()
			if count > 0 and base.fn then return 'Module x'..count..' + Engine' end
			if count > 0 then return 'Module x'..count end
			return base.fn and 'Engine' or meth and meth.Value or 'Auto'
		end,
		func = function(on)
			if on then
			silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
			resume = type(silent) == 'table' and silent.Enabled == true
			if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
			if not bind() then
				warn()
				task.defer(function()
					if mod.Enabled then mod:Toggle() end
				end)
				return
			end
			task.spawn(function()
				while mod.Enabled do
					if type(silent) == 'table' and silent.Enabled and type(silent.Toggle) == 'function' then
						pcall(silent.Toggle, silent)
					end
					task.wait(0.1)
				end
			end)
		else
			clear()
			if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then
				pcall(silent.Toggle, silent)
			end
			resume = false
		end
	end
	})

	local function make(name, dat)
		local fn = mod[name]
		if type(fn) ~= 'function' then
			ctx.log:add('module', 'Magic Bullet', name..' is unavailable')
			return
		end
		local ok, val = pcall(fn, mod, dat)
		if not ok then
			ctx.log:add('module', 'Magic Bullet', val)
			return
		end
		return val
	end

	meth = make('CreateDropdown', {
		Name = 'Method',
		List = {'Auto', 'Module', 'Engine'},
		Default = 'Auto',
		Function = function()
			if mod.Enabled and not bind() then
				warn()
				mod:Toggle()
			end
		end
	})

	detect = make('CreateDropdown', {
		Name = 'Detection',
		List = {'Smart', 'All'},
		Default = 'Smart'
	})

	targets = make('CreateTargets', {
		Players = true
	})

	part = make('CreateDropdown', {
		Name = 'Part',
		List = {'Head', 'RootPart'},
		Default = 'Head'
	})

	fov = make('CreateSlider', {
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 360,
		Suffix = 'px'
	})

	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	chance = make('CreateSlider', {
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})

	force = make('CreateToggle', {
		Name = 'Force Target Filter',
		Default = true
	})
end
