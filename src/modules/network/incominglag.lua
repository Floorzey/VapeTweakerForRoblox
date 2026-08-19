return function(ctx)
	local mod
	local delay
	local old
	local net

	local function get()
		if type(settings) ~= 'function' then return nil end
		local ok, val = pcall(settings)
		if not ok or type(val) ~= 'userdata' and type(val) ~= 'table' then return nil end
		local ok2, out = pcall(function() return val.Network end)
		return ok2 and out or nil
	end

	local function set(val)
		net = net or get()
		if not net then return false end
		return pcall(function() net.IncomingReplicationLag = val end)
	end

	mod = ctx:module('network', {
		name = 'IncomingLag',
		tooltip = 'Adds local incoming replication delay.',
		func = function(on)
			if on then
				net = get()
				if not net then return end
				local ok, val = pcall(function() return net.IncomingReplicationLag end)
				old = ok and val or 0
				set((delay and delay.Value or 250) / 1000)
			else
				if old ~= nil then set(old) end
				old = nil
				net = nil
			end
		end
	})

	delay = mod:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 3000,
		Default = 250,
		Suffix = 'ms',
		Function = function(val)
			if mod.Enabled then set(val / 1000) end
		end
	})
end
