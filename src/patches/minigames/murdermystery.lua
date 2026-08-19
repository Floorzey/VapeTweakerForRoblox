return function(ctx)
	if ctx.vapeapi.flavor ~= 'new' then return end
	local mod = ctx:find('MurderMystery')
	if type(mod) ~= 'table' or typeof(mod.Object) ~= 'Instance' then return end
	local cat = ctx.vapeapi:category('minigames')
	if type(cat) ~= 'table' or typeof(cat.Object) ~= 'Instance' then return end
	local box = cat.Object:FindFirstChild('Children')
	if typeof(box) ~= 'Instance' then return end
	local obj = mod.Object
	local child = mod.Children
	local op = obj.Parent
	local cp = typeof(child) == 'Instance' and child.Parent or nil
	local old = mod.Category
	obj.Parent = box
	if typeof(child) == 'Instance' then child.Parent = box end
	mod.Category = 'Minigames'
	obj.LayoutOrder = 1
	if typeof(child) == 'Instance' then child.LayoutOrder = 1 end
	ctx.vapeapi:reindex()
	ctx:clean(function()
		if obj.Parent then obj.Parent = op end
		if typeof(child) == 'Instance' and child.Parent then child.Parent = cp end
		mod.Category = old
		ctx.vapeapi:reindex()
	end)
end
