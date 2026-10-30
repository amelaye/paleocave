-- Carves the primordial caverns into the freshly generated terrain with a
-- VoxelManip, then decorates them. Only mapchunks crossing a level are touched.

local caves = paleocave.caves
local creatures = paleocave.creatures
local structures = paleocave.structures

if core.get_mapgen_setting("mg_name") == "singlenode" then
	core.log("action", "[paleocave] singlenode mapgen: no primordial caverns")
	return
end

local get_noise_map = core.get_value_noise_map or core.get_perlin_map

local c = {}          -- content ids, resolved on first use
local carvable = {}   -- content the caverns may hollow out
local fillable = {}   -- content turned into limestone around the caverns
local solid = {}      -- walkable content, in the way of a creature's body
local land_plants, shore_plants, paintings

local function id(name)
	return core.registered_nodes[name] and core.get_content_id(name)
end

local function plant(name, weight, param2)
	local cid = id(name)
	return cid and {cid = cid, weight = weight, param2 = param2 or 0}
end

local function weighted(...)
	local list, total = {}, 0
	for i = 1, select("#", ...) do
		local entry = select(i, ...)
		if entry then
			list[#list + 1] = entry
			total = total + entry.weight
		end
	end
	list.total = total
	return list
end

local function pick(list, rng)
	local r = rng:next(1, list.total)
	for _, entry in ipairs(list) do
		r = r - entry.weight
		if r <= 0 then
			return entry
		end
	end
end

local function init()
	c.air = core.get_content_id("air")
	c.ignore = core.get_content_id("ignore")
	c.water = id("default:water_source")
	c.dirt = id("default:dirt")
	c.sand = id("default:sand")
	c.clay = id("default:clay") or c.sand
	c.gravel = id("default:gravel") or c.sand
	c.kelp = id("default:sand_with_kelp")
	c.limestone = id("paleocave:limestone")
	c.grass = id("paleocave:primordial_grass")
	c.amber = id("paleocave:amber")
	c.ambersol = id("paleocave:ambersol")
	c.light = id("paleocave:ambersol_light")
	c.vine = id("paleocave:archaic_vine")
	c.vine_end = id("paleocave:archaic_vine_end")
	c.trunk = id("paleotest:metasequoia_tree") or id("default:pine_tree")
	c.leaves = id("paleotest:metasequoia_leaves") or id("default:pine_needles")

	-- Hollowing out only ground content keeps the trees, amber and vines that a
	-- neighbouring mapchunk already placed across the border.
	for name, def in pairs(core.registered_nodes) do
		local cid = core.get_content_id(name)
		if def.is_ground_content ~= false then
			carvable[cid] = true
		end
		if def.walkable ~= false then
			solid[cid] = true
		end
	end
	carvable[c.ignore], solid[c.ignore] = nil, nil
	carvable[c.air], fillable[c.air] = true, true
	-- liquids of other caves next to the caverns would leak into them
	for _, name in ipairs({"default:water_source", "default:water_flowing",
			"default:river_water_source", "default:river_water_flowing",
			"default:lava_source", "default:lava_flowing"}) do
		local cid = id(name)
		if cid then
			carvable[cid], fillable[cid] = true, true
		end
	end
	-- ores and PaleoTest fossil blocks stay visible in the limestone
	for _, name in ipairs({"default:stone", "default:desert_stone", "default:sandstone",
			"default:desert_sandstone", "default:silver_sandstone", "default:gravel"}) do
		local cid = id(name)
		if cid then
			fillable[cid] = true
		end
	end
	-- Everness fills the whole underground with its cave biomes (stone, moss,
	-- crystals, plants, structures): in and around the caverns, all of it is
	-- hollowed out or turned into limestone. Everness is generated first
	-- (optional dependency), so nothing of it comes back afterwards.
	for name in pairs(core.registered_nodes) do
		if name:sub(1, 9) == "everness:" then
			local cid = core.get_content_id(name)
			carvable[cid], fillable[cid] = true, true
		end
	end

	land_plants = weighted(
		plant("default:fern_1", 12), plant("default:fern_2", 10), plant("default:fern_3", 8),
		plant("default:junglegrass", 10), plant("default:grass_3", 5), plant("default:grass_5", 5),
		plant("paleotest:cycad_3", 10, 2), plant("paleotest:horsetail_3", 4, 2),
		plant("paleocave:tree_star", 6))
	shore_plants = weighted(
		plant("paleotest:horsetail_3", 14, 2), plant("default:fern_2", 6),
		plant("default:fern_3", 6), plant("default:junglegrass", 6),
		plant("paleocave:tree_star", 4))
	paintings = {}
	for _, name in ipairs(paleocave.paintings) do
		paintings[#paintings + 1] = id("paleocave:cave_painting_" .. name)
	end
end

local data, param2 = {}, {}
local noise_maps, noise_side
local values = {}
local floors, ceilings, tops = {}, {}, {}
local reserved = {} -- columns taken by a structure

-- Whether a tall decoration may fill a cell: air, or a cell of the mapchunk
-- above or below that is not generated yet but will be hollow there (the
-- engine keeps what is written in such cells, like it does for its own
-- decorations). Only for columns of the current mapchunk.
local function free(ctx, vi, x, y, z)
	local cid = data[vi]
	if cid == c.air then
		return true
	end
	if cid ~= c.ignore then
		return false
	end
	local i = (z - ctx.minp.z) * ctx.side + (x - ctx.minp.x) + 1
	local f = floors[i]
	return f and y > f and y > ctx.sea and y <= ceilings[i]
end

local function grow_tree(ctx, x, y, z, ceiling)
	local area = ctx.area
	local height = ctx.rng:next(8, math.min(16, ceiling - y - 4))
	local top = y + height + 1
	if top > area.MaxEdge.y then
		return
	end
	-- conical crown of a metasequoia
	local bottom = y + math.floor(height * 0.4)
	for yy = bottom, top do
		local radius = math.floor(0.5 + 3.2 * (top - yy) / (top - bottom))
		for dz = -radius, radius do
			for dx = -radius, radius do
				if dx * dx + dz * dz <= radius * radius + 1 then
					local vi = area:index(x + dx, yy, z + dz)
					if free(ctx, vi, x + dx, yy, z + dz) then
						data[vi] = c.leaves
					end
				end
			end
		end
	end
	for yy = y, y + height - 1 do
		local vi = area:index(x, yy, z)
		if data[vi] == c.leaves or free(ctx, vi, x, yy, z) then
			data[vi] = c.trunk
		end
	end
end

-- {dx, dz, wallmounted param2 facing that wall}
local WALLS = {{1, 0, 2}, {-1, 0, 3}, {0, 1, 4}, {0, -1, 5}}

-- Paintings at eye level on the limestone walls.
local function decorate_walls(ctx, x, y, z, ceiling)
	local area, rng, minp, maxp = ctx.area, ctx.rng, ctx.minp, ctx.maxp
	if #paintings == 0 then
		return
	end
	for yy = y + 1, math.min(ceiling - 1, y + 2, maxp.y) do
		local vi = area:index(x, yy, z)
		if data[vi] == c.air then
			for _, wall in ipairs(WALLS) do
				local nx, nz = x + wall[1], z + wall[2]
				if nx >= minp.x and nx <= maxp.x and nz >= minp.z and nz <= maxp.z then
					local ni = area:index(nx, yy, nz)
					if data[ni] == c.limestone and rng:next(1, 1000) <= 8 then
						data[vi] = paintings[rng:next(1, #paintings)]
						param2[vi] = wall[3]
						break
					end
				end
			end
		end
	end
end

local function decorate_floor(ctx, x, z, i, f, ceiling)
	local y = f + 1
	if y < ctx.minp.y or y > ctx.maxp.y then
		return
	end
	local area, rng = ctx.area, ctx.rng
	local vi = area:index(x, y, z)
	if data[vi] ~= c.air then
		return
	end
	local grassy = tops[i] == c.grass
	if rng:next(1, 1000) <= 5 and grassy and ceiling - f >= 20
			and x - ctx.minp.x >= 4 and ctx.maxp.x - x >= 4
			and z - ctx.minp.z >= 4 and ctx.maxp.z - z >= 4
			and not structures.near(ctx, x, z, 5) then
		grow_tree(ctx, x, y, z, ceiling)
	elseif grassy then
		local chance = math.max(8, math.min(70, 30 + 40 * values.flora[i]))
		local list = f <= ctx.sea + 2 and shore_plants or land_plants
		if list.total > 0 and rng:next(1, 100) <= chance then
			local p = pick(list, rng)
			data[vi], param2[vi] = p.cid, p.param2
		end
	end
	decorate_walls(ctx, x, y, z, ceiling)
end

local function decorate_seabed(ctx, x, z, f, ceiling)
	local area, rng = ctx.area, ctx.rng
	local vi = area:index(x, f, z)
	local cid = data[vi]
	if cid ~= c.sand and cid ~= c.clay and cid ~= c.gravel then
		return
	end
	if rng:next(1, 1000) <= 112 and c.kelp and cid == c.sand and ctx.sea - f >= 3 then
		data[vi] = c.kelp
		param2[vi] = 16 * rng:next(2, math.min(6, ctx.sea - f - 1))
	end
end

local function decorate_ceiling(ctx, x, z, f, ceiling)
	local area, rng = ctx.area, ctx.rng
	local ystride = area.ystride
	local vi = area:index(x, ceiling, z)
	if data[vi] ~= c.air then
		return
	end
	local ground = math.max(f, ctx.sea) -- floor, or water surface
	if rng:next(1, 1000) <= 63 then
		local length = math.min(rng:next(2, 9), ceiling - ground - 3)
		local n = 0
		while n < length and free(ctx, vi - n * ystride, x, ceiling - n, z) do
			n = n + 1
		end
		if n >= 2 then
			for k = 0, n - 2 do
				data[vi - k * ystride] = c.vine
			end
			data[vi - (n - 1) * ystride] = c.vine_end
		end
	end
end

-- Creatures --

-- tries per level and mapchunk, before the density setting: about fifteen
-- creatures per 80 x 80 columns of cavern
local CREATURE_TRIES = 11
local CORNERS = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
local AROUND = {{4, 0}, {-4, 0}, {0, 4}, {0, -4}, {8, 0}, {-8, 0}, {0, 8}, {0, -8}}

-- Floor and ceiling of a column of the current mapchunk, nil for rock, for a
-- structure or for a column outside the mapchunk.
local function column(ctx, x, z)
	if x < ctx.minp.x or x > ctx.maxp.x or z < ctx.minp.z or z > ctx.maxp.z then
		return nil
	end
	local i = (z - ctx.minp.z) * ctx.side + (x - ctx.minp.x) + 1
	if reserved[i] then
		return nil
	end
	return floors[i] or nil, ceilings[i]
end

local function near_water(ctx, x, z)
	for _, d in ipairs(AROUND) do
		local f = column(ctx, x + d[1], z + d[2])
		if f and f < ctx.sea then
			return true
		end
	end
	return false
end

-- Marine creatures need a real sea, wide creatures flat open ground.
local function surroundings(ctx, def, spot, x, z, f)
	if spot.kind == "water" then
		if def.where ~= "water" then
			return true
		end
		local reach = def.width or 5
		for _, d in ipairs(CORNERS) do
			local cf = column(ctx, x + d[1] * reach, z + d[2] * reach)
			if not cf or cf >= ctx.sea - 1 then
				return false
			end
		end
		return true
	end
	if not def.width then
		return true
	end
	for _, d in ipairs(CORNERS) do
		local cf, cc = column(ctx, x + d[1] * def.width, z + d[2] * def.width)
		if not cf or cf < ctx.sea or math.abs(cf - f) > 2 or cc - cf < def.room then
			return false
		end
	end
	return true
end

-- Nothing walkable and no water where a land creature's body will be.
local function body_clear(ctx, x, f, z, height, ceiling)
	for y = f + 1, f + height do
		local cid = data[ctx.area:index(x, y, z)]
		if cid == c.ignore then
			-- mapchunk above not generated yet: trust the cave shape
			if y > ceiling then
				return false
			end
		elseif solid[cid] or cid == c.water then
			return false
		end
	end
	return true
end

local function in_water(ctx, x, z, y0, y1)
	for y = y0, y1 do
		if data[ctx.area:index(x, y, z)] ~= c.water then
			return false
		end
	end
	return true
end

local function place_group(ctx, def, spot, x, z, f, counts)
	local rng, box, sea = ctx.rng, def.box, ctx.sea
	local height = math.ceil(box[5] - box[2])
	local placed = 0
	for n = 1, rng:next(def.group[1], def.group[2]) do
		local px, pz = x, z
		if n > 1 then
			px, pz = x + rng:next(-3, 3), z + rng:next(-3, 3)
		end
		local pf, pc = column(ctx, px, pz)
		local pos
		if pf and spot.kind == "water" then
			-- the whole body under the surface and above the sea floor
			local low, high = pf + 0.6 - box[2], sea + 0.4 - box[5]
			local y = math.min(math.max(math.floor((pf + sea) / 2), low), high)
			if pf < sea - 1 and low <= high and y >= ctx.minp.y and y <= ctx.maxp.y
					and in_water(ctx, px, pz, math.floor(y + box[2] + 0.5), math.floor(y + box[5] + 0.5)) then
				pos = {x = px, y = y, z = pz}
			end
		elseif pf and pf >= sea and pf >= ctx.minp.y and math.abs(pf - f) <= 2 then
			local y = pf + 0.6 - box[2]
			if y <= ctx.maxp.y and body_clear(ctx, px, pf, pz, height, pc) then
				pos = {x = px, y = y, z = pz}
			end
		end
		if pos then
			ctx.spawns[#ctx.spawns + 1] = {pos = pos, name = def.name}
			placed = placed + 1
		end
	end
	counts[def.name] = (counts[def.name] or 0) + placed
end

-- Chooses the creatures living in this part of the level. They are added to
-- the world once the mapchunk is written.
local function populate(ctx)
	local rng = ctx.rng
	local tries = math.floor(CREATURE_TRIES * creatures.density + rng:next(0, 99) / 100)
	local function random(a, b)
		return rng:next(a, b)
	end
	local counts = {}
	for _ = 1, tries do
		local x = rng:next(ctx.minp.x, ctx.maxp.x)
		local z = rng:next(ctx.minp.z, ctx.maxp.z)
		local f, ceiling = column(ctx, x, z)
		-- a creature belongs to the mapchunk holding the floor under it
		if f and f >= ctx.minp.y and f <= ctx.maxp.y then
			local spot
			if f < ctx.sea - 1 then
				spot = {kind = "water", room = ctx.sea - f}
			elseif f >= ctx.sea then
				spot = {room = ceiling - f,
					kind = f <= ctx.sea + 4 and near_water(ctx, x, z) and "shore" or "land"}
			end
			local def = spot and creatures.choose(spot, counts, random, function(d)
				return surroundings(ctx, d, spot, x, z, f)
			end)
			if def then
				place_group(ctx, def, spot, x, z, f, counts)
			end
		end
	end
end

-- Pillars, amber and light --

local function column_index(minp, side, x, z)
	return (z - minp.z) * side + (x - minp.x) + 1
end

-- Limestone pillars from floor to ceiling (see caves.pillar). Their core is
-- solid rock for everything else; structures stay off their wider base.
local function raise_pillars(level, minp, maxp, area, y0, y1)
	local side = maxp.x - minp.x + 1
	local cx0, cx1 = caves.cells(minp.x, maxp.x)
	local cz0, cz1 = caves.cells(minp.z, maxp.z)
	for cz = cz0, cz1 do
		for cx = cx0, cx1 do
			local p = caves.pillar(level, cx, cz)
			if p and p.x >= minp.x and p.x <= maxp.x and p.z >= minp.z and p.z <= maxp.z then
				local ci = column_index(minp, side, p.x, p.z)
				local pf, pc = floors[ci], ceilings[ci]
				if pf and pc - pf >= caves.PILLAR_HEIGHT then
					local widest = caves.pillar_radius(p, 0)
					local reach = math.ceil(widest)
					for z = math.max(p.z - reach, minp.z), math.min(p.z + reach, maxp.z) do
						for x = math.max(p.x - reach, minp.x), math.min(p.x + reach, maxp.x) do
							local i = column_index(minp, side, x, z)
							local f, ceiling = floors[i], ceilings[i]
							local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2) - 0.5
							if f and d <= widest then
								local vi = area:index(x, math.max(f + 1, y0), z)
								for y = math.max(f + 1, y0), math.min(ceiling, y1) do
									local t = math.min(math.max((y - pf) / (pc - pf), 0), 1)
									local cid = data[vi]
									if (cid == c.air or cid == c.water) and d <= caves.pillar_radius(p, t) then
										data[vi] = c.limestone
									end
									vi = vi + area.ystride
								end
								if d <= p.r then
									floors[i] = false
								else
									reserved[i] = true
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Amber blobs hanging from the ceiling, at most one per cell square of the
-- cavern grid, with an ambersol at the top of each one. Every mapchunk that
-- a blob crosses draws the same one. Returns the blobs.
local function hang_amber(ctx, level)
	local area, minp, maxp, side = ctx.area, ctx.minp, ctx.maxp, ctx.side
	local blobs = {}
	local cx0, cx1 = caves.cells(minp.x, maxp.x)
	local cz0, cz1 = caves.cells(minp.z, maxp.z)
	for cz = cz0, cz1 do
		for cx = cx0, cx1 do
			local rng = caves.cell_random(level, cx, cz, 2)
			local x0, z0 = caves.cell_corner(cx, cz)
			-- the first spot under a high enough ceiling
			for _ = 1, 8 do
				local x = x0 + rng:next(4, caves.CELL - 5)
				local z = z0 + rng:next(4, caves.CELL - 5)
				if x - minp.x >= 2 and maxp.x - x >= 2 and z - minp.z >= 2 and maxp.z - z >= 2 then
					local i = column_index(minp, side, x, z)
					local f, ceiling = floors[i], ceilings[i]
					if f and ceiling - math.max(f, ctx.sea) >= 8 then
						blobs[#blobs + 1] = {x = x, z = z, f = f, ceiling = ceiling, cx = cx, cz = cz,
							radius = rng:next(1, 2) + 0.5, down = rng:next(1, 2)}
						break
					end
				end
			end
		end
	end
	for _, b in ipairs(blobs) do
		-- one layer in the ceiling rock, one or two hanging below it
		local top = b.ceiling + 1
		for y = math.max(top - b.down, minp.y), math.min(top, maxp.y) do
			local r = b.radius - 0.7 * (top - y)
			for z = b.z - 2, b.z + 2 do
				for x = b.x - 2, b.x + 2 do
					if (x - b.x) ^ 2 + (z - b.z) ^ 2 <= r * r then
						local vi = area:index(x, y, z)
						local cid = data[vi]
						if cid == c.air or cid == c.limestone then
							data[vi] = c.amber
						end
					end
				end
			end
		end
		if top >= minp.y and top <= maxp.y then
			data[area:index(b.x, top, b.z)] = c.ambersol
		end
	end
	return blobs
end

-- Space between the invisible lights, over the floor and down the column
-- under each ambersol.
local LIGHT_STEP = 6

local function put_light(ctx, x, y, z)
	if y >= ctx.minp.y and y <= ctx.maxp.y then
		local vi = ctx.area:index(x, y, z)
		if data[vi] == c.air then
			data[vi] = c.light
		end
	end
end

-- The ambersol lights everything below it: invisible lights down from each
-- blob, and over the floor of its whole cell square. Placed after the
-- decorations, in the air only.
local function cast_light(ctx, blobs)
	local minp, maxp, side, sea = ctx.minp, ctx.maxp, ctx.side, ctx.sea
	for _, b in ipairs(blobs) do
		for y = b.ceiling - b.down, math.max(b.f, sea) + 2, -LIGHT_STEP do
			put_light(ctx, b.x, y, b.z)
		end
		local x0, z0 = caves.cell_corner(b.cx, b.cz)
		for z = math.max(z0 + 3, minp.z), math.min(z0 + caves.CELL - 1, maxp.z) do
			if (z - z0 - 3) % LIGHT_STEP == 0 then
				for x = math.max(x0 + 3, minp.x), math.min(x0 + caves.CELL - 1, maxp.x) do
					if (x - x0 - 3) % LIGHT_STEP == 0 then
						local i = column_index(minp, side, x, z)
						local f = floors[i]
						if f then
							local y = math.max(f, sea) + 2
							if y < ceilings[i] then
								put_light(ctx, x, y, z)
							end
						end
					end
				end
			end
		end
	end
end

local function generate_level(level, minp, maxp, area, rng, spawns, chests)
	local side = maxp.x - minp.x + 1
	if noise_side ~= side then
		noise_maps, noise_side = {}, side
		for name, params in pairs(caves.noises) do
			noise_maps[name] = get_noise_map(params, {x = side, y = side})
		end
	end
	local pos2d = {x = minp.x + level.ox, y = minp.z + level.oz}
	for name, map in pairs(noise_maps) do
		values[name] = map:get_2d_map_flat(pos2d, values[name])
	end

	local sea = level.sea
	local y0, y1 = math.max(minp.y, level.ymin), math.min(maxp.y, level.ymax)
	local ystride = area.ystride
	local n_floor, n_ceiling, n_open = values.floor, values.ceiling, values.open
	local n_basin, n_flora = values.basin, values.flora

	-- Terrain: hollow out the caverns, fill the seas, lay the floors and turn
	-- the surrounding rock into limestone.
	local i = 0
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			i = i + 1
			local open = caves.open(level, x, z, n_open[i])
			local f, ceiling = caves.column(sea, n_floor[i], n_ceiling[i], open, n_basin[i])
			floors[i], ceilings[i] = f or false, ceiling or false
			reserved[i] = false
			local top
			if f then
				if f < sea then
					top = n_flora[i] > 0.35 and c.clay or n_flora[i] < -0.45 and c.gravel or c.sand
				elseif f <= sea + 1 and n_flora[i] < 0.1 then
					top = c.sand -- beach
				else
					top = c.grass
				end
			end
			tops[i] = top or false
			if f or caves.near(open) then
				local vi = area:index(x, y0, z)
				for y = y0, y1 do
					local cid = data[vi]
					if f and y > f and y <= ceiling then
						if carvable[cid] then
							data[vi] = y <= sea and c.water or c.air
						end
					elseif f and y <= f and y > f - 4 then
						if carvable[cid] then
							if y == f then
								data[vi] = top
							elseif top == c.grass then
								data[vi] = c.dirt
							else
								data[vi] = c.sand
							end
						end
					elseif fillable[cid] then
						data[vi] = c.limestone
					end
					vi = vi + ystride
				end
			end
		end
	end

	raise_pillars(level, minp, maxp, area, y0, y1)

	local ctx = {area = area, rng = rng, minp = minp, maxp = maxp, sea = sea, side = side,
		spawns = spawns, data = data, param2 = param2, floors = floors, ceilings = ceilings,
		reserved = reserved, footprints = {}, chests = chests}
	-- Ruins and skeletons, on floors levelled for them
	if structures.enabled then
		structures.build(ctx)
	end

	local blobs = hang_amber(ctx, level)

	-- Decorations
	i = 0
	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			i = i + 1
			local f = floors[i]
			if f then
				local ceiling = ceilings[i]
				-- the structures keep their columns
				if not reserved[i] then
					if f >= sea then
						decorate_floor(ctx, x, z, i, f, ceiling)
					elseif f >= minp.y and f <= maxp.y then
						decorate_seabed(ctx, x, z, f, ceiling)
					end
				end
				if ceiling >= minp.y and ceiling <= maxp.y then
					decorate_ceiling(ctx, x, z, f, ceiling)
				end
			end
		end
	end

	cast_light(ctx, blobs)

	if creatures.density > 0 then
		populate(ctx)
	end
end

core.register_on_generated(function(minp, maxp, blockseed)
	if maxp.y < caves.BOTTOM or minp.y > caves.TOP then
		return
	end
	local todo
	for _, level in ipairs(caves.get_levels()) do
		if level.ymax >= minp.y and level.ymin <= maxp.y
				and level.x + level.radius >= minp.x and level.x - level.radius <= maxp.x
				and level.z + level.radius >= minp.z and level.z - level.radius <= maxp.z then
			todo = todo or {}
			todo[#todo + 1] = level
		end
	end
	if not todo then
		return
	end
	if not c.air then
		init()
	end

	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	data = vm:get_data(data)
	param2 = vm:get_param2_data(param2)
	local rng = PcgRandom(blockseed)
	local spawns, chests = {}, {}
	for _, level in ipairs(todo) do
		generate_level(level, minp, maxp, area, rng, spawns, chests)
	end
	vm:set_data(data)
	vm:set_param2_data(param2)
	vm:calc_lighting()
	vm:write_to_map()
	vm:update_liquids()
	if #chests > 0 then
		structures.fill_chests(chests)
	end
	if #spawns > 0 then
		core.after(0, creatures.add, spawns)
	end
end)
