return function(ctx)
	local api = {}

	function api:known()
		return false
	end

	function api:resolve()
		return 'generic'
	end

	ctx.weapon = api
end
