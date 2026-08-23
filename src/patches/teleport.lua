return function(ctx)
	local env = (getgenv and getgenv()) or _G
	local raw = type(env.VapeTweakerConfig) == 'table' and env.VapeTweakerConfig or {}
	local enabled = raw.teleport
	if enabled == nil then enabled = raw.Teleport end
	if enabled == false then
		ctx.teleport = {supported = false, queued = false, disabled = true}
		return
	end

	local queue = env.queue_on_teleport or env.queueonteleport or env.queueteleport
	if type(queue) ~= 'function' and type(syn) == 'table' then
		queue = syn.queue_on_teleport
	end
	if type(queue) ~= 'function' and type(fluxus) == 'table' then
		queue = fluxus.queue_on_teleport
	end

	local supported = type(queue) == 'function'
	ctx.teleport = {
		supported = supported,
		queued = env.VapeTweakerTeleportQueued == true,
		disabled = false
	}

	local players = game:GetService('Players')
	local lp = players.LocalPlayer
	if lp and lp.OnTeleport then
		ctx:clean(lp.OnTeleport:Connect(function(state)
			if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then
				if ctx.config and type(ctx.config.save) == 'function' then
					pcall(ctx.config.save, ctx.config, true)
				end
			end
		end))
	end

	if not supported or env.VapeTweakerTeleportQueued then return end

	local cfg = {}
	for key, value in pairs(ctx.cfg or {}) do
		local kind = type(value)
		if kind == 'boolean' or kind == 'number' or kind == 'string' then
			cfg[key] = value
		end
	end
	cfg.base = ctx.loader.requestbase or cfg.base
	cfg.teleport = true

	local http = game:GetService('HttpService')
	local ok, encoded = pcall(http.JSONEncode, http, cfg)
	if not ok then encoded = '{}' end

	local loaderurl = tostring(
		cfg.base or 'https://raw.githubusercontent.com/Floorzey/VapeTweakerForRoblox/main'
	):gsub('/+$', '')..'/loader.lua'

	local source = string.format([[
local env = (getgenv and getgenv()) or _G
if env.VapeTweakerTeleportBooting then return end
env.VapeTweakerTeleportBooting = true
env.VapeTweakerTeleportQueued = nil

local http = game:GetService('HttpService')
local ok, cfg = pcall(http.JSONDecode, http, %q)
env.VapeTweakerConfig = ok and type(cfg) == 'table' and cfg or {}

local fetched, body = pcall(
	game.HttpGet,
	game,
	%q..'?teleport='..tostring(os.clock()),
	true
)

if fetched and type(body) == 'string' then
	local fn = loadstring(body)
	if fn then pcall(fn) end
end

env.VapeTweakerTeleportBooting = nil
]], encoded, loaderurl)

	local queued = pcall(queue, source)
	if queued then
		env.VapeTweakerTeleportQueued = true
		ctx.teleport.queued = true
	end
end
