local S = paleocave.S

-- Every node of the caverns is "not ground content": caves of mapchunks
-- generated later must not cut through floors, walls and decorations.

-- Limestone --

core.register_node("paleocave:limestone", {
	description = S("Limestone"),
	tiles = {"paleocave_limestone.png"},
	groups = {cracky = 3, stone = 1},
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
})

core.register_node("paleocave:limestone_brick", {
	description = S("Limestone Brick"),
	paramtype2 = "facedir",
	place_param2 = 0,
	tiles = {"paleocave_limestone_brick.png"},
	groups = {cracky = 2, stone = 1},
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
})

if core.get_modpath("walls") then
	walls.register("paleocave:limestone_brick_wall", S("Limestone Brick Wall"),
		{"paleocave_limestone_brick.png"}, "paleocave:limestone_brick",
		default.node_sound_stone_defaults())
end

-- Bone block: bones bundled together, standing upright or lying like a log.
-- The ruins of primordial houses hold some.

core.register_node("paleocave:bone_block", {
	description = S("Bone Block"),
	tiles = {"paleocave_bone_block_top.png", "paleocave_bone_block_top.png",
		"paleocave_bone_block_side.png"},
	paramtype2 = "facedir",
	on_place = core.rotate_node,
	groups = {cracky = 2},
	is_ground_content = false,
	sounds = default.node_sound_gravel_defaults(),
})

-- Shapes --

-- Stairs, slabs and smaller shapes of these blocks and of PaleoTest's
-- metasequoia logs: those of moreblocks (cut with its circular saw) when it is
-- installed, else the stairs and slabs of the stairs mod. paleocave.shapes
-- lists them for the ruins.

paleocave.shapes = {}

local has_moreblocks = core.get_modpath("moreblocks") and core.global_exists("stairsplus")
	and type(stairsplus.register_all) == "function"

local MOREBLOCKS_SHAPES = {
	slab = "slab_%s", slab_quarter = "slab_%s_quarter", slab_three_quarter = "slab_%s_three_quarter",
	stair = "stair_%s", stair_inner = "stair_%s_inner", stair_outer = "stair_%s_outer",
	panel = "panel_%s", micro = "micro_%s",
}

-- stairs_args: arguments of stairs.register_stair_and_slab after the groups,
-- for the shapes of the stairs mod (nil: moreblocks shapes only)
local function register_shapes(subname, nodename, groups, stairs_args)
	local shapes = {full = nodename}
	paleocave.shapes[subname] = shapes
	local old = "paleocave_" .. subname -- name given by the stairs mod
	if has_moreblocks then
		local def = core.registered_nodes[nodename]
		stairsplus:register_all("paleocave", subname, nodename, {
			description = def.description,
			tiles = def.tiles,
			groups = groups,
			sounds = def.sounds,
			sunlight_propagates = true,
		})
		for kind, pattern in pairs(MOREBLOCKS_SHAPES) do
			shapes[kind] = "paleocave:" .. pattern:format(subname)
		end
		if stairs_args then
			-- stairs and slabs placed before moreblocks was installed
			core.register_alias("stairs:stair_" .. old, shapes.stair)
			core.register_alias("stairs:stair_inner_" .. old, shapes.stair_inner)
			core.register_alias("stairs:stair_outer_" .. old, shapes.stair_outer)
			core.register_alias("stairs:slab_" .. old, shapes.slab)
		end
	elseif stairs_args and core.get_modpath("stairs") then
		stairs.register_stair_and_slab(old, nodename, groups, unpack(stairs_args))
		shapes.stair = "stairs:stair_" .. old
		shapes.stair_inner = "stairs:stair_inner_" .. old
		shapes.stair_outer = "stairs:stair_outer_" .. old
		shapes.slab = "stairs:slab_" .. old
	end
end

