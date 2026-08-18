--  a fix for ray methoid because it made my camera bug in fortblox

return function(ctx)
	local patch = ctx:patch('SilentAim', 'SilentAimfix', 'combat')
	if not patch then return end

	local mod = patch.mod
	local players = game:GetService('Players')
	local localPlayer = players.LocalPlayer
	local guard
	local geometryGuard
	local weaponScripts

	local function readUpvalues(fn)
		local getter = debug and debug.getupvalues or getupvalues
		if type(getter) == 'function' then
			local ok, values = pcall(getter, fn)
			if ok and type(values) == 'table' then return values end
		end

		local get = debug and debug.getupvalue or getupvalue
		if type(get) ~= 'function' then return {} end

		local values = {}
		for index = 1, 48 do
			local result = table.pack(pcall(get, fn, index))
			if not result[1] or result[2] == nil then break end
			values[#values + 1] = result.n >= 3 and result[3] or result[2]
		end
		return values
	end

	local ok, moduleFunction = ctx.vapeapi:getprop(mod, 'Function')
	if not ok or type(moduleFunction) ~= 'function' then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim Function is unavailable')
		return
	end

	local hooks
	for _, value in pairs(readUpvalues(moduleFunction)) do
		if type(value) == 'table'
			and type(value.Ray) == 'function'
			and type(value.Raycast) == 'function'
			and type(value.ScreenPointToRay) == 'function' then
			hooks = value
			break
		end
	end

	if not hooks then
		ctx.log:add('patch', 'SilentAimfix', 'SilentAim hook table was not found')
		return
	end

	local originalRay = hooks.Ray

	local exactCamera = {
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

	local cameraPatterns = {
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

	local weaponPatterns = {
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

	local function lower(value)
		return tostring(value or ''):lower()
	end

	local function containsAny(text, patterns)
		text = lower(text)
		for _, pattern in ipairs(patterns) do
			if text:find(pattern, 1, true) then return true end
		end
		return false
	end

	local function fullName(instance)
		if typeof(instance) ~= 'Instance' then return '' end
		local got, value = pcall(instance.GetFullName, instance)
		return got and lower(value) or lower(instance.Name)
	end

	local function manuallyAllowed(instance)
		local list = weaponScripts and weaponScripts.ListEnabled
		if type(list) ~= 'table' then return false end

		local name = typeof(instance) == 'Instance' and lower(instance.Name) or ''
		local path = fullName(instance)
		for _, item in ipairs(list) do
			item = lower(item)
			if item ~= '' and (item == name or item == path or path:find(item, 1, true)) then
				return true
			end
		end
		return false
	end

	local function hasAncestor(instance, wanted)
		if typeof(instance) ~= 'Instance' then return false end
		local current = instance.Parent
		for _ = 1, 16 do
			if not current or current == game then break end
			local name = lower(current.Name)
			if wanted[name] then return true end
			current = current.Parent
		end
		return false
	end

	local function cameraCaller(instance)
		if typeof(instance) ~= 'Instance' then return false end
		local name = lower(instance.Name)
		local path = fullName(instance)
		if exactCamera[name] then return true end
		if containsAny(name, cameraPatterns) or containsAny(path, cameraPatterns) then return true end
		return hasAncestor(instance, {
			cameramodule = true,
			controlmodule = true
		})
	end

	local function weaponCaller(instance)
		if typeof(instance) ~= 'Instance' then return false end

		local current = instance.Parent
		for _ = 1, 16 do
			if not current or current == game then break end
			if current:IsA('Tool') then return true end
			current = current.Parent
		end

		local backpack = localPlayer and localPlayer:FindFirstChildOfClass('Backpack')
		if backpack and instance:IsDescendantOf(backpack) then return true end

		local name = lower(instance.Name)
		local path = fullName(instance)
		return containsAny(name, weaponPatterns) or containsAny(path, weaponPatterns)
	end

	local function near(first, second, radius)
		return (first - second).Magnitude <= radius
	end

	local function cameraGeometry(origin, direction)
		if not geometryGuard or not geometryGuard.Enabled then return false end
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' then return false end

		local length = direction.Magnitude
		if length <= 0.001 then return true end

		local camera = workspace.CurrentCamera
		if not camera then return false end

		local cameraPosition = camera.CFrame.Position
		local focusPosition = camera.Focus.Position
		local endpoint = origin + direction

		if length <= 256 then
			if near(origin, focusPosition, 8) and near(endpoint, cameraPosition, 10) then return true end
			if near(origin, cameraPosition, 8) and near(endpoint, focusPosition, 10) then return true end

			local character = localPlayer and localPlayer.Character
			local root = character and character:FindFirstChild('HumanoidRootPart')
			if root and near(origin, root.Position, 10) and near(endpoint, cameraPosition, 10) then
				return true
			end
		end

		if length <= 6 and (near(origin, cameraPosition, 6) or near(origin, focusPosition, 6)) then
			return true
		end

		return false
	end

	local function callingScript()
		if type(getcallingscript) ~= 'function' then return nil end
		local got, value = pcall(getcallingscript)
		return got and value or nil
	end

	local function shouldBypass(origin, direction)
		local calling = callingScript()
		if manuallyAllowed(calling) then return false end
		if cameraCaller(calling) then return true end
		if weaponCaller(calling) then return false end
		return cameraGeometry(origin, direction)
	end

	weaponScripts = patch:option('textlist', {
		name = 'Ray Weapon Scripts',
		darker = true,
		tooltip = 'Script names or full-name fragments that should always remain eligible for the Ray.new method.'
	})

	geometryGuard = patch:option('toggle', {
		name = 'Ray Geometry Guard',
		default = true,
		darker = true,
		tooltip = 'Also recognizes camera obstruction rays from their origin and endpoint when the calling script is unavailable.'
	})

	guard = patch:option('toggle', {
		name = 'Ray Camera Guard',
		default = true,
		darker = true,
		tooltip = 'Prevents the Ray.new method from redirecting camera, occlusion, shift-lock, and control rays.'
	})

	local guardedRay = function(args)
		if guard and guard.Enabled and shouldBypass(args[1], args[2]) then return end
		return originalRay(args)
	end

	if not patch:set('Ray', guardedRay, hooks) then
		error('SilentAim Ray transform could not be patched', 0)
	end
end
