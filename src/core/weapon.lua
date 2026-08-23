return function(ctx)
	local api = {}
	local players = game:GetService('Players')
	local rs = game:GetService('ReplicatedStorage')
	local lp = players.LocalPlayer

	local function up(fn, num)
		local get = debug and debug.getupvalue or getupvalue
		if type(get) ~= 'function' or type(fn) ~= 'function' then return end
		local out = table.pack(pcall(get, fn, num))
		if not out[1] then return end
		return out.n >= 3 and out[3] or out[2]
	end

	local function prison()
		if game.PlaceId ~= 155615604 or type(getconnections) ~= 'function' then return end
		local gui = lp and lp:FindFirstChild('PlayerGui')
		gui = gui and gui:FindFirstChild('Home')
		gui = gui and gui:FindFirstChild('hud')
		gui = gui and gui:FindFirstChild('ActionArea')
		if not gui then return end
		local ok, list = pcall(getconnections, gui.InputBegan)
		if not ok or type(list) ~= 'table' then return end
		for _, con in ipairs(list) do
			local fn = con and con.Function
			if type(fn) == 'function' then
				local shoot = up(fn, 2)
				local bullet = up(shoot, 16)
				if type(bullet) == 'function' then return bullet end
			end
		end
	end

	local function jail()
		if game.PlaceId ~= 606849621 then return end
		local gamef = rs:FindFirstChild('Game')
		local item = gamef and gamef:FindFirstChild('Item')
		local mod = item and item:FindFirstChild('Gun')
		if not mod then return end
		local ok, gun = pcall(require, mod)
		if not ok or type(gun) ~= 'table' or type(gun.ShootOther) ~= 'function' then return end
		return gun, gun.ShootOther
	end

	function api:known()
		return game.PlaceId == 155615604 or game.PlaceId == 606849621
	end

	function api:resolve()
		if game.PlaceId == 155615604 then
			for _ = 1, 30 do
				local fn = prison()
				if fn then return 'prison', fn end
				task.wait(0.05)
			end
			return nil, nil, 'Prison Life weapon function was not found.'
		end
		if game.PlaceId == 606849621 then
			for _ = 1, 30 do
				local gun, fn = jail()
				if fn then return 'jail', fn, gun end
				task.wait(0.05)
			end
			return nil, nil, 'Jailbreak weapon function was not found.'
		end
		return 'generic'
	end

	ctx.weapon = api
end
