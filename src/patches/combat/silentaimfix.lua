return function(ctx)
	local patch = ctx:patch('SilentAim', 'SilentAimfix', 'combat')
	if not patch then return end
	local mod = patch.mod
	local players = game:GetService('Players')
	local lp = players.LocalPlayer
	local fix

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

	fix = patch:option('toggle', {
		name = 'RayCamFix',
		default = true,
		darker = true,
		tooltip = 'Prevents Ray.new SilentAim from redirecting camera and control rays.'
	})
	if fix and fix.Object then fix.Object.Visible = false end
	ctx.raycamfix = fix

	local guard = function(args)
		if fix and fix.Enabled and bypass(args[1], args[2]) then return end
		return old(args)
	end
	local res
	if type(ray) == 'table' then
		res = patch:set('Function', guard, ray)
	else
		res = patch:set('Ray', guard, hooks)
	end
	if not res then error('SilentAim Ray transform could not be patched', 0) end
end
