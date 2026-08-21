return function(ctx)
	local mod
	local meth
	local mode
	local time
	local hook
	local net
	local old
	local busy = false
	local seq = 0
	local q = {}
	local head = 1
	local tail = 0

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
			pcall(vape.CreateNotification, vape, 'LagSwitch', 'This feature requires raknet! (risky feature, please do not use on mains.)', 10, 'warning')
		end
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
		local meta, pri, rel, chan = pcall(function()
			return pkt.Priority, pkt.Reliability, pkt.OrderingChannel
		end)
		if not meta then return nil end
		if type(pri) ~= 'number' or pri < 0 or pri > 3 then return nil end
		if type(rel) ~= 'number' or rel < 0 or rel > 7 then return nil end
		if type(chan) ~= 'number' or chan < 0 or chan > 31 then return nil end
		return {d = data, p = pri, r = rel, c = chan}
	end

	local function send(pkt)
		if not pkt or not api() then return false end
		local ok = pcall(raknet.send, pkt.d, pkt.p, pkt.r, pkt.c)
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
		end
		return pkt
	end

	local function count()
		return tail >= head and tail - head + 1 or 0
	end

	local function unhook()
		if hook and api() then pcall(raknet.remove_send_hook, hook) end
		hook = nil
	end

	local function flush()
		busy = true
		while head <= tail do
			local pkt = pop()
			if pkt then send(pkt) end
		end
		busy = false
		table.clear(q)
		head = 1
		tail = 0
	end

	local function stop()
		seq += 1
		unhook()
		flush()
		busy = false
		if old ~= nil then set(old) end
		old = nil
		net = nil
	end

	local function rak()
		if not ready() then return false end
		seq += 1
		local id = seq
		table.clear(q)
		head = 1
		tail = 0
		hook = function(pkt)
			if busy or not mod.Enabled or meth.Value ~= 'Raknet' or id ~= seq then return end
			local data = read(pkt)
			if not data then return end
			if count() >= 8192 then
				busy = true
				local out = pop()
				if out then send(out) end
				busy = false
			end
			local ok = pcall(function() pkt:Block() end)
			if not ok then return end
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
		if mode.Value == 'OneShot' then
			task.delay(math.max(tonumber(time.Value) or 1, 0), function()
				if id ~= seq or not mod.Enabled or meth.Value ~= 'Raknet' or mode.Value ~= 'OneShot' then return end
				if mod.Enabled then mod:Toggle() end
			end)
		end
		return true
	end

	local function rep()
		net = get()
		if not net then return false end
		local ok, val = pcall(function() return net.IncomingReplicationLag end)
		old = ok and val or 0
		seq += 1
		local id = seq
		local dur = math.max(tonumber(time.Value) or 1, 0)
		local lag = mode.Value == 'Toggle' and 1000000 or dur
		if not set(lag) then
			old = nil
			net = nil
			return false
		end
		if mode.Value == 'OneShot' then
			task.delay(dur, function()
				if id ~= seq or not mod.Enabled or meth.Value ~= 'Replication' or mode.Value ~= 'OneShot' then return end
				if mod.Enabled then mod:Toggle() end
			end)
		end
		return true
	end

	local function start()
		if meth.Value == 'Replication' then return rep() end
		return rak()
	end

	local function fail()
		if meth.Value == 'Raknet' then warn() end
		task.defer(function()
			if mod.Enabled then mod:Toggle() end
		end)
	end

	mod = ctx:module('blatant', {
		name = 'LagSwitch',
		tooltip = 'Temporarily stalls network traffic using Raknet or local replication lag.',
		extratext = function()
			if meth then return meth.Value end
			return 'Raknet'
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
		List = {'Raknet', 'Replication'},
		Default = 'Raknet',
		Function = function(val)
			if not mod.Enabled then
				if val == 'Raknet' and not ready() then warn() end
				return
			end
			stop()
			if val == 'Raknet' and not ready() then
				fail()
				return
			end
			if not start() then fail() end
		end
	})

	mode = mod:CreateDropdown({
		Name = 'Mode',
		List = {'OneShot', 'Toggle'},
		Default = 'OneShot',
		Function = function(val)
			if time and time.Object then time.Object.Visible = val == 'OneShot' end
			if not mod.Enabled then return end
			stop()
			if meth.Value == 'Raknet' and not ready() then
				fail()
				return
			end
			if not start() then fail() end
		end
	})

	time = mod:CreateSlider({
		Name = 'Time',
		Min = 0.1,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = 's'
	})

	if time.Object then time.Object.Visible = mode.Value == 'OneShot' end

	ctx:clean(stop)
end
