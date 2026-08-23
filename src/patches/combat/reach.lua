return function(ctx)
	if ctx.vapeapi.flavor ~= 'new' then return end
	local patch = ctx:patch('Reach', 'ReachMethods', 'combat')
	if not patch then return end
	local mod = patch.mod
	local mode = mod.Options and mod.Options.Mode
	local range = mod.Options and mod.Options.Range
	local chance = mod.Options and mod.Options.Chance
	if type(mode) ~= 'table' or type(range) ~= 'table' then return end
	local ok, base = ctx.vapeapi:getprop(mod, 'Function')
	if not ok or type(base) ~= 'function' then
		ctx.log:add('patch', 'ReachMethods', 'Reach callback is unavailable')
		return
	end
	local _, has = ctx.vapeapi:getlist(mode)
	if not has then
		ctx.log:add('patch', 'ReachMethods', 'Reach mode list is unavailable')
		return
	end

	local players = game:GetService('Players')
	local input = game:GetService('UserInputService')
	local lp = players.LocalPlayer
	local check = type(checkcaller) == 'function' and checkcaller or function() return false end
	local box
	local rad
	local boxold
	local radold
	local con
	local tool
	local stamp = 0
	local grips = {}
	local vis = chance and select(1, ctx.vapeapi:getvisible(chance))
	local list = {'TouchInterest', 'Resize', 'HitboxQuery', 'GripOffset'}

	local function gettool()
		local char = lp and lp.Character
		return char and char:FindFirstChildWhichIsA('Tool') or nil
	end

	local function getpart(obj)
		if not obj then return nil end
		local part = obj:FindFirstChild('Handle')
		if part and part:IsA('BasePart') then return part end
		return obj:FindFirstChildWhichIsA('BasePart', true)
	end

	local function getroot()
		local char = lp and lp.Character
		if not char then return nil end
		return char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
	end

	local function arm(obj)
		if mod.Enabled and mode.Value == 'HitboxQuery' and obj and obj == gettool() then
			stamp = os.clock() + 0.8
		end
	end

	local function bind(obj)
		if obj == tool then return end
		if con then con:Disconnect() con = nil end
		tool = obj
		if tool and tool.Activated then con = tool.Activated:Connect(function() arm(tool) end) end
	end

	local function close(pos, size)
		if typeof(pos) ~= 'Vector3' then return false end
		local cur = gettool()
		if not cur or os.clock() > stamp then return false end
		local part = getpart(cur)
		local root = getroot()
		local pad = math.clamp(tonumber(size) or 0, 0, 32) + 18
		if part and (pos - part.Position).Magnitude <= pad then return true end
		return root and (pos - root.Position).Magnitude <= pad or false
	end

	local function boxok(cf, size)
		if typeof(cf) ~= 'CFrame' or typeof(size) ~= 'Vector3' then return false end
		if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then return false end
		if math.max(size.X, size.Y, size.Z) > 32 then return false end
		return close(cf.Position, size.Magnitude / 2)
	end

	local function radok(pos, size)
		if typeof(pos) ~= 'Vector3' or type(size) ~= 'number' then return false end
		if size <= 0 or size > 24 then return false end
		return close(pos, size)
	end

	local function unhook()
		if type(hookfunction) == 'function' then
			if box and boxold then pcall(hookfunction, box, boxold) end
			if rad and radold then pcall(hookfunction, rad, radold) end
		end
		boxold = nil
		radold = nil
	end

	local function hook()
		unhook()
		if type(hookfunction) ~= 'function' then return end
		box = workspace.GetPartBoundsInBox
		rad = workspace.GetPartBoundsInRadius
		if type(box) == 'function' then
			local fn
			fn = function(self, cf, size, params)
				if mod.Enabled and mode.Value == 'HitboxQuery' and not check() and boxok(cf, size) then
					local val = math.max(tonumber(range.Value) or 0, 0)
					if val > 0 then size += Vector3.new(val * 2, val * 2, val * 2) end
				end
				return boxold(self, cf, size, params)
			end
			local ok2, val = pcall(hookfunction, box, fn)
			if ok2 and type(val) == 'function' then boxold = val end
		end
		if type(rad) == 'function' then
			local fn
			fn = function(self, pos, size, params)
				if mod.Enabled and mode.Value == 'HitboxQuery' and not check() and radok(pos, size) then
					local val = math.max(tonumber(range.Value) or 0, 0)
					if val > 0 then size += val end
				end
				return radold(self, pos, size, params)
			end
			local ok2, val = pcall(hookfunction, rad, fn)
			if ok2 and type(val) == 'function' then radold = val end
		end
	end

	local function joint(obj)
		local char = lp and lp.Character
		if not char or not obj then return nil end
		for _, val in ipairs(char:GetDescendants()) do
			if val.Name == 'RightGrip' and (val:IsA('Motor6D') or val:IsA('Weld')) then
				local part = val.Part1
				if part and part:IsDescendantOf(obj) then return val end
			end
		end
	end

	local function restore(keep)
		for obj, rec in pairs(grips) do
			if obj ~= keep then
				if obj.Parent then pcall(function() obj.C0 = rec.base end) end
				grips[obj] = nil
			end
		end
	end

	local function grip()
		local cur = gettool()
		local root = getroot()
		local obj = joint(cur)
		if not cur or not root or not obj or not obj.Part0 then restore() return end
		restore(obj)
		local rec = grips[obj]
		if not rec then
			rec = {base = obj.C0}
			grips[obj] = rec
		elseif rec.last and obj.C0 ~= rec.last then
			rec.base = obj.C0
		end
		local val = math.max(tonumber(range.Value) or 0, 0)
		local vec = obj.Part0.CFrame:VectorToObjectSpace(root.CFrame.LookVector * val)
		local next = rec.base + vec
		rec.last = next
		obj.C0 = next
	end

	local function clean()
		unhook()
		if con then con:Disconnect() con = nil end
		tool = nil
		stamp = 0
		restore()
	end

	local function show()
		if chance then ctx.vapeapi:setvisible(chance, mode.Value == 'TouchInterest') end
	end

	local function run(callback)
		local val = mode.Value
		if val == 'TouchInterest' or val == 'Resize' then return base(callback) end
		if not callback then clean() return end
		if val == 'HitboxQuery' then
			bind(gettool())
			hook()
			repeat
				bind(gettool())
				task.wait()
			until not mod.Enabled or mode.Value ~= 'HitboxQuery'
			clean()
		elseif val == 'GripOffset' then
			repeat
				grip()
				task.wait()
			until not mod.Enabled or mode.Value ~= 'GripOffset'
			clean()
		end
	end

	if not patch:callback(run) then error('Reach callback patch failed', 0) end
	if not patch:list(mode, list) then error('Reach mode list patch failed', 0) end
	patch:set('Tooltip', 'Changes reach method', mode)
	if type(mode.SetValue) == 'function' then
		patch:wrap('SetValue', function(oldfn, self, val, click)
			local reload = mod.Enabled and val ~= self.Value
			if reload then mod:Toggle() end
			local out = table.pack(oldfn(self, val, click))
			show()
			if reload then mod:Toggle() end
			return table.unpack(out, 1, out.n)
		end, mode)
	end
	show()
	ctx:clean(input.InputBegan:Connect(function(obj, gameproc)
		if gameproc then return end
		if obj.UserInputType == Enum.UserInputType.MouseButton1 then arm(gettool()) end
	end))
	ctx:clean(function()
		clean()
		if chance and vis ~= nil then ctx.vapeapi:setvisible(chance, vis) end
	end)
end
