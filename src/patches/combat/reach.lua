return function(ctx)
	if ctx.vapeapi.flavor ~= 'new' then return end
	local mod = ctx:find('Reach', 'combat') or ctx:find('Reach')
	if type(mod) ~= 'table' or type(mod.Options) ~= 'table' then return end
	local mode = mod.Options.Mode
	local range = mod.Options.Range
	local chance = mod.Options.Chance
	if type(mode) ~= 'table' or type(mode.Change) ~= 'function' or type(mode.SetValue) ~= 'function' or type(range) ~= 'table' then return end
	if type(mod.Function) ~= 'function' then return end

	local players = game:GetService('Players')
	local input = game:GetService('UserInputService')
	local lp = players.LocalPlayer
	local check = type(checkcaller) == 'function' and checkcaller or function() return false end
	local base = mod.Function
	local set = mode.SetValue
	local box
	local rad
	local boxold
	local radold
	local boxfn
	local radfn
	local con
	local tool
	local stamp = 0
	local grips = {}
	local tips = {}
	local list = {'TouchInterest', 'Resize', 'HitboxQuery', 'GripOffset'}
	local props
	local oldlist

	local function getprops()
		if ctx.vapeapi and type(ctx.vapeapi.settings) == 'function' then
			local ok, val = pcall(ctx.vapeapi.settings, ctx.vapeapi, mode)
			if ok and type(val) == 'table' and type(val.List) == 'table' then return val end
		end
		local get = debug and debug.getupvalues or getupvalues
		if type(get) ~= 'function' then return nil end
		for _, fn in ipairs({mode.Change, mode.SetValue, mode.Load, mode.Save}) do
			if type(fn) == 'function' then
				local ok, vals = pcall(get, fn)
				if ok and type(vals) == 'table' then
					for _, val in pairs(vals) do
						if type(val) == 'table' and val.Name == 'Mode' and type(val.List) == 'table' then return val end
					end
				end
			end
		end
	end

	local function setlist(vals)
		if props and type(props.List) == 'table' then
			table.clear(props.List)
			for i, val in ipairs(vals) do props.List[i] = val end
			return true
		end
		if type(mode.Change) == 'function' then
			local ok = pcall(mode.Change, mode, vals)
			return ok
		end
		return false
	end

	props = getprops()
	if props and type(props.List) == 'table' then oldlist = table.clone(props.List) end

	local function tooltip()
		local gets = getconnections
		local get = debug and debug.getupvalue or getupvalue
		local set2 = debug and debug.setupvalue or setupvalue
		local obj = mode.Object
		if type(gets) ~= 'function' or type(get) ~= 'function' or type(set2) ~= 'function' or not obj then return end
		local ok, cons = pcall(gets, obj.MouseEnter)
		if not ok or type(cons) ~= 'table' then return end
		local text = 'TouchInterest - Fake touches\nResize - Enlarges tool\nHitboxQuery - Expands attack queries\nGripOffset - Moves tool forward'
		for _, con2 in pairs(cons) do
			local fn = con2.Function
			if type(fn) == 'function' then
				for i = 1, 20 do
					local out = table.pack(pcall(get, fn, i))
					if not out[1] or out[2] == nil then break end
					local val = out.n >= 3 and out[3] or out[2]
					if type(val) == 'string' and val:find('TouchInterest - Reports fake collision events', 1, true) then
						if pcall(set2, fn, i, text) then tips[#tips + 1] = {fn = fn, idx = i, old = val, set = set2} end
						break
					end
				end
			end
		end
	end

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
		if mod.Enabled and mode.Value == 'HitboxQuery' and obj and obj == gettool() then stamp = os.clock() + 0.8 end
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
		boxfn = nil
		radfn = nil
	end

	local function hook()
		unhook()
		if type(hookfunction) ~= 'function' then return end
		box = workspace.GetPartBoundsInBox
		rad = workspace.GetPartBoundsInRadius
		if type(box) == 'function' then
			boxfn = function(self, cf, size, params)
				if mod.Enabled and mode.Value == 'HitboxQuery' and not check() and boxok(cf, size) then
					local val = math.max(tonumber(range.Value) or 0, 0)
					if val > 0 then size += Vector3.new(val * 2, val * 2, val * 2) end
				end
				return boxold(self, cf, size, params)
			end
			local ok, old = pcall(hookfunction, box, boxfn)
			if ok and type(old) == 'function' then boxold = old else boxfn = nil end
		end
		if type(rad) == 'function' then
			radfn = function(self, pos, size, params)
				if mod.Enabled and mode.Value == 'HitboxQuery' and not check() and radok(pos, size) then
					local val = math.max(tonumber(range.Value) or 0, 0)
					if val > 0 then size += val end
				end
				return radold(self, pos, size, params)
			end
			local ok, old = pcall(hookfunction, rad, radfn)
			if ok and type(old) == 'function' then radold = old else radfn = nil end
		end
	end

	local function joint(obj)
		local char = lp and lp.Character
		if not char or not obj then return nil end
		for _, val in ipairs(char:GetDescendants()) do
			if val.Name == 'RightGrip' and (val:IsA('Motor6D') or val:IsA('Weld')) then
				local p1 = val.Part1
				if p1 and p1:IsDescendantOf(obj) then return val end
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

	local fun = function(callback)
		local val = mode.Value
		if val == 'TouchInterest' or val == 'Resize' then
			return base(callback)
		end
		if not callback then clean() return end
		if val == 'HitboxQuery' then
			bind(gettool())
			hook()
			repeat
				bind(gettool())
				task.wait()
			until not mod.Enabled
			clean()
		elseif val == 'GripOffset' then
			repeat
				grip()
				task.wait()
			until not mod.Enabled
			clean()
		end
	end

	local setfn = function(self, val, click)
		local reload = click and mod.Enabled and val ~= self.Value
		if reload then mod:Toggle() end
		local out = table.pack(set(self, val, click))
		if reload then mod:Toggle() end
		return table.unpack(out, 1, out.n)
	end

	mod.Function = fun
	mode.SetValue = setfn
	if not setlist(list) then error('Reach mode list is unavailable', 0) end
	if props and type(props.List) == 'table' then
		for i, val in ipairs(list) do
			if props.List[i] ~= val then error('Reach mode list update failed', 0) end
		end
	end
	tooltip()
	if chance and chance.Object then chance.Object.Visible = mode.Value == 'TouchInterest' end
	ctx:clean(input.InputBegan:Connect(function(obj, gameproc)
		if gameproc then return end
		if obj.UserInputType == Enum.UserInputType.MouseButton1 then arm(gettool()) end
	end))
	ctx:clean(function()
		clean()
		if mod.Function == fun then mod.Function = base end
		if mode.SetValue == setfn then mode.SetValue = set end
		for _, rec in ipairs(tips) do pcall(rec.set, rec.fn, rec.idx, rec.old) end
		table.clear(tips)
		setlist(oldlist or {'TouchInterest', 'Resize'})
		if chance and chance.Object then chance.Object.Visible = mode.Value == 'TouchInterest' end
	end)
end
