-- PaleoTest creatures of the primordial caverns: dinosaurs on the floors,
-- sarcosuchus and spinosaurus on the shores, marine reptiles in the
-- underground seas, pterosaurs under the highest ceilings.
-- They are placed when the caverns are generated (see mapgen.lua), so they
-- are already there when players arrive. Optionally, new ones also appear
-- around players to repopulate caverns emptied by hunting.

local caves = paleocave.caves

local creatures = {}
paleocave.creatures = creatures

-- multiplier of the number of creatures placed by the map generator
creatures.density = core.settings:get_bool("paleocave_dinosaurs", true)
	and (tonumber(core.settings:get("paleocave_dinosaur_density")) or 1) or 0

-- where: land, shore (land next to water, or shallow water), water, or air
--        (land under a high ceiling, for flyers)
-- room:  free height above the floor, or water depth for marine creatures
-- width: half-size of the flat open ground a large creature needs, or of the
--        open water around a marine creature (5 by default)
-- max:   most individuals of the species in one place
local species = {
	{name = "paleotest:velociraptor", where = "land", weight = 3, group = {2, 3}, room = 2},
	{name = "paleotest:stegosaurus", where = "land", weight = 4, group = {1, 2}, room = 4},
	{name = "paleotest:triceratops", where = "land", weight = 4, group = {1, 3}, room = 4},
	{name = "paleotest:carnotaurus", where = "land", weight = 2, group = {1, 1}, room = 4},
	{name = "paleotest:tyrannosaurus", where = "land", weight = 1, group = {1, 1}, room = 4, max = 1},
	{name = "paleotest:brachiosaurus", where = "land", weight = 1, group = {1, 2}, room = 8,
		width = 3, max = 2},
	{name = "paleotest:sarcosuchus", where = "shore", weight = 8, group = {1, 2}, room = 3},
	{name = "paleotest:spinosaurus", where = "shore", weight = 5, group = {1, 1}, room = 5, max = 1},
	{name = "paleotest:plesiosaurus", where = "water", weight = 4, group = {2, 3}, room = 3},
	{name = "paleotest:dunkleosteus", where = "water", weight = 3, group = {1, 2}, room = 4},
	{name = "paleotest:mosasaurus", where = "water", weight = 1, group = {1, 1}, room = 10,
		width = 8, max = 1},
	{name = "paleotest:pteranodon", where = "air", weight = 3, group = {2, 3}, room = 16},
	{name = "paleotest:quetzalcoatlus", where = "air", weight = 2, group = {1, 1}, room = 18, max = 1},
}

local available = {}
local is_species = {}

