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
	local fire
	local fireenv
	local fireups = {}
	local installerror
	local lastnotice
	local noticetime = 0
	local fireraw = Ray
	local firenew = Ray.new
	local wraycast = workspace.Raycast
	local wfind = workspace.FindPartOnRay
	local wignore = workspace.FindPartOnRayWithIgnoreList
	local wwhite = workspace.FindPartOnRayWithWhitelist
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
		local unit = dir / len
		local pos = cam.CFrame.Position
		local focus = cam.Focus.Position
		local sub = subjectpos(cam)
		local char = type(lib) == 'table' and lib.character
		local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
		local head = type(char) == 'table' and char.Head
		local rootpos = typeof(root) == 'Instance' and root.Position or nil
		local headpos = typeof(head) == 'Instance' and head.Position or nil
		local last = origin + dir
		local zoom = math.max((pos - focus).Magnitude, sub and (pos - sub).Magnitude or 0, rootpos and (pos - rootpos).Magnitude or 0)
		local tight = math.clamp((zoom * 0.4) + 1.5, 2.5, 14)
		local short = math.clamp((zoom * 4) + 12, 16, 96)
		if len > short then return false end
		local function pair(a, b)
			if typeof(a) ~= 'Vector3' or typeof(b) ~= 'Vector3' or near(a, b, tight) then return false end
			return near(origin, a, tight) and near(last, b, tight)
		end
		if pair(focus, pos) or pair(pos, focus) then return true end
		if sub and (pair(sub, pos) or pair(pos, sub) or pair(sub, focus) or pair(focus, sub)) then return true end
		if rootpos and (pair(rootpos, pos) or pair(pos, rootpos) or pair(rootpos, focus) or pair(focus, rootpos)) then return true end
		local rig = math.max(rootpos and headpos and (headpos - rootpos).Magnitude + 2 or 0, 4)
		local charorigin = rootpos and near(origin, rootpos, rig) or headpos and near(origin, headpos, 3)
		if charorigin then
			local tocam = pos - origin
			if tocam.Magnitude > 0.25 and unit:Dot(tocam.Unit) > 0.45 then return true end
			if unit:Dot(-cam.CFrame.LookVector) > 0.7 then return true end
		end
		local anchor = sub or rootpos or focus
		if anchor and near(origin, anchor, tight) then
			local tocam = pos - origin
			if tocam.Magnitude > 0.25 and unit:Dot(tocam.Unit) > 0.6 then return true end
		end
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

	local function infofn(fn)
		local api = type(debug) == 'table' and debug.getinfo or getinfo
		if type(api) ~= 'function' then return '' end
		local ok, val = pcall(api, fn)
		return ok and type(val) == 'table' and tostring(val.name or '') or ''
	end

	local function upget(fn, index)
		if type(debug) == 'table' and type(debug.getupvalue) == 'function' then
			local ok, a, b = pcall(debug.getupvalue, fn, index)
			if ok then return b ~= nil and b or a end
		end
		if type(getupvalue) == 'function' then
			local ok, val = pcall(getupvalue, fn, index)
			if ok then return val end
		end
	end

	local function upset(fn, index, val)
		if type(debug) == 'table' and type(debug.setupvalue) == 'function' then
			return pcall(debug.setupvalue, fn, index, val)
		end
		if type(setupvalue) == 'function' then return pcall(setupvalue, fn, index, val) end
		return false
	end

	local function findfire()
		local list = {}
		local seen = {}
		local function add(val)
			if type(val) == 'function' and not seen[val] then
				seen[val] = true
				list[#list + 1] = val
			end
		end
		if type(filtergc) == 'function' then
			for _, name in ipairs({'firebullet', 'FireBullet', 'Firebullet'}) do
				local ok, out = pcall(filtergc, 'function', {Name = name, IgnoreExecutor = true})
				if ok then
					if type(out) == 'function' then add(out)
					elseif type(out) == 'table' then
						for _, fn in pairs(out) do add(fn) end
					end
				end
				local good, tabs = pcall(filtergc, 'table', {Keys = {name}})
				if good and type(tabs) == 'table' then
					for _, tab in pairs(tabs) do
						if type(tab) == 'table' then add(rawget(tab, name)) end
					end
				end
			end
		end
		if #list == 0 and type(getgc) == 'function' then
			local ok, out = pcall(getgc, false)
			if not ok or type(out) ~= 'table' then ok, out = pcall(getgc) end
			if ok and type(out) == 'table' then
				for _, val in pairs(out) do
					if type(val) == 'function' and lower(infofn(val)) == 'firebullet' then add(val) end
				end
			end
		end
		if #list == 0 then return end
		local best
		local env
		local score = -1
		for _, val in ipairs(list) do
			local e
			if type(getfenv) == 'function' then
				local ok, out = pcall(getfenv, val)
				if ok and type(out) == 'table' then e = out end
			end
			local n = lower(infofn(val)) == 'firebullet' and 8 or 0
			if e then
				if rawget(e, 'currentspread') ~= nil then n += 3 end
				if rawget(e, 'recoil') ~= nil then n += 3 end
				if rawget(e, 'spreadmodifier') ~= nil then n += 2 end
				if rawget(e, 'gun') ~= nil then n += 1 end
			end
			if n > score then best, env, score = val, e, n end
		end
		if not best then return end
		local ups = {}
		local empty = 0
		for index = 1, 96 do
			local val = upget(best, index)
			if val == nil then
				empty += 1
				if empty >= 8 then break end
			else
				empty = 0
				local kind
				if val == firenew then kind = 'new'
				elseif val == fireraw then kind = 'ray'
				elseif val == workspace then kind = 'workspace'
				elseif val == wraycast then kind = 'raycast'
				elseif val == wfind then kind = 'find'
				elseif val == wignore then kind = 'ignore'
				elseif val == wwhite then kind = 'white' end
				if kind then ups[#ups + 1] = {index, kind, val} end
			end
		end
		return best, env, ups
	end

	local function firehook()
		if oldhook then return false end
		local fn, env, ups = findfire()
		if type(fn) ~= 'function' then
			installerror = 'The firebullet function was not found.'
			return false
		end
		if type(hookfunction) ~= 'function' then
			installerror = 'hookfunction is unavailable on this executor.'
			return false
		end
		fire, fireenv, fireups = fn, env, ups or {}
		local wsproxy
		local rayproxy
		local function new(origin, dir)
			if mod.Enabled and typeof(origin) == 'Vector3' and typeof(dir) == 'Vector3' and not rayguard(origin, dir) then
				local pos = cast(origin, dir)
				if pos then active = 'Firebullet' origin = pos end
			end
			return firenew(origin, dir)
		end
		local function legacy(real)
			return function(self, ray, ...)
				if mod.Enabled and typeof(ray) == 'Ray' and not rayguard(ray.Origin, ray.Direction) then
					local pos, hit = cast(ray.Origin, ray.Direction)
					if pos then
						active = 'Firebullet'
						if wallbang and wallbang.Enabled and hit then return hit, hit.Position, hit:GetClosestPointOnSurface(ray.Origin), hit.Material end
						ray = firenew(pos, ray.Direction)
					end
				end
				return real(workspace, ray, ...)
			end
		end
		local function raycast(self, origin, dir, params)
			if mod.Enabled and typeof(origin) == 'Vector3' and typeof(dir) == 'Vector3' and not rayguard(origin, dir) then
				local pos, hit = cast(origin, dir)
				if pos then
					active = 'Firebullet'
					origin = pos
					if wallbang and wallbang.Enabled and hit then
						whitelist.FilterDescendantsInstances = {hit}
						pcall(function() whitelist.CollisionGroup = hit.CollisionGroup end)
						params = whitelist
					end
				end
			end
			return wraycast(workspace, origin, dir, params)
		end
		rayproxy = setmetatable({new = new}, {__index = function(_, key) return fireraw[key] end})
		local methods = {
			Raycast = raycast,
			FindPartOnRay = legacy(wfind),
			FindPartOnRayWithIgnoreList = legacy(wignore),
			FindPartOnRayWithWhitelist = legacy(wwhite)
		}
		wsproxy = setmetatable({}, {
			__index = function(_, key)
				if methods[key] then return methods[key] end
				local val = workspace[key]
				if type(val) == 'function' then return function(_, ...) return val(workspace, ...) end end
				return val
			end,
			__newindex = function(_, key, val) workspace[key] = val end
		})
		local replace = {
			new = new,
			ray = rayproxy,
			workspace = wsproxy,
			raycast = raycast,
			find = methods.FindPartOnRay,
			ignore = methods.FindPartOnRayWithIgnoreList,
			white = methods.FindPartOnRayWithWhitelist
		}
		local wrap = function(...)
			if not mod.Enabled or lock > 0 then return oldhook(...) end
			local oldray
			local oldws
			local hadray = false
			local hadws = false
			if type(fireenv) == 'table' then
				oldray = rawget(fireenv, 'Ray')
				oldws = rawget(fireenv, 'workspace')
				hadray = oldray ~= nil
				hadws = oldws ~= nil
				pcall(function() fireenv.Ray = rayproxy end)
				pcall(function() fireenv.workspace = wsproxy end)
			end
			local changed = {}
			for _, item in ipairs(fireups) do
				local val = replace[item[2]]
				if val and upset(fire, item[1], val) then changed[#changed + 1] = item end
			end
			local out = table.pack(pcall(oldhook, ...))
			for index = #changed, 1, -1 do
				local item = changed[index]
				upset(fire, item[1], item[3])
			end
			if type(fireenv) == 'table' then
				pcall(function() fireenv.Ray = hadray and oldray or nil end)
				pcall(function() fireenv.workspace = hadws and oldws or nil end)
			end
			if not out[1] then error(out[2], 0) end
			return table.unpack(out, 2, out.n)
		end
		local callback = wrap
		if type(newcclosure) == 'function' then
			local ok, val = pcall(newcclosure, wrap, 'VapeTweakerMagicBulletFirebullet')
			if ok and type(val) == 'function' then callback = val end
		end
		hooked = fn
		local ok, val = pcall(hookfunction, fn, callback)
		if not ok or type(val) ~= 'function' then
			installerror = 'firebullet was found, but hookfunction could not attach to it.'
			oldhook = nil
			hooked = nil
			return false
		end
		oldhook = val
		return true
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
		local wanted = method and method.Value or 'Raycast'
		if not ok or name ~= wanted then return oldname(...) end
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
		fire = nil
		fireenv = nil
		fireups = {}
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
		installerror = nil
		local name = method and method.Value or 'Raycast'
		local kind = hook and hook.Value or 'Hookmetamethod'
		if name == 'Firebullet' then
			if not firehook() then
				local err = installerror or 'Firebullet could not be installed.'
				clear()
				installerror = err
				return false, err
			end
			active = name
			return true
		end
		local data = hooks[name]
		if not data then
			installerror = 'The selected cast method is unavailable.'
			return false, installerror
		end
		if data.NoNamecall or kind == 'Function hook' then
			if not functionhook(name, data, kind == 'Oth hook') then
				clear()
				installerror = 'The selected function hook could not be installed.'
				return false, installerror
			end
			active = name
			return true
		end
		if not namehook(kind) then
			clear()
			installerror = 'The selected hook mode could not be installed.'
			return false, installerror
		end
		active = name
		return true
	end

	local function notifyfailure(msg)
		msg = tostring(msg or 'Magic Bullet could not be installed.')
		local now = os.clock()
		if msg == lastnotice and now - noticetime < 30 then return end
		lastnotice = msg
		noticetime = now
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'Magic Bullet', msg, 6, 'warning')
		end
	end

	local function refreshmethod()
		if hook and hook.Object then hook.Object.Visible = not method or method.Value ~= 'Firebullet' end
	end

	local function reinstall()
		refreshmethod()
		if not mod or not mod.Enabled then return end
		local ok, err = install()
		if not ok then
			notifyfailure(err)
			task.defer(function() if mod.Enabled then mod:Toggle() end end)
		end
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
				updatecircle()
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				local ok, err = install()
				if not ok then
					notifyfailure(err)
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
		List = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray', 'Firebullet'},
		Default = 'Raycast',
		Function = reinstall
	})
	hook = make('CreateDropdown', {
		Name = 'Hook',
		List = {'Hookmetamethod', 'Function hook', 'Oth hook'},
		Default = 'Hookmetamethod',
		Function = reinstall
	})
	refreshmethod()
	ignored = make('CreateTextList', {Name = 'Ignored Scripts', Default = {'CameraModule'}})
	fix = make('CreateToggle', {
		Name = 'RayCamFix',
		Default = true,
		Tooltip = 'Skips camera and camera-obstruction casts, including character-to-camera geometry in Ray mode.'
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
