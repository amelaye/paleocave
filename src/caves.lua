-- Geometry of the primordial caverns, shared by the map generator and the
-- creature spawner so that both agree on where floors, ceilings and seas are.

local caves = {
	TOP = -2000,
	BOTTOM = -5000,
	-- deepest floor and highest ceiling of a level, relative to its sea level
	DEPTH = 50,
	HEIGHT = 52,
	-- at most this many caverns in the world, each one a disc of this radius,
	-- inside the map (-MAP_LIMIT to MAP_LIMIT in x and z)
	COUNT = 5,
	RADIUS = 400,
	MAP_LIMIT = 10000,
}
paleocave.caves = caves

local storage = core.get_mod_storage()

local function noise(seed, spread, octaves, persistence)
	return {
		offset = 0,
		scale = 1,
		spread = {x = spread, y = spread, z = spread},
		seed = seed,
		octaves = octaves,
		persistence = persistence,
		lacunarity = 2.0,
	}
end

caves.noises = {
	floor = noise(61001, 96, 4, 0.5),
	ceiling = noise(61002, 160, 3, 0.55),
	open = noise(61003, 256, 3, 0.6),
	basin = noise(61004, 192, 2, 0.5),
	pillar = noise(61005, 14, 2, 0.5),
	flora = noise(61006, 48, 2, 0.5),
}

local function smoothstep(edge0, edge1, x)
	local t = (x - edge0) / (edge1 - edge0)
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return t * t * (3 - 2 * t)
end

-- Floor and ceiling of the cave in one column, or nil for solid rock.
-- Cells with floor < y <= ceiling are hollow; the hollow cells at or below sea
-- level hold water. Cave edges close above the sea, so water never touches air
-- from the side.
function caves.column(sea, n_floor, n_ceiling, n_open, n_basin, n_pillar)
	-- a narrow transition gives steep cave walls
	local open = smoothstep(-0.1, 0.05, n_open)
	if open == 0 then
		return nil
	end
	local mid = sea + 10
	local floor = sea + 6 + 9 * n_floor - 34 * smoothstep(0.15, 0.65, n_basin)
	local ceiling = sea + 30 + 12 * n_ceiling
	local f = math.max(math.floor(mid + (floor - mid) * open), sea - caves.DEPTH + 4)
	local c = math.min(math.floor(mid + (ceiling - mid) * open), sea + caves.HEIGHT - 4)
	if c - f < 2 or (n_pillar > 0.78 and open > 0.6 and c - f > 12) then
		return nil
	end
	return f, c
end

-- The "open" noise of a column, raised in the middle of the cavern and
-- lowered towards its edge: past 3/4 of the radius the cave closes, and
-- beyond the radius even the limestone stops (the noise never exceeds 1.96).
function caves.open(level, x, z, n_open)
	local t = math.sqrt((x - level.x) ^ 2 + (z - level.z) ^ 2) / level.radius
	return n_open + 0.25 - 3 * smoothstep(0.75, 1, t)
end

-- Rock in and around the caverns is limestone.
function caves.near(n_open)
	return n_open > -0.45
end

local get_noise = core.get_value_noise or core.get_perlin

-- Caverns of the world: a few discs, far from each other, each one holding a
-- single cave level with its own depth. Chosen from the world seed once the
-- map generator runs (noises only know the seed by then), then stored with
-- the world so that they never move, even if the settings change.
local levels

