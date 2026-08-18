return function(ctx)
	local vape = ctx.vape
	if ctx.target.gui ~= 'new' or type(vape) ~= 'table'
		or type(vape.CreateCategory) ~= 'function'
		or type(vape.Categories) ~= 'table'
		or type(vape.Modules) ~= 'table' then
		return
	end

	local tweenservice = game:GetService('TweenService')
	local runservice = game:GetService('RunService')
	local players = game:GetService('Players')
	local textservice = game:GetService('TextService')
	local inputservice = game:GetService('UserInputService')
	local alive = true
	local ticket = 0
	local profile
	local state = {
		favorites = {},
		hidden = {},
		editing = false,
		favoritewindow = {Enabled = false}
	}
	local decorated = {}
	local headers = {}
	local rows = {}
	local apiold = {}
	local assets = {}
	local fav
	local favchildren
	local favbutton
	local openfavorite
	local restoringwindow = false
	local palette
	local bounds = Instance.new('GetTextBoundsParams')
	bounds.Width = math.huge
	ctx:clean(bounds)

	local function isinst(obj)
		return typeof(obj) == 'Instance'
	end

	local function clone(tab)
		local out = {}
		for key, value in pairs(tab or {}) do
			out[key] = value
		end
		return out
	end

	local function tomap(tab)
		local out = {}
		if type(tab) ~= 'table' then return out end
		for key, value in pairs(tab) do
			local name = type(key) == 'number' and value or value and key
			if type(name) == 'string' and name ~= '' then
				out[name] = true
			end
		end
		return out
	end

	local function tolist(tab)
		local out = {}
		for name, enabled in pairs(tab or {}) do
			if enabled then out[#out + 1] = name end
		end
		table.sort(out)
		return out
	end

	local function asset(name)
		if assets[name] ~= nil then return assets[name] end
		local rel = 'assets/gui/'..name
		local full = ctx.store:path(rel)
		local present = false
		if full and type(isfile) == 'function' then
			local ok, value = pcall(isfile, full)
			present = ok and value == true
		end
		if not present and full and ctx.store.fs.write then
			local ok, body = pcall(game.HttpGet, game, ctx.loader.base..'/'..rel, true)
			if ok and type(body) == 'string' and #body > 8 then
				present = ctx.store:write(rel, body)
			end
		end
		local get = vape.Libraries and vape.Libraries.getcustomasset or getcustomasset
		if present and type(get) == 'function' then
			local ok, value = pcall(get, full)
			if ok and type(value) == 'string' then
				assets[name] = value
				return value
			end
		end
		assets[name] = ''
		return ''
	end

	local favoriteoff = asset('favoriteoff.png')
	local favoriteon = asset('favoriteon.png')
	local favoriteofftab = asset('favoriteofftab.png')
	local hiddeneyeoff = asset('hiddeneyeoff.png')
	local editasset = asset('edit.png')

	local function getpalette()
		if palette then return palette end
		local cat
		for name, value in pairs(vape.Categories) do
			if name ~= 'Main' and name ~= 'Favorites' and type(value) == 'table'
				and value.Type == 'Category' and isinst(value.Object) then
				cat = value
				break
			end
		end
		local row
		for _, mod in pairs(vape.Modules) do
			if type(mod) == 'table' and isinst(mod.Object) then
				row = mod.Object
				break
			end
		end
		local window = cat and cat.Object
		local title = window and window:FindFirstChild('Title')
		local dots = row and row:FindFirstChild('Dots')
		dots = dots and dots:FindFirstChild('Dots')
		local font = title and title.FontFace or row and row.FontFace or Font.fromEnum(Enum.Font.Arial)
		palette = {
			main = window and window.BackgroundColor3 or Color3.fromRGB(26, 25, 26),
			text = title and title.TextColor3 or Color3.fromRGB(200, 200, 200),
			inactive = dots and dots.ImageColor3 or Color3.fromRGB(120, 120, 128),
			font = font,
			semibold = Font.new(font.Family, Enum.FontWeight.SemiBold)
		}
		return palette
	end

	local function shifted(col, amount, light)
		local pal = getpalette()
		local h, s, v = col:ToHSV()
		local _, _, mainv = pal.main:ToHSV()
		local delta
		if light then
			delta = mainv > 0.5 and -amount or amount
		else
			delta = mainv > 0.5 and amount or -amount
		end
		return Color3.fromHSV(h, s, math.clamp(v + delta, 0, 1))
	end

	local function light(col, amount)
		return shifted(col, amount, true)
	end

	local function dark(col, amount)
		return shifted(col, amount, false)
	end

	local function textwidth(text, size, font)
		bounds.Text = tostring(text or '')
		bounds.Size = size
		bounds.Font = font
		local ok, value = pcall(textservice.GetTextBoundsAsync, textservice, bounds)
		return ok and value.X or (#bounds.Text * size * 0.55)
	end

	local function tween(obj, info, goal)
		if not isinst(obj) then return end
		local ok, value = pcall(tweenservice.Create, tweenservice, obj, info, goal)
		if ok then value:Play() end
	end

	local function pulse(obj)
		if not isinst(obj) then return end
		if obj:IsA('ImageButton') or obj:IsA('ImageLabel') then
			local size = obj:GetAttribute('VTOriginalSize') or obj.Size
			obj:SetAttribute('VTOriginalSize', size)
			tween(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(size.X.Offset + 3, size.Y.Offset + 3)
			})
			task.delay(0.08, function()
				if alive and isinst(obj) and obj.Parent then
					tween(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = size})
				end
			end)
			return
		end
		local size = obj:GetAttribute('VTOriginalTextSize') or obj.TextSize
		obj:SetAttribute('VTOriginalTextSize', size)
		tween(obj, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = size + 3})
		task.delay(0.08, function()
			if alive and isinst(obj) and obj.Parent then
				tween(obj, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextSize = size})
			end
		end)
	end

	local function activecolor()
		return Color3.fromRGB(255, 170, 42)
	end

	local function starvisual(star, active, hover)
		if not isinst(star) then return end
		local pal = getpalette()
		if star:IsA('ImageButton') or star:IsA('ImageLabel') then
			star.Image = active and favoriteon or favoriteoff
			tween(star, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				ImageColor3 = active and Color3.new(1, 1, 1)
					or hover and dark(pal.text, 0.16) or light(pal.main, 0.37),
				ImageTransparency = 0
			})
		else
			tween(star, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				TextColor3 = active and activecolor()
					or hover and dark(pal.text, 0.16) or light(pal.main, 0.37)
			})
		end
	end

	local function placeid()
		return tostring(math.floor(tonumber(game.PlaceId) or 0))
	end

	local function configpath(dir, id)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/'..tostring(id or placeid())..'.lua'
	end

	local function legacyconfigpath(dir)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/gui.json'
	end

	local function migrationpath(dir)
		dir = dir or ctx.profile and ctx.profile.dir or 'default'
		return 'configs/profiles/'..dir..'/placeconfigs.migrated'
	end

	local function luastr(value)
		return string.format('%q', tostring(value))
	end

	local function lualist(values)
		local out = {}
		for index, value in ipairs(values or {}) do
			out[index] = luastr(value)
		end
		return '{'..table.concat(out, ', ')..'}'
	end

	local function number(value, fallback)
		value = tonumber(value)
		if not value or value ~= value or value == math.huge or value == -math.huge then
			return fallback or 0
		end
		return value
	end

	local function readconfig(path)
		local raw = ctx.store:read(path)
		if not raw then return nil end
		local compiled, err = loadstring(raw)
		if not compiled then
			ctx.log:add('config_parse', path, err)
			return nil
		end
		local ok, data = pcall(compiled)
		if ok and type(data) == 'table' then return data end
		ctx.log:add('config_parse', path, ok and 'config did not return a table' or data)
	end

	local function syncapi()
		vape.Favorites = vape.Favorites or {}
		vape.Favorites.List = tolist(state.favorites)
		vape.Favorites.Rows = rows
		vape.Favorites.StarButton = favbutton
		vape.Hidden = vape.Hidden or {}
		vape.Hidden.List = tolist(state.hidden)
		vape.Hidden.Editing = state.editing
	end

	local function favoritewindow()
		local saved = state.favoritewindow or {Enabled = false}
		if fav and isinst(fav.Object) then
			local position = fav.Object.Position
			saved = {
				Enabled = fav.Button and fav.Button.Enabled == true or false,
				Expanded = fav.Expanded == true,
				Position = {
					XScale = position.X.Scale,
					X = position.X.Offset,
					YScale = position.Y.Scale,
					Y = position.Y.Offset
				}
			}
		end
		state.favoritewindow = saved
		return saved
	end

	local function configsource()
		local window = favoritewindow()
		local position = window.Position or window.position or {}
		return table.concat({
			'return {',
			'\tversion = 4,',
			'\tplaceid = '..placeid()..',',
			'\tfavorites = '..lualist(tolist(state.favorites))..',',
			'\thidden = '..lualist(tolist(state.hidden))..',',
			'\ttabs = {',
			'\t\tFavorites = {',
			'\t\t\tEnabled = '..tostring(window.Enabled == true)..',',
			'\t\t\tExpanded = '..tostring(window.Expanded == true)..',',
			'\t\t\tPosition = {',
			'\t\t\t\tXScale = '..tostring(number(position.XScale or position.xscale, 0))..',',
			'\t\t\t\tX = '..tostring(number(position.X or position.XOffset or position.x or position.xoffset, 0))..',',
			'\t\t\t\tYScale = '..tostring(number(position.YScale or position.yscale, 0))..',',
			'\t\t\t\tY = '..tostring(number(position.Y or position.YOffset or position.y or position.yoffset, 0)),
			'\t\t\t}',
			'\t\t}',
			'\t}',
			'}'
		}, '\n')
	end

	local function save(dir)
		if not alive then return false end
		return ctx.store:write(configpath(dir), configsource())
	end

	local function queuesave()
		ticket = ticket + 1
		local current = ticket
		task.delay(0.35, function()
			if alive and ticket == current then save() end
		end)
	end

	local function load()
		profile = ctx.profile and ctx.profile.dir or 'default'
		local file = configpath(profile)
		local data = readconfig(file)
		local created = type(data) ~= 'table'
		if data and tonumber(data.placeid) ~= tonumber(game.PlaceId) then
			data = nil
			created = true
		end

		if not data and not ctx.store:has(migrationpath(profile)) then
			local legacy = ctx.store:json(legacyconfigpath(profile))
			if type(legacy) == 'table' then data = legacy end
			ctx.store:write(migrationpath(profile), placeid())
		end

		state.favorites = tomap(data and data.favorites)
		state.hidden = tomap(data and data.hidden)
		local tabs = data and data.tabs
		local window = type(tabs) == 'table' and (tabs.Favorites or tabs.favorites)
			or data and data.favoritewindow
		local position = type(window) == 'table' and (window.Position or window.position)
		state.favoritewindow = {
			Enabled = type(window) == 'table' and (window.Enabled == true or window.enabled == true) or false,
			Expanded = type(window) == 'table' and (window.Expanded == true or window.expanded == true) or false,
			Position = type(position) == 'table' and {
				XScale = number(position.XScale or position.xscale, 0),
				X = number(position.X or position.XOffset or position.x or position.xoffset, 0),
				YScale = number(position.YScale or position.yscale, 0),
				Y = number(position.Y or position.YOffset or position.y or position.yoffset, 0)
			} or nil
		}
		state.editing = false
		syncapi()
		if created or not ctx.store:has(file) then save(profile) end
	end

	local function accent(mod)
		local gui = vape.GUIColor
		if type(gui) == 'table' then
			local h = tonumber(gui.Hue) or 0.46
			local s = tonumber(gui.Sat) or 0.96
			local v = tonumber(gui.Value) or 0.52
			if gui.Rainbow and type(vape.Color) == 'function' then
				local ok, ch, cs, cv = pcall(vape.Color, vape, (h - (((mod and mod.Index) or 1) * 0.025)) % 1)
				if ok then
					if typeof(ch) == 'Color3' then return ch end
					if type(ch) == 'number' then return Color3.fromHSV(ch, cs or 1, cv or 1) end
				end
			end
			return Color3.fromHSV(h, s, v)
		end
		return Color3.fromRGB(5, 134, 105)
	end

	local function corner(parent, radius)
		local value = Instance.new('UICorner')
		value.CornerRadius = radius or UDim.new(0, 5)
		value.Parent = parent
		return value
	end

	local function makehiddenrail(parent, zindex)
		local rail = Instance.new('Frame')
		rail.Name = 'VTHiddenRail'
		rail.Size = UDim2.new(0, 43, 1, 0)
		rail.Position = UDim2.fromOffset(0, 0)
		rail.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		rail.BackgroundTransparency = 0
		rail.BorderSizePixel = 0
		rail.Visible = false
		rail.ZIndex = zindex or parent.ZIndex
		rail.Parent = parent
		return rail
	end

	local function makehiddenbox(parent, zindex)
		local box = Instance.new('TextButton')
		box.Name = 'HiddenBox'
		box.Size = UDim2.fromOffset(12, 12)
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		box.Position = UDim2.new(0, 21.5, 0.5, 0)
		box.BackgroundColor3 = Color3.fromRGB(52, 52, 58)
		box.BackgroundTransparency = 0
		box.BorderSizePixel = 0
		box.AutoButtonColor = false
		box.Visible = false
		box.Text = ''
		box.ZIndex = zindex or parent.ZIndex
		box.Parent = parent

		local gap = Instance.new('Frame')
		gap.Name = 'Outline'
		gap.Size = UDim2.new(1, -2, 1, -2)
		gap.Position = UDim2.fromOffset(1, 1)
		gap.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		gap.BackgroundTransparency = 0
		gap.BorderSizePixel = 0
		gap.ZIndex = box.ZIndex
		gap.Parent = box

		local fill = Instance.new('Frame')
		fill.Name = 'Fill'
		fill.Size = UDim2.new(1, -4, 1, -4)
		fill.Position = UDim2.fromOffset(2, 2)
		fill.BackgroundTransparency = 1
		fill.BorderSizePixel = 0
		fill.ZIndex = box.ZIndex + 1
		fill.Parent = box
		return box, gap, fill
	end

	local function updatehiddenbox(box, gap, fill, hidden, mod)
		if not isinst(box) or not isinst(gap) or not isinst(fill) then return end
		local color = hidden and Color3.fromRGB(52, 52, 58) or accent(mod)
		box.BackgroundColor3 = color
		box.BackgroundTransparency = 0
		gap.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		gap.BackgroundTransparency = 0
		fill.BackgroundColor3 = color
		fill.BackgroundTransparency = hidden and 1 or 0
	end

	local refreshfavorites
	local updateheaders
	local applymodule
	local updatefavoriterow

	local function isfavorite(name)
		return state.favorites[name] == true
	end

	local function ishidden(name)
		return state.hidden[name] == true
	end

	local function hiddenincategory(category)
		local count = 0
		for _, mod in pairs(vape.Modules) do
			if type(mod) == 'table' and mod.Category == category and ishidden(mod.Name) then
				count = count + 1
			end
		end
		return count
	end

	local function restorechildren(data, hide)
		if not data or not data.favoriteopen or not isinst(data.children) then return end
		data.children.Visible = false
		if isinst(data.originalparent) then
			data.children.Parent = data.originalparent
			data.children.LayoutOrder = data.originalorder
		end
		data.favoriteopen = false
		if openfavorite == data then openfavorite = nil end
		if not hide then data.children.Visible = false end
		if applymodule then applymodule(data.mod) end
		if updatefavoriterow then updatefavoriterow(data.mod.Name) end
	end

	local function closefavoritechildren()
		if openfavorite then restorechildren(openfavorite, true) end
	end

	local function setfavoritechildren(data, enabled, order)
		if not data or not isinst(data.children) or state.editing then return end
		if not enabled then
			restorechildren(data, true)
			return
		end
		if openfavorite and openfavorite ~= data then restorechildren(openfavorite, true) end
		if data.children.Parent ~= data.originalparent and not data.favoriteopen then
			data.originalparent = data.children.Parent
			data.originalorder = data.children.LayoutOrder
		end
		data.children.Visible = false
		data.children.Parent = favchildren
		data.children.LayoutOrder = order
		data.children.Visible = true
		data.favoriteopen = true
		openfavorite = data
		applymodule(data.mod)
		updatefavoriterow(data.mod.Name)
	end

	local function setfavorite(name, enabled, skipsave)
		local mod = vape.Modules[name]
		if type(mod) ~= 'table' then return end
		state.favorites[name] = enabled and true or nil
		mod.Favorited = enabled and true or false
		local data = decorated[mod]
		if not enabled and data and data.favoriteopen then restorechildren(data, true) end
		syncapi()
		applymodule(mod)
		refreshfavorites()
		if not skipsave then queuesave() end
	end

	local function sethidden(name, enabled, skipsave)
		local mod = vape.Modules[name]
		if type(mod) ~= 'table' then return end
		state.hidden[name] = enabled and true or nil
		local data = decorated[mod]
		if enabled and data then
			if data.favoriteopen then restorechildren(data, true) end
			if isinst(data.children) then data.children.Visible = false end
		end
		syncapi()
		applymodule(mod)
		refreshfavorites()
		updateheaders()
		if not skipsave then queuesave() end
	end

	local function setediting(enabled)
		state.editing = enabled and true or false
		if state.editing then
			closefavoritechildren()
			for _, data in pairs(decorated) do
				if isinst(data.children) then data.children.Visible = false end
			end
		end
		syncapi()
		for _, data in pairs(decorated) do applymodule(data.mod) end
		refreshfavorites()
		updateheaders()
	end

	local function cleanstale(parent)
		if not isinst(parent) then return end
		for _, name in ipairs({
			'VTFavorite', 'VTHideShield', 'VTHideGuard', 'VTEditHidden',
			'VTDoneHidden', 'VTHiddenCount', 'VTHiddenRail', 'Favorite', 'HiddenBox',
			'EditHiddenModules', 'DoneHiddenModules', 'HiddenCount'
		}) do
			local child = parent:FindFirstChild(name)
			if child then child:Destroy() end
		end
	end

	local function addheader(name, cat)
		if headers[name] or name == 'Main' or type(cat) ~= 'table'
			or cat.Type ~= 'Category' or not isinst(cat.Object) then return end
		local window = cat.Object
		cleanstale(window)
		local pal = getpalette()

		local edit = Instance.new('TextButton')
		edit.Name = 'EditHiddenModules'
		edit.Size = UDim2.fromOffset(30, 40)
		edit.Position = UDim2.new(1, -61, 0, 0)
		edit.BackgroundTransparency = 1
		edit.AutoButtonColor = false
		edit.Visible = false
		edit.Text = ''
		edit.Parent = window

		local editicon = Instance.new('ImageLabel')
		editicon.Name = 'Icon'
		editicon.Size = UDim2.fromOffset(12, 12)
		editicon.Position = UDim2.fromOffset(11, 14)
		editicon.BackgroundTransparency = 1
		editicon.Image = editasset
		editicon.ImageColor3 = light(pal.main, 0.37)
		editicon.Parent = edit

		local done = Instance.new('TextButton')
		done.Name = 'DoneHiddenModules'
		done.Size = UDim2.fromOffset(58, 40)
		done.Position = UDim2.new(1, -75, 0, 0)
		done.BackgroundTransparency = 1
		done.AutoButtonColor = false
		done.Visible = false
		done.Text = 'DONE'
		done.TextColor3 = dark(pal.text, 0.16)
		done.TextSize = 12
		done.FontFace = pal.font
		done.Parent = window

		local count = Instance.new('Frame')
		count.Name = 'HiddenCount'
		count.Size = UDim2.fromOffset(40, 40)
		count.Position = UDim2.new(1, -60, 0, 0)
		count.BackgroundTransparency = 1
		count.Visible = false
		count.Parent = window

		local number = Instance.new('TextLabel')
		number.Name = 'Count'
		number.Size = UDim2.fromOffset(12, 40)
		number.Position = UDim2.fromOffset(3, 0)
		number.BackgroundTransparency = 1
		number.Text = '0'
		number.TextColor3 = Color3.fromRGB(145, 145, 153)
		number.TextSize = 13
		number.FontFace = pal.font
		number.Parent = count

		local eye = Instance.new('ImageLabel')
		eye.Name = 'Eye'
		eye.Size = UDim2.fromOffset(22, 22)
		eye.Position = UDim2.fromOffset(13, 9)
		eye.BackgroundTransparency = 1
		eye.Image = hiddeneyeoff
		eye.ImageColor3 = Color3.fromRGB(118, 118, 126)
		eye.ImageTransparency = 0
		eye.ScaleType = Enum.ScaleType.Fit
		eye.Parent = count

		local data = {
			name = name,
			cat = cat,
			window = window,
			edit = edit,
			editicon = editicon,
			done = done,
			count = count,
			number = number,
			hover = false
		}
		headers[name] = data

		ctx:clean(edit.MouseEnter:Connect(function()
			editicon.ImageColor3 = pal.text
		end))
		ctx:clean(edit.MouseLeave:Connect(function()
			editicon.ImageColor3 = light(pal.main, 0.37)
		end))
		ctx:clean(edit.MouseButton1Click:Connect(function()
			setediting(true)
		end))
		ctx:clean(done.MouseEnter:Connect(function()
			done.TextColor3 = pal.text
		end))
		ctx:clean(done.MouseLeave:Connect(function()
			done.TextColor3 = dark(pal.text, 0.16)
		end))
		ctx:clean(done.MouseButton1Click:Connect(function()
			setediting(false)
		end))
		ctx:clean(window.MouseEnter:Connect(function()
			data.hover = true
			updateheaders()
		end))
		ctx:clean(window.MouseLeave:Connect(function()
			data.hover = false
			updateheaders()
		end))
	end

	updateheaders = function()
		for name, data in pairs(headers) do
			local count = hiddenincategory(name)
			data.number.Text = tostring(count)
			data.done.Visible = state.editing
			data.edit.Visible = not state.editing and data.hover
			data.count.Visible = not state.editing and not data.hover and count > 0
		end
	end

	local function addmodule(mod)
		if type(mod) ~= 'table' or decorated[mod] or type(mod.Name) ~= 'string'
			or not isinst(mod.Object) then return end
		local row = mod.Object
		cleanstale(row)
		local pal = getpalette()
		local normal = '            '..mod.Name:gsub(' ', '')
		local edittext = '    '..mod.Name:gsub(' ', '')
		row.Text = normal

		local star = Instance.new('TextButton')
		star.Name = 'Favorite'
		star.Size = UDim2.fromOffset(22, 22)
		star.Position = UDim2.new(1, -61, 0, 8)
		star.AnchorPoint = Vector2.new(1, 0)
		star.BackgroundTransparency = 1
		star.AutoButtonColor = false
		star.Visible = false
		star.Text = '★'
		star.TextSize = 22
		star.FontFace = pal.semibold
		star.TextColor3 = light(pal.main, 0.37)
		star.ZIndex = row.ZIndex + 20
		star.Parent = row

		local guard = Instance.new('TextButton')
		guard.Name = 'VTHideGuard'
		guard.Size = UDim2.fromScale(1, 1)
		guard.BackgroundTransparency = 1
		guard.BorderSizePixel = 0
		guard.AutoButtonColor = false
		guard.Visible = false
		guard.Text = ''
		guard.ZIndex = row.ZIndex + 30
		guard.Parent = row

		local rail = makehiddenrail(row, row.ZIndex + 29)
		local hiddenbox, outline, fill = makehiddenbox(row, row.ZIndex + 31)
		local dots = row:FindFirstChild('Dots')
		local bind = row:FindFirstChild('Bind')
		local children = mod.Children
		local data = {
			mod = mod,
			row = row,
			star = star,
			guard = guard,
			rail = rail,
			hiddenbox = hiddenbox,
			outline = outline,
			fill = fill,
			dots = dots,
			bind = bind,
			children = children,
			originalparent = isinst(children) and children.Parent or nil,
			originalorder = isinst(children) and children.LayoutOrder or 0,
			normal = normal,
			edittext = edittext,
			starhover = false,
			hover = false,
			favoriteopen = false,
			oldfields = {
				Favorited = mod.Favorited,
				FavoriteStar = mod.FavoriteStar,
				HiddenBox = mod.HiddenBox,
				HiddenBoxOutline = mod.HiddenBoxOutline,
				HiddenBoxFill = mod.HiddenBoxFill,
				NormalText = mod.NormalText,
				EditHiddenText = mod.EditHiddenText,
				UpdateHiddenBox = mod.UpdateHiddenBox,
				UpdateFavoriteVisual = mod.UpdateFavoriteVisual,
				ApplyHiddenState = mod.ApplyHiddenState,
				SetChildrenVisible = mod.SetChildrenVisible,
				SetFavoriteChildrenVisible = mod.SetFavoriteChildrenVisible,
				FavoriteRow = mod.FavoriteRow
			}
		}
		decorated[mod] = data

		mod.Favorited = isfavorite(mod.Name)
		mod.FavoriteStar = star
		mod.HiddenBox = hiddenbox
		mod.HiddenBoxOutline = outline
		mod.HiddenBoxFill = fill
		mod.NormalText = normal
		mod.EditHiddenText = edittext
		mod.UpdateHiddenBox = function(self)
			updatehiddenbox(hiddenbox, outline, fill, ishidden(self.Name), self)
		end
		mod.UpdateFavoriteVisual = function(self)
			starvisual(star, isfavorite(self.Name), data.starhover)
		end
		mod.ApplyHiddenState = function(self)
			applymodule(self)
		end
		mod.SetChildrenVisible = function(self, enabled)
			if state.editing or not isinst(children) then return end
			if data.favoriteopen then restorechildren(data, true) end
			children.Parent = data.originalparent
			children.LayoutOrder = data.originalorder
			children.Visible = enabled and true or false
			applymodule(self)
		end
		mod.SetFavoriteChildrenVisible = function(_, enabled, customparent, order)
			setfavoritechildren(data, enabled, order or 1)
		end

		ctx:clean(row.MouseEnter:Connect(function()
			data.hover = true
			applymodule(mod)
		end))
		ctx:clean(row.MouseLeave:Connect(function()
			data.hover = false
			applymodule(mod)
		end))
		ctx:clean(star.MouseButton1Down:Connect(function()
			data.starclick = true
		end))
		ctx:clean(star.MouseEnter:Connect(function()
			data.starhover = true
			starvisual(star, isfavorite(mod.Name), true)
		end))
		ctx:clean(star.MouseLeave:Connect(function()
			data.starhover = false
			starvisual(star, isfavorite(mod.Name), false)
		end))
		ctx:clean(star.MouseButton1Click:Connect(function()
			pulse(star)
			setfavorite(mod.Name, not isfavorite(mod.Name))
			data.starclick = false
		end))
		ctx:clean(hiddenbox.MouseButton1Click:Connect(function()
			sethidden(mod.Name, not ishidden(mod.Name))
		end))
		if isinst(children) then
			ctx:clean(children:GetPropertyChangedSignal('Visible'):Connect(function()
				applymodule(mod)
				if rows[mod.Name] then updatefavoriterow(mod.Name) end
			end))
			ctx:clean(children:GetPropertyChangedSignal('Parent'):Connect(function()
				applymodule(mod)
			end))
		end
		ctx:clean(row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 and data.favoriteopen then
				restorechildren(data, true)
			end
		end))
		if isinst(dots) then
			ctx:clean(dots.InputBegan:Connect(function(input)
				if (input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.MouseButton2) and data.favoriteopen then
					restorechildren(data, true)
				end
			end))
		end
		applymodule(mod)
	end

	applymodule = function(mod)
		local data = decorated[mod]
		if not data or not isinst(data.row) then return end
		local hidden = ishidden(mod.Name)
		local editing = state.editing
		if hidden and not editing then
			if data.favoriteopen then restorechildren(data, true) end
			if isinst(data.children) then data.children.Visible = false end
		end
		data.row.Visible = editing or not hidden
		data.guard.Visible = editing
		data.rail.Visible = editing
		data.hiddenbox.Visible = editing
		data.row.Text = editing and data.edittext or data.normal
		if isinst(data.dots) then data.dots.Visible = not editing end
		local originalopen = isinst(data.children) and data.children.Visible
			and data.children.Parent == data.originalparent and not data.favoriteopen
		if isinst(data.bind) then
			local bound = type(mod.Bind) == 'table' and (#mod.Bind > 0 or mod.Bind.Mobile == true)
			data.bind.Visible = not editing and (bound or data.hover or originalopen)
		end
		data.star.Visible = not editing and originalopen
		updatehiddenbox(data.hiddenbox, data.outline, data.fill, hidden, mod)
		starvisual(data.star, isfavorite(mod.Name), data.starhover)
		mod.Favorited = isfavorite(mod.Name)
	end

	local function updatebindpreview(data)
		if not data or not isinst(data.bind) then return end
		if state.editing then
			data.bind.Visible = false
			return
		end
		local bindvalue = data.mod.Bind or {}
		local hasbind = type(bindvalue) == 'table' and #bindvalue > 0
		data.bind.Visible = data.hover or hasbind or data.moddata and data.moddata.favoriteopen
		if hasbind then
			data.bindtext.Visible = true
			data.bindicon.Visible = false
			data.bindtext.Text = table.concat(bindvalue, ' + '):upper()
			data.bind.Size = UDim2.fromOffset(math.max(textwidth(data.bindtext.Text, data.bindtext.TextSize, data.bindtext.FontFace) + 10, 20), 21)
		else
			data.bindtext.Visible = false
			data.bindicon.Visible = true
			data.bindicon.Image = data.bindasset
			data.bindicon.ImageColor3 = dark(getpalette().text, 0.43)
			data.bind.Size = UDim2.fromOffset(20, 21)
		end
	end

	local function createfavoriterow(mod)
		if rows[mod.Name] or not isinst(favchildren) then return end
		local pal = getpalette()
		local source = decorated[mod]
		if not source then return end
		local row = Instance.new('TextButton')
		row.Name = mod.Name
		row.Size = UDim2.fromOffset(220, 40)
		row.BackgroundColor3 = pal.main
		row.BorderSizePixel = 0
		row.AutoButtonColor = false
		row.Text = '            '..mod.Name:gsub(' ', '')
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = dark(pal.text, 0.16)
		row.TextSize = 14
		row.FontFace = pal.font
		row.Parent = favchildren

		local gradient = Instance.new('UIGradient')
		gradient.Rotation = 90
		gradient.Enabled = false
		gradient.Parent = row

		local rail = makehiddenrail(row, row.ZIndex + 1)
		local hiddenbox, outline, fill = makehiddenbox(row, row.ZIndex + 2)

		local bind = Instance.new('TextButton')
		bind.Name = 'BindPreview'
		bind.Size = UDim2.fromOffset(20, 21)
		bind.Position = UDim2.new(1, -36, 0, 9)
		bind.AnchorPoint = Vector2.new(1, 0)
		bind.BackgroundColor3 = Color3.new(1, 1, 1)
		bind.BackgroundTransparency = 0.92
		bind.BorderSizePixel = 0
		bind.AutoButtonColor = false
		bind.Visible = false
		bind.Text = ''
		bind.Parent = row
		corner(bind, UDim.new(0, 4))

		local sourcebind = source.bind
		local sourceicon = isinst(sourcebind) and sourcebind:FindFirstChild('Icon')
		local bindicon = Instance.new('ImageLabel')
		bindicon.Name = 'Icon'
		bindicon.Size = UDim2.fromOffset(12, 12)
		bindicon.Position = UDim2.new(0.5, -6, 0, 5)
		bindicon.BackgroundTransparency = 1
		bindicon.Image = sourceicon and sourceicon.Image or ''
		bindicon.ImageColor3 = dark(pal.text, 0.43)
		bindicon.Parent = bind

		local bindtext = Instance.new('TextLabel')
		bindtext.Name = 'Text'
		bindtext.Size = UDim2.fromScale(1, 1)
		bindtext.Position = UDim2.fromOffset(0, 1)
		bindtext.BackgroundTransparency = 1
		bindtext.Visible = false
		bindtext.Text = ''
		bindtext.TextColor3 = dark(pal.text, 0.43)
		bindtext.TextSize = 12
		bindtext.FontFace = pal.font
		bindtext.Parent = bind

		local sourcecover = source.row:FindFirstChild('Cover')
		local bindcover = Instance.new('ImageLabel')
		bindcover.Name = 'Cover'
		bindcover.Size = UDim2.fromOffset(154, 40)
		bindcover.BackgroundTransparency = 1
		bindcover.Visible = false
		bindcover.Image = sourcecover and sourcecover.Image or ''
		bindcover.ScaleType = Enum.ScaleType.Slice
		bindcover.SliceCenter = Rect.new(0, 0, 141, 40)
		bindcover.Parent = row

		local bindcovertext = Instance.new('TextLabel')
		bindcovertext.Name = 'Text'
		bindcovertext.Size = UDim2.new(1, -10, 1, -3)
		bindcovertext.BackgroundTransparency = 1
		bindcovertext.Text = 'PRESS A KEY TO BIND'
		bindcovertext.TextColor3 = pal.text
		bindcovertext.TextSize = 11
		bindcovertext.FontFace = pal.font
		bindcovertext.Parent = bindcover

		local dotsbutton = Instance.new('TextButton')
		dotsbutton.Name = 'Dots'
		dotsbutton.Size = UDim2.fromOffset(25, 40)
		dotsbutton.Position = UDim2.new(1, -25, 0, 0)
		dotsbutton.BackgroundTransparency = 1
		dotsbutton.Text = ''
		dotsbutton.Parent = row

		local sourcedots = source.dots and source.dots:FindFirstChild('Dots')
		local dots = Instance.new('ImageLabel')
		dots.Name = 'Dots'
		dots.Size = UDim2.fromOffset(3, 16)
		dots.Position = UDim2.fromOffset(4, 12)
		dots.BackgroundTransparency = 1
		dots.Image = sourcedots and sourcedots.Image or ''
		dots.ImageColor3 = light(pal.main, 0.37)
		dots.Parent = dotsbutton

		local data = {
			mod = mod,
			moddata = source,
			row = row,
			gradient = gradient,
			rail = rail,
			hiddenbox = hiddenbox,
			outline = outline,
			fill = fill,
			bind = bind,
			bindicon = bindicon,
			bindtext = bindtext,
			bindcover = bindcover,
			bindcovertext = bindcovertext,
			bindasset = bindicon.Image,
			dotsbutton = dotsbutton,
			dots = dots,
			hover = false,
			bindguard = false
		}
		rows[mod.Name] = data
		mod.FavoriteRow = row

		ctx:clean(row.MouseEnter:Connect(function()
			data.hover = true
			if not mod.Enabled then
				row.TextColor3 = pal.text
				row.BackgroundColor3 = light(pal.main, 0.02)
			end
			dots.ImageColor3 = pal.text
			updatebindpreview(data)
		end))
		ctx:clean(row.MouseLeave:Connect(function()
			data.hover = false
			updatefavoriterow(mod.Name)
			updatebindpreview(data)
		end))
		ctx:clean(row.MouseButton1Click:Connect(function()
			if state.editing then return end
			if data.bindguard then
				data.bindguard = false
				return
			end
			pcall(mod.Toggle, mod)
			updatefavoriterow(mod.Name)
		end))
		local function togglesettings()
			if state.editing then return end
			setfavoritechildren(source, not source.favoriteopen, row.LayoutOrder + 1)
			updatebindpreview(data)
		end
		ctx:clean(row.MouseButton2Click:Connect(togglesettings))
		ctx:clean(dotsbutton.MouseButton1Click:Connect(togglesettings))
		ctx:clean(dotsbutton.MouseButton2Click:Connect(togglesettings))
		ctx:clean(bind.MouseEnter:Connect(function()
			bindtext.Visible = false
			bindicon.Visible = true
			local edit = source.bind and source.bind:FindFirstChild('Icon')
			bindicon.Image = edit and edit.Image or bindicon.Image
			if editasset ~= '' then bindicon.Image = editasset end
			bindicon.ImageColor3 = dark(pal.text, 0.16)
		end))
		ctx:clean(bind.MouseLeave:Connect(function()
			updatebindpreview(data)
		end))
		ctx:clean(bind.MouseButton1Down:Connect(function()
			data.bindguard = true
		end))
		ctx:clean(bind.MouseButton1Click:Connect(function()
			if state.editing then return end
			bindcovertext.Text = 'PRESS A KEY TO BIND'
			bindcover.Size = UDim2.fromOffset(textwidth(bindcovertext.Text, bindcovertext.TextSize, bindcovertext.FontFace) + 20, 40)
			bindcover.Visible = true
			vape.Binding = {
				Bind = mod.Bind,
				SetBind = function(_, tab, mouse)
					mod:SetBind(tab, mouse)
					updatebindpreview(data)
					bindcovertext.Text = #tab <= 0 and 'BIND REMOVED' or 'BOUND TO'
					bindcover.Size = UDim2.fromOffset(textwidth(bindcovertext.Text, bindcovertext.TextSize, bindcovertext.FontFace) + 20, 40)
					task.delay(1, function()
						if alive and isinst(bindcover) then bindcover.Visible = false end
					end)
				end
			}
		end))
		ctx:clean(hiddenbox.MouseButton1Click:Connect(function()
			sethidden(mod.Name, not ishidden(mod.Name))
		end))
		updatebindpreview(data)
		updatefavoriterow(mod.Name)
	end

	updatefavoriterow = function(name)
		local data = rows[name]
		local mod = vape.Modules[name]
		if not data or type(mod) ~= 'table' or not isinst(data.row) then return end
		local pal = getpalette()
		local hidden = ishidden(name)
		data.row.Visible = state.editing or not hidden
		data.row.Text = state.editing and ('    '..mod.Name:gsub(' ', ''))
			or ('            '..mod.Name:gsub(' ', ''))
		data.rail.Visible = state.editing
		data.hiddenbox.Visible = state.editing
		data.dotsbutton.Visible = not state.editing
		updatehiddenbox(data.hiddenbox, data.outline, data.fill, hidden, mod)
		if state.editing then data.bind.Visible = false end

		local source = decorated[mod]
		local srcrow = source and source.row
		local srcgradient = srcrow and srcrow:FindFirstChildWhichIsA('UIGradient')
		if mod.Enabled and srcrow then
			data.row.TextColor3 = srcrow.TextColor3
			data.row.BackgroundColor3 = srcrow.BackgroundColor3
			if srcgradient then
				data.gradient.Enabled = srcgradient.Enabled
				data.gradient.Color = srcgradient.Color
			end
			local sourcedots = source.dots and source.dots:FindFirstChild('Dots')
			if sourcedots then data.dots.ImageColor3 = sourcedots.ImageColor3 end
			local sourcebind = source.bind
			local sourcebindicon = sourcebind and sourcebind:FindFirstChild('Icon')
			local sourcebindtext = sourcebind and sourcebind:FindFirstChildWhichIsA('TextLabel')
			if sourcebindicon then data.bindicon.ImageColor3 = sourcebindicon.ImageColor3 end
			if sourcebindtext then data.bindtext.TextColor3 = sourcebindtext.TextColor3 end
		else
			data.gradient.Enabled = false
			if not data.hover then
				data.row.TextColor3 = dark(pal.text, 0.16)
				data.row.BackgroundColor3 = pal.main
				data.dots.ImageColor3 = light(pal.main, 0.37)
			end
			data.bindicon.ImageColor3 = dark(pal.text, 0.43)
			data.bindtext.TextColor3 = dark(pal.text, 0.43)
		end
		updatebindpreview(data)
	end

	refreshfavorites = function()
		for name, data in pairs(clone(rows)) do
			if not isfavorite(name) or type(vape.Modules[name]) ~= 'table' then
				if data.moddata and data.moddata.favoriteopen then restorechildren(data.moddata, true) end
				if isinst(data.row) then data.row:Destroy() end
				rows[name] = nil
			end
		end
		local list = tolist(state.favorites)
		for order, name in ipairs(list) do
			local mod = vape.Modules[name]
			if type(mod) == 'table' then
				createfavoriterow(mod)
				local data = rows[name]
				if data then
					data.row.LayoutOrder = order * 2
					if data.moddata.favoriteopen and isinst(data.moddata.children) then
						data.moddata.children.LayoutOrder = order * 2 + 1
					end
					updatefavoriterow(name)
				end
			end
		end
		syncapi()
		if favbutton then
			local open = fav and fav.Button and fav.Button.Enabled
			starvisual(favbutton, open, vape.Favorites and vape.Favorites.StarButtonHovered)
		end
	end

	local function addfavoritesbutton()
		if isinst(favbutton) then return end
		local main = vape.Categories.Main
		local root = main and main.Object
		local children = root and root:FindFirstChild('Children')
		local bar = children and children:FindFirstChild('Overlays')
		if not isinst(bar) then return end
		local old = bar:FindFirstChild('FavoritesButton')
		if old then old:Destroy() end
		local button = Instance.new('ImageButton')
		button.Name = 'FavoritesButton'
		button.Size = UDim2.fromOffset(21, 21)
		button.Position = UDim2.new(1, -52, 0, 8)
		button.BackgroundTransparency = 1
		button.AutoButtonColor = false
		button.Image = favoriteoff
		button.ImageColor3 = light(getpalette().main, 0.37)
		button.Parent = bar
		favbutton = button
		ctx:clean(button.MouseEnter:Connect(function()
			vape.Favorites.StarButtonHovered = true
			starvisual(button, fav and fav.Button and fav.Button.Enabled, true)
		end))
		ctx:clean(button.MouseLeave:Connect(function()
			vape.Favorites.StarButtonHovered = false
			starvisual(button, fav and fav.Button and fav.Button.Enabled, false)
		end))
		ctx:clean(button.MouseButton1Click:Connect(function()
			pulse(button)
			if not fav or not fav.Button then return end
			fav.Button:Toggle()
			if fav.Button.Enabled and not fav.Expanded and type(fav.Expand) == 'function' then
				fav:Expand()
			end
			starvisual(button, fav.Button.Enabled, false)
		end))
		syncapi()
		starvisual(button, fav and fav.Button and fav.Button.Enabled, false)
	end

	local function applyfavoritewindow()
		if not fav or not isinst(fav.Object) or not fav.Button then return end
		local saved = state.favoritewindow or {Enabled = false}
		restoringwindow = true
		local position = saved.Position or saved.position
		local xscale = type(position) == 'table' and tonumber(position.XScale or position.xscale) or 0
		local x = type(position) == 'table'
			and tonumber(position.X or position.XOffset or position.x or position.xoffset)
		local yscale = type(position) == 'table' and tonumber(position.YScale or position.yscale) or 0
		local y = type(position) == 'table'
			and tonumber(position.Y or position.YOffset or position.y or position.yoffset)
		if x and y then fav.Object.Position = UDim2.new(xscale or 0, x, yscale or 0, y) end
		local expanded = saved.Expanded == true or saved.expanded == true
		if type(fav.Expand) == 'function' and fav.Expanded ~= expanded then fav:Expand() end
		local enabled = saved.Enabled == true or saved.enabled == true
		if fav.Button.Enabled ~= enabled then fav.Button:Toggle() end
		restoringwindow = false
		favoritewindow()
		if favbutton then starvisual(favbutton, fav.Button.Enabled, false) end
	end

	local function createfavorites()
		fav = vape.Categories.Favorites
		if type(fav) ~= 'table' or not isinst(fav.Object) then
			fav = vape:CreateCategory({
				Name = 'Favorites',
				Icon = '',
				Size = UDim2.fromOffset(25, 25)
			})
		end
		if type(fav) ~= 'table' or not isinst(fav.Object) then return false end
		fav.__VapeTweakerFavorites = true
		favchildren = fav.Children or fav.Object:FindFirstChild('Children')
		if not isinst(favchildren) then return false end
		fav.Children = favchildren
		for _, child in ipairs(favchildren:GetChildren()) do
			if child:IsA('GuiObject') then child:Destroy() end
		end
		local icon = fav.Object:FindFirstChild('Icon')
		if icon then
			icon.Size = UDim2.fromOffset(25, 25)
			icon.Position = UDim2.fromOffset(12, 8)
			icon.ImageTransparency = 0
			icon.Image = favoriteofftab
			icon.ImageColor3 = Color3.new(1, 1, 1)
		end
		local oldbutton = fav.Button
		if oldbutton and isinst(oldbutton.Object) then oldbutton.Object:Destroy() end
		local main = vape.Categories.Main
		if main and type(main.Buttons) == 'table' then main.Buttons.Favorites = nil end
		fav.Button = {
			Enabled = false,
			Toggle = function(buttonapi)
				buttonapi.Enabled = not buttonapi.Enabled
				fav.Object.Visible = buttonapi.Enabled
				if not buttonapi.Enabled then
					closefavoritechildren()
					local divider = fav.Object:FindFirstChild('Divider')
					if divider then divider.Visible = false end
				end
				if favbutton then starvisual(favbutton, buttonapi.Enabled, false) end
				if not restoringwindow then
					favoritewindow()
					queuesave()
				end
			end
		}
		fav.Object.Visible = false
		ctx:clean(fav.Object:GetPropertyChangedSignal('Position'):Connect(function()
			if restoringwindow then return end
			favoritewindow()
			queuesave()
		end))
		return true
	end

	for _, name in ipairs({
		'Favorites', 'Hidden', 'IsFavorite', 'GetFavoriteStarAsset', 'GetFavoriteActiveColor',
		'AnimateStarColor', 'PulseStar', 'PulseImage', 'UpdateFavoritesButton',
		'UpdateFavoriteRow', 'CreateFavoriteRow', 'RefreshFavorites', 'SetFavorite',
		'IsHidden', 'GetHiddenAccentColor', 'GetHiddenCategoryCount', 'UpdateHiddenHeaders',
		'UpdateHiddenModule', 'RefreshHiddenModules', 'SetHiddenEditing', 'SetHidden'
	}) do
		apiold[name] = vape[name]
	end

	load()
	if createfavorites() == false then return end
	addheader('Favorites', fav)
	addfavoritesbutton()
	applyfavoritewindow()

	vape.Favorites = {List = {}, Rows = rows, StarButton = favbutton}
	vape.Hidden = {List = {}, Editing = false}
	vape.IsFavorite = function(_, name) return isfavorite(name) end
	vape.GetFavoriteStarAsset = function(_, enabled) return enabled and favoriteon or favoriteoff end
	vape.GetFavoriteActiveColor = function() return activecolor() end
	vape.AnimateStarColor = function(_, star, enabled, hover) starvisual(star, enabled, hover) end
	vape.PulseStar = function(_, star) pulse(star) end
	vape.PulseImage = function(_, image) pulse(image) end
	vape.UpdateFavoritesButton = function()
		if favbutton then starvisual(favbutton, fav and fav.Button and fav.Button.Enabled, vape.Favorites.StarButtonHovered) end
	end
	vape.UpdateFavoriteRow = function(_, name) updatefavoriterow(name) end
	vape.CreateFavoriteRow = function(_, mod) createfavoriterow(mod) end
	vape.RefreshFavorites = function() refreshfavorites() end
	vape.SetFavorite = function(_, name, enabled, skipsave) setfavorite(name, enabled, skipsave) end
	vape.IsHidden = function(_, name) return ishidden(name) end
	vape.GetHiddenAccentColor = function(_, mod) return accent(mod) end
	vape.GetHiddenCategoryCount = function(_, category) return hiddenincategory(category) end
	vape.UpdateHiddenHeaders = function() updateheaders() end
	vape.UpdateHiddenModule = function(_, name)
		local mod = vape.Modules[name]
		if mod then applymodule(mod) end
		if rows[name] then updatefavoriterow(name) end
	end
	vape.RefreshHiddenModules = function()
		for _, data in pairs(decorated) do applymodule(data.mod) end
		refreshfavorites()
		updateheaders()
	end
	vape.SetHiddenEditing = function(_, enabled) setediting(enabled) end
	vape.SetHidden = function(_, name, enabled, skipsave) sethidden(name, enabled, skipsave) end
	syncapi()

	local function scan()
		for name, cat in pairs(vape.Categories) do
			if name ~= 'Main' then addheader(name, cat) end
		end
		for _, mod in pairs(vape.Modules) do addmodule(mod) end
		for mod, data in pairs(clone(decorated)) do
			if vape.Modules[mod.Name] ~= mod or not isinst(data.row) then
				if data.favoriteopen then restorechildren(data, true) end
				decorated[mod] = nil
			end
		end
		for name in pairs(clone(state.favorites)) do
			if type(vape.Modules[name]) ~= 'table' then state.favorites[name] = nil end
		end
		for name in pairs(clone(state.hidden)) do
			if type(vape.Modules[name]) ~= 'table' then state.hidden[name] = nil end
		end
		addfavoritesbutton()
		refreshfavorites()
		updateheaders()
	end

	scan()
	local lp = players.LocalPlayer
	if lp and lp.OnTeleport then
		ctx:clean(lp.OnTeleport:Connect(function(teleportstate)
			if teleportstate == Enum.TeleportState.Started
				or teleportstate == Enum.TeleportState.InProgress then
				save(profile)
			end
		end))
	end
	local scanclock = 0
	local syncclock = 0
	ctx:clean(runservice.Heartbeat:Connect(function(dt)
		scanclock = scanclock + dt
		syncclock = syncclock + dt
		local current = ctx.profile and ctx.profile.dir or 'default'
		if current ~= profile then
			save(profile)
			closefavoritechildren()
			load()
			scan()
			applyfavoritewindow()
		end
		if scanclock >= 0.5 then
			scanclock = 0
			scan()
		end
		if syncclock >= 0.1 then
			syncclock = 0
			for _, data in pairs(decorated) do applymodule(data.mod) end
			for name in pairs(rows) do updatefavoriterow(name) end
		end
	end))

	ctx:clean(function()
		if not alive then return end
		save(profile)
		alive = false
		closefavoritechildren()
		for mod, data in pairs(decorated) do
			if isinst(data.row) then
				data.row.Visible = true
				data.row.Text = data.normal
			end
			for _, obj in ipairs({data.star, data.guard, data.rail, data.hiddenbox}) do
				if isinst(obj) then obj:Destroy() end
			end
			if isinst(data.dots) then data.dots.Visible = true end
			for name, value in pairs(data.oldfields or {}) do
				mod[name] = value
			end
		end
		for _, data in pairs(rows) do
			if isinst(data.row) then data.row:Destroy() end
		end
		for _, data in pairs(headers) do
			for _, obj in ipairs({data.edit, data.done, data.count}) do
				if isinst(obj) then obj:Destroy() end
			end
		end
		if isinst(favbutton) then favbutton:Destroy() end
		if fav and fav.__VapeTweakerFavorites then
			if fav.Button and fav.Button.Enabled then fav.Button:Toggle() end
			if isinst(fav.Object) then fav.Object:Destroy() end
			if vape.Categories.Favorites == fav then vape.Categories.Favorites = nil end
		end
		for name, value in pairs(apiold) do
			vape[name] = value
		end
	end)
end
