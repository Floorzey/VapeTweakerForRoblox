return function(ctx)
	local mod
	local targets
	local mode
	local method
	local strategy
	local raytype
	local ignored
	local range
	local chance
	local part
	local wall
	local circle
	local color
	local alpha
	local fill
	local draw
	local silent
	local resume = false

	local entity = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
	local targetinfo = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.targetinfo
	local input = game:GetService('UserInputService')
	local run = game:GetService('RunService')
	local rng = Random.new()
	local cameraProbe = Instance.new('Camera')
	local white = RaycastParams.new()
	white.FilterType = Enum.RaycastFilterType.Include

	local function get(obj, key)
		if obj == nil then return end
		local ok, value = pcall(function() return obj[key] end)
		if ok and type(value) == 'function' then return value end
	end

	local raynew = get(Ray, 'new')
	local workspaceRaycast = get(workspace, 'Raycast')
	local findRay = get(workspace, 'FindPartOnRay')
	local findIgnore = get(workspace, 'FindPartOnRayWithIgnoreList')
	local findInclude = get(workspace, 'FindPartOnRayWithWhitelist')
	local screenRay = get(cameraProbe, 'ScreenPointToRay')
	local viewportRay = get(cameraProbe, 'ViewportPointToRay')

	local hooks = {}
	local metafn
	local oldnamecall
	local metahooked = false
	local bypass = 0
	local active
	local lastError
	local lastNotice
	local lastNoticeAt = 0

	local function mousePosition()
		local cam = workspace.CurrentCamera
		if input.TouchEnabled and cam then
			return cam.ViewportSize / 2
		end
		return input:GetMouseLocation()
	end

	local function eraseCircle()
		if not draw then return end
		pcall(function() draw.Visible = false end)
		pcall(function() draw:Remove() end)
		draw = nil
	end

	local function paintCircle()
		if not draw then return end
		local show = mod and mod.Enabled and circle and circle.Enabled and mode and mode.Value == 'Mouse'
		pcall(function()
			draw.Visible = show == true
			draw.Position = mousePosition()
			draw.Radius = range and range.Value or 150
			draw.Filled = fill and fill.Enabled == true or false
			draw.Color = Color3.fromHSV(color and color.Hue or 0, color and color.Sat or 0, color and color.Value or 1)
			draw.Transparency = 1 - (alpha and alpha.Value or 0.5)
		end)
	end

	local function buildCircle()
		eraseCircle()
		if not circle or not circle.Enabled or not Drawing or type(Drawing.new) ~= 'function' then return end
		local ok, obj = pcall(Drawing.new, 'Circle')
		if not ok or not obj then return end
		draw = obj
		pcall(function()
			obj.NumSides = 100
			obj.Thickness = 1
		end)
		paintCircle()
	end

	local function caller()
		if type(getcallingscript) ~= 'function' then return end
		local ok, obj = pcall(getcallingscript)
		if ok then return obj end
	end

	local function skip()
		if bypass > 0 then return true end
		if type(checkcaller) == 'function' then
			local ok, val = pcall(checkcaller)
			if ok and val then return true end
		end
		local obj = caller()
		return obj and ignored and type(ignored.ListEnabled) == 'table' and table.find(ignored.ListEnabled, tostring(obj)) ~= nil or false
	end

	local function base(fn, ...)
		bypass += 1
		local out = table.pack(pcall(fn, ...))
		bypass -= 1
		if not out[1] then error(out[2], 0) end
		return table.unpack(out, 2, out.n)
	end

	local function entityPart(ent, name)
		if type(ent) ~= 'table' then return end
		local hit = ent[name]
		if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		if name == 'RootPart' then
			hit = ent.HumanoidRootPart
			if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
		end
		local char = ent.Character
		if typeof(char) ~= 'Instance' then return end
		local wanted = name == 'RootPart' and 'HumanoidRootPart' or name
		hit = char:FindFirstChild(wanted) or char:FindFirstChild('Head') or char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if typeof(hit) == 'Instance' and hit:IsA('BasePart') then return hit end
	end

	local function selectTarget(origin, wallObject)
		if type(entity) ~= 'table' or entity.isAlive == false or typeof(origin) ~= 'Vector3' then return end
		if rng:NextNumber(0, 100) > (chance and chance.Value or 100) then return end

		local name = part and part.Value or 'Head'
		local fn = entity['Entity' .. (mode and mode.Value or 'Mouse')]
		if type(fn) ~= 'function' then return end

		bypass += 1
		local ok, ent = pcall(fn, {
			Range = range and range.Value or 150,
			Wallcheck = targets and targets.Walls and targets.Walls.Enabled and (wallObject or true) or nil,
			Part = name,
			Origin = origin,
			Players = not targets or not targets.Players or targets.Players.Enabled ~= false,
			NPCs = targets and targets.NPCs and targets.NPCs.Enabled == true
		})
		bypass -= 1

		if not ok or type(ent) ~= 'table' then return end
		local hit = entityPart(ent, name)
		if not hit then return end
		if type(targetinfo) == 'table' and type(targetinfo.Targets) == 'table' then
			targetinfo.Targets[ent] = tick() + 1
		end
		return ent, hit
	end

	local function redirected(origin, originalDirection, hit)
		if typeof(origin) ~= 'Vector3' or typeof(originalDirection) ~= 'Vector3' then return end
		if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') then return end
		local magnitude = originalDirection.Magnitude
		if magnitude <= 0.0001 then return end
		local delta = hit.Position - origin
		if delta.Magnitude <= 0.0001 then return end
		return delta.Unit * magnitude
	end

	local function spoofOrigin(hit, direction)
		if typeof(hit) ~= 'Instance' or not hit:IsA('BasePart') or typeof(direction) ~= 'Vector3' then return end
		local magnitude = direction.Magnitude
		if magnitude <= 0.0001 then return end

		local unit = direction / magnitude
		local ok, cf, size, pos = pcall(function()
			return hit.CFrame, hit.Size, hit.Position
		end)
		if not ok then return end

		local localDirection = cf:VectorToObjectSpace(unit)
		local half = size * 0.5
		local radius = math.abs(localDirection.X) * half.X + math.abs(localDirection.Y) * half.Y + math.abs(localDirection.Z) * half.Z
		return pos - unit * (radius + 0.05)
	end

	local function acceptsRaycast(params)
		if not raytype or raytype.Value == 'All' or not params then return true end
		if typeof(params) ~= 'RaycastParams' then return true end
		return params.FilterType == Enum.RaycastFilterType[raytype.Value]
	end

	local function selected(name)
		return (method and method.Value or 'Raycast') == name
	end

	local function rewriteVector(origin, direction, wallObject)
		local ent, hit = selectTarget(origin, wallObject)
		if not ent then return end

		if strategy and strategy.Value == 'MagicBullet' then
			local pos = spoofOrigin(hit, direction)
			if not pos then return end
			return pos, direction, hit
		end

		local dir = redirected(origin, direction, hit)
		if not dir then return end
		return origin, dir, hit
	end

	local handlers = {}

	handlers.Raycast = function(args)
		local origin, direction, params = args[1], args[2], args[3]
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' or direction.Magnitude <= 0.0001 then return end
		if not acceptsRaycast(params) then return end

		local newOrigin, newDirection, hit = rewriteVector(origin, direction)
		if not newOrigin then return end

		args[1] = newOrigin
		args[2] = newDirection
		if wall and wall.Enabled and hit then
			white.FilterDescendantsInstances = {hit}
			pcall(function() white.CollisionGroup = hit.CollisionGroup end)
			args[3] = white
		end
		return true
	end

	local function legacyHandler(args, ignoreIndex)
		local beam = args[1]
		if typeof(beam) ~= 'Ray' or not raynew then return end
		local origin, direction = beam.Origin, beam.Direction
		if direction.Magnitude <= 0.0001 then return end

		local wallObject = ignoreIndex and args[ignoreIndex] or nil
		local newOrigin, newDirection, hit = rewriteVector(origin, direction, wallObject)
		if not newOrigin then return end

		if wall and wall.Enabled and hit then
			local normal = origin - hit.Position
			normal = normal.Magnitude > 0.001 and normal.Unit or Vector3.yAxis
			return true, {hit, hit.Position, normal, hit.Material}
		end

		args[1] = raynew(newOrigin, newDirection)
		return true
	end

	handlers.FindPartOnRay = function(args)
		return legacyHandler(args)
	end

	handlers.FindPartOnRayWithIgnoreList = function(args)
		return legacyHandler(args, 2)
	end

	handlers.FindPartOnRayWithWhitelist = function(args)
		return legacyHandler(args, 2)
	end

	local function rayResult(beam)
		if typeof(beam) ~= 'Ray' or not raynew then return end
		local origin, direction = beam.Origin, beam.Direction
		if direction.Magnitude <= 0.0001 then return end
		local newOrigin, newDirection = rewriteVector(origin, direction)
		if not newOrigin then return end
		return raynew(newOrigin, newDirection)
	end

	handlers.ScreenPointToRay = {Result = rayResult}
	handlers.ViewportPointToRay = {Result = rayResult}

	handlers.Ray = function(args)
		if not raynew then return end
		local origin, direction = args[1], args[2]
		if typeof(origin) ~= 'Vector3' or typeof(direction) ~= 'Vector3' or direction.Magnitude <= 0.0001 then return end
		local newOrigin, newDirection = rewriteVector(origin, direction)
		if not newOrigin then return end
		args[1] = newOrigin
		args[2] = newDirection
		return true
	end

	local definitions = {
		Raycast = {Hook = workspaceRaycast, Owner = workspace},
		FindPartOnRay = {Hook = findRay, Owner = workspace},
		FindPartOnRayWithIgnoreList = {Hook = findIgnore, Owner = workspace},
		FindPartOnRayWithWhitelist = {Hook = findInclude, Owner = workspace},
		ScreenPointToRay = {Hook = screenRay, Class = 'Camera', Result = true},
		ViewportPointToRay = {Hook = viewportRay, Class = 'Camera', Result = true},
		Ray = {Hook = raynew, NoSelf = true, NoNamecall = true}
	}

	local function apply(name, args)
		local handler = handlers[name]
		if type(handler) == 'table' then handler = handler.Function end
		if type(handler) ~= 'function' then return false end
		local out = table.pack(pcall(handler, args))
		if not out[1] then return false end
		return out[2] == true, out[3]
	end

	local function transformResult(name, value)
		local handler = handlers[name]
		local fn = type(handler) == 'table' and handler.Result or nil
		if type(fn) ~= 'function' then return value, false end
		local ok, out = pcall(fn, value)
		if ok and out ~= nil then return out, true end
		return value, false
	end

	local function installFunction(name, data)
		if type(hookfunction) ~= 'function' or type(data.Hook) ~= 'function' then return false end
		local rec = {name = name, fn = data.Hook}

		local function wrapper(...)
			if not rec.old then return data.Hook(...) end
			if not mod.Enabled or skip() or not selected(name) then
				return base(rec.old, ...)
			end

			if data.NoSelf then
				local args = table.pack(...)
				local changed, result = apply(name, args)
				if changed then
					active = name
					if type(result) == 'table' then return table.unpack(result) end
				end
				return base(rec.old, table.unpack(args, 1, args.n))
			end

			local self, args = ..., {select(2, ...)}
			if data.Result then
				local value = base(rec.old, self, table.unpack(args))
				local out, changed = transformResult(name, value)
				if changed then active = name end
				return out
			end

			local changed, result = apply(name, args)
			if changed then
				active = name
				if type(result) == 'table' then return table.unpack(result) end
			end
			return base(rec.old, self, table.unpack(args))
		end

		local callback = type(newcclosure) == 'function' and newcclosure(wrapper) or wrapper
		local ok, old = pcall(hookfunction, data.Hook, callback)
		if not ok or type(old) ~= 'function' then return false end
		rec.old = old
		hooks[#hooks + 1] = rec
		return true
	end

	local function namecallHandler(self, ...)
		if not oldnamecall then return end
		local call = getnamecallmethod()
		local data = definitions[call]
		if not data or data.NoNamecall or not selected(call) then
			return base(oldnamecall, self, ...)
		end
		if data.Owner and self ~= data.Owner then return base(oldnamecall, self, ...) end
		if data.Class and (typeof(self) ~= 'Instance' or self.ClassName ~= data.Class) then
			return base(oldnamecall, self, ...)
		end
		if not mod.Enabled or skip() then return base(oldnamecall, self, ...) end

		local args = {...}
		if data.Result then
			local value = base(oldnamecall, self, table.unpack(args))
			local out, changed = transformResult(call, value)
			if changed then active = call end
			return out
		end

		local changed, result = apply(call, args)
		if changed then
			active = call
			if type(result) == 'table' then return table.unpack(result) end
		end
		return base(oldnamecall, self, table.unpack(args))
	end

	local function installMeta()
		if type(hookmetamethod) ~= 'function' or type(getnamecallmethod) ~= 'function' or type(getrawmetatable) ~= 'function' then return false end
		local mt = getrawmetatable(game)
		metafn = type(mt) == 'table' and mt.__namecall or nil
		if type(metafn) ~= 'function' then return false end
		local callback = type(newcclosure) == 'function' and newcclosure(namecallHandler) or namecallHandler
		local ok, old = pcall(hookmetamethod, game, '__namecall', callback)
		if not ok or type(old) ~= 'function' then return false end
		oldnamecall = old
		metahooked = true
		return true
	end

	local function clear()
		for i = #hooks, 1, -1 do
			local rec = hooks[i]
			if type(restorefunction) == 'function' then
				pcall(restorefunction, rec.fn)
			elseif type(hookfunction) == 'function' and type(rec.old) == 'function' then
				pcall(hookfunction, rec.fn, rec.old)
			end
			hooks[i] = nil
		end

		if metahooked then
			if type(restorefunction) == 'function' and type(metafn) == 'function' then
				pcall(restorefunction, metafn)
			elseif type(hookmetamethod) == 'function' and type(oldnamecall) == 'function' then
				pcall(hookmetamethod, game, '__namecall', oldnamecall)
			end
		end

		metafn = nil
		oldnamecall = nil
		metahooked = false
		bypass = 0
		active = nil
	end

	local function install()
		clear()
		lastError = nil

		local wanted = method and method.Value or 'Raycast'
		local data = definitions[wanted]
		if not data then
			lastError = 'The selected method is unavailable.'
			return false
		end

		local count = 0
		if not data.NoNamecall and installMeta() then count += 1 end
		if type(data.Hook) == 'function' and installFunction(wanted, data) then count += 1 end

		if count == 0 then
			lastError = 'No compatible hook backend is available.'
			return false
		end
		return true
	end

	local function notify(message)
		message = tostring(message or 'MagicBullet is unavailable.')
		local now = os.clock()
		if message == lastNotice and now - lastNoticeAt < 30 then return end
		lastNotice = message
		lastNoticeAt = now
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'MagicBullet', message, 6, 'warning')
		end
	end

	local function make(name, data)
		local fn = mod[name]
		if type(fn) ~= 'function' then return end
		local ok, value = pcall(fn, mod, data)
		if ok then return value end
		ctx.log:add('module', 'MagicBullet', value)
	end

	local function setVisible(obj, value)
		if obj and obj.Object then pcall(function() obj.Object.Visible = value end) end
	end

	mod = ctx:module('combat', {
		name = 'MagicBullet',
		autostart = false,
		tooltip = 'Redirects weapon casts toward the selected target',
		extratext = function()
			return active or method and method.Value or 'Raycast'
		end,
		func = function(on)
			if on then
				paintCircle()
				silent = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
				resume = type(silent) == 'table' and silent.Enabled == true
				if resume and type(silent.Toggle) == 'function' then pcall(silent.Toggle, silent) end
				if not install() then
					notify(lastError)
					if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then
						pcall(silent.Toggle, silent)
					end
					resume = false
				end
			else
				paintCircle()
				clear()
				if resume and type(silent) == 'table' and not silent.Enabled and type(silent.Toggle) == 'function' then
					pcall(silent.Toggle, silent)
				end
				resume = false
			end
		end
	})

	targets = make('CreateTargets', {Players = true})
	mode = make('CreateDropdown', {
		Name = 'Mode',
		List = {'Mouse', 'Position'},
		Default = 'Mouse',
		Function = paintCircle
	})
	method = make('CreateDropdown', {
		Name = 'Method',
		List = {'Raycast', 'FindPartOnRay', 'FindPartOnRayWithIgnoreList', 'FindPartOnRayWithWhitelist', 'ScreenPointToRay', 'ViewportPointToRay', 'Ray'},
		Default = 'Raycast',
		Function = function(value)
			setVisible(raytype, value == 'Raycast')
			active = nil
			if mod and mod.Enabled then
				if not install() then notify(lastError) end
			end
		end
	})
	strategy = make('CreateDropdown', {
		Name = 'Strategy',
		List = {'SilentAim', 'MagicBullet'},
		Default = 'SilentAim'
	})
	raytype = make('CreateDropdown', {
		Name = 'Raycast Type',
		List = {'All', 'Exclude', 'Include'},
		Default = 'All',
		Darker = true,
		Visible = true
	})
	ignored = make('CreateTextList', {
		Name = 'Ignored Scripts',
		Default = {'CameraModule'}
	})
	wall = make('CreateToggle', {Name = 'Wallbang'})
	range = make('CreateSlider', {
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 150,
		Suffix = function(value)
			if mode and mode.Value == 'Mouse' then return 'px' end
			return value == 1 and 'stud' or 'studs'
		end,
		Function = paintCircle
	})
	chance = make('CreateSlider', {
		Name = 'Hit Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	part = make('CreateDropdown', {
		Name = 'Part',
		List = {'Head', 'RootPart'},
		Default = 'Head'
	})
	circle = make('CreateToggle', {
		Name = 'Range Circle',
		Function = function(on)
			if on then buildCircle() else eraseCircle() end
			setVisible(color, on)
			setVisible(alpha, on)
			setVisible(fill, on)
		end
	})
	color = make('CreateColorSlider', {
		Name = 'Circle Color',
		Darker = true,
		Visible = false,
		Function = paintCircle
	})
	alpha = make('CreateSlider', {
		Name = 'Transparency',
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.5,
		Darker = true,
		Visible = false,
		Function = paintCircle
	})
	fill = make('CreateToggle', {
		Name = 'Circle Filled',
		Darker = true,
		Visible = false,
		Function = paintCircle
	})

	ctx:clean(run.RenderStepped:Connect(paintCircle))
	ctx:clean(eraseCircle)
	ctx:clean(clear)
	ctx:clean(function() pcall(function() cameraProbe:Destroy() end) end)
end