register_shapes("limestone", "paleocave:limestone", {cracky = 3},
	{{"paleocave_limestone.png"}, S("Limestone Stair"), S("Limestone Slab"),
	default.node_sound_stone_defaults(), true})
register_shapes("limestone_brick", "paleocave:limestone_brick", {cracky = 2},
	{{"paleocave_limestone_brick.png"}, S("Limestone Brick Stair"), S("Limestone Brick Slab"),
	default.node_sound_stone_defaults(), false})
register_shapes("bone_block", "paleocave:bone_block", {cracky = 2},
	{{"paleocave_bone_block_top.png", "paleocave_bone_block_top.png",
	"paleocave_bone_block_side.png"}, S("Bone Block Stair"), S("Bone Block Slab"),
	default.node_sound_gravel_defaults(), false})
if core.registered_nodes["paleotest:metasequoia_tree"] then
	register_shapes("metasequoia_tree", "paleotest:metasequoia_tree",
		{choppy = 2, oddly_breakable_by_hand = 1, flammable = 2})
end

-- Primordial grass --

core.register_node("paleocave:primordial_grass", {
	description = S("Primordial Grass"),
	tiles = {
		"paleocave_primordial_grass.png",
		"default_dirt.png",
		{name = "default_dirt.png^paleocave_primordial_grass_side.png", tileable_vertical = false},
	},
	groups = {crumbly = 3, soil = 1},
	drop = "default:dirt",
	is_ground_content = false,
	sounds = default.node_sound_dirt_defaults({
		footstep = {name = "default_grass_footstep", gain = 0.25},
	}),
})

-- Amber: translucent resin, in blobs hanging from the ceilings. The ambersol
-- at the top of each blob lights the cavern below it like a sun; its light
-- also makes it a heat source that hatches PaleoTest eggs.

core.register_node("paleocave:amber", {
	description = S("Amber"),
	drawtype = "glasslike",
	tiles = {"paleocave_amber.png"},
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	groups = {cracky = 3},
	is_ground_content = false,
	sounds = default.node_sound_glass_defaults(),
})

core.register_node("paleocave:ambersol", {
	description = S("Ambersol"),
	tiles = {"paleocave_ambersol.png"},
	paramtype = "light",
	light_source = core.LIGHT_MAX,
	groups = {cracky = 2},
	is_ground_content = false,
	sounds = default.node_sound_glass_defaults(),
})

-- Invisible light that the ambersol casts down to the cavern floor.
core.register_node("paleocave:ambersol_light", {
	description = S("Ambersol Light"),
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	light_source = core.LIGHT_MAX,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	drop = "",
	groups = {not_in_creative_inventory = 1},
	is_ground_content = false,
})

-- Amber with a mosquito was removed.
core.register_alias("paleocave:amber_with_mosquito", "paleocave:amber")
core.register_alias("paleocave:mosquito_in_amber", "paleocave:amber")

-- Archaic vines hang from the ceilings; brachiosaurs browse them like leaves.

local function dig_vines_below(pos, _, _, digger)
	local below = {x = pos.x, y = pos.y - 1, z = pos.z}
	local count = 0
	for _ = 1, 64 do
		local name = core.get_node(below).name
		if name ~= "paleocave:archaic_vine" and name ~= "paleocave:archaic_vine_end" then
			break
		end
		core.remove_node(below)
		count = count + 1
		below.y = below.y - 1
	end
	if count > 0 and digger and digger:is_player()
			and not core.is_creative_enabled(digger:get_player_name()) then
		local leftover = digger:get_inventory():add_item("main", "paleocave:archaic_vine " .. count)
		if not leftover:is_empty() then
			core.add_item(pos, leftover)
		end
	end
end