core.register_on_mods_loaded(function()
	for _, def in ipairs(species) do
		local entity = core.registered_entities[def.name]
		if entity then
			def.box = entity.collisionbox
				or (entity.initial_properties and entity.initial_properties.collisionbox)
				or {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
			available[#available + 1] = def
			is_species[def.name] = true
		end
	end
end)

local function suits(def, spot, counts)
	if def.max and (counts[def.name] or 0) >= def.max then
		return false
	end
	if spot.kind == "water" then
		return (def.where == "water" and spot.room >= def.room)
			or (def.where == "shore" and spot.room <= 6)
	end
	if def.where == "water" or (def.where == "shore" and spot.kind ~= "shore") then
		return false
	end
	return spot.room >= def.room
end

-- Picks a species for a spot, or nil.
-- spot:   {kind = "land"|"shore"|"water", room = free height or water depth}
-- counts: individuals of each species already there
-- random: function(min, max) returning an integer
-- fits:   function(def) checking the surroundings (width, open water)
function creatures.choose(spot, counts, random, fits)
	local candidates, total = {}, 0
	for _, def in ipairs(available) do
		if suits(def, spot, counts) and fits(def) then
			candidates[#candidates + 1] = def
			total = total + def.weight
		end
	end
	if total == 0 then
		return nil
	end
	local r = random(1, total)
	for _, def in ipairs(candidates) do
		r = r - def.weight
		if r <= 0 then
			return def
		end
	end
end

-- Adds the creatures chosen while generating a mapchunk. Far from players
-- they are stored with the map until someone comes close.
function creatures.add(list)
	for _, entry in ipairs(list) do
		if core.get_node_or_nil(entry.pos) then
			core.add_entity(entry.pos, entry.name)
		end
	end
end

-- Repopulation around players (off by default) --

if creatures.density == 0 or not core.settings:get_bool("paleocave_repopulate", false) then
	return
end

local MAX_NEAR = tonumber(core.settings:get("paleocave_max_dinosaurs")) or 14
local INTERVAL = tonumber(core.settings:get("paleocave_spawn_interval")) or 30
local RADIUS = 72

local function walkable(node)
	local def = core.registered_nodes[node.name]
	return def and def.walkable
end

local function water_at(pos)
	local node = core.get_node_or_nil(pos)
	return node and core.get_item_group(node.name, "water") > 0
end

-- Dry walkable node near the expected floor height with two free nodes above
-- it, or nil (also when the area is not loaded or the floor is under water).
local function find_floor(x, f, z)
	local pos = {x = x, y = 0, z = z}
	local free = 0
	for y = f + 4, f - 3, -1 do
		pos.y = y
		local node = core.get_node_or_nil(pos)
		if not node or node.name == "ignore" or core.get_item_group(node.name, "liquid") > 0 then
			return nil
		end
		if walkable(node) then
			if free >= 2 then
				return y
			end
			free = 0
		else
			free = free + 1
		end
	end
end

-- No new creature among the ruins.
local RUIN_NODES = {"paleocave:limestone_brick"}

local function find_spot(player_pos)
	local level = caves.level_at(player_pos)
	if not level then
		return nil
	end
	local sea = level.sea
	for _ = 1, 6 do
		local angle = math.random() * 2 * math.pi
		local distance = math.random(20, 56)
		local x = math.floor(player_pos.x + math.cos(angle) * distance + 0.5)
		local z = math.floor(player_pos.z + math.sin(angle) * distance + 0.5)
		local f, ceiling = caves.column_at(level, x, z)
		if f and f < sea - 1 then
			local y = math.floor((f + sea) / 2)
			if water_at({x = x, y = y, z = z}) then
				return {kind = "water", level = level, x = x, y = y, z = z,
					floor = f, room = sea - f}
			end
		elseif f then
			local floor = find_floor(x, f, z)
			if floor and not core.find_node_near({x = x, y = floor, z = z}, 12, RUIN_NODES) then
				local kind = "land"
				if floor <= sea + 4
						and core.find_node_near({x = x, y = sea, z = z}, 8, "group:water") then
					kind = "shore"
				end
				return {kind = kind, level = level, x = x, y = floor, z = z,
					floor = floor, room = ceiling - floor}
			end
		end
	end
end

local CORNERS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}

-- Marine creatures need a real sea, wide creatures flat open ground.
local function surroundings(spot)
	return function(def)
		if spot.kind == "water" then
			if def.where ~= "water" then
				return true
			end
			local reach = def.width or 5
			for _, d in ipairs(CORNERS) do
				local f = caves.column_at(spot.level, spot.x + d[1] * reach, spot.z + d[2] * reach)
				if not f or f >= spot.level.sea - 1 then
					return false
				end
			end
			return true
		end
		if not def.width then
			return true
		end
		for _, d in ipairs(CORNERS) do
			local f, ceiling = caves.column_at(spot.level,
				spot.x + d[1] * def.width, spot.z + d[2] * def.width)
			if not f or f < spot.level.sea or math.abs(f - spot.floor) > 2
					or ceiling - f < def.room then
				return false
			end
		end
		return true
	end
end

-- No walkable node (rock, trunk, leaves...) where the body will be.
local function clear_above(x, floor, z, height)
	local pos = {x = x, y = 0, z = z}
	for y = floor + 1, floor + height do
		pos.y = y
		local node = core.get_node_or_nil(pos)
		if not node or walkable(node) then
			return false
		end
	end
	return true
end

local function spawn(def, spot)
	local box = def.box
	local height = math.ceil(box[5] - box[2])
	for n = 1, math.random(def.group[1], def.group[2]) do
		local x, z = spot.x, spot.z
		if n > 1 then
			x, z = x + math.random(-3, 3), z + math.random(-3, 3)
		end
		local pos
		if spot.kind == "water" then
			-- the whole body under the surface and above the sea floor
			local low = spot.floor + 0.6 - box[2]
			local high = spot.level.sea + 0.4 - box[5]
			if low <= high then
				pos = {x = x, y = math.min(math.max(spot.y, low), high), z = z}
				if not water_at(vector.round(pos)) then
					pos = nil
				end
			end
		else
			local floor = find_floor(x, spot.floor, z)
			if floor and math.abs(floor - spot.floor) <= 2 and clear_above(x, floor, z, height) then
				pos = {x = x, y = floor + 0.6 - box[2], z = z}
			end
		end
		if pos then
			core.add_entity(pos, def.name)
		end
	end
end

local function count_near(pos)
	local total, counts = 0, {}
	for _, obj in ipairs(core.get_objects_inside_radius(pos, RADIUS)) do
		local ent = obj:get_luaentity()
		if ent and is_species[ent.name] and not ent.tamed then
			total = total + 1
			counts[ent.name] = (counts[ent.name] or 0) + 1
		end
	end
	return total, counts
end

local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < INTERVAL then
		return
	end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos.y <= caves.TOP and pos.y >= caves.BOTTOM then
			local total, counts = count_near(pos)
			if total < MAX_NEAR then
				local spot = find_spot(pos)
				local def = spot and creatures.choose(spot, counts, math.random, surroundings(spot))
				if def then
					spawn(def, spot)
				end
			end
		end
	end
end)
