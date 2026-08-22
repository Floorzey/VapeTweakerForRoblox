local env = (getgenv and getgenv()) or _G
local rawcfg = type(env.VapeTweakerConfig) == 'table' and env.VapeTweakerConfig or {}
local compile = loadstring
local http = game:GetService('HttpService')
local ver = '1.4.0'
local build = '1.4.0'

local function pick(low, high, default)
	local val = rawcfg[low]
	if val == nil then val = rawcfg[high] end
	if val == nil then return default end
	return val
end

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

local function rooted(path, fallback)
	path = norm(path)
	if not path or path == '' or path == '.' then return fallback end
	return path
end

local cfg = {
	base = tostring(pick('base', 'BaseUrl', 'https://raw.githubusercontent.com/Floorzey/VapeTweakerForRoblox/main')):gsub('/+$', ''),
	root = rooted(pick('root', 'Root', 'VapeTweaker'), 'VapeTweaker'),
	cache = pick('cache', 'Cache', true) ~= false,
	localdev = rawcfg.localdev == true or rawcfg['local'] == true or rawcfg.Local == true,
	localroot = rooted(pick('localroot', 'LocalRoot', 'VapeTweakerDev'), 'VapeTweakerDev'),
	localfallback = pick('localfallback', 'LocalFallback', false) == true,
	strict = pick('strict', 'StrictModules', false) == true,
	timeout = tonumber(pick('timeout', 'Timeout', 45)) or 45,
	autoload = pick('autoload', 'AutoLoadVape', true) ~= false,
	vapeurl = pick('vapeurl', 'VapeUrl'),
	vapepath = pick('vapepath', 'VapePath'),
	gui = pick('gui', 'Gui'),
	notify = pick('notify', 'Notify', false) == true,
	debounce = tonumber(pick('debounce', 'Debounce', 1.5)) or 1.5,
	debug = pick('debug', 'Debug', false) == true
}
cfg.timeout = math.clamp(cfg.timeout, 1, 120)

local token = {done = false, cancelled = false}
local previous = env.VapeTweakerLoading
if type(previous) == 'table' and not previous.done then
	previous.cancelled = true
	local started = os.clock()
	while not previous.done and os.clock() - started < cfg.timeout do task.wait(0.05) end
end
env.VapeTweakerLoading = token

local function owned()
	return not token.cancelled and env.VapeTweakerLoading == token
end

local function active()
	if not owned() then error('bootstrap superseded', 0) end
	return true
end

local function finish()
	token.done = true
	if env.VapeTweakerLoading == token then env.VapeTweakerLoading = nil end
end

local loaderrors = {}
local requestbase = cfg.base
local immutable = false
local moving = false
local nonce
local made, value = pcall(http.GenerateGUID, http, false)
if made and type(value) == 'string' and value ~= '' then
	nonce = value:gsub('[^%w%-_]', '')
else
	nonce = tostring(os.time and os.time() or 0)..'-'..tostring(math.floor(os.clock() * 1000000))
end

local function fresh(url)
	return url..(url:find('?', 1, true) and '&' or '?')..'vt='..nonce
end
if not cfg.localdev or cfg.localfallback then
	local owner, repo, ref = requestbase:match('^https://raw%.githubusercontent%.com/([^/]+)/([^/]+)/([^/]+)$')
	moving = owner ~= nil and repo ~= nil and (ref == 'main' or ref == 'master')
end

local function variant(path, tag)
	local stem, ext = path:match('^(.*)(%.[^/%.]+)$')
	return stem and stem..'.'..tag..ext or path..'.'..tag
end

local function join(a, b)
	if a == '' then return b end
	if b == '' then return a end
	return a..'/'..b
end

local function exists(path)
	if type(isfile) == 'function' then
		local ok, val = pcall(isfile, path)
		if ok then return val == true end
	end
	if type(readfile) ~= 'function' then return false end
	local ok, val = pcall(readfile, path)
	return ok and type(val) == 'string'
end

local function mkdir(path)
	if type(makefolder) ~= 'function' then return false end
	local out = ''
	for part in path:gmatch('[^/]+') do
		out = out == '' and part or out..'/'..part
		local present = false
		if type(isfolder) == 'function' then
			local ok, val = pcall(isfolder, out)
			present = ok and val == true
		end
		if not present then pcall(makefolder, out) end
	end
	return true
end

local function read(path)
	if type(readfile) ~= 'function' or not exists(path) then return nil end
	local ok, data = pcall(readfile, path)
	if ok and type(data) == 'string' then return data end
end

