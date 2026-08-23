return function(ctx)
	if ctx.vapeapi.flavor ~= 'new' then return end
	local vape = ctx.vape
	local old = ctx:find('Reach', 'combat')
	if type(old) ~= 'table' then return end
	local host = vape.Categories and vape.Categories.Combat
	if type(host) ~= 'table' or type(host.CreateModule) ~= 'function' then return end
	local lp = game:GetService('Players').LocalPlayer
	local input = game:GetService('UserInputService')
	local ent = vape.Libraries and vape.Libraries.entity
	if type(ent) ~= 'table' then return end
	local state = {
		enabled = old.Enabled == true,
		visible = select(1, ctx.vapeapi:getvisible(old)),
		bind = ctx.vapeapi:savebind(old)
	}
	if type(vape.SaveOptions) == 'function' then
		local ok, data = pcall(vape.SaveOptions, vape, old)
		if ok and type(data) == 'table' then state.opts = data end
	end

	local function gettool()
		local char = lp and lp.Character
		return char and char:FindFirstChildWhichIsA('Tool', true) or nil
	end

	local function getpart(tool)
		if not tool then return nil end
		local part = tool:FindFirstChild('Handle')
		if part and part:IsA('BasePart') then return part end
		return tool:FindFirstChildWhichIsA('BasePart', true)
	end

	local function getroot()
		local char = lp and lp.Character
		if not char then return nil end
		return char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
	end

	local function make(extra, own)
		local reach
		local target
		local mode
		local val
		local chance
		local over = OverlapParams.new()
		over.FilterType = Enum.RaycastFilterType.Include
		local mods = {}
		local grips = {}
		local box
		local rad
		local boxold
		local radold
		local act
		local tool
		local stamp = 0
		local rng = Random.new()
		local check = type(checkcaller) == 'function' and checkcaller or function() return false end

		local function sizestop()
			for part, rec in pairs(mods) do
				if part.Parent then
					pcall(function()
						part.Size = rec.size
						part.Massless = rec.mass
					end)
				end
				mods[part] = nil
			end
		end

		local function gripstop(keep)
			for obj, rec in pairs(grips) do
				if obj ~= keep then
					if obj.Parent then pcall(function() obj.C0 = rec.base end) end
					grips[obj] = nil
				end
			end
		end

		local function unhook()
			if type(hookfunction) == 'function' then
				if box and boxold then pcall(hookfunction, box, boxold) end
				if rad and radold then pcall(hookfunction, rad, radold) end
			end
			boxold = nil
			radold = nil
		end

		local function unbind()
			if act then act:Disconnect() act = nil end
			tool = nil
			stamp = 0
		end

		local function clean()
			sizestop()
			gripstop()
			unhook()
			unbind()
		end

		local function arm(obj)
			if reach and reach.Enabled and mode and mode.Value == 'HitboxQuery' and obj and obj == gettool() then
				stamp = os.clock() + 0.8
			end
		end

		local function bind(obj)
			if obj == tool then return end
			if act then act:Disconnect() act = nil end
			tool = obj
			if tool and tool.Activated then
				act = tool.Activated:Connect(function() arm(tool) end)
			end
		end

		local function near(pos, size)
			if typeof(pos) ~= 'Vector3' or os.clock() > stamp then return false end
			local cur = gettool()
			if not cur then return false end
			local part = getpart(cur)
			local root = getroot()
			local pad = math.clamp(tonumber(size) or 0, 0, 40) + 18
			if part and (pos - part.Position).Magnitude <= pad then return true end
			return root and (pos - root.Position).Magnitude <= pad or false
		end

		local function boxok(cf, size)
			if typeof(cf) ~= 'CFrame' or typeof(size) ~= 'Vector3' then return false end
			if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then return false end
			if math.max(size.X, size.Y, size.Z) > 40 then return false end
			return near(cf.Position, size.Magnitude / 2)
		end

		local function radok(pos, size)
			if typeof(pos) ~= 'Vector3' or type(size) ~= 'number' then return false end
			if size <= 0 or size > 30 then return false end
			return near(pos, size)
		end

		local function hook()
			if boxold or radold or type(hookfunction) ~= 'function' then return end
			box = workspace.GetPartBoundsInBox
			rad = workspace.GetPartBoundsInRadius
			if type(box) == 'function' then
				local fn = function(self, cf, size, params)
					if self == workspace and reach.Enabled and mode.Value == 'HitboxQuery' and not check() and boxok(cf, size) then
						local add = math.max(tonumber(val.Value) or 0, 0)
						if add > 0 then size += Vector3.new(add * 2, add * 2, add * 2) end
					end
					return boxold(self, cf, size, params)
				end
				local ok, base = pcall(hookfunction, box, fn)
				if ok and type(base) == 'function' then boxold = base end
			end
			if type(rad) == 'function' then
				local fn = function(self, pos, size, params)
					if self == workspace and reach.Enabled and mode.Value == 'HitboxQuery' and not check() and radok(pos, size) then
						local add = math.max(tonumber(val.Value) or 0, 0)
						if add > 0 then size += add end
					end
					return radold(self, pos, size, params)
				end
				local ok, base = pcall(hookfunction, rad, fn)
				if ok and type(base) == 'function' then radold = base end
			end
		end

		local function joint(cur)
			local char = lp and lp.Character
			if not char or not cur then return nil end
			local fall
			for _, obj in ipairs(char:GetDescendants()) do
				if obj:IsA('Motor6D') or obj:IsA('Weld') then
					local part = obj.Part1
					if part and part:IsDescendantOf(cur) then
						if obj.Name == 'RightGrip' then return obj end
						fall = fall or obj
					end
				end
			end
			return fall
		end

		local function grip()
			local cur = gettool()
			local root = getroot()
			local obj = joint(cur)
			if not cur or not root or not obj or not obj.Part0 then gripstop() return end
			gripstop(obj)
			local rec = grips[obj]
			if not rec then
				rec = {base = obj.C0}
				grips[obj] = rec
			elseif rec.last and obj.C0 ~= rec.last then
				rec.base = obj.C0
			end
			local add = math.max(tonumber(val.Value) or 0, 0)
			local vec = obj.Part0.CFrame:VectorToObjectSpace(root.CFrame.LookVector * add)
			local nextcf = rec.base + vec
			rec.last = nextcf
			obj.C0 = nextcf
		end

		local function touch()
			local cur = gettool()
			local hit = cur and cur:FindFirstChildWhichIsA('TouchTransmitter', true)
			local part = hit and hit.Parent
			if not hit or not part or not part:IsA('BasePart') or type(firetouchinterest) ~= 'function' then return end
			local list = {}
			for _, obj in pairs(ent.List or {}) do
				if obj.Targetable then
					if not target.Players.Enabled and obj.Player then continue end
					if not target.NPCs.Enabled and obj.NPC then continue end
					list[#list + 1] = obj.Character
				end
			end
			over.FilterDescendantsInstances = list
			local add = math.max(tonumber(val.Value) or 0, 0)
			local parts = workspace:GetPartBoundsInBox(part.CFrame * CFrame.new(0, 0, add / 2), part.Size + Vector3.new(0, 0, add), over)
			for _, obj in ipairs(parts) do
				if rng:NextNumber(0, 100) > chance.Value then
					task.wait(0.2)
					break
				end
				firetouchinterest(part, obj, 1)
				firetouchinterest(part, obj, 0)
			end
		end

		local function resize()
			local cur = gettool()
			local hit = cur and cur:FindFirstChildWhichIsA('TouchTransmitter', true)
			local part = hit and hit.Parent
			if not hit or not part or not part:IsA('BasePart') then return end
			local rec = mods[part]
			if not rec then
				rec = {size = part.Size, mass = part.Massless}
				mods[part] = rec
			end
			part.Size = rec.size + Vector3.new(0, 0, math.max(tonumber(val.Value) or 0, 0))
			part.Massless = true
		end

		local function run(on)
			if not on then clean() return end
			repeat
				local name = mode.Value
				if name == 'TouchInterest' then
					sizestop()
					gripstop()
					unhook()
					unbind()
					touch()
				elseif name == 'Resize' then
					gripstop()
					unhook()
					unbind()
					resize()
				elseif extra and name == 'HitboxQuery' then
					sizestop()
					gripstop()
					bind(gettool())
					hook()
				elseif extra and name == 'GripOffset' then
					sizestop()
					unhook()
					unbind()
					grip()
				end
				task.wait()
			until not reach.Enabled
			clean()
		end

		if own then
			reach = ctx:module('combat', {
				name = 'Reach',
				func = run,
				tooltip = 'Extends tool attack reach'
			})
		else
			reach = host:CreateModule({
				Name = 'Reach',
				Function = run,
				Tooltip = 'Extends tool attack reach'
			})
		end
		target = reach:CreateTargets({Players = true})
		mode = reach:CreateDropdown({
			Name = 'Mode',
			List = extra and {'TouchInterest', 'Resize', 'HitboxQuery', 'GripOffset'} or {'TouchInterest', 'Resize'},
			Function = function(name)
				if chance and chance.Object then chance.Object.Visible = name == 'TouchInterest' end
			end,
			Tooltip = extra and 'TouchInterest - Fake touches\nResize - Enlarges tool\nHitboxQuery - Expands queries\nGripOffset - Moves tool forward' or 'TouchInterest - Reports fake collision events to the server\nResize - Physically modifies the tools size'
		})
		val = reach:CreateSlider({
			Name = 'Range',
			Min = 0,
			Max = 2,
			Decimal = 10,
			Suffix = function(num)
				return num == 1 and 'stud' or 'studs'
			end
		})
		chance = reach:CreateSlider({
			Name = 'Chance',
			Min = 0,
			Max = 100,
			Default = 100,
			Suffix = '%'
		})
		chance.Object.Visible = mode.Value == 'TouchInterest'
		return reach, arm
	end

	local function apply(mod, data)
		if data.opts and type(vape.LoadOptions) == 'function' then pcall(vape.LoadOptions, vape, mod, data.opts) end
		if type(data.visible) == 'boolean' then pcall(ctx.vapeapi.setvisible, ctx.vapeapi, mod, data.visible) end
		if data.bind ~= nil then pcall(ctx.vapeapi.setbind, ctx.vapeapi, mod, data.bind) end
		if data.enabled and not mod.Enabled and type(mod.Toggle) == 'function' then pcall(mod.Toggle, mod, true) end
	end

	if old.Enabled and type(old.Toggle) == 'function' then
		pcall(old.Toggle, old, true)
		task.wait()
	end
	local ok, msg = pcall(vape.Remove, vape, 'Reach')
	if not ok then error(msg, 0) end
	if vape.Modules and vape.Modules.Reach == old then error('Reach removal failed', 0) end

	local restored = false
	ctx:clean(function()
		if restored then return true end
		restored = true
		if type(shared) ~= 'table' or shared.vape ~= vape or vape.Loaded == nil then return true end
		if vape.Modules and vape.Modules.Reach then return true end
		local mod = make(false, false)
		apply(mod, state)
		return true
	end)

	local reach, arm = make(true, true)
	apply(reach, state)
	ctx:clean(input.InputBegan:Connect(function(obj, used)
		if not used and obj.UserInputType == Enum.UserInputType.MouseButton1 then arm(gettool()) end
	end))
end
