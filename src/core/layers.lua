return function(ctx)
	local http = game:GetService('HttpService')
	local seen = {}
	local tree

	local function clean(path)
		return tostring(path or '')
			:gsub('\\', '/')
			:gsub('/+', '/')
			:gsub('^/+', '')
			:gsub('/+$', '')
			:lower()
	end

	local function fail(kind, path, msg, fatal)
		ctx.log:add(kind, path, msg, fatal)
		if fatal then error(msg, 0) end
	end

	local function trace(msg)
		if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
			return debug.traceback(tostring(msg), 2)
		end
		return tostring(msg)
	end

	local function run(path, data)
		path = clean(path)
		if seen[path] then return false end
		seen[path] = true
		local mark = ctx:_mark()
		local old = ctx.loading
		ctx.loading = {
			layer = data.layer,
			scope = data.scope,
			category = data.category,
			kind = data.kind,
			path = path,
			required = data.required == true
		}
		local ok, msg = xpcall(function()
			local init = ctx.loader:run(path)
			if type(init) ~= 'function' then error(path..' must return a function', 0) end
			init(ctx)
		end, trace)
		ctx.loading = old
		if ok then return true end
		if not ctx:_rollback(mark) then error('incomplete rollback for '..path, 0) end
		fail(data.kind, path, msg, ctx.cfg.strict or data.required == true)
		return false
	end

	local function cats(data, path)
		if data.categories == nil then return table.clone(ctx.cats.order) end
		if type(data.categories) ~= 'table' then error(path..' categories must be a table', 0) end
		local out = {}
		local seen2 = {}
		for key, val in pairs(data.categories) do
			local cat = type(key) == 'number' and val or val and key or nil
			if cat then
				cat = tostring(cat):lower()
				if not ctx.cats.names[cat] then error(path..' has unsupported category '..cat, 0) end
				if not seen2[cat] then
					seen2[cat] = true
					out[#out + 1] = cat
				end
			end
		end
		table.sort(out, function(a, b)
			return table.find(ctx.cats.order, a) < table.find(ctx.cats.order, b)
		end)
		return out
	end

	local function catload(root, cat, kind, layer, scope)
		local path = root..'/'..cat..'/manifest.lua'
		local ok, data, state = ctx.loader:try(path)
		if not ok then
			if state ~= 'missing' then fail(kind, path, data, ctx.cfg.strict) end
			return 0
		end
		if type(data) ~= 'table' then
			fail(kind, path, path..' must return a table', ctx.cfg.strict)
			return 0
		end
		local count = 0
		for _, item in ipairs(data.files or data[kind] or data) do
			local file = type(item) == 'string' and item or type(item) == 'table' and (item.path or item.file)
			if file and (type(item) ~= 'table' or item.enabled ~= false) then
				if run(root..'/'..cat..'/'..file, {
					layer = layer,
					scope = scope,
					category = cat,
					kind = kind,
					required = type(item) == 'table' and item.required == true
				}) then count += 1 end
			end
		end
		return count
	end

	local function rootload(root, kind, layer, scope, required)
		local path = root..'/manifest.lua'
		local ok, data, state = ctx.loader:try(path)
		if not ok then
			if required or state ~= 'missing' then fail('layer', path, data or 'missing manifest', required or ctx.cfg.strict) end
			return 0
		end
		if type(data) ~= 'table' then
			fail('layer', path, path..' must return a table', required or ctx.cfg.strict)
			return 0
		end
		local count = 0
		if data.init and run(root..'/'..data.init, {
			layer = layer,
			scope = scope,
			kind = kind,
			required = true
		}) then count += 1 end
		for _, cat in ipairs(cats(data, path)) do
			count += catload(root, cat, kind, layer, scope)
		end
		ctx.layers[#ctx.layers + 1] = {
			name = layer,
			kind = kind,
			root = root,
			files = count
		}
		return count
	end

	local function repo()
		local base = tostring(ctx.loader.base or ctx.loader.requestbase or '')
		return base:match('^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)')
	end

	local function scan()
		if tree ~= nil then return tree end
		tree = false
		local owner, name, ref = repo()
		if not owner or not name or not ref then return false end
		local url = 'https://api.github.com/repos/'..owner..'/'..name..'/git/trees/'..ref..'?recursive=1&vt='..tostring(os.clock())
		local ok, raw = pcall(game.HttpGet, game, url, true)
		if not ok or type(raw) ~= 'string' then return false end
		local ok2, data = pcall(http.JSONDecode, http, raw)
		if not ok2 or type(data) ~= 'table' or type(data.tree) ~= 'table' then return false end
		local out = {}
		for _, item in ipairs(data.tree) do
			if item.type == 'blob' and type(item.path) == 'string' then
				local path = clean(item.path)
				if path:sub(-4) == '.lua' then out[#out + 1] = path end
			end
		end
		table.sort(out)
		tree = out
		return out
	end

	local function gameload()
		local list = scan()
		if type(list) ~= 'table' then
			ctx.supportedgame = false
			ctx.gamefolder = nil
			return 0
		end
		local id = tostring(ctx.target.placeid or game.PlaceId)
		local root = 'src/games/'..id
		local prefix = root..'/'
		local files = {}
		for _, path in ipairs(list) do
			if path:sub(1, #prefix) == prefix then
				local rel = path:sub(#prefix + 1)
				if not rel:find('/', 1, true) then files[#files + 1] = path end
			end
		end
		table.sort(files)
		local count = 0
		for _, path in ipairs(files) do
			if run(path, {
				layer = 'place:'..id,
				scope = 'place',
				kind = 'game'
			}) then count += 1 end
		end
		ctx.supportedgame = count > 0
		ctx.gamefolder = count > 0 and root or nil
		if count > 0 then
			ctx.layers[#ctx.layers + 1] = {
				name = 'place:'..id,
				kind = 'game',
				root = root,
				files = count
			}
		end
		return count
	end

	function ctx:loadlayers()
		rootload('src/modules', 'modules', 'universal:modules', 'universal', true)
		rootload('src/patches', 'patches', 'universal:patches', 'universal', true)
		gameload()
	end
end