local function write(path, data)
	if type(writefile) ~= 'function' then return false end
	local dir = path:match('^(.*)/[^/]+$')
	if dir then mkdir(dir) end
	local ok, result = pcall(writefile, path, data)
	return ok and result ~= false
end

for _, path in ipairs({
	cfg.root,
	join(cfg.root, 'cache'),
	join(cfg.root, 'cache/files'),
	join(cfg.root, 'configs'),
	join(cfg.root, 'configs/profiles'),
	join(cfg.root, 'state'),
	join(cfg.root, 'data')
}) do
	mkdir(path)
end

local meta = {}
local metapath = join(cfg.root, 'cache/meta.json')
local backpath = variant(metapath, 'bak')
local legacyback = metapath..'.bak'
local function validmeta(data, expected)
	if type(data) ~= 'table' or data.schema ~= 5 or data.build ~= build
		or data.requestbase ~= requestbase or data.good ~= true
		or type(data.cohort) ~= 'string' or not data.cohort:match('^[%w_%-]+$')
		or type(data.files) ~= 'table' then return false end
	local count = 0
	for path, info in pairs(data.files) do
		if type(path) ~= 'string' or path == '' or norm(path) ~= path or type(info) ~= 'table'
			or type(info.size) ~= 'number' or info.size < 1 then return false end
		if expected and expected[path] == nil then return false end
		local source = join(join(join(join(cfg.root, 'cache/files'), build), data.cohort), path)
		local body = read(source)
		if not body or #body ~= info.size then return false end
		count = count + 1
	end
	if count == 0 then return false end
	if expected then
		local wanted = 0
		for path in pairs(expected) do
			wanted = wanted + 1
			if data.files[path] == nil then return false end
		end
		if wanted ~= count then return false end
	end
	return true
end

local function readmeta(path, expected)
	local raw = read(path)
	if not raw then return nil, nil end
	local ok, data = pcall(http.JSONDecode, http, raw)
	if ok and validmeta(data, expected) then return data, raw end
	loaderrors[#loaderrors + 1] = {
		time = os.clock(),
		kind = 'cache',
		path = path,
		message = 'invalid cache metadata'
	}
	return nil, raw
end
local primary, primaryraw = readmeta(metapath)
local backup, backupraw = readmeta(backpath)
if not backup then backup, backupraw = readmeta(legacyback) end
local metaraw = primary and primaryraw or backupraw
meta = primary or backup or {}
local cacheok = primary ~= nil or backup ~= nil
if not cacheok then
	meta = {
			schema = 5,
		version = ver,
		build = build,
		base = cfg.base,
		requestbase = requestbase,
		good = false,
		files = {}
	}
end
meta.files = type(meta.files) == 'table' and meta.files or {}

local ld = {
	version = ver,
	build = build,
	cfg = cfg,
	root = cfg.root,
	base = cfg.base,
	misses = {},
	pending = {},
	stats = {remote = 0, cache = 0, localdev = 0, missing = 0, requested = 0},
	meta = meta,
	cachevalid = cacheok,
	errors = loaderrors,
	immutable = immutable,
	moving = moving,
	metaraw = metaraw,
	requestbase = requestbase,
	mode = nil
}

function ld:active()
	return active()
end

function ld:cacheerror(path, msg)
	self.errors[#self.errors + 1] = {
		time = os.clock(),
		kind = 'cache',
		path = path,
		message = tostring(msg)
	}
end

function ld:cachestatus()
	local pending = 0
	local misses = 0
	for _ in pairs(self.pending) do pending = pending + 1 end
	for _ in pairs(self.misses) do misses = misses + 1 end
	local mode = self.mode or (cfg.localdev and 'local' or 'remote')
	if cfg.localdev and self.stats.localdev > 0 and self.mode then mode = 'local+'..self.mode end
	return {
		enabled = cfg.cache,
		valid = self.cachevalid,
		mode = mode,
		fallback = self.mode == 'cache',
		recovered = self.recovered == true,
		immutable = self.immutable,
		revision = cfg.base ~= requestbase and cfg.base:match('/([^/]+)$') or nil,
		prunable = type(delfolder) == 'function',
		pending = pending,
		misses = misses,
		errors = #self.errors,
		stats = table.clone(self.stats)
	}
end

local function cachepath(path, cohort)
	cohort = cohort or meta.cohort
	if type(cohort) ~= 'string' or cohort == '' then return nil end
	return join(join(join(join(cfg.root, 'cache/files'), build), cohort), path)
end

