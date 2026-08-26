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
	local players = game:GetService('Players')
	local white = RaycastParams.new()
	white.FilterType = Enum.RaycastFilterType.Include
	local silent
	local resume = false
	local active
	local err
	local last
	local stamp = 0
	local sig
	local clock = 0
	local lock = 0
	local funcs = {}
	local temp = Instance.new('Camera')
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

	local function get(obj, key)
		if obj == nil then return end
		local ok, val = pcall(function() return obj[key] end)
		if ok and type(val) == 'function' then return val end
	end

	local new = get(Ray, 'new')
	local rc = get(workspace, 'Raycast')
	local fr = get(workspace, 'FindPartOnRay')
	local fi = get(workspace, 'FindPartOnRayWithIgnoreList')
	local fw = get(workspace, 'FindPartOnRayWithWhitelist')
	local sr = get(temp, 'ScreenPointToRay')
	local vr = get(temp, 'ViewportPointToRay')

	local function mouse()
		local cam = workspace.CurrentCamera
		if input.TouchEnabled and cam then return cam.ViewportSize / 2 end
		return input:GetMouseLocation()
	end

	local function erase()
		if not draw then return end
		pcall(function() draw.Visible = false end)
		pcall(function() draw:Remove() end)
		draw = nil
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
		if type(getcallingscript) ~= 'function' then return end
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

	local function close(origin)
		if typeof(origin) ~= 'Vector3' then return false end
		local cam = workspace.CurrentCamera
		if cam and near(origin, cam.CFrame.Position, 96) then return true end
		local plr = players.LocalPlayer
		local char = plr and plr.Character
		if not char then return false end
		local root = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		local head = char:FindFirstChild('Head')
		if root and root:IsA('BasePart') and near(origin, root.Position, 96) then return true end
		if head and head:IsA('BasePart') and near(origin, head.Position, 96) then return true end
		local tool = char:FindFirstChildWhichIsA('Tool')
		local handle = tool and tool:FindFirstChild('Handle', true)
		return handle and handle:IsA('BasePart') and near(origin, handle.Position, 96) or false
	end

	local function subject(cam)
		if not cam then return end
		local sub = cam.CameraSubject
		if typeof(sub) ~= 'Instance' then return end
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
		local rpos = typeof(root) == 'Instance' and root:IsA('BasePart') and root.Position or nil
		local hpos = typeof(head) == 'Instance' and head:IsA('BasePart') and head.Position or nil
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

	local function valid(origin, dir, unit)
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return false end
		local len = dir.Magnitude
		if len <= 0.001 then return false end
		if not unit and len < 8 then return false end
		if not close(origin) then return false end
		return not guard(origin, dir)
	end

	local function skip()
		if lock > 0 then return true end
		if type(checkcaller) == 'function' then
			local ok, val = pcall(checkcaller)
			if ok and val then return true end
		end
		local obj = caller()
		return obj and ignored and type(ignored.ListEnabled) == 'table' and table.find(ignored.ListEnabled, tostring(obj)) ~= nil or false
	end

	local function piece(ent, name)
		if type(ent) ~= 'table' then return end
		local hit = ent[name]
		if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		if name == 'RootPart' then
			hit = ent.HumanoidRootPart
			if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		end
		local char = ent.Character
		if typeof(char) ~= 'Instance' then return end
		local real = name == 'RootPart' and 'HumanoidRootPart' or name
		hit = char:FindFirstChild(real) or char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		return char:FindFirstChildWhichIsA('BasePart')
	end

	local function target(origin, walls)
		if type(lib) ~= 'table' or lib.isAlive == false or typeof(origin) ~= 'Vector3' then return end
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
		if not ok or type(ent) ~= 'table' then return end
		local hit = piece(ent, name)
		if not hit then return end
		if type(info) == 'table' and type(info.Targets) == 'table' then info.Targets[ent] = tick() + 1 end
		return ent, hit
	end

	local function spoof(hit, dir)
		if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') or typeof(dir) ~= 'Vector3' then return end
		local mag = dir.Magnitude
		if mag <= 0.0001 then return end
		local unit = dir / mag
		local ok, cf, size, pos = pcall(function() return hit.CFrame, hit.Size, hit.Position end)
		if not ok then return end
		local vec = cf:VectorToObjectSpace(unit)
		local half = size * 0.5
		local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		return pos - unit * (dist + 0.05)
	end

	local function cast(origin, dir, scan)
		local ent, hit = target(origin)
		if not ent then return end
		local pos
		if scan and ctx.origin and type(ctx.origin.line) == 'function' then
			local ok, val = pcall(ctx.origin.line, ctx.origin, hit.Position, dir, hit)
			if ok then pos = val end
		end
		pos = pos or spoof(hit, dir)
		if not pos then return end
		return pos, hit
	end

	local hooks = {}
	local order = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'}

	local function raycast(args, scan)
		local origin, dir = args[1], args[2]
		if not valid(origin, dir) then return end
		local pos, hit = cast(origin, dir, scan)
		if not pos then return end
		args[1] = pos
		if wall and wall.Enabled and hit then
			white.FilterDescendantsInstances = {hit}
			pcall(function() white.CollisionGroup = hit.CollisionGroup end)
			args[3] = white
		end
		return true
	end

	local function legacy(args)
		local beam = args[1]
		if typeof(beam) ~= 'Ray' or not valid(beam.Origin, beam.Direction) then return end
		local pos, hit = cast(beam.Origin, beam.Direction)
		if not pos or not new then return end
		if wall and wall.Enabled and hit then
			local norm = beam.Origin - hit.Position
			norm = norm.Magnitude > 0.001 and norm.Unit or Vector3.yAxis
			return true, {hit, hit.Position, norm, hit.Material}
		end
		args[1] = new(pos, beam.Direction)
		return true
	end

	local function screen(beam)
		if typeof(beam) ~= 'Ray' or not valid(beam.Origin, beam.Direction, true) or not new then return end
		local pos = cast(beam.Origin, beam.Direction)
		if pos then return new(pos, beam.Direction) end
	end

	if rc then hooks.Raycast = {Hook = rc, Args = raycast, Meta = 'Raycast', Owner = workspace} end
	if fr and new then hooks.FindPartOnRay = {Hook = fr, Args = legacy, Meta = 'FindPartOnRay', Owner = workspace} end
	if fi and new then hooks.FindPartOnRayWithIgnoreList = {Hook = fi, Args = legacy, Meta = 'FindPartOnRayWithIgnoreList', Owner = workspace} end
	if fw and new then hooks.FindPartOnRayWithWhitelist = {Hook = fw, Args = legacy, Meta = 'FindPartOnRayWithWhitelist', Owner = workspace} end
	if sr and new then hooks.ScreenPointToRay = {Hook = sr, Result = screen, Meta = 'ScreenPointToRay', Class = 'Camera'} end
	if vr and new then hooks.ViewportPointToRay = {Hook = vr, Result = screen, Meta = 'ViewportPointToRay', Class = 'Camera'} end
	if new then
		hooks.Ray = {
			Hook = new,
			NoNamecall = true,
			NoSelf = true,
			Args = function(args)
				local origin, dir = args[1], args[2]
				if not valid(origin, dir) then return end
				local pos = cast(origin, dir)
				if pos then args[1] = pos return true end
			end
		}
	end
	if rc and ctx.origin and type(ctx.origin.line) == 'function' then
		hooks['Origin Scan'] = {Hook = rc, Args = function(args) return raycast(args, true) end, Meta = 'Raycast', Owner = workspace}
	end

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

	local function base(fn, ...)
		lock += 1
		local out = table.pack(pcall(fn, ...))
		lock -= 1
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	local function direct(name, data, use)
		if type(data) ~= 'table' or type(data.Hook) ~= 'function' then return false end
		local rec = {fn = data.Hook, oth = false}
		local function wrap(...)
			if not rec.old then return data.Hook(...) end
			if not mod.Enabled or skip() then return base(rec.old, ...) end
			if data.NoSelf then
				local args = table.pack(...)
				local changed, out = apply(data, args)
				if changed then
					active = name
					if type(out) == 'table' then return table.unpack(out) end
				end
				return base(rec.old, table.unpack(args, 1, args.n))
			end
			local self, args = ..., {select(2, ...)}
			if data.Result then
				local val = base(rec.old, self, table.unpack(args))
				local out, changed = result(data, val)
				if changed then active = name end
				return out
			end
			local changed, out = apply(data, args)
			if changed then
				active = name
				if type(out) == 'table' then return table.unpack(out) end
			end
			return base(rec.old, self, table.unpack(args))
		end
		if use and oth and type(oth.hook) == 'function' then
			local ok, old = pcall(oth.hook, rec.fn, wrap)
			if ok and type(old) == 'function' then
				rec.old = old
				rec.oth = true
				funcs[#funcs + 1] = rec
				return true
			end
		end
		if type(hookfunction) ~= 'function' then return false end
		local ok, old = pcall(hookfunction, rec.fn, wrap)
		if not ok or type(old) ~= 'function' then return false end
		rec.old = old
		funcs[#funcs + 1] = rec
		return true
	end

	local function meta(name, data)
		if type(data) ~= 'table' or type(data.Hook) ~= 'function' or data.NoNamecall then return false end
		if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' then return false end
		local mt = type(getrawmetatable) == 'function' and getrawmetatable(game) or nil
		local fn = type(mt) == 'table' and mt.__namecall or nil
		if type(fn) ~= 'function' then return false end
		local rec = {fn = fn, meta = true}
		local expect = data.Meta or name
		local old = fn
		local function wrap(self, ...)
			local call = getnamecallmethod()
			if call ~= expect then return old(self, ...) end
			if data.Owner and self ~= data.Owner then return old(self, ...) end
			if data.Class and (typeof(self) ~= 'Instance' or self.ClassName ~= data.Class) then return old(self, ...) end
			if not mod.Enabled or skip() then return base(data.Hook, self, ...) end
			local args = { ... }
			if data.Result then
				local val = base(data.Hook, self, table.unpack(args))
				local out, changed = result(data, val)
				if changed then active = name end
				return out
			end
			local changed, out = apply(data, args)
			if changed then
				active = name
				if type(out) == 'table' then return table.unpack(out) end
			end
			return base(data.Hook, self, table.unpack(args))
		end
		local cb = type(newcclosure) == 'function' and newcclosure(wrap) or wrap
		local ok, val = pcall(hookmetamethod, game, '__namecall', cb)
		if not ok or type(val) ~= 'function' then return false end
		old = val
		rec.old = val
		funcs[#funcs + 1] = rec
		return true
	end

	local function clear()
		for i = #funcs, 1, -1 do
			local rec = funcs[i]
			if rec.meta then
				if type(restorefunction) == 'function' then
					pcall(restorefunction, rec.fn)
				elseif type(hookmetamethod) == 'function' and type(rec.old) == 'function' then
					pcall(hookmetamethod, game, '__namecall', rec.old)
				end
			elseif rec.oth and oth and type(oth.unhook) == 'function' then
				pcall(oth.unhook, rec.fn)
			elseif type(hookfunction) == 'function' and type(rec.old) == 'function' then
				pcall(hookfunction, rec.fn, rec.old)
			elseif type(restorefunction) == 'function' then
				pcall(restorefunction, rec.fn)
			end
			funcs[i] = nil
		end
		if ctx.aim then ctx.aim:stop('magic') end
		active = nil
		lock = 0
		sig = nil
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
			method and method.Value or '',
			data.mode,
			tostring(data.range),
			tostring(data.chance),
			data.part,
			tostring(data.players)
		}, '|')
	end

	local function arsenal()
		if not ctx.aim then
			err = 'Actor support is unavailable.'
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
		local want = method and method.Value
		if want == 'Arsenal' then return arsenal() end
		local data = want and hooks[want]
		if not data then
			err = 'The selected method is unavailable.'
			active = 'Unavailable'
			return false
		end
		local kind = hook and hook.Value or 'Function hook'
		if kind == 'Hookmetamethod' and data.NoNamecall then
			err = 'Hookmetamethod cannot intercept this method.'
			active = 'Unavailable'
			return false
		end
		local ok
		if kind == 'Hookmetamethod' then
			ok = meta(want, data)
		else
			ok = direct(want, data, kind == 'Oth hook')
		end
		if not ok then
			clear()
			err = 'No compatible hook backend is available.'
			active = 'Unavailable'
			return false
		end
		active = want
		return true
	end

	local function notify(msg)
		msg = tostring(msg or 'MagicBullet is unavailable.')
		local now = os.clock()
		if msg == last and now - stamp < 30 then return end
		last = msg
		stamp = now
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'MagicBullet', msg, 6, 'warning')
		end
	end

	local function reload()
		if not mod or not mod.Enabled then return end
		if not install() then notify(err) end
	end

	mod = ctx:module('combat', {
		name = 'MagicBullet',
		autostart = false,
		tooltip = 'Spoofs weapon cast origins',
		extratext = function()
			return active or method and method.Value or ''
		end,
		func = function(on)
			if on then
				paint()
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not install() then notify(err) end
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
		ctx.log:add('module', 'MagicBullet', val)
	end

	targets = make('CreateTargets', {Players = true})
	mode = make('CreateDropdown', {
		Name = 'Target Mode',
		List = {'Mouse', 'Position'},
		Default = 'Mouse',
		Function = paint
	})
	local methods = {}
	if ctx.aim and ctx.aim.ars then methods[#methods + 1] = 'Arsenal' end
	for _, name in ipairs(order) do
		if hooks[name] then methods[#methods + 1] = name end
	end
	if hooks['Origin Scan'] then methods[#methods + 1] = 'Origin Scan' end
	local default = ctx.aim and ctx.aim.ars and 'Arsenal' or hooks.Raycast and 'Raycast' or methods[1]
	method = make('CreateDropdown', {
		Name = 'Method',
		List = methods,
		Default = default,
		Function = reload
	})
	hook = make('CreateDropdown', {
		Name = 'Hook',
		List = {'Function hook', 'Hookmetamethod', 'Oth hook'},
		Default = 'Function hook',
		Function = reload
	})
	ignored = make('CreateTextList', {Name = 'Ignored Scripts', Default = {'CameraModule'}})
	fix = make('CreateToggle', {
		Name = 'RayCamFix',
		Default = true,
		Tooltip = 'Skips camera and obstruction casts.'
	})
	wall = make('CreateToggle', {Name = 'Wallbang'})
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
