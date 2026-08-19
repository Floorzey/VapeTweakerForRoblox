return function(ctx)
	local mod
	local meth
	local ping
	local old
	local net
	local hook
	local busy = false
	local seq = 0
	local rng = Random.new()

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

	local function ready()
		return type(raknet) == 'table'
			and type(raknet.add_send_hook) == 'function'
			and type(raknet.remove_send_hook) == 'function'
			and type(raknet.send) == 'function'
	end

	local function check()
		if not ready() then return false end
		local fn = function() end
		local ok = pcall(raknet.add_send_hook, fn)
		if ok then pcall(raknet.remove_send_hook, fn) end
		return ok
	end

	local function warn()
		local vape = ctx.vapeapi and ctx.vapeapi.object
		if type(vape) == 'table' and type(vape.CreateNotification) == 'function' then
			pcall(vape.CreateNotification, vape, 'FakeLag', 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		end
	end

	local function pick()
		if ping and type(ping.GetRandomValue) == 'function' then
			local ok, val = pcall(ping.GetRandomValue, ping)
			if ok and tonumber(val) then return math.max(tonumber(val), 0) end
		end
		local low = tonumber(ping and ping.ValueMin) or 200
		local high = tonumber(ping and ping.ValueMax) or 300
		if high < low then low, high = high, low end
		return rng:NextNumber(low, high)
	end

	local function read(pkt)
		local data
		for _, key in ipairs({'AsBuffer', 'AsString', 'AsArray'}) do
			local ok, val = pcall(function() return pkt[key] end)
			local kind = ok and typeof(val) or nil
			if ok and (kind == 'buffer' or type(val) == 'string' or type(val) == 'table') then
				data = val
				break
			end
		end
		if data == nil then return nil end
		local ok, pri, rel, chan = pcall(function()
			return pkt.Priority, pkt.Reliability, pkt.OrderingChannel
		end)
		if not ok then return nil end
		return {data, pri, rel, chan}
	end

	local function stop()
		seq += 1
		if hook and ready() then pcall(raknet.remove_send_hook, hook) end
		hook = nil
		busy = false
		if old ~= nil then set(old) end
		old = nil
		net = nil
	end

	local function normal()
		net = get()
		if not net then return false end
		local ok, val = pcall(function() return net.IncomingReplicationLag end)
		old = ok and val or 0
		seq += 1
		local cur = seq
		if not set(pick() / 1000) then return false end
		task.spawn(function()
			while mod.Enabled and meth.Value == 'Normal' and cur == seq do
				set(pick() / 1000)
				task.wait(0.1)
			end
		end)
		return true
	end

	local function rakhook()
		if not ready() then return false end
		seq += 1
		local cur = seq
		hook = function(pkt)
			if busy or not mod.Enabled or meth.Value ~= 'Raknet' or cur ~= seq then return end
			local data = read(pkt)
			if not data then return end
			local ok = pcall(function() pkt:Block() end)
			if not ok then return end
			local wait = pick() / 1000
			task.delay(math.max(wait, 0), function()
				if not mod.Enabled or meth.Value ~= 'Raknet' or cur ~= seq or not ready() then return end
				busy = true
				pcall(raknet.send, data[1], data[2], data[3], data[4])
				busy = false
			end)
		end
		local ok = pcall(raknet.add_send_hook, hook)
		if not ok then hook = nil end
		return ok
	end

	local function start()
		if meth.Value == 'Raknet' then return rakhook() end
		return normal()
	end

	local function fail()
		warn()
		task.defer(function()
			if mod.Enabled then mod:Toggle() end
		end)
	end

	mod = ctx:module('world', {
		name = 'FakeLag',
		tooltip = 'Simulates fluctuating network delay using local replication or Raknet packets.',
		extratext = function()
			return meth and meth.Value or 'Normal'
		end,
		func = function(on)
			if on then
				if meth.Value == 'Raknet' and not check() then
					fail()
					return
				end
				if not start() then fail() end
			else
				stop()
			end
		end
	})

	meth = mod:CreateDropdown({
		Name = 'Method',
		List = {'Normal', 'Raknet'},
		Default = 'Normal',
		Function = function(val)
			if val == 'Raknet' and not check() then
				warn()
				if mod.Enabled then task.defer(function() if mod.Enabled then mod:Toggle() end end) end
				return
			end
			if not mod.Enabled then return end
			stop()
			if not start() then fail() end
		end
	})

	ping = mod:CreateTwoSlider({
		Name = 'Ping',
		Min = 0,
		Max = 3000,
		DefaultMin = 200,
		DefaultMax = 300
	})

	ctx:clean(stop)
end
