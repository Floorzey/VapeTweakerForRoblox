return function(ctx)
	local aim = {
		ars = game.PlaceId == 286090429,
		live = {},
		err = nil
	}
	local src = [=[
local key, kind, ars, mode, range, chance, head, part, walls, players, id = ...
local env = (getgenv and getgenv()) or _G
env.vtactor = type(env.vtactor) == 'table' and env.vtactor or {}
local box = env.vtactor
local old = box[key]
if type(old) == 'table' then
	for i = #old, 1, -1 do
		local val = old[i]
		if type(val) == 'table' and type(val[1]) == 'function' then
			if type(restorefunction) == 'function' then
				pcall(restorefunction, val[1])
			elseif type(hookfunction) == 'function' and type(val[2]) == 'function' then
				pcall(hookfunction, val[1], val[2])
			end
		end
	end
end
local save = {}
box[key] = save
local ps = game:GetService('Players')
local us = game:GetService('UserInputService')
local lp = ps.LocalPlayer
local rng = Random.new()
local make = Ray.new
local count = 0
local busy = false
local chan
if type(get_comm_channel) == 'function' and type(id) == 'number' then
	pcall(function() chan = get_comm_channel(id) end)
end
local function send(a, b)
	if chan then pcall(chan.Fire, chan, a, b) end
end
local function add(fn, cb)
	if type(fn) ~= 'function' or type(hookfunction) ~= 'function' then return false end
	local base
	local ok, val = pcall(hookfunction, fn, function(...)
		return cb(base, ...)
	end)
	if not ok or type(val) ~= 'function' then return false end
	base = val
	save[#save + 1] = {fn, val}
	count += 1
	return true, val
end
local function alive(plr)
	local char = plr and plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass('Humanoid')
	if not hum or hum.Health <= 0 then return end
	return char
end
local function pick(origin)
	if players == false or not lp then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local cur = us.TouchEnabled and cam.ViewportSize / 2 or us:GetMouseLocation()
	local best
	local dist = math.huge
	for _, plr in ipairs(ps:GetPlayers()) do
		if plr == lp then continue end
		if lp.Team and plr.Team and lp.Team == plr.Team then continue end
		local char = alive(plr)
		if not char then continue end
		local root = char:FindFirstChild('HumanoidRootPart')
		if not root then continue end
		local val
		if mode == 'Position' then
			val = (root.Position - origin).Magnitude
		else
			local pos, vis = cam:WorldToViewportPoint(root.Position)
			if not vis then continue end
			val = (Vector2.new(pos.X, pos.Y) - cur).Magnitude
		end
		if val > range or val >= dist then continue end
		local name = part
		if kind == 'silent' then name = rng:NextNumber(0, 100) <= head and 'Head' or 'HumanoidRootPart' end
		if name == 'RootPart' then name = 'HumanoidRootPart' end
		local hit = char:FindFirstChild(name) or root
		if not hit or not hit:IsA('BasePart') then continue end
		if walls then
			local set = RaycastParams.new()
			set.FilterType = Enum.RaycastFilterType.Exclude
			local list = {}
			if lp.Character then list[#list + 1] = lp.Character end
			set.FilterDescendantsInstances = list
			set.IgnoreWater = true
			busy = true
			local ok, ray = pcall(workspace.Raycast, workspace, origin, hit.Position - origin, set)
			busy = false
			if not ok then continue end
			if ray and not ray.Instance:IsDescendantOf(char) then continue end
		end
		dist = val
		best = hit
	end
	return best
end
local function calc(origin, dir)
	if busy or typeof(origin) ~= 'Vector3' or typeof(dir) ~= 'Vector3' then return origin, dir, false end
	if dir.Magnitude <= 0.0001 or rng:NextNumber(0, 100) > chance then return origin, dir, false end
	local hit = pick(origin)
	if not hit then return origin, dir, false end
	if kind == 'silent' then
		local vec = hit.Position - origin
		if vec.Magnitude <= 0.0001 then return origin, dir, false end
		return origin, vec.Unit * dir.Magnitude, true, hit
	end
	local unit = dir.Unit
	local vec = hit.CFrame:VectorToObjectSpace(unit)
	local half = hit.Size * 0.5
	local dist = math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
	return hit.Position - unit * (dist + 0.05), dir, true, hit
end
local function ray(beam)
	if typeof(beam) ~= 'Ray' then return beam, false end
	local origin, dir, ok, hit = calc(beam.Origin, beam.Direction)
	if not ok then return beam, false end
	busy = true
	local out = make(origin, dir)
	busy = false
	return out, true, hit
end
if ars then
	if type(getgc) == 'function' and type(islclosure) == 'function' and type(debug) == 'table' and type(debug.info) == 'function' and type(debug.getupvalues) == 'function' and type(debug.getconstants) == 'function' then
		local ok, list = pcall(getgc)
		if ok and type(list) == 'table' then
			for _, fn in pairs(list) do
				if type(fn) ~= 'function' or not islclosure(fn) then continue end
				if type(isexecutorclosure) == 'function' then
					local xok, mine = pcall(isexecutorclosure, fn)
					if xok and mine then continue end
				end
				local good, arity = pcall(debug.info, fn, 'a')
				if not good or arity ~= 2 then continue end
				local uok, ups = pcall(debug.getupvalues, fn)
				local cok, cons = pcall(debug.getconstants, fn)
				local nok, name = pcall(debug.info, fn, 'n')
				if not uok or type(ups) ~= 'table' or #ups ~= 2 then continue end
				if not cok or type(cons) ~= 'table' or #cons ~= 17 then continue end
				if not nok or type(name) ~= 'string' or #name > 10 then continue end
				add(fn, function(base, p1, p2)
					if type(base) ~= 'function' then return end
					if typeof(p1) == 'Ray' then p1 = ray(p1) end
					return base(p1, p2)
				end)
			end
		end
	end
else
	local ok, raw = add(Ray.new, function(base, origin, dir)
		if type(base) ~= 'function' then return end
		local a, b = calc(origin, dir)
		return base(a, b)
	end)
	if ok and type(raw) == 'function' then make = raw end
	add(workspace.Raycast, function(base, self, origin, dir, params)
		if type(base) ~= 'function' then return end
		local a, b = calc(origin, dir)
		return base(self, a, b, params)
	end)
	local function legacy(fn)
		add(fn, function(base, self, beam, ...)
			if type(base) ~= 'function' then return end
			local out = ray(beam)
			return base(self, out, ...)
		end)
	end
	legacy(workspace.FindPartOnRay)
	legacy(workspace.FindPartOnRayWithIgnoreList)
	legacy(workspace.FindPartOnRayWithWhitelist)
	local cam = Instance.new('Camera')
	local function camera(fn)
		add(fn, function(base, self, ...)
			if type(base) ~= 'function' then return end
			local beam = base(self, ...)
			local out = ray(beam)
			return out
		end)
	end
	camera(cam.ScreenPointToRay)
	camera(cam.ViewportPointToRay)
end
send('ready', count)
]=]
	local stop = [=[
local key = ...
local env = (getgenv and getgenv()) or _G
local box = type(env.vtactor) == 'table' and env.vtactor or nil
local old = box and box[key]
if type(old) == 'table' then
	for i = #old, 1, -1 do
		local val = old[i]
		if type(val) == 'table' and type(val[1]) == 'function' then
			if type(restorefunction) == 'function' then
				pcall(restorefunction, val[1])
			elseif type(hookfunction) == 'function' and type(val[2]) == 'function' then
				pcall(hookfunction, val[1], val[2])
			end
		end
	end
	box[key] = nil
end
]=]

	local function actors()
		if type(getactors) ~= 'function' then return {} end
		local ok, list = pcall(getactors)
		return ok and type(list) == 'table' and list or {}
	end

	local function send(actor, data, id)
		return pcall(run_on_actor, actor, src,
			data.key,
			data.kind,
			data.ars,
			data.mode,
			data.range,
			data.chance,
			data.head,
			data.part,
			data.walls,
			data.players,
			id
		)
	end

	local function clean(actor, key)
		if type(run_on_actor) ~= 'function' then return false end
		return pcall(run_on_actor, actor, stop, key)
	end

	function aim:stop(key)
		self.live[key] = nil
		for _, actor in ipairs(actors()) do clean(actor, key) end
		return true
	end

	function aim:start(key, kind, ars, data)
		self:stop(key)
		if type(run_on_actor) ~= 'function' or type(getactors) ~= 'function' then
			self.err = 'Actor execution is unavailable on this executor.'
			return false, self.err
		end
		data = type(data) == 'table' and data or {}
		local cfg = {
			key = key,
			kind = kind,
			ars = ars == true,
			mode = data.mode == 'Position' and 'Position' or 'Mouse',
			range = tonumber(data.range) or 150,
			chance = tonumber(data.chance) or 100,
			head = tonumber(data.head) or 100,
			part = data.part == 'RootPart' and 'RootPart' or 'Head',
			walls = data.walls == true,
			players = data.players ~= false
		}
		self.live[key] = cfg
		local list = actors()
		local count = 0
		local calls = 0
		local id
		local chan
		local conn
		if type(create_comm_channel) == 'function' then
			local ok, a, b = pcall(create_comm_channel)
			if ok and type(a) == 'number' and b ~= nil then
				id, chan = a, b
				local event = chan.Event
				if event and type(event.Connect) == 'function' then
					conn = event:Connect(function(msg, val)
						if msg == 'ready' then count += tonumber(val) or 0 end
					end)
				end
			end
		end
		for _, actor in ipairs(list) do
			local ok = send(actor, cfg, id)
			if ok then calls += 1 end
		end
		if conn then
			task.wait(0.05)
			pcall(conn.Disconnect, conn)
		end
		if cfg.ars and #list > 0 and conn and count == 0 then
			self.err = 'Arsenal actor hook was not found.'
			return false, self.err
		end
		if calls == 0 and #list > 0 then
			self.err = 'Actor hooks could not be installed.'
			return false, self.err
		end
		if #list == 0 and not on_actor_state_created then
			self.err = 'No actor state is available.'
			return false, self.err
		end
		self.err = nil
		return true, count
	end

	if on_actor_state_created and type(on_actor_state_created.Connect) == 'function' then
		local conn = on_actor_state_created:Connect(function(actor)
			for _, data in pairs(aim.live) do send(actor, data) end
		end)
		ctx:clean(conn)
	end
	ctx:clean(function()
		for key in pairs(aim.live) do aim:stop(key) end
	end)
	ctx.aim = aim
end
