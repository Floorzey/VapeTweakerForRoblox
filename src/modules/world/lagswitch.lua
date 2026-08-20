return function(ctx)
	local mod
	local mode
	local time
	local hook
	local busy = false
	local seq = 0
	local q = {}
	local head = 1
	local tail = 0

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
	end

	local function fail()
		warn()
		task.defer(function()
			if mod.Enabled then mod:Toggle() end
		end)
	end

	local function start()
		if not ready() then return false end
		seq += 1
		local id = seq
		table.clear(q)
		head = 1
		tail = 0
		hook = function(pkt)
			if busy or not mod.Enabled or id ~= seq then return end
			local data = read(pkt)
			if not data then return end
			if count() >= 8192 then
				busy = true
				local old = pop()
				if old then send(old) end
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
				if id ~= seq or not mod.Enabled or mode.Value ~= 'OneShot' then return end
				unhook()
				flush()
				if mod.Enabled then mod:Toggle() end
			end)
		end
		return true
	end

	mod = ctx:module('world', {
		name = 'LagSwitch',
		tooltip = 'Holds outgoing Raknet traffic and releases it in order.',
		extratext = function()
			if mode and mode.Value == 'Toggle' then return 'Toggle' end
			return time and tostring(time.Value)..'s' or '1s'
		end,
		func = function(on)
			if on then
				if not start() then fail() end
			else
				stop()
			end
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
