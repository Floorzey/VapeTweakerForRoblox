return function(ctx)
	local http = game:GetService('HttpService')
	local seen = {}
	local excluded = {
		modules = {},
		patches = {}
	}
	local removals = {}
	local tree

	local function clean(path)
		return tostring(path or '')
			:gsub('\\', '/')
			:gsub('/+', '/')
			:gsub('^/+', '')
			:gsub('/+$', '')
			:lower()
	end

	local function fail(kind, path, message, fatal)
		ctx.log:add(kind, path, message, fatal)
		if fatal then error(message, 0) end
	end

	local function trace(message)
		if ctx.cfg.debug and debug and type(debug.traceback) == 'function' then
			return debug.traceback(tostring(message), 2)
		end
		return tostring(message)
	end

	local function addexclude(kind, value)
		if type(value) == 'string' then
			value = clean(value)
			if value ~= '' then excluded[kind][value] = true end
			return
		end
		if type(value) ~= 'table' then return end
		for key, item in pairs(value) do
			local path = type(key) == 'number' and item or item == true and key or nil
			if type(path) == 'string' then addexclude(kind, path) end
		end
	end

	local function addremovals(value)
		if type(value) == 'string' then
			removals[value] = true
			return
		end
		if type(value) ~= 'table' then return end
		for key, item in pairs(value) do
			local name = type(key) == 'number' and item or item == true and key or nil
			if type(name) == 'string' and name ~= '' then removals[name] = true end
		end
	end

	local function collect(manifest)
		if type(manifest) ~= 'table' then return end
		local block = manifest.exclude or manifest.excludes
		if type(block) == 'table' then
			addexclude('modules', block.modules)
			addexclude('patches', block.patches)
		end
		addremovals(manifest.remove or manifest.removes)
	end

	local function isexcluded(path, kind)
		local rel = clean(path)
		local root = kind == 'modules' and 'src/modules/' or 'src/patches/'
		if rel:sub(1, #root) == root then rel = rel:sub(#root + 1) end
		if excluded[kind][rel] or excluded[kind][clean(path)] then return true end
		for pattern in pairs(excluded[kind]) do
			if pattern:sub(-2) == '/*' then
				local prefix = pattern:sub(1, -2)
				if rel == prefix or rel:sub(1, #prefix + 1) == prefix..'/' then
					return true
				end
			end
		end
		return false
	end

	local function run(path, meta)
		path = clean(path)
		if seen[path] then return false end
		if meta.scope == 'universal' and isexcluded(path, meta.kind) then return false end
		seen[path] = true

		local mark = ctx:_mark()
		local previous = ctx.loading
		ctx.loading = {
			layer = meta.layer,
			scope = meta.scope,
			category = meta.category,
			kind = meta.kind,
			path = path,
			required = meta.required == true
		}

		local ok, message = xpcall(function()
			local init = ctx.loader:run(path)
			if type(init) ~= 'function' then
				error(path..' must return a function', 0)
			end
			init(ctx)
		end, trace)

		ctx.loading = previous
		if ok then return true end
		if not ctx:_rollback(mark) then
			error('incomplete rollback for '..path, 0)
		end
		fail(meta.kind, path, message, ctx.cfg.strict or meta.required == true)
		return false
	end

	local function categories(manifest, path)
		if manifest.categories == nil then return table.clone(ctx.cats.order) end
		if type(manifest.categories) ~= 'table' then
			error(path..' categories must be a table', 0)
		end

		local output = {}
		local added = {}
		for key, value in pairs(manifest.categories) do
			local category = type(key) == 'number' and value or value and key or nil
			if category then
				category = tostring(category):lower()
				if not ctx.cats.names[category] then
					error(path..' has unsupported category '..category, 0)
				end
				if not added[category] then
					added[category] = true
					output[#output + 1] = category
				end
			end
		end

		table.sort(output, function(a, b)
			return table.find(ctx.cats.order, a) < table.find(ctx.cats.order, b)
		end)
		return output
	end

	local function loadcategory(root, category, kind, layer, scope)
		local manifestpath = root..'/'..category..'/manifest.lua'
		local ok, manifest, state = ctx.loader:try(manifestpath)
		if not ok then
			if state ~= 'missing' then fail(kind, manifestpath, manifest, ctx.cfg.strict) end
			return 0
		end
		if type(manifest) ~= 'table' then
			fail(kind, manifestpath, manifestpath..' must return a table', ctx.cfg.strict)
			return 0
		end

		local count = 0
		for _, entry in ipairs(manifest.files or manifest[kind] or manifest) do
			local file = type(entry) == 'string' and entry
				or type(entry) == 'table' and (entry.path or entry.file)
			if file and (type(entry) ~= 'table' or entry.enabled ~= false) then
				if run(root..'/'..category..'/'..file, {
					layer = layer,
					scope = scope,
					category = category,
					kind = kind,
					required = type(entry) == 'table' and entry.required == true
				}) then
					count += 1
				end
			end
		end
		return count
	end

	local function loadmanifestroot(root, kind, layer, scope, required)
		local manifestpath = root..'/manifest.lua'
		local ok, manifest, state = ctx.loader:try(manifestpath)
		if not ok then
			if required or state ~= 'missing' then
				fail('layer', manifestpath, manifest or 'missing manifest', required or ctx.cfg.strict)
			end
			return 0
		end
		if type(manifest) ~= 'table' then
			fail('layer', manifestpath, manifestpath..' must return a table', required or ctx.cfg.strict)
			return 0
		end

		local count = 0
		if manifest.init then
			if run(root..'/'..manifest.init, {
				layer = layer,
				scope = scope,
				kind = kind,
				required = true
			}) then
				count += 1
			end
		end

		for _, category in ipairs(categories(manifest, manifestpath)) do
			count += loadcategory(root, category, kind, layer, scope)
		end

		ctx.layers[#ctx.layers + 1] = {
			name = layer,
			kind = kind,
			root = root,
			files = count
		}
		return count
	end

	local function repoinfo()
		local base = tostring(ctx.loader.base or ctx.loader.requestbase or '')
		local owner, repo, ref = base:match(
			'^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)'
		)
		return owner, repo, ref
	end

	local function repotree()
		if tree ~= nil then return tree end
		tree = false

		local owner, repo, ref = repoinfo()
		if not owner or not repo or not ref then return false end

		local url = 'https://api.github.com/repos/'..owner..'/'..repo
			..'/git/trees/'..ref..'?recursive=1&vt='..tostring(os.clock())

		local ok, raw = pcall(game.HttpGet, game, url, true)
		if not ok or type(raw) ~= 'string' then return false end

		local decoded, data = pcall(http.JSONDecode, http, raw)
		if not decoded or type(data) ~= 'table' or type(data.tree) ~= 'table' then
			return false
		end

		tree = {}
		for _, entry in ipairs(data.tree) do
			if entry.type == 'blob' and type(entry.path) == 'string' then
				tree[#tree + 1] = entry.path
			end
		end
		table.sort(tree)
		return tree
	end

	local function autodiscover(root, kind, layer)
		local listing = repotree()
		if type(listing) ~= 'table' then return 0 end

		local prefix = clean(root)..'/'
		local files = {}
		for _, path in ipairs(listing) do
			local normalized = clean(path)
			if normalized:sub(1, #prefix) == prefix
				and normalized:sub(-4) == '.lua'
				and normalized:sub(-13) ~= '/manifest.lua' then
				local rel = normalized:sub(#prefix + 1)
				local category = rel:match('^([^/]+)/')
				if category and ctx.cats.names[category] then
					files[#files + 1] = {
						path = normalized,
						category = category
					}
				end
			end
		end

		local count = 0
		for _, file in ipairs(files) do
			if run(file.path, {
				layer = layer,
				scope = 'place',
				category = file.category,
				kind = kind
			}) then
				count += 1
			end
		end

		if count > 0 then
			ctx.layers[#ctx.layers + 1] = {
				name = layer,
				kind = kind,
				root = root,
				files = count,
				discovered = true
			}
		end
		return count
	end

	local function loadplace(root, manifest)
		if manifest.init then
			run(root..'/'..manifest.init, {
				layer = 'place:'..tostring(game.PlaceId),
				scope = 'place',
				kind = 'init',
				required = true
			})
		end

		if manifest.modules ~= false then
			local modulecount = autodiscover(
				root..'/modules',
				'modules',
				'place:'..tostring(game.PlaceId)..':modules'
			)
			if modulecount == 0 then
				loadmanifestroot(
					root..'/modules',
					'modules',
					'place:'..tostring(game.PlaceId)..':modules',
					'place',
					false
				)
			end
		end

		if manifest.patches ~= false then
			local patchcount = autodiscover(
				root..'/patches',
				'patches',
				'place:'..tostring(game.PlaceId)..':patches'
			)
			if patchcount == 0 then
				loadmanifestroot(
					root..'/patches',
					'patches',
					'place:'..tostring(game.PlaceId)..':patches',
					'place',
					false
				)
			end
		end
	end

	local function applyremovals()
		for name in pairs(removals) do
			if ctx.mods[name] then
				local ok = ctx:drop(name)
				if not ok then
					fail('layer', name, 'failed to remove universal module '..name, ctx.cfg.strict)
				end
			end
		end
	end

	function ctx:loadlayers()
		local placeid = tostring(self.target.placeid or game.PlaceId)
		local gameroot = 'src/games/'..placeid
		local manifestpath = gameroot..'/manifest.lua'
		local supported, manifest, state = self.loader:try(manifestpath)

		if supported then
			if type(manifest) ~= 'table' then
				fail('layer', manifestpath, manifestpath..' must return a table', self.cfg.strict)
				manifest = {}
			end
			collect(manifest)
		elseif state ~= 'missing' then
			fail('layer', manifestpath, manifest, self.cfg.strict)
		end

		self.excluded = {
			modules = table.clone(excluded.modules),
			patches = table.clone(excluded.patches)
		}
		self.removals = table.clone(removals)
		self.supportedgame = supported == true
		self.gamefolder = supported and gameroot or nil

		loadmanifestroot(
			'src/modules',
			'modules',
			'universal:modules',
			'universal',
			true
		)
		loadmanifestroot(
			'src/patches',
			'patches',
			'universal:patches',
			'universal',
			true
		)

		if supported then
			applyremovals()
			loadplace(gameroot, manifest)
		end
	end
end
