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
		tooltip = 'Prevents Ray.new hooks from redirecting camera, control, spectate and camera-obstruction casts.'
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
	local projectile = mod.Options and mod.Options.Projectile

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

	local function magic()
		local state = ctx.magicbullet
		if type(state) ~= 'table' or state.enabled ~= true then return nil end
		if type(state.module) == 'table' and state.module.Enabled ~= true then return nil end
		return state
	end

	local function call(cur, args, quiet, capture)
		local captureon = type(capture) == 'table'
		local custom = use and use.Enabled and type(lib) == 'table'
		if not captureon and not custom then return invoke(cur, args, quiet) end
		if type(lib) ~= 'table' or type(lib.EntityMouse) ~= 'function' or type(lib.EntityPosition) ~= 'function' then
			return invoke(cur, args, quiet)
		end

		local oldm = lib.EntityMouse
		local oldp = lib.EntityPosition
		local name, amount, active = data()
		custom = custom and type(name) == 'string' and amount ~= nil
		local hv = head and head.Value
		local cv = chance and chance.Value
		local av = auto and auto.Enabled

		local function record(fn)
			return function(sett)
				local ent = fn(sett)
				if captureon and ent then capture.entity = ent end
				return ent
			end
		end

		if custom then
			lib.EntityMouse = record(function(sett) return mouse(sett, name, amount, active) end)
			lib.EntityPosition = record(function(sett) return position(sett, name, amount, active) end)
			if head then head.Value = name == 'Head' and 100 or 0 end
			if auto and av then
				auto.Enabled = false
				if chance then chance.Value = 100 end
			end
		else
			lib.EntityMouse = record(oldm)
			lib.EntityPosition = record(oldp)
		end

		local out = table.pack(pcall(invoke, cur, args, quiet))
		lib.EntityMouse = oldm
		lib.EntityPosition = oldp
		if custom then
			if head then head.Value = hv end
			if chance then chance.Value = cv end
			if auto then auto.Enabled = av end
		end
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	local function entitypart(ent, name)
		if type(ent) ~= 'table' or type(name) ~= 'string' then return end
		local part = ent[name]
		if typeof(part) == 'Instance' and part:IsA('BasePart') then return part end
		if name == 'RootPart' then
			part = ent.HumanoidRootPart
			if typeof(part) == 'Instance' and part:IsA('BasePart') then return part end
		end
		local char = ent.Character
		if typeof(char) ~= 'Instance' then return end
		local wanted = name == 'RootPart' and 'HumanoidRootPart' or name
		part = char:FindFirstChild(wanted)
		if typeof(part) == 'Instance' and part:IsA('BasePart') then return part end
	end

	local function hintpart(params, ent)
		if typeof(params) ~= 'RaycastParams' or type(ent) ~= 'table' then return end
		local char = ent.Character
		if typeof(char) ~= 'Instance' then return end
		local ok2, list = pcall(function() return params.FilterDescendantsInstances end)
		if not ok2 or type(list) ~= 'table' then return end
		for _, obj in ipairs(list) do
			if typeof(obj) == 'Instance' then
				if obj:IsA('BasePart') and obj:IsDescendantOf(char) then return obj end
				if obj == char then
					local hname = data()
					return entitypart(ent, hname) or entitypart(ent, 'Head') or entitypart(ent, 'RootPart')
				end
			end
		end
	end

	local function pickpart(ent, origin, dir, hinted)
		if typeof(hinted) == 'Instance' and hinted:IsA('BasePart') then return hinted end
		if type(ent) ~= 'table' or typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or dir.Magnitude <= 0.001 then return end
		local unit = dir.Unit
		local order = {}
		local seen = {}
		local hname = data()
		for _, name in ipairs({hname, 'Head', 'RootPart', 'HumanoidRootPart'}) do
			if type(name) == 'string' and not seen[name] then
				seen[name] = true
				order[#order + 1] = name
			end
		end
		local best
		local score = math.huge
		for _, name in ipairs(order) do
			local part = entitypart(ent, name)
			if not part then continue end
			local rel = part.Position - origin
			local along = rel:Dot(unit)
			if along < -2 then continue end
			local closest = origin + unit * math.max(along, 0)
			local dist = (part.Position - closest).Magnitude
			if dist < score then
				score = dist
				best = part
			end
		end
		if not best then return end
		local limit = math.max(3, best.Size.Magnitude * 0.8)
		if score <= limit then return best end
	end

	local function fallbackline(part, dir)
		if typeof(part) ~= 'Instance' or not part:IsA('BasePart') or typeof(dir) ~= 'Vector3' or dir.Magnitude <= 0.001 then return end
		local unit = dir.Unit
		local vec = part.CFrame:VectorToObjectSpace(unit)
		local half = part.Size * 0.5
		local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		return part.Position - unit * (dist + 0.05)
	end

	local function moveorigin(origin, dir, part, state)
		if typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or dir.Magnitude <= 0.001 then return end
		if typeof(part) ~= 'Instance' or not part:IsA('BasePart') then return end
		local api = ctx.origin
		local mode = state and state.mode or 'Near Target'

		if mode == 'Origin Scan' and type(api) == 'table' and type(api.scan) == 'function' then
			local char = type(lib) == 'table' and lib.character
			local root = type(char) == 'table' and (char.RootPart or char.HumanoidRootPart)
			local start = typeof(root) == 'Instance' and root:IsA('BasePart') and root.Position or origin
			local ok2, pos = pcall(api.scan, api, start, part.Position, origin, part)
			if ok2 and typeof(pos) == 'Vector3' then
				local delta = part.Position - pos
				if delta.Magnitude > 0.001 then return pos, delta.Unit * dir.Magnitude end
			end
		end

		local pos
		if type(api) == 'table' and type(api.line) == 'function' then
			local ok2, val = pcall(api.line, api, part.Position, dir, part)
			if ok2 and typeof(val) == 'Vector3' then pos = val end
		end
		pos = pos or fallbackline(part, dir)
		if pos then return pos, dir end
	end

	local function transformvector(origin, dir, ent, hinted, state)
		if projectile and projectile.Enabled then return end
		local part = pickpart(ent, origin, dir, hinted)
		if not part then return end
		return moveorigin(origin, dir, part, state)
	end

	local function wrapraycast(cur)
		return function(args)
			local state = magic()
			if not state then return call(cur, args) end
			local origin = args[1]
			local capture = {}
			local out = table.pack(call(cur, args, false, capture))
			if capture.entity and typeof(origin) == 'Vector3' and typeof(args[2]) == 'Vector3' then
				local hint = hintpart(args[3], capture.entity)
				local pos, dir = transformvector(origin, args[2], capture.entity, hint, state)
				if pos then
					args[1] = pos
					args[2] = dir
				end
			end
			return table.unpack(out, 1, out.n)
		end
	end

	local function wraplegacy(cur)
		return function(args)
			local state = magic()
			if not state then return call(cur, args) end
			local beam = args[1]
			local origin = typeof(beam) == 'Ray' and beam.Origin or nil
			local capture = {}
			local out = table.pack(call(cur, args, false, capture))
			if out.n > 0 and out[1] ~= nil then return table.unpack(out, 1, out.n) end
			beam = args[1]
			if capture.entity and typeof(beam) == 'Ray' and typeof(origin) == 'Vector3' then
				local pos, dir = transformvector(origin, beam.Direction, capture.entity, nil, state)
				if pos then args[1] = Ray.new(pos, dir) end
			end
			return table.unpack(out, 1, out.n)
		end
	end

	local function wrapcamera(cur)
		return function(args)
			local state = magic()
			if not state then return call(cur, args) end
			local capture = {}
			local out = table.pack(call(cur, args, false, capture))
			if capture.entity and type(out[1]) == 'table' and typeof(out[1][1]) == 'Ray' then
				local beam = out[1][1]
				local part = pickpart(capture.entity, beam.Origin, beam.Direction)
				if part and state.mode == 'Origin Scan' then
					local pos, dir = moveorigin(beam.Origin, beam.Direction, part, state)
					if pos then out[1][1] = Ray.new(pos, dir) end
				end
			end
			return table.unpack(out, 1, out.n)
		end
	end

	local function wrapray(cur)
		return function(args)
			if fix and fix.Enabled and bypass(args[1], args[2]) then return end
			local state = magic()
			if not state then return call(cur, args, true) end
			local origin = args[1]
			local capture = {}
			local out = table.pack(call(cur, args, true, capture))
			if capture.entity and typeof(origin) == 'Vector3' and typeof(args[2]) == 'Vector3' then
				local pos, dir = transformvector(origin, args[2], capture.entity, nil, state)
				if pos then
					args[1] = pos
					args[2] = dir
				end
			end
			return table.unpack(out, 1, out.n)
		end
	end

	for name, val in pairs(hooks) do
		local cur = type(val) == 'table' and val.Function or val
		if type(cur) ~= 'function' then continue end
		local wrap
		if name == 'Raycast' then
			wrap = wrapraycast(cur)
		elseif name == 'FindPartOnRay' or name == 'FindPartOnRayWithIgnoreList' or name == 'FindPartOnRayWithWhitelist' then
			wrap = wraplegacy(cur)
		elseif name == 'ScreenPointToRay' or name == 'ViewportPointToRay' then
			wrap = wrapcamera(cur)
		elseif name == 'Ray' then
			wrap = wrapray(cur)
		else
			wrap = function(args) return call(cur, args) end
		end
		local done
		if type(val) == 'table' then done = patch:set('Function', wrap, val) else done = patch:set(name, wrap, hooks) end
		if name == 'Ray' and not done then ctx.log:add('patch', 'SilentAimfix', 'SilentAim Ray transform could not be patched') end
	end

	local fixstate = {
		ready = true,
		hooks = hooks,
		patch = patch
	}
	ctx.silentaimfix = fixstate
	ctx:clean(function()
		if ctx.silentaimfix == fixstate then ctx.silentaimfix = nil end
	end)
end