local vine = {
	description = S("Archaic Vine"),
	drawtype = "plantlike",
	tiles = {"paleocave_archaic_vine.png"},
	inventory_image = "paleocave_archaic_vine.png",
	wield_image = "paleocave_archaic_vine.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	climbable = true,
	selection_box = {type = "fixed", fixed = {-0.25, -0.5, -0.25, 0.25, 0.5, 0.25}},
	groups = {snappy = 3, flammable = 2, leaves = 1},
	is_ground_content = false,
	sounds = default.node_sound_leaves_defaults(),
	after_dig_node = dig_vines_below,
}
core.register_node("paleocave:archaic_vine", vine)

local vine_end = table.copy(vine)
vine_end.tiles = {"paleocave_archaic_vine_end.png"}
vine_end.drop = "paleocave:archaic_vine"
vine_end.groups = {snappy = 3, flammable = 2, leaves = 1, not_in_creative_inventory = 1}
core.register_node("paleocave:archaic_vine_end", vine_end)

-- Tree star: in the flora group, so PaleoTest herbivores graze it, follow the
-- player holding it and can be tamed with it.

core.register_node("paleocave:tree_star", {
	description = S("Tree Star") .. "\n" .. core.colorize("#90d060", S("Herbivores love it.")),
	drawtype = "plantlike",
	tiles = {"paleocave_tree_star.png"},
	inventory_image = "paleocave_tree_star.png",
	wield_image = "paleocave_tree_star.png",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	buildable_to = true,
	selection_box = {type = "fixed", fixed = {-0.3, -0.5, -0.3, 0.3, 0.3, 0.3}},
	groups = {snappy = 3, flora = 1, attached_node = 1, flammable = 1},
	is_ground_content = false,
	sounds = default.node_sound_leaves_defaults(),
})

-- Cave paintings --

paleocave.paintings = {"tyrannosaurus", "triceratops", "brachiosaurus", "mosasaurus"}

local painting_descriptions = {
	tyrannosaurus = S("Tyrannosaurus Cave Painting"),
	triceratops = S("Triceratops Cave Painting"),
	brachiosaurus = S("Brachiosaurus Cave Painting"),
	mosasaurus = S("Mosasaurus Cave Painting"),
}

for _, name in ipairs(paleocave.paintings) do
	local texture = "paleocave_cave_painting_" .. name .. ".png"
	core.register_node("paleocave:cave_painting_" .. name, {
		description = painting_descriptions[name],
		drawtype = "signlike",
		tiles = {texture},
		inventory_image = texture,
		wield_image = texture,
		paramtype = "light",
		paramtype2 = "wallmounted",
		sunlight_propagates = true,
		walkable = false,
		selection_box = {type = "wallmounted"},
		groups = {dig_immediate = 3, attached_node = 1},
		is_ground_content = false,
	})
end

-- The cavern floors slowly grow back what the herbivores eat. Plants are
-- swapped in so that PaleoTest's horsetails do not start spreading everywhere.

local regrowth = {}

core.register_on_mods_loaded(function()
	for _, entry in ipairs({
		{"default:fern_1", 0}, {"default:fern_2", 0}, {"default:junglegrass", 0},
		{"paleocave:tree_star", 0}, {"paleotest:horsetail_3", 2}, {"paleotest:cycad_3", 2},
	}) do
		if core.registered_nodes[entry[1]] then
			regrowth[#regrowth + 1] = {name = entry[1], param2 = entry[2]}
		end
	end
end)

core.register_abm({
	label = "Paleocave primordial flora regrowth",
	nodenames = {"paleocave:primordial_grass"},
	neighbors = {"air"},
	interval = 61,
	chance = 400,
	catch_up = false,
	action = function(pos)
		pos.y = pos.y + 1
		if #regrowth == 0 or core.get_node(pos).name ~= "air" then
			return
		end
		local around = core.find_nodes_in_area(
			{x = pos.x - 2, y = pos.y, z = pos.z - 2},
			{x = pos.x + 2, y = pos.y, z = pos.z + 2},
			{"group:flora", "group:plant"})
		if #around < 5 then
			core.swap_node(pos, regrowth[math.random(#regrowth)])
		end
	end,
})
