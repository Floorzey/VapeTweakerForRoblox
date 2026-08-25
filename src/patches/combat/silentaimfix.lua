return function(ctx)
	local patch = ctx:patch('SilentAim', 'SilentAimfix', 'combat')
	if not patch then return end
	local mod = patch.mod
	local players = game:GetService('Players')
	local input = game:GetService('UserInputService')
	local lp = players.LocalPlayer
	local fix
	local use
	local fun = mod.Options and mod.Options['Function hook']
	local oth = mod.Options and mod.Options['Oth hook']

	if type(fun) == 'table' then patch:manage(fun, 'Function hook') end
	if type(oth) == 'table' then patch:manage(oth, 'Oth hook') end

	local on = mod.Enabled == true
	if on and type(mod.Toggle) == 'function' then pcall(mod.Toggle, mod) end
	for _, opt in ipairs({fun, oth}) do
		if type(opt) == 'table' and opt.Enabled and type(opt.Toggle) == 'function' then pcall(opt.Toggle, opt) end
	end
	if on and type(mod.Toggle) == 'function' and not mod.Enabled then pcall(mod.Toggle, mod) end

	fix = patch:option('toggle', {
		name = 'RayCamFix',
		default = true,
		darker = true,
		tooltip = 'Prevents ray hooks from redirecting camera, control, spectate and camera-obstruction casts.'
	})
	if fix then patch:visible(fix, false) end
	ctx.raycamfix = fix

	use = patch:option('toggle', {
		name = 'Use Hitboxes',
		default = false,
		tooltip = 'Uses the HitBoxes part and expand amount for SilentAim targeting.'
	})
	if use then patch:visible(use, false) end
	ctx.usehitboxes = use

	local function ups(fn)
		local get = debug and debug.getupvalues or getupvalues
		if type(get) == 'function' then
			local ok, val = pcall(get, fn)
			if ok and type(val) == 'table' then return val end
		end
		get = debug and debug.getupvalue or getupvalue
		if type(get) ~= 'function' then return {} end
		local out = {}
		for i = 1, 48 do
			local val = table.pack(pcall(get, fn, i))
			if not val[1] or val[2] == nil then break end
			out[#out + 1] = val.n >= 3 and val[3] or val[2]
		end
		return out
	end

	local ok, fn = ctx.vapeapi:getprop(mod, 'Function')
	if not ok or type(fn) ~= 'function' then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim Function is unavailable')
		return
	end

	local hooks
	local score = 0
	local names = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'}
	local function valid(val)
		return type(val) == 'function' or type(val) == 'table' and type(val.Function) == 'function'
	end
	for _, val in pairs(ups(fn)) do
		if type(val) ~= 'table' then continue end
		local count = 0
		for _, name in ipairs(names) do
			if valid(val[name]) then count += 1 end
		end
		if count > score then
			hooks = val
			score = count
		end
	end
	if not hooks or score < 3 then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim hook table was not found')
		return
	end

	local baseenv = (getgenv and getgenv()) or _G
	local quietenv = setmetatable({print = function() end, warn = function() end}, {__index = baseenv, __newindex = baseenv})
	local function invoke(cur, args, quiet)
		if quiet and type(trampoline_call) == 'function' then
			local out = table.pack(trampoline_call(cur, {}, {env = quietenv}, args))
			if not out[1] then error(out[2], 0) end
			return table.unpack(out, 2, out.n)
		end
		return cur(args)
	end

	local ray = hooks.Ray
	local exact = {
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
	local cams = {
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

	local function lower(val)
		return tostring(val or ''):lower()
	end

	local function camera(obj)
		if typeof(obj) ~= 'Instance' then return false end
		local cur = obj
		for _ = 1, 20 do
			if not cur or cur == game then break end
			local name = lower(cur.Name)
			if exact[name] then return true end
			for _, token in ipairs(cams) do
				if name:find(token, 1, true) then return true end
			end
			cur = cur.Parent
		end
		return false
	end

	local function near(a, b, r)
		return typeof(a) == 'Vector3' and typeof(b) == 'Vector3' and (a - b).Magnitude <= r
	end

	local function subjectpos(cam)
		if not cam then return nil end
		local sub = cam.CameraSubject
		if typeof(sub) ~= 'Instance' then return nil end
		local ok2, pos = pcall(function() return sub.Position end)
		if ok2 and typeof(pos) == 'Vector3' then return pos end
		local root
		ok2, root = pcall(function() return sub.RootPart end)
		if ok2 and typeof(root) == 'Instance' then
			ok2, pos = pcall(function() return root.Position end)
			if ok2 and typeof(pos) == 'Vector3' then return pos end
		end
		ok2, root = pcall(function() return sub.PrimaryPart end)
		if ok2 and typeof(root) == 'Instance' then
			ok2, pos = pcall(function() return root.Position end)
			if ok2 and typeof(pos) == 'Vector3' then return pos end
		end
		return nil
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok2, val = pcall(getcallingscript)
		return ok2 and val or nil
	end

	local function bypass(origin, dir)
		if camera(caller()) then return true end
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return false end
		local len = dir.Magnitude
		if len <= 0.001 then return true end
		local cam = workspace.CurrentCamera
		if not cam then return false end
		local pos = cam.CFrame.Position
		local focus = cam.Focus.Position
		local sub = subjectpos(cam)
		local char = lp and lp.Character
		local root
		if char then
			local ok2, val = pcall(function() return char.HumanoidRootPart end)
			if ok2 then root = val end
		end
		local rootpos = typeof(root) == 'Instance' and root.Position or nil
		local last = origin + dir
		local zoom = math.max((pos - focus).Magnitude, sub and (pos - sub).Magnitude or 0, rootpos and (pos - rootpos).Magnitude or 0)
		local core = math.clamp(zoom + 8, 10, 96)
		local short = math.clamp((zoom * 6) + 24, 32, 320)
		local function anchor(point, radius)
			if near(point, pos, radius) or near(point, focus, radius) then return true end
			if sub and near(point, sub, radius) then return true end
			return rootpos and near(point, rootpos, radius) or false
		end
		if len <= 8 and anchor(origin, 8) then return true end
		if len <= short and anchor(origin, core) and anchor(last, core) then return true end
		if len <= short then
			if near(origin, focus, core) and near(last, pos, core) then return true end
			if near(origin, pos, core) and near(last, focus, core) then return true end
			if sub and near(origin, sub, core) and near(last, pos, core) then return true end
			if sub and near(origin, pos, core) and near(last, sub, core) then return true end
			if rootpos and near(origin, rootpos, core) and near(last, pos, core) then return true end
			if rootpos and near(origin, pos, core) and near(last, rootpos, core) then return true end
		end
		return false
	end

	local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local hit = ctx:find('HitBoxes', 'blatant') or ctx:find('HitBoxes')
	local head = mod.Options and mod.Options['Headshot Chance']
	local chance = mod.Options and mod.Options['Hit Chance']
	local auto = mod.Options and mod.Options.AutoFire

	local function data()
		if type(hit) ~= 'table' or type(hit.Options) ~= 'table' then return end
		local part = hit.Options.Part
		local expand = hit.Options['Expand amount']
		local name = part and part.Value
		local amount = tonumber(expand and expand.Value)
		if type(name) ~= 'string' or amount == nil then return end
		return name, math.max(amount, 0), hit.Enabled == true
	end

	local function size(part, amount, active)
		local val = part.Size
		if not active and amount > 0 then val += Vector3.new(amount, amount, amount) end
		return val
	end

	local function point(part, pos, amount, active)
		local half = size(part, amount, active) / 2
		local val = part.CFrame:PointToObjectSpace(pos)
		val = Vector3.new(
			math.clamp(val.X, -half.X, half.X),
			math.clamp(val.Y, -half.Y, half.Y),
			math.clamp(val.Z, -half.Z, half.Z)
		)
		return part.CFrame:PointToWorldSpace(val)
	end

	local function mouse(sett, name, amount, active)
		if type(lib) ~= 'table' or lib.isAlive == false or type(lib.List) ~= 'table' then table.clear(sett) return end
		local cam = workspace.CurrentCamera
		if not cam then table.clear(sett) return end
		local cur = sett.MouseOrigin or (input.TouchEnabled and cam.ViewportSize / 2 or input:GetMouseLocation())
		local ray2 = cam:ViewportPointToRay(cur.X, cur.Y)
		local origin = ray2.Origin
		local dir = ray2.Direction.Unit
		local list = {}
		for _, ent in lib.List do
			if not sett.Players and ent.Player then continue end
			if not sett.NPCs and ent.NPC then continue end
			if not ent.Targetable then continue end
			local part = ent[name]
			if typeof(part) ~= 'Instance' or not part:IsA('BasePart') then continue end
			local t = math.max((part.Position - origin):Dot(dir), 0)
			local pos = point(part, origin + (dir * t), amount, active)
			local scr, vis = cam:WorldToViewportPoint(pos)
			if not vis then continue end
			local mag = (cur - Vector2.new(scr.X, scr.Y)).Magnitude
			if mag > sett.Range then continue end
			if type(lib.isVulnerable) ~= 'function' or lib.isVulnerable(ent) then list[#list + 1] = {Entity = ent, Magnitude = ent.Target and -1 or mag} end
		end
		table.sort(list, sett.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
		for _, val in ipairs(list) do
			local part = val.Entity[name]
			if sett.Wallcheck and type(lib.Wallcheck) == 'function' and lib.Wallcheck(sett.Origin or origin, part.Position, sett.Wallcheck) then continue end
			table.clear(sett)
			table.clear(list)
			return val.Entity
		end
		table.clear(sett)
		table.clear(list)
	end

	local function position(sett, name, amount, active)
		if type(lib) ~= 'table' or lib.isAlive == false or type(lib.List) ~= 'table' then table.clear(sett) return end
		local origin = sett.Origin
		if typeof(origin) ~= 'Vector3' then
			local char = lib.character
			local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
			if typeof(root) == 'Instance' and root:IsA('BasePart') then origin = root.Position end
		end
		if typeof(origin) ~= 'Vector3' then table.clear(sett) return end
		local list = {}
		for _, ent in lib.List do
			if not sett.Players and ent.Player then continue end
			if not sett.NPCs and ent.NPC then continue end
			if not ent.Targetable then continue end
			local part = ent[name]
			if typeof(part) ~= 'Instance' or not part:IsA('BasePart') then continue end
			local mag = (point(part, origin, amount, active) - origin).Magnitude
			if mag > sett.Range then continue end
			if type(lib.isVulnerable) ~= 'function' or lib.isVulnerable(ent) then list[#list + 1] = {Entity = ent, Magnitude = ent.Target and -1 or mag} end
		end
		table.sort(list, sett.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
		for _, val in ipairs(list) do
			local part = val.Entity[name]
			if sett.Wallcheck and type(lib.Wallcheck) == 'function' and lib.Wallcheck(origin, part.Position, sett.Wallcheck) then continue end
			table.clear(sett)
			table.clear(list)
			return val.Entity
		end
		table.clear(sett)
		table.clear(list)
	end

	local function call(cur, args, quiet)
		if not use or not use.Enabled or type(lib) ~= 'table' then return invoke(cur, args, quiet) end
		local name, amount, active = data()
		if not name or type(lib.EntityMouse) ~= 'function' or type(lib.EntityPosition) ~= 'function' then return invoke(cur, args, quiet) end
		local oldm = lib.EntityMouse
		local oldp = lib.EntityPosition
		local hv = head and head.Value
		local cv = chance and chance.Value
		local av = auto and auto.Enabled
		lib.EntityMouse = function(sett) return mouse(sett, name, amount, active) end
		lib.EntityPosition = function(sett) return position(sett, name, amount, active) end
		if head then head.Value = name == 'Head' and 100 or 0 end
		if auto and av then
			auto.Enabled = false
			if chance then chance.Value = 100 end
		end
		local out = table.pack(pcall(invoke, cur, args, quiet))
		lib.EntityMouse = oldm
		lib.EntityPosition = oldp
		if head then head.Value = hv end
		if chance then chance.Value = cv end
		if auto then auto.Enabled = av end
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	for name, val in pairs(hooks) do
		local cur = type(val) == 'table' and val.Function or val
		if type(cur) ~= 'function' then continue end
		local wrap
		if name == 'Ray' then
			wrap = function(args)
				if fix and fix.Enabled and bypass(args[1], args[2]) then return end
				return call(cur, args, true)
			end
		else
			wrap = function(args)
				return call(cur, args)
			end
		end
		local done
		if type(val) == 'table' then done = patch:set('Function', wrap, val) else done = patch:set(name, wrap, hooks) end
		if name == 'Ray' and not done then ctx.log:add('patch', 'SilentAimfix', 'SilentAim Ray transform could not be patched') end
	end

	local method = mod.Options and mod.Options.Method
	local info = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local base = {}
	for _, name in ipairs({'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Raycast', 'Ray'}) do
		if valid(hooks[name]) then base[#base + 1] = name end
	end

	local function locate(origin, dir)
		if type(lib) ~= 'table' or type(lib.List) ~= 'table' or typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or dir.Magnitude <= 0.001 then return end
		local unit = dir.Unit
		local best
		local score = math.huge
		local names = {'Head', 'RootPart'}
		local hname = data()
		if type(hname) == 'string' and not table.find(names, hname) then table.insert(names, 1, hname) end
		local now = tick()
		for _, ent in lib.List do
			if not ent.Targetable then continue end
			if type(lib.isVulnerable) == 'function' and not lib.isVulnerable(ent) then continue end
			for _, name in names do
				local part = ent[name]
				if typeof(part) ~= 'Instance' or not part:IsA('BasePart') then continue end
				local rel = part.Position - origin
				local along = rel:Dot(unit)
				if along < 0 or along > dir.Magnitude + 32 then continue end
				local near = origin + unit * along
				local dist = (part.Position - near).Magnitude
				local live = type(info) == 'table' and type(info.Targets) == 'table' and tonumber(info.Targets[ent]) or 0
				local val = dist - (live > now and 1000 or 0)
				if val < score then
					score = val
					best = part
				end
			end
		end
		if best and score < 24 then return best end
		if best and score < -900 then return best end
	end

	local busy = false
	local function scan(args)
		if busy or args[1] ~= workspace then return end
		local origin, dir = args[2], args[3]
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return end
		if fix and fix.Enabled and bypass(origin, dir) then return end
		busy = true
		local vals = {origin, dir, args[4]}
		local ok, out = pcall(hooks.Raycast.Function, vals)
		if not ok then busy = false return end
		if out then busy = false return out end
		if typeof(vals[2]) ~= 'Vector3' or vals[2] == dir then busy = false return end
		local part = locate(origin, vals[2])
		local root = type(lib) == 'table' and lib.character and (lib.character.RootPart or lib.character.HumanoidRootPart)
		local start = typeof(root) == 'Instance' and root.Position or origin
		local pos
		if part and ctx.origin and type(ctx.origin.scan) == 'function' then
			local ok2, val = pcall(ctx.origin.scan, ctx.origin, start, part.Position, nil, part)
			if ok2 then pos = val end
		end
		args[2] = pos or origin
		args[3] = vals[2]
		args[4] = vals[3]
		busy = false
	end

	local raycast
	pcall(function() raycast = workspace.Raycast end)
	if type(method) == 'table' and type(method.Change) == 'function' and type(ctx.origin) == 'table' and type(raycast) == 'function' then
		local val = {Hook = raycast, Function = scan, NoNamecall = true}
		if patch:set('Origin Scan', val, hooks) then
			local list = table.clone(base)
			list[#list + 1] = 'Origin Scan'
			pcall(method.Change, method, list)
			ctx:clean(function()
				if method.Value == 'Origin Scan' and type(method.SetValue) == 'function' then pcall(method.SetValue, method, 'Raycast') end
				pcall(method.Change, method, base)
			end)
		end
	end
end
