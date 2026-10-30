-- mobkit, which PaleoTest uses through mob_core, writes "get_nodes_in_area:
-- area too big" in the chat each time a creature checks a step with more than
-- 125 nodes to look at. Same function, same limit, without the message.

if not (mobkit and mobkit.get_nodes_in_area and mobkit.get_node_pos and mobkit.nodeatpos) then
	return
end

local MAX_NODES = 125

function mobkit.get_nodes_in_area(pos1, pos2, full)
	local npos1, npos2 = mobkit.get_node_pos(pos1), mobkit.get_node_pos(pos2)
	local sx = pos2.x < pos1.x and -1 or 1
	local sy = pos2.y < pos1.y and -1 or 1
	local sz = pos2.z < pos1.z and -1 or 1
	local result, count = {}, 0
	for x = npos1.x, npos2.x, sx do
		for z = npos1.z, npos2.z, sz do
			for y = npos1.y, npos2.y, sy do
				local pos = {x = x, y = y, z = z}
				local node = mobkit.nodeatpos(pos)
				if node then
					if full == true then
						result[pos] = node
					else
						result[node] = true
					end
				end
				count = count + 1
				if count > MAX_NODES then
					return result
				end
			end
		end
	end
	return result
end
