return function(ctx)
	local function file(path)
		if type(isfile) ~= 'function' then return nil end
		local ok, val = pcall(isfile, path)
		if not ok then return nil end
		return val == true
	end

	function ctx:resolvetarget()
		local vape = self.vape
		local gameid = game.GameId
		local placeid = game.PlaceId
		local buildid = vape.Place or placeid
		local nativefile = file('newvape/games/'..tostring(placeid)..'.lua')
		local independent = type(shared) == 'table' and shared.VapeIndependent == true
		local native = not independent and (buildid ~= placeid or nativefile == true)
		local mode = independent and 'independent' or native and 'game' or 'universal'

		self.target = {
			mode = mode,
			gameid = gameid,
			placeid = placeid,
			buildid = buildid,
			native = native,
			native_known = buildid ~= placeid or nativefile ~= nil,
			gui = self.vapeapi.flavor or 'unknown',
			version = vape.Version,
			readiness = self.vapeapi.readiness
		}
		return self.target
	end
end
