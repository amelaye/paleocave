---
name: luanti-register-content
description: Ajoute ou modifie du contenu jouable dans le mod paleocave (nœuds, items, outils, recettes, escaliers, murs, plantes) avec les APIs de Minetest Game, et le rend compatible avec PaleoTest (viande, plantes, chaleur pour les œufs). À utiliser pour tout nouveau bloc, objet, outil ou recette.
---

# Enregistrer du contenu

Charger `paleocave-conventions`. Nom : `paleocave:<nom>`, code dans le fichier `src/` du domaine (`nodes.lua`, `crafts.lua`...).

## Nœud
```lua
local S = paleocave.S

core.register_node("paleocave:limestone", {
	description = S("Limestone"),
	tiles = {"paleocave_limestone.png"},
	groups = {cracky = 3, stone = 1},
	is_ground_content = false,  -- nœuds des cavernes : protégés des grottes générées plus tard
	sounds = default.node_sound_stone_defaults(),
})
```
Sons MTG : `default.node_sound_{stone,dirt,sand,gravel,wood,leaves,glass,metal,water,snow,ice}_defaults()`.
Groupes MTG : `cracky/crumbly/choppy/snappy/oddly_breakable_by_hand/dig_immediate` (+ `level`), `stone`, `wood`, `tree`, `leaves`, `flora`, `soil`, `sand`, `flammable`, `attached_node`.

## Variantes (APIs MTG, toujours sous condition)
Escaliers, dalles et autres formes : passer par `register_shapes(subname, nœud, groupes, args_stairs)` de `src/nodes.lua`. Avec **moreblocks**, il appelle `stairsplus:register_all("paleocave", subname, ...)` (nœuds `paleocave:slab_<subname>_quarter`, `paleocave:micro_<subname>`..., scie circulaire) et crée des alias depuis les anciens noms `stairs:*_paleocave_<subname>`. Sans moreblocks, il appelle `stairs.register_stair_and_slab("paleocave_<subname>", ...)`. Dans les deux cas, il remplit `paleocave.shapes[subname]` (`full`, `slab`, `slab_quarter`, `slab_three_quarter`, `stair`, `stair_inner`, `stair_outer`, `panel`, `micro`), que les ruines utilisent. Ne pas enregistrer de formes moreblocks pour les planches de métaséquoia : PaleoTest a déjà leurs escaliers `stairs`, et les recettes se contrediraient.
```lua
if core.get_modpath("walls") then
	walls.register("paleocave:limestone_brick_wall", S("Limestone Brick Wall"),
		{"paleocave_limestone_brick.png"}, "paleocave:limestone_brick", default.node_sound_stone_defaults())
end
```
Préfixer le `subname` des escaliers (`paleocave_...`) pour éviter les collisions avec d'autres mods du jeu. Lire les signatures dans le code de MTG (copie dans le scratchpad) avant d'utiliser `doors`, `farming`, `bucket`...

## Recettes
`core.register_craft` (shaped, `shapeless`, `cooking`, `fuel`). Pour modifier une recette d'un autre mod : `core.clear_craft` puis ré-enregistrer, depuis paleocave (jamais en éditant l'autre mod).

## Compatibilité PaleoTest
- Viande crue : `groups = {food_meat_raw = 1}` → mangée par les carnivores.
- Plante broutable / qui attire et apprivoise les herbivores : groupe `flora` (ex. `paleocave:tree_star`) ; feuillage pour le brachiosaure : groupe `leaves`.
- Source de lumière `>= 12` = couveuse pour les œufs (l'ambre à 13 l'est).
- Nouvelle source d'ADN : `paleotest.fossil_analyzer.register_recipe("paleocave:x", function() return "paleotest:dna_..." end)` (voir `src/crafts.lua`).
- Pour poser des plantes PaleoTest par programme, utiliser `core.swap_node` : un `set_node` lance leurs minuteries de croissance, et les prêles envahissent alors tout le sol.

## Textes
Chaque nouvelle chaîne `S("...")` est ajoutée à `locale/template.txt` et traduite dans `locale/paleocave.fr.tr`.
