return function(ctx)
	local mod
	local meth
	local detect
	local targets
	local part
	local range
	local walls
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local hooks = {}
	local base = {}
	local silent
	local resume = false
	local busy = false
	local guns = {
		'aim',
		'arrow',
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
		'tool',
		'weapon'
	}
	local cams = {
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

	local function full(obj)
		if typeof(obj) ~= 'Instance' then return '' end
		local ok, val = pcall(obj.GetFullName, obj)
		return ok and lower(val) or lower(obj.Name)
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok, val = pcall(getcallingscript)
		return ok and val or nil
	end

	local function camera(obj)
		if typeof(obj) ~= 'Instance' then return false end
		return has(obj.Name, cams) or has(full(obj), cams)
	end

	local function weapon(obj)
		if typeof(obj) ~= 'Instance' then return false end
		local cur = obj
		for _ = 1, 20 do
			if not cur or cur == game then break end
			if cur:IsA('Tool') then return true end
			cur = cur.Parent
		end
		return has(obj.Name, guns) or has(full(obj), guns)
	end

	local function equipped()
		local lp = game:GetService('Players').LocalPlayer
		local char = lp and lp.Character
		return char and char:FindFirstChildOfClass('Tool') or nil
	end

	local function allow(origin, dir, unit)
		if checkcaller and checkcaller() then return false end
		if detect and detect.Value == 'All' then return true end
		local obj = caller()
		if camera(obj) then return false end
		if weapon(obj) then return true end
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return false end
		local mag = dir.Magnitude
		if not unit and mag < 18 then return false end
		local cam = workspace.CurrentCamera
		if not cam or mag <= 0.001 then return false end
		local pos = cam.CFrame.Position
		local root = lib and lib.isAlive and lib.character and lib.character.RootPart
		local nearcam = (origin - pos).Magnitude <= 14
		local nearroot = root and (origin - root.Position).Magnitude <= 14
		local dot = dir.Unit:Dot(cam.CFrame.LookVector)
		if nearcam and dot > 0.08 then return true end
		if nearroot and dot > -0.05 and (equipped() or mag >= 40) then return true end
		return false
	end

	local function pick(origin)
		if type(lib) ~= 'table' or not lib.isAlive or type(lib.EntityPosition) ~= 'function' then return end
		local name = part and part.Value or 'Head'
		local ent = lib.EntityPosition({
			Range = range and range.Value or 150,
			Wallcheck = walls and not walls.Enabled and true or nil,
			Part = name,
			Origin = origin,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		if not ent then return end
		local hit = ent[name] or ent.Head or ent.RootPart
		if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') then return end
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
		return ent, hit
	end

	local function aim(origin, dir, unit)
		if not allow(origin, dir, unit) then return end
		local ent, hit = pick(origin)
		if not ent then return end
		local off = hit.Position - origin
		local dist = off.Magnitude
		if dist <= 0.001 then return end
		if unit then return off.Unit, ent, hit end
		local mag = math.max(dir.Magnitude, dist + math.max(hit.Size.X, hit.Size.Y, hit.Size.Z) + 2)
		return off.Unit * mag, ent, hit
	end

	local function ray(origin, dir)
		local fn = base.ray or Ray.new
		return fn(origin, dir)
	end

	local function params(old, ent)
		if not walls or not walls.Enabled then return old end
		local out = RaycastParams.new()
		out.FilterType = Enum.RaycastFilterType.Include
		out.FilterDescendantsInstances = {ent.Character}
		if old then
			pcall(function() out.CollisionGroup = old.CollisionGroup end)
			pcall(function() out.IgnoreWater = old.IgnoreWater end)
			pcall(function() out.RespectCanCollide = old.RespectCanCollide end)
		end
		return out
	end

	local function hook(fn, wrap, key)
		if type(fn) ~= 'function' or type(hookfunction) ~= 'function' then return false end
		local old
		local ok = pcall(function()
			old = hookfunction(fn, function(...)
				if busy or not mod.Enabled then return old(...) end
				return wrap(old, ...)
			end)
		end)
		if not ok or type(old) ~= 'function' then return false end
		base[key] = old
		hooks[#hooks + 1] = {f = fn, o = old}
		return true
	end

	local function clear()
		busy = true
		for i = #hooks, 1, -1 do
			local val = hooks[i]
			if type(restorefunction) == 'function' then
				pcall(restorefunction, val.f)
			elseif type(hookfunction) == 'function' then
				pcall(hookfunction, val.f, val.o)
			end
		end
		table.clear(hooks)
		table.clear(base)
		busy = false
	end

	local function raycast(old, self, origin, dir, rp)
		if self ~= workspace then return old(self, origin, dir, rp) end
		local nd, ent = aim(origin, dir, false)
		if not nd then return old(self, origin, dir, rp) end
		return old(self, origin, nd, params(rp, ent))
	end

	local function ignore(old, self, r, list, cubes, water)
		if self ~= workspace or typeof(r) ~= 'Ray' then return old(self, r, list, cubes, water) end
		local nd, ent = aim(r.Origin, r.Direction, false)
		if not nd then return old(self, r, list, cubes, water) end
		local nr = ray(r.Origin, nd)
		if walls and walls.Enabled and ent and type(base.whitelist) == 'function' then
			return base.whitelist(self, nr, {ent.Character}, water)
		end
		return old(self, nr, list, cubes, water)
	end

	local function whitelist(old, self, r, list, water)
		if self ~= workspace or typeof(r) ~= 'Ray' then return old(self, r, list, water) end
		local nd, ent = aim(r.Origin, r.Direction, false)
		if not nd then return old(self, r, list, water) end
		if walls and walls.Enabled and ent then list = {ent.Character} end
		return old(self, ray(r.Origin, nd), list, water)
	end

	local function simple(old, self, r, skip, cubes, water)
		if self ~= workspace or typeof(r) ~= 'Ray' then return old(self, r, skip, cubes, water) end
		local nd, ent = aim(r.Origin, r.Direction, false)
		if not nd then return old(self, r, skip, cubes, water) end
		local nr = ray(r.Origin, nd)
		if walls and walls.Enabled and ent and type(base.whitelist) == 'function' then
			return base.whitelist(self, nr, {ent.Character}, water)
		end
		return old(self, nr, skip, cubes, water)
	end

	local function screen(old, self, x, y, depth)
		local out = old(self, x, y, depth)
		if typeof(out) ~= 'Ray' then return out end
		local nd = aim(out.Origin, out.Direction, true)
		if not nd then return out end
		return ray(out.Origin, nd)
	end

	local function rawray(old, origin, dir)
		local nd = aim(origin, dir, false)
		return old(origin, nd or dir)
	end

	local function bind()
		clear()
		if type(hookfunction) ~= 'function' then return false end
		local val = meth and meth.Value or 'Auto'
		local total = 0
		local function add(fn, wrap, key)
			if hook(fn, wrap, key) then total += 1 end
		end
		if val == 'Auto' or val == 'Raycast' then add(workspace.Raycast, raycast, 'raycast') end
		if val == 'Auto' or val == 'Legacy' then
			add(workspace.FindPartOnRayWithIgnoreList, ignore, 'ignore')
			add(workspace.FindPartOnRayWithWhitelist, whitelist, 'whitelist')
			add(workspace.FindPartOnRay, simple, 'find')
		end
		if val == 'Auto' or val == 'Camera' then
			local cam = Instance.new('Camera')
			add(cam.ScreenPointToRay, screen, 'screen')
			add(cam.ViewportPointToRay, screen, 'viewport')
			cam:Destroy()
		end
		if val == 'Auto' or val == 'Ray' or val == 'Legacy' then add(Ray.new, rawray, 'ray') end
		return total > 0
	end

	local function warn()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'Magic Bullet', 'No supported function hook is available.', 5, 'warning')
		end
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		tooltip = 'Redirects weapon raycasts towards nearby targets without requiring crosshair alignment.',
		extratext = function()
			return meth and meth.Value or 'Auto'
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

	local function make(name, data)
		local fn = mod[name]
		if type(fn) ~= 'function' then
			ctx.log:add('module', 'Magic Bullet', name..' is unavailable')
			return
		end
		local ok, val = pcall(fn, mod, data)
		if not ok then
			ctx.log:add('module', 'Magic Bullet', val)
			return
		end
		return val
	end

	meth = make('CreateDropdown', {
		Name = 'Method',
		List = {'Auto', 'Raycast', 'Legacy', 'Camera', 'Ray'},
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

	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	walls = make('CreateToggle', {
		Name = 'Wallbang',
		Default = false
	})

end
