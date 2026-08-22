return function(ctx)
	local mod
	local targets
	local mode
	local method
	local hook
	local ignored
	local range
	local chance
	local part
	local fix
	local wallbang
	local circle
	local circlecolor
	local circletransparency
	local circlefilled
	local circleobject
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local rng = Random.new()
	local input = game:GetService('UserInputService')
	local run = game:GetService('RunService')
	local whitelist = RaycastParams.new()
	whitelist.FilterType = Enum.RaycastFilterType.Include
	local oldname
	local oldhook
	local hooked
	local nameoth = false
	local funoth = false
	local lock = 0
	local silent
	local resume = false
	local active
	local camnames = {
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
		popper = true,
		poppercam = true,
		shiftlockcontroller = true,
		shouldercamera = true,
		transparencycontroller = true,
		vehiclecamera = true,
		vrcamera = true,
		zoomcontroller = true
	}
	local camtokens = {
		'camera',
		'camcontroller',
		'clicktomove',
		'controlmodule',
		'controlscript',
		'firstperson',
		'invisicam',
		'mouselock',
		'occlusion',
		'popper',
		'shiftlock',
		'shouldercam',
		'spectat',
		'thirdperson',
		'transparencycontroller',
		'viewcontroller',
		'zoomcontroller'
	}

	local function mousepos()
		local cam = workspace.CurrentCamera
		if input.TouchEnabled and cam then return cam.ViewportSize / 2 end
		return input:GetMouseLocation()
	end

	local function removecircle()
		if circleobject then
			pcall(function() circleobject.Visible = false end)
			pcall(function() circleobject:Remove() end)
			circleobject = nil
		end
	end

	local function updatecircle()
		if not circleobject then return end
		local shown = mod and mod.Enabled and circle and circle.Enabled and mode and mode.Value == 'Mouse'
		pcall(function()
			circleobject.Visible = shown == true
			circleobject.Position = mousepos()
			circleobject.Radius = range and range.Value or 150
			circleobject.Filled = circlefilled and circlefilled.Enabled == true or false
			circleobject.Color = Color3.fromHSV(circlecolor and circlecolor.Hue or 0, circlecolor and circlecolor.Sat or 0, circlecolor and circlecolor.Value or 1)
			circleobject.Transparency = 1 - (circletransparency and circletransparency.Value or 0.5)
		end)
	end

	local function makecircle()
		removecircle()
		if not circle or not circle.Enabled or not Drawing or type(Drawing.new) ~= 'function' then return end
		local ok, obj = pcall(Drawing.new, 'Circle')
		if not ok or not obj then return end
		circleobject = obj
		pcall(function()
			obj.NumSides = 100
			obj.Thickness = 1
		end)
		updatecircle()
	end

	local function lower(val)
		return tostring(val or ''):lower()
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok, val = pcall(getcallingscript)
		return ok and val or nil
	end

	local function camera(obj)
		if typeof(obj) ~= 'Instance' then return false end
		local cur = obj
		for _ = 1, 20 do
			if not cur or cur == game then break end
			local name = lower(cur.Name)
			if camnames[name] then return true end
			for _, token in ipairs(camtokens) do
				if name:find(token, 1, true) then return true end
			end
			cur = cur.Parent
		end
		return false
	end

	local function near(a, b, dist)
		return typeof(a) == 'Vector3' and typeof(b) == 'Vector3' and (a - b).Magnitude <= dist
	end

	local function subjectpos(cam)
		if not cam then return nil end
		local sub = cam.CameraSubject
		if typeof(sub) ~= 'Instance' then return nil end
		local ok, pos = pcall(function() return sub.Position end)
		if ok and typeof(pos) == 'Vector3' then return pos end
		local root
		ok, root = pcall(function() return sub.RootPart end)
		if ok and typeof(root) == 'Instance' then
			ok, pos = pcall(function() return root.Position end)
			if ok and typeof(pos) == 'Vector3' then return pos end
		end
		ok, root = pcall(function() return sub.PrimaryPart end)
		if ok and typeof(root) == 'Instance' then
			ok, pos = pcall(function() return root.Position end)
			if ok and typeof(pos) == 'Vector3' then return pos end
		end
		return nil
	end

	local function rayguard(origin, dir)
		if not fix or fix.Enabled ~= true then return false end
		if camera(caller()) then return true end
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return false end
		local len = dir.Magnitude
		if len <= 0.001 then return true end
		local cam = workspace.CurrentCamera
		if not cam then return false end
		local pos = cam.CFrame.Position
		local focus = cam.Focus.Position
		local sub = subjectpos(cam)
		local char = type(lib) == 'table' and lib.character
		local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
		local rootpos = typeof(root) == 'Instance' and root.Position or nil
		local last = origin + dir
		local zoom = math.max((pos - focus).Magnitude, sub and (pos - sub).Magnitude or 0, rootpos and (pos - rootpos).Magnitude or 0)
		local tight = math.clamp((zoom * 0.35) + 1, 2, 12)
		local short = math.clamp((zoom * 4) + 32, 48, 320)
		if len > short then return false end
		local function pair(a, b)
			if typeof(a) ~= 'Vector3' or typeof(b) ~= 'Vector3' or near(a, b, tight) then return false end
			return near(origin, a, tight) and near(last, b, tight)
		end
		if pair(focus, pos) or pair(pos, focus) then return true end
		if sub and (pair(sub, pos) or pair(pos, sub) or pair(sub, focus) or pair(focus, sub)) then return true end
		if rootpos and (pair(rootpos, pos) or pair(pos, rootpos) or pair(rootpos, focus) or pair(focus, rootpos)) then return true end
		return false
	end

	local function skip()
		if lock > 0 then return true end
		if type(checkcaller) == 'function' then
			local ok, val = pcall(checkcaller)
			if ok and val then return true end
		end
		local obj = caller()
		if obj and ignored and type(ignored.ListEnabled) == 'table'
			and table.find(ignored.ListEnabled, tostring(obj)) then return true end
		return false
	end

	local function target(origin, wall)
		if type(lib) ~= 'table' or not lib.isAlive then return end
		if typeof(origin) ~= 'Vector3' then return end
		if rng:NextNumber(0, 100) > (chance and chance.Value or 100) then return end
		local name = part and part.Value or 'Head'
		local fn = lib['Entity'..(mode and mode.Value or 'Mouse')]
		if type(fn) ~= 'function' then return end
		lock += 1
		local ok, ent = pcall(fn, {
			Range = range and range.Value or 150,
			Wallcheck = targets and targets.Walls and targets.Walls.Enabled and (wall or true) or nil,
			Part = name,
			Origin = origin,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		lock -= 1
		if not ok or not ent then return end
		local hit = ent[name]
		if typeof(hit) ~= 'Instance' then return end
		local good = pcall(function()
			local _ = hit.Position
			local __ = hit.CFrame
			local ___ = hit.Size
		end)
		if not good then return end
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
		return ent, hit
	end

	local function spoof(hit, dir)
		if typeof(hit) ~= 'Instance' or typeof(dir) ~= 'Vector3' then return end
		local mag = dir.Magnitude
		if mag <= 0.0001 then return end
		local unit = dir / mag
		local ok, cf, size, pos = pcall(function()
			return hit.CFrame, hit.Size, hit.Position
		end)
		if not ok or typeof(cf) ~= 'CFrame' or typeof(size) ~= 'Vector3' or typeof(pos) ~= 'Vector3' then return end
		local vec = cf:VectorToObjectSpace(unit)
		local half = size * 0.5
		local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		return pos - unit * (dist + 0.05)
	end

	local function cast(origin, dir, wall)
		local ent, hit = target(origin, wall)
		if not ent then return end
		local pos = spoof(hit, dir)
		if not pos then return end
		return pos, hit
	end

	local hooks = {
		Raycast = {
			Hook = workspace.Raycast,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or rayguard(origin, dir) then return end
				local pos, hit = cast(origin, dir)
				if pos then
					args[1] = pos
					if wallbang and wallbang.Enabled and hit then
						whitelist.FilterDescendantsInstances = {hit}
						pcall(function() whitelist.CollisionGroup = hit.CollisionGroup end)
						args[3] = whitelist
					end
					return true
				end
			end
		},
		FindPartOnRayWithIgnoreList = {
			Hook = workspace.FindPartOnRayWithIgnoreList,
			Args = function(args)
				local ray = args[1]
				if typeof(ray) ~= 'Ray' or rayguard(ray.Origin, ray.Direction) then return end
				local pos, hit = cast(ray.Origin, ray.Direction, {args[2]})
				if pos then
					args[1] = Ray.new(pos, ray.Direction)
					if wallbang and wallbang.Enabled and hit then
						return true, {hit, hit.Position, hit:GetClosestPointOnSurface(ray.Origin), hit.Material}
					end
					return true
				end
			end
		},
		ScreenPointToRay = {
			Hook = Instance.new('Camera').ScreenPointToRay,
			Result = function(ray)
				if typeof(ray) ~= 'Ray' or rayguard(ray.Origin, ray.Direction) then return end
				local pos = cast(ray.Origin, ray.Direction)
				if pos then return Ray.new(pos, ray.Direction) end
			end
		},
		Ray = {
			Hook = Ray.new,
			NoNamecall = true,
			NoSelf = true,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or rayguard(origin, dir) then return end
				local pos = cast(origin, dir)
				if pos then args[1] = pos return true end
			end
		}
	}

	for _, name in ipairs({'FindPartOnRay', 'FindPartOnRayWithWhitelist'}) do
		hooks[name] = table.clone(hooks.FindPartOnRayWithIgnoreList)
		hooks[name].Hook = workspace[name]
	end
	hooks.ViewportPointToRay = table.clone(hooks.ScreenPointToRay)
	hooks.ViewportPointToRay.Hook = Instance.new('Camera').ViewportPointToRay

	local function runargs(data, args)
		if type(data.Args) ~= 'function' then return false end
		lock += 1
		local out = table.pack(pcall(data.Args, args))
		lock -= 1
		if not out[1] then return false end
		return out[2] == true, out[3]
	end

	local function runresult(data, val)
		if type(data.Result) ~= 'function' then return val, false end
		lock += 1
		local ok, out = pcall(data.Result, val)
		lock -= 1
		if ok and out ~= nil then return out, true end
		return val, false
	end

	local function namecall(...)
		if not mod.Enabled or skip() then return oldname(...) end
		local ok, name = pcall(getnamecallmethod)
		local wanted = method and method.Value or 'Auto'
		if not ok or wanted ~= 'Auto' and name ~= wanted then return oldname(...) end
		local data = hooks[name]
		if not data or data.NoNamecall then return oldname(...) end
		local self, args = ..., {select(2, ...)}
		if data.Result then
			local val = oldname(self, table.unpack(args))
			local out, changed = runresult(data, val)
			if changed then active = name end
			return out
		end
		local changed, result = runargs(data, args)
		if changed then
			active = name
			if type(result) == 'table' then return table.unpack(result) end
		end
		return oldname(self, table.unpack(args))
	end

	local function clear()
		if oldhook and hooked then
			if funoth and oth and type(oth.unhook) == 'function' then
				pcall(oth.unhook, hooked)
			elseif type(restorefunction) == 'function' then
				pcall(restorefunction, hooked)
			elseif type(hookfunction) == 'function' then
				pcall(hookfunction, hooked, oldhook)
			end
		end
		if oldname then
			if nameoth and oth and type(oth.unhook) == 'function' and type(getrawmetatable) == 'function' then
				pcall(oth.unhook, getrawmetatable(game).__namecall)
			elseif type(hookmetamethod) == 'function' then
				pcall(hookmetamethod, game, '__namecall', oldname)
			elseif type(restorefunction) == 'function' and type(getrawmetatable) == 'function' then
				pcall(restorefunction, getrawmetatable(game).__namecall)
			end
		end
		oldname = nil
		oldhook = nil
		hooked = nil
		nameoth = false
		funoth = false
		active = nil
		lock = 0
	end

	local function functionhook(name, data, useoth)
		if oldhook or type(data) ~= 'table' or type(data.Hook) ~= 'function' then return false end
		hooked = data.Hook
		local wrap
		wrap = function(...)
			if not mod.Enabled or skip() then return oldhook(...) end
			if data.NoSelf then
				local args = {...}
				local changed = runargs(data, args)
				if changed then active = name end
				return oldhook(table.unpack(args))
			end
			local self, args = ..., {select(2, ...)}
			if data.Result then
				local val = oldhook(self, table.unpack(args))
				local out, changed = runresult(data, val)
				if changed then active = name end
				return out
			end
			local changed, result = runargs(data, args)
			if changed then
				active = name
				if type(result) == 'table' then return table.unpack(result) end
			end
			return oldhook(self, table.unpack(args))
		end
		if useoth and oth and type(oth.hook) == 'function' then
			local ok = pcall(function() oldhook = oth.hook(data.Hook, wrap) end)
			if ok and type(oldhook) == 'function' then funoth = true return true end
			oldhook = nil
		end
		if type(hookfunction) ~= 'function' then hooked = nil return false end
		local ok = pcall(function() oldhook = hookfunction(data.Hook, wrap) end)
		if not ok or type(oldhook) ~= 'function' then oldhook = nil hooked = nil return false end
		return true
	end

	local function namehook(kind)
		if oldname or type(getnamecallmethod) ~= 'function' then return false end
		if kind == 'Oth hook' then
			if not oth or type(oth.hook) ~= 'function' or type(getrawmetatable) ~= 'function' then return false end
			local ok = pcall(function() oldname = oth.hook(getrawmetatable(game).__namecall, namecall) end)
			if not ok or type(oldname) ~= 'function' then oldname = nil return false end
			nameoth = true
			return true
		end
		if type(hookmetamethod) ~= 'function' then return false end
		local ok = pcall(function() oldname = hookmetamethod(game, '__namecall', namecall) end)
		if not ok or type(oldname) ~= 'function' then oldname = nil return false end
		return true
	end

	local function install()
		clear()
		local name = method and method.Value or 'Auto'
		local kind = hook and hook.Value or 'Hookmetamethod'
		if name == 'Auto' then
			local nok = namehook(kind == 'Oth hook' and 'Oth hook' or 'Hookmetamethod')
			local rok = functionhook('Ray', hooks.Ray, kind == 'Oth hook')
			if not nok and not rok then clear() return false end
			active = nil
			return true
		end
		local data = hooks[name]
		if not data then return false end
		if data.NoNamecall or kind == 'Function hook' then
			if not functionhook(name, data, kind == 'Oth hook') then clear() return false end
			active = name
			return true
		end
		if not namehook(kind) then clear() return false end
		active = name
		return true
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		autostart = false,
		tooltip = 'Spoofs the weapon cast origin to just behind the selected target while preserving the original direction.',
		extratext = function()
			return active or method and method.Value or 'Auto'
		end,
		func = function(on)
			if on then
				updatecircle()
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not install() then
					local vape = ctx.vapeapi and ctx.vapeapi.object
					if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
						pcall(vape.CreateNotification, vape, 'Magic Bullet', 'The selected cast hook is unavailable on this executor.', 6, 'warning')
					end
					task.defer(function() if mod.Enabled then mod:Toggle() end end)
				end
			else
				updatecircle()
				clear()
				if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				resume = false
			end
		end
	})

	local function make(name, data)
		local fn = mod[name]
		if type(fn) ~= 'function' then return end
		local ok, val = pcall(fn, mod, data)
		if ok then return val end
		ctx.log:add('module', 'Magic Bullet', val)
	end

	targets = make('CreateTargets', {Players = true})
	mode = make('CreateDropdown', {
		Name = 'Target Mode',
		List = {'Mouse', 'Position'},
		Default = 'Mouse',
		Function = updatecircle
	})
	method = make('CreateDropdown', {
		Name = 'Method',
		List = {'Auto', 'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'},
		Default = 'Auto',
		Function = function()
			if mod.Enabled and not install() then mod:Toggle() end
		end
	})
	hook = make('CreateDropdown', {
		Name = 'Hook',
		List = {'Hookmetamethod', 'Function hook', 'Oth hook'},
		Default = 'Hookmetamethod',
		Function = function()
			if mod.Enabled and not install() then mod:Toggle() end
		end
	})
	ignored = make('CreateTextList', {Name = 'Ignored Scripts', Default = {'CameraModule'}})
	fix = make('CreateToggle', {
		Name = 'RayCamFix',
		Default = true,
		Tooltip = 'Skips camera, control, spectate and camera-obstruction casts without discarding short weapon rays from the camera.'
	})
	wallbang = make('CreateToggle', {Name = 'Wallbang'})
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(v) return mode and mode.Value == 'Mouse' and 'px' or v == 1 and 'stud' or 'studs' end,
		Function = updatecircle
	})
	chance = make('CreateSlider', {Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	part = make('CreateDropdown', {Name = 'Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	circle = make('CreateToggle', {
		Name = 'Range Circle',
		Function = function(on)
			if on then makecircle() else removecircle() end
			if circlecolor and circlecolor.Object then circlecolor.Object.Visible = on end
			if circletransparency and circletransparency.Object then circletransparency.Object.Visible = on end
			if circlefilled and circlefilled.Object then circlefilled.Object.Visible = on end
		end
	})
	circlecolor = make('CreateColorSlider', {
		Name = 'Circle Color',
		Darker = true,
		Visible = false,
		Function = updatecircle
	})
	circletransparency = make('CreateSlider', {
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Darker = true,
		Visible = false,
		Function = updatecircle
	})
	circlefilled = make('CreateToggle', {
		Name = 'Circle Filled',
		Darker = true,
		Visible = false,
		Function = updatecircle
	})

	ctx:clean(run.RenderStepped:Connect(updatecircle))
	ctx:clean(removecircle)
	ctx:clean(clear)
end
