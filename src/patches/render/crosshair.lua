return function(ctx)
	local vape = ctx.vape
	if type(vape) ~= 'table' or type(vape.CreateOverlay) ~= 'function' then
		error('Crosshair requires the new Vape GUI overlay API', 0)
	end

	local run = game:GetService('RunService')

	local iconpath = ctx.store:path('assets/crosshair.png')
	local icon = 'rbxassetid://14368354234'
	local present = false
	if type(isfile) == 'function' and iconpath then
		local ok, val = pcall(isfile, iconpath)
		present = ok and val == true
	end
	if not present and iconpath and ctx.store.fs.write then
		local ok, body = pcall(game.HttpGet, game, ctx.loader.base..'/assets/crosshair.png', true)
		if ok and type(body) == 'string' and #body > 8 then
			present = ctx.store:write('assets/crosshair.png', body)
		end
	end
	local asset = vape.Libraries and vape.Libraries.getcustomasset
	if present and type(asset) == 'function' then
		local ok, val = pcall(asset, iconpath)
		if ok and type(val) == 'string' and val ~= '' then icon = val end
	end

	local overlay
	local holder
	local style
	local color
	local size
	local thickness
	local gap
	local outline
	local outlinewidth

	local function clear()
		if not holder then return end
		for _, obj in ipairs(holder:GetChildren()) do
			obj:Destroy()
		end
	end

	local function corner(obj)
		local ui = Instance.new('UICorner')
		ui.CornerRadius = UDim.new(1, 0)
		ui.Parent = obj
		return ui
	end

	local function box(name, parent, width, height, x, y, anchor, fill, transparency, round)
		local obj = Instance.new('Frame')
		obj.Name = name
		obj.Size = UDim2.fromOffset(math.max(1, width), math.max(1, height))
		obj.Position = UDim2.new(0.5, x, 0.5, y)
		obj.AnchorPoint = anchor
		obj.BackgroundColor3 = fill
		obj.BackgroundTransparency = transparency
		obj.BorderSizePixel = 0
		obj.ZIndex = 1000000
		obj.Parent = parent
		if round then corner(obj) end
		return obj
	end

	local function arm(name, width, height, x, y, anchor, fill, transparency, edge)
		if outline.Enabled then
			box(
				name..'Outline',
				holder,
				width + outlinewidth.Value * 2,
				height + outlinewidth.Value * 2,
				x,
				y,
				anchor,
				Color3.new(),
				transparency,
				edge
			)
		end
		box(name, holder, width, height, x, y, anchor, fill, transparency, edge)
	end

	local function dot(name, diameter, fill, transparency)
		if outline.Enabled then
			box(
				name..'Outline',
				holder,
				diameter + outlinewidth.Value * 2,
				diameter + outlinewidth.Value * 2,
				0,
				0,
				Vector2.new(0.5, 0.5),
				Color3.new(),
				transparency,
				true
			)
		end
		box(name, holder, diameter, diameter, 0, 0, Vector2.new(0.5, 0.5), fill, transparency, true)
	end

	local function circle(diameter, line, fill, transparency)
		if outline.Enabled then
			local outer = box(
				'CircleOutline',
				holder,
				diameter,
				diameter,
				0,
				0,
				Vector2.new(0.5, 0.5),
				Color3.new(),
				1,
				true
			)
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.new()
			stroke.Thickness = line + outlinewidth.Value * 2
			stroke.Transparency = transparency
			stroke.Parent = outer
		end

		local ring = box(
			'Circle',
			holder,
			diameter,
			diameter,
			0,
			0,
			Vector2.new(0.5, 0.5),
			fill,
			1,
			true
		)
		local stroke = Instance.new('UIStroke')
		stroke.Color = fill
		stroke.Thickness = line
		stroke.Transparency = transparency
		stroke.Parent = ring
		dot('CenterDot', math.max(2, line + 1), fill, transparency)
	end

	local function optionvisibility()
		if not style then return end
		local selected = style.Value
		if gap then gap.Object.Visible = selected == 'Classic' end
		if thickness then thickness.Object.Visible = selected ~= 'Dot' end
		if outlinewidth then outlinewidth.Object.Visible = outline.Enabled end
	end

	local function draw()
		if not holder or not style or not color or not size or not thickness or not gap or not outline or not outlinewidth then
			return
		end
		clear()
		optionvisibility()

		local fill = Color3.fromHSV(color.Hue, color.Sat, color.Value)
		local transparency = 1 - color.Opacity
		local length = size.Value
		local line = thickness.Value
		local space = gap.Value

		if style.Value == 'Dot' then
			dot('Dot', math.max(2, math.floor(length * 0.45 + 0.5)), fill, transparency)
		elseif style.Value == 'Circle' then
			circle(math.max(8, length * 2), line, fill, transparency)
		else
			arm('Left', length, line, -space, 0, Vector2.new(1, 0.5), fill, transparency, true)
			arm('Right', length, line, space, 0, Vector2.new(0, 0.5), fill, transparency, true)
			arm('Top', line, length, 0, -space, Vector2.new(0.5, 1), fill, transparency, true)
			arm('Bottom', line, length, 0, space, Vector2.new(0.5, 0), fill, transparency, true)
		end
	end

	local centerticket = 0
	local centering = false

	local function positionscale(obj)
		local value = 1
		local current = obj and obj.Parent
		while current do
			if current:IsA('GuiObject') then
				for _, child in ipairs(current:GetChildren()) do
					if child:IsA('UIScale') then
						value *= child.Scale
					end
				end
			end
			current = current.Parent
		end
		return math.max(value, 0.01)
	end

	local function viewportcenter()
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize
		if not viewport or viewport.X <= 0 or viewport.Y <= 0 then
			viewport = Vector2.new(1920, 1080)
		end
		return viewport / 2
	end

	local function center()
		if not overlay or not overlay.Object or not holder then return end
		centerticket += 1
		local ticket = centerticket

		task.spawn(function()
			centering = true
			for _ = 1, 4 do
				run.RenderStepped:Wait()
				if ticket ~= centerticket
					or not overlay
					or not overlay.Object
					or not overlay.Object.Parent
					or not holder
					or not holder.Parent then
					centering = false
					return
				end

				local rendered = holder.AbsolutePosition + (holder.AbsoluteSize / 2)
				local delta = viewportcenter() - rendered
				if math.abs(delta.X) <= 0.25 and math.abs(delta.Y) <= 0.25 then
					break
				end

				local factor = positionscale(overlay.Object)
				local position = overlay.Object.Position
				overlay.Object.Position = UDim2.new(
					position.X.Scale,
					position.X.Offset + (delta.X / factor),
					position.Y.Scale,
					position.Y.Offset + (delta.Y / factor)
				)
			end
			centering = false
		end)
	end

	overlay = vape:CreateOverlay({
		Name = 'Crosshair',
		Icon = icon,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(11, 12),
		CategorySize = 220,
		Function = function(on)
			if holder then holder.Visible = on end
		end
	})

	ctx:clean(function()
		if type(vape.Overlays) == 'table' and type(vape.Overlays.Toggles) == 'table' then
			for i = #vape.Overlays.Toggles, 1, -1 do
				if vape.Overlays.Toggles[i] == overlay.Button then
					table.remove(vape.Overlays.Toggles, i)
				end
			end
		end
		if vape.Categories and vape.Categories.Crosshair == overlay then
			if overlay.Button and overlay.Button.Enabled then pcall(overlay.Button.Toggle, overlay.Button) end
			pcall(vape.Remove, vape, 'Crosshair')
		end
	end)

	holder = Instance.new('Frame')
	holder.Name = 'Crosshair'
	holder.Size = UDim2.fromOffset(160, 160)
	holder.Position = UDim2.fromOffset(110, 0)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Visible = false
	holder.ZIndex = 1000000
	holder.Parent = overlay.Children

	style = overlay:CreateDropdown({
		Name = 'Style',
		List = {'Classic', 'Dot', 'Circle'},
		Function = draw
	})

	color = overlay:CreateColorSlider({
		Name = 'Color',
		DefaultHue = 0,
		DefaultSat = 0,
		DefaultValue = 1,
		DefaultOpacity = 1,
		Function = draw
	})

	size = overlay:CreateSlider({
		Name = 'Size',
		Min = 2,
		Max = 40,
		Default = 12,
		Function = draw
	})

	thickness = overlay:CreateSlider({
		Name = 'Thickness',
		Min = 1,
		Max = 10,
		Default = 2,
		Function = draw
	})

	gap = overlay:CreateSlider({
		Name = 'Gap',
		Min = 0,
		Max = 30,
		Default = 6,
		Function = draw
	})

	outline = overlay:CreateToggle({
		Name = 'Outline',
		Default = true,
		Function = draw
	})

	outlinewidth = overlay:CreateSlider({
		Name = 'Outline Thickness',
		Min = 1,
		Max = 5,
		Default = 1,
		Function = draw
	})

	local centerlocked = false
	overlay:CreateButton({
		Name = 'Center Crosshair',
		Function = function()
			centerlocked = true
			center()
		end
	})

	ctx:clean(overlay.Object:GetPropertyChangedSignal('Position'):Connect(function()
		if not centering then centerlocked = false end
	end))

	local cameraconnection
	local function watchcamera()
		if cameraconnection then
			cameraconnection:Disconnect()
			cameraconnection = nil
		end
		local camera = workspace.CurrentCamera
		if camera then
			cameraconnection = camera:GetPropertyChangedSignal('ViewportSize'):Connect(function()
				if centerlocked then center() end
			end)
		end
	end
	watchcamera()
	ctx:clean(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
		watchcamera()
		if centerlocked then center() end
	end))
	ctx:clean(function()
		if cameraconnection then cameraconnection:Disconnect() end
	end)

	center()
	if not overlay.Pinned then overlay:Pin() end
	draw()

	pcall(function()
		vape:Load(true)
	end)

end
