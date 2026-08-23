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
	local native = mod.Options.Method
	local ray = mod.Options['Raycast Type']
	local fix = mod.Options.RayCamFix or ctx.raycamfix
	local use = mod.Options['Use Hitboxes'] or ctx.usehitboxes
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
	local uv = use and use.Object and use.Object.Visible
	local nv = native and native.Object and native.Object.Visible
	local rv = ray and ray.Object and ray.Object.Visible
	if fun.Object then fun.Object.Visible = false end
	if oth.Object then oth.Object.Visible = false end
	if native and native.Object then native.Object.Visible = false end
	if ray and ray.Object then ray.Object.Visible = false end
	if native and native.Value ~= 'Raycast' and type(native.SetValue) == 'function' then pcall(native.SetValue, native, 'Raycast') end
	if fix and fix.Object then fix.Object.Visible = false end
	if use and use.Object then use.Object.Visible = false end
	ctx:clean(function()
		if fun.Object then fun.Object.Visible = fv end
		if oth.Object then oth.Object.Visible = ov end
		if native and native.Object then native.Object.Visible = nv end
		if ray and ray.Object then ray.Object.Visible = rv end
		if use and use.Object then use.Object.Visible = uv end
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
	local hook
	local meth
	local apply
	local methods = ctx.aim and ctx.aim.ars and {'Arsenal', 'Universal'} or {'Universal'}
	meth = pane:CreateDropdown({
		Name = 'Method',
		List = methods,
		Function = function(val)
			if lock then return end
			if val == 'Arsenal' and hook and hook.Value ~= 'Function hook' and type(apply) == 'function' then
				lock = true
				apply('Function hook')
				if hook.Value ~= 'Function hook' then hook:SetValue('Function hook') end
				lock = false
			end
			if mod.Enabled then
				lock = true
				mod:Toggle()
				mod:Toggle()
				lock = false
			end
		end
	})
	ctx.smethod = meth
	if ctx.aim and ctx.aim.ars then
		task.defer(function()
			if meth and meth.Value ~= 'Arsenal' and type(meth.SetValue) == 'function' then meth:SetValue('Arsenal') end
			if hook and hook.Value ~= 'Function hook' and type(hook.SetValue) == 'function' then hook:SetValue('Function hook') end
		end)
	end
	local function mode()
		if oth.Enabled then return 'Oth hook' end
		if fun.Enabled then return 'Function hook' end
		return 'Hookmetamethod'
	end
	local function set(opt, val)
		if opt.Enabled ~= val then opt:Toggle() end
		return opt.Enabled == val
	end
	apply = function(val)
		local fe = val == 'Function hook'
		local oe = val == 'Oth hook'
		if fun.Enabled == fe and oth.Enabled == oe then return true end
		local on = mod.Enabled == true
		local pf = fun.Enabled == true
		local po = oth.Enabled == true
		local ok, msg = pcall(function()
			if on then mod:Toggle() end
			if not set(fun, fe) or not set(oth, oe) then error('hook option state did not apply', 0) end
			if on then mod:Toggle() end
			if mod.Enabled ~= on or mode() ~= val then error('SilentAim hook did not rebuild', 0) end
		end)
		if not ok then
			pcall(function()
				if mod.Enabled then mod:Toggle() end
				set(fun, pf)
				set(oth, po)
				if on and not mod.Enabled then mod:Toggle() end
			end)
			ctx.log:add('patch', 'SilentAimSettings', msg)
		end
		return ok
	end
	hook = pane:CreateDropdown({
		Name = 'Hook',
		List = {'Hookmetamethod', 'Oth hook', 'Function hook'},
		Function = function(val)
			if lock then return end
			lock = true
			apply(val)
			lock = false
		end
	})
	local now = mode()
	if hook.Value ~= now then
		lock = true
		hook:SetValue(now)
		lock = false
	end
	local ft = fun.Toggle
	local ot = oth.Toggle
	local function sync()
		if lock or not hook then return end
		local val = mode()
		if hook.Value ~= val then
			lock = true
			hook:SetValue(val)
			lock = false
		end
	end
	local fw = function(obj, ...)
		local out = table.pack(ft(obj, ...))
		sync()
		return table.unpack(out, 1, out.n)
	end
	local ow = function(obj, ...)
		local out = table.pack(ot(obj, ...))
		sync()
		return table.unpack(out, 1, out.n)
	end
	fun.Toggle = fw
	oth.Toggle = ow
	ctx:clean(function()
		if fun.Toggle == fw then fun.Toggle = ft end
		if oth.Toggle == ow then oth.Toggle = ot end
	end)
	if type(fix) == 'table' and type(fix.Toggle) == 'function' then
		local ray
		local sync2 = false
		local old = fix.Toggle
		local wrap
		wrap = function(obj, ...)
			local out = table.pack(old(obj, ...))
			if ray and ray.Enabled ~= fix.Enabled then
				sync2 = true
				ray:Toggle()
				sync2 = false
			end
			return table.unpack(out, 1, out.n)
		end
		fix.Toggle = wrap
		ray = pane:CreateToggle({
			Name = 'RayCamFix',
			Default = fix.Enabled == true,
			Function = function(val)
				if sync2 then return end
				if fix.Enabled ~= val then fix:Toggle() end
			end
		})
		ctx:clean(function()
			if fix.Toggle == wrap then fix.Toggle = old end
		end)
	end
	if type(use) == 'table' and type(use.Toggle) == 'function' then
		local hit
		local sync3 = false
		local old = use.Toggle
		local wrap
		wrap = function(obj, ...)
			local out = table.pack(old(obj, ...))
			if hit and hit.Enabled ~= use.Enabled then
				sync3 = true
				hit:Toggle()
				sync3 = false
			end
			return table.unpack(out, 1, out.n)
		end
		use.Toggle = wrap
		hit = pane:CreateToggle({
			Name = 'Use Hitboxes',
			Default = use.Enabled == true,
			Function = function(val)
				if sync3 then return end
				if use.Enabled ~= val then use:Toggle() end
			end
		})
		ctx:clean(function()
			if use.Toggle == wrap then use.Toggle = old end
		end)
	end
	ctx:clean(function()
		if ctx.smethod == meth then ctx.smethod = nil end
		for obj, val in pairs(map) do
			if obj.Parent then obj.LayoutOrder = val end
		end
		if main.Buttons and main.Buttons['Silent Aim'] == btn then main.Buttons['Silent Aim'] = nil end
		if vape.Settings['Silent Aim'] == pane then vape.Settings['Silent Aim'] = nil end
		if btn and type(btn.Destroy) == 'function' then pcall(btn.Destroy, btn) end
		if pane and pane.Object then pcall(pane.Object.Destroy, pane.Object) end
	end)
end
