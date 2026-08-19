return function(ctx)
	local stats = game:GetService('Stats')
	local run = game:GetService('RunService')
	local mod
	local ping
	local send
	local recv
	local time = 0

	local function read(name)
		local ok, val = pcall(function()
			local net = stats.Network
			local tab = net and net.ServerStatsItem
			local item = tab and tab[name]
			return item and item:GetValue()
		end)
		return ok and tonumber(val) or 0
	end

	local function text()
		local out = {}
		if ping and ping.Enabled then
			out[#out + 1] = tostring(math.floor(read('Data Ping') + 0.5))..'ms'
		end
		if send and send.Enabled then
			out[#out + 1] = string.format('%.1f↑', read('Data Send Kbps'))
		end
		if recv and recv.Enabled then
			out[#out + 1] = string.format('%.1f↓', read('Data Receive Kbps'))
		end
		return table.concat(out, ' ')
	end

	local function update()
		if mod and mod.Enabled and type(ctx.vape.UpdateTextGUI) == 'function' then
			ctx.vape:UpdateTextGUI()
		end
	end

	mod = ctx:module('network', {
		name = 'NetworkStats',
		tooltip = 'Shows live Roblox network statistics in the Text GUI.',
		extratext = text,
		func = function(on)
			if on then
				time = 0
				mod:Clean(run.Heartbeat:Connect(function(dt)
					time += dt
					if time < 1 then return end
					time = 0
					update()
				end))
			else
				time = 0
			end
		end
	})

	ping = mod:CreateToggle({
		Name = 'Ping',
		Default = true,
		Function = update
	})

	send = mod:CreateToggle({
		Name = 'Send',
		Function = update
	})

	recv = mod:CreateToggle({
		Name = 'Receive',
		Function = update
	})
end
