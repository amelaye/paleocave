-- Geometry of the primordial caverns, shared by the map generator and the
-- creature spawner so that both agree on where floors, ceilings and seas are.

local caves = {
	TOP = -2000,
	BOTTOM = -5000,
	-- deepest floor and highest ceiling of a level, relative to its sea level
	DEPTH = 50,
	HEIGHT = 150,
	-- at most this many caverns in the world, each one a disc of this radius,
	-- inside the map (-MAP_LIMIT to MAP_LIMIT in x and z)
	COUNT = 5,
	RADIUS = 250,
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
-- The ceiling is a wide dome, 100 to 120 nodes above the floor in the middle
-- of the cavern and lower towards its edge (`lens`, see caves.lens). Where
-- the cave closes, it curves down to the floor.
function caves.column(sea, n_floor, n_ceiling, n_open, n_basin, lens)
	-- a narrow transition gives steep cave walls, a wider one arched ceilings
	local open = smoothstep(-0.1, 0.05, n_open)
	if open == 0 then
		return nil
	end
	local arch = smoothstep(-0.1, 0.4, n_open)
	local mid = sea + 10
	local floor = sea + 6 + 9 * n_floor - 34 * smoothstep(0.15, 0.65, n_basin)
	local ceiling = sea + 128 + 14 * n_ceiling
	local f = math.max(math.floor(mid + (floor - mid) * open), sea - caves.DEPTH + 4)
	local c = math.min(math.floor(mid + (ceiling - mid) * lens * arch), sea + caves.HEIGHT - 4)
	if c - f < 2 then
		return nil
	end
	return f, c
end

-- The volcano of each cavern: a cone of ash streaked with frozen lava flows,
-- rising from the floor towards a domed ceiling, with a lake of lava in its
-- crater above a conduit going down into the rock. Like the seas, the lava
-- fills a basin closed on every side up to a flat surface: each column is
-- rock up to its floor, then lava up to the lava level, then air. So the
-- lava never flows.
caves.VOLCANO_RADIUS = 90 -- foot of the cone
local VOLCANO_OFFSET = 0.24 -- from the centre of the cavern, in cavern radii
local CRATER_RADIUS = 14 -- top of the rim
local CRATER_WALL = 4 -- inner wall, from the rim down to the lava
local CONE_POWER = 1.5 -- the cone gets steeper towards the top
-- heights relative to the sea level of the cavern; the lava stays below the
-- lowest point of the rim (RIM - 5)
local RIM = 58
local LAVA = 50
local CONDUIT_RADIUS = 2.5
local CONDUIT_BOTTOM = -24
local DOME = caves.HEIGHT - 4 -- ceiling over the crater
local DOME_EDGE = 50 -- and at the edge of the dome
local DOME_RADIUS = 1.3 * caves.VOLCANO_RADIUS
local TAU = 2 * math.pi

-- Position and shape of the volcano of a cavern, drawn from its position.
local function volcano_of(k, cavern)
	local rng = PcgRandom(cavern.x * 7919 + cavern.z * 104729 + k)
	local function angle()
		return rng:next(0, 999) / 1000 * TAU
	end
	local direction, reach = angle(), caves.RADIUS * VOLCANO_OFFSET
	local v = {
		x = math.floor(cavern.x + reach * math.cos(direction) + 0.5),
		z = math.floor(cavern.z + reach * math.sin(direction) + 0.5),
		rim = cavern.sea + RIM,
		lava = cavern.sea + LAVA,
		-- the rim rises and falls around the crater
		wobble = {angle(), angle(), angle()},
		flows = {},
	}
	for n = 1, rng:next(5, 7) do
		v.flows[n] = {angle = angle(), phase = angle(),
			length = rng:next(55, 95) / 100, -- part of the slope it runs down
			width = rng:next(20, 32) / 10}
	end
	return v
end

-- Floor, ceiling and lava level of a column under the dome of the volcano,
-- from the floor and ceiling of the cave without it (the cave is always open
-- there, see caves.open). Also returns the height on the cone, from 0 at its
-- foot to 1 on the rim and in the crater, and whether a frozen lava flow
-- covers the column. Other columns are returned unchanged.
function caves.volcano(level, x, z, f, ceiling)
	local v = level.volcano
	local dx, dz = x - v.x, z - v.z
	local d2 = dx * dx + dz * dz
	if not f or d2 >= DOME_RADIUS * DOME_RADIUS then
		return f, ceiling
	end
	local sea = level.sea
	ceiling = math.max(ceiling,
		math.floor(sea + DOME - (DOME - DOME_EDGE) * d2 / (DOME_RADIUS * DOME_RADIUS)))
	local d = math.sqrt(d2)
	if d >= caves.VOLCANO_RADIUS then
		return f, ceiling
	end
	local lake = CRATER_RADIUS - CRATER_WALL
	if d < lake then
		-- a bowl of lava, the conduit in its middle
		local bottom = d < CONDUIT_RADIUS and sea + CONDUIT_BOTTOM
			or math.floor(v.lava - 2 - 5 * (1 - (d / lake) ^ 2))
		return bottom, ceiling, v.lava, 1, false
	end
	local a = math.atan2(dz, dx)
	local w = v.wobble
	local rim = v.rim + 2.5 * math.sin(2 * a + w[1]) + 1.5 * math.sin(5 * a + w[2])
		+ math.sin(9 * a + w[3])
	if d < CRATER_RADIUS then
		-- inner wall, never below the lava
		local t = (d - lake) / CRATER_WALL
		return math.max(v.lava, math.floor(v.lava + (rim - v.lava) * t ^ 0.6)), ceiling, nil, 1, false
	end
	local slope = caves.VOLCANO_RADIUS - CRATER_RADIUS
	local cone = ((caves.VOLCANO_RADIUS - d) / slope) ^ CONE_POWER
	local top = f + (rim - f) * cone
	for _, flow in ipairs(v.flows) do
		local far = CRATER_RADIUS + flow.length * slope
		if d < far then
			-- a ridge winding down the slope, wider downhill, rounded at its end
			local fa = flow.angle + 0.35 * d / caves.VOLCANO_RADIUS * math.sin(d / 11 + flow.phase)
			local off = math.abs((a - fa + math.pi) % TAU - math.pi) * d
			local width = flow.width * (0.6 + 0.8 * (d - CRATER_RADIUS) / slope)
				* math.sqrt(math.min(1, (far - d) / 8))
			if off < width then
				return math.floor(top) + 1, ceiling, nil, cone, true
			end
		end
	end
	return math.floor(top), ceiling, nil, cone, false
end

-- The cavern grid: squares of CELL nodes that spread out the pillars and the
-- amber blobs. Its lines follow the edges of the default 80-node mapchunks,
-- so that a pillar or a blob stays within one mapchunk.
caves.CELL = 40
local CELL_ORIGIN = -32

-- Range of grid squares covering a range of coordinates.
function caves.cells(from, to)
	return math.floor((from - CELL_ORIGIN) / caves.CELL), math.floor((to - CELL_ORIGIN) / caves.CELL)
end

-- Grid square holding a column.
function caves.cell_of(x, z)
	return math.floor((x - CELL_ORIGIN) / caves.CELL), math.floor((z - CELL_ORIGIN) / caves.CELL)
end

function caves.cell_corner(cx, cz)
	return CELL_ORIGIN + cx * caves.CELL, CELL_ORIGIN + cz * caves.CELL
end

-- Random generator of one grid square of a cavern, the same for every
-- mapchunk that needs it.
function caves.cell_random(level, cx, cz, salt)
	return PcgRandom((cx * 73856093 + cz * 19349663 + level.ox * 83492791 + salt) % 2147483647)
end

-- Limestone pillars from floor to ceiling: one in about half of the grid
-- squares, where the cavern is at least PILLAR_HEIGHT high at its centre.
-- Round, slimmest halfway up, more than twice as wide where they meet the
-- floor and the ceiling.
caves.PILLAR_HEIGHT = 12

function caves.pillar(level, cx, cz)
	local rng = caves.cell_random(level, cx, cz, 1)
	if rng:next(1, 100) > 55 then
		return nil
	end
	local x0, z0 = caves.cell_corner(cx, cz)
	-- the widest part stays inside the square
	local p = {x = x0 + rng:next(10, caves.CELL - 11), z = z0 + rng:next(10, caves.CELL - 11),
		r = rng:next(20, 40) / 10}
	-- none on the volcano
	local v = level.volcano
	if (p.x - v.x) ^ 2 + (p.z - v.z) ^ 2 < (caves.VOLCANO_RADIUS + 12) ^ 2 then
		return nil
	end
	return p
end

-- Radius of a pillar at height t: 0 at the floor, 1 at the ceiling. The
-- widest is at both ends (t = 0 or 1).
function caves.pillar_radius(p, t)
	return p.r * (1 + 1.2 * math.abs(2 * t - 1) ^ 2.5)
end

-- The "open" noise of a column, raised in the middle of the cavern and
-- lowered towards its edge: past 3/4 of the radius the cave closes, and
-- beyond the radius even the limestone stops (the noise stays between -1.96
-- and 1.96). The cave is always open around the volcano, which lies within
-- 3/4 of the radius.
function caves.open(level, x, z, n_open)
	local t = math.sqrt((x - level.x) ^ 2 + (z - level.z) ^ 2) / level.radius
	local v = level.volcano
	local d = math.sqrt((x - v.x) ^ 2 + (z - v.z) ^ 2)
	local volcano = 1.8 * (1 - smoothstep(caves.VOLCANO_RADIUS, DOME_RADIUS, d))
	return n_open + 0.25 + volcano - 3 * smoothstep(0.75, 1, t)
end

-- How high the ceiling rises in a column, from 1 in the middle of the cavern
-- down to 0 at its edge: the cavern is shaped like a lens.
function caves.lens(level, x, z)
	local t2 = ((x - level.x) ^ 2 + (z - level.z) ^ 2) / level.radius ^ 2
	return math.sqrt(math.max(0, 1 - t2))
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
				volcano = volcano_of(k, cavern),
			}
		end
	end
	return levels
