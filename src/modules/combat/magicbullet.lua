return function(ctx)
	local mod
	local back
	local detect
	local targets
	local part
	local fov
	local range
	local chance
	local walls
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local players = game:GetService('Players')
	local rep = game:GetService('ReplicatedStorage')
	local lplr = players.LocalPlayer
	local rng = Random.new()
	local list = {}
	local map = {}
	local live
	local hand
	local silent
	local resume = false
	local busy = false
	local cache = {t = 0}
	local roll = {t = 0, v = true}
	local hooks = {}
	local good = {'aim', 'ballistic', 'bullet', 'combat', 'firearm', 'gun', 'projectile', 'raycast', 'rifle', 'shoot', 'shot', 'weapon'}
	local bad = {'camera', 'control', 'ground', 'occlusion', 'path', 'visibility'}
	local api = {}

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

	local function full(v)
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

	local function tool()
		local c = lplr and lplr.Character
		return c and c:FindFirstChildOfClass('Tool') ~= nil
	end

	local function origin(o)
		if typeof(o) ~= 'Vector3' then return false end
		local cam = workspace.CurrentCamera
		if cam and (o - cam.CFrame.Position).Magnitude <= 32 then return true end
		local c = lplr and lplr.Character
		local r = c and (c:FindFirstChild('HumanoidRootPart') or c.PrimaryPart)
		return r and (o - r.Position).Magnitude <= 32 or false
	end

	local function allow(o, d)
		if busy or not mod.Enabled or cc() then return false end
		if typeof(o) ~= 'Vector3' or typeof(d) ~= 'Vector3' or d.Magnitude < 1 then return false end
		local c = caller()
		if c then
			local s = full(c)
			if has(s, bad) then return false end
			if has(s, good) then return true end
		end
		if detect and detect.Value == 'Loose' then return origin(o) end
		return tool() and origin(o) and d.Magnitude >= 16
	end

	local function shot()
		local now = os.clock()
		if now - roll.t > 0.025 then
			roll.t = now
			roll.v = rng:NextNumber(0, 100) <= (chance and chance.Value or 100)
		end
		return roll.v
	end

	local function pick(o)
		if not shot() or type(lib) ~= 'table' or not lib.isAlive or type(lib.EntityMouse) ~= 'function' then return end
		local now = os.clock()
		if now - cache.t <= 0.015 and cache.h and cache.h.Parent then
			if typeof(o) ~= 'Vector3' or (cache.h.Position - o).Magnitude <= (range and range.Value or 1000) then
				return cache.e, cache.h
			end
		end
		local n = part and part.Value or 'Head'
		busy = true
		local ok, e = pcall(lib.EntityMouse, {
			Range = fov and fov.Value or 360,
			Part = n,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true,
			Wallcheck = targets and targets.Walls and targets.Walls.Enabled == true,
			Origin = o
		})
		busy = false
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

	local function point(h, o)
		local p = h.Position
		if typeof(o) == 'Vector3' and type(h.GetClosestPointOnSurface) == 'function' then
			local ok, v = pcall(h.GetClosestPointOnSurface, h, o)
			if ok and typeof(v) == 'Vector3' then p = v end
		end
		return p
	end

	local function params(p, e, h)
		if not walls or walls.Enabled == false then return p end
		local n = RaycastParams.new()
		n.FilterType = Enum.RaycastFilterType.Include
		local c = e and (e.Character or e.Model)
		n.FilterDescendantsInstances = {typeof(c) == 'Instance' and c or h}
		if p then
			pcall(function() n.CollisionGroup = p.CollisionGroup end)
			pcall(function() n.IgnoreWater = p.IgnoreWater end)
			pcall(function() n.RespectCanCollide = p.RespectCanCollide end)
		end
		return n
	end

	local function redirect(o, d, p)
		if not allow(o, d) then return end
		local e, h = pick(o)
		if not e then return end
		local q = point(h, o)
		local v = q - o
		if v.Magnitude <= 0.001 then return end
		local pad = math.max(h.Size.X, h.Size.Y, h.Size.Z) + 2
		local n = v.Unit * math.max(d.Magnitude, v.Magnitude + pad)
		return n, params(p, e, h), e, h
	end

	function api:redirect(o, d, p)
		return redirect(o, d, p)
	end

	function api:target(o)
		return pick(o)
	end

	function api:register(d)
		if type(d) ~= 'table' or type(d.name) ~= 'string' or d.name == '' or type(d.start) ~= 'function' then return false end
		if map[d.name] then return false end
		d.priority = tonumber(d.priority) or 0
		map[d.name] = d
		list[#list + 1] = d
		table.sort(list, function(a, b) return a.priority > b.priority end)
		return true
	end

	function api:unregister(n)
		local d = map[n]
		if not d or live == d then return false end
		map[n] = nil
		for i = #list, 1, -1 do
			if list[i] == d then table.remove(list, i) break end
		end
		return true
	end

	function api:backend()
		return live and live.name or nil
	end

	function api:adapters()
		local out = {}
		for _, d in ipairs(list) do out[#out + 1] = {name = d.name, priority = d.priority} end
		return out
	end

	local function stop()
		local h = hand
		hand = nil
		live = nil
		if type(h) == 'table' and type(h.stop) == 'function' then pcall(h.stop, h) end
		cache.t = 0
	end

	local function start(d, probe)
		local ok, h = pcall(d.start, d, api, probe)
		if not ok or h == false then
			ctx.log:add('module', 'Magic Bullet', ok and 'backend start returned false' or h)
			return false
		end
		live = d
		hand = type(h) == 'table' and h or {}
		return true
	end

	local function choose()
		stop()
		local v = back and back.Value or 'Auto'
		for _, d in ipairs(list) do
			local pass = v == 'Auto' or v == 'Game' and d.kind == 'game' or v == 'Raycast' and d.kind == 'ray'
			if pass then
				local ok, p = pcall(d.probe or function() return true end, d, api)
				if ok and p then
					if start(d, p) then return true end
				elseif not ok then
					ctx.log:add('module', 'Magic Bullet', p)
				end
			end
		end
		return false
	end

	local rayad
	rayad = {
		name = 'Raycast',
		kind = 'ray',
		priority = 10,
		probe = function()
			if type(hookmetamethod) == 'function' and type(getnamecallmethod) == 'function' then return 'namecall' end
			if type(hookfunction) == 'function' and type(workspace.Raycast) == 'function' then return 'function' end
		end,
		start = function(_, _, kind)
			if kind == 'namecall' then
				if not hooks.name then
					local old
					local fn = function(self, ...)
						if live ~= rayad or not mod.Enabled or busy or cc() or self ~= workspace then return old(self, ...) end
						local ok, m = pcall(getnamecallmethod)
						if not ok or m ~= 'Raycast' and m ~= 'Spherecast' then return old(self, ...) end
						local a = table.pack(...)
						local o
						local d
						local pi
						if m == 'Raycast' then
							o, d, pi = a[1], a[2], 3
						else
							o, d, pi = a[1], a[3], 4
						end
						local nd, np = redirect(o, d, a[pi])
						if not nd then return old(self, ...) end
						if m == 'Raycast' then a[2], a[3] = nd, np else a[3], a[4] = nd, np end
						busy = true
						local r = table.pack(pcall(old, self, table.unpack(a, 1, a.n)))
						busy = false
						if r[1] then return table.unpack(r, 2, r.n) end
						return old(self, ...)
					end
					local ok = pcall(function() old = hookmetamethod(game, '__namecall', fn) end)
					if not ok or type(old) ~= 'function' then return false end
					hooks.name = {old = old, fn = fn}
				end
				return {}
			end
			if not hooks.ray then
				local old
				local fn = function(self, o, d, p)
					if live ~= rayad or not mod.Enabled or busy or cc() or self ~= workspace then return old(self, o, d, p) end
					local nd, np = redirect(o, d, p)
					if not nd then return old(self, o, d, p) end
					busy = true
					local r = table.pack(pcall(old, self, o, nd, np))
					busy = false
					if r[1] then return table.unpack(r, 2, r.n) end
					return old(self, o, d, p)
				end
				local ok = pcall(function() old = hookfunction(workspace.Raycast, fn) end)
				if not ok or type(old) ~= 'function' then return false end
				hooks.ray = {old = old, fn = fn}
			end
			return {}
		end
	}

	api:register(rayad)

	local gamead
	gamead = {
		name = 'GameCommon',
		kind = 'game',
		priority = 500,
		probe = function()
			local root = rep:FindFirstChild('ModuleScript')
			local obj = root and root:FindFirstChild('GameCommonMethod')
			if not obj or not obj:IsA('ModuleScript') then return end
			local ok, t = pcall(require, obj)
			local f = ok and type(t) == 'table' and rawget(t, 'Raycast') or nil
			if type(f) ~= 'function' then return end
			return {obj = obj, tab = t, fn = f}
		end,
		start = function(_, _, p)
			local t = p.tab
			local f = p.fn
			if hooks.game and hooks.game.fn == f then
				hooks.game.on = true
				local rec = hooks.game
				return {stop = function() rec.on = false end}
			end
			if type(hookfunction) == 'function' then
				local old
				local rec = {fn = f, on = true}
				local fn = function(...)
					if not rec.on or live ~= gamead or not mod.Enabled or busy or cc() then return old(...) end
					local a = table.pack(...)
					local oi
					local di
					local pi
					local o
					local d
					for i = 1, a.n do
						local v = a[i]
						if typeof(v) == 'Vector3' then
							if not oi then oi, o = i, v elseif not di then di, d = i, v end
						elseif typeof(v) == 'RaycastParams' then
							pi = i
						end
					end
					if not oi or not di then return old(...) end
					local nd, np = redirect(o, d, pi and a[pi] or nil)
					if not nd then return old(...) end
					a[di] = nd
					if pi then a[pi] = np end
					busy = true
					local r = table.pack(pcall(old, table.unpack(a, 1, a.n)))
					busy = false
					if r[1] then return table.unpack(r, 2, r.n) end
					return old(...)
				end
				local ok = pcall(function() old = hookfunction(f, fn) end)
				if ok and type(old) == 'function' then
					rec.old = old
					rec.wrap = fn
					hooks.game = rec
					return {stop = function() rec.on = false end}
				end
			end
			local old = f
			local fn = function(...)
				if live ~= gamead or not mod.Enabled or busy or cc() then return old(...) end
				local a = table.pack(...)
				local oi
				local di
				local pi
				local o
				local d
				for i = 1, a.n do
					local v = a[i]
					if typeof(v) == 'Vector3' then
						if not oi then oi, o = i, v elseif not di then di, d = i, v end
					elseif typeof(v) == 'RaycastParams' then
						pi = i
					end
				end
				if not oi or not di then return old(...) end
				local nd, np = redirect(o, d, pi and a[pi] or nil)
				if not nd then return old(...) end
				a[di] = nd
				if pi then a[pi] = np end
				busy = true
				local r = table.pack(pcall(old, table.unpack(a, 1, a.n)))
				busy = false
				if r[1] then return table.unpack(r, 2, r.n) end
				return old(...)
			end
			local ok = pcall(rawset, t, 'Raycast', fn)
			if not ok or rawget(t, 'Raycast') ~= fn then return false end
			return {
				stop = function()
					if rawget(t, 'Raycast') == fn then pcall(rawset, t, 'Raycast', old) end
				end
			}
		end
	}

	api:register(gamead)
	local function warn()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'Magic Bullet', 'No supported game adapter or ray hook is available.', 6, 'warning')
		end
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		autostart = false,
		tooltip = 'Redirects supported weapon hit queries using game adapters first and a conservative ray fallback.',
		extratext = function()
			return live and live.name or back and back.Value or 'Auto'
		end,
		func = function(on)
			if on then
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not choose() then
					warn()
					task.defer(function() if mod.Enabled then mod:Toggle() end end)
				end
			else
				stop()
				if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				resume = false
			end
		end
	})
	ctx.magicbullet = api

	local function make(n, d)
		local f = mod[n]
		if type(f) ~= 'function' then return end
		local ok, v = pcall(f, mod, d)
		if ok then return v end
		ctx.log:add('module', 'Magic Bullet', v)
	end

	back = make('CreateDropdown', {
		Name = 'Backend',
		List = {'Auto', 'Game', 'Raycast'},
		Default = 'Auto',
		Function = function()
			cache.t = 0
			if mod.Enabled and not choose() then warn() mod:Toggle() end
		end
	})
	detect = make('CreateDropdown', {Name = 'Call Filter', List = {'Strict', 'Loose'}, Default = 'Strict'})
	targets = make('CreateTargets', {Players = true})
	part = make('CreateDropdown', {Name = 'Aim Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	fov = make('CreateSlider', {Name = 'Aim FOV', Min = 1, Max = 1000, Default = 360, Suffix = 'px'})
	range = make('CreateSlider', {
		Name = 'Max Range',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Suffix = function(v) return v == 1 and 'stud' or 'studs' end
	})
	chance = make('CreateSlider', {Name = 'Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	walls = make('CreateToggle', {Name = 'Wallbang', Default = true})

	ctx:clean(function()
		stop()
		if ctx.magicbullet == api then ctx.magicbullet = nil end
	end)
end
