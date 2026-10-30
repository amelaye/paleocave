core.register_craft({
	output = "paleocave:limestone_brick 4",
	recipe = {
		{"paleocave:limestone", "paleocave:limestone"},
		{"paleocave:limestone", "paleocave:limestone"},
	},
})

-- A mosquito trapped in amber holds dinosaur blood: PaleoTest's fossil analyzer
-- turns it into DNA of a dinosaur, pterosaur or marine reptile.

local dna = {}
for _, name in ipairs({"brachiosaurus", "carnotaurus", "dunkleosteus", "mosasaurus",
		"plesiosaurus", "pteranodon", "quetzalcoatlus", "sarcosuchus", "spinosaurus",
		"stegosaurus", "triceratops", "tyrannosaurus", "velociraptor"}) do
	if core.registered_items["paleotest:dna_" .. name] then
		dna[#dna + 1] = "paleotest:dna_" .. name
	end
end

local analyzer = paleotest.fossil_analyzer
if analyzer and analyzer.register_recipe and #dna > 0 then
	analyzer.register_recipe("paleocave:mosquito_in_amber", function()
		if math.random(10) <= 7 then
			return dna[math.random(#dna)]
		end
		return "paleocave:amber"
	end)
else
	core.log("warning", "[paleocave] PaleoTest fossil analyzer not found: " ..
		"mosquitoes in amber cannot be analyzed")
end
