return function(ctx)
	local api = {}
	local ray = RaycastParams.new()
	local over = OverlapParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	over.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function() ray.RespectCanCollide = true end)
	pcall(function() over.RespectCanCollide = true end)
	local pos = {
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(0.7, -0.5, -0.5),
		Vector3.new(-0.1, -0.8, -0.8),
		Vector3.new(-0.8, -0.5, -0.5),
		Vector3.new(-1, 0, 0),
		Vector3.new(-0.8, 0.4, 0.4),
		Vector3.new(0, 0.7, 0.7),
		Vector3.new(0.7, 0.5, 0.5),
		Vector3.new(0.7, 0, -0.8),
		Vector3.new(-0.1, 0, -1),
		Vector3.new(-0.8, 0, -0.8),
		Vector3.new(-0.8, 0, 0.7),
		Vector3.new(0, 0, 1),
		Vector3.new(0.7, 0, 0.7),
		Vector3.new(0.7, 0.4, -0.5),
		Vector3.new(-0.1, 0.7, -0.8),
		Vector3.new(-0.8, 0.4, -0.5),
		Vector3.new(-1, -0.1, 0),
		Vector3.new(-0.8, -0.5, 0.4),
		Vector3.new(0, -0.8, 0.7),
		Vector3.new(0.7, -0.6, 0.5),
		Vector3.new(0, -1, 0)
	}

	local function list(extra)
		local out = {}
		local lib = ctx.vape and ctx.vape.Libraries and ctx.vape.Libraries.entity
		local plr = game:GetService('Players').LocalPlayer
		if plr and plr.Character then out[#out + 1] = plr.Character end
		local cam = workspace.CurrentCamera
		if cam then out[#out + 1] = cam end
		if type(lib) == 'table' and type(lib.List) == 'table' then
			for _, ent in lib.List do
				if ent.Character then out[#out + 1] = ent.Character end
			end
		end
		if typeof(extra) == 'Instance' then out[#out + 1] = extra end
		return out
	end

	local function free(point)
		local ok, out = pcall(workspace.GetPartBoundsInRadius, workspace, point, 0, over)
		if not ok or type(out) ~= 'table' then return true end
		for _, part in out do
			if part.CanCollide then
				local ok2, near = pcall(part.GetClosestPointOnSurface, part, point)
				if ok2 and typeof(near) == 'Vector3' and (near - point).Magnitude <= 0.0001 then return false end
			end
		end
		return true
	end

	local function prep(extra)
		local out = list(extra)
		ray.FilterDescendantsInstances = out
		over.FilterDescendantsInstances = out
	end

	function api:scan(origin, target, extra, part)
		if typeof(origin) ~= 'Vector3' or typeof(target) ~= 'Vector3' then return end
		prep(part)
		local dist = (origin - target).Magnitude
		local size = math.clamp(dist * 0.02, 4, 14)
		local scan = {origin}
		local hits = {}
		if typeof(extra) == 'Vector3' and (origin - extra).Magnitude < size and free(extra) then return extra end
		if free(target) then hits[#hits + 1] = target end
		local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
		local dir = flat.Magnitude > 0.001 and flat.Unit or Vector3.zAxis
		for _, side in Enum.NormalId:GetEnumItems() do
			local off = Vector3.fromNormalId(side)
			local flat2 = Vector3.new(off.X, 0, off.Z)
			if flat2:Dot(-dir) > -0.5 then
				local point = target + off * size
				if free(point) then hits[#hits + 1] = point end
			end
		end
		for _, off in pos do
			local flat2 = Vector3.new(off.X, 0, off.Z)
			if flat2:Dot(dir) > -0.5 then
				local point = origin + off * size
				if free(point) then scan[#scan + 1] = point end
			end
		end
		for _, hit in hits do
			for _, point in scan do
				local ok, out = pcall(workspace.Raycast, workspace, hit, point - hit, ray)
				if ok and not out then return point, hit end
			end
		end
	end

	function api:line(target, dir, part)
		if typeof(target) ~= 'Vector3' or typeof(dir) ~= 'Vector3' or dir.Magnitude <= 0.0001 then return end
		prep(part)
		local unit = dir.Unit
		local base = 0.05
		if typeof(part) == 'Instance' and part:IsA('BasePart') then
			local vec = part.CFrame:VectorToObjectSpace(unit)
			local half = part.Size * 0.5
			base += math.abs(vec.X) * half.X + math.abs(vec.Y) * half.Y + math.abs(vec.Z) * half.Z
		end
		for _, add in {0, 0.5, 1, 2, 4, 6, 8, 12, 16} do
			local point = target - unit * (base + add)
			if free(point) then
				local ok, out = pcall(workspace.Raycast, workspace, target, point - target, ray)
				if ok and not out then return point end
			end
		end
	end

	ctx.origin = api
end
