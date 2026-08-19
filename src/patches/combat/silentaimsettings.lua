return function(ctx)
	if ctx.vapeapi.flavor ~= 'new' then return end
	local vape = ctx.vape
	local mod = ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
	if type(mod) ~= 'table' or type(mod.Options) ~= 'table' then
		ctx.log:add('patch', 'SilentAimSettings', 'SilentAim is unavailable')
		return
	end
	local fun = mod.Options['Function hook']
	local oth = mod.Options['Oth hook']
	local fix = mod.Options.RayCamFix or ctx.raycamfix
	if type(fun) ~= 'table' or type(oth) ~= 'table' then
		ctx.log:add('patch', 'SilentAimSettings', 'SilentAim hook options are unavailable')
		return
	end
	local main = vape.Categories and vape.Categories.Main and vape.Categories.Main.Settings
	if type(main) ~= 'table' or type(main.CreateSettingsPane) ~= 'function' then
		ctx.log:add('patch', 'SilentAimSettings', 'Vape settings pane is unavailable')
		return
	end
	if type(vape.Settings) ~= 'table' then return end
	local fv = fun.Object and fun.Object.Visible
	local ov = oth.Object and oth.Object.Visible
	if fun.Object then fun.Object.Visible = false end
	if oth.Object then oth.Object.Visible = false end
	if fix and fix.Object then fix.Object.Visible = false end
	ctx:clean(function()
		if fun.Object then fun.Object.Visible = fv end
		if oth.Object then oth.Object.Visible = ov end
	end)
	local pane = main:CreateSettingsPane({Name = 'Silent Aim'})
	local btn = main.Buttons and main.Buttons['Silent Aim']
	local map = {}
	for i, name in ipairs({'General', 'Modules', 'Silent Aim', 'GUI', 'Notifications'}) do
		local item = main.Buttons and main.Buttons[name]
		if item and item.Object then
			map[item.Object] = item.Object.LayoutOrder
			item.Object.LayoutOrder = -60 + (i * 10)
		end
	end
	local lock = false
	local function mode()
		if oth.Enabled then return 'Oth hook' end
		if fun.Enabled then return 'Function hook' end
		return 'Hookmetamethod'
	end
	local hook = pane:CreateDropdown({
		Name = 'Hook',
		List = {'Hookmetamethod', 'Oth hook', 'Function hook'},
		Function = function(val)
			if lock then return end
			local fe = val == 'Function hook'
			local oe = val == 'Oth hook'
			if fun.Enabled == fe and oth.Enabled == oe then return end
			lock = true
			local ok, msg = pcall(function()
				local on = mod.Enabled
				if on then
					mod:Toggle()
					task.wait()
				end
				if fun.Enabled ~= fe and type(fun.Toggle) == 'function' then fun:Toggle() end
				if oth.Enabled ~= oe and type(oth.Toggle) == 'function' then oth:Toggle() end
				if on then mod:Toggle() end
			end)
			lock = false
			if not ok then ctx.log:add('patch', 'SilentAimSettings', msg) end
		end
	})
	local now = mode()
	if hook.Value ~= now then hook:SetValue(now) end
	if type(fix) == 'table' and type(fix.Toggle) == 'function' then
		local ray
		local sync = false
		local old = fix.Toggle
		local wrap
		wrap = function(obj, ...)
			local out = table.pack(old(obj, ...))
			if ray and ray.Enabled ~= fix.Enabled then
				sync = true
				ray:Toggle()
				sync = false
			end
			return table.unpack(out, 1, out.n)
		end
		fix.Toggle = wrap
		ray = pane:CreateToggle({
			Name = 'RayCamFix',
			Default = fix.Enabled == true,
			Function = function(val)
				if sync then return end
				if fix.Enabled ~= val then fix:Toggle() end
			end
		})
		ctx:clean(function()
			if fix.Toggle == wrap then fix.Toggle = old end
		end)
	end
	ctx:clean(function()
		for obj, val in pairs(map) do
			if obj.Parent then obj.LayoutOrder = val end
		end
		if main.Buttons and main.Buttons['Silent Aim'] == btn then main.Buttons['Silent Aim'] = nil end
		if vape.Settings['Silent Aim'] == pane then vape.Settings['Silent Aim'] = nil end
		if btn and type(btn.Destroy) == 'function' then pcall(btn.Destroy, btn) end
		if pane and pane.Object then pcall(pane.Object.Destroy, pane.Object) end
	end)
end
