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
	local bad = {}
	local goal = 0
	local cur = 0
	local base = 0
	local extra = 0
	local last = 0
	local next = 0
	local stats = game:GetService('Stats')

	local function get()
		if type(settings) ~= 'function' then return nil end
		local ok, val = pcall(settings)
		if not ok then return nil end
		local kind = type(val)
		if kind ~= 'userdata' and kind ~= 'table' then return nil end
		local ok2, out = pcall(function() return val.Network end)
		return ok2 and out or nil
	end

	local function set(val)
		net = net or get()
		if not net then return false end
		return pcall(function() net.IncomingReplicationLag = val end)
	end

	local function api()
		return type(raknet) == 'table'
			and type(raknet.add_send_hook) == 'function'
			and type(raknet.remove_send_hook) == 'function'
			and type(raknet.send) == 'function'
			and type(raknet.is_enabled) == 'function'
	end

	local function ready()
		if not api() then return false end
		local ok, val = pcall(raknet.is_enabled)
		return ok and val == true
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
		return val and math.max(val, 0) or nil
	end

	local function copy(val)
		local kind = typeof(val)
		if type(val) == 'string' then return val end
		if kind == 'buffer' then
			if type(buffer) ~= 'table' or type(buffer.len) ~= 'function' or type(buffer.create) ~= 'function' or type(buffer.copy) ~= 'function' then return val end
			local ok, out = pcall(function()
				local n = buffer.len(val)
				local b = buffer.create(n)
				buffer.copy(b, 0, val, 0, n)
				return b
			end)
			return ok and out or val
		end
		if type(val) == 'table' then
			local out = table.create(#val)
			for i, v in ipairs(val) do out[i] = v end
			return out
		end
	end

	local function read(pkt)
		local data
		local ok, val = pcall(function() return pkt.AsString end)
		if ok and type(val) == 'string' and #val > 0 then data = val end
		if data == nil then
			ok, val = pcall(function() return pkt.AsBuffer end)
			if ok and typeof(val) == 'buffer' then data = copy(val) end
		end
		if data == nil then
			ok, val = pcall(function() return pkt.AsArray end)
			if ok and type(val) == 'table' and #val > 0 then data = copy(val) end
		end
		if data == nil then return nil end
		local meta, id, pri, rel, chan, size = pcall(function()
			return pkt.PacketId, pkt.Priority, pkt.Reliability, pkt.OrderingChannel, pkt.Size
		end)
		if not meta then return nil end
		if type(pri) ~= 'number' or pri < 0 or pri > 3 then return nil end
		if type(rel) ~= 'number' or rel < 0 or rel > 7 then return nil end
		if type(chan) ~= 'number' or chan < 0 or chan > 31 then return nil end
		return {d = data, i = id, p = pri, r = rel, c = chan, s = size}
	end

	local function send(pkt)
		if not pkt or not ready() then return false end
		busy = true
		local ok = pcall(raknet.send, pkt.d, pkt.p, pkt.r, pkt.c)
		busy = false
		if not ok and pkt.i ~= nil then bad[pkt.i] = true end
		return ok
	end

	local function push(pkt)
		tail += 1
		q[tail] = pkt
	end

	local function pop()
		if head > tail then return nil end
		local pkt = q[head]
		q[head] = nil
		head += 1
		if head > tail then
			table.clear(q)
			head = 1
			tail = 0
			last = 0
		end
		return pkt
	end

	local function count()
		return tail >= head and tail - head + 1 or 0
	end

	local function flush()
		while head <= tail do
			local pkt = pop()
			if pkt then send(pkt) end
		end
		table.clear(q)
		head = 1
		tail = 0
		last = 0
	end

	local function unhook()
		if hook and api() then pcall(raknet.remove_send_hook, hook) end
		hook = nil
	end

	local function stop()
		seq += 1
		unhook()
		flush()
		busy = false
		table.clear(bad)
		if old ~= nil then set(old) end
		old = nil
		net = nil
		last = 0
	end

	local function flow(id, normal)
		local low, high = bounds()
		goal = math.clamp(cur > 0 and cur or pick(), low, high)
		cur = goal
		next = os.clock() + rng:NextNumber(0.8, 1.4)
		local mark = os.clock()
		task.spawn(function()
			while mod.Enabled and id == seq and (normal and meth.Value == 'Normal' or not normal and meth.Value == 'Raknet') do
				local now = os.clock()
				local dt = math.min(now - mark, 0.1)
				mark = now
				low, high = bounds()
				if now >= next then
					goal = high > low and rng:NextNumber(low, high) or low
					next = now + rng:NextNumber(0.8, 1.4)
				end
				goal = math.clamp(goal, low, high)
				local rate = math.min(dt * 3.5, 1)
				cur = math.clamp(cur + (goal - cur) * rate, low, high)
				if normal then
					set(cur / 1000)
				else
					extra = math.max(cur - base, 0)
				end
				task.wait(0.03)
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
		cur = pick()
		flow(id, true)
		return set(cur / 1000)
	end

	local function rak()
		if not ready() then return false end
		seq += 1
		local id = seq
		base = stat() or 0
		cur = pick()
		extra = math.max(cur - base, 0)
		flow(id, false)
		hook = function(pkt)
			if busy or not mod.Enabled or meth.Value ~= 'Raknet' or id ~= seq then return end
			local data = read(pkt)
			if not data or bad[data.i] then return end
			if count() >= 2048 then
				local first = pop()
				if first then send(first) end
			end
			local ok = pcall(function() pkt:Block() end)
			if not ok then return end
			local now = os.clock()
			local at = now + extra / 1000
			if at <= last then at = last + 0.000001 end
			last = at
			data.t = at
			push(data)
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
				while q[head] and q[head].t <= now do
					local pkt = pop()
					if pkt then send(pkt) end
				end
				task.wait()
			end
		end)
		return true
	end

	local function start()
		if meth.Value == 'Raknet' then return rak() end
		return normal()
	end

	local function fail()
		warn()
		task.defer(function()
			if mod.Enabled then mod:Toggle() end
		end)
	end

	mod = ctx:module('blatant', {
		name = 'FakeLag',
		tooltip = 'Simulates fluctuating network delay using local replication or Raknet packets.',
		extratext = function()
			return meth and meth.Value or 'Normal'
		end,
		func = function(on)
			if on then
				if meth.Value == 'Raknet' and not ready() then
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
			if val == 'Raknet' and not ready() then
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