local function dropcohort(cohort)
	if type(delfolder) ~= 'function' or type(cohort) ~= 'string'
		or not cohort:match('^[%w_%-]+$') then return false end
	local path = cachepath('', cohort)
	local base = join(join(cfg.root, 'cache/files'), build)..'/'
	if not path or path:sub(1, #base) ~= base then return false end
	return pcall(delfolder, path)
end

local function localfile(path)
	if not cfg.localdev or ld.cacheonly then return nil end
	local data = read(join(cfg.localroot, path))
	if data and data ~= '' then
		ld.stats.localdev = ld.stats.localdev + 1
		return data, 'local'
	end
	return nil, 'missing'
end

local function cachefile(path)
	if not cfg.cache or not cacheok then return nil end
	if type(meta.files[path]) ~= 'table' then return nil end
	local data = read(cachepath(path))
	if data and data ~= '' then
		ld.stats.cache = ld.stats.cache + 1
		return data, 'cache'
	end
	ld:cacheerror(path, 'cached source is unavailable')
end

local function savecache(path, data, cohort, files)
	if not cfg.cache then return false end
	local target = cachepath(path, cohort)
	if not target or not write(target, data) or read(target) ~= data then
		ld:cacheerror(path, 'cache source write failed')
		return false
	end
	files[path] = {time = os.time and os.time() or 0, size = #data}
	return true
end

local function remote(path)
	active()
	ld.remoteattempted = true
	local url = cfg.base..'/'..path
	if moving and not immutable then url = fresh(url) end
	local ok, data = pcall(game.HttpGet, game, url, true)
	active()
	if not ok then return nil, tostring(data), 'network' end
	if type(data) ~= 'string' or data == '' then return nil, 'empty response', 'network' end
	if data == '404: Not Found' or data:find('404: Not Found', 1, true) then
		return nil, 'missing', 'missing'
	end
	ld.stats.remote = ld.stats.remote + 1
	return data, 'remote'
end

local function source(path, optional)
	active()
	path = norm(path)
	if not path or path == '' then error('invalid source path', 0) end
	if ld.misses[path] then
		if optional then return nil, 'missing' end
		error('missing source: '..path, 0)
	end

	ld.stats.requested = ld.stats.requested + 1
	local data, from = localfile(path)
	if data then return data, from end
	if cfg.localdev and not cfg.localfallback then
		ld.misses[path] = true
		ld.stats.missing = ld.stats.missing + 1
		if optional then return nil, 'missing' end
		error('missing local source: '..path, 0)
	end

	if ld.mode == 'cache' then
		data, from = cachefile(path)
		if data then return data, from end
		ld.misses[path] = true
		ld.stats.missing = ld.stats.missing + 1
		if optional then return nil, 'missing' end
		error('missing cached source: '..path, 0)
	end

	local rem, detail, state = remote(path)
	if rem then
		ld.mode = 'remote'
		return rem, detail
	end
	if state == 'missing' then
		ld.misses[path] = true
		ld.stats.missing = ld.stats.missing + 1
		if optional then return nil, 'missing' end
		error('missing remote source: '..path, 0)
	end

	data, from = cachefile(path)
	if data then return data, from end
	if optional and state == 'missing' then return nil, 'missing' end
	error('source unavailable: '..path..' ('..tostring(detail)..')', 0)
end

function ld:load(path, optional, ...)
	active()
	path = norm(path)
	if not path then error('invalid source path', 0) end
	local src, from = source(path, optional)
	if not src then return nil, from, false end
	if type(compile) ~= 'function' then error('loadstring is unavailable', 0) end
	local fn, msg = compile(src, '@vapetweaker/'..build..'/'..path)
	if not fn then
		error('compile failed for '..path..' ('..tostring(from)..'): '..tostring(msg), 0)
	end
	if from == 'remote' then self.pending[path] = src end
	local result = fn(...)
	active()
	return result, from, true
end

function ld:run(path, ...)
	return self:load(path, false, ...)
end

function ld:try(path, ...)
	local out = table.pack(pcall(self.load, self, path, true, ...))
	if not out[1] then return false, out[2], 'error' end
	if out[4] == false then return false, nil, 'missing' end
	return true, table.unpack(out, 2, out.n)
end

function ld:flush(data, expected)
	data = data or meta
	if not cfg.cache or not owned() or not validmeta(data, expected) then return false, false end
	local ok, raw = pcall(http.JSONEncode, http, data)
	if not ok then
		self:cacheerror(metapath, 'cache metadata encode failed')
		return false, false
	end
	local tmp = variant(metapath, data.cohort..'.tmp')
	if not write(tmp, raw) then
		self:cacheerror(tmp, 'cache metadata candidate write failed')
		return false, false
	end
	local candidate = readmeta(tmp, expected)
	if not candidate or candidate.cohort ~= data.cohort then return false, false end
	if cacheok and not primary then
		if not owned() or not write(metapath, metaraw) then
			self:cacheerror(metapath, 'cache metadata recovery failed')
			return false, false
		end
		local recovered = readmeta(metapath)
		if not recovered or recovered.cohort ~= meta.cohort then return false, false end
	end
	if not owned() or not write(backpath, raw) then
		self:cacheerror(backpath, 'cache metadata backup promotion failed')
		return false, false
	end
	local nextbackup = readmeta(backpath, expected)
	if not nextbackup or nextbackup.cohort ~= data.cohort then return false, false end
	if not owned() or not write(metapath, raw) then
		self:cacheerror(metapath, 'cache metadata promotion failed')
		return false, true
	end
	local final = readmeta(metapath, expected)
	if not final or final.cohort ~= data.cohort then
		self:cacheerror(metapath, 'cache metadata verification failed')
		return false, true
	end
	if type(delfile) == 'function' then pcall(delfile, tmp) end
	self.metaraw = raw
	return true, true
end

local function saveerror(msg)
	if not owned() then return end
	env.VapeTweakerLastError = tostring(msg)
	local data = {
		version = ver,
		time = os.time and os.time() or 0,
		message = tostring(msg)
	}
	local ok, encoded = pcall(http.JSONEncode, http, data)
	if ok and owned() then write(join(cfg.root, 'state/last_error.json'), encoded) end
end

local function trace(msg)
	if cfg.debug and debug and type(debug.traceback) == 'function' then
		return debug.traceback(tostring(msg), 2)
	end
	return tostring(msg)
end

local function boot()
	return xpcall(function()
		return ld:run('src/init.lua', ld)
	end, trace)
end

local ok, result = boot()
local failed = not ok or type(result) ~= 'table' or result.state ~= 'loaded'
if not owned() then finish() return nil end
if failed and cacheok and ld.mode ~= 'cache' and ld.remoteattempted
	and (not cfg.localdev or cfg.localfallback) then
	ld.mode = 'cache'
	ld.cacheonly = true
	ld.recovered = true
	table.clear(ld.misses)
	table.clear(ld.pending)
	ok, result = boot()
	failed = not ok or type(result) ~= 'table' or result.state ~= 'loaded'
end

if failed then
	if owned() then saveerror(ok and 'runtime did not return a context' or result) end
	finish()
	return nil
end

if not owned() then finish() return nil end

if cfg.cache and ld.mode == 'remote' and ld.stats.localdev == 0 and (not moving or immutable) then
	local same = cacheok
	local count = 0
	if same then
		for path, src in pairs(ld.pending) do
			count = count + 1
			if read(cachepath(path)) ~= src then same = false break end
		end
		local cached = 0
		for _ in pairs(meta.files) do cached = cached + 1 end
		if count ~= cached then same = false end
	end
	if same then
		ld.cachevalid = true
		table.clear(ld.pending)
	else
		local made, cohort = pcall(http.GenerateGUID, http, false)
		if not made or type(cohort) ~= 'string' or cohort == '' then
			cohort = tostring(os.time and os.time() or 0)..'-'..tostring(math.floor(os.clock() * 1000000))
		end
		local files = {}
		local committed = true
		for path, src in pairs(ld.pending) do
			if not owned() or not savecache(path, src, cohort, files) then committed = false break end
		end
		if committed and next(files) then
			local oldcohort = cacheok and meta.cohort
			local nextmeta = {
				schema = 5,
				version = ver,
				build = build,
				base = cfg.base,
				requestbase = requestbase,
				immutable = immutable,
				good = true,
				cohort = cohort,
				files = files
			}
			local promoted, keep = ld:flush(nextmeta, ld.pending)
			if promoted then
				meta = nextmeta
				ld.meta = meta
				ld.cachevalid = true
				table.clear(ld.pending)
				if owned() and oldcohort and oldcohort ~= cohort then dropcohort(oldcohort) end
			elseif not keep then
				dropcohort(cohort)
			end
		elseif not committed then
			dropcohort(cohort)
		end
	end
	elseif not cfg.cache or ld.mode == 'remote' then
	table.clear(ld.pending)
end
if not owned() then finish() return nil end
env.VapeTweakerLastError = nil
local last = join(cfg.root, 'state/last_error.json')
if exists(last) then
	if type(delfile) == 'function' then
		pcall(delfile, last)
	elseif type(writefile) == 'function' then
		write(last, '{}')
	end
end
if not owned() then finish() return nil end
finish()
return result