local function place_caverns()
	local saved = core.deserialize(storage:get_string("caverns"))
	if saved then
		return saved
	end
	local seed = get_noise(noise(61010, 1, 1, 0.5)):get_2d({x = 3, y = 7})
	local rng = PcgRandom(math.floor((seed + 1) * 1073741823))
	-- the whole disc inside the map, with a mapchunk to spare
	local reach = caves.MAP_LIMIT - caves.RADIUS - 80
	local spacing = math.max(reach * 0.6, 2 * caves.RADIUS + 80)
	local list = {}
	for try = 1, 2000 do
		local x, z = rng:next(-reach, reach), rng:next(-reach, reach)
		local free = true
		for _, other in ipairs(list) do
			if (x - other.x) ^ 2 + (z - other.z) ^ 2 < spacing * spacing then
				free = false
				break
			end
		end
		if free then
			list[#list + 1] = {x = x, z = z,
				sea = rng:next(caves.BOTTOM + caves.DEPTH + 16, caves.TOP - caves.HEIGHT - 16)}
			if #list == caves.COUNT then
				break
			end
		elseif try % 200 == 0 then
			-- small map: closer caverns, but never overlapping
			spacing = math.max(spacing * 0.8, 2 * caves.RADIUS + 80)
		end
	end
	storage:set_string("caverns", core.serialize(list))
	return list
end

function caves.get_levels()
	if not levels then
		levels = {}
		for k, cavern in ipairs(place_caverns()) do
			levels[k] = {
				x = cavern.x,
				z = cavern.z,
				radius = caves.RADIUS,
				sea = cavern.sea,
				ymin = cavern.sea - caves.DEPTH,
				ymax = cavern.sea + caves.HEIGHT,
				-- shifting the noise sampling gives every cavern its own layout
				ox = k * 1733 + 31,
				oz = -k * 2671 - 17,
			}
		end
	end
	return levels
end

local point_noises -- created on first use, once the map seed is known

function caves.column_at(level, x, z)
	if (x - level.x) ^ 2 + (z - level.z) ^ 2 >= level.radius ^ 2 then
		return nil
	end
	if not point_noises then
		point_noises = {}
		for name, params in pairs(caves.noises) do
			point_noises[name] = get_noise(params)
		end
	end
	local pos = {x = x + level.ox, y = z + level.oz}
	return caves.column(level.sea, point_noises.floor:get_2d(pos), point_noises.ceiling:get_2d(pos),
		caves.open(level, x, z, point_noises.open:get_2d(pos)), point_noises.basin:get_2d(pos),
		point_noises.pillar:get_2d(pos))
end

function caves.level_at(pos)
	for _, level in ipairs(caves.get_levels()) do
		if pos.y >= level.ymin and pos.y <= level.ymax
				and (pos.x - level.x) ^ 2 + (pos.z - level.z) ^ 2 < level.radius ^ 2 then
			return level
		end
	end
end

local SEARCH_STEP = 8

-- Dry floor of the nearest cavern: the position just above it, or nil.
-- Columns are sampled every SEARCH_STEP nodes in square rings growing around
-- pos when it is above or below the cavern, around its centre otherwise.
function caves.find_nearest(pos)
	local px, py, pz = math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5)
	-- distance between pos and each cavern
	local sorted, gaps = {}, {}
	for _, level in ipairs(caves.get_levels()) do
		local h = math.max(math.sqrt((px - level.x) ^ 2 + (pz - level.z) ^ 2) - level.radius, 0)
		local v = math.max(level.ymin - py, py - level.ymax, 0)
		gaps[level] = h * h + v * v
		sorted[#sorted + 1] = level
	end
	table.sort(sorted, function(a, b) return gaps[a] < gaps[b] end)

	for _, level in ipairs(sorted) do
		local cx, cz = level.x, level.z
		if (px - cx) ^ 2 + (pz - cz) ^ 2 < level.radius ^ 2 then
			cx, cz = px, pz
		end
		local best, best_d
		local function try(x, z)
			local f = caves.column_at(level, x, z)
			if f and f >= level.sea then
				local y = f + 1
				local d = (x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2
				if not best_d or d < best_d then
					best, best_d = vector.new(x, y, z), d
				end
			end
		end
		for r = 0, 2 * level.radius, SEARCH_STEP do
			if r == 0 then
				try(cx, cz)
			else
				for d = -r, r, SEARCH_STEP do
					try(cx + d, cz - r)
					try(cx + d, cz + r)
				end
				for d = -r + SEARCH_STEP, r - SEARCH_STEP, SEARCH_STEP do
					try(cx - r, cz + d)
					try(cx + r, cz + d)
				end
			end
			if best then
				return best
			end
		end
	end
end
