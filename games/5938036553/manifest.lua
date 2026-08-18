return {
	name = "frontlines - game",
	original = "frontlines/5938036553 - game",

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
