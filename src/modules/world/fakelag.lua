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
	local q = {}
	local head = 1
	local tail = 0
	local goal = 0
	local cur = 0
	local base = 0
	local last = 0
	local stats = game:GetService('Stats')

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

	local function bounds()
		local low = tonumber(ping and (ping.ValueMin or ping.MinValue or ping.LowValue)) or 200
		local high = tonumber(ping and (ping.ValueMax or ping.MaxValue or ping.HighValue)) or 300
		if high < low then low, high = high, low end
		return math.clamp(low, 0, 500), math.clamp(high, 0, 500)
	end

	local function pick()
		local low, high = bounds()
		if high <= low then return low end
		return rng:NextNumber(low, high)
	end

	local function stat()
		local ok, val = pcall(function()
			return stats.Network.ServerStatsItem['Data Ping']:GetValue()
		end)
		val = ok and tonumber(val) or nil
		return val and math.max(val, 0) or 0
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

	local function send(data)
		if not data or not ready() then return end
		busy = true
		pcall(raknet.send, data[1], data[2], data[3], data[4])
		busy = false
	end

	local function flush()
		for i = head, tail do
			if q[i] then send(q[i][2]) end
		end
		table.clear(q)
		head = 1
		tail = 0
		last = 0
	end

	local function stop()
		seq += 1
		if hook and ready() then pcall(raknet.remove_send_hook, hook) end
		hook = nil
		flush()
		busy = false
		if old ~= nil then set(old) end
		old = nil
		net = nil
	end

	local function flow(curid, normal)
		goal = pick()
		cur = goal
		local nxt = os.clock() + rng:NextNumber(0.65, 1.25)
		task.spawn(function()
			while mod.Enabled and curid == seq and (normal and meth.Value == 'Normal' or not normal and meth.Value == 'Raknet') do
				local low, high = bounds()
				local now = os.clock()
				if now >= nxt then
					goal = rng:NextNumber(low, high)
					nxt = now + rng:NextNumber(0.65, 1.25)
				end
				goal = math.clamp(goal, low, high)
				cur = math.clamp(cur + (goal - cur) * 0.18, low, high)
				if normal then set(cur / 1000) end
				task.wait(0.05)
			end
		end)
	end

	local function normal()
		net = get()
		if not net then return false end
		local ok, val = pcall(function() return net.IncomingReplicationLag end)
		old = ok and val or 0
		seq += 1
		local id = seq
		flow(id, true)
		return set(cur / 1000)
	end

	local function rakhook()
		if not ready() then return false end
		seq += 1
		local id = seq
		base = stat()
		flow(id, false)
		hook = function(pkt)
			if busy or not mod.Enabled or meth.Value ~= 'Raknet' or id ~= seq then return end
			local data = read(pkt)
			if not data then return end
			local ok = pcall(function() pkt:Block() end)
			if not ok then return end
			local extra = math.max(cur - base, 0) / 1000
			local now = os.clock()
			local at = math.max(now + extra, last + 0.0001)
			last = at
			tail += 1
			q[tail] = {at, data}
		end
		local ok = pcall(raknet.add_send_hook, hook)
		if not ok then
			hook = nil
			table.clear(q)
			head = 1
			tail = 0
			return false
		end
		task.spawn(function()
			while mod.Enabled and meth.Value == 'Raknet' and id == seq do
				local now = os.clock()
				while head <= tail and q[head] and q[head][1] <= now do
					send(q[head][2])
					q[head] = nil
					head += 1
				end
				if head > tail then
					table.clear(q)
					head = 1
					tail = 0
				end
				task.wait()
			end
		end)
		return true
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
		Max = 500,
		DefaultMin = 200,
		DefaultMax = 300
	})

	ctx:clean(stop)
end
