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
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local rng = Random.new()
	local oldname
	local oldhook
	local hooked
	local didoth = false
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
		'clicktomove',
		'controlmodule',
		'controlscript',
		'invisicam',
		'mouselock',
		'occlusion',
		'popper',
		'shiftlock',
		'shouldercam',
		'transparencycontroller',
		'zoomcontroller'
	}

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
		for _ = 1, 16 do
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
		local last = origin + dir
		if len <= 256 then
			if near(origin, focus, 8) and near(last, pos, 10) then return true end
			if near(origin, pos, 8) and near(last, focus, 10) then return true end
			local char = type(lib) == 'table' and lib.character
			local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
			if typeof(root) == 'Instance' and near(origin, root.Position, 10) and near(last, pos, 10) then return true end
		end
		return len <= 6 and (near(origin, pos, 6) or near(origin, focus, 6))
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
		return pos
	end

	local hooks = {
		Raycast = {
			Hook = workspace.Raycast,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or rayguard(origin, dir) then return end
				local pos = cast(origin, dir)
				if pos then args[1] = pos return true end
			end
		},
		FindPartOnRayWithIgnoreList = {
			Hook = workspace.FindPartOnRayWithIgnoreList,
			Args = function(args)
				local ray = args[1]
				if typeof(ray) ~= 'Ray' or rayguard(ray.Origin, ray.Direction) then return end
				local pos = cast(ray.Origin, ray.Direction, {args[2]})
				if pos then args[1] = Ray.new(pos, ray.Direction) return true end
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
		local ok, val = pcall(data.Args, args)
		lock -= 1
		return ok and val == true
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
		if not ok or name ~= (method and method.Value or 'Raycast') then return oldname(...) end
		local data = hooks[name]
		if not data or data.NoNamecall then return oldname(...) end
		local self, args = ..., {select(2, ...)}
		if data.Result then
			local val = oldname(self, table.unpack(args))
			local out, changed = runresult(data, val)
			if changed then active = name end
			return out
		end
		if runargs(data, args) then active = name end
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
			elseif type(hookmetamethod) == 'function' then
				pcall(hookmetamethod, game, '__namecall', oldname)
			elseif type(restorefunction) == 'function' and type(getrawmetatable) == 'function' then
				pcall(restorefunction, getrawmetatable(game).__namecall)
			end
		end
		oldname = nil
		oldhook = nil
		hooked = nil
		didoth = false
		active = nil
		lock = 0
	end

	local function install()
		clear()
		local name = method and method.Value or 'Raycast'
		local data = hooks[name]
		if not data then return false end
		local kind = hook and hook.Value or 'Hookmetamethod'
		if data.NoNamecall then kind = 'Function hook' end
		if kind == 'Function hook' then
			if type(data.Hook) ~= 'function' or type(hookfunction) ~= 'function' then return false end
			hooked = data.Hook
			local wrap
			wrap = function(...)
				if not mod.Enabled or skip() then return oldhook(...) end
				if data.NoSelf then
					local args = {...}
					if runargs(data, args) then active = name end
					return oldhook(table.unpack(args))
				end
				local self, args = ..., {select(2, ...)}
				if data.Result then
					local val = oldhook(self, table.unpack(args))
					local out, changed = runresult(data, val)
					if changed then active = name end
					return out
				end
				if runargs(data, args) then active = name end
				return oldhook(self, table.unpack(args))
			end
			local ok = pcall(function() oldhook = hookfunction(data.Hook, wrap) end)
			if not ok or type(oldhook) ~= 'function' then clear() return false end
			active = name
			return true
		end
		if data.NoNamecall or type(getnamecallmethod) ~= 'function' then return false end
		if kind == 'Oth hook' then
			if not oth or type(oth.hook) ~= 'function' or type(getrawmetatable) ~= 'function' then return false end
			local ok = pcall(function() oldname = oth.hook(getrawmetatable(game).__namecall, namecall) end)
			if not ok or type(oldname) ~= 'function' then clear() return false end
			didoth = true
			active = name
			return true
		end
		if type(hookmetamethod) ~= 'function' then return false end
		local ok = pcall(function() oldname = hookmetamethod(game, '__namecall', namecall) end)
		if not ok or type(oldname) ~= 'function' then clear() return false end
		active = name
		return true
	end

	mod = ctx:module('combat', {
		name = 'Magic Bullet',
		autostart = false,
		tooltip = 'Spoofs the weapon cast origin to just behind the selected target while preserving the original direction.',
		extratext = function()
			return active or method and method.Value or 'Raycast'
		end,
		func = function(on)
			if on then
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
		Default = 'Mouse'
	})
	method = make('CreateDropdown', {
		Name = 'Cast Method',
		List = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'},
		Default = 'Raycast',
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
		Tooltip = 'Skips camera, control and camera-obstruction rays when spoofing cast origins.'
	})
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(v) return mode and mode.Value == 'Mouse' and 'px' or v == 1 and 'stud' or 'studs' end
	})
	chance = make('CreateSlider', {Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	part = make('CreateDropdown', {Name = 'Part', List = {'Head', 'RootPart'}, Default = 'Head'})

	ctx:clean(clear)
end
