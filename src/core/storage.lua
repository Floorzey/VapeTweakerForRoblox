return function(ctx)
	local http = game:GetService('HttpService')
	local store = {root = ctx.loader.root, dirs = {}}

	local function norm(path)
		path = tostring(path or ''):gsub('\\', '/'):gsub('/+', '/')
		path = path:gsub('^%./', ''):gsub('^/+', ''):gsub('/+$', '')
		if path:find('[%z\1-\31:]') then return nil end
		local parts = {}
		for part in path:gmatch('[^/]+') do
			if part == '..' then return nil end
			if part ~= '.' then parts[#parts + 1] = part end
		end
		return table.concat(parts, '/')
	end


	local function variant(path, tag)
		path = norm(path)
		if not path then return nil end
		local stem, ext = path:match('^(.*)(%.[^/%.]+)$')
		return stem and stem..'.'..tag..ext or path..'.'..tag
	end

	function store:path(path)
		path = norm(path)
		if not path then return nil end
		return path == '' and self.root or self.root..'/'..path
	end

	function store:mkdir(path)
		path = self:path(path)
		if not path or type(makefolder) ~= 'function' then return false end
		local out = ''
		for part in path:gmatch('[^/]+') do
			out = out == '' and part or out..'/'..part
			if not self.dirs[out] then
				local present = false
				if type(isfolder) == 'function' then
					local ok, val = pcall(isfolder, out)
					present = ok and val == true
				end
				if not present then
					local ok, msg = pcall(makefolder, out)
					if not ok and type(isfolder) == 'function' then
						local checked, val = pcall(isfolder, out)
						if checked and val then ok = true end
					end
					if not ok and type(isfolder) == 'function' then
						ctx.log:add('storage', out, msg)
						return false
					end
				end
				self.dirs[out] = true
			end
		end
		return true
	end

	function store:read(path)
		path = self:path(path)
		if not path or type(readfile) ~= 'function' then return nil end
		if type(isfile) == 'function' then
			local ok, val = pcall(isfile, path)
			if ok and not val then return nil end
		end
		local ok, data = pcall(readfile, path)
		if ok and type(data) == 'string' then return data end
		if not ok then ctx.log:add('storage', path, data) end
	end

	function store:variant(path, tag)
		return variant(path, tostring(tag or 'tmp'))
	end

	function store:temp(path, token)
		local tag = token and tostring(token)..'.tmp' or 'tmp'
		return variant(path, tag)
	end

	function store:backup(path)
		return variant(path, 'bak')
	end

	function store:write(path, data)
		path = norm(path)
		local full = path and self:path(path)
		if not full or type(writefile) ~= 'function' then return false end
		local dir = path:match('^(.*)/[^/]+$')
		if dir and not self:mkdir(dir) then return false end
		local ok, msg = pcall(writefile, full, tostring(data))
		if not ok or msg == false then
			ctx.log:add('storage', full, ok and 'writefile returned false' or msg)
			return false
		end
		return true
	end

	function store:remove(path)
		local full = self:path(path)
		if not full or type(delfile) ~= 'function' then return false end
		if type(isfile) == 'function' then
			local checked, present = pcall(isfile, full)
			if checked and not present then return true end
		end
		local ok, msg = pcall(delfile, full)
		if not ok or msg == false then
			ctx.log:add('storage', full, ok and 'delfile returned false' or msg)
			return false
		end
		return true
	end

	function store:decode(raw, path)
		local ok, data = pcall(http.JSONDecode, http, raw)
		if ok then return data end
		ctx.log:add('config_parse', path, data)
	end

	function store:encode(data, path)
		local ok, raw = pcall(http.JSONEncode, http, data)
		if ok then return raw end
		ctx.log:add('config_write', path, raw)
	end

	function store:json(path)
		local raw = self:read(path)
		if not raw then return nil end
		return self:decode(raw, path)
	end

	function store:has(path)
		return self:read(path) ~= nil
	end

	store.fs = {
		read = type(readfile) == 'function',
		write = type(writefile) == 'function',
		folders = type(makefolder) == 'function',
		delete = type(delfile) == 'function'
	}

	ctx.store = store
end
