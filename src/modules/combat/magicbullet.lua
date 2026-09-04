return function(ctx)
	local mod
	local mode
	local autostart
	local silent
	local owned = false
	local last
	local stamp = 0
	local state = {
		enabled = false,
		mode = 'Near Target'
	}

	local function find()
		return ctx:find('SilentAim', 'combat') or ctx:find('SilentAim')
	end

	local function notify(msg)
		msg = tostring(msg or 'MagicBullet is unavailable.')
		local now = os.clock()
		if msg == last and now - stamp < 30 then return end
		last = msg
		stamp = now
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'MagicBullet', msg, 6, 'warning')
		end
	end

	local function sync()
		state.mode = mode and mode.Value or 'Near Target'
		state.enabled = mod and mod.Enabled == true or false
	end

	local function start()
		sync()
		silent = find()
		if type(silent) ~= 'table' then
			state.enabled = false
			notify('Vape SilentAim is unavailable.')
			return
		end
		if type(ctx.silentaimfix) ~= 'table' or ctx.silentaimfix.ready ~= true then
			state.enabled = false
			notify('SilentAim fix is unavailable.')
			return
		end
		owned = false
		if autostart and autostart.Enabled and silent.Enabled ~= true and type(silent.Toggle) == 'function' then
			local ok = pcall(silent.Toggle, silent)
			owned = ok and silent.Enabled == true
			if not owned then
				state.enabled = false
				notify('SilentAim could not be enabled.')
			end
		end
	end

	local function stop()
		state.enabled = false
		if owned and type(silent) == 'table' and silent.Enabled == true and type(silent.Toggle) == 'function' then
			pcall(silent.Toggle, silent)
		end
		owned = false
		silent = nil
	end

	mod = ctx:module('combat', {
		name = 'MagicBullet',
		autostart = false,
		tooltip = 'Extends Vape SilentAim by moving the final weapon-cast origin without replacing Vape hooks.',
		extratext = function()
			return mode and mode.Value or 'Near Target'
		end,
		func = function(on)
			if on then start() else stop() end
		end
	})

	if not mod then return end

	mode = mod:CreateDropdown({
		Name = 'Mode',
		List = {'Near Target', 'Origin Scan'},
		Default = 'Near Target',
		Function = function()
			sync()
		end
	})

	autostart = mod:CreateToggle({
		Name = 'Auto enable SilentAim',
		Default = true
	})

	state.module = mod
	ctx.magicbullet = state

	ctx:clean(function()
		stop()
		if ctx.magicbullet == state then ctx.magicbullet = nil end
	end)
end
