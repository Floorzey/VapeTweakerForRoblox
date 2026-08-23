return function(ctx)
	local players = game:GetService('Players')
	local run = game:GetService('RunService')
	local input = game:GetService('UserInputService')
	local lp = players.LocalPlayer
	local refs = {}
	local rayparams = RaycastParams.new()
	local mod
	local distance
	local scale
	local objecttext
	local actiontext
	local keybind
	local holdduration
	local targets
	local background
	local color
	local folder
	local elapsed = 0

	rayparams.FilterType = Enum.RaycastFilterType.Exclude
	rayparams.IgnoreWater = true

	local function escape(text)
		return tostring(text)
			:gsub('&', '&amp;')
			:gsub('<', '&lt;')
			:gsub('>', '&gt;')
			:gsub('"', '&quot;')
	end

	local function adornee(prompt)
		local parent = prompt.Parent
		if not parent then return nil end
		if parent:IsA('Attachment') or parent:IsA('BasePart') then
			return parent
		end
		if parent:IsA('Model') then
			return parent.PrimaryPart or parent:FindFirstChildWhichIsA('BasePart', true)
		end
		return parent:FindFirstAncestorWhichIsA('BasePart')
	end

	local function partof(obj)
		if not obj then return nil end
		if obj:IsA('Attachment') then return obj.Parent end
		if obj:IsA('BasePart') then return obj end
	end

	local function position(obj)
		if not obj then return nil end
		if obj:IsA('Attachment') then return obj.WorldPosition end
		if obj:IsA('BasePart') then return obj.Position end
	end

	local function key(prompt)
		local code = prompt.KeyboardKeyCode
		if input.GamepadEnabled and prompt.GamepadKeyCode ~= Enum.KeyCode.Unknown then
			code = prompt.GamepadKeyCode
		end
		if code == Enum.KeyCode.Unknown then return nil end
		return code.Name
	end

	local function objectname(prompt)
		if prompt.ObjectText ~= '' then return prompt.ObjectText end
		local parent = prompt.Parent
		if parent and parent:IsA('Attachment') then parent = parent.Parent end
		return parent and parent.Name or 'Prompt'
	end

	local function maketext(prompt, studs)
		local top = {}
		local bottom = {}

		if objecttext.Enabled then
			top[#top + 1] = '<b>'..escape(objectname(prompt))..'</b>'
		end

		if actiontext.Enabled then
			bottom[#bottom + 1] = escape(prompt.ActionText ~= '' and prompt.ActionText or 'Interact')
		end

		if keybind.Enabled then
			local bind = key(prompt)
			if bind then table.insert(bottom, 1, '['..escape(bind)..']') end
		end

		if holdduration.Enabled and prompt.HoldDuration > 0 then
			bottom[#bottom + 1] = string.format('%.1fs', prompt.HoldDuration)
		end

		if distance.Enabled then
			bottom[#bottom + 1] = tostring(math.floor(studs + 0.5))..' studs'
		end

		if #top == 0 then return table.concat(bottom, '  ') end
		if #bottom == 0 then return table.concat(top, '  ') end
		return table.concat(top, '  ')..'\n'..table.concat(bottom, '  ')
	end

	local function remove(prompt)
		local data = refs[prompt]
		if not data then return end
		refs[prompt] = nil
		data:destroy()
	end

	local function clear()
		for prompt, data in pairs(refs) do
			refs[prompt] = nil
			data:destroy()
		end
	end

	local function add(prompt)
		if refs[prompt] or not prompt:IsA('ProximityPrompt') then return end
		local target = adornee(prompt)
		if not target then return end

		local gui = Instance.new('BillboardGui')
		gui.Name = 'ProximityPromptESP'
		gui.Adornee = target
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.ResetOnSpawn = false
		gui.StudsOffsetWorldSpace = Vector3.new(0, 1.25, 0)
		gui.Size = UDim2.fromOffset(210, 48)
		gui.Parent = folder

		local frame = Instance.new('Frame')
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = Color3.new()
		frame.BackgroundTransparency = 0.35
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = frame

		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Transparency = 0.25
		stroke.Parent = frame

		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, -10, 1, -6)
		label.Position = UDim2.fromOffset(5, 3)
		label.BackgroundTransparency = 1
		label.RichText = true
		label.Text = ''
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.65
		label.TextWrapped = true
		label.TextSize = 14
		label.Font = Enum.Font.Gotham
		label.Parent = frame

		local dead = false
		local data = {
			gui = gui,
			frame = frame,
			label = label,
			stroke = stroke,
			target = target
		}

		function data:destroy()
			if dead then return end
			dead = true
			gui:Destroy()
		end

		refs[prompt] = data
	end

	local function targetallowed(prompt)
		local model = prompt:FindFirstAncestorOfClass('Model')
		if not model then return true end
		if players:GetPlayerFromCharacter(model) then
			return targets.Players.Enabled
		end
		if model:FindFirstChildOfClass('Humanoid') then
			return targets.NPCs.Enabled
		end
		return true
	end

	local function invisible(prompt, target)
		if not prompt.Enabled then return true end
		local part = partof(target)
		if not part then return false end
		return math.max(part.Transparency, part.LocalTransparencyModifier) >= 1
	end

	local function behindwall(prompt, target, origin, pos, char)
		local offset = pos - origin
		if offset.Magnitude <= 0.01 then return false end
		rayparams.FilterDescendantsInstances = char and {char} or {}
		local hit = workspace:Raycast(origin, offset, rayparams)
		if not hit then return false end

		local part = partof(target)
		if part and hit.Instance == part then return false end
		local model = prompt:FindFirstAncestorOfClass('Model')
		if model and hit.Instance:IsDescendantOf(model) then return false end
		return true
	end

	local function update()
		local char = lp.Character
		local root = char and char:FindFirstChild('HumanoidRootPart')
		local cam = workspace.CurrentCamera
		local origin = cam and cam.CFrame.Position or root and root.Position
		if not origin then return end

		local tint = Color3.fromHSV(color.Hue, color.Sat, color.Value)
		local size = scale.Value / 100
		local max = distance.Value
		local removequeue = {}

		for prompt, data in pairs(refs) do
			if not prompt.Parent or not prompt:IsDescendantOf(workspace) then
				removequeue[#removequeue + 1] = prompt
			else
				local target = adornee(prompt)
				local pos = position(target)
				if not target or not pos then
					data.gui.Enabled = false
				else
					if data.target ~= target then
						data.target = target
						data.gui.Adornee = target
					end

					local studs = (pos - origin).Magnitude
					local shown = studs <= max and targetallowed(prompt)
					if shown and targets.Invisible.Enabled then
						shown = not invisible(prompt, target)
					end
					if shown and targets.Walls.Enabled then
						shown = not behindwall(prompt, target, origin, pos, char)
					end
					data.gui.Enabled = shown

					if shown then
						data.gui.Size = UDim2.fromOffset(210 * size, 48 * size)
						data.frame.BackgroundTransparency = background.Enabled and 0.35 or 1
						data.label.TextSize = math.floor(14 * size + 0.5)
						data.label.TextColor3 = tint
						data.label.TextTransparency = studs <= prompt.MaxActivationDistance and 0 or 0.25
						data.stroke.Color = tint
						data.stroke.Enabled = background.Enabled
						data.label.Text = maketext(prompt, studs)
					end
				end
			end
		end

		for _, prompt in ipairs(removequeue) do
			remove(prompt)
		end
	end

	mod = ctx:module('render', {
		name = 'ProximityPromptESP',
		tooltip = 'Extra Sensory Perception for proximity prompts',
		func = function(on)
			if on then
				clear()
				folder = Instance.new('Folder')
				folder.Name = 'ProximityPromptESP'
				folder.Parent = typeof(ctx.vape.gui) == 'Instance' and ctx.vape.gui or lp:WaitForChild('PlayerGui')
				mod:Clean(folder)

				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA('ProximityPrompt') then add(obj) end
				end

				mod:Clean(workspace.DescendantAdded:Connect(function(obj)
					if obj:IsA('ProximityPrompt') then add(obj) end
				end))

				mod:Clean(workspace.DescendantRemoving:Connect(function(obj)
					if obj:IsA('ProximityPrompt') then remove(obj) end
				end))

				mod:Clean(run.Heartbeat:Connect(function(dt)
					elapsed = elapsed + dt
					if elapsed < 0.1 then return end
					elapsed = 0
					update()
				end))

				update()
			else
				clear()
				folder = nil
				elapsed = 0
			end
		end
	})

	targets = mod:CreateTargets({
		Players = true,
		NPCs = true,
		Invisible = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	distance = mod:CreateSlider({
		Name = 'Distance',
		Min = 10,
		Max = 1000,
		Default = 250,
		Suffix = function(val)
			return val == 1 and ' stud' or ' studs'
		end,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	scale = mod:CreateSlider({
		Name = 'Scale',
		Min = 50,
		Max = 150,
		Default = 100,
		Suffix = '%',
		Function = function()
			if mod.Enabled then update() end
		end
	})

	objecttext = mod:CreateToggle({
		Name = 'Object Text',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	actiontext = mod:CreateToggle({
		Name = 'Action Text',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	keybind = mod:CreateToggle({
		Name = 'Keybind',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	holdduration = mod:CreateToggle({
		Name = 'Hold Duration',
		Function = function()
			if mod.Enabled then update() end
		end
	})

	background = mod:CreateToggle({
		Name = 'Background',
		Default = true,
		Function = function()
			if mod.Enabled then update() end
		end
	})

	color = mod:CreateColorSlider({
		Name = 'Color',
		Function = function()
			if mod.Enabled then update() end
		end
	})
end
