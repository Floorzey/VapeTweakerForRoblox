return function(ctx)
	local mod
	local targets
	local mode
	local method
	local raytype
	local hooktype
	local ignored
	local range
	local chance
	local part
	local walls
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local input = game:GetService('UserInputService')
	local rng = Random.new()
	local whitelist = RaycastParams.new()
	whitelist.FilterType = Enum.RaycastFilterType.Include
	local oldname
	local oldhook
	local hooked
	local didoth = false
	local silent
	local players = game:GetService('Players')
	local lplr = players.LocalPlayer
	local resume = false
	local current
	local api = {}

	local function camera()
		return workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
	end

	local function mousepos()
		local cam = camera()
		if not cam then return Vector2.zero end
		if input.TouchEnabled then return cam.ViewportSize / 2 end
		return input:GetMouseLocation()
	end

	local function checkcaller2()
		if type(checkcaller) ~= 'function' then return false end
		local ok, val = pcall(checkcaller)
		return ok and val == true
	end

	local function calling()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok, val = pcall(getcallingscript)
		return ok and val or nil
	end

	local function skip()
		if checkcaller2() then return true end
		local obj = calling()
		if obj and ignored and type(ignored.ListEnabled) == 'table' and table.find(ignored.ListEnabled, tostring(obj)) then return true end
		return false
	end

	local function basetarget(origin, obj, filter)
		if type(lib) ~= 'table' or not lib.isAlive then return end
		if rng:NextNumber(0, 100) > (chance and chance.Value or 100) then return end
		local name = part and part.Value or 'Head'
		if not filter then
			local fn = lib['Entity'..(mode and mode.Value or 'Mouse')]
			if type(fn) ~= 'function' then return end
			local sett = {
				Range = range and range.Value or 150,
				Wallcheck = targets and targets.Walls and targets.Walls.Enabled and (obj or true) or nil,
				Part = name,
				Origin = origin,
				Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
				NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
			}
			local ok, ent = pcall(fn, sett)
			if not ok or not ent then return end
			local hit = ent[name]
			if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') then return end
			if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
			return ent, hit, origin
		end
		local cam = camera()
		if not cam then return end
		local mouse = mousepos()
		local best
		local bestmag = math.huge
		for _, ent in lib.List do
			if not filter(ent) or not ent.Targetable or not lib.isVulnerable(ent) then continue end
			local hit = ent[name]
			if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') then continue end
			local mag
			if mode and mode.Value == 'Position' then
				mag = (hit.Position - origin).Magnitude
			else
				local pos, vis = cam:WorldToViewportPoint(hit.Position)
				if not vis then continue end
				mag = (mouse - Vector2.new(pos.X, pos.Y)).Magnitude
			end
			if mag > (range and range.Value or 150) or mag >= bestmag then continue end
			if targets and targets.Walls and targets.Walls.Enabled and lib.Wallcheck(origin, hit.Position, obj or true) then continue end
			best = ent
			bestmag = mag
		end
		if not best then return end
		local hit = best[name]
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[best] = tick() + 1 end
		return best, hit, origin
	end

	local function target(origin, obj)
		return basetarget(origin, obj)
	end

	local function remotetarget()
		local cam = camera()
		local root = lib and lib.character and lib.character.RootPart
		local origin = mode and mode.Value == 'Position' and root and root.Position or cam and cam.CFrame.Position
		if typeof(origin) ~= 'Vector3' then return end
		local gameid = lplr and lplr:GetAttribute('Game')
		local team = lplr and lplr:GetAttribute('Team')
		return basetarget(origin, nil, function(ent)
			local plr = ent.Player
			if not plr or plr == lplr then return false end
			local egame = plr:GetAttribute('Game')
			local eteam = plr:GetAttribute('Team')
			if gameid ~= nil and egame ~= gameid then return false end
			if team ~= nil and eteam == team then return false end
			return true
		end)
	end


	local hooks = {
		FindPartOnRayWithIgnoreList = {
			Hook = workspace.FindPartOnRayWithIgnoreList,
			Function = function(args)
				local ray = args[1]
				if typeof(ray) ~= 'Ray' then return end
				local ent, hit, origin = target(ray.Origin, {args[2]})
				if not ent then return end
				if walls and walls.Enabled then
					return {hit, hit.Position, hit:GetClosestPointOnSurface(origin), hit.Material}
				end
				args[1] = Ray.new(origin, CFrame.lookAt(origin, hit.Position).LookVector * ray.Direction.Magnitude)
			end
		},
		Raycast = {
			Hook = workspace.Raycast,
			Function = function(args)
				local origin = args[1]
				local dir = args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return end
				if raytype and raytype.Value ~= 'All' and args[3] and args[3].FilterType ~= Enum.RaycastFilterType[raytype.Value] then return end
				local ent, hit = target(origin)
				if not ent then return end
				args[2] = CFrame.lookAt(origin, hit.Position).LookVector * dir.Magnitude
				if walls and walls.Enabled then
					whitelist.FilterDescendantsInstances = {hit}
					pcall(function() whitelist.CollisionGroup = args[3] and args[3].CollisionGroup or hit.CollisionGroup end)
					pcall(function() whitelist.IgnoreWater = args[3] and args[3].IgnoreWater or false end)
					pcall(function() whitelist.RespectCanCollide = args[3] and args[3].RespectCanCollide or false end)
					args[3] = whitelist
				end
			end
		},
		ScreenPointToRay = {
			Hook = Instance.new('Camera').ScreenPointToRay,
			Function = function(args)
				local cam = camera()
				if not cam then return end
				local origin = cam.CFrame.Position
				local ent, hit = target(origin)
				if not ent then return end
				local cf = CFrame.lookAt(origin, hit.Position)
				return {Ray.new(origin + (args[3] and cf.LookVector * args[3] or Vector3.zero), cf.LookVector)}
			end
		},
		Ray = {
			Hook = Ray.new,
			Function = function(args)
				local origin = args[1]
				local dir = args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return end
				local ent, hit = target(origin)
				if not ent then return end
				args[2] = CFrame.lookAt(origin, hit.Position).LookVector * dir.Magnitude
			end,
			NoNamecall = true
		}
	}

	for _, name in ipairs({'FindPartOnRayWithWhitelist', 'FindPartOnRay'}) do
		hooks[name] = table.clone(hooks.FindPartOnRayWithIgnoreList)
		hooks[name].Hook = workspace[name]
	end
	hooks.ViewportPointToRay = table.clone(hooks.ScreenPointToRay)
	hooks.ViewportPointToRay.Hook = Instance.new('Camera').ViewportPointToRay

	local function namecall(...)
		if not mod.Enabled or skip() then return oldname(...) end
		local ok, name = pcall(getnamecallmethod)
		if not ok then return oldname(...) end
		local data = method and method.Value or 'Auto'
		local self, args = ..., {select(2, ...)}
		if name == 'FireServer' and (data == 'Auto' or data == 'Remote')
			and typeof(self) == 'Instance' and self.ClassName == 'RemoteEvent' and self.Name == 'kill'
			and self.Parent and self.Parent.ClassName == 'Tool' and typeof(args[1]) == 'Instance'
			and args[1].ClassName == 'Player' and typeof(args[2]) == 'Vector3' then
			local ent, hit = remotetarget()
			if ent and ent.Player then
				args[1] = ent.Player
				args[2] = hit.Position
				current = 'Remote'
				return oldname(self, table.unpack(args))
			end
		end
		if data ~= 'Auto' and data ~= name then return oldname(...) end
		local h = hooks[name]
		if not h or h.NoNamecall then return oldname(...) end
		local out = h.Function(args)
		if out then return table.unpack(out) end
		if data == 'Auto' then current = name end
		return oldname(self, table.unpack(args))
	end

	local function clear()
		if oldhook and hooked then
			if didoth and oth and type(oth.unhook) == 'function' then
				pcall(oth.unhook, hooked)
			elseif type(restorefunction) == 'function' then
				pcall(restorefunction, hooked)
			elseif type(hookfunction) == 'function' then
				pcall(hookfunction, hooked, oldhook)
			end
		end
		if oldname then
			if didoth and oth and type(oth.unhook) == 'function' and type(getrawmetatable) == 'function' then
				pcall(oth.unhook, getrawmetatable(game).__namecall)
			elseif type(restorefunction) == 'function' and type(getrawmetatable) == 'function' then
				pcall(restorefunction, getrawmetatable(game).__namecall)
			elseif type(hookmetamethod) == 'function' then
				pcall(hookmetamethod, game, '__namecall', oldname)
			end
		end
		oldname = nil
		oldhook = nil
		hooked = nil
		current = nil
		didoth = false
	end

	local function install()
		clear()
		local name = method and method.Value or 'Auto'
		local kind = hooktype and hooktype.Value or 'Hookmetamethod'
		if name == 'Ray' then kind = 'Function hook' end
		if (name == 'Auto' or name == 'Remote') and kind ~= 'Hookmetamethod' then kind = 'Hookmetamethod' end
		if kind == 'Function hook' then
			local h = hooks[name]
			if not h or type(h.Hook) ~= 'function' or type(hookfunction) ~= 'function' then return false end
			hooked = h.Hook
			local wrapper
			wrapper = function(...)
				if not mod.Enabled or skip() then return oldhook(...) end
				if h.NoNamecall then
					local args = {...}
					local out = h.Function(args)
					if out then return table.unpack(out) end
					return oldhook(table.unpack(args))
				end
				local self, args = ..., {select(2, ...)}
				local out = h.Function(args)
				if out then return table.unpack(out) end
				return oldhook(self, table.unpack(args))
			end
			local ok = pcall(function() oldhook = hookfunction(h.Hook, wrapper) end)
			if not ok or type(oldhook) ~= 'function' then clear() return false end
			current = name..' / Function'
			return true
		end
		if kind == 'Oth hook' then
			if not oth or type(oth.hook) ~= 'function' or type(getrawmetatable) ~= 'function' or type(getnamecallmethod) ~= 'function' then return false end
			local ok = pcall(function() oldname = oth.hook(getrawmetatable(game).__namecall, namecall) end)
			if not ok or type(oldname) ~= 'function' then clear() return false end
			didoth = true
			current = name..' / Oth'
			return true
		end
		if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then return false end
		local ok = pcall(function() oldname = hookmetamethod(game, '__namecall', namecall) end)
		if not ok or type(oldname) ~= 'function' then clear() return false end
		current = name == 'Auto' and 'Auto' or name..' / Meta'
		return true
	end

	function api:target(origin, wall)
		return target(origin, wall)
	end

	function api:method()
		return current
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		autostart = false,
		tooltip = 'Redirects the same weapon ray methods used by Vape SilentAim directly through the selected target.',
		extratext = function()
			return current or method and method.Value or 'Auto'
		end,
		func = function(on)
			if on then
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not install() then
					local vape = ctx.vapeapi and ctx.vapeapi.object
					if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
						pcall(vape.CreateNotification, vape, 'Magic Bullet', 'The selected hook method is unavailable on this executor.', 6, 'warning')
					end
					task.defer(function() if mod.Enabled then mod:Toggle() end end)
				end
			else
				clear()
				if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				resume = false
			end
		end
	})
	ctx.magicbullet = api

	local function make(name, data)
		local fn = mod[name]
		if type(fn) ~= 'function' then return end
		local ok, val = pcall(fn, mod, data)
		if ok then return val end
		ctx.log:add('module', 'Magic Bullet', val)
	end

	targets = make('CreateTargets', {Players = true})
	mode = make('CreateDropdown', {
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Default = 'Mouse'
	})
	method = make('CreateDropdown', {
		Name = 'Method',
		List = {'Auto', 'Remote', 'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'},
		Default = 'Auto',
		Function = function(val)
			if raytype and raytype.Object then raytype.Object.Visible = val == 'Raycast' or val == 'Auto' end
			if mod.Enabled then
				if not install() then mod:Toggle() end
			end
		end
	})
	raytype = make('CreateDropdown', {
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Default = 'All',
		Darker = true,
		Visible = true
	})
	hooktype = make('CreateDropdown', {
		Name = 'Hook',
		List = {'Hookmetamethod', 'Function hook', 'Oth hook'},
		Default = 'Hookmetamethod',
		Function = function()
			if mod.Enabled then
				if not install() then mod:Toggle() end
			end
		end
	})
	ignored = make('CreateTextList', {Name = 'Ignored Scripts', Default = {'CameraModule'}})
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(v) return mode and mode.Value == 'Mouse' and 'px' or v == 1 and 'stud' or 'studs' end
	})
	chance = make('CreateSlider', {Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	part = make('CreateDropdown', {Name = 'Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	walls = make('CreateToggle', {Name = 'Wallbang', Default = true})

	ctx:clean(function()
		clear()
		if ctx.magicbullet == api then ctx.magicbullet = nil end
	end)
end
