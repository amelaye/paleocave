-- Geometry of the primordial caverns, shared by the map generator and the
-- creature spawner so that both agree on where floors, ceilings and seas are.

local caves = {
	TOP = -2000,
	BOTTOM = -5000,
	-- deepest floor and highest ceiling of a level, relative to its sea level
	DEPTH = 50,
	HEIGHT = 52,
}
paleocave.caves = caves

local LEVEL_SPACING = 200

-- The layer holds stacked cavern levels, each one a cave "world" with its own
-- sea level, floor and ceiling.
caves.levels = {}
for k = 0, (caves.TOP - caves.BOTTOM) / LEVEL_SPACING - 1 do
	local sea = caves.TOP - LEVEL_SPACING / 2 - k * LEVEL_SPACING + (k * 37) % 41 - 20
	caves.levels[#caves.levels + 1] = {
		sea = sea,
		ymin = sea - caves.DEPTH,
		ymax = sea + caves.HEIGHT,
		-- shifting the noise sampling gives every level its own layout
		ox = k * 1733 + 31,
		oz = -k * 2671 - 17,
	}
end

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

-- Rock in and around the caverns is limestone.
function caves.near(n_open)
	return n_open > -0.45
end

local get_noise = core.get_value_noise or core.get_perlin
local point_noises -- created on first use, once the map seed is known

function caves.column_at(level, x, z)
	if not point_noises then
		point_noises = {}
		for name, params in pairs(caves.noises) do
			point_noises[name] = get_noise(params)
		end
	end
	local pos = {x = x + level.ox, y = z + level.oz}
	return caves.column(level.sea, point_noises.floor:get_2d(pos), point_noises.ceiling:get_2d(pos),
		point_noises.open:get_2d(pos), point_noises.basin:get_2d(pos), point_noises.pillar:get_2d(pos))
end

function caves.level_at(y)
	for _, level in ipairs(caves.levels) do
		if y >= level.ymin and y <= level.ymax then
			return level
		end
	end
end