end

local point_noises -- created on first use, once the map seed is known

-- Floor, ceiling and lava level of a column as the map generator makes it,
-- pillars aside, and whether the rock there is turned into limestone.
function caves.column_model(level, x, z)
	if not point_noises then
		point_noises = {}
		for name, params in pairs(caves.noises) do
			point_noises[name] = get_noise(params)
		end
	end
	local pos = {x = x + level.ox, y = z + level.oz}
	local open = caves.open(level, x, z, point_noises.open:get_2d(pos))
	local f, c = caves.column(level.sea, point_noises.floor:get_2d(pos), point_noises.ceiling:get_2d(pos),
		open, point_noises.basin:get_2d(pos), caves.lens(level, x, z))
	local lava, cone
	f, c, lava, cone = caves.volcano(level, x, z, f, c)
	return f, c, lava, cone, f ~= nil or caves.near(open)
end

local function noise_column(level, x, z)
	local f, c, lava, cone = caves.column_model(level, x, z)
	return f, c, lava, cone
end

-- Same floor and ceiling as the map generator, nil for rock, including the
-- core of the pillars, and for the crater of the volcano and its rim: no
-- creature appears there and nobody is sent there.
function caves.column_at(level, x, z)
	if (x - level.x) ^ 2 + (z - level.z) ^ 2 >= level.radius ^ 2 then
		return nil
	end
	local f, c, lava, cone = noise_column(level, x, z)
	if not f or lava or (cone and cone > 0.9) then
		return nil
	end
	local p = caves.pillar(level, caves.cell_of(x, z))
	if p and math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2) - 0.5 <= p.r then
		local pf, pc = noise_column(level, p.x, p.z)
		if pf and pc - pf >= caves.PILLAR_HEIGHT then
			return nil
		end
	end
	return f, c
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
