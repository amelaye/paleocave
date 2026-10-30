---
name: luanti-cave-mapgen
description: Modifie la génération des cavernes primordiales du mod paleocave (couche -2000 à -5000) - forme des niveaux, mers souterraines, calcaire, ambre lumineux, végétation, arbres, vignes, peintures rupestres - via src/caves.lua et src/mapgen.lua (VoxelManip dans on_generated). À utiliser pour tout ce qui touche au terrain, aux grottes ou à l'éclairage par l'ambre.
---

# Cavernes primordiales : génération

Charger `paleocave-conventions`. Le mod ne choisit pas le mapgen du jeu : il fonctionne avec tout mapgen qui remplit le sous-sol de pierre (v7, valleys, carpathian, v5, flat...). Il est désactivé en `singlenode`.

## Architecture
- `src/caves.lua` : **seule source de vérité** de la géométrie. Couche `TOP = -2000` à `BOTTOM = -5000`, 15 niveaux espacés de 200 nœuds (niveau de la mer ± 20 selon le niveau). Six bruits 2D : `floor`, `ceiling`, `open`, `basin`, `pillar`, `flora`. `caves.column(...)` renvoie le sol F et le plafond C (ou nil pour de la roche) ; les cellules avec F < y <= C sont creuses, et celles <= niveau de la mer contiennent de l'eau.
- `src/mapgen.lua` : `core.register_on_generated` + VoxelManip. Trois passes : terrain (creuser, eau, calcaire, sol), décorations (ambre, plantes, arbres, vignes, varech, peintures), puis `calc_lighting`, `write_to_map`, `update_liquids`.
- Les créatures sont placées à la fin de chaque niveau par `populate()` (même fichier), à partir des données VoxelManip. Le repeuplement optionnel (`src/spawning.lua`) relit la géométrie avec `caves.column_at` : toute modification de la forme doit passer par `caves.lua`.

## Règles à respecter
- Ne creuser que le contenu « sol » (`is_ground_content`), l'air et les liquides : on ne détruit pas les décorations posées par un mapchunk voisin (arbres, ambre, vignes sont `is_ground_content = false`).
- Ne transformer en calcaire que les pierres, le gravier, l'air et les liquides : les minerais et les blocs fossiles de PaleoTest restent visibles dans les parois.
- Toute cellule creuse sous le niveau de la mer est de l'eau, donc l'eau ne touche jamais l'air de côté : pas de fuite. Garder cette propriété.
- Les décorations et les créatures s'ancrent dans le mapchunk (`minp..maxp`). Une décoration qui déborde (arbre, vigne, flèche d'ambre) n'écrit que dans de l'air, ou dans une case pas encore générée qui sera creuse (`free()`).
- Le hasard passe par `PcgRandom(blockseed)` : la génération est alors déterministe.
- Bruits : `core.get_value_noise_map or core.get_perlin_map` (et `core.get_value_noise or core.get_perlin`) pour rester compatible entre versions de Luanti.

## Réglages fréquents
- Densité de lumière : probabilités d'ambre au sol, au plafond, dans les parois et au fond des mers dans `mapgen.lua`. L'ambre émet 13 et la lumière perd 1 par nœud.
- Plus d'eau : seuils de `basin` dans `caves.column`. Plafonds plus hauts : `ceiling`. Moins de cavernes : seuil de `open`.
- Changer `TOP`/`BOTTOM` ou l'espacement ne vaut que pour les zones pas encore générées.

## Vérifier
Monde **neuf** (les chunks déjà générés ne changent pas). En créatif : `/teleport` vers un niveau (par exemple y = -2110), puis observer les mers, l'éclairage et la végétation.
