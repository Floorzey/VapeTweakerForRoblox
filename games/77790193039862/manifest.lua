return {
	name = "1.8arena - game",
	original = "1.8arena/77790193039862 - game",

	-- Universal files that must not load in this place:
	exclude = {
		modules = {},
		patches = {}
	},

	-- Universal VapeTweaker module names to remove after loading:
	remove = {},

	modules = true,
	patches = true
}
