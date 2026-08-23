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
	local wall
	local circle
	local color
	local alpha
	local fill
	local draw
	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local rng = Random.new()
	local input = game:GetService('UserInputService')
	local run = game:GetService('RunService')
	local white = RaycastParams.new()
	white.FilterType = Enum.RaycastFilterType.Include
	local old
	local orig
	local bound
	local moth = false
	local foth = false
	local lock = 0
	local silent
	local resume = false
	local active
	local err
	local last
	local stamp = 0
	local sig
	local clock = 0
	local new = Ray.new
	local rc = workspace.Raycast
	local fr = workspace.FindPartOnRay
	local fi = workspace.FindPartOnRayWithIgnoreList
	local fw = workspace.FindPartOnRayWithWhitelist
	local sr = Instance.new('Camera').ScreenPointToRay
	local vr = Instance.new('Camera').ViewportPointToRay
	local cameras = {
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
	local tokens = {
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

	local function mouse()
		local cam = workspace.CurrentCamera
		if input.TouchEnabled and cam then return cam.ViewportSize / 2 end
		return input:GetMouseLocation()
	end

	local function erase()
		if draw then
			pcall(function() draw.Visible = false end)
			pcall(function() draw:Remove() end)
			draw = nil
		end
	end

	local function paint()
		if not draw then return end
		local show = mod and mod.Enabled and circle and circle.Enabled and mode and mode.Value == 'Mouse'
		pcall(function()
			draw.Visible = show == true
			draw.Position = mouse()
			draw.Radius = range and range.Value or 150
			draw.Filled = fill and fill.Enabled == true or false
			draw.Color = Color3.fromHSV(color and color.Hue or 0, color and color.Sat or 0, color and color.Value or 1)
			draw.Transparency = 1 - (alpha and alpha.Value or 0.5)
		end)
	end

	local function build()
		erase()
		if not circle or not circle.Enabled or not Drawing or type(Drawing.new) ~= 'function' then return end
		local ok, obj = pcall(Drawing.new, 'Circle')
		if not ok or not obj then return end
		draw = obj
		pcall(function()
			obj.NumSides = 100
			obj.Thickness = 1
		end)
		paint()
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
			local text = tostring(cur.Name or ''):lower()
			if cameras[text] then return true end
			for _, token in ipairs(tokens) do
				if text:find(token, 1, true) then return true end
			end
			cur = cur.Parent
		end
		return false
	end

	local function near(a, b, dist)
		return typeof(a) == 'Vector3' and typeof(b) == 'Vector3' and (a - b).Magnitude <= dist
	end

	local function subject(cam)
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
	end

	local function guard(origin, dir)
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
		local sub = subject(cam)
		local char = type(lib) == 'table' and lib.character
		local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
		local head = type(char) == 'table' and char.Head
		local rpos = typeof(root) == 'Instance' and root.Position or nil
		local hpos = typeof(head) == 'Instance' and head.Position or nil
		local tail = origin + dir
		local zoom = math.max((pos - focus).Magnitude, sub and (pos - sub).Magnitude or 0, rpos and (pos - rpos).Magnitude or 0)
		local tight = math.clamp((zoom * 0.4) + 1.5, 2.5, 14)
		local short = math.clamp((zoom * 4) + 12, 16, 96)
		if len > short then return false end
		local function pair(a, b)
			if typeof(a) ~= 'Vector3' or typeof(b) ~= 'Vector3' or near(a, b, tight) then return false end
			return near(origin, a, tight) and near(tail, b, tight)
		end
		if pair(focus, pos) or pair(pos, focus) then return true end
		if sub and (pair(sub, pos) or pair(pos, sub) or pair(sub, focus) or pair(focus, sub)) then return true end
		if rpos and (pair(rpos, pos) or pair(pos, rpos) or pair(rpos, focus) or pair(focus, rpos)) then return true end
		local rig = math.max(rpos and hpos and (hpos - rpos).Magnitude + 2 or 0, 4)
		local body = rpos and near(origin, rpos, rig) or hpos and near(origin, hpos, 3)
		if body then
			local to = pos - origin
			if to.Magnitude > 0.25 and unit:Dot(to.Unit) > 0.45 then return true end
			if unit:Dot(-cam.CFrame.LookVector) > 0.7 then return true end
		end
		local anchor = sub or rpos or focus
		if anchor and near(origin, anchor, tight) then
			local to = pos - origin
			if to.Magnitude > 0.25 and unit:Dot(to.Unit) > 0.6 then return true end
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
		if obj and ignored and type(ignored.ListEnabled) == 'table' and table.find(ignored.ListEnabled, tostring(obj)) then return true end
		return false
	end

	local function target(origin, walls)
		if type(lib) ~= 'table' or not lib.isAlive or typeof(origin) ~= 'Vector3' then return end
		if rng:NextNumber(0, 100) > (chance and chance.Value or 100) then return end
		local name = part and part.Value or 'Head'
		local fn = lib['Entity'..(mode and mode.Value or 'Mouse')]
		if type(fn) ~= 'function' then return end
		lock += 1
		local ok, ent = pcall(fn, {
			Range = range and range.Value or 150,
			Wallcheck = targets and targets.Walls and targets.Walls.Enabled and (walls or true) or nil,
			Part = name,
			Origin = origin,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		lock -= 1
		if not ok or not ent then return end
		local hit = ent[name]
		if typeof(hit) ~= 'Instance' then return end
		local good = pcall(function() return hit.Position, hit.CFrame, hit.Size end)
		if not good then return end
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
		return ent, hit
	end

	local function spoof(hit, dir)
		if typeof(hit) ~= 'Instance' or typeof(dir) ~= 'Vector3' then return end
		local mag = dir.Magnitude
		if mag <= 0.0001 then return end
		local unit = dir / mag
		local ok, cf, size, pos = pcall(function() return hit.CFrame, hit.Size, hit.Position end)
		if not ok or typeof(cf) ~= 'CFrame' or typeof(size) ~= 'Vector3' or typeof(pos) ~= 'Vector3' then return end
		local vec = cf:VectorToObjectSpace(unit)
		local half = size * 0.5
		local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		return pos - unit * (dist + 0.05)
	end

	local function cast(origin, dir, walls)
		local ent, hit = target(origin, walls)
		if not ent then return end
		local pos = spoof(hit, dir)
		if not pos then return end
		return pos, hit
	end

	local hooks = {
		Raycast = {
			Hook = rc,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or guard(origin, dir) then return end
				local pos, hit = cast(origin, dir)
				if not pos then return end
				args[1] = pos
				if wall and wall.Enabled and hit then
					white.FilterDescendantsInstances = {hit}
					pcall(function() white.CollisionGroup = hit.CollisionGroup end)
					args[3] = white
				end
				return true
			end
		},
		FindPartOnRayWithIgnoreList = {
			Hook = fi,
			Args = function(args)
				local beam = args[1]
				if typeof(beam) ~= 'Ray' or guard(beam.Origin, beam.Direction) then return end
				local pos, hit = cast(beam.Origin, beam.Direction, {args[2]})
				if not pos then return end
				args[1] = new(pos, beam.Direction)
				if wall and wall.Enabled and hit then return true, {hit, hit.Position, hit:GetClosestPointOnSurface(beam.Origin), hit.Material} end
				return true
			end
		},
		ScreenPointToRay = {
			Hook = sr,
			Result = function(beam)
				if typeof(beam) ~= 'Ray' or guard(beam.Origin, beam.Direction) then return end
				local pos = cast(beam.Origin, beam.Direction)
				if pos then return new(pos, beam.Direction) end
			end
		},
		Ray = {
			Hook = new,
			NoNamecall = true,
			NoSelf = true,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or guard(origin, dir) then return end
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
	hooks.ViewportPointToRay.Hook = vr

	local function apply(data, args)
		if type(data.Args) ~= 'function' then return false end
		lock += 1
		local out = table.pack(pcall(data.Args, args))
		lock -= 1
		if not out[1] then return false end
		return out[2] == true, out[3]
	end

	local function result(data, val)
		if type(data.Result) ~= 'function' then return val, false end
		lock += 1
		local ok, out = pcall(data.Result, val)
		lock -= 1
		if ok and out ~= nil then return out, true end
		return val, false
	end

	local function namecall(...)
		if not mod.Enabled or skip() then return old(...) end
		local ok, name = pcall(getnamecallmethod)
		local want = method and method.Value or 'Raycast'
		if not ok or name ~= want then return old(...) end
		local data = hooks[name]
		if not data or data.NoNamecall then return old(...) end
		local self, args = ..., {select(2, ...)}
		if data.Result then
			local val = old(self, table.unpack(args))
			local out, changed = result(data, val)
			if changed then active = name end
			return out
		end
		local changed, out = apply(data, args)
		if changed then
			active = name
			if type(out) == 'table' then return table.unpack(out) end
		end
		return old(self, table.unpack(args))
	end


	local function clear()
		if orig and bound then
			if foth and oth and type(oth.unhook) == 'function' then
				pcall(oth.unhook, bound)
			elseif type(restorefunction) == 'function' then
				pcall(restorefunction, bound)
			elseif type(hookfunction) == 'function' then
				pcall(hookfunction, bound, orig)
			end
		end
		if old then
			if moth and oth and type(oth.unhook) == 'function' and type(getrawmetatable) == 'function' then
				pcall(oth.unhook, getrawmetatable(game).__namecall)
			elseif type(hookmetamethod) == 'function' then
				pcall(hookmetamethod, game, '__namecall', old)
			elseif type(restorefunction) == 'function' and type(getrawmetatable) == 'function' then
				pcall(restorefunction, getrawmetatable(game).__namecall)
			end
		end
		old = nil
		orig = nil
		bound = nil
		moth = false
		foth = false
		if ctx.aim then ctx.aim:stop('magic') end
		active = nil
		lock = 0
		sig = nil
	end

	local function direct(name, data, use)
		if orig or type(data) ~= 'table' or type(data.Hook) ~= 'function' then return false end
		bound = data.Hook
		local wrap
		wrap = function(...)
			if not mod.Enabled or skip() then return orig(...) end
			if data.NoSelf then
				local args = {...}
				local changed = apply(data, args)
				if changed then active = name end
				return orig(table.unpack(args))
			end
			local self, args = ..., {select(2, ...)}
			if data.Result then
				local val = orig(self, table.unpack(args))
				local out, changed = result(data, val)
				if changed then active = name end
				return out
			end
			local changed, out = apply(data, args)
			if changed then
				active = name
				if type(out) == 'table' then return table.unpack(out) end
			end
			return orig(self, table.unpack(args))
		end
		if use and oth and type(oth.hook) == 'function' then
			local ok = pcall(function() orig = oth.hook(data.Hook, wrap) end)
			if ok and type(orig) == 'function' then foth = true return true end
			orig = nil
		end
		if type(hookfunction) ~= 'function' then bound = nil return false end
		local ok = pcall(function() orig = hookfunction(data.Hook, wrap) end)
		if not ok or type(orig) ~= 'function' then orig = nil bound = nil return false end
		return true
	end

	local function attach(kind)
		if old or type(getnamecallmethod) ~= 'function' then return false end
		if kind == 'Oth hook' then
			if not oth or type(oth.hook) ~= 'function' or type(getrawmetatable) ~= 'function' then return false end
			local ok = pcall(function() old = oth.hook(getrawmetatable(game).__namecall, namecall) end)
			if not ok or type(old) ~= 'function' then old = nil return false end
			moth = true
			return true
		end
		if type(hookmetamethod) ~= 'function' then return false end
		local ok = pcall(function() old = hookmetamethod(game, '__namecall', namecall) end)
		if not ok or type(old) ~= 'function' then old = nil return false end
		return true
	end


	local function cfg()
		return {
			mode = mode and mode.Value or 'Mouse',
			range = range and range.Value or 150,
			chance = chance and chance.Value or 100,
			head = part and part.Value == 'Head' and 100 or 0,
			part = part and part.Value or 'Head',
			walls = true,
			players = not targets or not targets.Players or targets.Players.Enabled ~= false
		}
	end

	local function token()
		local data = cfg()
		return table.concat({
			method and method.Value or 'Raycast',
			data.mode,
			tostring(data.range),
			tostring(data.chance),
			data.part,
			tostring(data.players)
		}, '|')
	end

	local function arsenal()
		if not ctx.aim then
			err = 'Arsenal actor support is unavailable.'
			return false
		end
		local ok, msg = ctx.aim:start('magic', 'magic', true, cfg())
		if not ok then err = msg return false end
		active = 'Arsenal'
		sig = token()
		return true
	end

	local function install()
		clear()
		err = nil
		local name = method and method.Value or 'Raycast'
		if name == 'Arsenal' then return arsenal() end
		local kind = hook and hook.Value or 'Hookmetamethod'
		local data = hooks[name]
		if not data then
			err = 'The selected cast method is unavailable.'
			return false
		end
		if data.NoNamecall or kind == 'Function hook' then
			if not direct(name, data, kind == 'Oth hook') then
				clear()
				err = 'The selected function hook could not be installed.'
				return false
			end
			active = name
			return true
		end
		if not attach(kind) then
			clear()
			err = 'The selected hook mode could not be installed.'
			return false
		end
		active = name
		return true
	end

	local function notify(msg)
		msg = tostring(msg or 'Magic Bullet could not be installed.')
		local now = os.clock()
		if msg == last and now - stamp < 30 then return end
		last = msg
		stamp = now
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then pcall(vape.CreateNotification, vape, 'Magic Bullet', msg, 6, 'warning') end
	end


	local function reload()
		if not mod or not mod.Enabled then return end
		local ok = install()
		if not ok then
			notify(err)
			task.defer(function() if mod.Enabled then mod:Toggle() end end)
		end
	end

	mod = ctx:module('combat', {
		name = 'MagicBullet',
		autostart = false,
		tooltip = 'Spoofs the weapon cast origin',
		extratext = function()
			return active or method and method.Value or 'Raycast'
		end,
		func = function(on)
			if on then
				paint()
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				local ok = install()
				if not ok then
					notify(err)
					task.defer(function() if mod.Enabled then mod:Toggle() end end)
				end
			else
				paint()
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
		Function = paint
	})
	local methods = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'}
	if ctx.aim and ctx.aim.ars then table.insert(methods, 1, 'Arsenal') end
	method = make('CreateDropdown', {
		Name = 'Method',
		List = methods,
		Default = ctx.aim and ctx.aim.ars and 'Arsenal' or 'Raycast',
		Function = reload
	})
	hook = make('CreateDropdown', {
		Name = 'Hook',
		List = {'Hookmetamethod', 'Function hook', 'Oth hook'},
		Default = ctx.aim and ctx.aim.ars and 'Function hook' or 'Hookmetamethod',
		Function = reload
	})
	ignored = make('CreateTextList', {Name = 'Ignored Scripts', Default = {'CameraModule'}})
	fix = make('CreateToggle', {
		Name = 'RayCamFix',
		Default = true,
		Tooltip = 'Skips camera and camera-obstruction casts, including character-to-camera geometry in Ray mode.'
	})
	if not (ctx.aim and ctx.aim.ars) then wall = make('CreateToggle', {Name = 'Wallbang'}) end
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(v) return mode and mode.Value == 'Mouse' and 'px' or v == 1 and 'stud' or 'studs' end,
		Function = paint
	})
	chance = make('CreateSlider', {Name = 'Hit Chance', Min = 0, Max = 100, Default = 100, Suffix = '%'})
	part = make('CreateDropdown', {Name = 'Part', List = {'Head', 'RootPart'}, Default = 'Head'})
	circle = make('CreateToggle', {
		Name = 'Range Circle',
		Function = function(on)
			if on then build() else erase() end
			if color and color.Object then color.Object.Visible = on end
			if alpha and alpha.Object then alpha.Object.Visible = on end
			if fill and fill.Object then fill.Object.Visible = on end
		end
	})
	color = make('CreateColorSlider', {
		Name = 'Circle Color',
		Darker = true,
		Visible = false,
		Function = paint
	})
	alpha = make('CreateSlider', {
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Darker = true,
		Visible = false,
		Function = paint
	})
	fill = make('CreateToggle', {
		Name = 'Circle Filled',
		Darker = true,
		Visible = false,
		Function = paint
	})

	ctx:clean(run.RenderStepped:Connect(function()
		paint()
		if not mod.Enabled or not method or method.Value ~= 'Arsenal' then return end
		local now = os.clock()
		if now - clock < 0.25 then return end
		clock = now
		local val = token()
		if val ~= sig then
			sig = val
			arsenal()
		end
	end))
	ctx:clean(erase)
	ctx:clean(clear)
end
