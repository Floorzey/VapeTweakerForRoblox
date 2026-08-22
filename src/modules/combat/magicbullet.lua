return function(ctx)
	local mod
	local meth
	local detect
	local targets
	local part
	local fov
	local range
	local chance
	local force
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local players = game:GetService('Players')
	local input = game:GetService('UserInputService')
	local rep = game:GetService('ReplicatedStorage')
	local lplr = players.LocalPlayer
	local mouse = lplr and lplr:GetMouse()
	local cam = workspace.CurrentCamera
	local rand = Random.new()
	local funcs = {}
	local rawtabs = {}
	local stat = {}
	local silent
	local resume = false
	local busy = false
	local num = 0
	local cache = {t = 0}
	local roll = {t = 0, v = true}
	local good = {
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

	local function lower(v)
		return tostring(v or ''):lower()
	end

	local function has(s, t)
		s = lower(s)
		for _, v in ipairs(t) do
			if s:find(v, 1, true) then return true end
		end
		return false
	end

	local function source(f)
		if type(f) ~= 'function' then return '' end
		if debug and type(debug.info) == 'function' then
			local ok, v = pcall(debug.info, f, 's')
			if ok then return lower(v) end
		end
		if type(getinfo) == 'function' then
			local ok, v = pcall(getinfo, f)
			if ok and type(v) == 'table' then return lower(v.source or v.short_src) end
		end
		return ''
	end

	local function fullname(v)
		if typeof(v) ~= 'Instance' then return '' end
		local ok, s = pcall(v.GetFullName, v)
		return ok and lower(s) or lower(v.Name)
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok, v = pcall(getcallingscript)
		return ok and v or nil
	end

	local function cc()
		if type(checkcaller) ~= 'function' then return false end
		local ok, v = pcall(checkcaller)
		return ok and v == true
	end

	local function mode(v)
		local m = meth and meth.Value or 'Auto'
		return m == 'Auto' or m == v
	end

	local function tool()
		local c = lplr and lplr.Character
		return c and c:FindFirstChildOfClass('Tool') ~= nil
	end

	local function allow(k, o, d)
		if busy or not mod.Enabled or cc() then return false end
		if detect and detect.Value == 'All' then return true end
		local c = caller()
		if c then
			local s = fullname(c)
			if has(s, bad) then return false end
			if has(s, good) then return true end
		end
		if typeof(o) == 'Vector3' and typeof(d) == 'Vector3' then
			if d.Magnitude < 1 then return false end
			cam = workspace.CurrentCamera
			local near = cam and (o - cam.CFrame.Position).Magnitude <= 32
			local root = lib and lib.isAlive and lib.character and (lib.character.RootPart or lib.character.HumanoidRootPart)
			near = near or root and (o - root.Position).Magnitude <= 32
			if not near then return false end
			if cam and d.Magnitude > 0 and d.Unit:Dot(cam.CFrame.LookVector) < -0.35 then return false end
			return true
		end
		if k == 'Mouse' or k == 'Input' or k == 'Camera' then return tool() end
		return false
	end

	local function shot()
		local now = os.clock()
		if now - roll.t > 0.02 then
			roll.t = now
			roll.v = rand:NextNumber(0, 100) <= (chance and chance.Value or 100)
		end
		return roll.v
	end

	local function pick(o)
		if not shot() or type(lib) ~= 'table' or not lib.isAlive or type(lib.EntityMouse) ~= 'function' then return end
		cam = workspace.CurrentCamera
		local now = os.clock()
		if now - cache.t <= 0.012 and cache.h and cache.h.Parent then
			if typeof(o) ~= 'Vector3' or (cache.h.Position - o).Magnitude <= (range and range.Value or 1000) then
				return cache.e, cache.h
			end
		end
		local n = part and part.Value or 'Head'
		local ok, e = pcall(lib.EntityMouse, {
			Range = fov and fov.Value or 360,
			Part = n,
			Origin = o,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		if not ok or not e then return end
		local h = e[n] or e.Head or e.RootPart or e.HumanoidRootPart
		if typeof(h) ~= 'Instance' or not h:IsA('BasePart') then return end
		if typeof(o) == 'Vector3' and (h.Position - o).Magnitude > (range and range.Value or 1000) then return end
		cache.t = now
		cache.e = e
		cache.h = h
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[e] = tick() + 1 end
		return e, h
	end

	local function line(h)
		local y = math.max(h.Size.Y * 0.5 + 0.75, 1)
		return h.Position + Vector3.new(0, y, 0), Vector3.new(0, -(y * 2 + 0.5), 0)
	end

	local function params(p, h)
		if not force or force.Enabled == false then return p end
		local n = RaycastParams.new()
		n.FilterType = Enum.RaycastFilterType.Include
		n.FilterDescendantsInstances = {h}
		if p then
			pcall(function() n.CollisionGroup = p.CollisionGroup end)
			pcall(function() n.IgnoreWater = p.IgnoreWater end)
			pcall(function() n.RespectCanCollide = p.RespectCanCollide end)
			pcall(function() n.BruteForceAllSlow = p.BruteForceAllSlow end)
		end
		return n
	end

	local function list(t, h)
		if type(t) ~= 'table' then return t end
		local n = {}
		for _, v in ipairs(t) do
			local skip = false
			if typeof(v) == 'Instance' then
				local ok, r = pcall(h.IsDescendantOf, h, v)
				skip = ok and r
			end
			if not skip then table.insert(n, v) end
		end
		return n
	end

	local function rawray(o, d)
		local v = funcs.ray
		if v and type(v.old) == 'function' then return v.old(o, d) end
		busy = true
		local ok, r = pcall(Ray.new, o, d)
		busy = false
		if ok then return r end
	end

	local function screen()
		cam = workspace.CurrentCamera
		if not cam then return end
		local e, h = pick(cam.CFrame.Position)
		if not e then return end
		local p, vis = cam:WorldToViewportPoint(h.Position)
		if not vis then return end
		return e, h, Vector2.new(p.X, p.Y)
	end

	local function call(f, a)
		busy = true
		local r = table.pack(pcall(f, table.unpack(a, 1, a.n)))
		busy = false
		if not r[1] then error(r[2], 0) end
		return table.unpack(r, 2, r.n)
	end

	local function magic(f, ...)
		if not mode('Game') or busy or not mod.Enabled or cc() then return f(...) end
		local a = table.pack(...)
		local oi
		local di
		local ri
		local pi
		local o
		local d
		for i = 1, a.n do
			local v = a[i]
			if typeof(v) == 'Vector3' then
				if not oi then
					oi = i
					o = v
				elseif not di then
					di = i
					d = v
				end
			elseif typeof(v) == 'Ray' and not ri then
				ri = i
				o = v.Origin
				d = v.Direction
			elseif typeof(v) == 'RaycastParams' then
				pi = i
			end
		end
		if typeof(o) ~= 'Vector3' or typeof(d) ~= 'Vector3' or not allow('Game', o, d) then return f(...) end
		local e, h = pick(o)
		if not e then return f(...) end
		local no, nd = line(h)
		if ri then
			local r = rawray(no, nd)
			if not r then return f(...) end
			a[ri] = r
		else
			if not oi or not di then return f(...) end
			a[oi] = no
			a[di] = nd
		end
		if pi then a[pi] = params(a[pi], h) end
		return call(f, a)
	end

	local function score(t, f, hint, key)
		local s = source(f)
		local h = lower(hint)
		local k = lower(key)
		local n = 0
		if k == 'raycast' then n += 5 end
		if k == 'castray' or k == 'raycastfunc' then n += 3 end
		if has(s, good) then n += 5 end
		if has(h, good) then n += 8 end
		if h:find('gamecommonmethod', 1, true) then n += 15 end
		local c = 0
		for x in next, t do
			if type(x) == 'string' and has(x, good) then n += 1 end
			c += 1
			if c >= 48 then break end
		end
		return n
	end

	local function hooktab(t, k, hint)
		if type(t) ~= 'table' then return false end
		local f = rawget(t, k)
		if type(f) ~= 'function' or funcs[f] or score(t, f, hint, k) < 8 then return false end
		if type(hookfunction) == 'function' then
			local old
			local w = function(...)
				return magic(old or f, ...)
			end
			local ok = pcall(function() old = hookfunction(f, w) end)
			if ok and type(old) == 'function' then
				funcs[f] = {old = old, new = w, kind = 'game'}
				num += 1
				return true
			end
		end
		local w = function(...)
			return magic(f, ...)
		end
		local ok = pcall(rawset, t, k, w)
		if ok and rawget(t, k) == w then
			funcs[f] = {old = f, new = w, kind = 'game'}
			rawtabs[t] = rawtabs[t] or {}
			rawtabs[t][k] = f
			num += 1
			return true
		end
		return false
	end

	local function scantab(t, hint, depth, seen)
		if type(t) ~= 'table' or seen[t] then return end
		seen[t] = true
		for k, v in pairs(t) do
			if type(k) == 'string' and type(v) == 'function' then
				local s = lower(k)
				if s == 'raycast' or s == 'castray' or s == 'raycastfunc' then hooktab(t, k, hint) end
			elseif depth > 0 and type(v) == 'table' then
				scantab(v, tostring(hint)..'.'..tostring(k), depth - 1, seen)
			end
		end
	end

	local function scan()
		if not mode('Game') then return end
		local seen = {}
		local root = rep:FindFirstChild('ModuleScript')
		local obj = root and root:FindFirstChild('GameCommonMethod')
		if obj and obj:IsA('ModuleScript') then
			local ok, v = pcall(require, obj)
			if ok then scantab(v, obj:GetFullName(), 2, seen) end
		end
		if type(getloadedmodules) == 'function' then
			local ok, mods = pcall(getloadedmodules)
			if ok and type(mods) == 'table' then
				for _, m in ipairs(mods) do
					if typeof(m) == 'Instance' and m:IsA('ModuleScript') then
						local h = fullname(m)
						if has(h, good) then
							local yes, v = pcall(require, m)
							if yes then scantab(v, h, 2, seen) end
						end
					end
				end
			end
		end
		if type(getgc) == 'function' then
			local ok, gc = pcall(getgc, true)
			if ok and type(gc) == 'table' then
				for _, v in ipairs(gc) do
					if type(v) == 'table' then scantab(v, '', 0, seen) end
				end
			end
		end
	end

	local function wrap(f)
		return type(newcclosure) == 'function' and newcclosure(f) or f
	end

	local function ncall(f, self, a)
		busy = true
		local r = table.pack(pcall(f, self, table.unpack(a, 1, a.n)))
		busy = false
		if not r[1] then error(r[2], 0) end
		return table.unpack(r, 2, r.n)
	end

	local function metaname()
		if stat.name or type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then return end
		local old
		local fn = wrap(function(self, ...)
			if busy or not mod.Enabled or cc() then return old(self, ...) end
			local ok, m = pcall(getnamecallmethod)
			if not ok then return old(self, ...) end
			local a = table.pack(...)
			if self == workspace and m == 'Raycast' and mode('Raycast') then
				local o, d = a[1], a[2]
				if allow('Raycast', o, d) then
					local e, h = pick(o)
					if e then
						local no, nd = line(h)
						a[1] = no
						a[2] = nd
						a[3] = params(a[3], h)
						return ncall(old, self, a)
					end
				end
			elseif self == workspace and mode('Legacy') and (m == 'FindPartOnRay' or m == 'FindPartOnRayWithIgnoreList' or m == 'FindPartOnRayWithWhitelist') then
				local r = a[1]
				if typeof(r) == 'Ray' and allow('Legacy', r.Origin, r.Direction) then
					local e, h = pick(r.Origin)
					if e then
						local no, nd = line(h)
						a[1] = rawray(no, nd)
						if m == 'FindPartOnRayWithWhitelist' then
							a[2] = {h}
						elseif m == 'FindPartOnRayWithIgnoreList' then
							a[2] = list(a[2], h)
						elseif typeof(a[2]) == 'Instance' then
							local yes, r2 = pcall(h.IsDescendantOf, h, a[2])
							if yes and r2 then a[2] = lplr.Character end
						end
						return ncall(old, self, a)
					end
				end
			elseif typeof(self) == 'Instance' and self:IsA('Camera') and mode('Camera') and (m == 'ScreenPointToRay' or m == 'ViewportPointToRay') and allow('Camera') then
				local e, h = pick(self.CFrame.Position)
				if e then
					local no, nd = line(h)
					return rawray(no, nd.Unit)
				end
			elseif self == input and m == 'GetMouseLocation' and mode('Input') and allow('Input') then
				local e, h, p = screen()
				if e then return p end
			end
			return old(self, ...)
		end)
		local ok = pcall(function() old = hookmetamethod(game, '__namecall', fn) end)
		if ok and type(old) == 'function' then
			stat.name = true
			stat.nameold = old
		end
	end

	local function metaindex()
		if stat.index or type(hookmetamethod) ~= 'function' or not mouse then return end
		local old
		local fn = wrap(function(self, k)
			if self == mouse and mod.Enabled and mode('Mouse') and not busy and not cc() then
				local s = tostring(k)
				if s == 'Hit' or s == 'hit' or s == 'Target' or s == 'target' or s == 'UnitRay' or s == 'X' or s == 'x' or s == 'Y' or s == 'y' then
					if allow('Mouse') then
						local e, h, p = screen()
						if e then
							if s == 'Target' or s == 'target' then return h end
							if s == 'Hit' or s == 'hit' then return h.CFrame end
							if s == 'X' or s == 'x' then return p.X end
							if s == 'Y' or s == 'y' then return p.Y end
							if s == 'UnitRay' then
								cam = workspace.CurrentCamera
								local o = cam and cam.CFrame.Position or h.Position
								return rawray(o, (h.Position - o).Unit)
							end
						end
					end
				end
			end
			return old(self, k)
		end)
		local ok = pcall(function() old = hookmetamethod(game, '__index', fn) end)
		if ok and type(old) == 'function' then
			stat.index = true
			stat.indexold = old
		end
	end

	local function hfun(k, f, w)
		if stat[k] or type(hookfunction) ~= 'function' or type(f) ~= 'function' then return end
		local old
		local fn = wrap(function(...)
			return w(old, ...)
		end)
		local ok = pcall(function() old = hookfunction(f, fn) end)
		if ok and type(old) == 'function' then
			stat[k] = true
			funcs[k] = {old = old, new = fn}
		end
	end

	local function direct()
		hfun('raycast', workspace.Raycast, function(old, self, o, d, p)
			if self == workspace and mode('Raycast') and allow('Raycast', o, d) then
				local e, h = pick(o)
				if e then
					local no, nd = line(h)
					busy = true
					local r = table.pack(pcall(old, self, no, nd, params(p, h)))
					busy = false
					if not r[1] then error(r[2], 0) end
					return table.unpack(r, 2, r.n)
				end
			end
			return old(self, o, d, p)
		end)

		hfun('fpor', workspace.FindPartOnRay, function(old, self, r, ign, ...)
			if self == workspace and mode('Legacy') and typeof(r) == 'Ray' and allow('Legacy', r.Origin, r.Direction) then
				local e, h = pick(r.Origin)
				if e then
					local no, nd = line(h)
					if typeof(ign) == 'Instance' then
						local ok, v = pcall(h.IsDescendantOf, h, ign)
						if ok and v then ign = lplr.Character end
					end
					return old(self, rawray(no, nd), ign, ...)
				end
			end
			return old(self, r, ign, ...)
		end)

		hfun('fpori', workspace.FindPartOnRayWithIgnoreList, function(old, self, r, ign, ...)
			if self == workspace and mode('Legacy') and typeof(r) == 'Ray' and allow('Legacy', r.Origin, r.Direction) then
				local e, h = pick(r.Origin)
				if e then
					local no, nd = line(h)
					return old(self, rawray(no, nd), list(ign, h), ...)
				end
			end
			return old(self, r, ign, ...)
		end)

		hfun('fporw', workspace.FindPartOnRayWithWhitelist, function(old, self, r, inc, ...)
			if self == workspace and mode('Legacy') and typeof(r) == 'Ray' and allow('Legacy', r.Origin, r.Direction) then
				local e, h = pick(r.Origin)
				if e then
					local no, nd = line(h)
					return old(self, rawray(no, nd), {h}, ...)
				end
			end
			return old(self, r, inc, ...)
		end)

		hfun('input', input.GetMouseLocation, function(old, self)
			if self == input and mode('Input') and allow('Input') then
				local e, h, p = screen()
				if e then return p end
			end
			return old(self)
		end)

		local c = Instance.new('Camera')
		hfun('screenray', c.ScreenPointToRay, function(old, self, ...)
			if typeof(self) == 'Instance' and self:IsA('Camera') and mode('Camera') and allow('Camera') then
				local e, h = pick(self.CFrame.Position)
				if e then
					local no, nd = line(h)
					return rawray(no, nd.Unit)
				end
			end
			return old(self, ...)
		end)
		hfun('viewray', c.ViewportPointToRay, function(old, self, ...)
			if typeof(self) == 'Instance' and self:IsA('Camera') and mode('Camera') and allow('Camera') then
				local e, h = pick(self.CFrame.Position)
				if e then
					local no, nd = line(h)
					return rawray(no, nd.Unit)
				end
			end
			return old(self, ...)
		end)
		c:Destroy()

		hfun('ray', Ray.new, function(old, o, d)
			if mode('Legacy') and allow('Legacy', o, d) then
				local e, h = pick(o)
				if e then
					local no, nd = line(h)
					return old(no, nd)
				end
			end
			return old(o, d)
		end)
	end

	local function install()
		metaname()
		metaindex()
		direct()
		scan()
	end

	local function avail()
		local v = meth and meth.Value or 'Auto'
		if v == 'Game' then return num > 0 end
		if v == 'Raycast' then return stat.name or stat.raycast end
		if v == 'Mouse' then return stat.index end
		if v == 'Input' then return stat.name or stat.input end
		if v == 'Legacy' then return stat.name or stat.fpor or stat.fpori or stat.fporw or stat.ray end
		if v == 'Camera' then return stat.name or stat.screenray or stat.viewray end
		return num > 0 or stat.name or stat.index or stat.raycast or stat.input or stat.fpor or stat.fpori or stat.fporw or stat.ray or stat.screenray or stat.viewray
	end

	local function warn()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'Magic Bullet', 'No compatible hook surface was found for this method.', 6, 'warning')
		end
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		tooltip = 'Forces supported shot queries to resolve through the selected target part.',
		extratext = function()
			local v = meth and meth.Value or 'Auto'
			if num > 0 and (v == 'Auto' or v == 'Game') then return v..' x'..num end
			return v
		end,
		func = function(on)
			if on then
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				install()
				if not avail() then
					warn()
					task.defer(function()
						if mod.Enabled then mod:Toggle() end
					end)
					return
				end
				task.spawn(function()
					while mod.Enabled do
						if type(silent) == 'table' and silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
						task.wait(0.1)
					end
				end)
			else
				cache.t = 0
				if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				resume = false
			end
		end
	})

	local function make(n, d)
		local f = mod[n]
		if type(f) ~= 'function' then
			ctx.log:add('module', 'Magic Bullet', n..' is unavailable')
			return
		end
		local ok, v = pcall(f, mod, d)
		if not ok then
			ctx.log:add('module', 'Magic Bullet', v)
			return
		end
		return v
	end

	meth = make('CreateDropdown', {
		Name = 'Method',
		List = {'Auto', 'Game', 'Raycast', 'Mouse', 'Input', 'Legacy', 'Camera'},
		Default = 'Auto',
		Function = function()
			cache.t = 0
			if mod.Enabled then
				install()
				if not avail() then
					warn()
					mod:Toggle()
				end
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
		Suffix = function(v)
			return v == 1 and 'stud' or 'studs'
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
