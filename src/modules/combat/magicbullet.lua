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
	local state = {}
	local gamehook
	local silent
	local resume = false
	local busy = false
	local cache = {t = 0}
	local roll = {t = 0, v = true}
	local good = {'aim', 'bullet', 'combat', 'firearm', 'gun', 'projectile', 'raycast', 'rifle', 'shoot', 'shot', 'weapon'}
	local bad = {'camera', 'control', 'ground', 'occlusion', 'path', 'visibility'}

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
		if m == 'Auto' then
			if gamehook then return v == 'Game' end
			return v == 'Raycast' or v == 'Legacy' or v == 'Camera' or v == 'Input'
		end
		return m == v
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
		return (k == 'Mouse' or k == 'Input' or k == 'Camera') and tool()
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

	local function ray(o, d)
		busy = true
		local ok, r = pcall(Ray.new, o, d)
		busy = false
		return ok and r or nil
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

	local function wrap(f)
		return type(newcclosure) == 'function' and newcclosure(f) or f
	end

	local function gamecall(f, ...)
		if not mode('Game') or busy or not mod.Enabled or cc() then return f(...) end
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
		if not oi or not di or not allow('Game', o, d) then return f(...) end
		local e, h = pick(o)
		if not e then return f(...) end
		local no, nd = line(h)
		a[oi], a[di] = no, nd
		if pi then a[pi] = params(a[pi], h) end
		busy = true
		local r = table.pack(pcall(f, table.unpack(a, 1, a.n)))
		busy = false
		if not r[1] then return f(...) end
		return table.unpack(r, 2, r.n)
	end

	local function cleargame()
		if not gamehook then return end
		local t, old, fn = gamehook.t, gamehook.old, gamehook.fn
		if type(t) == 'table' and rawget(t, 'Raycast') == fn then pcall(rawset, t, 'Raycast', old) end
		gamehook = nil
	end

	local function setgame()
		cleargame()
		if not mode('Game') then return false end
		local root = rep:FindFirstChild('ModuleScript')
		local obj = root and root:FindFirstChild('GameCommonMethod')
		if not obj or not obj:IsA('ModuleScript') then return false end
		local ok, t = pcall(require, obj)
		if not ok or type(t) ~= 'table' or type(rawget(t, 'Raycast')) ~= 'function' then return false end
		local old = rawget(t, 'Raycast')
		local fn = function(...)
			return gamecall(old, ...)
		end
		local yes = pcall(rawset, t, 'Raycast', fn)
		if not yes or rawget(t, 'Raycast') ~= fn then return false end
		gamehook = {t = t, old = old, fn = fn}
		return true
	end

	local function namehook()
		if state.name or type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then return state.name end
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
						a[1], a[2], a[3] = no, nd, params(a[3], h)
						busy = true
						local r = table.pack(pcall(old, self, table.unpack(a, 1, a.n)))
						busy = false
						if r[1] then return table.unpack(r, 2, r.n) end
					end
				end
			elseif self == workspace and mode('Legacy') and (m == 'FindPartOnRay' or m == 'FindPartOnRayWithIgnoreList' or m == 'FindPartOnRayWithWhitelist') then
				local r = a[1]
				if typeof(r) == 'Ray' and allow('Legacy', r.Origin, r.Direction) then
					local e, h = pick(r.Origin)
					if e then
						local no, nd = line(h)
						a[1] = ray(no, nd)
						if m == 'FindPartOnRayWithWhitelist' then a[2] = {h} elseif m == 'FindPartOnRayWithIgnoreList' then a[2] = list(a[2], h) end
					end
				end
			elseif typeof(self) == 'Instance' and self:IsA('Camera') and mode('Camera') and (m == 'ScreenPointToRay' or m == 'ViewportPointToRay') and allow('Camera') then
				local e, h = pick(self.CFrame.Position)
				if e then
					local no, nd = line(h)
					local r = ray(no, nd.Unit)
					if r then return r end
				end
			elseif self == input and m == 'GetMouseLocation' and mode('Input') and allow('Input') then
				local e, h, p = screen()
				if e then return p end
			end
			return old(self, ...)
		end)
		local ok = pcall(function() old = hookmetamethod(game, '__namecall', fn) end)
		if ok and type(old) == 'function' then state.name = true end
		return state.name == true
	end

	local function indexhook()
		if state.index or type(hookmetamethod) ~= 'function' or not mouse then return state.index end
		local old
		local fn = wrap(function(self, k)
			if self == mouse and mod.Enabled and mode('Mouse') and not busy and not cc() and allow('Mouse') then
				local s = tostring(k)
				if s == 'Hit' or s == 'hit' or s == 'Target' or s == 'target' or s == 'UnitRay' then
					local e, h = screen()
					if e then
						if s == 'Target' or s == 'target' then return h end
						if s == 'Hit' or s == 'hit' then return h.CFrame end
						cam = workspace.CurrentCamera
						local o = cam and cam.CFrame.Position or h.Position
						return ray(o, (h.Position - o).Unit)
					end
				end
			end
			return old(self, k)
		end)
		local ok = pcall(function() old = hookmetamethod(game, '__index', fn) end)
		if ok and type(old) == 'function' then state.index = true end
		return state.index == true
	end

	local function install()
		local m = meth and meth.Value or 'Auto'
		cleargame()
		if m == 'Game' then return setgame() end
		if m == 'Mouse' then return indexhook() end
		if m == 'Auto' then
			if setgame() then return true end
			return namehook()
		end
		return namehook()
	end

	local function warn()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'Magic Bullet', 'No compatible hook surface was found for this method.', 6, 'warning')
		end
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		tooltip = 'Redirects supported weapon hit queries through the selected target part.',
		extratext = function()
			local v = meth and meth.Value or 'Auto'
			if v == 'Auto' and gamehook then return 'Game' end
			return v
		end,
		func = function(on)
			if on then
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not install() then
					warn()
					task.defer(function() if mod.Enabled then mod:Toggle() end end)
					return
				end
			else
				cleargame()
				cache.t = 0
				if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				resume = false
			end
		end
	})

	local function make(n, d)
		local f = mod[n]
		if type(f) ~= 'function' then return end
		local ok, v = pcall(f, mod, d)
		if ok then return v end
		ctx.log:add('module', 'Magic Bullet', v)
	end

	meth = make('CreateDropdown', {
		Name = 'Method',
		List = {'Auto', 'Game', 'Raycast', 'Mouse', 'Input', 'Legacy', 'Camera'},
		Default = 'Auto',
		Function = function()
			cache.t = 0
			if mod.Enabled then
				cleargame()
				if not install() then warn() mod:Toggle() end
			end
		end
	})

	detect = make('CreateDropdown', {Name = 'Detection', List = {'Smart', 'All'}, Default = 'Smart'})
	targets = make('CreateTargets', {Players = true})
	part = make('CreateDropdown', {Name = 'Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	fov = make('CreateSlider', {Name = 'FOV', Min = 1, Max = 1000, Default = 360, Suffix = 'px'})
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Suffix = function(v) return v == 1 and 'stud' or 'studs' end
	})
	chance = make('CreateSlider', {Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	force = make('CreateToggle', {Name = 'Force Target Filter', Default = true})
end
