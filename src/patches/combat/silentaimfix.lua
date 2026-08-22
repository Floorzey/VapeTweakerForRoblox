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
		tooltip = 'Prevents Ray.new SilentAim from redirecting camera and control rays.'
	})
	if fix and fix.Object then fix.Object.Visible = false end
	ctx.raycamfix = fix

	use = patch:option('toggle', {
		name = 'Use Hitboxes',
		default = false,
		tooltip = 'Uses the HitBoxes part and expand amount for SilentAim targeting.'
	})
	if use and use.Object then use.Object.Visible = false end
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
	local function valid(val)
		return type(val) == 'function' or type(val) == 'table' and type(val.Function) == 'function'
	end
	for _, val in pairs(ups(fn)) do
		if type(val) == 'table' and valid(val.Ray) and valid(val.Raycast) and valid(val.ScreenPointToRay) then
			hooks = val
			break
		end
	end
	if not hooks then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim hook table was not found')
		return
	end

	local ray = hooks.Ray
	local old = type(ray) == 'table' and ray.Function or ray
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
	local guns = {
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
		'weapon'
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
		local ok2, val = pcall(obj.GetFullName, obj)
		return ok2 and lower(val) or lower(obj.Name)
	end

	local function parent(obj, list)
		if typeof(obj) ~= 'Instance' then return false end
		local cur = obj.Parent
		for _ = 1, 16 do
			if not cur or cur == game then break end
			if list[lower(cur.Name)] then return true end
			cur = cur.Parent
		end
		return false
	end

	local function camera(obj)
		if typeof(obj) ~= 'Instance' then return false end
		local name = lower(obj.Name)
		local path = full(obj)
		if exact[name] then return true end
		if has(name, cams) or has(path, cams) then return true end
		return parent(obj, {cameramodule = true, controlmodule = true})
	end

	local function weapon(obj)
		if typeof(obj) ~= 'Instance' then return false end
		local cur = obj.Parent
		for _ = 1, 16 do
			if not cur or cur == game then break end
			if cur:IsA('Tool') then return true end
			cur = cur.Parent
		end
		local bag = lp and lp:FindFirstChildOfClass('Backpack')
		if bag and obj:IsDescendantOf(bag) then return true end
		return has(obj.Name, guns) or has(full(obj), guns)
	end

	local function near(a, b, r)
		return (a - b).Magnitude <= r
	end

	local function geometry(origin, dir)
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
			local char = lp and lp.Character
			local root = char and char:FindFirstChild('HumanoidRootPart')
			if root and near(origin, root.Position, 10) and near(last, pos, 10) then return true end
		end
		return len <= 6 and (near(origin, pos, 6) or near(origin, focus, 6))
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return nil end
		local ok2, val = pcall(getcallingscript)
		return ok2 and val or nil
	end

	local function bypass(origin, dir)
		local obj = caller()
		if camera(obj) then return true end
		if weapon(obj) then return false end
		return geometry(origin, dir)
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
		if type(lib) ~= 'table' or not lib.isAlive then table.clear(sett) return end
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
			if lib.isVulnerable(ent) then list[#list + 1] = {Entity = ent, Magnitude = ent.Target and -1 or mag} end
		end
		table.sort(list, sett.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
		for _, val in ipairs(list) do
			local part = val.Entity[name]
			if sett.Wallcheck and lib.Wallcheck(sett.Origin or origin, part.Position, sett.Wallcheck) then continue end
			table.clear(sett)
			table.clear(list)
			return val.Entity
		end
		table.clear(sett)
		table.clear(list)
	end

	local function position(sett, name, amount, active)
		if type(lib) ~= 'table' or not lib.isAlive then table.clear(sett) return end
		local origin = sett.Origin or lib.character.HumanoidRootPart.Position
		local list = {}
		for _, ent in lib.List do
			if not sett.Players and ent.Player then continue end
			if not sett.NPCs and ent.NPC then continue end
			if not ent.Targetable then continue end
			local part = ent[name]
			if typeof(part) ~= 'Instance' or not part:IsA('BasePart') then continue end
			local mag = (point(part, origin, amount, active) - origin).Magnitude
			if mag > sett.Range then continue end
			if lib.isVulnerable(ent) then list[#list + 1] = {Entity = ent, Magnitude = ent.Target and -1 or mag} end
		end
		table.sort(list, sett.Sort or function(a, b) return a.Magnitude < b.Magnitude end)
		for _, val in ipairs(list) do
			local part = val.Entity[name]
			if sett.Wallcheck and lib.Wallcheck(origin, part.Position, sett.Wallcheck) then continue end
			table.clear(sett)
			table.clear(list)
			return val.Entity
		end
		table.clear(sett)
		table.clear(list)
	end

	local function call(cur, args)
		if not use or not use.Enabled or type(lib) ~= 'table' then return cur(args) end
		local name, amount, active = data()
		if not name or type(lib.EntityMouse) ~= 'function' or type(lib.EntityPosition) ~= 'function' then return cur(args) end
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
		local out = table.pack(pcall(cur, args))
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
				return call(cur, args)
			end
		else
			wrap = function(args)
				return call(cur, args)
			end
		end
		local done
		if type(val) == 'table' then done = patch:set('Function', wrap, val) else done = patch:set(name, wrap, hooks) end
		if name == 'Ray' and not done then error('SilentAim Ray transform could not be patched', 0) end
	end
end
